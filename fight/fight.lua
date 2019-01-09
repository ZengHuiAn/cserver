#!../bin/server 

package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

math.randomseed(os.time());
math.random();

require "log"
require "cell"
require "NetService"
require "XMLConfig"
require "protobuf"
local Property = require "Property"

local TeamProxy = require "TeamProxy"

local NpcRoll = require "NpcRoll"
local PlayerTeamFight = require "PlayerTeamFight"
local TeamPlayerNpcRewardPool = require "TeamPlayerNpcRewardPool"
local RollGame = require "RollGame"
local TeamFightActivity = require "TeamFightActivity"
local Bounty = require "Bounty"
local MatchFightVM = require "MatchFightVM"
local AutoFightVM = require "AutoFightVM"
local TeamFightVM = require "TeamFightVM"
local Fish = require "Fish"
local TeamRewardManger = require "TeamReward"
local TeamFightActivityTimeControl = require "TeamFightActivityTimeControl"
local BattleConfig = require "BattleConfig"
local TeamBattleManager = require "TeamBattleManager"
local AutoFightRecord = require "AutoFightRecord"

local ai_debug = false 
function AI_DEBUG_LOG(...)
	if ai_debug then
		log.debug(...)
	end
end


if log.open then
	local l = log.open(XMLConfig.FileDir and XMLConfig.FileDir .. "/fight_%T.log" or "../log/fight_%T.log");
	log.debug    = function(...) l:debug   (...) end;
	log.info     = function(...) l:info   (...)  end;
	log.warning  = function(...) l:warning(...)  end;
	log.error    = function(...) l:error  (...)  end;
end

local function sendClientRespond(conn, cmd, channel, msg)
	assert(conn);
	assert(cmd);
	assert(channel);
	assert(msg and (table.maxn(msg) >= 2));

	local sid = tonumber(bit32.rshift_long(channel, 32))
	assert(sid > 0)

	local code = AMF.encode(msg);
	-- log.debug(string.format("send %d byte to conn %u", string.len(code), conn.fd));
	-- log.debug("sendClientRespond", cmd, string.len(code));

	if code then conn:sends(1, cmd, channel, sid, code) end
end

local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));		
		loop.exit();
		return nil;
	end
	return code;
end

function sendServiceRespond(conn, cmd, channel, protocol, msg)
    local code = encode(protocol, msg);
	local sid = tonumber(bit32.rshift_long(channel, 32))
    if code then
        return conn:sends(2, cmd, channel, sid, code);
    else
        return false;
    end
end

local function decode(code, protocol)
	return protobuf.decode("com.agame.protocol." .. protocol, code);
end

local cfg = XMLConfig.Social["Fight"];
service = NetService.New(cfg.port, cfg.host, cfg.name);
assert(service, "listen on " .. cfg.host .. ":" .. cfg.port .. " failed");

local function onServiceRegister(conn, channel, request)
	if request.type == "GATEWAY" then
		-- for k, v in pairs(request.players) do end
	end
end
	
service:on("accept", function (client)
	client.sendClientRespond = sendClientRespond;
	log.debug(string.format("Service: client %d connected", client.fd));
end);

service:on("close", function(client)
	log.debug(string.format("Service: client %d closed", client.fd));
end);


service:on(Command.C_LOGIN_REQUEST, function(conn, pid, request)
end);

service:on(Command.C_LOGOUT_REQUEST, function(conn, pid, request) 
end);

service:on(Command.S_SERVICE_REGISTER_REQUEST,	onServiceRegister);

local fight_id = 0;
local function next_fight_id() 
	fight_id = fight_id + 1;
	return fight_id;
end

local playerFightInfo = {}

service:on(Command.C_FIGHT_PREPARE_REQUEST, function(conn, pid, request)
	local sn = request[1];
	local target = request[2];
	local npc = request[3] or 0;
	local heros = request[4];
	local assists = request[5];
	
	log.debug(string.format('player %d load fight data of target %d(%s)', pid, target, (npc ~= 0) and "npc" or "player"))

	local attacker, defender, err;
	local scene = "";
	local win_type = 0
	local win_para = 0
	local fight_type = 0
	local duration = 0;

	local starInfo = nil;

	if npc == 0 then
		attacker, err = cell.QueryPlayerFightInfo(pid, false, 0, heros, assists);
		if err then
			log.debug(string.format('load fight data of player %d error %s', pid, err))
			return conn:sendClientRespond(Command.C_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		defender, err = cell.QueryPlayerFightInfo(target, false, 100);
		if err then
			log.debug(string.format('load fight data of target %d(%s) error %s', target, (npc ~= 0) and "npc" or "player", err))
			return conn:sendClientRespond(Command.C_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		scene = "18hao"
	else
		local fight_cfg = BattleConfig.Get(target)
		if fight_cfg then
			local battle_cfg = BattleConfig.GetBattleConfig(fight_cfg.battle_id)
			if not battle_cfg then
				log.debug(string.format('load fight data of player %d vs npc %d battle_cfg is nil', pid, target))
				return conn:sendClientRespond(Command.C_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_ERROR});
			end

			if battle_cfg.team_member > 0 then
				log.debug(string.format('load fight data of player %d vs npc %d team members > 0 ', pid, target))
				return conn:sendClientRespond(Command.C_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_ERROR});
			end
		end

		local fight_data, err = cell.PlayerFightPrepare(pid, target, heros, assists);
		if err then
			log.debug(string.format('load fight data of player %d vs npc %d error %s', pid, target, err))
			return conn:sendClientRespond(Command.C_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_ERROR});
		end
		attacker = fight_data.attacker;
		defender = fight_data.defender;
		scene = fight_data.scene;
		starInfo = fight_data.star;
		win_type = fight_data.win_type;
		win_para = fight_data.win_para;
		fight_type = fight_data.fight_type;
		duration = fight_data.duration;
	end

	local fightData = {
		id = next_fight_id();
		attacker = attacker,
		defender = defender,
		seed = math.random(1, 0x7fffffff),
		scene = scene,
		star = starInfo,
		win_type = win_type;
		win_para = win_para;
		fight_type = fight_type;
		duration = duration;
	}

--[[
	-- don't remove next for loops
	-- print(attacker.name, #attacker.roles);
	for _, role in ipairs(attacker.roles) do
		-- print('', role.mode);
		for _,v in ipairs(role.propertys) do
			local t,v = v.type, v.value
			-- print('', '', v.type, v.value);
		end
	end
--]]

-- [[
	-- print(defender.name, #defender.roles);
	for _, role in ipairs(defender.roles) do
		-- print('', role.mode, role.x, role.y, role.z);
		role.share_mode = 0;
		for _,v in ipairs(role.propertys) do
			local t,v = v.type, v.value
		end
	end
--]]


	local code = encode('FightData', fightData);
	if code == nil then
		log.debug(string.format('encode fight data failed'));
		return conn:sendClientRespond(Command.C_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	playerFightInfo[pid] = fightData;

	return conn:sendClientRespond(Command.C_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_SUCCESS, fightData.id, code});
end);

service:on(Command.C_FIGHT_OPT_REQUEST, function(conn, pid, request)
-- [sn, id, data]
-- C_FIGHT_OPT_RESPOND = 16004  
-- [sn, result]
end)

service:on(Command.C_FIGHT_CHECK_REQUEST, function(conn, pid, request)
-- [sn, id, opt]
-- C_FIGHT_CHECK_RESPOND = 16006 
-- [sn, result, rewards]
	local sn        = request[1];
	local fightid   = request[2] or 0
	local starValue = request[3] or 0;

	local code      = request[4];
	local record    = request[5] or {}

	local input     = decode(code, "FightCommand");

	if not input  then
		log.debug('  input error');
		return conn:sendClientRespond(Command.C_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	
--[[
message FightInput {
	message Operation {
		optional uint32 refid       = 1;
		optional uint32 skill       = 2;
		optional uint32 target      = 3;
	}

	repeated Operation operations  = 1;
}
--]]
	log.debug(string.format('player %d check fight %d', pid, fightid));
	local fightData = playerFightInfo[pid]
	if fightData == nil then
		log.debug('  no fight info');
		return conn:sendClientRespond(Command.C_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	if fightid ~= fightData.id then
		log.debug('  fight info not match', fightid, fightData.id);
		-- return conn:sendClientRespond(Command.C_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	if not fightData.defender.npc then
		-- pvp, pass
		return conn:sendClientRespond(Command.C_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_SUCCESS, 0, {} });
	end


	local finished = false;
	local winner = 1;

--[[
	local battle = battle_load({
		TIMELINE_Finished = function()
			finished = true
			winner = battle.game.timeline.winner
		end,
		UNIT_SKILL_ERROR = function()
			finished = true
			winner = -1
		end
	}, nil, fightData, input_record)



	while not finished do
		battle.game:Tick(1);
	end

	if winner ~= 1 then
		-- TODO: failed
	end
--]]

	local heros = {}
	for _, v in ipairs(fightData.attacker.roles) do
		table.insert(heros, v.uuid);
	end

	local rewards, err = cell.PlayerFightConfirm(pid, fightData.defender.pid, starValue, heros);
	if err then
		log.debug(string.format(' confirm failed', pid, fightData.defender.pid, err))
		return conn:sendClientRespond(Command.C_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	playerFightInfo[pid] = nil;

	local ar = {}
	for k, v in ipairs(rewards) do
		if v.uuid ~= 0 then
			table.insert(ar, {v.type, v.id, v.value, v.uuid});
		else
			table.insert(ar, {v.type, v.id, v.value});
		end
	end

	--quest
	--cell.NotifyQuestEvent(pid, {{type = 4, id = 20, count = 1}})

	local list = {}
	for _, v in ipairs(record) do
		table.insert(list, {type = 92, id = v[1], count = v[2]});
	end
	if #list > 0 then
		cell.NotifyQuestEvent(pid, list);
	end

	return conn:sendClientRespond(Command.C_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_SUCCESS, winner, ar});
end);


service:on(Command.C_FIGHT_PVP_REQUEST, function(conn, pid, request)
	local sn, target = request[1], request[2];

	if target == nil then
		return 
	end

	local vm = MatchFightVM.New(pid, target);

	vm:Start();
end);


-- pvp for other server
local reference_time = 946656000 --2000-01-01
--local next_pvp_fight_id = 0;
local pvp_fight_info = { }

local time_index = 0
local index = 0
function nextFightID()
	local now = loop.now()
	local next_fight_id
	if now == time_index then
		next_fight_id = time_index * 1000 + index	
	else
		index = 0
		time_index = now
		next_fight_id = time_index * 1000 + index
	end

	index = index + 1	
	next_fight_id = next_fight_id + 1;
	return next_fight_id;
end

local function expendRoleData(player)
	if not player then return end;

	for k, role in pairs(player.roles) do
		local property = {}
		for _, v in ipairs(role.propertys) do
			property[v.type] = (property[v.type] or 0) + v.value
			print(role.id, v.type, v.value)
		end
		-- role.Property = Property(property);
	end

	for k, role in ipairs(player.assists) do
		local property = {}
		for _, v in ipairs(role.propertys) do
			property[v.type] = (property[v.type] or 0) + v.value
			print(role.id, v.type, v.value)
		end
		-- role.Property = Property(property);

		for _, v in ipairs(role.assist_skills) do
			print(v.id, v.weight);
		end
	end
end


service:on(Command.S_PVP_FIGHT_PREPARE_REQUEST, 'PVPFightPrepareRequest', function(conn, channel, request)
	local sn, attacker, target, auto, scene = request.sn, request.attacker, request.defender, request.auto, request.scene
	
	expendRoleData(request.attacker_data);
	expendRoleData(request.defender_data);

	--next_pvp_fight_id = next_pvp_fight_id + 1;
	local id = nextFightID()--= loop.now() - reference_time + next_pvp_fight_id;

	if auto then
		local vm = AutoFightVM.New(attacker, target, scene);
		vm:SetFightData(request.attacker_data, request.defender_data);
		local fight_result, attacker_data, defender_data = vm:Fight();
		if fight_result then
			AutoFightRecord.Save(id, fight_result[1], fight_result[2], scene, attacker_data, defender_data)
			sendServiceRespond(conn, Command.S_PVP_FIGHT_PREPARE_RESPOND, channel, 'PVPFightPrepareRespond', { sn = sn, result = Command.RET_SUCCESS, 
				id = id, winner = fight_result[1], seed = fight_result[2], roles = fight_result[3] })
		else
			sendServiceRespond(conn, Command.S_PVP_FIGHT_PREPARE_RESPOND, channel, 'PVPFightPrepareRespond', { sn = sn, result = Command.RET_ERROR})
		end
	else
		local vm = MatchFightVM.New(attacker, target, {
			scene = scene,
			OnFightFinished = function(_, winner, fight_id, fight_time, members_heros)
				pvp_fight_info[id] = { time = loop.now(), winner = winner }
				sendServiceRespond(conn, Command.S_PVP_FIGHT_PREPARE_RESPOND, channel, 'PVPFightPrepareRespond', { sn = sn, result = Command.RET_SUCCESS, id = id, winner = winner})
			end,
		});

		local attacker_data, defender_data;
		if request.attacker_data.pid > 0 then
			attacker_data = request.attacker_data;
		end

		if request.defender_data.pid > 0 then
			defender_data = request.defender_data;
		end

		vm:SetFightData(attacker_data, defender_data);

		-- remove timeout
		for k, v in pairs(pvp_fight_info) do
			if loop.now() - v.time > 600 then
				pvp_fight_info[k] = nil;
			end
		end

		if not vm:Start() then
			sendServiceRespond(conn, Command.S_PVP_FIGHT_PREPARE_RESPOND, channel, 'PVPFightPrepareRespond', { sn = sn, result = Command.RET_ERROR})
		end
	end
end);

--[[
service:on(Command.S_PVP_FIGHT_CHECK_REQUEST, 'PVPFightCheckRequest', function(conn, pid, request)
	local sn, id = request.sn, request.id;

	local info = pvp_fight_info[id];
	pvp_fight_info[id] = nil;

	if info then
		sendServiceRespond(conn, Command.S_PVP_FIGHT_PREPARE_RESPOND, channel, 'PVPFightCheckRespond', { sn = sn, result = Command.RET_ERROR})
	else
		sendServiceRespond(conn, Command.S_PVP_FIGHT_PREPARE_RESPOND, channel, 'PVPFightCheckRespond', { sn = sn, result = Command.RET_SUCCESS, winner = info.winner});
	end
end);
--]]

service:on(Command.S_FIGHT_PREPARE_REQUEST, 'PVEFightPrepareRequest', function(conn, channel, request)
	local sn, pid, target, npc, heros, assists = request.sn, request.attacker, request.target, request.npc, request.heros, request.assists
	
	log.debug(string.format('player %d load fight data of target %d(%s)', pid, target, (npc ~= 0) and "npc" or "player"))
	print("!!!!!!!!!!!!!!!!!!!", pid, target, npc, sprinttb(heros))

	local attacker, defender, err;
	local scene = "";
	local win_type = 0
	local win_para = 0
	local fight_type = 0
	local duration = 0;

	local starInfo = nil;

	if npc == 0 then
		attacker, err = cell.QueryPlayerFightInfo(pid, false, 0, heros, assists);
		if err then
			log.debug(string.format('load fight data of player %d error %s', pid, err))
			return sendServiceRespond(conn, Command.S_FIGHT_PREPARE_RESPOND, channel, 'PVEFightPrepareRespond', { sn = sn, result = Command.RET_ERROR})
		end

		defender, err = cell.QueryPlayerFightInfo(target, false, 100);
		if err then
			log.debug(string.format('load fight data of target %d(%s) error %s', target, (npc ~= 0) and "npc" or "player", err))
			return sendServiceRespond(conn, Command.S_FIGHT_PREPARE_RESPOND, channel, 'PVEFightPrepareRespond', { sn = sn, result = Command.RET_ERROR})
		end

		scene = "18hao"
	else
		local fight_data, err = cell.PlayerFightPrepare(pid, target, heros, assists);
		if err then
			log.debug(string.format('load fight data of player %d vs npc %d error %s', pid, target, err))
			return sendServiceRespond(conn, Command.S_FIGHT_PREPARE_RESPOND, channel, 'PVEFightPrepareRespond', { sn = sn, result = Command.RET_ERROR})
		end
		attacker = fight_data.attacker;
		defender = fight_data.defender;
		scene = fight_data.scene;
		starInfo = fight_data.star;
		win_type = fight_data.win_type;
		win_para = fight_data.win_para;
		fight_type = fight_data.fight_type;
		duration = fight_data.duration;
	end

	local fightData = {
		id = next_fight_id();
		attacker = attacker,
		defender = defender,
		seed = math.random(1, 0x7fffffff),
		scene = scene,
		star = starInfo,
		win_type = win_type;
		win_para = win_para;
		fight_type = fight_type;
		duration = duration;
	}

	local code = encode('FightData', fightData);
	if code == nil then
		log.debug(string.format('encode fight data failed'));
		return sendServiceRespond(conn, Command.S_FIGHT_PREPARE_RESPOND, channel, 'PVEFightPrepareRespond', { sn = sn, result = Command.RET_ERROR})
	end

	playerFightInfo[pid] = fightData;

	return sendServiceRespond(conn, Command.S_FIGHT_PREPARE_RESPOND, channel, 'PVEFightPrepareRespond', { sn = sn, result = Command.RET_SUCCESS, fightID = fightData.id, fightData = code})
end);

service:on(Command.S_FIGHT_CHECK_REQUEST, 'PVEFightCheckRequest', function(conn, channel, request)
	local sn, pid, fightid, starValue, code = request.sn, request.pid, request.fightid, request.starValue, request.code
	local input     = decode(code, "FightCommand");

	if not input  then
		log.debug('  input error');
		return sendServiceRespond(conn, Command.S_FIGHT_CHECK_RESPOND, channel, 'PVEFightCheckRespond', { sn = sn, result = Command.RET_ERROR})
	end
	
	log.debug(string.format('player %d check fight %d', pid, fightid));
	local fightData = playerFightInfo[pid]
	if fightData == nil then
		log.debug('  no fight info');
		return sendServiceRespond(conn, Command.S_FIGHT_CHECK_RESPOND, channel, 'PVEFightCheckRespond', { sn = sn, result = Command.RET_ERROR})
	end

	if fightid ~= fightData.id then
		log.debug('  fight info not match', fightid, fightData.id);
		--return sendServiceRespond(conn, Command.S_FIGHT_CHECK_RESPOND, channel, 'PVEFightCheckRespond', { sn = sn, result = Command.RET_ERROR})
	end

	if not fightData.defender.npc then
		-- pvp, pass
		-- return conn:sendClientRespond(Command.C_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_ERROR});
		return sendServiceRespond(conn, Command.S_FIGHT_CHECK_RESPOND, channel, 'PVEFightCheckRespond', { sn = sn, result = Command.RET_SUCCESS})
	end

	local finished = false;
	local winner = 1;

	local heros = {}
	for _, v in ipairs(fightData.attacker.roles) do
		table.insert(heros, v.uuid);
	end

	local rewards, err = cell.PlayerFightConfirm(pid, fightData.defender.pid, starValue, heros);
	if err then
		log.debug(string.format(' confirm failed', pid, fightData.defender.pid, err))
		return sendServiceRespond(conn, Command.S_FIGHT_CHECK_RESPOND, channel, 'PVEFightCheckRespond', { sn = sn, result = Command.RET_ERROR})
	end

	playerFightInfo[pid] = nil;

	local ar = {}
	for k, v in ipairs(rewards) do
		table.insert(ar, {type = v.type, id = v.id, value = v.value});
	end

	return sendServiceRespond(conn, Command.S_FIGHT_CHECK_RESPOND, channel, 'PVEFightCheckRespond', { sn = sn, result = Command.RET_SUCCESS, winner = winner, rewards = rewards})
end);

service:on(Command.S_TEAM_FIGHT_START_REQUEST, 'TeamFightStartRequest', function(conn, channel, request)
	local sn, pids, fight_id, fight_level, attacker_data, defender_data = request.sn, request.pids, request.fight_id, request.fight_level, request.attacker_data, request.defender_data;
	local vm = TeamFightVM.New(pids, 
		{
			OnFightFinished = function(_, winner, fight_id, fight_time, members_heros, attacker_hp, defender_hp) 
				sendServiceRespond(conn, Command.S_TEAM_FIGHT_START_RESPOND, channel, 'TeamFightStartRespond', { sn = sn, result = Command.RET_SUCCESS, winner = winner, attacker_hp = attacker_hp, defender_hp = defender_hp})
			end
		}, 
		fight_id, {level = fight_level} )
	if attacker_data or defender_data then
		if #attacker_data > 0 then	
			for _, v in pairs(attacker_data) do
				for k, role in pairs(v.fight_data.roles) do
					local property = {}
					for _, v in ipairs(role.propertys) do
						property[v.type] = (property[v.type] or 0) + v.value
					end
					role.Property = Property(property);
				end
			end
		end

		if defender_data.pid > 0 then
			for k, role in pairs(defender_data.roles) do
				local property = {}
				for _, v in ipairs(role.propertys) do
					property[v.type] = (property[v.type] or 0) + v.value
				end
				role.Property = Property(property);
			end
		end

		vm:SetFightData(#attacker_data > 0 and attacker_data or nil, defender_data.pid > 0 and defender_data or nil)
	end
	if not vm:Start() then
		sendServiceRespond(conn, Command.S_TEAM_FIGHT_START_RESPOND, channel, 'TeamFightStartRespond', { sn = sn, result = Command.RET_ERROR})
	end
end);

service:on(Command.C_FIGHT_QUERY_AUTO_FIGHT_RECORD_REQUEST, function(conn, pid, request)
	local sn = request[1]
	local fight_id = request[2]
	
	local fight_data = AutoFightRecord.Query(fight_id)
	if not fight_data then
		return conn:sendClientRespond(Command.C_FIGHT_QUERY_AUTO_FIGHT_RECORD_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	local code = encode('FightData', fight_data);
	if code == nil then
		log.debug(string.format('encode fight data failed'));
		return conn:sendClientRespond(Command.C_FIGHT_QUERY_AUTO_FIGHT_RECORD_RESPOND, pid, {sn, Command.RET_ERROR});
	end
	
	return conn:sendClientRespond(Command.C_FIGHT_QUERY_AUTO_FIGHT_RECORD_RESPOND, pid, {sn, Command.RET_SUCCESS, code});
end);


TeamProxy.registerCommand(service);
NpcRoll.registerCommand(service);
PlayerTeamFight.registerCommand(service);
TeamPlayerNpcRewardPool.registerCommand(service);
RollGame.registerCommand(service);
TeamFightActivity.registerCommand(service);
Bounty.registerCommand(service);
Fish.RegisterCommand(service)
TeamRewardManger.RegisterCommand(service)
TeamFightActivityTimeControl.RegisterCommand(service)
TeamBattleManager.RegisterCommand(service)

local function loadModule(name)
	log.debug("loadModule", name);
	assert(loadfile(name .. ".lua"))(service);
end

loadModule("defend_stronghold")

--[[
local loading = false;
Scheduler.Register(function(t)
	if loading then
		return;
	end
	loading = true;

	assert(coroutine.resume(coroutine.create(function()
		print('start auto fight');

		local vm = AutoFightVM.New(463856567972,463856568089);
		local winner = vm:Fight();
		if not winner then
			print('failed');
			loading = false;
		else
			print('winner', winner);
		end
	end)));
end);
--]]
