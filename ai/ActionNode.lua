require "AISocialManager"
local AIData = require "AIData"
local FriendData = require "AIFriend"
local GuildData = require "AIGuild"
local BattleConfig = require "BattleConfig"
local AIName = require "AIName"
local WELLRNG512a_ = require "WELLRNG512a"
require "AIGuild"

local ActionNode = {}

function RandomSleep(min, max)
	local sleep_time = math.random(min, max)
	Sleep(sleep_time)
	return sleep_time
end

function ActionNode.LoginMap(id)
	AIData.LoginMap(id)
end

local birth_map = {10, 13, 24, 28}

function ActionNode.EnterMap(id)
	local target = AIData.GetTarget(id)
	if not target then
		AI_WARNING_LOG(string.format("AI %d fail to Enter map, target not exist", id))
		return false
	end

	local activity_cfg = BattleConfig.GetActivityConfig(target)
	if not activity_cfg then
		AI_WARNING_LOG(string.format("AI %d fail to Enter map, cannt get activity config for target %d", id, target))
		return false
	end
	
	local npc_cfg = BattleConfig.GetNpcConfig(activity_cfg.findnpcname)
	if not npc_cfg then
		AI_WARNING_LOG(string.format("AI %d fail to Enter map, cannt get npc config for npc %d", id, activity_cfg.findnpcname))
		return false
	end

	local init_pos = BattleConfig.GetInitPos(npc_cfg.mapid)
	local current_pos = AIData.GetPos(id)
	if not current_pos or current_pos.mapid ~= npc_cfg.mapid then
		if init_pos then
   			AIData.MapMove(id, init_pos.x, init_pos.y, init_pos.z, npc_cfg.mapid, 2, 1)
		else
   			AIData.MapMove(id, 0, 0, 0, npc_cfg.mapid, 2, 1)
		end
		RandomSleep(1, 3)
	end

	local rand_pos = BattleConfig.GetPosCfg(activity_cfg.findnpcname, 2)
	if rand_pos then
    	AIData.MapMove(id, rand_pos.x, rand_pos.y, rand_pos.z)
	else
    	AIData.MapMove(id, npc_cfg.Position_x, npc_cfg.Position_z, npc_cfg.Position_y)
	end

	RandomSleep(1, 3)
end

function ActionNode.EnterGuildMap(id)
	local target = AIData.GetTarget(id)
	if not target then
		AI_WARNING_LOG(string.format("AI %d fail to Enter guild map, target not exist.", id))
		return false
	end

	local point = BattleConfig.GetPosCfg(25, 3)
	if not point then
		AI_WARNING_LOG(string.format("AI %d fail to Enter guild map, point not exist.", id))
		return false	
	end
	local x = point.x
	local y = point.y

	local info = GuildData.GetGuildInfo(id)	
   	AIData.MapMove(id, x, y, 0, 25, 4, info.gid)
	RandomSleep(10, 15)	
end

function ActionNode.EnterFreeMoveMap(id)
	local pos, mid = BattleConfig.GetPosCfg(0, 1)
	AI_DEBUG_LOG(string.format("AI %d enter free Map mid %d", id, mid))
	local init_pos = BattleConfig.GetInitPos(mid)
	if not init_pos then
   		AIData.MapMove(id, 0, 0, 0, mid, 2, 1)
	else
   		AIData.MapMove(id, init_pos.x, init_pos.y, init_pos.z, mid, 2, 1)
	end
	RandomSleep(1, 2)	
	AI_DEBUG_LOG(string.format("AI %d move in free Map mid %d", id, mid), pos.x, pos.y, pos.z)
   	AIData.MapMove(id, pos.x, pos.y, pos.z)
	AIData.SetEnterFreeMoveMapTime(id)
	RandomSleep(1, 2)	
end

local MIN_X = -10
local MAX_X = 10
local MIN_Y = -10
local MAX_Y = 10
function ActionNode.Move(id)
	local pos = AIData.GetPos(id)
	if not pos or not pos.mapid then
		AI_DEBUG_LOG(string.format("AI %d not in map"))
		return RandomSleep(1, 3)	
	end

	--[[x  = pos.x + math.random(-100, 100) / 10 --x or math.random(-1, 1)
	y  = pos.y + math.random(-100, 100) / 10 --y or math.random(-1, 1)
	local offset_x = math.random(-10, 10) / 10
    local offset_y = math.random(-10, 10) / 10
    x  = pos.x + offset_x --x or math.random(-1, 1)
    y  = pos.y + offset_x --y or math.random(-1, 1)
    -- 检查坐标是否超过最大范围
    if x > MAX_X then
            x = x - 2 * math.abs(offset_x)
    elseif x < MIN_X then
            x = x + 2 * math.abs(offset_x)
    end

    if y > MAX_Y then
            y = y - 2 * math.abs(offset_y)
    elseif y < MIN_Y then
            y = y + 2 * math.abs(offset_y)
    end

	z  = 0 --]]

	local target = AIData.GetTarget(id)
	if not target then
		AI_WARNING_LOG(string.format("AI %d fail to Move, target not exist", id))
		return false
	end

	local activity_cfg = BattleConfig.GetActivityConfig(target)
	if not activity_cfg then
		AI_WARNING_LOG(string.format("AI %d fail to Move, cannt get activity config for target %d", id, target))
		return false
	end
	local rand_pos = BattleConfig.GetPosCfg(activity_cfg.findnpcname, 2)

	if not rand_pos then
		AI_WARNING_LOG(string.format("AI %d fail to Move, cannt get rand_pos for npc %d", id,activity_cfg.findnpcname))
		RandomSleep(1, 3)
		return false	
	end
	
	local move_count = AIData.GetMoveCount(id)
	if move_count >= 10 then
		AI_DEBUG_LOG(string.format("AI %d move to x %d y %d in map %d", id, rand_pos.x, rand_pos.y, pos.mapid))
		AIData.MapMove(id, rand_pos.x, rand_pos.y, rand_pos.z)

		RandomSleep(1, 3)
	else
		AIData.SetMoveCount(id, move_count + math.random(1, 3))
		RandomSleep(1, 3)
	end	
end

function ActionNode.CreateTeam(id)
	AI_DEBUG_LOG(string.format("AI %d create team", id))

	local team = AIData.CreateTeam(id)
	--if team then
		--AIData.TeamAutoConfirm(id)
		--AIData.TeamAutoMatch(id)
		--AIData.AddAutoMatchTeams(team.teamid, team.group)
		local target_str = AIData.GetTargetStr(id)
		--AIData.Chat(id, 10, string.format("%s来人！[-1#申请入队]", target_str))
		local lower_level , upper_level = AIData.GetTeamLevelLimit(id)
		AIData.Chat(id, 10, string.format("%s(1/5)\n[%d级-%d级]进组啦[-1#申请入队]", target_str, lower_level or 0, upper_level or 200))
	--end

	RandomSleep(1, 3)
end

function ActionNode.SetTeamAutoConfirmAndAutoMatch(id)
	AI_DEBUG_LOG(string.format("AI %d set team autoconfirm and automatch", id))
	--AIData.TeamAutoConfirm(id)
	AIData.TeamAutoMatch(id)
end

function ActionNode.Roll(id)
	AI_DEBUG_LOG(string.format("AI %d roll public reward", id))
	local sleep_time = RandomSleep(1, 5)
	local reward_count = AIData.GetRewardCount(id)
	for i = 1, reward_count, 1 do
		AIData.Roll(id, i)
		RandomSleep(1, 3)
	end

	AIData.DeleteRollGame(id)
end

function ActionNode.MoveToBoss(id)
	local next_fight = AIData.GetNextFight(id)
	if not next_fight then
		return 
	end

	local mapid, pos = GetFightPos(next_fight)
	AI_DEBUG_LOG(string.format("AI %d move to boss, boss pos map %f x %f y %f z %d", id, mapid, pos.x, pos.y, pos.z))

	local current_pos = AIData.GetPos(id)

	local team = AIData.GetTeam(id)
	local channel = 2
	local room = 1
	if team and team.teamid then
		channel = 3
		room = team.teamid
	end

	if not current_pos or not current_pos.mapid or current_pos.mapid ~= mapid or current_pos.channel ~= channel or current_pos.room ~= room then
		AI_DEBUG_LOG(string.format("AI %d enter into boss map, map %d, channel %d, room %d", id, mapid, 3, team.teamid))			
		local target = AIData.GetTarget(id)
		local enter_pos = {x = 0, y = 0, z = 0}
		if target then
			battle_cfg = BattleConfig.GetBattleConfig(target)
			if battle_cfg then
				enter_pos = {x = battle_cfg.enter_x, y = battle_cfg.enter_z, z = battle_cfg.enter_y}
			end
		end
		AIData.MapMove(id, enter_pos.x, enter_pos.y, enter_pos.z, mapid, channel, room)
		RandomSleep(2, 2)
		print(string.format("AI %d enter battle", id))
		AIData.EnterBattle(id)
		AIData.MapMove(id, pos.x, pos.y, pos.z)
	else
		AI_DEBUG_LOG(string.format("AI %d move to boss map directly", id))			
		AIData.MapMove(id, pos.x, pos.y, pos.z)
	end	
	RandomSleep(3, 3)

	AIData.TriggerStory(id)
	RandomSleep(3, 3)
end

function ActionNode.MoveToBountyNpc(id)
	local target = AIData.GetTarget(id)
	if not target then
		AI_WARNING_LOG(string.format("AI %d fail to move to bounty npc, target not exist", id))
		return false
	end

	local activity_cfg = BattleConfig.GetActivityConfig(target)
	if not activity_cfg then
		AI_WARNING_LOG(string.format("AI %d fail to move to bounty npc, cannt get activity config for target %d", id, target))
		return false
	end
	
	local npc_cfg = BattleConfig.GetNpcConfig(activity_cfg.findnpcname)
	if not npc_cfg then
		AI_WARNING_LOG(string.format("AI %d fail to move to bounty npc, cannt get npc config for npc %d", id, activity_cfg.findnpcname))
		return false
	end

	local team = AIData.GetTeam(id)
	local channel = 2
	local room = 1
	--[[if team and team.teamid then
		channel = 3
		room = team.teamid
	end--]]
	
	local mapid, pos = npc_cfg.mapid, {x = npc_cfg.Position_x, y = npc_cfg.Position_z, z = npc_cfg.Position_y}--GetFightPos(next_fight)
	local current_pos = AIData.GetPos(id)
	if not current_pos or not current_pos.mapid or current_pos.mapid ~= mapid then
		AI_DEBUG_LOG(string.format("AI %d move to bounty npc map", id))			
		AIData.MapMove(id, 0, 0, 0, mapid, channel, room)
		RandomSleep(2, 2)
		AIData.MapMove(id, pos.x, pos.y, pos.z)
	else
		AI_DEBUG_LOG(string.format("AI %d move to bounty npc map directly", id))			
		AIData.MapMove(id, pos.x, pos.y, pos.z)
	end	
	RandomSleep(6, 6)

end

function ActionNode.MoveToNpc(id)
	local target = AIData.GetTarget(id)
	if not target then
		AI_WARNING_LOG(string.format("AI %d fail to move to npc, target not exist", id))
		return false
	end

	local activity_cfg = BattleConfig.GetActivityConfig(target)
	if not activity_cfg then
		AI_WARNING_LOG(string.format("AI %d fail to move to npc, cannt get activity config for target %d", id, target))
		return false
	end
	
	local npc_cfg = BattleConfig.GetNpcConfig(activity_cfg.findnpcname)
	if not npc_cfg then
		AI_WARNING_LOG(string.format("AI %d fail to move to npc, cannt get npc config for npc %d", id, activity_cfg.findnpcname))
		return false
	end

	local team = AIData.GetTeam(id)
	local channel = 2
	local room = 1
	--[[if team and team.teamid then
		channel = 3
		room = team.teamid
	end--]]
	
	local mapid, pos = npc_cfg.mapid, {x = npc_cfg.Position_x, y = npc_cfg.Position_z, z = npc_cfg.Position_y}--GetFightPos(next_fight)
	local current_pos = AIData.GetPos(id)
	print("move to npc>>>>>>>>>>>>>>>>>>", current_pos.mapid, mapid, npc_cfg.mapid)
	if not current_pos or not current_pos.mapid or current_pos.mapid ~= mapid then
		AI_DEBUG_LOG(string.format("AI %d move to npc map", id))			
		AIData.MapMove(id, 0, 0, 0, mapid, channel, room)
		RandomSleep(2, 2)
		AIData.MapMove(id, pos.x, pos.y, pos.z)
	else
		AI_DEBUG_LOG(string.format("AI %d move to npc map directly", id))			
		AIData.MapMove(id, pos.x, pos.y, pos.z)
	end	
	RandomSleep(3, 3)
end


function ActionNode.MoveInBountyMap(id)
	AI_DEBUG_LOG(string.format("AI %d move in bounty map", id))
	
	local target = AIData.GetTarget(id) 
	if not target then
		AI_WARNING_LOG(string.format("AI %d fail to Move In bounty map, target is nil", id))
		return
	end

	local bounty_info = AIData.GetBountyInfo(id)
	if not bounty_info or bounty_info.quest_id == 0 then
		AI_WARNING_LOG(string.format("AI %d fail to Move In bounty map, bounty not active quest", id))
		return
	end

	local cfg = GetBountyQuestConfig(target, bounty_info.quest_id)
	if not cfg then
		AI_WARNING_LOG(string.format("AI %d fail to Move In bounty map, bounty cfg is nil", id))
		return 
	end

	local current_pos = AIData.GetPos(id)
	local team = AIData.GetTeam(id)
	local channel = 2
	local room = 1
	--[[if team and team.teamid then
		channel = 3
		room = team.teamid
	end--]]

	local mapid, pos = cfg.map_id, BattleConfig.GetBountyNpcPos(cfg.map_id)--{{x = 0, y = 0, z= 0},  {x = 1, y = 0, z= 0}, {x = 2, y = 0, z= 0}, {x = 3, y = 0, z= 0}}--GetFightPos(next_fight)

	if target == 54 then
		local random_hit = WELLRNG512a_.value(WELLRNG512a_.new(bounty_info.next_fight_time + team.teamid))
		AI_DEBUG_LOG(string.format("AI %d  random hit %d  next_fight_time %d  teamid %d", id, random_hit, bounty_info.next_fight_time, team.teamid))
		local all_pos_config = BattleConfig.GetAllPosConfig(cfg.map_id)
		if not all_pos_config then 
			AI_DEBUG_LOG(string.format("AI %d cannt get all_position_config for map %d", id, cfg.map_id))
			return 
		end

		local idx = random_hit % (#all_pos_config) + 1
		AI_DEBUG_LOG(string.format("AI %d random idx in 元素试炼 %d", id, idx), bounty_info.next_fight_time, team.teamid, all_pos_config[idx].x, all_pos_config[idx].y, all_pos_config[idx].z)
		if not current_pos or not current_pos.mapid or current_pos.mapid ~= mapid or current_pos.channel ~= channel or current_pos.room ~= room then
			AI_DEBUG_LOG(string.format("AI %d first move to bounty map, then move in bounty map,  map %d,  channel %d, room %d", id, mapid, channel, room), current_pos.mapid, current_pos.channel, current_pos.room)			
			AIData.MapMove(id, 0, 0, 0, mapid, channel, room)
			RandomSleep(2, 2)
			AIData.MapMove(id, all_pos_config[idx].x, all_pos_config[idx].y, all_pos_config[idx].z)
		else
			AI_DEBUG_LOG(string.format("AI %d move in bounty map directly", id))	
			RandomSleep(5, 10)
			AIData.MapMove(id, all_pos_config[idx].x, all_pos_config[idx].y, all_pos_config[idx].z)
		end
		AIData.AddSteps(id, 100)
	else
		--local idx = AIData.GetNavigationProgress(id)
		if not current_pos or not current_pos.mapid or current_pos.mapid ~= mapid or current_pos.channel ~= channel or current_pos.room ~= room then
			AI_DEBUG_LOG(string.format("AI %d first move to bounty map, then move in bounty map,  map %d,  channel %d, room %d", id, mapid, channel, room), current_pos.mapid, current_pos.channel, current_pos.room)			
			AIData.MapMove(id, 0, 0, 0, mapid, channel, room)
			RandomSleep(2, 2)
			AIData.MapMove(id, pos[1].x, pos[1].y, pos[1].z)
			idx = 1
		else
			AI_DEBUG_LOG(string.format("AI %d move in bounty map directly", id))	
			local idx = math.random(1, #pos)		
			RandomSleep(5, 10)
			AIData.MapMove(id, pos[idx].x, pos[idx].y, pos[idx].z)
			--[[if idx >= 4 then
				idx = 1 
			else
				idx = idx + 1
			end--]]
		end	

		AIData.AddSteps(id, math.random(10, 50))
		--AIData.UpdateNavigationProgress(id, idx)
	end

	AIData.AddStepsWithOutRealPlayer(id, 0)
	
	RandomSleep(5, 10)
end

function ActionNode.MoveInBountyMapWithOutRealMan(id)
	AI_DEBUG_LOG(string.format("AI %d move in bounty map", id))
	
	local target = AIData.GetTarget(id) 
	if not target then
		AI_WARNING_LOG(string.format("AI %d fail to Move In bounty map, target is nil", id))
		return
	end

	local bounty_info = AIData.GetBountyInfo(id)
	if not bounty_info or bounty_info.quest_id == 0 then
		AI_WARNING_LOG(string.format("AI %d fail to Move In bounty map, bounty not active quest", id))
		return
	end

	local cfg = GetBountyQuestConfig(target, bounty_info.quest_id)
	if not cfg then
		AI_WARNING_LOG(string.format("AI %d fail to Move In bounty map, bounty cfg is nil", id))
		return 
	end

	local current_pos = AIData.GetPos(id)
	local team = AIData.GetTeam(id)
	local channel = 2
	local room = 1
	--[[if team and team.teamid then
		channel = 3
		room = team.teamid
	end--]]

	local mapid, pos = cfg.map_id, BattleConfig.GetBountyNpcPos(cfg.map_id)--{{x = 0, y = 0, z= 0},  {x = 1, y = 0, z= 0}, {x = 2, y = 0, z= 0}, {x = 3, y = 0, z= 0}}--GetFightPos(next_fight)

	if target == 54 then
		local all_pos_config = BattleConfig.GetAllPosConfig(cfg.map_id)
		if not all_pos_config then 
			AI_DEBUG_LOG(string.format("AI %d cannt get all_position_config for map %d", id, cfg.map_id))
			return 
		end

		local idx = math.random(1, #all_pos_config)
		AI_DEBUG_LOG(string.format("AI %d random idx in 元素试炼 %d", id, idx), bounty_info.next_fight_time, team.teamid, all_pos_config[idx].x, all_pos_config[idx].y, all_pos_config[idx].z)
		if not current_pos or not current_pos.mapid or current_pos.mapid ~= mapid or current_pos.channel ~= channel or current_pos.room ~= room then
			AI_DEBUG_LOG(string.format("AI %d first move to bounty map, then move in bounty map,  map %d,  channel %d, room %d", id, mapid, channel, room), current_pos.mapid, current_pos.channel, current_pos.room)			
			AIData.MapMove(id, 0, 0, 0, mapid, channel, room)
			RandomSleep(2, 2)
			AIData.MapMove(id, all_pos_config[idx].x, all_pos_config[idx].y, all_pos_config[idx].z)
		else
			AI_DEBUG_LOG(string.format("AI %d move in bounty map directly", id))	
			RandomSleep(5, 10)
			AIData.MapMove(id, all_pos_config[idx].x, all_pos_config[idx].y, all_pos_config[idx].z)
		end
		AIData.AddSteps(id, 0)
	else
		--local idx = AIData.GetNavigationProgress(id)
		if not current_pos or not current_pos.mapid or current_pos.mapid ~= mapid or current_pos.channel ~= channel or current_pos.room ~= room then
			AI_DEBUG_LOG(string.format("AI %d first move to bounty map, then move in bounty map,  map %d,  channel %d, room %d", id, mapid, channel, room), current_pos.mapid, current_pos.channel, current_pos.room)			
			AIData.MapMove(id, 0, 0, 0, mapid, channel, room)
			RandomSleep(2, 2)
			AIData.MapMove(id, pos[1].x, pos[1].y, pos[1].z)
			idx = 1
		else
			AI_DEBUG_LOG(string.format("AI %d move in bounty map directly", id), idx)	
			local idx = math.random(1, #pos)		
			AIData.MapMove(id, pos[idx].x, pos[idx].y, pos[idx].z)
			--[[if idx >= 4 then
				idx = 1 
			else
				idx = idx + 1
			end--]]
		end	

		AIData.AddSteps(id, 0)
		--AIData.UpdateNavigationProgress(id, idx)
	end

	AIData.AddStepsWithOutRealPlayer(id, 1)
	
	RandomSleep(5, 10)
end

function ActionNode.MoveInBountyMapBySmallStep(id)
	AI_DEBUG_LOG(string.format("AI %d move in bounty map by small step", id))
	
	local target = AIData.GetTarget(id) 
	if not target then
		AI_WARNING_LOG(string.format("AI %d fail to Move In bounty map by samll step, target is nil", id))
		return
	end

	local bounty_info = AIData.GetBountyInfo(id)
	if not bounty_info or bounty_info.quest_id == 0 then
		AI_WARNING_LOG(string.format("AI %d fail to Move In bounty map by small step, bounty not active quest", id))
		return
	end

	local cfg = GetBountyQuestConfig(target, bounty_info.quest_id)
	if not cfg then
		AI_WARNING_LOG(string.format("AI %d fail to Move In bounty map by small step, bounty cfg is nil", id))
		return 
	end

	local mapid, pos = cfg.map_id, BattleConfig.GetBountyNpcPos(cfg.map_id)--{{x = 0, y = 0, z= 0},  {x = 1, y = 0, z= 0}, {x = 2, y = 0, z= 0}, {x = 3, y = 0, z= 0}}--GetFightPos(next_fight)

	local current_pos = AIData.GetPos(id)
	local team = AIData.GetTeam(id)
	local channel = 2
	local room = 1
	--[[if team and team.teamid then
		channel = 3
		room = team.teamid
	end--]]

	local idx = AIData.GetNavigationProgress(id)
	if not current_pos or not current_pos.mapid or current_pos.mapid ~= mapid or current_pos.channel ~= channel or current_pos.room ~= room then
		AI_DEBUG_LOG(string.format("AI %d first move to bounty map, then move in bounty map,  map %d,  channel %d, room %d(small step)", id, mapid, channel, room))			
		AIData.MapMove(id, 0, 0, 0, mapid, channel, room)
		RandomSleep(2, 2)
		AIData.MapMove(id, pos[1].x, pos[1].y, pos[1].z)
		idx = 1
	else
		AI_DEBUG_LOG(string.format("AI %d move in bounty map directly(small step)", id))	
		local idx = math.random(1, #pos)		
		AIData.MapMove(id, pos[idx].x, pos[idx].y, pos[idx].z)
		--[[if idx >= 4 then
			idx = 1 
		else
			idx = idx + 1
		end--]]
	end	

	AIData.AddSteps(id, math.random(10, 50))
	--AIData.UpdateNavigationProgress(id, idx)

	RandomSleep(3, 4)
end

function ActionNode.StartBountyFight(id)
	AI_DEBUG_LOG(string.format("AI %d start bounty fight", id))
	AIData.StartBountyFight(id)
end

function ActionNode.InplaceCheck(id)
	AI_DEBUG_LOG(string.format("AI %d inplace check", id))
	AIData.InplaceCheck(id)
	AIData.SetHasKickUnactiveMember(id, nil)
	RandomSleep(1, 1)
end

function ActionNode.InplaceReady(id)
	AI_DEBUG_LOG(string.format("AI %d inplace ready", id))
	RandomSleep(1, 3)
	AIData.InplaceReady(id)
	RandomSleep(1, 1)
end

function ActionNode.StartFight(id)
	AI_DEBUG_LOG(string.format("AI %d start Fight", id))
	local next_fight, err = AIData.GetNextFight(id)
	if not next_fight then
		AI_DEBUG_LOG(string.format("AI %d start Fight fail err %s", id, err))
		return
	end

	AI_DEBUG_LOG(string.format("AI %d start Fight %d", id, next_fight))
	AIData.StartFight(id, next_fight)
end

function ActionNode.StartBountyQuest(id)
	AIData.StartBountyQuest(id)
	AIData.SetStatus(id, STATUS_TASKING)
	RandomSleep(1, 3)
end

function ActionNode.FindNpc(id)
	AI_DEBUG_LOG(string.format("AI %d find npc", id))
	AIData.FindNpc(id)
	RandomSleep(5, 10)
end

function ActionNode.CleanOldData(id)
	AI_DEBUG_LOG(string.format("AI %d clean old data", id))
	AIData.CleanOldData(id)
	AIData.SetStatus(id, STATUS_PREPARE)
	RandomSleep(1, 1)
end

function ActionNode.ChangeStatusToPrepare(id)
	AI_DEBUG_LOG(string.format("AI %d change status to prepare", id))
	AIData.SetStatus(id, STATUS_PREPARE)
	RandomSleep(1, 1)
end

function ActionNode.ChangeStatusToWaiting(id)
	AI_DEBUG_LOG(string.format("AI %d change status to waiting", id))
	AIData.SetStatus(id, STATUS_WAITING)
	RandomSleep(1, 1)
end

function ActionNode.SetBeginTaskTime(id)
	AI_DEBUG_LOG(string.format("AI %d set begin task time", id))
	AIData.SetBeginTaskTime(id)
	RandomSleep(1, 1)
end

function ActionNode.BeginTask(id)
	AI_DEBUG_LOG(string.format("AI %d begin task", id))
	AIData.SetStatus(id, STATUS_TASKING)
	AIData.CleanBeginTaskTime(id)
	RandomSleep(1, 1)
end

function ActionNode.SetDeadlineTime(id)
	AI_DEBUG_LOG(string.format("AI %d set dead line time", id))
	AIData.SetDeadlineTime(id)
	RandomSleep(1, 1)
end

function ActionNode.DissolveTeamAndPrepare(id)
	AI_DEBUG_LOG(string.format("AI %d dissolve team and prepare", id))
	AIData.SetStatus(id, STATUS_PREPARE)
	AIData.DissolveTeam(id)
	RandomSleep(1, 1)
end

function ActionNode.DissolveTeamAndCleanBountyInfoAndPrepare(id)
	AI_DEBUG_LOG(string.format("AI %d dissolve team and clean bounty info and prepare", id))
	AIData.CleanBountyInfo(id)
	AIData.SetStatus(id, STATUS_PREPARE)
	AIData.DissolveTeam(id)
	RandomSleep(1, 1)
end

function ActionNode.DissolveTeamAndLogout(id)
	AI_DEBUG_LOG(string.format("AI %d dissolve team and logout", id))
	AIData.DissolveTeam(id)
	AIData.LogoutMap(id)
	--AIData.Unload(id)
	return "Logout"
end

function ActionNode.ChangeLeaderAndLogout(id)
	AI_DEBUG_LOG(string.format("AI %d change leader and logout", id))
	AIData.ChangeLeader(id)
	AIData.LeaveTeam(id)
	AIData.LogoutMap(id)
	--AIData.Unload(id)
	return "Finish"
end

function ActionNode.AIAutoMatch(id)
	AI_DEBUG_LOG(string.format("AI %d auto match", id))
	AIData.AIAutoMatch(id)
	RandomSleep(1, 2)
end

function ActionNode.LeaveTeamAndReAutoMatch(id)
	AI_DEBUG_LOG(string.format("AI %d leave team and reautomatch", id))
	local team = AIData.GetTeam(id)
	if team then
		local group = team.group
		AIData.LeaveTeam(id)
		AIData.SetTeamAllFightFinish(team.teamid, group)
		AIData.SetStatus(id, STATUS_PREPARE)
	end
end

function ActionNode.Logout(id)
	AI_DEBUG_LOG(string.format("AI %d logout", id))
	RandomSleep(5, 15)
	AIData.LeaveTeam(id)
	AIData.LogoutMap(id)
	--AIData.Unload(id)
	return "Logout"
	--StopAction(id)
end

function ActionNode.LogoutAndFinish(id)
	AI_DEBUG_LOG(string.format("AI %d logout and finish", id))
	RandomSleep(5, 15)
	AIData.LeaveTeam(id)
	AIData.LogoutMap(id)
	--AIData.Unload(id)
	return "Finish"
end

function ActionNode.FinishChangeName(id)
	AI_DEBUG_LOG(string.format("AI %d FinishChangeName and do next action", id))
	--AIData.Unload(id)
	return "Finish"
end

function ActionNode.WaitingForFightFinish(id)
	AI_DEBUG_LOG(string.format("AI %d waiting for fight finish", id))
	AI.waiting["FIGHT_FINISH"] = true
	AI.co = coroutine.running()
	local winner, fight_id = coroutine.yield()

	is_fighting = false 
	AI_DEBUG_LOG(string.format("fight %d finish winner %d", fight_id, winner))
	AIData.UpdateFightResult(id, fight_id, winner)
end

function ActionNode.WaitingForAllMemberReady(id)
	AI_DEBUG_LOG(string.format("AI %d waiting for all member ready", id))
	AI.waiting["MEMBER_READY"] = true	
	AI.co = coroutine.running()
	AI.RegisterTimeout("MEMBER_READY", 70)
	coroutine.yield()
end

function ActionNode.DoNothing(id)
	AI_DEBUG_LOG(string.format("AI %d do nothing", id))
	RandomSleep(1, 1)
end

function ActionNode.GetAction(name)
	if not ActionNode[name] then
		AI_DEBUG_LOG(string.format("donnt has action %s", name))
	end
	return ActionNode[name]
end

function ActionNode.AddFriend(id)
	FriendData.AddFriend(id)
	FriendData.PresentEnergy(id)

	FriendData.Unload(id)

	return "Finish"
end

function ActionNode.FinishTargetFriend(id)
	FriendData.Unload(id)

	return "Finish"
end

function ActionNode.ApplyGuild(id)
	return GuildData.ApplyGuild(id)
end

function ActionNode.DoGuildWork(id)
	return GuildData.DoGuildWork(id)
end

function ActionNode.DoLeaderWork(id)
	return GuildData.DoLeaderWork(id)
end

function ActionNode.ChangeName(id)
	--local rand_name =  ai_name_config[math.random(1, #ai_name_config)].name
	for i = 1, 10, 1 do	
		local sexual = math.random(0, 1) 
		local rand_name = AIName.GetAIRandomName(sexual)
		if rand_name then
			local success = AIData.UpdateNickName(id, rand_name)
			if success then
				AIData.ChangeSexual(id, sexual)
				AI_DEBUG_LOG(string.format("AI %d change sexual to %d", id, sexual))
				return 
			end
		end
	end

	return "ForceQuit"
end

function ActionNode.ChangeHead(id)
	local level = AIData.GetAILevel(id)
	if not level then
		return
	end

	local head_cfg = BattleConfig.GetHeadConfig(level)
	if not head_cfg then
		return 
	end

	local head = head_cfg[math.random(1, #head_cfg)]
	AI_DEBUG_LOG(string.format("AI %d change head %d", id, head.head))
	AIData.UpdateNickName(id, nil, head.head)

	AIData.SetTodayHasChangeHead(id)
end

function ActionNode.KickAIMember(id)
	local team = AIData.GetTeam(id)
	local min_level = 9999
	local min_level_ai 
	AI_DEBUG_LOG(string.format("AI %d kick ai team members", id), sprinttb(team.members))
	for k, v in ipairs(team.members) do
		if v.level < min_level and v.pid < 100000 and id ~= v.pid then
			min_level = v.level
			min_level_ai = v.pid	
		end	
	end

	AI_DEBUG_LOG(string.format("AI %d Kick AI member >>>>>>>>>>>>>>>>>>>>", id), min_level_ai)
	if min_level_ai then
		AIData.LeaveTeam(id, min_level_ai)
		AIData.SetHasKickAI(id, true)
	else
		AIData.SetHasKickAI(id, true)
	end	

end

function ActionNode.SetDissolveTimeline(id)
	AIData.SetDissolveTeamTimeLine(id)
end

function ActionNode.ClearDissolveTimeline(id)
	AIData.ClearDissolveTeamTimeLine(id)
end

function ActionNode.SetTeamDissolveTimelineWhenAllMemberIsAI(id)
	AIData.SetDissolveTeamTimeLineWhenAllAI(id)
end

function ActionNode.SetShoutTimeLine(id)
	local team = AIData.GetTeam(id)
	if not team then
		return 	
	end

	local real_mem_count = 0
	for k, v in ipairs(team.members or {}) do
		if v.pid > 100000 then
			real_mem_count = real_mem_count + 1
		end
	end

	local interval
	if real_mem_count == 0 then
		interval = 300 
	elseif real_mem_count == 1 then
		interval = 150 
	elseif real_mem_count == 2 then
		interval = 90
	elseif real_mem_count == 3 then
		interval = 60 
	end

	if interval then
		AIData.SetShoutTimeLine(id, interval)
	end
end

function ActionNode.CancelShoutTimeLine(id)
	AIData.CancelShoutTimeLine(id)
end

function ActionNode.ShoutInWorld(id)
	local target_str = AIData.GetTargetStr(id)
	local lower_level , upper_level = AIData.GetTeamLevelLimit(id)
	local mem_count = AIData.GetTeamMemberCount(id)
	AIData.Chat(id, 10, string.format("%s(%d/5)\n[%d级-%d级]进组啦[-1#申请入队]", target_str, mem_count or 1, lower_level or 0, upper_level or 200))
	AIData.CancelShoutTimeLine(id)
end

function ActionNode.KickUnactiveMember(id)
	local team = AIData.GetTeam(id)
	if not team then
		return 
	end

	local kick_list = {}
	for k, v in ipairs(team.members or {}) do
		if v.ready == 0 then
			table.insert(kick_list, v.pid)
		end
	end

	for k, kpid in ipairs(kick_list) do
		AIData.LeaveTeam(id, kpid)
	end	

	AIData.SetInplaceCheckingTime(id, 0)
	AIData.SetHasKickUnactiveMember(id, true)
end

function ActionNode.DoNextQuest(id)
	local current_pos = AIData.GetPos(id)
	local current_step = AIData.GetCurrentStep(id)
	if not current_step then
		return 
	end
	print("current_step >>>>>>>>>>>>>>", current_step)

	local quest_cfg = BattleConfig.GetQuestConfig(current_step)
	if not quest_cfg then
		return 
	end

	if not current_pos or not current_pos.mapid or current_pos.mapid ~= quest_cfg.mapid then
		AI_DEBUG_LOG(string.format("AI %d enter into main quest map, map %d", id, quest_cfg.mapid))			
		local init_pos = BattleConfig.GetInitPos(quest_cfg.mapid)
		if not init_pos then
			AIData.MapMove(id, 0, 0, 0, quest_cfg.mapid, 2, 1)
		else
			AIData.MapMove(id, init_pos.x, init_pos.y, init_pos.z, quest_cfg.mapid, 2, 1)
		end
		RandomSleep(2,2)
	end	
	AI_DEBUG_LOG(string.format("AI %d move in quest map directly", id))			
	AIData.MapMove(id, quest_cfg.x, quest_cfg.y, quest_cfg.z)
	local sleep_time = math.random(quest_cfg.min_time, quest_cfg.max_time) + 5
	RandomSleep(sleep_time, sleep_time)
	
	-- send exp
	local exp = {{type = 90, id = 90000, value = quest_cfg.exp}}
	cell.sendReward(id, exp, nil, Command.REASON_AI_GET_EXP, false)

	if current_step == 21 then
		local level = AIData.GetAILevel(id,force)
		if level then
			local head_cfg = BattleConfig.GetHeadConfig(level)
			if head_cfg then
				local head = head_cfg[math.random(1, #head_cfg)]
				AI_DEBUG_LOG(string.format("AI %d change head %d", id, head.head))
				AIData.UpdateNickName(id, nil, head.head)
			end

		end
		
		for i = 1, 10, 1 do
			local sexual = math.random(0, 1)
			local rand_name = AIName.GetAIRandomName(sexual)
			print(string.format("AI %d begin to change name", id))
			if rand_name and AIData.UpdateNickName(id, rand_name)then
				print(string.format("AI %d change name success", id))	
				AIData.ChangeSexual(id, sexual)
				AI_DEBUG_LOG(string.format("AI %d change sexual to %d", id, sexual))
				break
			end
		end
	end

	AIData.SetNextStep(id, quest_cfg.next_step)
	
	RandomSleep(1, 2)	
end

function ActionNode.ProcessJoinRequest(id)
	AIData.ConfirmJoinRequest(id)
end

function ActionNode.Vote(id)
	local candidate = AIData.GetVote(id)

	if candidate and candidate ~= 0 then
		AIData.Vote(id, candidate, 1)	
		AIData.RemoveVote(id)
	end
end

return ActionNode
