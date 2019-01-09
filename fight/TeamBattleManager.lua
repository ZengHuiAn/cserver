local database = require "database"
local TeamBattle = require "TeamBattle"
local TeamProxy = require "TeamProxy"
local TeamActivityConfig = require "TeamActivityConfig"

local TeamBattleManager = {}
local battles = {}

local function Load(teamid)
	local t = {}
	local success, result = database.query("select teamid, battle_id, seed, unix_timestamp(begin_time) as begin_time, unix_timestamp(end_time) as end_time from team_battle where teamid = %d and end_time > %d", teamid, loop.now())
	if success then
		for _, row in ipairs(result) do
			t[row.battle_id] = TeamBattle.Resume(row, TeamBattleManager);
		end
	end

	return t
end

local function Query(teamid, battle_id)
	if not battles[teamid] then
		battles[teamid] = Load(teamid)
	end

	if not battle_id then
		return battles[teamid];
	else
		return battles[teamid][battle_id]
	end
end

local function Add(battle)
	battles[battle.teamid] = battles[battle.teamid] or {}
	battles[battle.teamid][battle.battle] = battle
end

function TeamBattleManager.Query(teamid, battle_id)
	return Query(teamid, battle_id)
end

function TeamBattleManager.Create(teamid, battle_id, begin_time, end_time)
	local battle = TeamBattleManager.Query(teamid, battle_id)
	if battle then
		log.debug(string.format("team %d fail to create battle %d, already exist", teamid, battle_id))
		return false
	end

	battle = TeamBattle.New(teamid, battle_id, begin_time, end_time, TeamBattleManager)
	if not battle then
		return false
	end

	Add(battle)
	return true
end

function TeamBattleManager.OnRemove(battle)
	local teamInfo = battles[battle.teamid]

	if teamInfo and teamInfo[battle.battle] then
		teamInfo[battle.battle] = nil
		if not next(teamInfo) then
			battles[battle.teamid] = nil;
		end
	end
end

TeamProxy.RegisterObserver({
	OnTeamDissolve = function(_, team_id)
		local teamInfo = battles[team_id]
		for battle_id, info in pairs(teamInfo or {}) do
			info:OnTeamDissolve()	
		end
	end
})

function TeamBattleManager.RegisterCommand(service)
	service:on(Command.C_TEAM_BATTLE_QUERY_INFO_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local team = getTeamByPlayer(pid)
		
		log.debug(string.format("player %d begin to query team battle info", pid))
		if not team then
			log.debug(string.format("fail to query team battle info, player %d not has team", pid))
			return conn:sendClientRespond(Command.C_TEAM_BATTLE_QUERY_INFO_RESPOND, pid, {sn, Command.RET_ERROR});
		end
	
		local team_battles = TeamBattleManager.Query(team.id)
		if not team_battles then
			log.debug(string.format("fail to query team battle info, cant get team battles for team %d", team.id))			
			return conn:sendClientRespond(Command.C_TEAM_BATTLE_QUERY_INFO_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local info = {}
		for uuid, team_battle in pairs(team_battles) do
			table.insert(info, team_battle:Info())
		end 	
		print("info >>>>>>>>>>>", sprinttb(info))

		return conn:sendClientRespond(Command.C_TEAM_BATTLE_QUERY_INFO_RESPOND, pid, {sn, Command.RET_SUCCESS, info});
	end);

	service:on(Command.C_TEAM_BATTLE_START_REQUEST, function(conn, pid, request)
		local sn = request[1]
		local battle_id = request[2]

		log.debug(string.format("player %d begin to start team battle %d", pid, battle_id))
		local team = getTeamByPlayer(pid)
		if not team then
			log.debug(string.format("fail to start team battle, player %d not has team", pid))
			return conn:sendClientRespond(Command.C_TEAM_BATTLE_START_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local on_time, begin_time, end_time, dur = TeamActivityConfig.GetTeamActivityTime(battle_id)
		if not on_time then
			log.debug(string.format("fail to start team battle, battle %d not on time", battle_id))
			return conn:sendClientRespond(Command.C_TEAM_BATTLE_START_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local ret = TeamBattleManager.Create(team.id, battle_id, loop.now(), dur == 0 and end_time or (loop.now() + dur))
		return conn:sendClientRespond(Command.C_TEAM_BATTLE_START_RESPOND, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR});
	end);

	service:on(Command.C_TEAM_BATTLE_INTERACT_REQUEST, function(conn, pid, request)
		local sn = request[1]
		local battle_id = request[2]
		local npc_uuid = request[3]
		local option = request[4]

		log.debug(string.format("player %d begin to interact with npc %d in battle %d, option %d", pid, npc_uuid, battle_id, option))
		local team = getTeamByPlayer(pid)
		if not team then
			log.debug(string.format("fail to interact with npc, player %d not has team", pid))
			return conn:sendClientRespond(Command.C_TEAM_BATTLE_INTERACT_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local team_battle = TeamBattleManager.Query(team.id, battle_id)
		if not team_battle then
			log.debug(string.format("fail to interact with npc, cant get team battle %d", battle_id))
			return conn:sendClientRespond(Command.C_TEAM_BATTLE_INTERACT_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		team_battle:Command("INTERACT", pid, npc_uuid, option, conn, sn)
		--return conn:sendClientRespond(Command.C_TEAM_BATTLE_INTERACT_RESPOND, pid, {sn, Command.RET_SUCCESS});
	end);
end

return TeamBattleManager
