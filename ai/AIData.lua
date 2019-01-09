local EventManager = require "EventManager"
local BattleConfig = require "BattleConfig"
local Command = require "Command"
local EventList = require "EventList"
local DataThread = require "DataThread"
require "printtb"

AI_MAX_ID = 99999

STATUS_CLEAN = 1        -- 清理数据
STATUS_PREPARE = 2      -- 创建队伍或加入队伍
STATUS_WAITING = 3      -- 等候玩家（队长模式） 
STATUS_TASKING = 4      -- 执行任务（打副本）
INPLACE_CHECK_LAST_TIME = 30

local saveValue = {}

local function err_log(...)
	return  "ERROR"..tostring(...) --AI_DEBUG_LOG("ERROR ", ...)
	--AI_DEBUG_LOG("", debug.traceback())
end

local AIData = { auto_match_teams = {} }    -- team_list{[team_id] = {finish_all_fight = true, update_time = 0}, .... }

local function PlayerIndex(members, pid)
	for k, v in ipairs(members or {}) do
		if v.pid == pid then
		 	return k	
		end
	end

	return nil	
end

local function InitBountyData(id)
	if not AIData[id] then
		--AIData[id] = {}
		return 
	end

	if not AIData[id].bounty then
		AIData[id].bounty = {
			activity_id = 0,
			quest_id = 0,
			record = 0,
			next_fight_time = 0,
			win_count = 0,
			lose_count = 0,
			finish = false,
			finish_round = 0,
			steps = 0,
			nav_idx = 0,
			steps_without_real_player = 0,
		}
	end
end

local function TeamAllFightFinish(finish, time)
	if loop.now() - time > 60 then
		return false 
	end

	return finish 
end

function AIData.RefreshAutoMatchTeams(respond)
	if not respond or respond.result ~= Command.RET_SUCCESS then
		return 
	end

	local new_team_list = {}
	
	for k, teamInfo in ipairs(respond.team_list or {}) do
		local group = teamInfo.grup
		local teamid = teamInfo.teamid
		AIData.auto_match_teams[group] = AIData.auto_match_teams[group] or {team_list = {}}
		local old_info = AIData.auto_match_teams[group].team_list[teamid]
		if old_info then
			AIData.auto_match_teams[group].team_list[teamid] = {finish_all_fight = old_info.finish_all_fight, update_time = old_info.update_time}
		else
			AIData.auto_match_teams[group].team_list[teamid] = {finish_all_fight = false, update_time = loop.now()}
		end	
	end

end

function AIData.AddAutoMatchTeams(teamid, group)
	AIData.auto_match_teams[group] = AIData.auto_match_teams[group] or {team_list = {}}
	AIData.auto_match_teams[group].team_list[teamid] = {finish_all_fight = false, update_time = loop.now()}	
end

function AIData.GetNotFinishAllFightTeam(group)
	if not AIData.auto_match_teams[group] then
		print(string.format("get team which not finish all fight for group %d fail", group))
		return 0
	end

	local t = {}
	for teamid, v in pairs(AIData.auto_match_teams[group].team_list) do
		if not TeamAllFightFinish(v.finish_all_fight, v.update_time) then
			table.insert(t, teamid)
		end
	end

	if #t == 0 then
		print(string.format("get team which not finish all fight for group %d fail", group))
		return 0
	end

	local rand_key = math.random(1, #t)
	return t[rand_key]
end

function AIData.SetTeamAllFightFinish(teamid, group)
	AIData.auto_match_teams[group] = AIData.auto_match_teams[group] or {team_list = {}}
	AIData.auto_match_teams[group].team_list[teamid] = {finish_all_fight = true, update_time = loop.now()}
end

function AIData.GetStatus(id)
	if not AIData[id] then
		--AIData[id] = {}
		return 
	end
	
	if not AIData[id].status then
		AIData[id].status = STATUS_CLEAN
	end

	return AIData[id].status
end

function AIData.SetStatus(id, stat)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	AI_DEBUG_LOG(string.format("AI %d set status to %d", id, stat))
	AIData[id].status = stat
end

function AIData.SetTarget(id, target)
	if not AIData[id] then
		--AIData[id] = {}
		return 
	end
	
	AIData[id].target = target
end

function AIData.GetTarget(id, target)
	return AIData[id] and AIData[id].target or nil
end

function AIData.GetSleepTime(id)
	if not AIData[id] then
		return 
	end

	return AIData[id].sleep_time
end

function AIData.SetSleepTime(id)
	if not AIData[id] then
		return
	end

	if not AIData[id].sleep_time then
		AIData[id].sleep_time = loop.now()
	end
end

function AIData.ClearSleepTime(id)
	if not AIData[id] then
		return
	end

	AIData[id].sleep_time = nil 
end

function AIData.GetPos(id)
	if not AIData[id] then
		return nil
	end

	if not AIData[id].pos then
		AIData[id].pos = {}
		local _,sn = GetPos(id)
		saveValue[sn] = id
	end

	return AIData[id].pos
end

local function UpdatePos(id, mid, x, y, z, ch, rm)
	if not AIData[id] then
		return 
	end
	
	local o_mid, o_ch, o_rm
	if AIData[id].pos and AIData[id].pos.mapid then
		o_mid = AIData[id].pos.mapid
	end

	if AIData[id].pos and AIData[id].pos.channel then
		o_ch = AIData[id].pos.channel
	end

	if AIData[id].pos and AIData[id].pos.room then
		o_rm = AIData[id].pos.room
	end
	
	mid = mid or o_mid or 10
	ch = ch or o_ch or 2
	rm = rm or o_rm or 1
	AIData[id].pos = {mapid = mid, x = x, y = y, z = z, channel = ch, room = rm}
	--AI_DEBUG_LOG(string.format("AI %d update pos >>>>>", id), AIData[id].pos.channel, AIData[id].pos.room)
end

local TEAM_SYNC_COMMAND_CHANGE_MAP = 100    -- {mapid, channel, room}  队长切换地图
local TEAM_SYNC_COMMAND_TRIGGER_STORY = 103 -- {stroyid}  副本内触发剧情
local TEAM_SYNC_COMMAND_TAKE_TASK = 104 --{taskid}   接任务
local TEAM_SYNC_COMMAND_SUBMIT_TASK = 105 --{taskid} 交任务

function AIData.GetNickName(id)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	if not AIData[id].nick_name then
		local respond = cell.getPlayerInfo(id)
		if respond then
			AIData[id].nick_name = respond.name
		end
	end

	return AIData[id].nick_name
end

function AIData.UpdateNickName(id, name, head)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end	

	local success = ChangeNickName(id, name, head)
	AI_DEBUG_LOG(string.format("AI %d Update Nick Name %s", id, name), success)
	if success then
		AIData[id].nick_name = name
	end

	return success
end

function AIData.ChangeSexual(id, sexual)
	if not AIData[id] then
		return
	end

	ModifyPlayerProperty(id, 1, {2, sexual})
end

function AIData.GetHasChangeHead(id)
	if not AIData[id] then
		return 
	end

	return AIData[id].today_has_change_head
end

function AIData.SetTodayHasChangeHead(id)
	if not AIData[id] then
		return
	end

	AIData[id].today_has_change_head = true 
end

function AIData.TeamSync(id, cmd, data)
	local team = AIData.GetTeam(id)
	if not team or (team.leader ~=id) then
		AI_WARNING_LOG(string.format("AI %d team sync fail"))
		return false
	end

	TeamSync(id, cmd, data)
end

function AIData.LoginMap(id)
	if not AIData[id] then
		--AIData[id] =  {}
		return 
	end
	
	LoginMap(id)
	AIData[id].login_map = true
end

function AIData.GetLoginMap(id)
	if not AIData[id] then
		return false 
	end

	return AIData[id].login_map
end

function AIData.LogoutMap(id)
	LogoutMap(id)	
	if AIData[id] and AIData[id].login_map ~= nil then
		AIData[id].login_map = false
	end
end

local function RandomPos(pos, old_pos)
	assert(pos)
	
	if not old_pos then
		if math.random(1, 10) > 5 then
			return pos + math.random(500, 600) / 1000
		else
			return pos - math.random(500, 600) / 1000
		end
	else
		if old_pos > pos then
			return pos + math.random(500, 600) / 1000
		else
			return pos - math.random(500, 600) / 1000
		end
	end
end

function AIData.MapMove(id, x, y, z, mapid, channel, room)
	if not AIData[id] then
		return 
	end

	AI_DEBUG_LOG(string.format("AI %d Map move >>>>>>>>>>>>>>>>>>>>>>>", id), x, y, z, mapid, channel, room)
	local old_y =  AIData[id].pos and AIData[id].pos.y or nil
	x = RandomPos(x)	
	y = RandomPos(y, old_y)	
	--z = RandomPos(z)	
	local _, sn = MapMove(id, x, y, z, mapid, channel, room)
	saveValue[sn] = {id = id, x = x, y = y, z = z, mapid = mapid, channel = channel, room = room}
end

local function getBattleByGroup(group)
	local cfg = BattleConfig.GetGroupConfig(group)
	if not cfg then
		AI_WARNING_LOG(string.format("cannt get battle group config for group %d", group))
		return nil
	end

	return cfg.gid_id
end

local function getTargetFights(group, teamid, id)
	local target = AIData.GetTarget(id)
	if not target then
		return {} 
	end

	local target_type = GetTargetType(target)
	if target_type ~= "team_fight" then
		return {}
	end

	local target = {}
	local t = {}
	--if group >= 20 and group <= 23 then
		--local battle_id = group -20 
		local battle_id = getBattleByGroup(group)
		if battle_id then
			local fights = 	BattleConfig.GetBattleFights(battle_id)	
			for gid, v in pairs(fights) do
				table.insert(target, {fight_id = v.gid, sequence = v.sequence, finish = 0, fight_count = 0})
				table.insert(t, gid)
			end
		end
	--end	

	if #t > 0 then
		if id and teamid then
			local respond = GetTeamProgress(id, teamid, t)
			if respond and respond.result == Command.RET_SUCCESS then
				local map = {}
				for k, v in ipairs(respond.progress) do
					map[v.fight_id] = v.progress	
				end

				for k, v in ipairs(target) do
					if map[v.fight_id] and map[v.fight_id] >= 1 then
						v.finish = 1
					end
				end
			end
		end

		table.sort(target, function(a, b) 
			if a.sequence ~= b.sequence then
				return a.sequence < b.sequence 
			end
			if a.finish ~= b.finish then
				return a.finish > b.finish
			end
		end)
	end

	return target
end

local function getTargetBattle(group)
	local target = AIData.GetTarget(id)
	if not target then
		return 0
	end

	local target_type = GetTargetType(target)
	if target_type ~= "team_fight" then
		return 0 
	end

	return getBattleByGroup(group) or 0
end

local function LoadBountyInfo(group, teamid, id)
	InitBountyData(id)
	
	local target = AIData.GetTarget(id)
	if not target then
		AI_DEBUG_LOG(string.format("AI %d LoadBountyInfo fail, not has target", id))
	end

	local respond = BountyQuery(id)
	if respond and respond.result == Command.RET_SUCCESS then
		for k, v in ipairs(respond.quest_info) do
			if v.activity_id == target then
				AIData[id].bounty.quest_id = v.quest
				AIData[id].bounty.record = v.record
				AIData[id].bounty.activity_id = v.activity_id
				AIData[id].bounty.next_fight_time = v.next_fight_time
			end
		end
	end
end

local function TeamPlayerAFK(id, pid)
	if not AIData[id] or not AIData[id].team then
		return false
	end

	local team = AIData[id].team
	for _, afk_pid in ipairs(team.afk_list) do
		if pid == afk_pid then
			return 
		end
	end

	table.insert(team.afk_list, pid)
end

local function TeamPlayerBackToTeam(id, pid)
	if not AIData[id] or not AIData[id].team then
		return false
	end

	local team = AIData[id].team
	local idx = 0
	for k, afk_pid in ipairs(team.afk_list) do
		if pid == afk_pid then
			idx = k
			break
		end
	end
	
	if idx > 0 then
		table.remove(team.afk_list, idx)
	end
end

local function AddTeam(id, teamid, group, leaderid, inplace_checking, mems, old, auto_confirm, auto_match, afk_list)
	if not AIData[id] then
		return
	end

	LoadBountyInfo(group, teamid, id)

	local target_fights = getTargetFights(group, teamid, id)
	if not AIData[id] then
		AI_DEBUG_LOG(string.format("AI %d has already unload, func AddTeam", id))
		return 
	end

	local battle_id = getTargetBattle(group)
	if battle_id > 0 then
		local _, sn = QueryTeamBattleTime(id, battle_id)
		saveValue[sn] = {id = id}
	end

	AIData[id].team = {
		teamid = teamid,
		group = group,
		leader = leaderid,
		inplace_checking = inplace_checking,
		members = mems,
		target_fights = target_fights,
		old = old,
		auto_confirm = auto_confirm,
		auto_match = auto_match,
		battle_begin_time = 0,
		battle_end_time = 0,
		afk_list = afk_list,
	}

	AIData[id].ai_auto_match = false 
end

function AIData.GetBattleTime(id)
	local team = AIData.GetTeam(id)
	if not team then
		AI_WARNING_LOG(string.format("AI %d get battle time fail , not has team", id))
		return 
	end

	AI_DEBUG_LOG(string.format("AI %d battle time count down %d,  end_time %d", id, team.battle_end_time - loop.now(), team.battle_end_time))
	return team.battle_begin_time, team.battle_end_time
end

function AIData.EnterBattle(id)
	if not AIData[id] then
		return 
	end
	
	local team = AIData.GetTeam(id)
	if not team then
		AI_DEBUG_LOG(string.format("AI %d fail to enter battle, not in a team", id))
		return 
	end

	if getBattleByGroup(team.group) == 0 then
		AI_DEBUG_LOG(string.format("AI %d fail to enter battle, not has battle", id))
		return 
	end

	EnterBattle(id, getBattleByGroup(team.group))
end

function AIData.GetBountyInfo(id)
	InitBountyData(id)

	return AIData[id].bounty
end

function AIData.CleanBountyInfo(id)
	if not AIData[id] then
		return 
	end

	AIData[id].bounty = nil	
end

function AIData.GetTeam(id, new)
	if not AIData[id] then
		return 
	end

	if not AIData[id].team or new then--or not AIData[id].team.teamid then	
		AIData[id].team = {}
		local _, sn = LoadTeam(id)
		saveValue[sn] = {id = id, new = new}
	end

	return (AIData[id].team and AIData[id].team.teamid) and AIData[id].team or nil
end

function AIData.SetLeader(id, leader)
	local team = AIData.GetTeam(id)
	if team then
		team.leader = leader
	end
end

function AIData.IsOldTeam(id)
	local team = AIData.GetTeam(id)
	if not team then
		return false
	end

	return team.old
end

local function transformTargetToGroup(target)
	local target_type = GetTargetType(target)
	if not target_type then
		AI_WARNING_LOG("transformTargetToGroup fail, cannt get target type")
		return nil
	end

	if target_type == "team_fight" then
		local cfg = BattleConfig.GetBattleConfig(target)

		if not cfg then
			return nil
		end

		return target--cfg.activity_id
	elseif target_type == "bounty" then
		return target 
	end

	--[[if target >= 1 and target <= 4 then
		return target + 19
	end	

	return nil--]]
end

function AIData.GetTargetStr(id)
	local target = AIData.GetTarget(id)
	if not target then
		return ""
	end

	local cfg = BattleConfig.GetBattleConfig(target)
	if not cfg then
		return "" 
	end

	return cfg.tittle_name
end

function AIData.TargetFitWithGroup(id)
	local target = AIData.GetTarget(id)
	if not target then
		AI_WARNING_LOG(string.format("AI %d check target fitwith group fail, not has target", id))
		return nil
	end

	local team = AIData.GetTeam(id)
	if not team or not team.group then
		AI_WARNING_LOG(string.format("AI %d check target fitwith group fail, not has group", id))
		return nil
	end

	local target_type = GetTargetType(target)
	if not target_type then
		AI_WARNING_LOG(string.format("AI %d check target fitwith group fail, cannt get target type", id))
		return nil
	end

	if target_type == "team_fight" then
		--[[local cfg = BattleConfig.GetBattleConfig(target)

		if not cfg then
			AI_WARNING_LOG(string.format("AI %d check target fitwith group fail, cfg is nil", id))
			return nil 
		end

		return cfg.activity_id == team.group--]]
		return target == team.group
	end

	if target_type == "bounty" then
		return target == team.group 
	end
end

function AIData.CreateTeam(id)
	if not AIData[id] then
		return
	end

	local target = AIData.GetTarget(id)
	if not target then
		AI_WARNING_LOG(string.format("AI %d create team fail, has not target", id))
		return false
	end

	local group = transformTargetToGroup(target)
	if not group then
		AI_WARNING_LOG(string.format("AI %d create team fail, group error", id))
		return false
	end

	local target_type = GetTargetType(target)
	local lower_limit = 0
	local upper_limit = 0
	if target_type == "team_fight" or target_type == "bounty" then
		local activity_cfg = BattleConfig.GetActivityConfig(target)
		if activity_cfg then
			lower_limit = activity_cfg.lv_limit
		end
	end

	local _, sn = CreateTeam(id, group, lower_limit, upper_limit)
	saveValue[sn] = {id = id, group = group}
end

function AIData.GetTeamLevelLimit(id)
	if not AIData[id] then
		return
	end

	local target = AIData.GetTarget(id)
	if not target then
		AI_WARNING_LOG(string.format("AI %d get team level limit, has not target", id))
		return false
	end

	local target_type = GetTargetType(target)
	local lower_limit = 0
	local upper_limit = 200 
	if target_type == "team_fight" or target_type == "bounty" then
		local activity_cfg = BattleConfig.GetActivityConfig(target)
		if activity_cfg then
			lower_limit = activity_cfg.lv_limit
		end
	end

	return lower_limit, upper_limit
end

function AIData.Chat(id, channel, message)
	AI_DEBUG_LOG(string.format("AI %d send chat message %s to channel %d", id, message, channel))
	Chat(id, channel, message)
end

function AIData.SetTeamGroup(id, group)
	local team = AIData.GetTeam(id)
	if not team then
		AI_WARNING_LOG(string.format("AI %d set team group fail , not has team", id))
		return false
	end

	team.group = group
end

function AIData.SetAutoMatch(id, auto_match)
	local team = AIData.GetTeam(id)
	if not team then
		AI_WARNING_LOG(string.format("AI %d set auto match fail , not has team", id))
		return false
	end

	team.auto_match = auto_match 
end

function AIData.TeamAutoMatch(id)
	if not AIData[id] then
		return 
	end

	local target = AIData.GetTarget(id)
	if not target then
		AI_WARNING_LOG(string.format("AI %d automatch team fail, has not target", id))
		return false
	end

	local group = transformTargetToGroup(target)
	if not group then
		AI_WARNING_LOG(string.format("AI %d automatch team fail, group error", id))
		return false
	end

	local _, sn = AITeamAutoMatch(id, true)
	AIData.SetAutoMatch(id, "loading")
	saveValue[sn] = {id = id}
end

function AIData.SetAutoConfirm(id, auto_confirm)
	local team = AIData.GetTeam(id)
	if not team then
		AI_WARNING_LOG(string.format("AI %d set auto confirm fail , not has team", id))
		return false
	end

	team.auto_confirm = auto_confirm 
end

function AIData.TeamAutoConfirm(id)
	if not AIData[id] then
		return
	end

	local target = AIData.GetTarget(id)
	if not target then
		AI_WARNING_LOG(string.format("AI %d autoconfirm fail, has not target", id))
		return false
	end

	local group = transformTargetToGroup(target)
	if not group then
		AI_WARNING_LOG(string.format("AI %d autoconfirm fail, group error", id))
		return false
	end

	local team = AIData.GetTeam(id)
	if not team then
		AI_WARNING_LOG(string.format("AI %d autoconfirm fail, not has team", id))
		return false
	end

	local _, sn = SetAutoConfirm(id, team.teamid)
	AIData.SetAutoConfirm(id, "loading")
	saveValue[sn] = {id = id}
end

function AIData.SetAILevel(id, level)
	if not AIData[id] then
		return 
	end

	AIData[id].level = level
end

function AIData.GetAILevel(id, force)
	if not AIData[id] then
		return 
	end

	if not AIData[id].level or force then
		local player = cell.getPlayerInfo(id)
		if player and player.level then
			AIData[id].level = player.level
		end
	end

	return AIData[id].level
end

function AIData.GetMode(id)
	if not AIData[id] then
		return
	end

	print("mode >>>>>>>>>>>>>>>>>>>>>>", AIData[id].mode)
	if AIData[id].mode then
		return AIData[id].mode ~= "loading" and AIData[id].mode or nil
	end

	local target = AIData.GetTarget(id)
	if not target then
		AI_WARNING_LOG(string.format("AI %d get mode fail, has not target", id))
		return false
	end

	local group = transformTargetToGroup(target)	
	if not group then
		AI_WARNING_LOG(string.format("AI %d get mode fail, group error", id))
		return false
	end

	local level = AIData.GetAILevel(id) or 0
	local _, sn = GetAutoMatchTeamCount(id, group, level)
	AIData[id].mode = "loading"
	saveValue[sn] ={id = id, group = group, level = level}
	return AIData[id].mode ~= "loading" and AIData[id].mode or nil
end

function AIData.ClearMode(id)
	if not AIData[id] then
		return
	end

	if AIData[id].mode then
		AIData[id].mode = nil
	end
end

function AIData.GetAIAutoMatchStatus(id)
	if AIData[id] then
		return AIData[id].ai_auto_match
	end

	return false
end

function AIData.AIAutoMatch(id)
	local target = AIData.GetTarget(id)
	if not target then
		AI_WARNING_LOG(string.format("AI %d auto match fail, has not target", id))
		return false
	end

	local group = transformTargetToGroup(target)
	if not group then
		AI_WARNING_LOG(string.format("AI %d auto match fail, group error", id))
		return false
	end
	
	local teamid = AIData.GetNotFinishAllFightTeam(group)
	AIAutoMatch(id, group, teamid)
	AIData[id].ai_auto_match = true
end

local function SetIsFighting(id, is_fighting)
	if not AIData[id] then
		return false
	end

	AIData[id].is_fighting = is_fighting 
end

local function SetLastFightResult(id, winner)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	if winner == 1 then
		AIData[id].last_fight_result = 1
	elseif winner == nil then
		AI_DEBUG_LOG("fffffffffff")
		AIData[id].last_fight_result = nil
	else
		AIData[id].last_fight_result = 0
	end
end

local function SetInplaceCheckingTime(id, time)
	if not AIData[id] or not AIData[id].team then
		return false
	end	

	local team = AIData[id].team
	team.inplace_checking = time
end

local function TeamMemberReady(id, pid, ready)
	if not AIData[id] or not AIData[id].team then
		return false
	end	

	local team = AIData[id].team

	if pid == 0 then
		for k, v in ipairs(team.members) do
			v.ready = ready
		end
		return true
	end

	local idx = PlayerIndex(team.members, pid)
	if not idx then
		AI_DEBUG_LOG(string.format("player %d not in ai team", pid))
		return false
	end
	team.members[idx].ready = ready
	AI_DEBUG_LOG(string.format("AI %d  member ready@@@@@@", id), sprinttb(team.members))
	
	return true
end

function AIData.StartFight(id, fight_id)
	if not AIData[id] then
		return false
	end

	if not fight_id then
		return false
	end

	local _, sn = StartFight(id, fight_id)
	saveValue[sn] = {id = id}

	return true 
end

function AIData.UpdateBountyInfo(id, quest, record, next_fight_time, activity_id, finish, winner)
	if not AIData[id] then
		return 
	end

	AI_DEBUG_LOG(string.format("AI %d start update bounty info", id))
	InitBountyData(id)
	AIData[id].bounty.quest_id = quest
	AIData[id].bounty.record = record
	AIData[id].bounty.next_fight_time = next_fight_time
	AIData[id].bounty.activity_id = activity_id
	AIData[id].bounty.finish = finish
	if finish then
		AIData[id].bounty.finish_round = AIData[id].bounty.finish_round + 1
	end
	if winner and winner == 1 then
		AIData[id].bounty.win_count = AIData[id].bounty.win_count + 1
	end

	if winner and winner ~= 1 and winner ~= -1 then
		AIData[id].bounty.lose_count = AIData[id].bounty.lose_count + 1
	end
	
end

function AIData.AddSteps(id, steps)
	InitBountyData(id)

	if steps == 0 then
		AIData[id].bounty.steps = 0
	else
		AIData[id].bounty.steps = AIData[id].bounty.steps + steps
	end
end

function AIData.AddStepsWithOutRealPlayer(id, steps)
	InitBountyData(id)

	if steps == 0 then
		AIData[id].bounty.steps_without_real_player = 0
	else
		AIData[id].bounty.steps_without_real_player = AIData[id].bounty.steps_without_real_player + steps
	end	
end

function AIData.GetNavigationProgress(id, idx)
	InitBountyData(id)

	AI_DEBUG_LOG(string.format("AI %d bounty >>>>>", id), sprinttb(AIData[id].bounty))
	return AIData[id].bounty.nav_idx
end

function AIData.UpdateNavigationProgress(id, idx)
	InitBountyData(id)
	
	AIData[id].bounty.nav_idx = idx 
end

function AIData.StartBountyQuest(id)
	AI_DEBUG_LOG(string.format("AI %d start to begin bounty quest", id))
	InitBountyData(id)

	local target = AIData.GetTarget(id)
	if not target then
		AI_WARNING_LOG(string.format("AI %d fail to start bounty quest, cannt get target",id))
		return nil
	end

	local _, sn= BountyStart(id, target)
	saveValue[sn] = {id = id}

	return nil
end

function AIData.StartBountyFight(id)
	AI_DEBUG_LOG(string.format("AI %d start bounty fight", id))

	local target = AIData.GetTarget(id)
	if not target then
		AI_WARNING_LOG(string.format("AI %d fail to start bounty fight, cannt get target",id))
		return nil
	end

	local _, sn = BountyFight(id, target)
	saveValue[sn] = {id = id}

	return nil
end


function AIData.IsFighting(id)
	if not AIData[id] then
		--AIData[id] =  {}
		return false
	end

	if not AIData[id].is_fighting then
		return false	
	else	
		return true 
	end
end

function AIData.GetLastFightResult(id)
	if not AIData[id] then
		--AIData[id] = {}
		return 
	end

	return AIData[id].last_fight_result
end

local function UpdateFightResult(id, fight_id, winner, not_attend)
	if not AIData[id] or not AIData[id].team then
		return false
	end

	local team = AIData[id].team	

	for k, v in ipairs(team.target_fights or {}) do
		if v.fight_id == fight_id then
			v.finish = (winner == 1 and 1 or 0)
			if not not_attend then
				v.fight_count = v.fight_count + 1
			end
			break
		end
	end

	team.fight_finish_time = loop.now()

	AIData[id].attend_fight_count = AIData[id].attend_fight_count or 0
	if not not_attend then
		AIData[id].attend_fight_count = AIData[id].attend_fight_count + 1
	end
end

function AIData.GetFightCount(id)
	if not AIData[id] then
		--AIData[id] =  {}
		return 0
	end	

	if not AIData[id].attend_fight_count then
		return 0
	end

	return AIData[id].attend_fight_count
end

function AIData.GetFightFinishTime(id)
	local team = AIData.GetTeam(id)

	if not team then
		return nil
	end

	return team.fight_finish_time
end

function AIData.GetNextFight(id)
	local team = AIData.GetTeam(id)

	if not team then
		return false, "has no team"
	end

	if not team.target_fights or #team.target_fights == 0 then
		return false, "no target fight" 
	end 

	for k, v in ipairs(team.target_fights) do 
		if v.finish == 0 and v.fight_count <= 2 then 
			return v.fight_id 
		elseif v.finish == 0 and v.fight_count > 2 then 
			return false, "battle fail" 
		end	
	end 

	return false, "battle finish" 
end

function AIData.NextFightIsStory(id)
	local next_fight_id = AIData.GetNextFight(id)
	if not next_fight_id then
		return false
	end

	local cfg = BattleConfig.Get(next_fight_id)
	if not cfg then
		return false
	end

	return cfg.is_fight_npc == 0
end

function AIData.FindNpc(id)
	local fight_id = AIData.GetNextFight(id)	
	if fight_id then
		--UpdateFightResult(id, fight_id, 1)
		--[[local story_id = fight_id
		AIData.TeamSync(id, TEAM_SYNC_COMMAND_TRIGGER_STORY, {story_id})--]]

		FindNpc(id, fight_id)
	end
end

function AIData.TriggerStory(id)
	local fight_id = AIData.GetNextFight(id)	
	if fight_id then
		local cfg = BattleConfig.Get(fight_id)
		if not cfg then
			AI_WARNING_LOG(string.format("Trigger story fail , cannt find fight_cfg for %d", fight_id))
			return 
		end
		AIData.TeamSync(id, TEAM_SYNC_COMMAND_TRIGGER_STORY, {cfg.story_id})
	end
end

local function DeleteTeam(id)
	if AIData[id] and AIData[id].team then
		AIData[id].team = nil	
	end

	if AIData[id] and AIData[id].is_fighting then
		AIData[id].is_fighting = nil
	end

	if AIData[id] and AIData[id].has_kick_ai then
		AIData[id].has_kick_ai = nil
	end

	if AIData[id] and AIData[id].dissolve_team_time_line then
		AIData[id].dissolve_team_time_line = nil
	end

	if AIData[id] and AIData[id].shout_time_line then
		AIData[id].shout_time_line = nil
	end

	if AIData[id] and AIData[id].dissolve_team_time_line_when_all_ai then
		AIData[id].dissolve_team_time_line_when_all_ai = nil
	end
end

function AIData.SetDissolveTeamTimeLine(id)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	AIData[id].dissolve_team_time_line = loop.now() + 20 * 60
end

function AIData.ClearDissolveTeamTimeLine(id)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	if AIData[id].dissolve_team_time_line then
		AIData[id].dissolve_team_time_line = nil
	end
end

function AIData.GetDissolveTeamTimeLine(id)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	return AIData[id].dissolve_team_time_line
end

function AIData.SetDissolveTeamTimeLineWhenAllAI(id)
	if not AIData[id] then
		return
	end

	AIData[id].dissolve_team_time_line_when_all_ai = loop.now() + math.random(1, 5) * 60
end

function AIData.ClearDissolveTeamTimeLineWhenAllAI(id)
	if not AIData[id] then
		return
	end

	if AIData[id].dissolve_team_time_line_when_all_ai then
		AIData[id].dissolve_team_time_line_when_all_ai = nil
	end
end

function AIData.GetDissolveTeamTimeLineWhenAllAI(id)
	if not AIData[id] then
		return
	end

	return AIData[id].dissolve_team_time_line_when_all_ai
end

function AIData.CleanOldData(id)
	LeaveTeam(id)
	DeleteTeam(id)
	--AI_DEBUG_LOG(string.format("AI %d clean old data", id))
end

function AIData.TeamHasRealPlayer(id)
	local team = AIData.GetTeam(id)
	if not team then
		AI_WARNING_LOG(string.format("AI %d fail to check team has real player, not has team", id))
		return nil
	end

	for k, v in ipairs(team.members or {}) do
		if v.pid > AI_MAX_ID then
			return true
		end
	end	

	return false
end

local BEGIN_TASK_CD = 10
function AIData.SetBeginTaskTime(id)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	AIData[id].begin_task_time = loop.now() + BEGIN_TASK_CD 
end

function AIData.CleanBeginTaskTime(id)
	if AIData[id] and AIData[id].begin_task_time then
		AIData[id].begin_task_time = nil
	end
end

function AIData.GetBeginTaskTime(id)
	return AIData[id] and AIData[id].begin_task_time or nil
end

function AIData.SetDeadlineTime(id)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	AIData[id].deadline_time = loop.now() + 60
end

function AIData.CleanDeadlineTime(id)
	if AIData[id] and AIData[id].deadline_time then
		AIData[id].deadline_time = nil
	end
end

function AIData.GetDeadlineTime(id)
	return AIData[id] and AIData[id].deadline_time or nil
end

function AIData.LeaveTeam(id, kicked_id)
	if kicked_id then
		LeaveTeam(id, kicked_id)
		--DeleteTeam(kicked_id)	
	else
		LeaveTeam(id)
		--DeleteTeam(id)
	end	
end

function AIData.DissolveTeam(id)
	DissolveTeam(id)
	--DeleteTeam(id)
end

function AIData.ChangeLeader(id)
	local team = AIData.GetTeam(id)
	local new_leader 
	local max_level = 0
	for k, v in ipairs(team.members or {}) do
		if v.level > max_level then
			new_leader = v.pid
			max_level = v.level
		end
	end
	ChangeLeader(id, new_leader)		
end

local function AddTeamMember(id, member, level)
	--[[if not AIData[id] or not AIData[id].team then
		return false
	end--]]
	local team = AIData.GetTeam(id)
	if not team then
		return false
	end

	--local team = AIData[id].team
	--if team and team.members then
	if team and team.members then
		local idx = PlayerIndex(team.members, member)
		if not idx then
			table.insert(team.members, {pid = member, level = level, ready = 0})	
		end
	else
		table.insert(team.members, {pid = member, level = level, ready = 0})	
	end
	--end
end

local function DeleteTeamMember(id, pid, opt_pid)
	if not AIData[id] or not AIData[id].team then
		return false
	end

	local team = AIData[id].team
	local idx = PlayerIndex(team.members, pid)
	if idx then
		table.remove(team.members, idx)
	end

	if id == pid and opt_pid ~= pid then--(team.leader and team.leader ~= id) then
		AI_DEBUG_LOG(string.format("AI %d be kicked", id), "opt_pid", opt_pid)
		AIData[id].kicked = true
	end

	if id == pid then
		DeleteTeam(id)
	end
end

function AIData.IsKicked(id)
	if not AIData[id] or not AIData[id].kicked then
		return false
	end

	AI_DEBUG_LOG(string.format("AI %d is kicked", id), AIData[id].kicked)
	return AIData[id].kicked == true
end

function AIData.SetHasKickAI(id, kick)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end	

	AIData[id].has_kick_ai = kick
end

function AIData.HasKickAI(id)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	return AIData[id].has_kick_ai
end

function AIData.SetHasKickUnactiveMember(id, kick)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end	

	AIData[id].has_kick_unactive_member = kick
end

function AIData.GetHasKickUnactiveMember(id)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	return AIData[id].has_kick_unactive_member
end

function AIData.GetTeamMemberCount(id)
	local team = AIData.GetTeam(id)
	if not team then
		return false
	end 

	return #team.members
end

function AIData.GetReadyMemberCount(id)
	if not AIData[id] or not AIData[id].team then
		return false
	end	

	local team = AIData[id].team

	local count = 0
	for k, v in ipairs(team.members) do
		if v.ready == 1 then
			count = count + 1
		end
	end

	return count 
end

function AIData.AllMembersReady(id)
	if not AIData[id] or not AIData[id].team then
		return false
	end	

	local team = AIData[id].team

	for k, v in ipairs(team.members) do
		if v.ready  ~= 1 then
			return false
		end
	end

	return true
end

function AIData.GetInplaceCheckingTime(id)
	if not AIData[id] or not AIData[id].team then
		return nil 
	end

	local team = AIData[id].team
	return team.inplace_checking
end

function AIData.SetInplaceCheckingTime(id, t)
	SetInplaceCheckingTime(id, t)
end

function AIData.IsInplaceChecking(id)
	if not AIData[id] or not AIData[id].team then
		return false
	end	

	local team = AIData[id].team
	return loop.now() - team.inplace_checking < INPLACE_CHECK_LAST_TIME + 10
end

function AIData.InplaceCheck(id)
	if not AIData[id] or not AIData[id].team then
		return false
	end

	TeamMemberReady(id, 0, 0)

	local fight, err = AIData.GetNextFight(id)
	if not fight then
		AI_WARNING_LOG(string.format("AI %d fail to Inplace check , next fight_id is nil", Id))
		return
	end

	InplaceCheck(id, AIData[id].team.teamid, fight)
	SetInplaceCheckingTime(id, loop.now())
	AI_DEBUG_LOG(string.format("AI %d inplace ready", id))
	--InplaceReady(id, AIData[id].team.teamid, 1, 1)
end

function AIData.NeedToInplaceReady(id)
	if not AIData[id] then
		return false
	end

	if not AIData[id].has_inplace_check then
		return false
	end

	return AIData[id].has_inplace_check
end

function AIData.SetHasInplaceCheck(id)
	if not AIData[id] then
		return
	end

	AIData[id].has_inplace_check = true
end

function AIData.CancelInplaceCheck(id)
	if not AIData[id] then
		return
	end

	AIData[id].has_inplace_check = nil 
end

function AIData.InplaceReady(id)
	if not AIData[id] or not AIData[id].team then
		return false
	end

	AI_DEBUG_LOG(string.format("AI %d inplace ready", id))
	InplaceReady(id, AIData[id].team.teamid, 1, 1)
	AIData.CancelInplaceCheck(id)
end

local function CreateRollGame(id, game_id, reward_count)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	AIData[id].roll_game = {game_id = game_id, reward_count = reward_count, has_roll = false}
end

function AIData.GetRollGame(id)
	if not AIData[id] then
		return nil
	end

	return AIData[id].roll_game
end

function AIData.DeleteRollGame(id)
	if AIData[id] and AIData[id].roll_game then
		AIData[id].roll_game = nil
	end
end

function AIData.GetRewardCount(id)
	local game = AIData.GetRollGame(id)
	if not game then
		return 0
	end	

	return game.reward_count
end

function AIData.Roll(id, idx)
	local game = AIData.GetRollGame(id)	
	if game then
		Roll(id, game.game_id, idx, true)	
		game.has_roll = true
	end

	--DeleteRollGame(id)
end

function AIData.AIHasRoll(id)
	local game = AIData.GetRollGame(id)	
	if not game then
		return true
	end

	return game.has_roll
end

function AIData.SetShoutTimeLine(id, interval)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	local t = os.date("*t", loop.now())
	AI_DEBUG_LOG(string.format("AI %d SetShoutTimeLine interval:%d   %d-%d-%d %d:%d:%d", id, interval, t.year, t.month, t.day, t.hour, t.min, t.sec))
	AIData[id].shout_time_line = loop.now() + interval	
end

function AIData.CancelShoutTimeLine(id)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	AIData[id].shout_time_line = nil	
end

function AIData.GetShoutTimeLine(id)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	return AIData[id].shout_time_line 
end

function AIData.GetMoveCount(id)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	if not AIData[id].move_count then
		AIData[id].move_count = 0
	end

	return AIData[id].move_count
end

function AIData.SetMoveCount(id, count)
	if not AIData[id] then
		--AIData[id] = {}
		return
	end

	if not AIData[id].move_count then
		AIData[id].move_count = 0
	end

	AIData[id].move_count = count
end

function AIData.GetEnterFreeMoveMapTime(id)
	if not AIData[id] then
		return nil
	end

	return AIData[id].enter_free_move_map_time
end

function AIData.SetEnterFreeMoveMapTime(id)
	if not AIData[id] then
		return 
	end

	AIData[id].enter_free_move_map_time = loop.now()
end

function AIData.GetCurrentStep(id)
	if not AIData[id] then
		return 
	end

	local target = AIData.GetTarget(id)
	if not target then
		return 
	end

	local target_type = GetTargetType(target)
	if target_type ~= "main_quest" then
		return 
	end

	if not AIData[id].main_quest_id then
		AIData[id].main_quest_id = 1
	end

	return AIData[id].main_quest_id
end

function AIData.SetNextStep(id, next_step)
	if not AIData[id] then
		return 
	end

	local target = AIData.GetTarget(id)
	if not target then
		return 
	end

	local target_type = GetTargetType(target)
	if target_type ~= "main_quest" then
		return 
	end

	AIData[id].main_quest_id = next_step
end

function AIData.UpdateVote(id, candidate)
	if not AIData[id] then
		print("update candidate fail >>>>>>>>>>>>>>>>>")
		return
	end

	print("%%%%%%%%%%%%%", candidate)
	AIData[id].candidate = candidate
end

function AIData.RemoveVote(id)
	if not AIData[id] then
		return 
	end

	AIData[id].candidate = 0
end

function AIData.Init(id)
	if not AIData[id] then
		AIData[id] = {}
	end
end

function AIData.GetVote(id)
	if not AIData[id] then
		print(string.format("AI %d GetVote fail>>>>>>>>>>>",id))
		return 
	end

	print("AIData candidate>>>>>>>>>>>>", AIData[id].candidate)
	return AIData[id].candidate
end

function AIData.Vote(id, candidate, agree)
	if not AIData[id] then
		return
	end

	Vote(id, candidate, agree)
end

function AIData.AddJoinRequest(id, pid, level)
	if not AIData[id] then
		return 
	end

	AIData[id].join_request = AIData[id].join_request or {}
	table.insert(AIData[id].join_request, {pid = pid, level = level})
end

function AIData.GetJoinRequest(id)
	if not AIData[id] then
		return false
	end

	return AIData[id].join_request
end

function AIData.ConfirmJoinRequest(id)
	if not AIData[id] then
		return 
	end

	local total_level = 0
	local team = AIData.GetTeam(id)
	if not team then
		AIData[id].join_request = nil
		return
	end

	for k, v in ipairs(team.members or {}) do
		total_level = total_level + v.level	
	end

	if total_level == 0 or not team.members or #(team.members) == 0 then
		AIData[id].join_request = nil
		return
	end

	local average_level = math.floor(total_level / #(team.members))
	AI_DEBUG_LOG(string.format("AI %d team average level is %d", id, average_level))	

	for k, v in ipairs(AIData[id].join_request or {}) do
		if v.level >= average_level - 30 and v.level <= average_level + 30 then
			ConfirmJoinRequest(id, v.pid , true)
		end
	end

	AIData[id].join_request = nil
end

function AIData.Unload(id)
	AI_DEBUG_LOG(string.format("AI %d unload data", id))
	if AIData[id] then
		AIData[id] = nil
	end
end

local boss_pos_cfg = {
	[11001] = {mapid = 15, x = -1, y = 0, z = 0},
	[12001] = {mapid = 15, x =  1, y = 0, z = 0},
	[13001] = {mapid = 15, x =  0, y = 1, z = 0},
	[14001] = {mapid = 15, x =  0, y = 2, z = 0},
	[15001] = {mapid = 15, x =  0, y = -2, z = 0},
}
function GetFightPos(fight_id)
	local fight_cfg = BattleConfig.Get(fight_id)
	if not fight_cfg then
		AI_WARNING_LOG(string.format("GetFightPos fail for fight %d, fight_cfg is nil", fight_id))
		return nil
	end

	local npc_cfg = BattleConfig.GetNpcConfig(fight_cfg.monster_id)
	if not npc_cfg then
		AI_WARNING_LOG(string.format("GetFightPos fail for fight %d, npc_cfg is nil", fight_id))
		return nil
	end

	return npc_cfg.mapid, {x = npc_cfg.Position_x, y = npc_cfg.Position_z, z = npc_cfg.Position_y}

	--[[if not boss_pos_cfg[fight_id] then
		log.error(string.format("boss pos cfg is nil for fight %d", fight_id))
		return nil
	end
	return boss_pos_cfg[fight_id].mapid, {x = boss_pos_cfg[fight_id].x, y = boss_pos_cfg[fight_id].y , z = boss_pos_cfg[fight_id].z}--]]
end


function AIData.RegisterCommand(service)
	--NOTIFY
	DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_TEAM_PLAYER_ENTER_REQUEST, function(cmd, channel, request)
		local id = request.id
		local teamid = request.teamid
		local pid = request.pid 	
		local level = request.level

		--EventList.Push(id, function()
			AI_DEBUG_LOG(string.format("AI %d Enter player %d", id, pid, teamid, level))
			if id == pid then
				AIData.GetTeam(id, true)
			else	
				AddTeamMember(id, pid, level)
				
				--如果加入使队伍人数超过三人则改变has_kick_ai的值
				local mem_count = AIData.GetTeamMemberCount(id)
				if mem_count and mem_count >= 3 then
					AIData.SetHasKickAI(id, false)
					SetLastFightResult(id, nil)	
				end
				
				AIData.ClearDissolveTeamTimeLineWhenAllAI(id)
				if pid > AI_MAX_ID then
					--AIData.CleanDeadlineTime(id)
				end
			end
		--end)
	end)
	service:on(Command.S_NOTIFY_AI_TEAM_PLAYER_ENTER_REQUEST, "NotifyAITeamPlayerEnterRequest", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_TEAM_PLAYER_ENTER_REQUEST, channel, request)
	end)

	DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_TEAM_PLAYER_LEAVE_REQUEST, function(cmd, channel, request)
		local id = request.id
		local teamid = request.teamid
		local pid = request.pid 	
		local opt_pid = request.opt_pid
		local x = request.x
		local y = request.y
		local z = request.z
		local mapid = request.mapid
		local channel = request.channel
		local room = request.room

		--EventList.Push(id, function()
			AI_DEBUG_LOG(string.format("AI %d NotifyAITeamPlayerLeave leave player %d", id, pid), x, y, z, mapid, channel, room)
			DeleteTeamMember(id, pid, opt_pid)
			if id == pid and mapid > 0 then
				AI_DEBUG_LOG(string.format("AI %d leave team, leader pos", id), x, y, z, mapid, channel, room)
				AIData.MapMove(id, x, y, z, mapid, channel, room)
			end
		
			--assert(id ~= nil, err_log("notify player leave, id is nil", request.id, id, pid))
			local mem_count = AIData.GetTeamMemberCount(id)
			if (AIData.TeamHasRealPlayer(id) == false) or (mem_count and mem_count < 2) then
				AIData.CleanBeginTaskTime(id)
			end
		--end)
	end)
	service:on(Command.S_NOTIFY_AI_TEAM_PLAYER_LEAVE_REQUEST, "NotifyAITeamPlayerLeaveRequest", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_TEAM_PLAYER_LEAVE_REQUEST, channel, request)
	end)

	DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_TEAM_PLAYER_READY_REQUEST, function(cmd, channel, request)
		local id = request.id
		local teamid = request.teamid
		local pid = request.pid 	
		local ready = request.ready 	

		--EventList.Push(id, function()
			AI_DEBUG_LOG(string.format("AI %d  player %d inplace ready", id, pid))
			TeamMemberReady(id, pid, ready)
			--Dispatch(id, "MEMBER_READY")
		--end)
	end)
	service:on(Command.S_NOTIFY_AI_TEAM_PLAYER_READY_REQUEST, "NotifyAITeamPlayerReadyRequest", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_TEAM_PLAYER_READY_REQUEST, channel, request)
		local cmd = Command.S_NOTIFY_AI_TEAM_PLAYER_READY_RESPOND;
		local proto = "aGameRespond";
	end)

	DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_TEAM_FIGHT_FINISH_REQUEST, function(cmd, channel, request)
		local id = request.id
		local winner = request.winner
		local fight_id = request.fight_id

		--EventList.Push(id, function()
			SetIsFighting(id, false)
			SetLastFightResult(id, winner)
			AI_DEBUG_LOG(string.format("AI %d  Fight finish>>>>>>>>>>>>>>>", id), winner)
			UpdateFightResult(id, fight_id, winner)
			-- 防止在战斗过程中加入AI导致该AI的队伍进度没有更新这场战斗需要遍历每一个成员
			--[[local team = AIData.GetTeam(id)
			if team then
				for k, v in ipairs(team.members) do
					if v.pid < 100000 and v.pid ~= id then
						UpdateFightResult(v.pid, fight_id, winner, true)
					end
				end
			end--]]
		--end)
		--Dispatch(id, "FIGHT_FINISH", winner, fight_id)
	end)
	service:on(Command.S_NOTIFY_AI_TEAM_FIGHT_FINISH_REQUEST, "NotifyAITeamFightFinishRequest", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_TEAM_FIGHT_FINISH_REQUEST, channel, request)
	end)

	--[[service:on(Command.S_NOTIFY_AI_BOUNTY_FIGHT_FINISH_REQUEST, "NotifyAIBountyFightFinish", function(conn, channel, request) 
		local id = request.id
		local winner = request.winner
		local fight_id = request.fight_id
		local count = request.count

		
		SetIsFighting(id, false)
		--UpdateBountyFightResult(id, fight_id, winner)
	end)--]]

	DataThread.getInstance():AddListener(Command.S_NOTIFY_ROLL_GAME_CREATE, function(cmd, channel, request)
		local id = request.id
		local game_id = request.game_id
		local reward_count = request.reward_count
		
		--EventList.Push(id, function()
			CreateRollGame(id, game_id, reward_count)
		--end)
	end)
	service:on(Command.S_NOTIFY_ROLL_GAME_CREATE, "NotifyAIRollGameCreate", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_ROLL_GAME_CREATE, channel, request)
	end)

	DataThread.getInstance():AddListener(Command.S_NOTIFY_ROLL_GAME_FINISH, function(cmd, channel, request)
		local id = request.id
		local game_id = request.game_id

		--EventList.Push(id, function()
			--DeleteRollGame(id, game_id)
		--end)

	end)
	service:on(Command.S_NOTIFY_ROLL_GAME_FINISH, "NotifyAIRollGameFinish", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_ROLL_GAME_FINISH, channel, request)
	end)

	DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_TEAM_FIGHT_START, function(cmd, channel, request)
		local id = request.id
		--EventList.Push(id, function()
			SetInplaceCheckingTime(id, 0)
		--end)
	end)
	service:on(Command.S_NOTIFY_AI_TEAM_FIGHT_START, "NotifyAITeamFightStart", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_TEAM_FIGHT_START, channel, request)
	end)

	DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_TEAM_INPLACE_CHECK, function(cmd, channel, request)
		local id = request.id
		SetInplaceCheckingTime(id, loop.now())
		TeamMemberReady(id, 0, 0)

		AIData.SetHasInplaceCheck(id)
		--AIData.InplaceReady(id)
	end)
	service:on(Command.S_NOTIFY_AI_TEAM_INPLACE_CHECK, "NotifyAITeamInplaceCheck", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_TEAM_INPLACE_CHECK, channel, request)
	end)
	
	DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_TEAM_LEADER_CHANGE, function(cmd, channel, request)
		local id = request.id
		local leader = request.leader
		local x = request.x
		local y = request.y
		local z = request.z
		local mapid = request.mapid
		local channel = request.channel
		local room = request.room
		assert(leader ~= nil, err_log("Leader Change >>>>>>>>>"))
		--EventList.Push(id, function()
			AIData.SetLeader(id, leader)
			if id == leader then
				AI_DEBUG_LOG(string.format("AI %s change pos, because ai become leader map:%d x:%d y:%d z:%d channel:%d room:%d", id, mapid, x, y, z, channel, room))
				if mapid > 0 then
					AIData.MapMove(id, x, y, z, mapid, channel, room)
				end
			end
		--end)
	end)
	service:on(Command.S_NOTIFY_AI_TEAM_LEADER_CHANGE, "NotifyAITeamLeaderChange", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_TEAM_LEADER_CHANGE, channel, request)
	end)

	DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_TEAM_GROUP_CHANGE, function(cmd, channel, request)
		local id = request.id
		local group = request.grup
		--EventList.Push(id, function()
			AIData.SetTeamGroup(id, group)
		--end)
	end)
	service:on(Command.S_NOTIFY_AI_TEAM_GROUP_CHANGE, "NotifyAITeamGroupChange", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_TEAM_GROUP_CHANGE, channel, request)
	end)

	DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_BOUNTY_CHANGE, function(cmd, channel, request)
		local id = request.id
		local quest = request.quest
		local record = request.record
		local next_fight_time = request.next_fight_time
		local activity_id = request.activity_id
		local finish = request.finish
		local winner = request.winner
		--EventList.Push(id, function()
			--AI_DEBUG_LOG("bounty change>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>", id, quest, record, next_fight_time, activity_id, tostring(finish), winner)
			if winner == -1 then
				AIData.UpdateBountyInfo(id, quest, record, next_fight_time, activity_id, finish, nil)
			else
				SetIsFighting(id, false)
				SetLastFightResult(id, winner)
				AIData.UpdateBountyInfo(id, quest, record, next_fight_time, activity_id, finish, winner)
			end
		--end)
	end)
	service:on(Command.S_NOTIFY_AI_BOUNTY_CHANGE, "NotifyAIBountyChange", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_BOUNTY_CHANGE, channel, request)
	end)

	DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_PLAYER_APPLY_TO_BE_LEADER, function(cmd, channel, request)
		local id = request.id
		local candidate = request.candidate
		AIData.UpdateVote(id, candidate)
	end)
	service:on(Command.S_NOTIFY_AI_PLAYER_APPLY_TO_BE_LEADER, "NotifyAIPlayerApplyToBeLeader", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_PLAYER_APPLY_TO_BE_LEADER, channel, request)
	end)

	DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_NEW_JOIN_REQUEST, function(cmd, channel, request)
		local id = request.id
		local pid = request.pid
		local level = request.level

		AI_DEBUG_LOG(string.format("AI %d has join request from player %d", id, pid))
		AIData.AddJoinRequest(id, pid, level)
	end)
	service:on(Command.S_NOTIFY_AI_NEW_JOIN_REQUEST, "NotifyAINewJoinRequest", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_NEW_JOIN_REQUEST, channel, request)
	end)

	DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_TEAM_AUTO_MATCH_CHANGE, function(cmd, channel, request)
		local id = request.id
		local auto_match = request.auto_match

		AI_DEBUG_LOG(string.format("AI %d s team auto_match change %s", id, tostring(auto_match)))
		AIData.SetAutoMatch(id, auto_match)	
	end)
	service:on(Command.S_NOTIFY_AI_TEAM_AUTO_MATCH_CHANGE, "NotifyAITeamAutoMatchChange", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_TEAM_AUTO_MATCH_CHANGE, channel, request)
	end)

	DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_BATTLE_TIME_CHANGE, function(cmd, channel, request)
		local id = request.id
		local battle_begin_time = request.battle_begin_time
		local battle_end_time = request.battle_end_time

		AI_DEBUG_LOG(string.format("AI %d team battle time change begin_time %d end_time %d", id, battle_begin_time, battle_end_time))
		if AIData[id] and AIData[id].team then
			AIData[id].team.battle_begin_time = battle_begin_time
			AIData[id].team.battle_end_time = battle_end_time
		end
	end)
	service:on(Command.S_NOTIFY_AI_BATTLE_TIME_CHANGE, "NotifyAIBattleTimeChange", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_BATTLE_TIME_CHANGE, channel, request)
	end)

	--[[DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_TEAM_PLAYER_AFK, function(cmd, channel, request)
		local id = request.id
		local pid = request.pid 	

		AI_DEBUG_LOG(string.format("AI %d player %d afk", id, pid))
		TeamPlayerAFK(id, pid)
	end)
	service:on(Command.S_NOTIFY_AI_TEAM_PLAYER_AFK, "NotifyAITeamPlayerAFK", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_TEAM_PLAYER_AFK, channel, request)
	end)

	DataThread.getInstance():AddListener(Command.S_NOTIFY_AI_TEAM_PLAYER_BACK_TO_TEAM, function(cmd, channel, request)
		local id = request.id
		local pid = request.pid 	

		AI_DEBUG_LOG(string.format("AI %d player %d back to team", id, pid))
		TeamPlayerBackToTeam(id, pid)
	end)
	service:on(Command.S_NOTIFY_AI_TEAM_PLAYER_BACK_TO_TEAM, "NotifyAITeamPlayerBackToTeam", function(conn, channel, request) 
		DataThread.getInstance():SendMessage(Command.S_NOTIFY_AI_TEAM_PLAYER_BACK_TO_TEAM, channel, request)
	end)--]]

	-- RESPOND
	DataThread.getInstance():AddListener(Command.S_MAP_QUERY_POS_RESPOND, function(cmd, channel, respond)
		local sn = respond.sn
		local result = respond.result
		local mapid = respond.mapid
		local x = respond.x
		local y = respond.y
		local z = respond.z
		local channel = respond.channel
		local room = respond.room
		local id = saveValue[sn]

		if not id or not AIData[id] then
			saveValue[sn] = nil
			return
		end

		if result and result == Command.RET_SUCCESS then
			UpdatePos(id, mapid, x, y, z, channel, room)
		end
		--AIData[id].pos = {mapid = mapid, x = x, y = y, z = z, channel = channel, room = room}
		--AI_DEBUG_LOG("*******update pos >>>>>>>>>>>>>>>>>>>>>", id, mapid, x, y, z, channel, room)
		saveValue[sn] = nil
	end)

	DataThread.getInstance():AddListener(Command.S_MAP_MOVE_RESPOND, function(cmd, channel, respond)
		local sn = respond.sn
		local result = respond.result
		local sv = saveValue[sn]
		local id = sv.id
		local x = sv.x
		local y = sv.y
		local z = sv.z
		local mapid = sv.mapid
		local channel = sv.channel
		local room = sv.room

		if not id or not AIData[id] then
			saveValue[sn] = nil
			return
		end
		
		AI_DEBUG_LOG(string.format("AI %d move ", id), x, y, z, mapid, channel, room)
		if result and result == Command.RET_SUCCESS then
			local team = AIData.GetTeam(id)
			if team and team.leader == id then
				local pos = AIData.GetPos(id)	
				if pos and ((pos.mapid ~= mapid and mapid ~= nil) or (pos.channel ~= channel and channel ~= nil) or (pos.room ~= room and room ~= nil)) then
					AIData.TeamSync(id, TEAM_SYNC_COMMAND_CHANGE_MAP, {mapid, pos.channel ~= channel and channel or pos.channel, pos.room ~= room and room or pos.room})
				end
			end

			print("MOVE RESPOND",   mapid, channel, room)
			UpdatePos(id, mapid, x, y, z, channel, room)
		elseif result and result == Command.RET_CHANNEL_INVALID then
			local o_mid, o_ch, o_rm
			if AIData[id].pos and AIData[id].pos.mapid then
				o_mid = AIData[id].pos.mapid
			end

			if AIData[id].pos and AIData[id].pos.channel then
				o_ch = AIData[id].pos.channel
			end

			if AIData[id].pos and AIData[id].pos.room then
				o_rm = AIData[id].pos.room
			end

			local _, sn2 = MapMove(id, x, y, z, mapid or o_mid, channel or o_ch, room or o_rm)
			saveValue[sn2] = {id = id, x = x, y = y, z = z, mapid = mapid or o_mid, channel = channel or o_ch, room = room or o_rm}
		end

		saveValue[sn] = nil
	end)

	DataThread.getInstance():AddListener(Command.S_TEAM_QUERY_INFO_RESPOND, function(cmd, channel, respond)
		local sn = respond.sn
		local result = respond.result
		local sv = saveValue[sn]
		local id = sv.id
		local new = sv.new

		if not id or not AIData[id] then
			saveValue[sn] = nil
			return
		end

		if result and result == Command.RET_SUCCESS then
			local t = {} 
			for k, v in ipairs(respond.members) do
				table.insert(t, {pid = v.pid, ready = v.ready, level = v.level})
			end
			local old = true
			if new then 
				old = false
			end
			AddTeam(id, respond.teamid, respond.grup, respond.leader, respond.inplace_checking - INPLACE_CHECK_LAST_TIME, t, old, respond.auto_confirm, respond.auto_match, respond.afk_list)
		end
		
		saveValue[sn] = nil
	end)

	DataThread.getInstance():AddListener(Command.S_TEAM_CREATE_RESPOND, function(cmd, channel, respond)
		local sn = respond.sn
		local result = respond.result
		local sv = saveValue[sn]
		local id = sv.id
		local group = sv.group

		if not id or not AIData[id] then
			saveValue[sn] = nil
			return
		end

		if result and result == Command.RET_SUCCESS then
			AddTeam(id, respond.teamid, group, id, 0, {{pid = id, ready = 0, level = 0}}, false, false, false, {})
		end
		
		saveValue[sn] = nil
	end)

	DataThread.getInstance():AddListener(Command.S_TEAM_SET_AUTO_CONFIRM_RESPOND, function(cmd, channel, respond)
		local sn = respond.sn
		local result = respond.result
		local sv = saveValue[sn]
		local id = sv.id

		if not id or not AIData[id] then
			saveValue[sn] = nil
			return
		end

		if result and result == Command.RET_SUCCESS then
			AIData.SetAutoConfirm(id, true)	
		else
			AIData.SetAutoConfirm(id, false)	
		end	
		
		saveValue[sn] = nil
	end)

	DataThread.getInstance():AddListener(Command.S_AI_TEAM_AUTOMATCH_RESPOND, function(cmd, channel, respond)
		local sn = respond.sn
		local result = respond.result
		local sv = saveValue[sn]
		local id = sv.id

		if not id or not AIData[id] then
			saveValue[sn] = nil
			return
		end

		if result and result == Command.RET_SUCCESS then
			AIData.SetAutoMatch(id, true)	
			local team = AIData.GetTeam(id)
			if team then
				AIData.AddAutoMatchTeams(team.teamid, team.group)
			end
		else	
			AIData.SetAutoMatch(id, false)	
		end
		
		saveValue[sn] = nil
	end)

	DataThread.getInstance():AddListener(Command.S_TEAM_START_ACTIVITY_FIGHT_RESPOND, function(cmd, channel, respond)
		local sn = respond.sn
		local result = respond.result
		local sv = saveValue[sn]
		local id = sv.id

		if not id or not AIData[id] then
			saveValue[sn] = nil
			return
		end

		if result and result == Command.RET_SUCCESS then
			SetInplaceCheckingTime(id, 0)
			TeamMemberReady(id, 0, 0)
			SetIsFighting(id, true)
		end
		
		saveValue[sn] = nil
	end)

	DataThread.getInstance():AddListener(Command.S_GET_AUTOMATCH_TEAM_COUNT_RESPOND, function(cmd, channel, respond)
		local sn = respond.sn
		local result = respond.result
		local sv = saveValue[sn]
		local id = sv.id
		local group = sv.group
		local level = sv.level

		if not id or not AIData[id] then
			saveValue[sn] = nil
			return
		end

		if result and result == Command.RET_SUCCESS then
			local team_count = respond.count
			AI_DEBUG_LOG(string.format("AI %d GetTeamCount, group %d, level %d, count:%d", id, group, level, team_count))
			if team_count < 1 then
				AIData[id].mode = "leader" 
			else
				AIData[id].mode = "member" 
			end
		else
			AIData[id].mode = nil
		end	

		saveValue[sn] = nil
	end)

	DataThread.getInstance():AddListener(Command.S_BOUNTY_START_RESPOND, function(cmd, channel, respond)
		local sn = respond.sn
		local result = respond.result
		local sv = saveValue[sn]
		local id = sv.id

		if not id or not AIData[id] then
			saveValue[sn] = nil
			return
		end

		if result and result ~= Command.RET_SUCCESS then
			AI_WARNING_LOG(string.format("AI %d fail to start bounty quest, service error",id))
		end
		
		saveValue[sn] = nil
	end)

	DataThread.getInstance():AddListener(Command.S_BOUNTY_FIGHT_RESPOND, function(cmd, channel, respond)
		local sn = respond.sn
		local result = respond.result
		local sv = saveValue[sn]
		local id = sv.id

		if not id or not AIData[id] then
			saveValue[sn] = nil
			return
		end

		if result and result == Command.RET_SUCCESS then
			SetIsFighting(id, true)
			AIData[id].bounty.steps = 0
		end
		
		saveValue[sn] = nil
	end)

	DataThread.getInstance():AddListener(Command.S_TEAM_QUERY_BATTLE_TIME_RESPOND, function(cmd, channel, respond)
		local sn = respond.sn
		local result = respond.result
		local battle_begin_time = respond.battle_begin_time
		local battle_end_time = respond.battle_end_time
		local id = saveValue[sn]

		if not id or not AIData[id] then
			saveValue[sn] = nil
			return
		end

		if result and result == Command.RET_SUCCESS then
			if AIData[id].team then
				AIData[id].team.battle_begin_time = battle_begin_time
				AIData[id].team.battle_end_time = battle_end_time
			end
		end
		saveValue[sn] = nil
	end)

end

local begin_time = loop.now()
local init = false
local refresh_time = -1
local co  
--[[Scheduler.New(function(t)
	if (loop.now() - begin_time > 4 and not init) or (loop.now() - refresh_time > 20 and refresh_time > 0)then

		co = coroutine.create(function()
			local respond = QueryAutoMatchTeam()
			AIData.RefreshAutoMatchTeams(respond)
			init = true
			refresh_time = loop.now()
		end)
		coroutine.resume(co)

	end
end)--]]



return AIData 

