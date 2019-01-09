
package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

require "network"

local Thread = require "utils.Thread"
local cell = require "cell"
local Scheduler = require "Scheduler"
local PlayerManager = require "PlayerManager"

local BattleConfig = require "BattleConfig"

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


local VMPlayer = {}

function VMPlayer.New(pid, vm)
	return setmetatable({
		pid = pid, vm = vm,


		total_hurt   = 0,
		total_health = 0,
		total_round  = 0,
		total_dead   = 0,

	}, {__index=VMPlayer});
end

function VMPlayer:OnClientCommand(cmd)
	if not cmd then return; end

	print(self.pid, 'OnClientCommand', cmd.type);
	if cmd.pid and cmd.pid ~= self.pid and cmd.pid ~= 0 then
		print('', 'pid error', cmd.pid, self.pid);
		return;
	end

	if cmd.type == "INPUT" then
		if cmd.skill == 99036 then
			print(self.pid, 'set auto input', cmd.target == 1);
			self.auto_input = (cmd.target == 1);
			self:DoCommand(cmd);
		elseif cmd.skill == 99040 then
			self.battle.game:CleanSleep();
		elseif cmd.skill == 98000 then
			print(self.pid, 'set focus tag', cmd.refid, cmd.sync_id, cmd.target);
			self.vm:AllBattleDoCommand({ type="INPUT", refid = cmd.refid, sync_id = cmd.sync_id, skill = 98000, target = cmd.target})
		elseif self.waiting_input == nil or self.waiting_input.refid ~= cmd.refid or self.waiting_input.sync_id ~= cmd.sync_id then
			if self.waiting_input then
				print('player input error', self.waiting_input.refid, self.waiting_input.sync_id, cmd.refid, cmd.sync_id);
			else
				print('player input error', 'nil');
			end
		
			self:NotifyPlayerCommand({{ type="INPUT", refid = cmd.refid, sync_id = cmd.sync_id,	skill = 99035}})
			return;
		else
			self:DoCommand(cmd);
		end
	else
		print('unknown player command', cmd.type);
	end
end

function VMPlayer:DoCommand(...)
	if self.battle then
		for _, cmd in ipairs({...}) do
			print(self.pid, 'NotifyPlayerCommand', cmd.pid, cmd.tick, cmd.type);
			self.battle:PushCommand(cmd);
		end
	end

	self:NotifyPlayerCommand({...});
end

function VMPlayer:DoAutoAction(refid, sync_id, pid)
	self:DoCommand({
			type="INPUT", pid = pid or self.pid,
			tick = self.battle:GetTick(),
			refid = refid, sync_id = sync_id,
			skill = 0,
			target = 0,
	});
end

function VMPlayer:DoTimeoutAction(refid, sync_id)
	local is_ai = (self.pid <= AI_MAX_ID)
	local cmd = {
		type="INPUT", pid = self.pid,
		tick   = self.battle:GetTick(),
		refid  = refid, sync_id = sync_id,
		skill  = is_ai and 0 or 11,
		target = is_ai and 0 or 1;
	};

	if self.auto_input or is_ai then
		self:DoCommand(cmd);
	else
		print(self.pid, 'set auto input by time', true);
		self.auto_input = true;

		self:DoCommand(cmd, {
				  type="INPUT", pid = self.pid,
				  tick = self.battle:GetTick(),
				  refid = 0, sync_id = 0,
				  skill = 99036,
				  target = 1
		});
	end
end


function VMPlayer:NotifyPlayerCommand(cmds)
	if self.pid <= AI_MAX_ID then return end

	if not self.ready or self.pid <= AI_MAX_ID then
		return;
	end

	for _, cmd in ipairs(cmds) do
		print(self.pid, 'NotifyPlayerCommand', cmd.pid, cmd.tick, cmd.type);
	end

	local code = encode('FightCommand', {commands=cmds});
	self.vm:Notify(Command.NOTIFY_FIGHT_SYNC, {T.PLAYER_COMMAND, {code}}, {self.pid});
end

local VM = {}

local next_vm_id = 0;

function VM.New(pids, observer, fightID, opt)
	local t = {pids = pids, fights = {fightID}, observer = observer, opt = opt or {} }

	t.thread = Thread.Create(VM.Loop);

	t.player_info =  {}

	t.sync_id = 100;

	t = setmetatable(t, {__index=VM})

	t.command_record = {}

	next_vm_id = next_vm_id + 1;
	t.id = next_vm_id;

	t.name = 'TeamFightVM ' .. t.id;

	t.fight_time = loop.now()
	t.fight_id = fightID;

	t.monster_count = 0;
	-- t.hurt_sync_queue = {}

	return t;
end

local function checkLimit(fight_id, pid)
	local result = cell.getPlayer(pid)
	local player = result and result.player or nil;
    if not player then
        log.debug(string.format("TeamFightVM checkLimit fail , player:%d not exist", pid))
        return false
    end

	local fight_cfg = BattleConfig.Get(fight_id)
    if not fight_cfg then
        log.debug(string.format("TeamFightVM checkLimit fail , cannt get fight_cfg for fight:%d", fight_id))
        return false
    end

    if not fight_cfg.depend_level_id then
        log.debug(string.format("TeamFightVM checkLimit fail , level limit for fight:%d not exist", fight_id))
        return true
    end
    return player.level >= fight_cfg.depend_level_id 
end

function VM:Start()
	for _, pid in ipairs(self.pids) do
		local player = PlayerManager.Get(pid);
		if player.vm then
			self:LOG("player %d already in vm %s", pid, player.vm.name);
			return false;
		end
	
		if not checkLimit(self.fight_id, pid) then
			self:LOG("player %d check limit fail", pid)
			return false
		end
	end

	for _, pid in ipairs(self.pids) do
		local player = PlayerManager.Get(pid);
		player.vm = self;
	end

	self.thread:Start(self);
	return true
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

function VM:CalcScore()
	local info = {};

	local total_hurt = 0;
	
	local mvp = nil;
	for k, v in pairs(self.player_info) do
		local cfg = BattleConfig.GetTeamFightScoreConfig(self.score_type, v.level)
		if not cfg then
			log.debug('team_fight_score not found', self.score_type, v.level);
			return;
		end

		local a, b, c = cfg.damage, cfg.health, cfg.dead;

		local score = math.floor((v.total_hurt * a + v.total_health * b ) / v.total_round - c * v.total_dead);

		local rating = #cfg.rating + 1;

		for k, v in ipairs(cfg.rating) do
			if score >= v then
				rating = k;
				break;
			end
		end

		table.insert(info, {pid=v.pid, score=score, rating=rating, total_hurt = v.total_hurt});
		if mvp == nil or info[mvp].total_hurt < v.total_hurt then
			mvp = #info
		end

		total_hurt = total_hurt + v.total_hurt;
	end

	if mvp then
		info[mvp].mvp = true;
	end

	info.total_hurt = total_hurt;

	return info -- [ [pid, scrore, [mvp] ]
end


local score_reward = {
	{ rank = 0, level = {min =   1, max =  50}, drop = 75 },
	{ rank = 0, level = {min =  51, max = 100}, drop = 76 },
	{ rank = 0, level = {min = 101, max = 150}, drop = 77 },
	{ rank = 0, level = {min = 151, max = 200}, drop = 78 },

	{ rank = 1, level = {min =   1, max =  50}, drop = 55 },
	{ rank = 2, level = {min =   1, max =  50}, drop = 56 },
	{ rank = 3, level = {min =   1, max =  50}, drop = 57 },
	{ rank = 4, level = {min =   1, max =  50}, drop = 58 },
	{ rank = 5, level = {min =   1, max =  50}, drop = 59 },
	{ rank = 6, level = {min =   1, max =  50}, drop = 59 },
	{ rank = 7, level = {min =   1, max =  50}, drop = 59 },

	{ rank = 1, level = {min =  51, max = 100}, drop = 60 },
	{ rank = 2, level = {min =  51, max = 100}, drop = 61 },
	{ rank = 3, level = {min =  51, max = 100}, drop = 62 },
	{ rank = 4, level = {min =  51, max = 100}, drop = 63 },
	{ rank = 5, level = {min =  51, max = 100}, drop = 64 },
	{ rank = 6, level = {min =  51, max = 100}, drop = 64 },
	{ rank = 7, level = {min =  51, max = 100}, drop = 64 },


	{ rank = 1, level = {min = 101, max = 150}, drop = 65 },
	{ rank = 2, level = {min = 101, max = 150}, drop = 66 },
	{ rank = 3, level = {min = 101, max = 150}, drop = 67 },
	{ rank = 4, level = {min = 101, max = 150}, drop = 68 },
	{ rank = 5, level = {min = 101, max = 150}, drop = 69 },
	{ rank = 6, level = {min = 101, max = 150}, drop = 69 },
	{ rank = 7, level = {min = 101, max = 150}, drop = 69 },


	{ rank = 1, level = {min = 151, max = 200}, drop = 70 },
	{ rank = 2, level = {min = 151, max = 200}, drop = 71 },
	{ rank = 3, level = {min = 151, max = 200}, drop = 72 },
	{ rank = 4, level = {min = 151, max = 200}, drop = 73 },
	{ rank = 5, level = {min = 151, max = 200}, drop = 74 },
	{ rank = 6, level = {min = 151, max = 200}, drop = 74 },
	{ rank = 7, level = {min = 151, max = 200}, drop = 74 },
}

local function sendScoreReward(scores, player_info)
	for _, v in ipairs(scores or {}) do
		local pid, rating, mvp = v.pid, v.rating, v.mvp
		
		local info = player_info[pid];

		if pid and pid ~= 0 and info then
			local level = info and info.level or 1;

			local drops = {}
			for _, cfg in ipairs(score_reward) do
				if (cfg.rank == v.rating or (cfg.rank == 0 and mvp)) and level >= cfg.level.min and level <= cfg.level.max then
					table.insert(drops, {id=cfg.drop, level=level});
				end
			end

			if #drops > 0 then
				local rewards, ret = cell.sendDropReward(pid, drops, Command.REASON_TEAM_FIGHT_SCORE_REWARD);
				if ret ~= 0 then
					log.debug(string.format("send score reward to %s failed", pid));
				else
					log.debug(string.format("send score reward to %s success", pid));

					local cc = {}
					for _, r in ipairs(rewards) do
						table.insert(cc, {r.type,r.id,r.value});
					end

					local agent = Agent.Get(pid);
					if agent then
						agent:Notify({Command.NOTIFY_FIGHT_REWARD, {Command.FIGHT_REWARD_TYPE_SCORE, cc}});
					end
				end
			end

			if mvp then
                cell.NotifyQuestEvent(pid, {{type = 90, id = 1, count = 1}})
            end
		end
	end
end

function VM:Loop()
	log.debug(string.format('TeamFightVM %s start', tostring(self)));
	self:LOG('start fight thread');

	update_list[self.id] = self;

	local success, winner = true, 0;

	for _, fightID in ipairs(self.fights) do
		-- check ready
		success, winner = pcall(self.DoFight, self, fightID);
		if not success then
			self:LOG(winner);
			winner = 0;
			break;
		end

		if winner ~= 1 then
			break;
		end
	end

	self:LOG('winner ==> %s', winner or 'nil');
	
	update_list[self.id] = nil;

	local members_heros = {}
	local attacker_hp = {}
	local defender_hp = {} 
	local first_access = true
	for _, v in pairs(self.player_info) do
		local player = PlayerManager.Get(v.pid);
		members_heros[v.pid] = v.heros
		player.vm = nil;

		for _, v2 in pairs (v.battle.game.roles) do 
			if v2.refid < 100 then
				table.insert(attacker_hp, {v.pid, v2.refid, v2.hp})
			elseif first_access then
				table.insert(defender_hp, {v.pid, v2.refid, v2.hp})
			end
		end
		first_access = false
	end

	local score = self:CalcScore();

	if winner == 1 then
		sendScoreReward(score, self.player_info);
	end

	if self.observer and self.observer.OnFightFinished then
		log.debug(string.format('TeamFightVM %s OnFightFinished', tostring(self)));
		self.observer:OnFightFinished(winner, self.fight_id, self.fight_time, members_heros, score, attacker_hp, defender_hp);
	end

	if self.observer and self.observer.OnVMFinished then
		log.debug(string.format('TeamFightVM %s OnVMFinished', tostring(self)));
		self.observer:OnVMFinished()
	end

	if winner == 1 then
		for _, v in pairs(self.player_info) do
			local record = v.battle.game:GetEventRecord();
			local list = {}
			for _, v in ipairs(record) do
				table.insert(list, {type = 92, id = v[1], count = v[2]});
			end
			if #list > 0 then
				cell.NotifyQuestEvent(v.pid, list);
			end
		end
	end

	self.observer = nil
	log.debug(string.format('TeamFightVM %s end', tostring(self)));
end

function VM:PLAYER_STATUS_CHANGE(pid, value, target)
	for _, v in pairs(self.player_info) do
		v:DoCommand({
			type = "PLAYER_STATUS_CHANGE", pid = pid,
			target= target or 0, value = value,
		});
	end
end

function VM:SetFightData(attacker_data, defender_data)
	if attacker_data then
		self.attacker_data = self.attacker_data or {}
		for _, v in ipairs(attacker_data) do
			self.attacker_data[v.pid] = v.fight_data
		end
	end

	if defender_data then
		self.defender_data = defender_data;
	end
end

function VM:DoFight(id)
	self:LOG('start fight %d', id);

	local winner, err;

	self.player_info =  {}
	self.monster_count = 0;

	repeat
		self:LOG('enter mode 1');
		self.mode = 1;
		if not self:prepareFightData(id, self.opt.level) then
			winner = 0;
			self:LOG('prepareFightData failed');
			break;
		end

		if not self:CheckReady(fightID) then
			winner = 0;
			self:LOG(' player not ready');
			break;
		end
	
--[[
		-- send player status to client
		for pid, v in pairs(self.player_info) do
			for _, role in pairs(v.roles) do
				self:PLAYER_STATUS_CHANGE(pid, 1, role.pos);
			end
			self:genPlayerMonster(pid);
		end

		winner = self:FightLoop();
		if winner ~= 1 then
			self:LOG('mode winner ~= 1');
			break;
		end
--]]

		self:LOG('enter mode 2');
		self.mode = 2;

		local wave = 0;

		while true do
			wave = wave + 1;

			local have_more_monster = false;

			for _, monster in ipairs(self.defender.roles) do
				if monster.share_mode == 3 and monster.wave == wave then
					have_more_monster = true;
				end

				if monster.share_mode == 2 and monster.wave == wave then
					self.sync_id = self.sync_id + 1;
					monster.sync_id = self.sync_id;
					monster.share_count = 0;

					have_more_monster = true;

					for pid, player in pairs(self.player_info) do
						self.monster_count = self.monster_count + 1;

						self:LOG('add monster refid %d, sync_id %s', pid, monster.refid, monster.sync_id or 'nil');
						self:PlayerAddMonster(pid, monster)
					end
				end
			end

			if not have_more_monster then break end

			winner = self:FightLoop();

			if winner ~= 1 then break; end
		end
	until true

	self:LOG('finished fight %d, winner %s', id, winner or '<nil>');

	local score = self:CalcScore();
	local amfScore = nil;

	-- local total_hurt = score.total_hurt; if total_hurt == 0 then total_hurt = 1; end

	if score then
		amfScore = {}
		for _, v in ipairs(score) do
			table.insert(amfScore,{
				v.pid,
				v.rating,
				v.mvp and true or false,
				math.floor(v.total_hurt),
			});
		end
	end

	self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.FIGHT_FINISHED, {winner or 0, amfScore} });
	self:PLAYER_STATUS_CHANGE(0, winner or 0, 0);

	return winner;
end


local INPUT_TIMEOUT = 60;
local INPUT_TIMEOUT_OFFLINE = 60;
local INPUT_TIMEOUT_ONE_HERO = 9999;
local INPUT_TIMEOUT_AI = 5;
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
				info.ready = data and true or false;

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
			local winner = self:AIVoteToExit()
			if winner then return winner; end

			winner, err = self:Tick();
			if winner then return winner; end
		elseif cmd == T.PLAYER_COMMAND then
			local player = self.player_info[pid]

			local message = decode(data[1], 'FightCommand');
			if not message then
				print('decode command faield');
			else
				for _, cmd in ipairs(message.commands) do
					player:OnClientCommand(cmd);
				end
			end
		elseif cmd == T.MONSTER_ENTER then -- 招怪
			local player = self.player_info[pid]
			if player and player.ready and not player.offline then
				player.battle:Update(nil);
				self:genPlayerMonster(pid, data);
			end
		elseif cmd == T.PLAYER_BACK	then
			self:MemberEnter(pid);
		elseif cmd == T.VOTE_TO_EXIT then
			local winner = self:VoteToExit(pid, data)
			if winner then return winner; end
		elseif cmd == T.KILL_COMMAND then
			local player = self.player_info[pid]
			
			local refid, sync_id, value = data[1], data[2], data[3];

			self:AllBattleDoCommand({type = "MONSTER_HP_CHANGE", pid = 0,
					refid = refid, sync_id = sync_id, value = value});
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


	local timeout = 0;

	if player.waiting_input then timeout = player.waiting_input.time + player.input_timeout  - 1518263653; end

	if ready == 3 then
		self:LOG("player %d become offline", pid);
		player.offline = true;
		return;
	elseif ready == 4 then
		self:LOG("player %d become online", pid);
		player.offline = false;
		if player.ready then
			player:NotifyPlayerCommand({{
					type="INPUT", refid = timeout, sync_id = 0, skill = 99037,
					target = player.battle:GetTick(),
			}});
		end
		return;
	end


	if not ready then
		player.ready = false;

		self:PLAYER_STATUS_CHANGE(pid, 0);
		return;
	end

	player.ready = true;

	player.waiting_for_ready = 0

	if true or player.waiting_for_ready then
		local commands = player.battle:GetCommandQueue();
		local cached_commands = {}
		for i = player.waiting_for_ready + 1, #commands do
			table.insert(cached_commands, commands[i]);
		end

		print('waiting_for_ready', player.waiting_for_ready);

		player.waiting_for_ready = nil;

		if #cached_commands > 0 then

			table.insert(cached_commands, {
				type="INPUT", refid = timeout, sync_id = 0, skill = 99037, target = player.battle:GetTick(),
			});

			player:NotifyPlayerCommand(cached_commands);
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

	local all_is_waiting_for_boss = true;
	local boss_sync_id = 0;

	local have_player = false;
	for _, v in pairs(self.player_info) do
		v.battle:Update();

		if v.waiting_input then
			local left = v.waiting_input.time + v.input_timeout - loop.now();
			if left < 5 or (left % 10) == 0 then 
				self:LOG('%d %s waiting for input, left %d sec', v.pid, v.waiting_input.name, v.waiting_input.time + v.input_timeout - loop.now()); 
			end

			if v.waiting_input.pid then
				if left < -2 then
					v.waiting_input.pid = nil;
					v.waiting_input.is_timeout = true;
					v:DoTimeoutAction(v.waiting_input.refid, v.waiting_input.sync_id);
				elseif v.auto_input then
					v.waiting_input.pid = nil;
					v:DoAutoAction(v.waiting_input.refid, v.waiting_input.sync_id);
				end
				v.battle:Update()
			end

			if left < -INPUT_TIMEOUT then
				self:LOG("fight error, timeout more than", INPUT_TIMEOUT * 2, "sec !");
				return 0
			end
		end

		if next(v.roles) then
			all_is_waiting_for_boss = all_is_waiting_for_boss and v.waiting_boss;
			have_player = true;

			if boss_sync_id ~= 0 and v.waiting_boss and v.waiting_boss.sync_id ~= 0 and v.waiting_boss.sync_id ~= boss_sync_id then
				self:LOG("boss id not match %d/%d", boss_sync_id, v.waiting_boss.sync_id);
			elseif v.waiting_boss then
				boss_sync_id = v.waiting_boss.sync_id;
			end
		end
	end

	if all_is_waiting_for_boss and have_player then
		self:BossAction();
	end


	winner, err = self:CheckWinner();

	if winner then
		return winner, err;
	end
end

function VM:BossAction()
	self:LOG('BossAction');

	local waint_info = {}

	for _, v in pairs(self.player_info) do
		waint_info[v.pid] = v.waiting_boss;
		v.waiting_boss = nil;
	end

	for _, v in pairs(self.player_info) do
		local info = waint_info[v.pid];
		if info then
			-- local skill, target = v.battle:INPUT(info.refid, info.sync_id, "auto");
			-- print('boss -->', info.refid, info.sync_id, skill, target);
			v:DoAutoAction(info.refid, info.sync_id, 0);
		end
	end
end

function VM:Notify(cmd, msg, pids)
	for _, pid in ipairs(pids or self.pids) do
		local player = self.player_info[pid]
		if player and pid > AI_MAX_ID then
			local agent = Agent.Get(pid);
			if agent then
				agent:Notify({cmd, msg});
			else
				player.offline = true;
				player.ready = false;
			end
		end
	end
end

function VM:AllBattleDoCommand(cmd)
	for _, info in pairs(self.player_info) do
		info:DoCommand(cmd);
	end
end

function VM:AddMonster(refid, count)
	local monster = nil;
	for k, v in ipairs(self.defender.roles) do
		if v.refid == refid then
			monster = v;
			break;
		end
	end

	if not monster then
		return ;
	end

	local count = monster.share_count + 1;
	monster.share_count = count

	self:LOG('monster count change refid %d, count %d', monster.refid, count);

	self:AllBattleDoCommand({ type = "MONSTER_COUNT_CHANGE", refid = mode.refid, value = count});
end

function VM:GetMonster(refid)
	for k, v in ipairs(self.defender.roles) do
		if v.refid == refid then
			return v;
		end
	end
end

function VM:PeekMonster(refid)
	if self.mode ~= 1 then return; end -- 只有小怪阶段才可以招怪

	refid = refid or 0;

	local idx;
	if refid == 0 then
		local t = {}
		for k, v in ipairs(self.defender.roles) do
			if v.share_count > 0 and v.share_mode == 1 then
				table.insert(t, k);				

			end
		end

		if #t > 0 then
			idx = t[math.random(1, #t)];
		end
	else
		for k, v in ipairs(self.defender.roles) do
			if v.refid == refid then
				if v.share_count > 0 and v.share_mode == 1 then
					idx = k;
				end
				break;
			end
		end
	end

	if not idx then
		return;
	end

	local count = self.defender.roles[idx].share_count - 1;
	self.defender.roles[idx].share_count = count;

	self:LOG('monster count change refid %d, count %d', monster.refid, count);

	self:AllBattleDoCommand({ type = "MONSTER_COUNT_CHANGE", refid = mode.refid, value = count});

	return self.defender.roles[idx];
end

function VM:PlayerAddMonster(pid, monster) --  refid, sync_id)
	local player = self.player_info[pid]
	if not player then
		return;
	end

	local sync_id = monster.sync_id;

	if not sync_id then
		self.sync_id = self.sync_id + 1;
		sync_id = self.sync_id;
	end

	player.monsters[sync_id] = monster.refid
	player.monster_count = player.monster_count + 1;
	player.monstersID[sync_id] = monster.id;

	-- self:LOG('notify monster enter refid %d, share_count %d, sync_id %d', monster.refid, monster.share_count, pid, sync_id or 0);
	-- self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.MONSTER_ENTER, {monster.refid, monster.share_count, pid, sync_id}});


	self:LOG('player %d add monster refid %d, sync_id %d', pid, monster.refid, sync_id);

	-- self:AllBattleDoCommand({ type = "MONSTER_ENTER", tick=player.battle:GetTick(), pid = pid, refid = monster.refid, sync_id = sync_id});
	self:AllBattleDoCommand({ type = "MONSTER_ENTER", tick= 0, pid = pid, refid = monster.refid, sync_id = sync_id});
end

function VM:GetMonsterLevelAndPosAndWave(refid)
	local defender = self.defender
	for k, v in ipairs(defender.roles) do
		if v.refid == refid then
			return v.level, v.pos, v.wave
		end
	end

	return 0, nil, nil 
end

function VM:MonsterDead(sync_id, pid)
	self:LOG('player %d Monster DEAD, sync_id %d', pid, sync_id or 0);
	local player = self.player_info[pid]	
	if not player then
		return;
	end

	if player.monsters[sync_id] then
		local refid = player.monsters[sync_id];
		player.monster_count = player.monster_count - 1;
		player.monsters[sync_id] = nil;

		local monster_id = player.monstersID[sync_id]
		player.monstersID[sync_id] = nil;

		if self.observer.OnKillMonster then
			local monster_level, monster_pos, monster_wave = self:GetMonsterLevelAndPosAndWave(refid)
			self.observer:OnKillMonster(pid, self.fight_id, self.fight_time, refid, monster_id, player.heros, monster_level, monster_pos, monster_wave)
		end

		if self.monster_count > 0 then
			self.monster_count = self.monster_count - 1;
		end

		local monster = self:GetMonster(refid);

		self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.MONSTER_DEAD, {monster.refid, monster.share_count, player.pid, sync_id}});

		if not next(player.monsters) then
			self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.PLAYER_FINISHED, player.pid});
		end
	else
		self:LOG('monster not exists');
	end

end

function VM:PlayerCharacterDead(pid, refid)
	self:LOG('Character DEAD refid %d', refid);
	local player = self.player_info[pid]	
	if not player then
		return;
	end

	if not player.roles[refid] then
		return;
	end

	local role = player.roles[refid];
	player.roles[refid] = nil;

	self:PLAYER_STATUS_CHANGE(pid, 2, role.pos);

	self:PlayerCheckDead(pid);

	player.total_dead = player.total_dead + 1;	

--[[
	if self.mode ~= 2 then
		self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.FIGHT_FINISHED, 2}, {pid});
	end
--]]
end

function VM:PlayerCheckDead(pid)
	local player = self.player_info[pid]	
	if not player then
		return;
	end

	if not next(player.roles) then
		for k, v in pairs(player.monsters) do
			if self.mode == 1 then -- 只有小怪阶段才返还小怪
				self:LOG('%d return monster %d', pid, v);
				self:AddMonster(v, 1);
			elseif self.mode == 2 then
				-- if self.monster_count > 1 then -- BOSS模式下，最后一个必须战胜才减少
				--	self.monster_count = self.monster_count - 1;
				-- end
			end
		end

		self.monster_count = self.monster_count - player.monster_count;

		player.monsters = {}
		player.monster_count = 0;
		player.monstersID = {}

		player.waiting_input = nil;

		self:PLAYER_STATUS_CHANGE(pid, 2);

		return true;
	end
end

function VM:onPlayerCharacterDead(pid, refid, sync_id)
	log.debug('onPlayerCharacterDead', pid, refid, sync_id);

	local player = self.player_info[pid]
	if not player then
		log.debug(' player not in vm');
		return;
	end

	if player.roles[refid] then
		self:PlayerCharacterDead(pid, refid);
	else
		self:MonsterDead(sync_id, pid)
	end

	for _, info in pairs(self.player_info) do
		if info.waiting_boss and info.waiting_boss.sync_id == sync_id then
			self:LOG(info.pid, 'waiting for boss info changed');
			info.waiting_boss = nil;
		end
	end
end

function VM:prepareFightData(fightID, level)
	self:LOG("prepareFightData %d %s", fightID, level or '-');

	local fightConfig = BattleConfig.Get(fightID);
	local sceneName = '18hao';
	local fight_type = nil;
	local win_type = nil;
	local win_para = nil;
	local duration = nil;

	if fightConfig and fightConfig.scene_bg_id and fightConfig.scene_bg_id ~= "" and fightConfig.scene_bg_id ~= '0' then
		sceneName  = fightConfig.scene_bg_id;
		fight_type = fightConfig.fight_type;
		win_type   = fightConfig.win_type;
		win_para   = fightConfig.win_para;
		duration   = fightConfig.duration;
		self.score_type = fightConfig.score_type;
	end

	for _, pid in pairs(self.pids) do
		self.player_info[pid] = VMPlayer.New(pid, self);
	end

	if not self.defender_data then
		local defender, err = cell.QueryPlayerFightInfo(fightID, true, 100, nil, nil, {level = level, target_fight = fightID});
		if err then
			log.debug(string.format('  load fight data %d error %s', fightID, err))
			return;
		end
		self.defender = defender;
	else	
		self.defender = self.defender_data;
	end

	if #self.defender.roles == 0 then
		log.debug('  defender roles count is zero');
		return;
	end

	for k, v in ipairs(self.defender.roles) do
		if v.share_mode == 1 then
			log.debug(string.format('set %d %d share_count %d', v.refid, v.id, v.share_count));
			--v.share_count = 0 
			self.monster_count = self.monster_count + v.share_count;
		elseif v.share_mode == 2 or v.share_mode == 3 then
			self.sync_id = self.sync_id + 1;
			v.sync_id = self.sync_id;
		else
			v.share_mode = 2;
			self.sync_id = self.sync_id + 1;
			v.sync_id = self.sync_id;
		end

		--add buff
		for k, property in ipairs(v.propertys) do
			if self.buff and self.buff.defender_debuff and self.buff.defender_debuff[property.type] then
				local value = (self.buff.defender_debuff[property.type] > 1) and self.buff.defender_debuff[property.type] or (v.value * self.buff.defender_debuff[property.type])
				property.value = property.value - value 
			end
			if self.buff and self.buff.defender_property_replace and self.buff.defender_property_replace[property.type] then
				property.value = self.buff.defender_property_replace[property.type]
			end
		end
	end

	for _, pid in pairs(self.pids) do
		local attacker, err 
		if self.attacker_data and self.attacker_data[pid] then
			attacker, err = self.attacker_data[pid]
		else	
			attacker, err = cell.QueryPlayerFightInfo(pid, false, 0, nil, nil, {target_fight = fightID});
		end
		if err then
			log.debug(string.format('load fight data of player %d error %s', pid, err))
			return;
		end

		local info = self.player_info[pid] -- VMPlayer.New(pid, self);
		info.roles={}
		info.monsters={}
		info.monster_count = 0
		info.data = attacker
		info.monstersID = {}
		info.heros = {}

		info.level = attacker.level;

		if #attacker.roles == 0 then
			log.debug(string.format(' player %d have no character', pid))
			return;	
		end

		info.summary_info = { 
			pid = pid,
			name = attacker.name,
			level = attacker.level,
			roles = {},
		}

		for k, v in ipairs(attacker.roles) do
			info.roles[v.refid] = v;
			table.insert(info.heros, v.uuid);

			table.insert(info.summary_info.roles, {
				refid      = v.refid,
				pos        = v.pos,
				id         = v.id,
				mode       = v.mode,
				level      = v.level,
				grow_star  = v.grow_star,
				grow_stage = v.grow_stage,
			})

			if self.buff and self.buff.buff_list then
				for property_type, property_value in pairs(self.buff.buff_list or {}) do
					table.insert(v.propertys, {type = property_type, value = property_value})
				end
			end	

			--add buff
			for k, property in ipairs(v.propertys) do
				if self.buff and self.buff.attacker_buff and self.buff.attacker_buff[property.type] then
					local value = (self.buff.attacker_buff[property.type] > 1) and self.buff.attacker_buff[property.type] or (v.value * self.buff.attacker_buff[property.type])
					property.value = property.value + value 
				end
			end
		end

		local fight_data = {
			id = 0,
			attacker = attacker,
			defender = self.defender,
			seed = math.random(1, 0x7fffffff),
			scene = sceneName,
			fight_type = fight_type,
			win_type = win_type,
			win_para = win_para,
			duration = duration,
		}

		local code = encode('FightData', fight_data);
		if code == nil then
			log.debug(string.format('encode fight data failed'));
			self.thread = nil;
			return 
		end


		info.code = code;
		info.fight_data = fight_data;
		info.ready = false;
		info.finished = false;
		info.event_index = 0;
		info.input_timeout = INPUT_TIMEOUT;
		if pid <= AI_MAX_ID then
			info.input_timeout = INPUT_TIMEOUT_AI
		elseif Agent.Get(pid) == nil then
			self:LOG('%d is offline', pid);
			info.offline = true;
			info.input_timeout = INPUT_TIMEOUT_OFFLINE
		end

		self.player_info[pid] = info;
	end


	for _, pid in ipairs(self.pids) do
		self:LOG("send player fight data %d", pid);

		local info = self.player_info[pid];
		local code = info.code
		local pid  = pid;

		info.battle = battle_loader.New(self, pid, info.fight_data);

		info.fight_data = nil;
		-- info.code = nil;

		info.battle:Start();
		info.battle:Update();

		local partner_info = self:FillPartnerInfo(pid);

		self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.FIGHT_START, {code, {INPUT_TIMEOUT}, {}, 0, {INPUT_TIMEOUT_ONE_HERO}, partner_info}}, {pid});
	end

	return true;
end

function VM:genPlayerMonster(pid, refid)
	log.debug('genPlayerMonster', pid, refid);

	local player = self.player_info[pid]
	if not player then
		log.debug(' player not in fight');
		return
	end

	if player.monster_count >= 5 then
		log.debug('  player have more than 5 monster');
		return;
	end

	if not next(player.roles) then
		log.debug('  player is dead');
		return;
	end

	if self.monster_count == 0 then
		log.debug('  no monster left');
		return;
	end

	local monster = self:PeekMonster(refid)
	if not monster then
		log.debug('  peek monster failed');
		return;
	end

	self:PlayerAddMonster(pid, monster);
end

local always_win = false;
local file = io.open("../log/TEAM_FIGHT_DEBUG") 
if file then
	file:close();
	always_win = true;
end

function VM:CheckWinner()
	if always_win then
		return 1;
	end

	local side = {false, false};
	if self.monster_count > 0 then
		side[2] = true;
	end

	for _, v in pairs(self.player_info) do
		if not v.finished then
			return
		end

		if v.monster_count > 0 then
			self[2] = true;
		end

		if next(v.roles) then
			side[1] = true
		end
	end

	if side[1] and side[2] then
		return;
	end

	return side[1] and 1 or 2;
end

function VM:TIMELINE_Enter(pid, role) 
	self:LOG('%d %s Enter, syncid %d', pid, role.name, role.sync_id);
	local player = self.player_info[pid]
	if player and player.waint_info then
		player.waiting_input.time = loop.now();
	end
end

function VM:UNIT_Hurt(pid, role, value)
	self:LOG('%d %s(%d,%d) hurt, hp %d, value %d', pid, role.name, role.refid, role.sync_id, role.hp, value)
	local player = self.player_info[pid];
	if not player then
		self:LOG('  player not in battle');
		return;
	end

	if role.side == 2 then
		player.total_hurt = player.total_hurt + value;
	end

	if role.share_mode == 0 then
		return;
	end

	for _, v in pairs(self.player_info) do
		v:DoCommand({type = "MONSTER_HP_CHANGE",
				tick = v.battle:GetTick(), pid = pid,
				refid = role.refid, sync_id = role.sync_id,
				value = -value});
	end
end

function VM:UNIT_Health(pid, role, value)
	self:LOG('%d %s(%d,%d) health, hp %d, value %d', pid, role.name, role.refid, role.sync_id, role.hp, value)

	local player = self.player_info[pid];
	if not player then
		self:LOG('  player not in battle');
		return;
	end

	if role.side == 1 then
		player.total_health = player.total_health + value;
	end

	if role.share_mode == 0 then
		return
	end

	for _, v in pairs(self.player_info) do
		v:DoCommand({type = "MONSTER_HP_CHANGE", 
				tick = v.battle:GetTick(), pid = pid,
				refid = role.refid, sync_id = role.sync_id,
				value = value});
	end
end

function VM:CreateBullet(pid, from, to, name, cfg)
	if from.side ~= 1 or to.side ~= 2 then
		return;
	end

	local refid, sync_id = from.refid, from.sync_id;
	if from.owner ~= 0 then
		refid, sync_id = from.owner.refid, from.owner.sync_id;
	end

	local to_refid, to_sync_id = to.refid, to.sync_id;
	if to.owner ~= 0 then
		to_refid, to_sync_id = to.owner.refid, to.owner.sync_id;
	end

	for _, v in pairs(self.player_info) do
		if v.pid ~= pid then
			v:DoCommand({type = "INPUT", 
					tick = v.battle:GetTick(), pid = pid,
					refid = refid, sync_id = sync_id,
					skill = 99038,
					target = to_refid, value = to_sync_id});
		end
	end
end

function VM:UNIT_CAST_SKILL(pid, role, skill)
	if role.side ~= 1 or role.owner ~= 0 then
		return
	end

	for _, v in pairs(self.player_info) do
		if v.pid ~= pid then
			v:DoCommand({type = "INPUT", 
					tick = v.battle:GetTick(), pid = pid,
					refid = role.refid, sync_id = role.sync_id,
					skill = 99039, value = skill.icon});
		end
	end
end

function VM:TIMELINE_BeforeAction(pid, role)
	print(pid, role.name, 'BeforeAction');
	if role.side == 1 then
		self:PLAYER_STATUS_CHANGE(pid, 10, role.pos);
	end
end

function VM:TIMELINE_StartAction(pid, role)
	print(pid, role.name, 'StartAction');
	if role.share_mode ~= 2 and role.share_mode ~= 3 then
		return;
	end

	local player = self.player_info[pid]
	if not player then
		return;
	end

	self:PLAYER_STATUS_CHANGE(pid, 11);

	player.waiting_input = nil;
	player.waiting_boss =  {refid = role.refid, sync_id = role.sync_id}
	self:LOG(' %d waiting_boss', pid);
	return;
end


function VM:TIMELINE_AfterAction(pid, role) 
	print(pid, role.name, 'AfterAction');
	if role.side == 1 then
		self:PLAYER_STATUS_CHANGE(pid, 11, role.pos);
	end
end

function VM:TIMELINE_BeforeRound(pid)
	self:LOG('BeforeRound %d', pid);
	local player = self.player_info[pid];
	if player then
		player.waiting_input = { time = loop.now() }
		player.total_round = player.total_round + 1;	

		self:PLAYER_STATUS_CHANGE(pid, 10);
	end
end

function VM:UNIT_INPUT(pid, role)
	self:LOG('UNIT_INPUT %d, %s, refid %d, sync_id %d %s', pid, role.name, role.refid, role.sync_id, tostring(role));

	local player = self.player_info[pid]
	if not player then
		return;
	end

	-- self:LOG('%d, %s refid %d, sync_id %d Start wait for input', pid, role.name, role.refid, role.sync_id);
	if role.share_mode == 2 then
		self:PLAYER_STATUS_CHANGE(pid, 11);

		player.waiting_input = nil;
		player.waiting_boss =  {refid = role.refid, sync_id = role.sync_id}
		self:LOG(' %d waiting_boss', pid);
		return;
	end


	if player.waiting_input and player.waiting_input.is_timeout then
		player:DoTimeoutAction(role.refid, role.sync_id);
		return;
	end

	player.waiting_input = player.waiting_input or {pid = pid, time = loop.now() }

	player.waiting_input.pid  = pid;
	player.waiting_input.name = role.name

	player.waiting_input.refid   = role.refid
	player.waiting_input.sync_id = role.sync_id
end

function VM:TIMELINE_Finished(pid)
	self:LOG('%d finished', pid);
	if self.player_info[pid] then
		self.player_info[pid].finished = true;
	end
end

function VM:UNIT_DEAD(pid, role) 
	-- self:LOG('%d %s DEAD, sync_id %d', pid, role.name, role.sync_id);
	-- self:onPlayerCharacterDead(pid, role.refid, role.sync_id);
end

function VM:TIMELINE_Leave(pid, role)
	self:LOG('%d %s leave from timeline, sync_id %d', pid, role.name, role.sync_id);
	self:onPlayerCharacterDead(pid, role.refid, role.sync_id);
end

function VM:AddStageEffect(pid, _, _, cfg)
	local player = self.player_info[pid]
	if not player then
		return;
	end

	if player.auto_input and cfg.click_skip then
		-- player.battle.game:CleanSleep();
	end
end

function VM:AIVoteToExit()
	if self.vote_to_exit_info and loop.now() - self.vote_to_exit_info.time <= 60 then
		if self.ai_vote_list and #self.ai_vote_list > 0 then
			for _, v in ipairs(self.ai_vote_list) do
				if self.vote_to_exit_info and self.vote_to_exit_info.pids[v.pid] ~= 1 and loop.now() > v.vote_time then
					local winner = self:VoteToExit(v.pid, {1})
					if winner then return winner end
				end
			end			
		else	
			self.ai_vote_list = {}
			for k, v in pairs(self.player_info) do
				if k <= AI_MAX_ID then
					table.insert(self.ai_vote_list, {pid = k, vote_time = loop.now() + math.random(1, 5)})	
				end
			end	
		end
	else
		self.ai_vote_list = nil
	end	
end

function VM:VoteToExit(pid, data)
	self:LOG('%d vote to exit %s', pid, data and data[1] or '-');

	if data[1] == 0 then
		if self.vote_to_exit_info and loop.now() - self.vote_to_exit_info.time <= 60 then
			self.vote_to_exit_info = nil;
			self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.VOTE_TO_EXIT, {0, pid}});
		end
	elseif data[1] == 1 then
		if self.vote_to_exit_info == nil or loop.now() - self.vote_to_exit_info.time > 60 then
			self:LOG("start vote");

			self.vote_to_exit_info = {pids = {}, time = loop.now() }
			local pids = {}
			for k, v in pairs(self.player_info) do
				if v.ready or k <= AI_MAX_ID then
					table.insert(pids, k);	
					self.vote_to_exit_info.pids[k] = true;
				end
			end

			if #pids <= 1 then
				return 2;
			end

			self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.VOTE_TO_EXIT, {3, pids, pid, loop.now() + 60}});
		end

		self.vote_to_exit_info.time = self.vote_to_exit_info.time or loop.now();
		self.vote_to_exit_info.pids[pid] = nil;
		self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.VOTE_TO_EXIT, {1, pid}});

		if not next(self.vote_to_exit_info.pids) then
			self.vote_to_exit_info = nil;
			return 2;
		end

--[[
		local ready = true;
	
		for k, v in pairs(self.player_info) do
			if (not v.offline or k <= AI_MAX_ID) and (self.vote_to_exit_info.pids[k] ~= 1) then
				ready = false;
				break;
			end
		end

		if ready then
			self.vote_to_exit_info = nil;
			return 2;
		end
--]]
	end
end


function VM:FillPartnerInfo(target_pid)
	local t = {};
	for _, pid in ipairs(self.pids) do
		if pid ~= target_pid then
			if self.player_info[pid] then
				local code = encode('FightPlayer', self.player_info[pid].summary_info);
				table.insert(t, code);
			end
		end
	end
	return t;
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
	if info.waiting_input then
		t1[2] = info.waiting_input.time + info.input_timeout;
		t1[3] = info.battle.game.timeline.round;
	end

	local partner_info = self:FillPartnerInfo(pid);

	info.waiting_for_ready = 0;
	self:Notify(Command.NOTIFY_FIGHT_SYNC, {T.FIGHT_START, {info.code, t1, {}, 0, t2, partner_info}}, {pid});
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
