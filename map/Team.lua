require "Command"
require "Scheduler"
require "protobuf"
require "Thread"
local Map = require "MapManager"

local ai_debug = true 
function AI_DEBUG_LOG(...)
	if ai_debug then
		log.debug(...)
	end
end

local AI_MAX_ID = 0xffffffff
local player_online = {}

local Agent = require "Agent"
local database = require "database"
local cell = require "cell"
local SocialManager = require "SocialManager"

local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));		
		loop.exit();
		return nil;
	end
	return code;
end

if not log then
	log = {
		debug = function(...) print(...); end
	}
end

local Team = {}

-- teams
local teams = {}
local teamGroups = {}

local function recordTeam(team)
	local group, id = team.group, team.id;

	teams[id] = team;

	teamGroups[group] = teamGroups[group] or {}
	teamGroups[group][id] = team;

	return team;
end

function getTeam(id)
	return id and teams[id];
end

local function getTeamGroup(group)
	return teamGroups[group] or {};
end

local function cleanTeam(id)
	local team = teams[id]
	if team then
		local group = team.group;

		if teamGroups[group] then
			teamGroups[group][id] = nil;
		end

		teams[id] = nil;
	end
end

local function changeTeamGroup(id, old_group, new_group)
	local team = getTeam(id)
	if team then
		if old_group == new_group then
			return 
		end
		teamGroups[old_group][team.id] = nil
		teamGroups[new_group] = teamGroups[new_group] or {}
		teamGroups[new_group][team.id] = team 
	end
end

-- team by player
local teamByPlayer = {}
function getTeamByPlayer(pid)
	return getTeam(teamByPlayer[pid])
end

local function recordTeamOfPlayer(pid, teamid)
	teamByPlayer[pid] = teamid;
end


-- join request
local joinRequest = {};
local function recordJoinRequest(pid, teamid)
	joinRequest[pid] = joinRequest[pid] or {}
	joinRequest[pid][teamid] = true;
end

local function haveJoinRequest(pid, teamid)
	return joinRequest[pid] and joinRequest[pid][teamid];
end

local function cleanJoinRequest(pid, teamid)
	if pid == 0 and teamid then
		for playerid, v in pairs(joinRequest) do
			for teamID, _ in pairs(v) do
				if teamID == teamid then
					local team = getTeam(teamID);		
					team:RemoveJoinRequest(playerid)
					joinRequest[playerid][teamID] = nil
				end	
			end
		end	
		return 
	end

	if not joinRequest[pid] then
		return;
	end

	if teamid then -- remove from on team
		local team = getTeam(teamid);		
		if team then
			team:RemoveJoinRequest(pid);
			joinRequest[pid][teamid] = nil
		end
	else
		for teamid, _ in pairs(joinRequest[pid]) do
			local team = getTeam(teamid);		
			if team then
				team:RemoveJoinRequest(pid);
				joinRequest[pid] = nil
			end
		end
	end
end

local playerFightData = {}
local function getPlayerFightData(pid)
	if playerFightData[pid] == nil or loop.now() - playerFightData[pid].refresh_time > 60 then
		playerFightData[pid] = {}
		playerFightData[pid].refresh_time = loop.now()	
		local attacker, err = cell.QueryPlayerFightInfo(pid, false, 0);
		if err then
			log.debug(string.format('get fight data of player %d error %s', pid, err))
			return "" 
		end

		local code = encode('FightPlayer', attacker);
		playerFightData[pid].code = code
	end 

	return playerFightData[pid].code
end

-- players
local players = {}
function getPlayer(pid, force)
	if not players[pid] or force then
		local result = cell.getPlayer(pid)
		local player = result and result.player or nil;

		players[pid] = { 
			pid = pid,
			_name = player and player.name or "unknown",
			_level = player and player.level or 1,
			fresh_time = loop.now(),
			conn = nil
		};

		setmetatable(players[pid], {__index = function(t, k)
			if (loop.now() - t.fresh_time > 60) and coroutine.running() then
				local result = cell.getPlayer(pid)
				local player = result and result.player or nil

				t._name = player and player.name or t._name --"unknown"
				t._level= player and player.level or t._level --1 

				t.fresh_time = loop.now()
			end 			 

			return rawget(t, "_"..k)
		end})
	end
	return players[pid]
end

-- watch
local watchInfo = {}
local playerWatchGroup = {};
local changedList = {}

local function startWatchTeamList(pid, group)
	local old_group = playerWatchGroup[pid];
	if old_group then
		watchInfo[old_group][pid] = nil;
	end

	playerWatchGroup[pid] = group;

	if group then
		watchInfo[group] = watchInfo[group] or {}
		watchInfo[group][pid] = loop.now() + 60 * 5;
	end
end

local function sendTeamInfoToWatcher(team)
	local msg = { team.id,team.group,#team.members,
		team.leader and team.leader.pid or 0,
		team.leader and team.leader.name or "",
		team.level_lower_limit,
		team.level_upper_limit,
		team:GetMems(),
	}

	for pid, v in pairs(watchInfo[team.group] or {}) do
		if v < loop.now() then
			watchInfo[team.group][pid] = nil
		else
			local agent = Agent.Get(pid);
			if agent then
				agent:Notify({Command.NOTIFY_TEAM_CHANGE, msg});
			end
		end
	end	
end

local function notifyTeamWatcher(team)
	if #team.members == 0 then
		sendTeamInfoToWatcher(team);
		changedList[team.id] = nil;
	elseif not changedList[team.id] then
		-- push to notify after 3 seconds
		print(string.format("team info change notify to watcher team:%d", team.id))
		changedList[team.id] = loop.now();
	end
end

Scheduler.Register(function(t)
	for k, v in pairs(changedList) do
		if t - v >= 3 then
			changedList[k] = nil;
			local team = getTeam(k);
			if team then
				print(string.format("send team %d info to watcher", k))
				sendTeamInfoToWatcher(team);
			end
		end
	end
end);

local function Notify(cmd, pid, msg)
	local agent = Agent.Get(pid);
	if agent then
		agent:Notify({cmd, msg});
	end
end

--invite list by player
local inviteListByPlayer = {}
local INVITE_LIST_INCREASE = 1
local INVITE_LIST_DECREASE = 0 
local function addInviteList(pid, teamid)
	inviteListByPlayer[pid] = inviteListByPlayer[pid] or {} 
	local team = getTeam(teamid)
	if not team then
		log.debug("Player %d fail to addInviteList , team %d not exist", pid, teamid)
	end
	if not inviteListByPlayer[pid][teamid] then
		inviteListByPlayer[pid][teamid] = {
			teamid = team.id,
			group  = team.group,
			leader_id = team.leader.pid,
			leader_name = team.leader.name,
			leader_level = team.leader.level,
		}	
		Notify(Command.NOTIFY_TEAM_PLAYER_INVITE_LIST_CHANGE, pid, {INVITE_LIST_INCREASE, {{team.id, team.group, team.leader.pid, team.leader.name, team.leader.level}}})
	end
end

local function cleanInviteList(pid, teamid)
	if not pid and not teamid then
		return
	end
	if pid and not teamid then
		if inviteListByPlayer[pid] then
			local delete_list = {}
			for k, v in pairs do 
				local team_info = {v.teamid, v.group, v.leader_id, v.leader_name, v.leader_level}
				table.insert(delte_list, team_info)
			end
			if #delete_list > 0 then
				Notify(Command.NOTIFY_TEAM_PLAYER_INVITE_LIST_CHANGE, pid, {INVITE_LIST_DECREASE, delete_list})
			end
			inviteListByPlayer[pid] = nil
		end	
		return
	end
	if not pid and teamid then
		for playerid, v in pairs(inviteListByPlayer) do
			for id, _ in pairs(v) do
				if id == teamid then
					local leader_id = inviteListByPlayer[playerid][id].leader_id
					local leader_name = inviteListByPlayer[playerid][id].leader_name
					local leader_level = inviteListByPlayer[playerid][id].leader_level
					Notify(Command.NOTIFY_TEAM_PLAYER_INVITE_LIST_CHANGE, playerid, {INVITE_LIST_DECREASE, {{inviteListByPlayer[playerid][id].teamid, inviteListByPlayer[playerid][id].group, leader_id, leader_name, leader_level}}})
					inviteListByPlayer[playerid][id] = nil	
				end
			end	
		end
		return
	end
	if pid and teamid then
		if not inviteListByPlayer[pid] or not inviteListByPlayer[pid][teamid] then
			return	
		end
		local leader_id = inviteListByPlayer[pid][teamid].leader_id
		local leader_name = inviteListByPlayer[pid][teamid].leader_name
		local leader_level = inviteListByPlayer[pid][teamid].leader_level
		Notify(Command.NOTIFY_TEAM_PLAYER_INVITE_LIST_CHANGE, pid, {INVITE_LIST_DECREASE, {{inviteListByPlayer[pid][teamid].teamid, inviteListByPlayer[pid][teamid].group, leader_id, leader_name, leader_level}}})
		inviteListByPlayer[pid][teamid] = nil
		return
	end
end

local function hasInvitation(pid, teamid)
	return inviteListByPlayer[pid] and inviteListByPlayer[pid][teamid]
end

local function replyInvitation(pid, teamid, agree)
	log.debug(string.format("Player %d begin to reply invitation from team:%d", pid, teamid))

	if teamid == 0 and agree then
		log.debug(" cannt agree invitation of all team")
		return false
	end

	if teamid == 0 then
		for team_id, v in pairs(inviteListByPlayer[pid] or {}) do
			local team = getTeam(team_id)
			if team and hasInvitation(pid, team_id) then
				team:ProcessInviteList(pid, agree)
			end
		end
		return true
	end
		
	local team = getTeam(teamid)
	if not team then
		log.debug("  dont has this team")
		cleanInviteList(pid, teamid)
		return false
	end

	if not hasInvitation(pid, teamid) then
		log.debug("  dont has invitation")
		return false
	end

	if getTeamByPlayer(pid) and agree then
		log.debug("  already in a team")
		return false
	end

	return team:ProcessInviteList(pid , agree)
end

local function queryInviteList(pid)
	local result = {} 
	for k, v in pairs(inviteListByPlayer[pid] or {}) do
		table.insert(result, {v.teamid, v.group, v.leader_id, v.leader_name, v.leader_level})
	end
	return result
end

-------------new auto match---------------------------------------------
local TeamMatchList = {}
local TeamMatchInfo = {}
local PlayerMatchList = {}
local PlayerMatchInfo = {} 
local AIMatchList = {}
local AIMatchInfo = {}

local function GetAutoMatchTeamCount(group, level)
	print("GetAutoMatchTeamCount for group level", group, level)
	local count = 0
	if level == 0 then
		for lv, v in pairs (TeamMatchList[group] or {}) do
			for teamid, v2 in pairs(v) do
				count = count + 1
			end
		end
	else
		for lv, v in pairs (TeamMatchList[group] or {}) do
			print("team level for group", group, lv)
			if lv >= level - 15 and lv <= level + 15 then
				for teamid, v2 in pairs(v) do
					local team = v2.team
					print(string.format("team %d, mem_count %d", teamid, #team.members))
					if team and #team.members < 5 then
						count = count + 1
					end
				end
			end
		end
	end

	return count
end

local function QueryAutoMatchTeamList()
	local t = {}
	for group, v in pairs(TeamMatchList) do
		for level, v1 in pairs (v) do
			for teamid, v2 in pairs(v1) do
				table.insert(t, {grup = group, teamid = teamid})	
			end
		end
	end

	return t
end

local function AddTeamToMatchList(group, team, level)
	TeamMatchList[group] = TeamMatchList[group] or {}
	TeamMatchList[group][level] = TeamMatchList[group][level] or {}
	TeamMatchList[group][level][team.id] = {team = team, match_time = loop.now()}
	TeamMatchInfo[team.id] = {group = group, level = level} 
end

local function RemoveTeamFromMatchList(team)
	if not team then
		return 
	end

	local info = TeamMatchInfo[team.id]
	if not info then
		return
	end

	local group = info.group
	local level = info.level
	if group and level and TeamMatchList[group] and TeamMatchList[group][level] and TeamMatchList[group][level][team.id] then
		TeamMatchList[group][level][team.id] = nil
		TeamMatchInfo[team.id] = nil
	end
end

local function AddPlayerToMatchList(group, pid, level)
	PlayerMatchList[group] = PlayerMatchList[group] or {}
	PlayerMatchList[group][level] = PlayerMatchList[group][level] or {}
	PlayerMatchList[group][level][pid] = {pid = pid, match_time = loop.now()}
	PlayerMatchInfo[pid] = {group = group, level = level}
	AddToCandidateList(group, pid, level)
end

local function ChangeTeamMatchTime(team, t)
	if not team then
		return 
	end	

	local info = TeamMatchInfo[team.id]
	if not info then
		return
	end

	local group = info.group
	local level = info.level
	if group and level and TeamMatchList[group] and TeamMatchList[group][level] and TeamMatchList[group][level][team.id] then
		TeamMatchList[group][level][team.id].match_time = t
	end
end

local function RemovePlayerFromMatchList(pid)
	if not pid then
		return
	end

	local info = PlayerMatchInfo[pid]
	if not info then
		return
	end
	
	local group = info.group
	local level = info.level
	if group and level and PlayerMatchList[group] and PlayerMatchList[group][level] and PlayerMatchList[group][level][pid] then
		PlayerMatchList[group][level][pid] = nil
		PlayerMatchInfo[pid] = nil
		RemoveFromCandidateList(pid)
	end
end

local function AddAIToMatchList(group, pid, level)
	AIMatchList[group] = AIMatchList[group] or {}
	AIMatchList[group][level] = AIMatchList[group][level] or {}
	AIMatchList[group][level][pid] = {pid = pid, match_time = loop.now()}
	AIMatchInfo[pid] = {group = group, level = level}
	AddToCandidateList(group, pid, level)
end

local function RemoveAIFromMatchList(pid)
	if not pid then
		return
	end

	local info = AIMatchInfo[pid]
	if not info then
		return
	end
	
	local group = info.group
	local level = info.level
	if group and level and AIMatchList[group] and AIMatchList[group][level] and AIMatchList[group][level][pid] then
		AIMatchList[group][level][pid] = nil
		AIMatchInfo[pid] = nil
		RemoveFromCandidateList(pid)
	end
end

local function IsPlayerAutoMatching(pid)
	local info
	if pid <= AI_MAX_ID then
		info = AIMatchInfo[pid] 	
	else
		info = PlayerMatchInfo[pid]
	end	

	if info then
		return true
	else
		return false
	end
end

local function AutoMatch(pid, group)
	log.debug(string.format("Player %d begin to auto match for group %d", pid, group))

	--player cancel auto match
	if group == 0 then
		if pid <= AI_MAX_ID then
			RemoveAIFromMatchList(pid)
		else
			RemovePlayerFromMatchList(pid)
		end
		return true
	end

	if IsPlayerAutoMatching(pid) then
		log.debug("auto match fail, is auto matching")
		return false
	end	

	if getTeamByPlayer(pid) then
		log.debug("auto match fail, already in a team")
		return false 
	end
	
	local player = getPlayer(pid)
	if not player then
		return false
	end

	if pid <= AI_MAX_ID then
		AddAIToMatchList(group, pid, player.level)
	else
		AddPlayerToMatchList(group, pid, player.level)
	end

	return true
end

--候选队长需要的等级
local CandidateList = {}
local CandidateListInfo = {}
function AddToCandidateList(group, pid, level)
	CandidateList[group] = CandidateList[group] or {total_level = 0, total = 0, list = {}}	
	CandidateList[group].list[pid] = {pid = pid, level = level} 
	CandidateList[group].total_level = CandidateList[group].total_level + level
	CandidateList[group].total = CandidateList[group].total + 1
	CandidateListInfo[pid] = {group = group}
end

function RemoveFromCandidateList(pid)
	if not pid then
		return
	end

	local info = CandidateListInfo[pid]
	if not info then	
		return
	end

	local group = info.group
	if group and CandidateList[group] and CandidateList[group].list[pid] then
		CandidateList[group].total_level = CandidateList[group].total_level - CandidateList[group].list[pid].level
		if CandidateList[group].total_level < 0 then
			CandidateList[group].total_level = 0
		end

		CandidateList[group].total = CandidateList[group].total - 1
		if CandidateList[group].total < 0 then
			CandidateList[group].total = 0
		end

		CandidateList[group].list[pid] = nil
		CandidateListInfo[pid] = nil
	end
end

function GetCandidateList(group)
	CandidateList[group] = CandidateList[group] or {total_level = 0, total = 0, list = {}}

	if not next(CandidateList[group].list) then
		for level, v in pairs(PlayerMatchList[group] or {}) do
			for pid, v2 in pairs(v) do
				AddToCandidateList(group, pid, level)
			end	
		end

		for level, v in pairs(AIMatchList[group] or {}) do
			for pid, v2 in pairs(v) do
				AddToCandidateList(group, pid, level)
			end	
		end
	end

	return CandidateList[group]
end

function GetCandidate(group)
	local list = GetCandidateList(group)
	local candidate = 0
	local average_level = 0
	
	if not list then
		return
	end

	local total_level = list.total_level
	local total = list.total
	
	if total_level == 0 or total == 0 then
		return
	end

	average_level = math.ceil(total_level/total)
	local most_near_value = 9999 
	for k, v in pairs(list.list) do
		if math.abs(v.level - average_level) < math.abs(most_near_value - average_level) then
			candidate = v.pid
			most_near_value = v.level
		elseif (math.abs(v.level - average_level) == math.abs(most_near_value - average_level)) and candidate <= AI_MAX_ID then
			candidate = v.pid
		end	
	end

	if candidate == 0 then
		return 
	end

	return candidate, most_near_value
end

local match_co
local active_ai_co
Scheduler.Register(function(t)
	if not match_co then
		match_co = coroutine.create(match_logic)
		assert(coroutine.resume(match_co))
	end

	if not active_ai_co then
		active_ai_co = coroutine.create(active_ai)
	end

	--[[if t % 5 == 0 and match_co and coroutine.status(match_co) == "suspended" then
		log.debug("math co", tostring(match_co))
		assert(coroutine.resume(match_co))
	end--]]

	if t % 10 == 0 and active_ai_co and coroutine.status(active_ai_co) == "suspended" then
		assert(coroutine.resume(active_ai_co))
	end
end)

--[[for i = 1, 1000, 1 do
	AddAIToMatchList(51, i, 30 + i % 90)
end--]]

--获取自动匹配的真实玩家和AI的比例
local function GetRatioOfRealPlayerAndAI(group)
	local real_player_count = 0
	local ai_count = 0;
	for level, v1 in pairs(TeamMatchList[group] or {}) do
		for teamid, v2 in pairs(v1) do
			local team = v2.team
			local match_time = v2.match_time
			if #team.members < team.max_player_count then
				for k, v in ipairs(team.members) do
					if v.pid <= AI_MAX_ID then
						ai_count = ai_count + 1
					else
						real_player_count = real_player_count + 1
					end
				end
			end
		end
	end

	if PlayerMatchList[group] then
		for k, v in pairs(PlayerMatchList[group]) do
			local playerMatchList = PlayerMatchList[group][k]
			for pid, v in pairs(playerMatchList or {}) do
				ai_count = ai_count + 1
			end
		end	
	end

	--从AI匹配
	if not finish_match and AIMatchList[group] then
		for k, v in pairs(AIMatchList[group]) do
			local AIMatchList = AIMatchList[group][k]
			for pid, v in pairs(AIMatchList or {}) do
				real_player_count = real_player_count + 1
			end
		end
	end

	--print("GetRatio   group ai_count   real_player_count", group, ai_count, real_player_count)
	if real_player_count == 0 then
		real_player_count = 1
	end

	return ai_count / real_player_count
end

local function match_player(team_list, group, level, remove_list)
	for _, v in ipairs(team_list) do
		local team = v.team
		local match_time = v.match_time
		
		if #team.members < team.max_player_count then
			local step = math.ceil((loop.now() - match_time) / 30) * 5
			if step > 30 then
				step = 30
			end

			--print("step>>>>>>>>>>>>>", step)
			local lower = level - step
			if lower < 0 then
				lower = 1
			end
			if team.level_lower_limit ~= 0 then
				lower = math.max(team.level_lower_limit, lower)
			end

			local upper = level + step
			if team.level_upper_limit ~= 0 then
				upper = math.min(team.level_upper_limit, upper)
			end

			local finish_match = false
			--先从真实玩家匹配
			if PlayerMatchList[group] then
				for i = upper, lower, -1 do
					local playerMatchList = PlayerMatchList[group][i]
					for pid, v in pairs(playerMatchList or {}) do
						if not v.has_remove and team:Enter(pid) then
							table.insert(remove_list, pid)
							v.has_remove = true
						end

						if #team.members >= team.max_player_count then
							finish_match = true
							break
						end
					end

					if finish_match then
						break
					end
				end	
			end

			--从AI匹配
			if not finish_match and AIMatchList[group] then
				for i = upper, lower, -1 do
					local AIMatchList = AIMatchList[group][i]
					for pid, v in pairs(AIMatchList or {}) do
						if not v.has_remove and team:Enter(pid) then
							table.insert(remove_list, pid)
							v.has_remove = true
						end

						if #team.members >= team.max_player_count then
							finish_match = true
							break
						end
					end

					if finish_match then
						break
					end
				end
			end
		end
	end
end

function match_logic(t)
	while true do
		--local begin = os.clock()
		--队伍匹配
		local remove_list = {}
		local player_team_list = {}
		local ai_team_list = {}
		local team_match_size = 0
		for group, v in pairs(TeamMatchList) do
			for level, v1 in pairs(v) do
				local player_team_list = {}
				local ai_team_list = {}
				for teamid, v2 in pairs(v1) do
					local team = v2.team 
					if team then
						if v2.team.leader.pid <= AI_MAX_ID then
							table.insert(ai_team_list, {team = v2.team, match_time = v2.match_time, mem_count = #team.members})
						else
							table.insert(player_team_list, {team = v2.team, match_time = v2.match_time, mem_count = #team.members})
						end
					end
				end
				
				team_match_size = team_match_size + 1
				table.sort(player_team_list, function(a, b)
					if a.mem_count ~= b.mem_count then
						return a.mem_count > b.mem_count
					end
				end)

				table.sort(ai_team_list, function(a, b)
					if a.mem_count ~= b.mem_count then
						return a.mem_count > b.mem_count
					end
				end)

				match_player(player_team_list, group, level, remove_list)
				match_player(ai_team_list, group, level, remove_list)
			end
		end
		
		for _, pid in ipairs(remove_list) do
			if pid <= AI_MAX_ID then
				RemoveAIFromMatchList(pid)
			else
				RemovePlayerFromMatchList(pid)
			end
		end

		remove_list = {}

		--个人匹配
		local groups = {}
		for group, v in pairs(PlayerMatchList) do
			if not groups[group] then
				groups[group] = true	
			end
		end

		for group, v in pairs(AIMatchList) do
			if not groups[group] then
				groups[group] = true	
			end
		end
	
		for group, _ in pairs(groups) do
			local candidate, level = GetCandidate(group)
			--print("candidate  level >>>>>>>>>>>>>>>>>>>>>>>>", candidate, level)
			if candidate then
				local auto_match_success = false 
				for step = 5, 20, 5 do
					if auto_match_success then
						break
					end

					local mems = {}

					local lower = level - step
					if lower < 0 then
						lower = 1
					end
					local upper = level + step

					local finish_match = false
					--先从真实玩家匹配
					if PlayerMatchList[group] then
						for i = upper, lower, -1 do
							local playerMatchList = PlayerMatchList[group][i]
							for pid, v in pairs(playerMatchList or {}) do
								if pid ~= candidate then
									table.insert(mems, playerMatchList[pid])	
								end

								if #mems >= 5 then
									finish_match = true
									break
								end
							end

							if finish_match then
								break
							end
						end	
					end

					--从AI匹配
					if not finish_match and AIMatchList[group] then
						for i = upper, lower, -1 do
							local aiMatchList = AIMatchList[group][i]
							for pid, v in pairs(aiMatchList or {}) do
								if pid ~= candidate then
									table.insert(mems, aiMatchList[pid])	
								end

								if #mems >= 5 then
									finish_match = true
									break
								end	
							end

							if finish_match then
								break
							end
						end
					end
							
					if #mems >= 2 then
						local team = Team.Create(group)				
						if team then
							team:Enter(candidate)
							table.insert(remove_list, candidate)
							team:AutoMatch(true, candidate)
						end
						for pid, v in ipairs(mems) do
							team:Enter(v.pid)	
							table.insert(remove_list, v.pid)
						end
						auto_match_success = true
					end
				end

				if not auto_match_success then
					RemoveFromCandidateList(candidate)
				end
			end
		end

		for _, pid in ipairs(remove_list) do
			if pid <= AI_MAX_ID then
				RemoveAIFromMatchList(pid)
			else
				RemovePlayerFromMatchList(pid)
			end
		end
		local end_time = os.clock()
		--print("calc time >>>>>>>>>>", end_time - begin)
		--coroutine.yield()
		Sleep(5)
	end
end

local MASK_GROUP = 999
function active_ai(t)
	while true do
		local begin = os.clock()
		--print("active_ai >>>>>>>>>>>>>")
		local count_auto_match = {}
		--队伍匹配
		for group, v in pairs(TeamMatchList) do
			count_auto_match[group] = count_auto_match[group] or {}
			for level, v1 in pairs(v) do
				count_auto_match[group][level] = count_auto_match[group][level] or {count = 0, has_player_auto_match = false}
				for teamid, v2 in pairs(v1) do
					local team = v2.team
					local match_time = v2.match_time
					if #team.members < team.max_player_count then
						count_auto_match[group][level].count = count_auto_match[group][level].count + 1
						if team:HasRealMember() then
							count_auto_match[group][level].has_player_auto_match = true
						end
					end
				end
			end
		end
		
		--个人匹配
		local groups = {}
		for group, v in pairs(PlayerMatchList) do
			count_auto_match[group] = count_auto_match[group] or {}
			for level, v1 in pairs(v) do
				count_auto_match[group][level] = count_auto_match[group][level] or {count = 0, has_player_auto_match = false}
				for pid, v2 in pairs(v1) do
					count_auto_match[group][level].count = count_auto_match[group][level].count + 1
					count_auto_match[group][level].has_player_auto_match = true
				end
			end	
		end

		for group, v in pairs(AIMatchList) do
			count_auto_match[group] = count_auto_match[group] or {}
			for level, v1 in pairs(v) do
				count_auto_match[group][level] = count_auto_match[group][level] or {count = 0, has_player_auto_match = false}
				for pid, v2 in pairs(v1) do
					count_auto_match[group][level].count = count_auto_match[group][level].count + 1
					--count_auto_match[group][level].has_player_auto_match = true
				end
			end
		end

		for group , v in pairs(count_auto_match) do
			for level, v1 in pairs(v) do
				if v1.count < 5 and v1.has_player_auto_match then
					local lower = level - 5
					if lower < 0 then
						lower = 1
					end
					local upper = level + 5

					local total = 0
					for i = lower, upper, 1 do
						if v[i] then
							total = total + v[i].count  	
							if total >= 5 then
								break
							end
						end
					end

					if total < 5 then
						if group ~= MASK_GROUP then
							print(string.format("Notify ai service to create ai level:%d group:%d  left_count %d", level, group, 5 - total))
							SocialManager.NotifyToActiveAI(level, group)
						end
					end
				end
			end
		end

		coroutine.yield()
	end	
end

-----------------------------------------------------------------------------------------------------------------




-- reward pos
local rewardPos = {}
local function nextRewardPos(teamid, pid, fight_id)
	rewardPos[teamid] = rewardPos[teamid] or {}
	rewardPos[teamid][pid] = rewardPos[teamid][pid] or {}
	rewardPos[teamid][pid][fight_id] = rewardPos[teamid][pid][fight_id] and rewardPos[teamid][pid][fight_id] + 1 or 1
	return rewardPos[teamid][pid][fight_id]
end

local function updateRewardPos(teamid, pid, fight_id, pos)
	rewardPos[teamid] = rewardPos[teamid] or {}
	rewardPos[teamid][pid] = rewardPos[teamid][pid] or {}
	if not rewardPos[teamid][pid][fight_id] or pos > rewardPos[teamid][pid][fight_id] then
		rewardPos[teamid][pid][fight_id] = pos
		return
	end 
end

local function resetRewardPos(teamid, pid, fight_id)
	if fight_id == 0 and rewardPos[teamid] and rewardPos[teamid][pid] then
		rewardPos[teamid][pid] = nil			
		return
	end
	if rewardPos[teamid] and rewardPos[teamid][pid] and rewardPos[teamid][pid][fight_id] then
		rewardPos[teamid][pid][fight_id] = 0
	end
end

--load all team info
local MEM_STAT_INIT = 0
local MEM_STAT_AFK = 1 
local function loadAllTeamInfo()
	local success, result = database.query("select * from team_members");
	if success then
		for _, row in ipairs(result) do
		
			local members = {}
			local next_pos_id = 0
			for i = 1, 5, 1 do
				if row["mem"..i] ~= 0 then
					next_pos_id = next_pos_id + 1	
					local mem = {pid = row["mem"..i], player = {pid = row["mem"..i]}, pos = next_pos_id}
					table.insert(members, mem);
					setmetatable(mem.player, {__index = function(t, k) 
						if k ~= "pid" then
							local pid = t.pid
							local player = getPlayer(pid)
							rawset(t, "player", player)
							return player[k]
						end
					end})
					if row["mem"..i] == row.leader then
						leader_index = #members
					end
				end	
			end

			local mem_stat = {}
			for _, v in ipairs(members) do
				mem_stat[v.pid] = MEM_STAT_INIT
			end

			local afk_list = {}
			for i = 1, 5, 1 do
				if row["afk_mem"..i] ~= 0 then
					table.insert(afk_list, row["afk_mem"..i])
					mem_stat[row["afk_mem"..i]] = MEM_STAT_AFK
				end	
			end

			local team = setmetatable({
			group = row.group,
			id = row.id,

			next_pos_id = next_pos_id,
			max_player_count = 5,
			team_status = 0,

			auto_confirm = false,
			auto_match = false,

			leader = {pid = row.leader},

			members = members,
			npc_reward = {},
			waiting = {},
			apply_info = {},

			level_lower_limit = row.level_lower_limit,
			level_upper_limit = row.level_upper_limit,
		
			mem_stat = mem_stat,
			afk_list = afk_list,

			}, {__index=Team});

			local function loadLeaderInfo(leader_id)		
				for k, v in ipairs(team.members) do
					if leader_id == v.pid then
						team.leader = v.player
						return v.player
					end
				end
				team.leader = {pid = team.leader.pid}
			end

			setmetatable(team.leader, {__index = function(t, k) 
				loadLeaderInfo(t.pid)
				return team.leader[k]	
			end}) 
		
			recordTeam(team);
			for k, v in ipairs(team.members) do
				recordTeamOfPlayer(v.pid, team.id)
			end

			if row.leader <= 100000 then
				team.need_to_be_dissolved = true
			end
		end
	end
end

loadAllTeamInfo()

local function addDBTeamInfo(team)
	return database.update("insert into team_members(id, `group`, leader, mem1, mem2, mem3, mem4, mem5, level_lower_limit, level_upper_limit, afk_mem1, afk_mem2, afk_mem3, afk_mem4, afk_mem5) values(%d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d)", team.id, team.group, 0, team.members[1] and team.members[1].pid or 0, team.members[2] and team.members[2].pid or 0, team.members[3] and team.members[3].pid or 0, team.members[4] and team.members[4].pid or 0, team.members[5] and team.members[5].pid or 0, team.level_lower_limit, team.level_upper_limit, team.afk_list[1] or 0, team.afk_list[2] or 0, team.afk_list[3] or 0, team.afk_list[4] or 0, team.afk_list[5] or 0)
end

local function updateDBTeamInfo(teamid, key, value)
	return database.update("update team_members set `%s` = %d where id = %d ", key, value, teamid)
end

local function updateDBTeamMem(team)
	--log.debug("update db for team_members", #team.members, team.members[1] and team.members[1].pid or 0, team.members[2] and team.members[2].pid or 0, team.members[3] and team.members[3].pid or 0, team.members[4] and team.members[4].pid or 0, team.members[5] and team.members[5].pid or 0 )
	return database.update("update team_members set mem1 = %d, mem2 = %d, mem3 = %d, mem4 = %d, mem5 = %d where id = %d", team.members[1] and team.members[1].pid or 0, team.members[2] and team.members[2].pid or 0, team.members[3] and team.members[3].pid or 0, team.members[4] and team.members[4].pid or 0, team.members[5] and team.members[5].pid or 0, team.id )
end

local function updateDBTeamAFKMem(team)
	return database.update("update team_members set afk_mem1 = %d, afk_mem2 = %d, afk_mem3 = %d, afk_mem4 = %d, afk_mem5 = %d where id = %d", team.afk_list[1] or 0, team.afk_list[2] or 0, team.afk_list[3] or 0, team.afk_list[4] or 0, team.afk_list[5] or 0, team.id)
end


local function deleteDBTeamInfo(teamid)
	return database.update("delete from team_members where id = %d", teamid)
end

-- team implement
--local next_team_id = 0;

local time_index = 0
local index = 0

function nextTeamID()
	local now = os.time()
	local next_team_id
	if now == time_index then
		next_team_id = time_index * 1000 + index	
	else
		index = 0
		time_index = now
		next_team_id = time_index * 1000 + index
	end

	index = index + 1	
	next_team_id = next_team_id + 1;
	return next_team_id;
end

local INVITE_STAT_HAS_INVITED = 1

function Team.Create(group, pid)
	local id = nextTeamID();
	log.debug(string.format("team %d-%d is created", group, id));

	--[[if not checkLimit(group, pid) then
		log.debug(string.format("Player %d fail to Create team, checkLimit fail", pid))
		return
	end--]]

	local team = setmetatable({
		group = group,
		id = id,

		next_pos_id = 0,
		max_player_count = 5,
		team_status = 0,

		auto_confirm = false,
		auto_match = false,

		leader = nil,

		members = {},
		waiting = {},
		npc_reward = {},
		apply_info = {},
		level_lower_limit = 0,
		level_upper_limit = 0,
		--invite  = {},
		mem_stat = {},
		afk_list = {},
	}, {__index=Team});

	addDBTeamInfo(team)
	return recordTeam(team);
end

function Team:Notify(cmd, msg, pids, include_afk_mem)
	local map = nil;
	if pids and #pids > 0 then
		map = {};
		for _, v in ipairs(pids) do
			table.insert(map, {pid=v});
			map[v] = true;
		end
	end

	for _, v in ipairs(map or self.members) do
		local agent = Agent.Get(v.pid);
		if agent then
			if not map then
				if include_afk_mem then
					agent:Notify({cmd, msg});
				elseif not self:PlayerAFK(v.pid) then
					agent:Notify({cmd, msg});
				end
			else
				agent:Notify({cmd, msg});
			end
		else
			print('team member agent not exists', v.pid, cmd);
		end
	end
end

function Team:PlayerIndex(pid)
	for k, v in ipairs(self.members) do
		if v.pid == pid then
			return k, v.player;
		end
	end
end

function Team:RemoveJoinRequest(pid)
	if pid == 0 then
		self.waiting = {};
	else
		self.waiting[pid] = nil;
	end
end

function Team:GetAIMembers()
	local ai = {}
	for k, v in ipairs (self.members) do
		if v.pid <= AI_MAX_ID then
			table.insert(ai, v.pid)	
		end
	end

	return ai
end

function Team:HasRealMember()
	for k, v in ipairs (self.members) do
		if v.pid > AI_MAX_ID then
			return true	
		end
	end

	return false
end

function Team:Enter(pid)
	local co = coroutine.running()
	assert(co, "team enter must in a thread")
	self.waiting_queue = self.waiting_queue or {}
	table.insert(self.waiting_queue, co)
	if #self.waiting_queue >= 2 then
		coroutine.yield()
	end

	local ret, err = self:_Enter(pid)
	table.remove(self.waiting_queue, 1)
	local waiting_co = self.waiting_queue[1]
	if waiting_co then
		local success, info = coroutine.resume(waiting_co)	
		if not success then
			log.error("player fail to enter team ,start coroutine error: " .. info);
		end
	end

	return ret, err
end

function Team:_Enter(pid)
	-- load player info
	
	log.debug(string.format("player %d enter team %d-%d", pid, self.group, self.id));
	local player = getPlayer(pid);
	if player == nil then
		log.debug("  get player failed")
		return false, Command.RET_ERROR;
	end

	if self:PlayerIndex(pid) then
		log.debug("  player already in the team")
		return true, Command.RET_EXIST;
	end

	if #self.members >= self.max_player_count then
		log.debug("  team is full");
		return false, Command.RET_FULL;
	end

	local code = getPlayerFightData(pid)

	self.next_pos_id = self.next_pos_id + 1;
	table.insert(self.members, { pid = pid, pos = self.next_pos_id, player = player });
	updateDBTeamMem(self)

	if not self.leader then
		self.auto_confirm = false;
		self.leader = player;
		log.debug(string.format('team %d-%d leader change to %d', self.group, self.id, self.leader.pid));
		notifyTeamWatcher(self);
		updateDBTeamInfo(self.id, "leader", self.leader.pid)
	end

	recordTeamOfPlayer(pid, self.id);
	cleanJoinRequest(pid, self.id);

	-- notify
	self:Notify(Command.NOTIFY_TEAM_PLAYER_JOIN, {pid, self.next_pos_id, player.level, player.name, code})
	Map.Sync(self.leader.pid, {1, {self.leader.pid, self:GetMems(), self.id}})
	if (self.leader.pid ~= pid) then
		Map.RemoveObject(pid)
	end

	local AI_members = self:GetAIMembers()
	for _, id  in ipairs(AI_members or {}) do
		local index, player = self:PlayerIndex(pid)
		print(string.format("Notify AI %d player %d enter team", id, pid))
		SocialManager.NotifyAITeamPlayerEnter(id, self.id, pid, player.level)
	end

	if #self.members >= self.max_player_count then
		self:AutoMatch(false, self.leader.pid)
	end

	self:ChangeMemStat(pid, MEM_STAT_INIT)
	
	return true;
end

function Team:GetMems()
	local mems = {}
	for k, v in ipairs(self.members or {}) do
		table.insert(mems, v.pid)
	end

	return mems
end

function Team:Leave(pid, opt_pid)
	log.debug(string.format("player %d leave team %d-%d", pid, self.group, self.id));
	local index, player = self:PlayerIndex(pid);
	if index == nil then
		log.debug("  player not in team");
		return true;
	end

	local new_leader_pid = 0;
	local old_leader_pid = 0;
	local old_member_count = #self.members
	if self.leader.pid == pid then
		-- find new leader
		--self.auto_confirm = true;
		old_leader_pid = self.leader.pid
		local old_leader = self.leader
		self.leader = nil;
		for _, v in ipairs(self.members) do
			if v.player.pid ~= pid and not self:PlayerAFK(v.player.pid) then
				self.leader = v.player;
				new_leader_pid = self.leader.pid
				log.debug(string.format('team %d-%d leader change form %d to %d', self.group, self.id, pid, self.leader.pid));
				updateDBTeamInfo(self.id, "leader", self.leader.pid)
				break;
			end
		end

		if #self.members > 1 and new_leader_pid == 0 then
			log.debug("all member afk, so dissolve team")
			self.leader = old_leader
			return self:Dissolve(pid)
		end
	end

	-- notify leader change
	if new_leader_pid ~= 0 then
		self:Notify(Command.NOTIFY_TEAM_CHANGE_LEADER, {new_leader_pid, self.auto_confirm})
		local pos = Map.GetPos(old_leader_pid)
		Map.ReplaceObject(old_leader_pid, new_leader_pid)

		local ai_members = self:GetAIMembers()
		for _, id  in ipairs(ai_members or {}) do
			SocialManager.NotifyAITeamLeaderChange(id, new_leader_pid, pos and pos[2] or 0, pos and pos[3] or 0, pos and pos[4] or 0, pos and pos[1] or 0, pos and pos[5] or 0, pos and pos[6] or 0)
		end
	end

	local AI_members = self:GetAIMembers()
	local pos 
	if self.leader then
		pos = Map.GetPos(self.leader.pid)
	end
	for _, id  in ipairs(AI_members or {}) do
		if pos then
			print("player leave, leader pos", sprinttb(pos))
			SocialManager.NotifyAITeamPlayerLeave(id, self.id, pid, opt_pid or pid, pos and pos[2] or 0, pos and pos[3] or 0, pos and pos[4] or 0, pos and pos[1] or 0, pos and pos[5] or 0, pos and pos[6] or 0)
		else
			SocialManager.NotifyAITeamPlayerLeave(id, self.id, pid, opt_pid or pid)
		end
	end

	local player_afk, idx = self:PlayerAFK(pid)
	if player_afk then
		table.remove(self.afk_list, idx)
		self:ChangeMemStat(pid, MEM_STAT_INIT)
		updateDBTeamAFKMem(self)
		self.mem_stat[pid] = nil 
	end
	
	-- notify player leave
	self:Notify(Command.NOTIFY_TEAM_PLAYER_LEAVE, {pid, self.leader and self.leader.pid or 0}, nil, true);
	self:FinishVote(pid)
	self:OnPlayerLeaveWhenVoting(pid)

	-- remove
	table.remove(self.members, index);
	recordTeamOfPlayer(pid, nil);

	-- delete player npc reward
	-- self:DeletePlayerNpcReward(pid, nil, nil, true, nil)

	if #self.members == 0 then
		log.debug("  team dissolve");
		notifyTeamWatcher(self);
		cleanTeam(self.id);
		cleanInviteList(nil, self.id)	

		-- if self.vm then self.vm:Command(0, 'STOP'); end
		-- TODO: notify other server
		SocialManager.NotifyTeamDissolve(self.id);

		deleteDBTeamInfo(self.id)
		--cleanAutoMatchTeamList(self.id)
		RemoveTeamFromMatchList(self)	
		Map.Sync(pid, {2, pid})
	else
		updateDBTeamMem(self)
		Map.Sync(pid, {2, pid})
		Map.Sync(self.leader.pid, {1, {self.leader.pid, self:GetMems(), self.id}})
	end	

	notifyTeamWatcher(self);

	-- 重置队伍匹配时间， 使队伍匹配等级回到5级
	if old_member_count == 5 then
		ChangeTeamMatchTime(self, loop.now())
	end

	-- if self.vm then self.vm:MemberLeave(pid); end
	return true;
end

function Team:PlayerAFK(pid)
	for k, id in ipairs(self.afk_list) do
		if id == pid then
			return true, idx
		end
	end

	return false
end

function Team:ChangeMemStat(pid, stat)
	if not self:PlayerIndex(pid) then
		log.debug(string.format("change mem stat fail player %d not in team", pid))
		return false
	end

	self.mem_stat[pid] = stat
end

function Team:AFK(pid)
	if self.leader.pid == pid then
		log.debug(string.format("fail to temporarily leave, player %d is leader", pid))
		return false
	end

	if self:PlayerAFK(pid) then
		log.debug("player already afk")
		return false
	end

	if self.apply_info and self.apply_info[pid] and loop.now() < self.apply_info[pid].end_time then
		log.debug("player want to be leader from voting")
		return false
	end

	table.insert(self.afk_list, pid)
	self:ChangeMemStat(pid, MEM_STAT_AFK)
	updateDBTeamAFKMem(self)

	local AI_members = self:GetAIMembers()
	for _, id  in ipairs(AI_members or {}) do
		SocialManager.NotifyAITeamPlayerAFK(id, pid)
	end

	self:Notify(Command.NOTIFY_TEAM_PLAYER_AFK, {pid}, nil, true);
	return true
end

function Team:BackToTeam(pid)
	local player_afk, idx = self:PlayerAFK(pid)
	if not player_afk then
		log.debug(string.format("back to team fail, player %d  not afk", pid))
		return false
	end

	table.remove(self.afk_list, idx)
	self:ChangeMemStat(pid, MEM_STAT_INIT)
	updateDBTeamAFKMem(self)
	
	local AI_members = self:GetAIMembers()
	for _, id  in ipairs(AI_members or {}) do
		SocialManager.NotifyAITeamPlayerBackToTeam(id, pid)
	end

	Map.RemoveObject(pid)
	self:Notify(Command.NOTIFY_TEAM_PLAYER_BACK_TO_TEAM, {pid}, nil, true);
	return true
end

function Team:GetMemsNotAFK()
	local mems = {}
	for _, v in (self.members) do
		if not self:PlayerAFK(v.pid) then
			table.insert(mems, v.pid)
		end
	end

	return mems
end

-- 计算队伍自动匹配时需要匹配的等级
function Team:GetAutoMatchAverageLevel()
	local total = 0
	local count = 0
	for _, v in ipairs(self.members) do
		total = total + v.player.level 	
		count = count + 1
	end

	if count == 0 then
		return 0
	end

	local average_level = math.ceil(total / count)
	if average_level < self.level_lower_limit then
		average_level = self.level_lower_limit
	end

	if average_level > self.level_upper_limit and self.level_upper_limit ~= 0 then
		average_level = self.level_upper_limit
	end

	return average_level
end

function Team:SetLeader(pid, opt_pid)
	log.debug(string.format("team %d-%d player %d begin to set player %d new leader", self.group, self.id, opt_id, pid))
	if pid == opt_id then
		log.debug("fail to set leader, same player")
		return false
	end
	
	if self.leader.pid ~= opt_pid then
		log.debug("fail to set leader, not leader")
		return false
	end

	if not self:PlayerIndex(pid) then
		log.debug(string.format("fail to set leader, player %d not in this team", pid))
		return false
	end

	local old_leader_pid = self.leader.pid
		
	local index,player = self:PlayerIndex(pid)
	self.leader = self.members[index].player
	log.debug(string.format('team %d-%d leader change to %d', self.group, self.id, self.leader.pid));
	updateDBTeamInfo(self.id, "leader", self.leader.pid)
	self:Notify(Command.NOTIFY_TEAM_CHANGE_LEADER, {self.leader.pid, self.auto_confirm})
	Map.Sync(self.leader.pid, {1, {self.leader.pid, self:GetMems(), self.id}})
	
	local ai_members = self:GetAIMembers()
	local pos = Map.GetPos(old_leader_pid)
	for _, id  in ipairs(ai_members or {}) do
		SocialManager.NotifyAITeamLeaderChange(id, self.leader.pid, pos and pos[2] or 0, pos and pos[3] or 0, pos and pos[4] or 0, pos and pos[1] or 0, pos and pos[5] or 0, pos and pos[6] or 0)
	end
end

function Team:AutoConfirm(b, opt_pid)
	log.debug(string.format("team %d-%d player %d %s auto confirm", self.group, self.id, opt_pid, b and "set" or "cancel"));

	if self.leader.pid ~= opt_pid then
		log.debug('  player not leader');
		return false;
	end

	self.auto_confirm = b;
	return true
end

function Team:AutoMatch(b, opt_pid)
	log.debug(string.format("team %d-%d player %d %s auto match", self.group, self.id, opt_pid, b and "set" or "cancel"));
	
	if self.leader.pid ~= opt_pid then
		log.debug('  player not leader');
		return false;
	end

	if self.auto_match == b then
		return true 
	end

	self.auto_match = b
	self:Notify(Command.NOTIFY_TEAM_AUTO_MATCH, {self.auto_match})
	if b then
		--addAutoMatchTeamList(self.id, self.group)
		--onNewAutoMatchTeamJoin(self.id, self.group)
		AddTeamToMatchList(self.group, self, self:GetAutoMatchAverageLevel())

		local ai_members = self:GetAIMembers()
		for _, id  in ipairs(ai_members or {}) do
			SocialManager.NotifyAITeamAutoMatchChange(id, b)
		end

		return true
	else
		--cleanAutoMatchTeamList(self.id)
		RemoveTeamFromMatchList(self)

		local ai_members = self:GetAIMembers()
		for _, id  in ipairs(ai_members or {}) do
			SocialManager.NotifyAITeamAutoMatchChange(id, b)
		end

		return true
	end

end

function Team:JoinRequest(pid)
	log.debug(string.format("player %d request to join team %d-%d", pid, self.group, self.id));

	local player = getPlayer(pid);

	--[[if not checkLimit(self.group, pid) then
		log.debug(string.format("Player %d fail to join team, check limit fail", pid))
		return
	end--]]

	if self.waiting[pid] then
		log.debug("   already in the team waiting list");
		if self.leader.pid <= AI_MAX_ID then
			local player = getPlayer(pid) 
			if player and player.level then
				SocialManager.NotifyAINewJoinRequest(self.leader.pid, pid, player.level)
			end
		end
		return true;
	end

	if getTeamByPlayer(pid) then
		log.debug("   already in a team");
		return false
	end

	if not self:LevelProper(pid) then
		log.debug("  level not proper")
		return false, Command.RET_LEVEL_NOT_ENOUGH
	end

	if self.auto_confirm and self:Enter(pid) then
		return true;
	end

	self.waiting[pid] = true;
	recordJoinRequest(pid, self.id);

	self:Notify(Command.NOTIFY_TEAM_PLAYER_JOIN_REQUEST, {pid, player.level, player.name});

	if self.leader.pid <= AI_MAX_ID then
		local player = getPlayer(pid) 
		if player and player.level then
			SocialManager.NotifyAINewJoinRequest(self.leader.pid, pid, player.level)
		end
	end

	return true;
end


function Team:JoinConfirm(pid, opt_pid)
	log.debug(string.format("team %d-%d player %d confirmed join request of player %d", self.group, self.id, opt_pid, pid));

	if self.leader.pid ~= opt_pid then
		log.debug('  player not leader');
		return false, nil, Command.RET_PREMISSIONS;
	end

	if not self.waiting[pid] then
		log.debug("  player not in waiting list");
		return false, nil, Command.RET_NOT_EXIST;
	end

	if getTeamByPlayer(pid) then
		log.debug("  player already in team");
		cleanJoinRequest(pid, self.id);
		return false, nil, Command.RET_ALREADY_HAS_TEAM;
	end

	if not player_online[pid] or not player_online[pid].online then
		log.debug(string.format("Join confirm fail,  player %d not online", pid))
		cleanJoinRequest(pid, self.id);
		return false, nil, Command.RET_NOT_ONLINE;
	end

	local success, err = self:Enter(pid)
	if success then
		cleanJoinRequest(pid, self.id);
		return true;
	end

	log.debug("  enter team failed");

	return false, nil, err or Command.RET_ERROR;
end

function Team:Invite(pid, opt_pid)
	log.debug(string.format("team %d-%d player %d invite player %d", self.group, self.id, opt_pid, pid))

	if self.leader.pid ~= opt_pid and pid ~= opt_pid then
		log.debug('  player not leader');
		return false, Command.RET_ERROR
	end

	if self:PlayerIndex(pid) then
		log.debug(string.format("Player %d fail to invite player %d, already in team", opt_pid, pid))
		return false, Command.RET_ALREADY_HAS_TEAM
	end

	--[[if self.invite[pid] and self.invite[pid] == INVITE_STAT_HAS_INVITED then
		log.debug("Player %d fail to invite player %d, already invited", opt_id, pid)
		return false
	end--]]

	--[[if not checkLimit(self.group, pid) then
		log.debug("Player %d fail to invite player %d, level not enough", opt_id, pid)
		return false
	end--]]
	if getTeamByPlayer(pid) then
		log.debug("  already in a team")
		return false, Command.RET_ALREADY_HAS_TEAM
	end

	addInviteList(pid, self.id)
	return true
	--self.invite[pid] = INVITE_STAT_HAS_INVITED
end

function Team:ProcessInviteList(pid , agree)
	log.debug(string.format("team %d-%d begin to process invite list for player %d , agree:%s", self.group, self.id, pid, tostring(agree)))

	--[[if not self.invite[pid] or self.invite[pid] ~= INVITE_STAT_HAS_INVITED then
		log.debug(string.format("fail to process invite list, Player %d not be invited", pid))
		return false
	end]]
	cleanInviteList(pid, self.id)
	if agree then
		return self:Enter(pid)	
	end
	return true
	--[[else
		self.invite[pid] = nil
		return true
	end--]]	
end

function Team:Kick(pid, opt_pid)
	log.debug(string.format("team %d-%d player %d kick player %d", self.group, self.id, opt_pid, pid));

	if self.leader.pid ~= opt_pid and pid ~= opt_pid then
		log.debug('  player not leader');
		return false;
	end

	return self:Leave(pid, opt_pid);
end

function Team:AllMemberAI()
	if self.leader.pid < 100000 then
		return true
	end
end

function Team:Dissolve(opt_id)
	log.debug(string.format("team %d-%d player %d dissolve team", self.group, self.id, opt_id));
	if self.leader.pid ~= opt_id then
		log.debug('  player not leader');
		return false;
	end

	local leave_list = {}
	for k,v in ipairs(self.members) do
		if v.pid ~= opt_id then
			table.insert(leave_list, v.pid)
			--self:Leave(v.pid)
		end
	end	

	for _, pid in ipairs(leave_list) do
		self:Kick(pid, opt_id)
	end

	self:Leave(opt_id)
end

function Team:CancelJoinRequest(pid)
	log.debug(string.format("player %d canceled join requeset of team %d-%d", pid, self.group, self.id));

	cleanJoinRequest(pid, self.id);
	return true;
end

function Team:DeleteJoinRequest(pid, opt_pid)
	log.debug(string.format("team %d-%d player %d delete join request for player %d", self.group, self.id, opt_pid, pid));
	
	if self.leader.pid ~= opt_pid and pid ~= opt_pid then
		log.debug('  player not leader');
		return false;
	end

	self:RemoveJoinRequest(pid)
	cleanJoinRequest(pid, self.id);
	return true
end

function Team:ChangeGroup(opt_pid, group)
	log.debug(string.format("team %d-%d player %d change group to %d", self.group, self.id, opt_pid, group));
	
	if self.leader.pid ~= opt_pid and pid ~= opt_pid then
		log.debug('  player not leader');
		return false;
	end

	-- if self.vm then log.debug("  is fighting") return false end

	local old_group = self.group
	self.group = group
	changeTeamGroup(self.id, old_group, group)
	updateDBTeamInfo(self.id, "group", self.group)
	notifyTeamWatcher(self);
	
	self:Notify(Command.NOTIFY_TEAM_GROUP_CHANGE, {group})
	
	local AI_members = self:GetAIMembers()
	for _, id  in ipairs(AI_members or {}) do
		SocialManager.NotifyAITeamGroupChange(id, group)
	end

	if self.auto_match then
        --cleanAutoMatchTeamList(self.id)
        --addAutoMatchTeamList(self.id, self.group)
        --onNewAutoMatchTeamJoin(self.id, self.group)
		RemoveTeamFromMatchList(self)
		AddTeamToMatchList(self.group, self, self:GetAutoMatchAverageLevel())
    end	

	return true
end

function Team:LevelProper(pid)
	local player = getPlayer(pid, true) 
	if player.level >= self.level_lower_limit and (player.level <= self.level_upper_limit or self.level_upper_limit == 0) then
		return true
	else
		return false
	end
end

function Team:ChangeLevelLimit(opt_pid, lower_limit, upper_limit)
	log.debug(string.format("team %d-%d player %d change level_limit to %d-%d", self.group, self.id, opt_pid, lower_limit, upper_limit));
	if upper_limit ~= 0 and lower_limit > upper_limit then
		log.debug('  upper_limit < lower_limit');
		return false
	end

	if self.leader.pid ~= opt_pid and pid ~= opt_pid then
		log.debug('  player not leader');
		return false;
	end

	self.level_lower_limit = lower_limit 
	self.level_upper_limit = upper_limit 
	updateDBTeamInfo(self.id, "level_lower_limit", self.level_lower_limit)
	updateDBTeamInfo(self.id, "level_upper_limit", self.level_upper_limit)
	notifyTeamWatcher(self);

	self:Notify(Command.NOTIFY_TEAM_LEVEL_LIMIT_CHANGE, {lower_limit, upper_limit})

	--onNewAutoMatchTeamJoin(self.id, self.group)
	if self.auto_match then
		RemoveTeamFromMatchList(self)
		AddTeamToMatchList(self.group, self, self:GetAutoMatchAverageLevel())
	end
	return true
end

function Team:Chat(pid, type, msg)
	log.debug(string.format('team %d-%d player %d chat %d %s', self.group, self.id, pid, type, msg));
	local idx = self:PlayerIndex(pid);
	if not idx then
		log.debug('  player not in team');
		return false;
	end

	self:Notify(Command.NOTIFY_TEAM_PLAYER_CHAT, {pid, type, msg});

	return true;
end

function Team:Info()
	local vote_info = {
		{self.is_inplace_checking, self.inplace_check_type, {}},
		{},
	}

	local mems = {}
	for k, v in ipairs(self.members) do
		local code = getPlayerFightData(v.pid)
		local m = {v.pid, v.pos, v.player.level, v.player.name, code}
		table.insert(mems, m);
		vote_info[1][3][k] = v.ready;
	end

	local waiting = {}
	for pid, _ in pairs(self.waiting) do
		local player = getPlayer(pid);

		if player then
			table.insert(waiting, {player.pid, player.level, player.name});
		end
	end

	local afk_list = {}
	for _,pid in ipairs(self.afk_list) do
		table.insert(afk_list, pid)
	end

	--[[local invite = {}
	for pid, _ in pairs(self.waiting) do
		local player = getPlayer(pid);

		if player then
			table.insert(invite, {player.pid, player.level, player.name, true});
		end
	end--]]


	local candidate = next(self.apply_info);
	if candidate and self.apply_info[candidate].end_time > loop.now() then
		local info = { self.apply_info[candidate].end_time, candidate, {} }
		for k, v in ipairs(self.members) do
			info[3][k] = self.apply_info[candidate].vote_list[v.pid];
		end
		vote_info[2] = info;
	end

	return {
		self.id,
		self.group,
		self.leader.pid,
		self.auto_confirm,
		mems,
		waiting,
		self.auto_match,
		self.team_status,
		self.level_lower_limit,
		self.level_upper_limit,
		vote_info,
		afk_list,
	};

end

function Team:InplaceCheck(opt_pid, type)
	log.debug(string.format('team %d-%d player %d start inplace check', self.group, self.id, opt_pid));

	if self.leader.pid ~= opt_pid then
		log.debug('  player not leader');
		return false;
	end

	self.is_inplace_checking = loop.now() + 30--true;
	self.inplace_check_type = type;
	for _, v in ipairs(self.members) do
		v.ready = 0--false
	end
	self:Notify(Command.NOTIFY_TEAM_INPLACE_CHECK, {self.is_inplace_checking, type});

	local AI_members = self:GetAIMembers()
	for _, id  in ipairs(AI_members or {}) do
		SocialManager.NotifyAITeamInplaceCheck(id)
	end
	return true;
end

function Team:InplaceReady(pid, ready, type)
	log.debug(string.format('team %d-%d player %d inplace set `%s`', self.group, self.id, pid, ready == 1 and "ready" or "not ready"));

	if not self.is_inplace_checking then
		log.debug('  not inplace checking');
		return false;	
	end

	local idx = self:PlayerIndex(pid);
	if not idx then
		log.debug('  player not in team');
		return false;
	end

	if self.members[idx].ready == ready then
		log.debug('  player status no change `%s`', ready == 1 and "ready" or "not ready");
		return true;
	end

	if not (ready == 1) then
		self:Notify(Command.NOTIFY_TEAM_INPLACE_READY, {pid, ready, type});
		return true
	end

	
	if self.vm then
		log.debug("already in vm")
		-- self.vm:MemberEnter(pid);
	else
		self.members[idx].ready = ready
		self:Notify(Command.NOTIFY_TEAM_INPLACE_READY, {pid, ready, type});

		local AI_members = self:GetAIMembers()
		for _, id  in ipairs(AI_members or {}) do
			SocialManager.NotifyAITeamPlayerReady(id, self.id, pid, ready)
		end

		local all_member_is_ready = true;
		for _, v in ipairs(self.members) do
			if not v.ready or (v.ready ~= 1) then
				all_member_is_ready = false;
			end
		end

		if not all_member_is_ready then
			return true;
		end

		log.debug(string.format('team %d-%d all player is ready', self.group, self.id));
		
		--self:StartFight(self.leader.pid, 20010101); --, 20010102);
	end

	return true;
end

local vote_listen_list = {}
local function AddToVoteListenList(candidate, teamid, end_time)
	if not vote_listen_list[candidate] then
		vote_listen_list[candidate] = {}
	end

	if not vote_listen_list[candidate][teamid] then
		vote_listen_list[candidate][teamid] = end_time 
	end
end

local function DeleteFromVoteListenList(candidate, teamid)
	if vote_listen_list[candidate] and vote_listen_list[candidate][teamid] then
		vote_listen_list[candidate][teamid] = nil
	end
end

function Team:HasOtherApply(pid)
	for candidate, apply_info in pairs(self.apply_info) do
		if candidate ~= pid and loop.now() <= apply_info.end_time then
			return true
		end
	end
	
	return false
end

function Team:ApplyToBeLeader(pid)
	log.debug(string.format('team %d-%d player %d apply to be leader', self.group, self.id, pid));

	if self.leader.pid == pid then
		log.debug('  player is already the leader');
		return false;
	end

	local idx = self:PlayerIndex(pid);
	if not idx then
		log.debug('  player not in team');
		return false;
	end

	if self:HasOtherApply(pid) then
		log.debug("has other apply")
		return false
	end

	local apply_info = self.apply_info[pid]

	if apply_info and loop.now() <= apply_info.end_time then
		log.debug('  is voting');
		return false
	end

	if self:PlayerAFK(pid) then
		log.debug("player afk")
		return false
	end

	self.apply_info[pid] = {}
	self.apply_info[pid].end_time = loop.now() + 60
	self.apply_info[pid].vote_list = {}
	for _, v in ipairs(self.members) do
		if v.pid == pid then
			self.apply_info[pid].vote_list[v.pid] = 1
		else
			if not self:PlayerAFK(v.pid) then
				self.apply_info[pid].vote_list[v.pid] = -1 
			end
		end
	end

	AddToVoteListenList(pid, self.id, self.apply_info[pid].end_time)
	self:Notify(Command.NOTIFY_TEAM_APPLY_TO_BE_LEADER, {pid, self.apply_info[pid].end_time});

	local ai_members = self:GetAIMembers()
	for _, id  in ipairs(ai_members or {}) do
		SocialManager.NotifyAIPlayerApplyToBeLeader(id, pid)
	end

	return true;	
end

local MIN_AGREE_COUNT = 2
function Team:Vote(pid, candidate, agree)
	log.debug(string.format('team %d-%d player %d begin vote for player %d', self.group, self.id, pid, candidate));

	local idx = self:PlayerIndex(pid);
	if not idx then
		log.debug('  player not in team');
		return false;
	end

	local apply_info = self.apply_info[candidate]	
	if not apply_info or loop.now() > apply_info.end_time then
		log.debug(string.format("candidate %d not apply to be leader", candidate))
		return false
	end

	if not apply_info.vote_list[pid] then
		log.debug(string.format("Player %d do not has right to vote", pid))
		return false
	end

	if pid == self.leader.pid then
		self:Notify(Command.NOTIFY_TEAM_VOTE, {candidate, pid, agree});
		self:FinishVote(candidate)	
		
		if agree == 1 then
			self:ChangeLeader(self.leader.pid, candidate)
		end
		return true
	end
	
	apply_info.vote_list[pid] = agree
	self:Notify(Command.NOTIFY_TEAM_VOTE, {candidate, pid, agree});

	local agree_count = 0 
	local total_count = 0
	for pid, agree in pairs(apply_info.vote_list) do
		if agree == 1 then
			agree_count = agree_count + 1
		end
		
		if pid ~= self.leader.pid then
			total_count = total_count + 1
		end
	end

	if agree_count >= math.floor(total_count / 2 + 1) and apply_info.vote_list[self.leader.pid] ~= -1 then
		self:FinishVote(candidate)
		self:ChangeLeader(self.leader.pid, candidate)
	end

	return true
end

function Team:OnVoteOutOfTime(candidate)
	local agree_count = 0 
	local total_count = 0
	local apply_info = self.apply_info[candidate]
	for pid, agree in pairs(apply_info.vote_list) do
		if agree == 1 then
			agree_count = agree_count + 1
		end
		
		if pid ~= self.leader.pid then
			total_count = total_count + 1
		end
	end

	if agree_count >= math.floor(total_count / 2 + 1) then
		self:FinishVote(candidate)
		self:ChangeLeader(self.leader.pid, candidate)
	end
end

function Team:OnPlayerLeaveWhenVoting(pid)
	print(string.format("Player %d leave when voting", pid), sprinttb(self.apply_info))
	for candidate, v in pairs (self.apply_info) do
		for id, agree in pairs(v.vote_list) do
			if id == pid and agree == -1 then
				self:FinishVote(candidate)
			end
		end
	end
end

function Team:FinishVote(candidate)
	if self.apply_info[candidate] then
		self.apply_info[candidate] = nil
		self:Notify(Command.NOTIFY_TEAM_VOTE_FINISH, {candidate});
		DeleteFromVoteListenList(candidate, self.id)
	end
end

function Team:ChangeLeader(opt_id, pid)
	log.debug(string.format('team %d-%d player %d give leader title to player %d', self.group, self.id, opt_id, pid));
	
	if self.leader.pid ~= opt_id then
		log.debug("player not leader")
		return false
	end

	local idx = self:PlayerIndex(pid)
	if not idx then
		log.debug("player not in team")
		return false
	end

	if self.leader.pid == pid then
		return true
	end

	old_leader_pid = self.leader.pid
	self.leader = self.members[idx].player
	new_leader_pid = self.leader.pid
	notifyTeamWatcher(self);
	updateDBTeamInfo(self.id, "leader", self.leader.pid)

	self:Notify(Command.NOTIFY_TEAM_CHANGE_LEADER, {new_leader_pid, self.auto_confirm})
	Map.Sync(self.leader.pid, {1, {self.leader.pid, self:GetMems(), self.id}})
	local pos = Map.GetPos(old_leader_pid)
	Map.ReplaceObject(old_leader_pid, new_leader_pid)

	local ai_members = self:GetAIMembers()
	for _, id  in ipairs(ai_members or {}) do
		SocialManager.NotifyAITeamLeaderChange(id, new_leader_pid, pos and pos[2] or 0, pos and pos[3] or 0, pos and pos[4] or 0, pos and pos[1] or 0, pos and pos[5] or 0, pos and pos[6] or 0)
	end
	return true
end

-- 同步数据
function Team:Sync(pid, type, data)
	log.debug(string.format('team %d-%d player %d sync %s', self.group, self.id, pid, tostring(type)));
	local idx = self:PlayerIndex(pid);
	if not idx then
		log.debug('  player not in team');
		return false;
	end

	self:Notify(Command.NOTIFY_TEAM_SYNC, {pid, type, data}, nil, true);

	return true;
end

function Team.registerCommand(service)
	service:on(Command.C_TEAM_QUERY_REQUEST, function(conn, pid, request)
		local sn = request[1];

		local team = getTeamByPlayer(pid);
		local teamInfo = team and team:Info(pid) or {0};

		conn:sendClientRespond(Command.C_TEAM_QUERY_RESPOND, pid, {sn, Command.RET_SUCCESS, teamInfo});
	end);

	service:on(Command.S_TEAM_QUERY_INFO_REQUEST, "TeamQueryInfoRequest", function(conn, channel, request) 
		local cmd = Command.S_TEAM_QUERY_INFO_RESPOND;
		local proto = "TeamQueryInfoRespond";

		print("S_TEAM_QUERY_INFO_REQUEST", request.tid, request.pid);

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_TEAM_QUERY_INFO_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local tid = request.tid;

		local team = nil
		if tid and tid ~= 0 then
			team = getTeam(tid);
		else
			local pid = request.pid
			team = getTeamByPlayer(pid);
		end

		local teamInfo = team and team:Info(pid) or nil;
		if not team or not teamInfo then
			print('S_TEAM_QUERY_INFO_REQUEST faield', team, teamInfo);
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

		local t = {}
		for k, v in ipairs(teamInfo[5] or {}) do
			table.insert(t, {pid = v[1], ready = v[6] or 0, level = v[3]})
		end
	
		print('S_TEAM_QUERY_INFO_REQUEST success', team.id);
		AI_DEBUG_LOG("Success ai query team info")
		return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS,
				teamid = teamInfo[1], grup = teamInfo[2], leader = teamInfo[3],
				inplace_checking = team.is_inplace_checking, 
				members = t, auto_confirm = teamInfo[4], auto_match = teamInfo[7], afk_list = teamInfo[12]});
	end)

	service:on(Command.C_TEAM_WATCH_GROUP_REQUEST, function(conn, pid, request)
		startWatchTeamList(pid, request[2]);
	end)

	service:on(Command.S_NOTIFY_AI_SERVICE_RESTART, "aGameRequest", function(conn, channel, request) 
		log.debug("AI service restart , begin to clean team data")
		for teamid, team in pairs(teams) do
			if team.leader.pid <= 100000 then
				team:Dissolve(team.leader.pid)	
			end
		end	
	
		Map.CleanAIData()
	end)

	service:on(Command.C_TEAM_QUERY_LIST_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local group = request[2] or 0;

		local teams = getTeamGroup(group);

		local list = {}
		for _, v in pairs(teams) do
			if v.need_to_be_dissolved then
				v:Dissolve(v.leader.pid)
			else
				if v.leader then
					table.insert(list, {v.id, #v.members, v.leader.pid, v.leader.name, haveJoinRequest(pid, v.id) and true or false, v.level_lower_limit, v.level_upper_limit, v:GetMems()})
				else
					table.insert(list, {v.id, #v.members, 0, "", false, v.level_lower_limit, v.level_upper_limit, v:GetMems()});
				end
			end
		end
		
		conn:sendClientRespond(Command.C_TEAM_QUERY_LIST_RESPOND, pid, {sn, Command.RET_SUCCESS, group, list});
	end);

	service:on(Command.C_TEAM_CREATE_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local group = request[2] or 0;
		local lower_limit = request[3] or 0;
		local upper_limit = request[3] or 0;
		
		local team = getTeamByPlayer(pid);
		if team then
			log.debug(string.format('player already in team %d', team.id));
			return conn:sendClientRespond(Command.C_TEAM_CREATE_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local team = Team.Create(group, pid);
		
		if not team then
			return conn:sendClientRespond(Command.C_TEAM_CREATE_RESPOND, pid, {sn, Command.RET_ERROR});
		end
		if not team:Enter(pid) then
			return conn:sendClientRespond(Command.C_TEAM_CREATE_RESPOND, pid, {sn, Command.RET_ERROR});
		end
		if not team:ChangeLevelLimit(pid, lower_limit, upper_limit) then
			return conn:sendClientRespond(Command.C_TEAM_CREATE_RESPOND, pid, {sn, Command.RET_ERROR});
		end
		
		return conn:sendClientRespond(Command.C_TEAM_CREATE_RESPOND, pid, {sn, Command.RET_SUCCESS});
	end)

	service:on(Command.S_TEAM_CREATE_REQUEST, "TeamCreateRequest", function(conn, channel, request) 
		local cmd = Command.S_TEAM_CREATE_RESPOND;
		local proto = "TeamCreateRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_TEAM_CREATE_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local group = request.grup
		local lower_limit = request.lower_limit
		local upper_limit = request.upper_limit

		local respond = {
			sn = request.sn,
			result = Command.RET_SUCCESS,
		}

		local team = getTeamByPlayer(pid);
		if team then
			log.debug(string.format('player already in team %d', team.id));
			respond.result = Command.RET_ERROR	
			return sendServiceRespond(conn, cmd, channel, proto, respond);
		end

		local team = Team.Create(group, pid);
		
		if not team then
			respond.result = Command.RET_ERROR	
			return sendServiceRespond(conn, cmd, channel, proto, respond);
		end
		
		if not team:Enter(pid) then
			respond.result = Command.RET_ERROR	
			return sendServiceRespond(conn, cmd, channel, proto, respond);
		end

		team:ChangeLevelLimit(pid, lower_limit, upper_limit)
	
		AI_DEBUG_LOG("Success ai create team")
		respond.teamid = team.id
		respond.leader_level = team.leader.level
		return sendServiceRespond(conn, cmd, channel, proto, respond);
	end)

	service:on(Command.C_TEAM_JOIN_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local teamid = request[2] or 0;

		local team = getTeam(teamid);
		if not team then
			return conn:sendClientRespond(Command.C_TEAM_JOIN_RESPOND, pid, {sn, Command.RET_NOT_EXIST});
		end

		local success, err = team:JoinRequest(pid)
		if not success then
			return conn:sendClientRespond(Command.C_TEAM_JOIN_RESPOND, pid, {sn, err or Command.RET_ERROR});
		end

		return conn:sendClientRespond(Command.C_TEAM_JOIN_RESPOND, pid, {sn, Command.RET_SUCCESS});
	end);

	local function registerTeamOpt(cmd, func, paramMaker)
		service:on(cmd, function(conn, pid, request)
				local sn = request[1];

				local team = getTeamByPlayer(pid)
				if not team then
					return conn:sendClientRespond(cmd+1, pid, {sn, Command.RET_NOT_EXIST});
				end

				local ret, info, err = func(team, paramMaker(conn, pid, request))
				return conn:sendClientRespond(cmd+1, pid, {sn, ret and Command.RET_SUCCESS or (err and err or Command.RET_ERROR), info});
		end)
	end

	registerTeamOpt(Command.C_TEAM_JOIN_CONFIRM_REQUEST, Team.JoinConfirm, function(conn, pid, request)
		local target_pid = request[2] or 0;
		return target_pid, pid
	end);

	service:on(Command.S_TEAM_JOIN_CONFIRM_REQUEST, "TeamJoinConfirmRequest", function(conn, channel, request) 
		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_TEAM_JOIN_CONFIRM_REQUEST`, channel ~= 0")
			return;
		end

		local opt_id = request.opt_id
		local pid = request.pid

		local team = getTeamByPlayer(opt_id)
		if not team then
			return 
		end

		local ret = team:JoinConfirm(pid, opt_id)
		if ret then
			AI_DEBUG_LOG("Success ai join confirm")
		end

		return	
	end)

	registerTeamOpt(Command.C_TEAM_KICK_REQUEST, Team.Kick, function(conn, pid, request)
		local target_pid = request[2] or 0;

		return target_pid, pid;
	end)

	service:on(Command.S_TEAM_LEAVE_REQUEST, "TeamLeaveRequest", function(conn, channel, request) 
		local cmd = Command.S_TEAM_LEAVE_RESPOND;
		local proto = "aGameRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_TEAM_LEAVE_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local opt_id = request.opt_id
		local pid = request.pid

		local team = getTeamByPlayer(opt_id)
		if not team then
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

		local ret, info = team:Kick(pid, opt_id)
		if ret then
			AI_DEBUG_LOG("Success ai leave team")
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
		else
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

	end)

	service:on(Command.S_TEAM_DISSOLVE_REQUEST, "TeamDissolveRequest", function(conn, channel, request) 
		local cmd = Command.S_TEAM_DISSOLVE_RESPOND;
		local proto = "aGameRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_TEAM_DISSOLVE_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid

		local team = getTeamByPlayer(pid)
		if not team then
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

		local ret, info = team:Dissolve(pid)
		if ret then
			AI_DEBUG_LOG("Success ai dissolve team")
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
		else
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

	end)

	registerTeamOpt(Command.C_TEAM_CHAT_REQUEST, Team.Chat, function(conn, pid, request)
		local type, msg = request[2] or 0, request[3];
		return pid, type, msg;
	end);

	registerTeamOpt(Command.C_TEAM_AUTO_CONFIRM_REQUEST, Team.AutoConfirm, function(conn, pid, request)
		local auto = request[2] and true or false;
		return auto, pid
	end);

	service:on(Command.S_TEAM_SET_AUTO_CONFIRM_REQUEST, "TeamSetAutoConfirmRequest", function(conn, channel, request) 
		local cmd = Command.S_TEAM_SET_AUTO_CONFIRM_RESPOND;
		local proto = "aGameRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_TEAM_SET_AUTO_CONFIRM_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local teamid = request.teamid

		local team = getTeamByPlayer(pid)
		if not team then
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

		local ret, info = team:AutoConfirm(true, pid)
		if ret then
			AI_DEBUG_LOG("Success ai set team auto confirm")
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
		else
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

	end)

	registerTeamOpt(Command.C_TEAM_INPLACE_CHECK_REQUEST, Team.InplaceCheck, function(conn, pid, request)
		return pid, request[2];
	end);

	service:on(Command.S_TEAM_INPLACE_CHECK_REQUEST, "TeamInplaceCheckRequest", function(conn, channel, request) 
		local cmd = Command.S_TEAM_INPLACE_CHECK_RESPOND;
		local proto = "aGameRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_TEAM_INPLACE_CHECK_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local teamid = request.teamid
		local type = request.type

		local team = getTeamByPlayer(pid)
		if not team then
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

		local ret, info = team:InplaceCheck(pid, type)
		if ret then
			AI_DEBUG_LOG("Success ai inplace check")
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
		else
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

	end)

	registerTeamOpt(Command.C_TEAM_INPLACE_READY_REQUEST, Team.InplaceReady, function(conn, pid, request)
		return pid, request[2], request[3];
	end);

	service:on(Command.S_TEAM_INPLACE_READY_REQUEST, "TeamInplaceReadyRequest", function(conn, channel, request) 
		local cmd = Command.S_TEAM_INPLACE_READY_RESPOND;
		local proto = "aGameRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_TEAM_INPLACE_READY_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local teamid = request.teamid
		local ready = request.ready
		local type = request.type

		local team = getTeamByPlayer(pid)
		if not team then
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

		local ret, info = team:InplaceReady(pid, ready, type)
		if ret then
			AI_DEBUG_LOG("Success ai inplace ready")
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
		else
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

	end)

	service:on(Command.C_TEAM_SYNC_REQUEST, function(conn, channel, request) 
		local sn, type, data = request[1], request[2], request[3];
		local pid = channel;

		local team = getTeamByPlayer(pid)
		if not team then
			return conn:sendClientRespond(Command.C_TEAM_SYNC_RESPOND, pid, {sn, Command.RET_NOT_EXIST});
		end

		team:Sync(pid, type, data);

		return conn:sendClientRespond(Command.C_TEAM_SYNC_RESPOND, pid, {sn, Command.RET_SUCCESS});
	end)

	service:on(Command.S_TEAM_SYNC_REQUEST, "TeamSyncRequest", function(conn, channel, request) 
		local cmd = Command.S_TEAM_SYNC_RESPOND;
		local proto = "aGameRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_TEAM_SYNC_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local cmd = request.cmd
		local data = request.data

		local team = getTeamByPlayer(pid)
		if not team then
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

		AI_DEBUG_LOG("Success ai team sync *************************", pid, cmd, unpack(data))
		if cmd == 100 then
			team:Sync(pid, cmd, data)
		else
			team:Sync(pid, cmd, unpack(data))
		end	
		return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
	end)

	service:on(Command.S_TEAM_INPLACE_READY_REQUEST, "TeamInplaceReadyRequest", function(conn, channel, request) 
		local cmd = Command.S_TEAM_INPLACE_READY_RESPOND;
		local proto = "aGameRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_TEAM_INPLACE_READY_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local teamid = request.teamid
		local ready = request.ready
		local type = request.type

		local team = getTeamByPlayer(pid)
		if not team then
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

		local ret, info = team:InplaceReady(pid, ready, type)
		if ret then
			AI_DEBUG_LOG("Success ai inplace ready")
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
		else
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

	end)

	--NEED TEST
	registerTeamOpt(Command.C_TEAM_DELETE_JOIN_REQUEST_LIST_REQUEST, Team.DeleteJoinRequest, function(conn,pid,request)
		return request[2], pid;
	end);

	service:on(Command.C_TEAM_INVITE_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local tid = request[2]

		local team = getTeamByPlayer(pid)
		if not team then
			return conn:sendClientRespond(Command.C_TEAM_INVITE_RESPOND, pid, {sn, Command.RET_NOT_EXIST});
		end

		local ret, errn = team:Invite(tid,pid) 
		return conn:sendClientRespond(Command.C_TEAM_INVITE_RESPOND, pid, {sn, ret and Command.RET_SUCCESS or errn, info});
	end);	

	service:on(Command.C_TEAM_PLAYER_QUERY_INVITE_LIST_REQUEST, function(conn, pid, request)
		local sn = request[1];
		return conn:sendClientRespond(Command.C_TEAM_PLAYER_QUERY_INVITE_LIST_RESPOND, pid, {sn, Command.RET_SUCCESS, queryInviteList(pid)});
	end);

	service:on(Command.C_TEAM_PLAYER_REPLY_INVITATION_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local teamid = request[2]
		local agree = request[3] and true or false
		local ret = replyInvitation(pid, teamid, agree)
		return conn:sendClientRespond(Command.C_TEAM_PLAYER_REPLY_INVITATION_RESPOND, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR});
	end);

	service:on(Command.C_TEAM_PLAYER_AUTO_MATCH_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local group = request[2]
		--local ret, auto_match_success = autoMatch(pid, group)
		local ret = AutoMatch(pid, group)
		return conn:sendClientRespond(Command.C_TEAM_PLAYER_AUTO_MATCH_RESPOND, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR, auto_match_success});
	end);

	service:on(Command.S_AI_AUTOMATCH_REQUEST, "AIAutomatchRequest", function(conn, channel, request) 
		local cmd = Command.S_AI_AUTOMATCH_RESPOND;
		local proto = "aGameRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_AI_AUTOMATCH_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local group = request.grup
		local pid = request.pid
		local teamid = request.teamid
		local ret, _ = AutoMatch(pid, group)--AIAutoMatch(pid, group, teamid)--autoMatch(pid, group)

		if ret then
			AI_DEBUG_LOG("Success ai auto match")
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
		else
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

	end)
	
	registerTeamOpt(Command.C_TEAM_AUTO_MATCH_REQUEST, Team.AutoMatch, function(conn,pid,request)
		return request[2] and true or false, pid;
	end);

	service:on(Command.S_AI_TEAM_AUTOMATCH_REQUEST, "AITeamAutomatchRequest", function(conn, channel, request) 
		local cmd = Command.S_AI_TEAM_AUTOMATCH_RESPOND;
		local proto = "aGameRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_AI_TEAM_AUTOMATCH_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local auto_match = request.auto_match

		local team = getTeamByPlayer(pid)
		if not team then
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

		local ret = team:AutoMatch(auto_match, pid)

		if ret then
			AI_DEBUG_LOG("Success ai team auto match")
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
		else
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

	end)

	service:on(Command.S_GET_AUTOMATCH_TEAM_COUNT_REQUEST, "GetAutomatchTeamCountRequest", function(conn, channel, request) 
		local cmd = Command.S_GET_AUTOMATCH_TEAM_COUNT_RESPOND;
		local proto = "GetAutomatchTeamCountRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_GET_AUTOMATCH_TEAM_COUNT_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local group = request.grup
		local level = request.level

		--local ret = getAutoMatchTeamCount(group)
		local ret = GetAutoMatchTeamCount(group, level)

		if ret then
			AI_DEBUG_LOG("Success ai get automatch team count >>>>>>>!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!", ret)
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS, count = ret});
		else
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

	end)
	
	service:on(Command.S_QUERY_AUTOMATCH_TEAM_REQUEST, "QueryAutoMatchTeamRequest", function(conn, channel, request) 
		local cmd = Command.S_QUERY_AUTOMATCH_TEAM_RESPOND;
		local proto = "QueryAutoMatchTeamRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_QUERY_AUTOMATCH_TEAM_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		--local team_list = GetAutoMatchTeamList()
		local team_list = QueryAutoMatchTeamList()
		
		AI_DEBUG_LOG("Success ai get automatch team list")
		return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS, team_list = team_list});
	end)

	registerTeamOpt(Command.C_TEAM_CHANGE_GROUP_REQUEST, Team.ChangeGroup, function(conn,pid,request)
		return pid, request[2];
	end);

	registerTeamOpt(Command.C_TEAM_CHANGE_LEVEL_LIMIT_REQUEST, Team.ChangeLevelLimit, function(conn,pid,request)
		return pid, request[2], request[3];
	end);

	registerTeamOpt(Command.C_TEAM_CHANGE_LEADER_REQUEST, Team.ChangeLeader, function(conn,pid,request)
		return pid, request[2];
	end);

	service:on(Command.S_TEAM_CHANGE_LEADER_REQUEST, "TeamChangeLeaderRequest", function(conn, channel, request) 
		local cmd = Command.S_TEAM_CHANGE_LEADER_RESPOND;
		local proto = "aGameRespond";

		if channel ~= 0 then
			--log.error(request.pid .. "Fail to `S_TEAM_CHANGE_LEADER_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local new_leader = request.new_leader

		local respond = {
			sn = request.sn,
			result = Command.RET_SUCCESS,
		}

		local team = getTeamByPlayer(pid);
		
		if not team then
			respond.result = Command.RET_ERROR	
			return sendServiceRespond(conn, cmd, channel, proto, respond);
		end

		
		if not team:ChangeLeader(pid, new_leader) then
			respond.result = Command.RET_ERROR	
			return sendServiceRespond(conn, cmd, channel, proto, respond);
		end
	
		AI_DEBUG_LOG("Success ai change leader")
		return sendServiceRespond(conn, cmd, channel, proto, respond);
	end)

	service:on(Command.C_TEAM_QUERY_INFO_BY_PID_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local tid = request[2] or pid
		local team = getTeamByPlayer(tid);
		local teamInfo = team and team:Info(tid) or {};

		conn:sendClientRespond(Command.C_TEAM_QUERY_INFO_BY_PID_RESPOND, pid, {sn, Command.RET_SUCCESS, teamInfo});
	end);

	service:on(Command.C_TEAM_APPLY_TO_BE_LEADER_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local team = getTeamByPlayer(pid);
		if not team then
			log.debug(string.format("Player %d Fail to apply to be leader, not has team", pid))	
			return conn:sendClientRespond(Command.C_TEAM_APPLY_TO_BE_LEADER_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local ret = team:ApplyToBeLeader(pid)
		conn:sendClientRespond(Command.C_TEAM_APPLY_TO_BE_LEADER_RESPOND, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR});
	end);

	service:on(Command.C_TEAM_VOTE_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local team = getTeamByPlayer(pid);
		local candidate = request[2]
		local agree = request[3]
		if not candidate or not agree then
			log.debug(string.format("Player %d Fail to vote, param error", pid))	
			return conn:sendClientRespond(Command.C_TEAM_VOTE_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		if not team then
			log.debug(string.format("Player %d Fail to vote, not has team", pid))	
			return conn:sendClientRespond(Command.C_TEAM_VOTE_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local ret = team:Vote(pid, candidate, agree)
		conn:sendClientRespond(Command.C_TEAM_VOTE_RESPOND, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR});
	end);	

	service:on(Command.S_TEAM_VOTE_REQUEST, "TeamVoteRequest", function(conn, channel, request)
		if channel ~= 0 then
			return;
		end

		local pid = request.pid
		local candidate = request.candidate
		local agree = request.agree

		local team = getTeamByPlayer(pid);
		if not team then
			return
		end

		if not team:Vote(pid, candidate, agree) then
			return 
		end
	
		AI_DEBUG_LOG("Success ai vote")
		return 
	end)

	service:on(Command.S_TEAM_GET_PLAYER_AI_RATIO_REQUEST, "GetPlayerAIRatioRequest", function(conn, channel, request) 
		local cmd = Command.S_TEAM_GET_PLAYER_AI_RATIO_RESPOND;
		local proto = "GetPlayerAIRatioRespond";

		if channel ~= 0 then
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local targets = request.targets

		local ret = {}
		for k, group in ipairs(targets) do
			local ratio = GetRatioOfRealPlayerAndAI(group)
			table.insert(ret, {target = group, priority = ratio})	
		end

		return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn, result = Command.RET_SUCCESS, targets_priority = ret});
	end)

	service:on(Command.C_GM_MEMBER_LEAVE_REQUEST, function (conn, pid, request)
		local cmd = Command.C_GM_MEMBER_LEAVE_RESPOND
		if #request < 2 then
			log.warning(string.format("cmd: %d, param error.", cmd))
			return sendClientRespond(cmd, pid, { 1, Command.RET_PARAM_ERROR })
		end
		local sn = request[1]
		local leave_pid = request[2]
		local team = getTeamByPlayer(leave_pid)
		if team then
			team:Leave(leave_pid)
			conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
		else
			log.warning(string.format("cmd: %d, player %d has no team.", cmd, leave_pid))
			conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
		end	
	end)

	service:on(Command.C_TEAM_AFK_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local team = getTeamByPlayer(pid);
		if not team then
			log.debug(string.format("Player %d fail to afk, not has team", pid))	
			return conn:sendClientRespond(Command.C_TEAM_AFK_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local ret = team:AFK(pid)
		print("ret >>>>>>>>>>>", tostring(ret))
		conn:sendClientRespond(Command.C_TEAM_AFK_RESPOND, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR});
	end);	

	service:on(Command.C_TEAM_BACK_TO_TEAM_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local team = getTeamByPlayer(pid);
		if not team then
			log.debug(string.format("Player %d fail to back to team, not has team", pid))	
			return conn:sendClientRespond(Command.C_TEAM_BACK_TO_TEAM_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local ret = team:BackToTeam(pid)
		conn:sendClientRespond(Command.C_TEAM_BACK_TO_TEAM_RESPOND, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR});
	end);	

	--[[service:on(Command.S_NOTIFY_TEAM_MEMBERS, "NotifyTeamMembers", function(conn, channel, request) 
		print("S_NOTIFY_TEAM_MEMBERS",  request.teamid, request.cmd, request.msg, request.pids, request.include_afk_afk_mem, request.targets)
		if channel ~= 0 then
			return;
		end

		local teamid = request.teamid
		local cmd = request.cmd
		local msg = request.msg
		local pids = requests.pids
		local include_afk_mem = request.include_afk_mem

		local team = getTeam(teamid)
		if not team then
			return 
		end

		team:Notify(cmd, msg, pids, include_afk_mem)
	end)--]]

end

local listen_team_list = {}

local function addToListenTeamList(team, time)
	time = time or loop.now()
	listen_team_list[team.id] = {
		team = team,
		leader_logout_time = time 
	}
end

local function deleteFromListenTeamList(team)
	if listen_team_list[team.id] then
		listen_team_list[team.id] = nil
	end
end

function Team.OnPlayerLogout(pid)
	if not player_online[pid] then
		player_online[pid] = {
			online = false,
			last_login_time = 0,
			last_logout_time = loop.now()
		}
	end
	player_online[pid].online = false 
	player_online[pid].last_logout_time = loop.now()

	local team = getTeamByPlayer(pid);
	if team and team.leader.pid == pid then
		addToListenTeamList(team)
	end

	if pid <= AI_MAX_ID then
		RemoveAIFromMatchList(pid)
	else
		RemovePlayerFromMatchList(pid)
	end
end

function Team.OnPlayerLogin(pid)
	if not player_online[pid] then
		player_online[pid] = {
			online = true,
			last_login_time = loop.now(),
			last_logout_time = 0
		}
	end
	player_online[pid].online = true 
	player_online[pid].last_login_time = loop.now()
	
	local team = getTeamByPlayer(pid);
	if team and team.leader.pid == pid then
		deleteFromListenTeamList(team)
	end
end

local OFFLINE_PROTECT_TIME = 5 * 60 
Scheduler.Register(function(t)
	for k, v in pairs(listen_team_list) do
		--log.debug("count down", OFFLINE_PROTECT_TIME - (loop.now() - v.leader_logout_time))
		if t - v.leader_logout_time >= OFFLINE_PROTECT_TIME then
			local team = v.team
			local new_leader = 0
			local all_member_offline = true 
			local min_offline_time = OFFLINE_PROTECT_TIME

			for k, v in ipairs(team.members) do
				if player_online[v.pid] and player_online[v.pid].online and v.pid ~= team.leader.pid and not team:PlayerAFK(v.pid) then
					new_leader = v.pid
					all_member_offline = false
					break	
				end
			end

			-- all member offline
			if all_member_offline then
				for k, v in ipairs(team.members) do
					if player_online[v.pid] and (player_online[v.pid].last_logout_time ~= 0) and (loop.now() - player_online[v.pid].last_logout_time < min_offline_time) and not team:PlayerAFK(v.pid) then
						new_leader = v.pid
						min_offline_time = loop.now() - player_online[v.pid].last_logout_time
					end
				end	
			end

			if new_leader ~= 0 then
				--if not Agent.Get(team.leader.pid) then
					log.debug(string.format("leader of team %d logout too long, change leader", team.id))
					team:AutoMatch(false, team.leader.pid)
					team:ChangeLeader(team.leader.pid, new_leader)
					
					if all_member_offline then
						addToListenTeamList(team, player_online[new_leader].last_logout_time)
					else
						deleteFromListenTeamList(team)	
					end
				--else
					--deleteFromListenTeamList(team)	
				--end
			else
				log.debug(string.format("no member active, team %d need to be dissolved",team.id))
				--[[local real_all_offline = true
				for k, v in ipairs(team.members) do
					if Agent.Get(v.pid) then
						real_all_offline = false
						break
					end
				end--]]
	
				--if real_all_offline then
					while team.members[1] do
						team:Leave(team.members[1].pid)
					end
				--end
				
				deleteFromListenTeamList(team)
			end

		end
	end

	for candidate, v in pairs(vote_listen_list) do
		for teamid, end_time in pairs(v) do
			if loop.now() > end_time then
				local team = getTeamByPlayer(candidate);
				if team then
					team:OnVoteOutOfTime(candidate)
				end
			end
		end
	end
end);





--[[
-- in fight
C_TEAM_LOAD_MONSTER_REQUEST = 16040  -- {sn, monster_type}
C_TEAM_LOAD_MONSTER_RESPOND = 16041  -- {sn, result}

NOTIFY_TEAM_ADD_MONSTER = 16007  -- {data}
NOTIFY_TEAM_MONSTER_SYNC = 16008  -- {data}
--]]


--[[
local team = Team.Create(11);
team:Enter(100001);
team:JoinRequest(100002);
team:JoinConfirm(100002, 100001);
team:AutoConfirm(true, 100001);
team:JoinRequest(100003);
team:Kick(100001, 100001);
team:AutoConfirm(false, 100002);
team:JoinRequest(100001);
team:JoinConfirm(100001, 100002);
--]]

--[[-- delete join test case
local team = Team.Create(11, 100001);
team:Enter(100001);
team:JoinRequest(100002);
team:JoinRequest(100003);
team:JoinRequest(100004);
log.info("!!!!!!!!!!!!  before delete join request ", sprinttb(team:Info()))
team:DeleteJoinRequest(100002, 100001)
log.info("!!!!!!!!!!!!  delete join request for 100002", sprinttb(team:Info()))
team:DeleteJoinRequest(0, 100001)
log.info("!!!!!!!!!!!!  delete join request for all", sprinttb(team:Info()))
--]]

-- invite test case	
--[[local team = Team.Create(11, 100001);
team:Enter(100001)
local team2 = Team.Create(11, 100003)
team2:Enter(100003)
log.info("before agree, team info", sprinttb(team:Info()))
log.info("before agree, team2 info", sprinttb(team2:Info()))
team:Invite(100002, 100001)
team2:Invite(100002, 100003)
log.info("before agree, player invite list", sprinttb(queryInviteList(100002)))
local teamid = team.id
replyInvitation(100002, teamid, false)
log.info("after agree, player invite list", sprinttb(queryInviteList(100002)))
--]]

-- auto match test case -----
-- case 1
--[[local team = Team.Create(11, 100001);
team:Enter(100001)
log.info("before auto match team info", sprinttb(team:Info()))
autoMatch(100002, 11)
team:AutoMatch(true, 100001)
log.info("after auto match,  player auto match list", sprinttb(autoMatchPlayerList))
log.info("after auto match team info", sprinttb(team:Info()))
--]]

-- case 2
--[[local team = Team.Create(11, 100001);
team:Enter(100001)
log.info("before auto match team info", sprinttb(team:Info()))
autoMatch(100002, 11)
autoMatch(100003, 11)
log.info("after auto match,  player auto match list", sprinttb(autoMatchPlayerList))
log.info("after auto match team info", sprinttb(team:Info()))
log.info("teams", sprinttb(teams))
--]]

----------------------------

return Team;
