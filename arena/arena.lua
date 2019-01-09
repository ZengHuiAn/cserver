#!../bin/server 

-- init env --
package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";
math.randomseed(os.time());
math.random();

require "log"
require('yqlog_sys')
require('yqmath')
require "cell"
require "AMF"
require "Command"
--require "protos"
require "NetService"
require "printtb"
require "bit32"

--require "ArenaConfigManager"
--require "ArenaEnemyConfigManager"
--require "ArenaPlayerPool"
--require "ArenaFightRecord"
function SGK_Game()
	return XMLConfig.Environment == "xd"	
end

require "ArenaLogic"
local PillageArena = require "PillageArena"
local RankArenaLogic = require "RankArenaLogic"
local PlayerManager = require "RankArenaPlayerManager"

-- func --
local function sendClientRespond(conn, cmd, channel, msg)
	assert(conn);
	assert(cmd);
	assert(channel);
	assert(msg and (table.maxn(msg) >= 2));

	local sid = tonumber(bit32.rshift_long(channel, 32))
	assert(sid > 0)
	local code = AMF.encode(msg);
	if code then conn:sends(1, cmd, channel, sid, code) end
end

local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));		
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

local function onLogin(conn, channel, req)
	log.debug("channel",channel)
	PillageArena.Login(channel)	
	PlayerManager.Login(channel, conn)
end

local function onServiceRegister(conn, channel, req)
	if req.type == "GATEWAY" then
        for k, v in pairs(req.players) do
            -- print(k, v);
            onLogin(conn, v, nil)
        end
    end
end

local function onLogout(conn, channel, req)
	resetPlayerPower(pid)
	PillageArena.Logout(channel)	
end

-- create service --
local cfg = XMLConfig.Social["Arena"];
service = NetService.New(cfg.port, cfg.host, cfg.name or "Arena");
assert(service, "listen on " .. cfg.host .. ":" .. cfg.port .. " failed");

-- basic route  --
service:on("accept", function (client)
	client.sendClientRespond = sendClientRespond;
	log.debug(string.format("Service: client %d connected", client.fd));
end);

service:on("close", function(client)
	log.debug(string.format("Service: client %d closed", client.fd));
end);

service:on(Command.C_LOGIN_REQUEST, function(conn, pid, req)
	onLogin(conn, pid, req)
end);

service:on(Command.C_LOGOUT_REQUEST, function(conn, pid, req)
	onLogout(conn, pid, req)
end);

service:on(Command.S_SERVICE_REGISTER_REQUEST,  onServiceRegister)

service:on(Command.C_ARENA_JOIN_ARENA, process_arena_join_arena)

service:on(Command.C_ARENA_GET_ENEMY_LIST, process_arena_get_enemy_list)

service:on(Command.C_ARENA_UPDATE_FIGHT_RESULT, process_arena_update_fight_result)

service:on(Command.C_ARENA_RESET_ENEMY_LIST_REQUEST, process_arena_reset_enemy_list)

service:on(Command.C_ARENA_INSPIRE_PLAYER_REQUEST, process_arena_inspire_player)

service:on(Command.C_ARENA_DRAW_REWARD_REQUEST, process_arena_draw_reward)

service:on(Command.C_ARENA_QUERY_PLAYER_INFO_REQUEST, process_arena_query_player_info)

service:on(Command.C_ARENA_FIGHT_PREPARE_REQUEST, process_arena_fight_prepare)

PillageArena.RegisterCommand(service)

service:on(Command.S_GET_RANKLIST_REQUEST, "ArenaGetRankListRequest", function (conn, channel, request)
	local protocol = "ArenaGetRankListRespond"
	local cmd = Command.S_GET_RANKLIST_RESPOND
	
	if channel ~= 0 then
		log.info("S_GET_RANKLIST_REQUEST failed, channel ~= 0")
		sendServiceRespond(conn, cmd, channel, protocol, { sn = request.sn or 0, result = Command.RET_PREMISSIONS })
	end
		
	local pillage_arena = PillageArena.Get(getCurrentPeriod())
	if not pillage_arena then
		log.info("S_GET_RANKLIST_REQUEST failed, pillage arena is nil.")	
		sendServiceRespond(conn, cmd, channel, protocol, { sn = request.sn or 0, result = Command.RET_ERROR })
	end
	local rankList = {}
	for lv, rank in pairs(pillage_arena.player_pool) do
		for pid, v in pairs(rank) do
			table.insert(rankList, { pid = pid, level = lv, wealth = v.wealth, name = "" })
		end
	end
	table.sort(rankList, function (i, j)
		return i.wealth > j.wealth
	end)
	local n = request.topcnt
	local j = 1
	local ranks = {}
	for i, v in pairs(rankList) do
		if n > 0 then
			table.insert(ranks, { rank = j, level = v.level, pid = v.pid, name = v.name })
			n = n - 1
			j = j + 1
		end
	end
	local respond = {
		sn = request.sn,
		result = Command.RET_SUCCESS,
		ranks = ranks
	}
	log.debug("S_GET_RANKLIST_REQUEST success.")
	sendServiceRespond(conn, cmd, channel, protocol, respond)
end)

service:on(Command.S_ARENA_ADD_WEALTH_REQUEST, "ArenaAddWealthRequest", add_wealth)

RankArenaLogic.RegisterCommand(service)
