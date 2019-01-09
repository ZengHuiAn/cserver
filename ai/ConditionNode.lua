local AIData = require "AIData"
local FriendData = require "AIFriend"
local GuildData = require "AIGuild"
local BattleConfig = require "BattleConfig"

require "ConditionConfig"
require "printtb"
local ConditionNode = {}

function ConditionNode.StatusClean(id)
	local stat =  AIData.GetStatus(id)
	return stat == STATUS_CLEAN;
end

function ConditionNode.StatusPrepare(id)
	local stat =  AIData.GetStatus(id)
	return stat == STATUS_PREPARE;
end

function ConditionNode.StatusWaiting(id)
	local stat =  AIData.GetStatus(id)
	return stat == STATUS_WAITING;
end

function ConditionNode.StatusTasking(id)
	local stat =  AIData.GetStatus(id)
	return stat == STATUS_TASKING;
end

function ConditionNode.AlreadyLoginMap(id)
	local login = AIData.GetLoginMap(id)
	return login == true
end

function ConditionNode.NotLoginMap(id)
	local login = AIData.GetLoginMap(id)
	return not login
end

function ConditionNode.HasRollGame(id)
	local game = AIData.GetRollGame(id)
	return game ~= nil
end

function ConditionNode.NotHasRollGame(id)
	local game = AIData.GetRollGame(id)
	return game == nil
end

function ConditionNode.AIHasRoll(id)
	return AIData.AIHasRoll(id) == true	
end

function ConditionNode.AIHasNotRoll(id)
	return AIData.AIHasRoll(id) == false	
end

local birth_map = {10, 13, 24, 28}
local function InMap(pos, id)
	print("InMap >>>>>>>>>>>>>>>>>", pos, sprinttb(pos))
	if not pos or not pos.mapid then
		return false
	end

	local target = AIData.GetTarget(id)
	if not target then
		return false
	end

	local activity_cfg = BattleConfig.GetActivityConfig(target)
	if not activity_cfg then
		log.warning(string.format("AI %d fail to check in map, cannt get activity config for target %d", id, target))
		return false
	end
	
	local npc_cfg = BattleConfig.GetNpcConfig(activity_cfg.findnpcname)
	if not npc_cfg then
		log.warning(string.format("AI %d fail to check in map, cannt get npc config for npc %d", id, activity_cfg.findnpcname))
		return false
	end

	if pos.mapid == npc_cfg.mapid then
		return true
	end
	--[[for k, v in ipairs(birth_map) do
		if v == pos.mapid then
			return true
		end
	end--]]

	return false
end

function ConditionNode.InFreeMoveMapPos(id)
	local pos = AIData.GetPos(id)	

	if not pos or not pos.mapid then
		return false
	end

	return BattleConfig.CheckPosInFreeMoveMap(pos.mapid, pos) == true
end

function ConditionNode.NotInFreeMoveMapPos(id)
	local pos = AIData.GetPos(id)	

	if not pos or not pos.mapid then
		return true 
	end

	return BattleConfig.CheckPosInFreeMoveMap(pos.mapid, pos) == false 
end

function ConditionNode.InTargetMap(id)
	local pos = AIData.GetPos(id)	
	return InMap(pos, id) == true--pos.mapid ~= nil 
end

function ConditionNode.NotInTargetMap(id)
	local pos = AIData.GetPos(id)	
	return InMap(pos, id) == false 
end

function ConditionNode.InGuildMap(id)
	local pos = AIData.GetPos(id)
	if pos.mapid == 25 then
		return true
	end
	return false
end

function ConditionNode.NotInGuildMap(id)
	return ConditionNode.InGuildMap(id) == false
end

function ConditionNode.OldTeam(id)
	return AIData.IsOldTeam(id) == true
end

function ConditionNode.NotOldTeam(id)
	return AIData.IsOldTeam(id) == false 
end

function ConditionNode.TargetNeedCreateTeam(id)
	local target = AIData.GetTarget(id)
	if not target then
		return false
	end
	
	return target <= 4
end

function ConditionNode.WantToBeLeader(id)
	local mode = AIData.GetMode(id)
	if not mode then
		return false
	end

	--return false
	return mode == "leader"
end

function ConditionNode.WantToBeMember(id)
	local mode = AIData.GetMode(id)
	if not mode then
		return false
	end

	--return true
	return mode == "member"
end

function ConditionNode.AINotAutoMatch(id)
	local ai_auto_match = AIData.GetAIAutoMatchStatus(id)

	return not ai_auto_match
end

function ConditionNode.TargetNeedntCreateTeam(id)
	local target = AIData.GetTarget()
	if not target then
		return false
	end

	return target > 4
end

function ConditionNode.TeamHasRealPlayer(id)
	local ret = AIData.TeamHasRealPlayer(id)
	return ret == true
end

function ConditionNode.TeamNotHasRealPlayer(id)
	local ret = AIData.TeamHasRealPlayer(id)
	return ret == false 
end

function ConditionNode.HasBeginTaskTime(id)
	local t = AIData.GetBeginTaskTime(id)	
	return t ~= nil
end

function ConditionNode.NotHasBeginTaskTime(id)
	local t = AIData.GetBeginTaskTime(id)	
	return t == nil
end

function ConditionNode.TimeToBeginTask(id)
	local t = AIData.GetBeginTaskTime(id)	
	if not t then
		return false
	end

	return loop.now() > t
end

function ConditionNode.HasDeadlineTime(id)
	local t = AIData.GetDeadlineTime(id)
	return t ~= nil
end

function ConditionNode.NotHasDeadlineTime(id)
	local t = AIData.GetDeadlineTime(id)
	return t == nil
end

function ConditionNode.TimeToDead(id)
	local t = AIData.GetDeadlineTime(id)	
	if not t then
		return false
	end

	--AI_DEBUG_LOG("dead count down >>>>>>>>>>>>>>>>>>>>>>", t - loop.now())
	return loop.now() > t
end

function ConditionNode.AIIsLeader(id)
	local team = AIData.GetTeam(id)
	if not team then
		return false
	end

	return team.leader == id
end

function ConditionNode.TargetNotFitWithGroup(id)
	return AIData.TargetFitWithGroup(id) == false
end

function ConditionNode.AIIsMember(id)
	local team = AIData.GetTeam(id)
	if not team then
		return false
	end

	return team.leader ~= id
end

function ConditionNode.BeKicked(id)
	return AIData.IsKicked(id)
end

function ConditionNode.HasTeam(id)
	local team = AIData.GetTeam(id)
	AI_DEBUG_LOG(string.format("AI %d HasTeam>>>>>>", id), tostring(team ~= nil))
	return team ~= nil
end

function ConditionNode.HasNoTeam(id)
	local team = AIData.GetTeam(id)
	AI_DEBUG_LOG(string.format("AI %d HasNoTeam>>>>>>", id), tostring(team == nil))
	if not team == nil then
		AI_DEBUG_LOG(string.format("AI %d team", id), sprinttb(team))
	end
	return team == nil
end

function ConditionNode.TeamHasMoreThanThreeMember(id)
	local team = AIData.GetTeam(id)
	if not team then
		return false	
	end

	return #team.members >= 3 
end

function ConditionNode.TeamHasLessThanThreeMember(id)
	local team = AIData.GetTeam(id)
	print("AI "..tostring(id).."TeamHasLessThanThreeMember", team)
	if not team then
		return false	
	end
	print("AI "..tostring(id).."TeamHasLessThanThreeMember", #team.members)

	return #team.members < 3 
end

function ConditionNode.TeamHasFiveMember(id)
	local team = AIData.GetTeam(id)
	if not team then
		return false	
	end

	return #team.members == 5 
end

function ConditionNode.TeamNotHasFiveMember(id)
	local team = AIData.GetTeam(id)
	if not team then
		return false	
	end

	return #team.members ~= 5 
end

function ConditionNode.TeamIsFighting(id)
	return AIData.IsFighting(id) == true
end

function ConditionNode.TeamIsNotFighting(id)
	return AIData.IsFighting(id) == false 
end

function ConditionNode.FightFinishMoreThanTenSec(id)
	local fight_finish_time = AIData.GetFightFinishTime(id)
	if not fight_finish_time or loop.now() - fight_finish_time > 15 then
		return true
	end
end

function ConditionNode.FightFinishLessThanTenSec(id)
	return not ConditionNode.FightFinishMoreThanTenSec()
end

function ConditionNode.FightFinishMoreThanTwentySec(id)
	local fight_finish_time = AIData.GetFightFinishTime(id)
	if not fight_finish_time or loop.now() - fight_finish_time > 25 then
		return true
	end
end

function ConditionNode.FightFinishLessThanTwentySec(id)
	return not ConditionNode.FightFinishMoreThanTwentySec()
end

function ConditionNode.InFrontOfBoss(id)
	local pos = AIData.GetPos(id)	
	if not pos.mapid then
		return false
	end

	local next_fight = AIData.GetNextFight(id)
	if not next_fight then
		return false
	end

	local mapid, boss_pos = GetFightPos(next_fight)

	if (mapid == pos.mapid) and (math.abs(boss_pos.x - pos.x) <= 1) and (math.abs(boss_pos.y - pos.y) <= 1) and (math.abs(boss_pos.z - pos.z) <= 1) then
		return true
	end

	return false
end

function ConditionNode.NotInFrontOfBoss(id)
	local pos = AIData.GetPos(id)	
	if not pos.mapid then
		return false
	end

	local next_fight = AIData.GetNextFight(id)
	if not next_fight then
		return false
	end
	local mapid, boss_pos = GetFightPos(next_fight)

	if (mapid == pos.mapid) and (math.abs(boss_pos.x - pos.x) <= 1) and (math.abs(boss_pos.y - pos.y) <= 1) and (math.abs(boss_pos.z - pos.z) <= 1) then
		return false
	end

	return true 
end

function ConditionNode.InFrontOfBountyNpc(id)
	local pos = AIData.GetPos(id)	
	if not pos.mapid then
		return false
	end

	local target = AIData.GetTarget(id)
	if not target then
		return false
	end

	local activity_cfg = BattleConfig.GetActivityConfig(target)
	if not activity_cfg then
		return false
	end
	
	local npc_cfg = BattleConfig.GetNpcConfig(activity_cfg.findnpcname)
	if not npc_cfg then
		return false
	end
	
	local mapid, boss_pos = npc_cfg.mapid, {x = npc_cfg.Position_x, y = npc_cfg.Position_z, z = npc_cfg.Position_y}

	if (mapid == pos.mapid) and (math.abs(boss_pos.x - pos.x) <= 1) and (math.abs(boss_pos.y - pos.y) <= 1) and (math.abs(boss_pos.z - pos.z) <= 1) then
		return true
	end

	return false
end

function ConditionNode.NotInFrontOfBountyNpc(id)
	local pos = AIData.GetPos(id)	
	if not pos.mapid then
		return false
	end

	local target = AIData.GetTarget(id)
	if not target then
		return false
	end

	local activity_cfg = BattleConfig.GetActivityConfig(target)
	if not activity_cfg then
		return false
	end
	
	local npc_cfg = BattleConfig.GetNpcConfig(activity_cfg.findnpcname)
	if not npc_cfg then
		return false
	end
	
	local mapid, boss_pos = npc_cfg.mapid, {x = npc_cfg.Position_x, y = npc_cfg.Position_z, z = npc_cfg.Position_y}

	if (mapid == pos.mapid) and (math.abs(boss_pos.x - pos.x) <= 1) and (math.abs(boss_pos.y - pos.y) <= 1) and (math.abs(boss_pos.z - pos.z) <= 1) then
		return false 
	end

	return true 
end

function ConditionNode.InBossMap(id)
	local next_fight = AIData.GetNextFight(id)
	if not next_fight then
		return false
	end

	local mapid, _ = GetFightPos(next_fight)
	local pos = AIData.GetPos(id)	
	if not pos.mapid then
		return false
	end

	return mapid == pos.mapid
end

function ConditionNode.NotInBossMap(id)
	local next_fight = AIData.GetNextFight(id)
	if not next_fight then
		return false
	end

	local mapid, _ = GetFightPos(next_fight)
	local pos = AIData.GetPos(id)	
	if not pos.mapid then
		return false
	end

	print("NotInBossMap>>>>>>>>>>>>>>>>>>>>>>>>", mapid, pos.mapid)
	return mapid ~= pos.mapid
end

function ConditionNode.TeamIsInplaceChecking(id)
    return AIData.IsInplaceChecking(id)
end

function ConditionNode.TeamIsNotInplaceChecking(id)
	return not AIData.IsInplaceChecking(id)
end

function ConditionNode.TeamAllMemberReady(id)
	local team = AIData.GetTeam(id)
	
	if not team then
		return false
	end

	if not AIData.IsInplaceChecking(id) then
		return false
	end

	AI_DEBUG_LOG(string.format("AI %d, TeamAllMemberReady", id), sprinttb(team.members))
	for k, v in ipairs(team.members or {}) do
		if v.ready ~= 1 then
			AI_DEBUG_LOG(string.format("AI %d,  player %d not ready", id, v.pid))
			return false
		end 
	end

	return true
end

function ConditionNode.TeamNotAllMemberReady(id)
	local team = AIData.GetTeam(id)
	
	if not team then
		return false
	end

	if not AIData.IsInplaceChecking(id) then
		return true 
	end

	for k, v in ipairs(team.members or {}) do
		if v.ready ~= 1 then
			return true 
		end 
	end

	return false 
end

function ConditionNode.AINotReady(id)
	local team = AIData.GetTeam(id)
	
	if not team then
		return false
	end

	if not AIData.IsInplaceChecking(id) then
		return true 
	end

	for k, v in ipairs(team.members or {}) do
		if v.pid == id and v.ready ~= 1 then
			return true 
		end 
	end

	return false 
end

function ConditionNode.HasNextFight(id)
	local fight, err = AIData.GetNextFight(id)

	if fight then
		return true
	else
		return false
	end
end

function ConditionNode.NotHasNextFight(id)
	local fight, err = AIData.GetNextFight(id)

	AI_DEBUG_LOG(string.format("AI %d NotHasNextFight >>>>>>>>>>>>>>>>>>>>>",  id), fight, err)
	if not fight and err ~= "has no team" then
		return true
	else
		return false
	end
end

function ConditionNode.LastFightFail(id)
	local fight_result = AIData.GetLastFightResult(id)
	if not fight_result then
		return false
	end

	return fight_result == 0
end

function ConditionNode.LastFightWin(id)
	local fight_result = AIData.GetLastFightResult(id)
	if not fight_result then
		return false
	end

	return fight_result == 1 
end

function ConditionNode.NotHasLastFight(id)
	local fight_result = AIData.GetLastFightResult(id)
	if not fight_result then
		return true 
	end

	return false 
end

function ConditionNode.HasKickAI(id)
	local has_kick_ai = AIData.HasKickAI(id)
	if has_kick_ai == nil then
		return false
	end

	return has_kick_ai == true
end

function ConditionNode.NotHasKickAI(id)
	local has_kick_ai = AIData.HasKickAI(id)
	if has_kick_ai == nil then
		return true 
	end

	return has_kick_ai == false 
end

function ConditionNode.NextFightIsStory(id)
	return AIData.NextFightIsStory(id)
end

function ConditionNode.NextFightIsNotStory(id)
	return AIData.NextFightIsNotStory(id)
end

function ConditionNode.HasPresentEnergy(id)
	return FriendData.IsPresent(id)
end

function ConditionNode.HasNoPresent(id)
	return FriendData.IsPresent(id) == false
end

function ConditionNode.NeedPresentEnergy(id)
	return FriendData.IsNeedPresent(id)
end

function ConditionNode.GuildLevelEnough(id)
	local info = cell.getPlayerInfo(id)
	local limit = BattleConfig.GetActivityConfig(14).lv_limit
	if info and info.level >= limit then
		return true
	else
		return false
	end
end

function ConditionNode.IsGuildLeader(id)
	return GuildData.IsLeader(id)	
end

function ConditionNode.HasGuild(id)
	return GuildData.HasGuild(id) == true
end

function ConditionNode.HasNotGuild(id)
	return GuildData.HasGuild(id) == false
end

function ConditionNode.FinishBounty(id)
	local bounty_info = AIData.GetBountyInfo(id)
	
	return bounty_info.finish_round >= 2 
end


function ConditionNode.NotFinishBounty(id)
	local bounty_info = AIData.GetBountyInfo(id)

	return bounty_info.finish_round < 2 
end

function ConditionNode.NotHasBountyQuest(id)
	local bounty_info = AIData.GetBountyInfo(id)

	return bounty_info.quest_id == 0
end

function ConditionNode.HasBountyQuest(id)
	local bounty_info = AIData.GetBountyInfo(id)

	return bounty_info.quest_id ~= 0
end

function ConditionNode.MeetEnemy(id)
	local bounty_info = AIData.GetBountyInfo(id)

	if bounty_info.next_fight_time == 0 then
		return false
	end

	AI_DEBUG_LOG(string.format("AI %d steps >>>>>>>>>>>", id), bounty_info.steps)
	if loop.now() > bounty_info.next_fight_time and bounty_info.steps >= 100 then
		return true
	end

	return false 
end

function ConditionNode.NotMeetEnemy(id)
	local bounty_info = AIData.GetBountyInfo(id)

	if bounty_info.next_fight_time == 0 then
		return false
	end

	if loop.now() > bounty_info.next_fight_time and bounty_info.steps >= 100 then
		return false
	end

	return true
end

function ConditionNode.FightMoreThanOnce(id)
	local fight_count = AIData.GetFightCount(id)

	return fight_count >= 1
end

function ConditionNode.NotFightMoreThanOnce(id)
	local fight_count = AIData.GetFightCount(id)

	return fight_count < 1
end

local function matchingName(name)
	assert(name)

    local _a = string.sub(name, 1, 5)
    local _b = string.sub(name, -6)
    if _a == "<SGK>" and _b == "</SGK>" then
        return true 
    end

    return false 
end


function ConditionNode.AINameIsNumber(id)
	local name = AIData.GetNickName(id)
	if name and matchingName(name) then
		return true
	end

	return false
end

function ConditionNode.AINameIsNotNumber(id)
	local name = AIData.GetNickName(id)
	if name and not matchingName(name) then
		return true
	end
	
	return false
end

function ConditionNode.HasDissolveTeamTimeLine(id)
	local time_line = AIData.GetDissolveTeamTimeLine(id)
	return time_line ~= nil
end

function ConditionNode.NotHasDissolveTeamTimeLine(id)
	local time_line = AIData.GetDissolveTeamTimeLine(id)
	return time_line == nil
end

function ConditionNode.TimeToDissolve(id)
	local time_line = AIData.GetDissolveTeamTimeLine(id)
	if not time_line then
		return false
	else
		return loop.now() > time_line
	end
end

function ConditionNode.NotTimeToDissolve(id)
	local time_line = AIData.GetDissolveTeamTimeLine(id)
	if not time_line then
		return true 
	else
		return loop.now() <= time_line
	end
end

function ConditionNode.HasShoutTimeLine(id)
	local time_line = AIData.GetShoutTimeLine(id)
	return time_line ~= nil
end

function ConditionNode.NotHasShoutTimeLine(id)
	local time_line = AIData.GetShoutTimeLine(id)
	return time_line == nil
end

function ConditionNode.TimeToShout(id)
	local time_line = AIData.GetShoutTimeLine(id)
	if not time_line then
		return false
	else
		local t = os.date("*t", time_line)
		AI_DEBUG_LOG(string.format("AI %d TimeToShout  time_line %d-%d-%d %d:%d:%d now:%d", id, t.year, t.month, t.day, t.hour, t.min, t.sec, loop.now()), tostring(loop.now() > time_line))
		return loop.now() > time_line
	end
end

function ConditionNode.NotTimeToShout(id)
	local time_line = AIData.GetShoutTeamTimeLine(id)
	if not time_line then
		return true
	else
		return loop.now() <= time_line
	end
end

function ConditionNode.TeamInplaceCheckingOutOfTime(id)
	local inplace_checking_time = AIData.GetInplaceCheckingTime(id)
	if not inplace_checking_time then
		return false
	end

	if inplace_checking_time <= 0 then
		return false
	end

	return (loop.now() > inplace_checking_time + INPLACE_CHECK_LAST_TIME + 5) and (loop.now() < inplace_checking_time + INPLACE_CHECK_LAST_TIME + 15)
end

function ConditionNode.TeamInplaceCheckingNotOutOfTime(id)
	local inplace_checking_time = AIData.GetInplaceCheckingTime(id)
	if not inplace_checking_time then
		return false
	end

	if inplace_checking_time <= 0 then
		return false
	end

	return (loop.now() <= inplace_checking_time + INPLACE_CHECK_LAST_TIME) or (loop.now() >= inplace_checking_time + INPLACE_CHECK_LAST_TIME + 15)
end

function ConditionNode.SomeOneNotReady(id)
	local team = AIData.GetTeam(id)
	if not team then
		return false
	end
	
	for k, v in ipairs(team.members) do
		if v.ready == 0 then
			return true
		end
	end

	return false
end

function ConditionNode.NoOneNotReady(id)
	local team = AIData.GetTeam(id)
	if not team then
		return false
	end
	
	for k, v in ipairs(team.members) do
		if v.ready == 0 then
			return false 
		end
	end

	return true 
end

function ConditionNode.HasKickUnactiveMember(id)
	local has_kick_unactive_member = AIData.GetHasKickUnactiveMember(id)
	
	return has_kick_unactive_member == true
end

function ConditionNode.NotHasKickUnactiveMember(id)
	local has_kick_unactive_member = AIData.GetHasKickUnactiveMember(id)
	
	return has_kick_unactive_member == nil 
end

function ConditionNode.TeamNotAutoConfirmOrNotAutoMatch(id)
	local team = AIData.GetTeam(id)
	if not team then
		return false	
	end

	local auto_confirm =  team.auto_confirm
	local auto_match =  team.auto_match
	
	return auto_match == false
	--return auto_confirm == false or auto_match == false
end

function ConditionNode.TeamIsAutoConfirmOrNotAutoMatch(id)
	local team = AIData.GetTeam(id)
	if not team then
		return false	
	end

	local auto_confirm =  team.auto_confirm
	local auto_match =  team.auto_match

	return auto_match == true
	--return auto_confirm == true and auto_match == true	
end

function ConditionNode.InFreeMoveMapTooLong(id)
	local t = AIData.GetEnterFreeMoveMapTime(id)
	if not t then
		return false
	end

	return loop.now() - t > 15 
end

function ConditionNode.InFreeMoveMapNotTooLong(id)
	local t = AIData.GetEnterFreeMoveMapTime(id)
	if not t then
		return false
	end

	return loop.now() - t <= 15 
end

function ConditionNode.NotEnterFreeMoveMap(id)
	local t = AIData.GetEnterFreeMoveMapTime(id)
	if not t then
		return true
	end
	
	return false
end

function ConditionNode.HasEnterFreeMoveMap()
	local t = AIData.GetEnterFreeMoveMapTime(id)
	if not t then
		return false 
	end
	
	return true 
end

function ConditionNode.NotHasNextStep(id)
	local step = AIData.GetCurrentStep(id)	
	if step and step ~= 0 then
		return false
	else
		return true
	end	
end

function ConditionNode.HasNextStep(id)
	local step = AIData.GetCurrentStep(id)	
	if step and step ~= 0 then
		return true 
	else
		return false 
	end
end

function ConditionNode.NotHasVote(id)
	local candidate = AIData.GetVote(id)
	if not candidate or candidate == 0 then
		return true
	else
		return false
	end
end

function ConditionNode.HasVote(id)
	local candidate = AIData.GetVote(id)
	if candidate and candidate ~= 0 then
		return true
	else
		return false
	end
end

function ConditionNode.AILevelEnough(id)
	local level = AIData.GetAILevel(id)
	if not level then
		return false
	end

	if level >= 12 then
		return true
	end
end

function ConditionNode.AILevelNotEnough(id)
	local level = AIData.GetAILevel(id)
	if not level then
		return false
	end

	if level < 12 then
		return true
	end
end

function ConditionNode.TodayHasChangeHead(id)
	local has_change_head = AIData.GetHasChangeHead(id)
	if not has_change_head then
		return false
	end

	return true
end

function ConditionNode.TodayNotHasChangeHead(id)
	local has_change_head = AIData.GetHasChangeHead(id)
	if not has_change_head then
		return true 
	end

	return false 
end

function ConditionNode.HasJoinRequest(id)
	local join_request = AIData.GetJoinRequest(id)
	
	if not join_request then
		return false
	end

	if #join_request > 0 then
		return true
	end

	return false
end

function ConditionNode.NotHasJoinRequest(id)
	local join_request = AIData.GetJoinRequest(id)
	if not join_request then
		return false
	end

	if #join_request > 0 then
		return false 
	end

	return true 
end

function ConditionNode.FinishMoveWithOutRealPlayer(id)
	local bounty_info = AIData.GetBountyInfo(id)

	if not bounty_info then
		return false
	end

	AI_DEBUG_LOG(string.format("AI %d steps_without_real_player",id) ,bounty_info.steps_without_real_player)
	if bounty_info.steps_without_real_player >= 10 then
		return true
	end

	return false
end

function ConditionNode.NotFinishMoveWithOutRealPlayer(id)
	local bounty_info = AIData.GetBountyInfo(id)

	if not bounty_info then
		return false
	end

	AI_DEBUG_LOG(string.format("AI %d steps_without_real_player",id) ,bounty_info.steps_without_real_player)
	if bounty_info.steps_without_real_player < 10 then
		return true 
	end

	return false
end

function ConditionNode.NeedToInplaceReady(id)
	return AIData.NeedToInplaceReady(id)
end

function ConditionNode.SleepTooLong(id)
	local sleep_time = AIData.GetSleepTime(id)
	if not sleep_time then
		return false
	end

	AI_DEBUG_LOG(string.format("AI %d has sleep %d secs", id, loop.now() - sleep_time))
	return loop.now() - sleep_time > 10 * 60
end

function ConditionNode.NotHasDissolveTimeLineWhenAllAI(id)
	local time_line = AIData.GetDissolveTeamTimeLineWhenAllAI(id)
	return time_line == nil
end

function ConditionNode.TimeToDissolveWhenAllAI(id)
	local time_line = AIData.GetDissolveTeamTimeLineWhenAllAI(id)
	if time_line then
		AI_DEBUG_LOG(string.format("AI %d dissolvetimeline when all ai ,count down %d", id, time_line - loop.now()))
	else
		AI_DEBUG_LOG(string.format("AI %d not has dissolvetimeline when all ai", id))
	end	
	if not time_line then
		return false
	else
		return loop.now() > time_line
	end
end

function ConditionNode.BattleEnd(id)
	local battle_begin_time, battle_end_time = AIData.GetBattleTime(id)
	if not battle_end_time or battle_end_time then
		return false
	end

	return loop.now() > battle_end_time
end

function ConditionNode.BattleNotEnd(id)
	local battle_begin_time, battle_end_time = AIData.GetBattleTime(id)
	if not battle_end_time or battle_end_time then
		return false
	end

	return loop.now() < battle_end_time
end

function ConditionNode.GetCondition(name)
	return ConditionNode[name] 
end

return ConditionNode
