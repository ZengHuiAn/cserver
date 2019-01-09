
package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

require "network"

local Battle = require "battlefield/Battle"
local Skill = require "battlefield/Skill"
local battle_config = require "config/battle";
local Thread = require "utils.Thread"
local cell = require "cell"
local Scheduler = require "Scheduler"
local PlayerManager = require "PlayerManager"

require "NetService"
require "protobuf"
require "Thread"

require "battle_init"

local battle_loader = require "battle_loader"
local AI_MAX_ID = 99999

local T = {
	FIGHT_START           = 1,
	MONSTER_ENTER         = 2,
	MONSTER_DEAD          = 3,
	PLAYER_READY          = 4,
	CHARACTER_DEAD        = 5, 
	PLAYER_FINISHED       = 6, 
	FIGHT_FINISHED        = 7, 
	PLAYER_COMMAND        = 8,
	KILL_COMMAND          = 9,
	PLAYER_BACK           = 10,
	VOTE_TO_EXIT          = 11,
}

local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));		
		loop.exit();
		return nil;
	end
	return code;
end

local function decode(code, protocol)
	return protobuf.decode("com.agame.protocol." .. protocol, code);
end

local VM = {}

local next_vm_id = 0;

function VM:OnClientCommand(pid, cmd)
	if not cmd then return; end

	print(pid, 'OnClientCommand', pid, cmd.type);
	local player = self.player_info[pid];
	if not player then
		print('', pid, 'not in battle')
		return;
	end
		
	if cmd.pid ~= player.pid then
		print('', 'pid error', cmd.pid, self.pid);
		return;
	end


	if cmd.type == "INPUT" then
		if cmd.skill == 99036 then
			print(pid, 'set auto input', cmd.target == 1);
			player.auto_input = (cmd.target == 1);
			self:DoCommand(cmd);
		elseif cmd.skill == 98000 then
			self:DoCommand({{ type="INPUT", refid = cmd.refid, sync_id = cmd.sync_id, skill = 98000, target = cmd.target}})
		elseif self.waiting_input == nil or self.waiting_input.refid ~= cmd.refid or self.waiting_input.sync_id ~= cmd.sync_id then
			if self.waiting_input then
				print('player input error', self.waiting_input.refid, self.waiting_input.sync_id, cmd.refid, cmd.sync_id);
			else
				print('player input error', 'nil');
			end
			self:NotifyPlayerCommand({{ type="INPUT", refid = cmd.refid, sync_id = cmd.sync_id,	skill = 99035}}, {pid})
			return;
		else
			self:DoCommand(cmd);
		end

	else
		print('unknown player command', cmd.type);
	end
end

function VM:DoCommand(...)
	for _, cmd in ipairs({...}) do
		self.battle:PushCommand(cmd);
	end

	self:NotifyPlayerCommand({...});
end

function VM:DoAutoAction(refid, sync_id, pid)
	self:DoCommand({
			type="INPUT", pid = pid,
			tick = self.battle:GetTick(),
			refid = refid, sync_id = sync_id,
			skill = 0,
			target = 0,
	});
end

function VM:DoTimeoutAction(refid, sync_id, pid)
	local is_ai = (pid <= AI_MAX_ID);
	local cmd = {
		type="INPUT", pid = pid,
		tick   = self.battle:GetTick(),
		refid  = refid, sync_id = sync_id,
		skill  = is_ai and 0 or 11,
		target = is_ai and 0 or 1;
	};

	local player = self.player_info[pid]

	if player.auto_input or is_ai then
		self:DoCommand(cmd);
	else
		print(pid, 'set auto input by time', true);
		player.auto_input = true;

		self:DoCommand(cmd, {
				  type="INPUT", pid = pid,
				  tick = self.battle:GetTick(),
				  refid = 0, sync_id = 0,
				  skill = 99036,
				  target = 1
		});
	end
end


function VM:NotifyPlayerCommand(cmds, pids)
	local code = encode('FightCommand', {commands=cmds});
	self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.PLAYER_COMMAND, {code}}, pids, true);
end

function VM.New(attacker, defender, observer, ...)
	local t = { pids = {attacker, defender} , observer = observer, player_info = {} }

	t.thread = Thread.Create(VM.Loop);

	t.player_info =  {}
	t.scene = observer and observer.scene

	t.sync_id = 100;

	t = setmetatable(t, {__index=VM})

	next_vm_id = next_vm_id + 1;
	t.id = next_vm_id;

	t.name = 'MatchFightVM ' .. t.id;

	t.fight_time = loop.now()

	return t;
end

function VM:Start()
	for _, pid in ipairs(self.pids) do
		local player = PlayerManager.Get(pid);
		if player.vm then
			self:LOG("player %d already in vm %s", pid, player.vm.name);
			return false;
		end
	end

	for _, pid in ipairs(self.pids) do
		local player = PlayerManager.Get(pid);
		player.vm = self;
	end

	self.thread:Start(self);
	return true
end

function VM:Command(pid, cmd, data)
	self.thread:send_message(pid, cmd, data);
end

-- buff    {defender_debuff = {type = value...}, defender_property_change = {type = value, ...}, attacker_buff = {type = value, ...}}   防守者属性降低， 防守者属性改变， 攻击者属性增加
function VM:AddBuff(buff)
	self.buff = buff
end

function VM:LOG(...)
	print(string.format('[%s]', self.name),  string.format(...));	
end

function VM:Command(pid, cmd, data)
	self.thread:send_message(pid, cmd, data);
end


local update_list = {}
Scheduler.Register(function()
	for _, v in pairs(update_list) do
		v.thread:send_message(0, 'UPDATE');
	end
end)

function VM:Loop()
	self:LOG('start fight thread');

	update_list[self.id] = self;

	local winner = self:DoFight();

	self:LOG('winner ==> %s', winner or 'nil');
	
	update_list[self.id] = nil;

	local members_heros = {}
	for _, v in pairs(self.player_info) do
		local player = PlayerManager.Get(v.pid);
		members_heros[v.pid] = v.heros
		player.vm = nil;
	end

	if self.observer and self.observer.OnFightFinished then
		self.observer:OnFightFinished(winner, self.fight_id, self.fight_time, members_heros)
	end

	if self.observer and self.observer.OnVMFinished then
		self.observer:OnVMFinished()
	end

	self.observer = nil
end

function VM:PLAYER_STATUS_CHANGE(pid, value, target)
	self:DoCommand({
			type = "PLAYER_STATUS_CHANGE", pid = pid,
			target= target or 0, value = value,
		});
end

function VM:SetFightData(attacker_data, defender_data)
	self.attacker_data = attacker_data;
	self.defender_data = defender_data;
end

function VM:DoFight()
	self:LOG('start fight');

	local winner, err;

	self.player_info =  {}
	self.monster_count = 0;

	for i = 1, 1 do
		if not self:prepareFightData() then
			self:LOG('prepareFightData faield');
			break;
		end

		if not self:CheckReady() then
			winner = 0;
			self:LOG(' player not ready');
			break;
		end

		for _, player in pairs(self.player_info) do
			for _, role in pairs(player.roles) do

				self.sync_id = self.sync_id + 1;
				role.sync_id = self.sync_id;

				self:DoCommand({ type = "MONSTER_ENTER", tick= self.battle:GetTick(), pid = 0, refid = role.refid, sync_id = role.sync_id});
			end
		end

		winner = self:FightLoop();
	end

	self:LOG('finished, winner %s', winner or '<nil>');

	local winner_2 = winner;
	if winner == 1 then winner_2 = 2;
	elseif winner == 2 then winner_2 = 1; end

	self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.FIGHT_FINISHED, {winner   or 0} }, {self.pids[1]});
	self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.FIGHT_FINISHED, {winner_2 or 0} }, {self.pids[2]});

	-- self:PLAYER_STATUS_CHANGE(0, winner or 0, 0);

	self.battle:PushCommand({ type = "PLAYER_STATUS_CHANGE", pid = 0, value = winner or 0, target = 0, })

	self:LOG('notify fight finished');

	self:NotifyPlayerCommand({{ type = "PLAYER_STATUS_CHANGE", pid = 0, value = winner   or 0, target = 0, }}, {self.pids[1]});
    self:NotifyPlayerCommand({{ type = "PLAYER_STATUS_CHANGE", pid = 0, value = winner_2 or 0, target = 0, }}, {self.pids[2]});


	return winner;
end


local INPUT_TIMEOUT = 9999;
local INPUT_TIMEOUT_ONE_HERO = 30;
local INPUT_TIMEOUT_AI = 3;
local PREPARE_TIMEOUT = 30;

function VM:CheckReady(fightID)
	local waiting_pids = {}

	for _, v in pairs(self.player_info) do
		if v.pid > AI_MAX_ID then
			waiting_pids[v.pid] = true;
		else
			self:PLAYER_STATUS_CHANGE(v.pid, 1);
		end
	end

	local start_time = loop.now();

	while true	do
		local pid, cmd, data = self.thread:read_message();
		if cmd == 'STOP' and pid == 0 then
			return false;
		elseif cmd == 'UPDATE' and pid == 0 then
			if loop.now() - start_time > PREPARE_TIMEOUT then
				for _, v in pairs(self.player_info) do
					if waiting_pids[v.pid] then
						self:LOG(string.format('%d is ready, time out', v.pid));
						v.offline = true;
					end
				end
				return true;
			end

			local have_online = false;
			for _, v in pairs(self.player_info) do
				if v.offline then 
					waiting_pids[v.pid] = nil; -- stop waiting fro offline player
				else
					have_online = true;
				end
			end

			if not have_online then
				self:LOG('all player is offline, stop fight');
				return false;
			end

			if not next(waiting_pids) then
				self:LOG('all online player is enter game');
				return true;
			end
		elseif cmd == T.PLAYER_READY then
			self:LOG('%d enter game', pid);
			local info = self.player_info[pid];
			if info then
				self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.PLAYER_READY, pid, data});
				info.ready = data;

				self:PLAYER_STATUS_CHANGE(pid, info.ready and 1 or 0);

				if info.ready then
					waiting_pids[pid] = nil;
				else
					waiting_pids[pid] = true;
				end

				if not next(waiting_pids) then
					self:LOG('all is enter game');
					return true;
				end
			end
		elseif cmd == T.PLAYER_BACK	then
			self:MemberEnter(pid);
		end
	end

	return false;
end

function VM:FightLoop()
	self:LOG('enter fight loop');

	-- self.boss_hp = {};
	while true do
		local pid, cmd, data = self.thread:read_message();
		if cmd == 'STOP' and pid == 0 then
			break;
		elseif cmd == T.PLAYER_READY then
			self:PlayerReadyChangeOnFightLoop(pid, data);
		elseif cmd == 'UPDATE' and pid == 0 then
			-- local winner = self:AIVoteToExit()
			-- if winner then return winner; end

			winner, err = self:Tick();
			if winner then return winner; end
		elseif cmd == T.PLAYER_COMMAND then
			local player = self.player_info[pid]

			local message = decode(data[1], 'FightCommand');
			if not message then
				print('decode command faield');
			else
				for _, cmd in ipairs(message.commands) do
					self:OnClientCommand(pid, cmd);
				end
			end
		elseif cmd == T.PLAYER_BACK	then
			self:MemberEnter(pid);
		elseif cmd == T.VOTE_TO_EXIT then
			local winner = self:VoteToExit(pid, data)
			if winner then return winner; end
		else
			self:LOG('UNKNOWN VM COMMAND pid %d, cmd %s, data %s', pid or 0, cmd or 'nil', tostring(data));
		end
	end

	self:LOG('exit fight loop');
end

function VM:PlayerReadyChangeOnFightLoop(pid, ready)
	print('PlayerReadyChangeOnFightLoop', pid, ready);

	-- sync boss hp and rank to client
	local player = self.player_info[pid];
	if not player then
		return;
	end


	-- local timeout = 0;
	-- if self.waiting_input then timeout = self.waiting_input.time + player.input_timeout  - 1518263653; end

	if ready == 3 then
		self:LOG("player %d become offline", pid);
		player.offline = true;
		return;
	elseif ready == 4 then
		self:LOG("player %d become online", pid);
		player.offline = false;
		self:NotifyPlayerCommand({{
				type="INPUT", refid = timeout, sync_id = 0, skill = 99037,
				target = self.battle:GetTick(),
		}}, {pid});
		return;
	end


	if not ready then
		player.ready = false;
		self:PLAYER_STATUS_CHANGE(pid, 0);
		return;
	end

	player.ready = true;

	if player.waiting_for_ready then
		local commands = self.battle:GetCommandQueue();
		local cached_commands = {}
		for i = player.waiting_for_ready + 1, #commands do
			table.insert(cached_commands, commands[i]);
		end

		print('waiting_for_ready', player.waiting_for_ready);

		player.waiting_for_ready = nil;

		if #cached_commands > 0 then
			table.insert(cached_commands, {
				type="INPUT", refid = timeout, sync_id = 0, skill = 99037, target = self.battle:GetTick(),
			});

			self:NotifyPlayerCommand(cached_commands, {pid});
		end
	end

	self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.PLAYER_READY, pid, ready});
	self:PLAYER_STATUS_CHANGE(pid, 1);
end

function VM:Tick()
	if not next(self.player_info) then
		self:LOG('remove from update list');
		update_list[self.id] = nil;
		return;
	end

	self.battle:Update();

	if self.waiting_input and self.waiting_input.pid then
		local player = self.player_info[self.waiting_input.pid]
	
		local left = self.waiting_input.time + player.input_timeout - loop.now();
		if left < 5 or left % 10 == 0 then
			self:LOG('%d %s waiting for input, left %d sec', player.pid, self.waiting_input.name, left);
		end
	
		local refid, sync_id = self.waiting_input.refid, self.waiting_input.sync_id;

		-- self.waiting_input.time = self.waiting_input.time + 1;

		local player = self.player_info[self.waiting_input.pid];

		if left < -2 then
			self.waiting_input.pid = nil;
			self:DoTimeoutAction(refid, sync_id, player.pid);
		elseif player.auto_input then
			self.waiting_input.pid = nil;
			self:DoAutoAction(refid, sync_id, player.pid);
		end

		self.battle:Update();
	end 

	winner, err = self:CheckWinner();

	if winner then
		return winner, err;
	end
end


function VM:Notify(cmd, msg, pids, check_player_ready)
	for _, pid in ipairs(pids or self.pids) do
		local player = self.player_info[pid]
		local skip = false;
		if player == nil then skip = true; end
		if check_player_ready and not player.ready then skip = true end
		if pid <= AI_MAX_ID then skip = true end

		if not skip then
			local agent = Agent.Get(pid);
			if agent then
				agent:Notify({cmd, msg});
			else
				player.offline = true 
				player.ready = false
			end
		end
	end
end

function VM:prepareFightData()
	self:LOG("prepareFightData");

	local fight_data = {
		id       = self.id,
		attacker = self.attacker_data,
		defender = self.defender_data,
		seed     = math.random(1, 0x7fffffff),
		scene    = self.scene or '18hao',
	}

	for k, pid in ipairs(self.pids) do
		print("!!!!!!!!!!!", k, pid);

		local attacker,err
		if k == 1 then
			attacker = self.attacker_data
		else
			attacker = self.defender_data;
		end

		if not attacker then
			attacker, err = cell.QueryPlayerFightInfo(pid, false, 100 * (k - 1));
			if err then
				log.debug(string.format('  load fight data %d error %s', self.pids[1], err))
				return;
			end
		end

		local info = {pid=pid};

		if k == 1 then
			fight_data.attacker = attacker
		else
			fight_data.defender = attacker 
		end

		info.ready         = false;
		info.finished      = false;
		info.input_timeout = INPUT_TIMEOUT_ONE_HERO;
		if pid < 0xffffffff then
			info.input_timeout = INPUT_TIMEOUT_AI
		end

		info.roles = {}
		info.heros = {}
		for _, v in ipairs(attacker.roles) do
			info.roles[v.refid] = v;
			v.share_mode = 2;

			table.insert(info.heros, v.uuid);
		end

		if not Agent.Get(pid) then
			info.offline = true;
		end

		self.player_info[pid] = info;
	end

	print("----", fight_data.attacker.pid, fight_data.defender.pid);


	local code = encode('FightData', fight_data);
	if code == nil then
		log.debug(string.format('encode fight data failed'));
		self.thread = nil;
		return 
	end

	self.code = code;
	self.battle = battle_loader.New(self, self.pids[1], fight_data);
	self.battle:Start();
	self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.FIGHT_START, {code, {INPUT_TIMEOUT}, {}, 0, {INPUT_TIMEOUT_ONE_HERO}}});

	return true;
end

function VM:CheckWinner()
	return self.battle.game.timeline.winner;
end


function VM:UNIT_INPUT(pid, role)
	self:LOG('UNIT_INPUT %d, %s, refid %d, sync_id %d %s', pid, role.name, role.refid, role.sync_id, tostring(role));

	pid = self.pids[(role.side == 1) and 1 or 2];

	local player = self.player_info[pid]
	if not player then
		return;
	end

	self.waiting_input = self.waiting_input or {pid = pid, time = loop.now()}
	self.waiting_input.pid = pid

	if self.waiting_input.refid ~= role.refid and self.waiting_input.sync_id ~= role.sync_id then
		self.waiting_input.time = loop.now();

		if pid < 0xffffffff then -- AI 随机提前出手
			self.waiting_input.time = loop.now() - math.random(0, INPUT_TIMEOUT_AI * 2)
		end
	end

	self.waiting_input.refid   = role.refid
	self.waiting_input.sync_id = role.sync_id
	self.waiting_input.name    = role.name;
end


function VM:VoteToExit(pid, data)
	self:LOG('%d vote to exit', pid);

	if pid == self.pids[1] then
		return 2
	elseif pid == self.pids[2] then
		return 1;
	end
end

function VM:MemberEnter(pid)
	local info = self.player_info[pid];

	self:LOG('player %d enter', pid);

	if not info then
		self:LOG("player %d enter, but not in fight", pid);
		return;
	end

	info.offline = false;
	info.ready = false;

	local t1, t2 = {INPUT_TIMEOUT}, {INPUT_TIMEOUT_ONE_HERO};
	if self.waiting_input then
		t2[2] = self.waiting_input.time + info.input_timeout;
	end

	info.waiting_for_ready = 0;
	self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.FIGHT_START, {self.code, t1, {}, 0, t2}}, {pid});
end

function VM:MemberLeave(pid)
	local player = self.player_info[pid]
	if not player then
		return
	end

	player.offline = true;
	player.ready = false;
end

return VM;
