local BattleConfig = require "BattleConfig"
local AIData = require "AIData"
local EventList = require "EventList"
require "ConditionConfig"
local acting_list = {}
local function ReadScript(name)
    AI_DEBUG_LOG("ReadScript", name);
	return dofile(name .. ".lua")
    --assert(t = loadfile(name .. ".lua"))();
end

local function AllTargetsFinish(id)
	if not acting_list[id] then
		AI_WARNING_LOG(string.format("check all targets finish fail, AI %d not active", id))
		return false 
	end

	for k, v in pairs(acting_list[id].targets) do
		if v.finish_count < v.total_round  then
			return false
		end
	end

	return true
end

local function SetTargetFinish(id, target)
	if not acting_list[id] then
		AI_WARNING_LOG(string.format("set target finish fail, AI %d not active", id))
		return nil
	end

	if acting_list[id].targets then
		acting_list[id].targets[target].finish_count =  acting_list[id].targets[target].finish_count + 1
	else
		AI_WARNING_LOG(string.format("set target finish fail, AI %d not has target %d", id, target))
	end	
end

local function AddTryCount(id, target)
	if not acting_list[id] then
		AI_WARNING_LOG(string.format("set target try count fail, AI %d not active", id))
		return nil
	end

	if acting_list[id].targets then
		acting_list[id].targets[target].try_count =  acting_list[id].targets[target].try_count + 1
	else
		AI_WARNING_LOG(string.format("add target try count fail, AI %d not has target %d", id, target))
	end

	if acting_list[id].targets and acting_list[id].targets[target].try_count >= acting_list[id].targets[target].try_count_limit then
		acting_list[id].targets[target].finish_count =  acting_list[id].targets[target].finish_count + 1
	end
end

local function SetAllTargetFinish(id)
	if not acting_list[id] then
		AI_WARNING_LOG(string.format("set target finish fail, AI %d not active", id))
		return nil
	end

	for k, v in pairs(acting_list[id].targets) do
		v.finish_count = v.total_round  
	end
end

local TARGET_TYPE_FREE_MOVE = 10004
local TARGET_TYPE_CHANGE_NAME = 10001

local function GetTargetByLogic(targets, id)
	assert(#targets > 0)

	local normal_targets = {}
	local dynamic_targets = {}
	local final_targets = {}
	for _, target in ipairs(targets) do
		if target > 50 and target < 10000 then
			table.insert(dynamic_targets, target)	
		else
			table.insert(normal_targets, target)
		end	
	end	

	if #normal_targets > 0 then
		has_dynamic_targets = 0
		if #dynamic_targets > 0 then
			has_dynamic_targets = 1
		end

		local rand = math.random(1, #normal_targets + has_dynamic_targets)
		if rand <= #normal_targets then
			return normal_targets[rand]	
		else
			-- TODO
			local target_priority = GetTargetPriority(dynamic_targets)	
			local highest_priority = 9999
			local highest_priority_target = 0

			if not target_priority or not target_priority.targets_priority then
				print(string.format("AI %d get targets priority fail >>>>>>>>>>>", id), sprinttb(dynamic_targets))
				return dynamic_targets[math.random(1, #dynamic_targets)]
			end

			final_targets = {}
			for _, v in ipairs(target_priority.targets_priority or {}) do
				AI_DEBUG_LOG(string.format("AI %d ############target %d priority %f", id, v.target, v.priority))
				if v.priority < highest_priority then
					highest_priority = v.priority
				end
			end

			for _, v in ipairs(target_priority.targets_priority or {}) do
				if v.priority == highest_priority then
					table.insert(final_targets, v.target)
				end
			end
			local rand_idx = math.random(1, #final_targets)
			AI_DEBUG_LOG("all targets >>>>>>>>>>>>>>", id, sprinttb(targets))
			AI_DEBUG_LOG(string.format("%d highest priority %f", id, highest_priority, final_targets[rand_idx]), rand_idx, sprinttb(final_targets))

			return final_targets[rand_idx]
		end	
	end

	--TODO
	local target_priority = GetTargetPriority(dynamic_targets)	
	local highest_priority = 9999
	local highest_priority_target = 0
	final_targets = {}
	if target_priority and target_priority.targets_priority then
		for _, v in ipairs(target_priority.targets_priority) do
			AI_DEBUG_LOG(string.format("AI %d ############target %d priority %f", id, v.target, v.priority))
			if v.priority < highest_priority then
				highest_priority = v.priority
			end
		end

		for _, v in ipairs(target_priority.targets_priority or {}) do
			if v.priority == highest_priority then
				table.insert(final_targets, v.target)
			end
		end	

		local rand_idx = math.random(1, #final_targets)
		AI_DEBUG_LOG(string.format("%d highest priority %f", id, highest_priority, final_targets[rand_idx]), rand_idx, sprinttb(final_targets))

		return final_targets[rand_idx]
	else
		return dynamic_targets[math.random(1, #dynamic_targets)]
	end
end

local DEFAULT_PRIORITY = 3
local function GetTarget(id, first_target)
	if not acting_list[id] then
		AI_WARNING_LOG(string.format("get random target fail, AI %d not active", id))
		return nil
	end

	if acting_list[id].targets[TARGET_TYPE_CHANGE_NAME] and acting_list[id].targets[TARGET_TYPE_CHANGE_NAME].finish_count < acting_list[id].targets[TARGET_TYPE_CHANGE_NAME].total_round then
		return TARGET_TYPE_CHANGE_NAME
	end

	if acting_list[id].targets[first_target] and acting_list[id].targets[first_target].finish_count < acting_list[id].targets[first_target].total_round then
		print(string.format("AI %d return first target", id))
		return first_target
	end

	local t = {}
	local t2 = {}
	local target_free_move_not_finish = false
	local highest_priority = 9999 
	for k, v in pairs(acting_list[id].targets) do
		if v.finish_count < v.total_round and k ~= TARGET_TYPE_FREE_MOVE then
			table.insert(t, k)
			if not priority_cfg[k] then
				priority_cfg[k] = DEFAULT_PRIORITY 
			end
			if priority_cfg[k] and priority_cfg[k] < highest_priority then
				highest_priority = priority_cfg[k]
			end
		end
	end

	if highest_priority == 1 then
		return TARGET_TYPE_CHANGE_NAME
	end

	for _, v in ipairs(t) do
		if priority_cfg[v] == highest_priority then
			table.insert(t2, v)
		end
	end

	local target_free_move_finish = false
	if condition_cfg[TARGET_TYPE_FREE_MOVE] and acting_list[id].targets[TARGET_TYPE_FREE_MOVE].finish_count >= acting_list[id].targets[TARGET_TYPE_FREE_MOVE].total_round then
		target_free_move_finish = true
	end

	if #t2 == 0 and not target_free_move_finish then
		return TARGET_TYPE_FREE_MOVE
	end

	if #t2 == 0 and target_free_move_finish then
		return 0
	end

	if highest_priority ~= 3 then
		return GetTargetByLogic(t2, id)
	else	
		if target_free_move_finish then
			return GetTargetByLogic(t2, id)
		else		
			local rand = math.random(1, 100)
			if rand <= 10 then
				return TARGET_TYPE_FREE_MOVE
			else
				return GetTargetByLogic(t2, id)
			end
		end
	end

end


local function CheckLimit(id, target)
	assert(id)
	assert(target)

	local target_type = GetTargetType(target)
	if target_type ~= "team_fight" and target_type ~= "bounty" and target_type ~= "main_quest" then
		return true
	end

	local player = cell.getPlayerInfo(id)
	local level 
	if player and player.level then
		level = player.level
		AIData.SetAILevel(id, level)
	else	
		AI_WARNING_LOG("fail to check limit, get player level failed.");	
		return false
	end

	if target_type == "team_fight" or target_type == "bounty" then
		local activity_cfg = BattleConfig.GetActivityConfig(target)
		if not activity_cfg then
			AI_WARNING_LOG("fail to check limit, get activity config failed.");	
			return false
		end

		if level >= activity_cfg.lv_limit then
			return true
		end	

		return false
	end

	if target_type == "main_quest" then
		if level < 28 then
			return true
		else
			return false
		end
	end
end

local function UnixTimeStampToFormatTime(t)
	return os.date("%Y-%m-%d  %H:%M:%S", t)
end

local acting_ai_num = 0
function Create(id, first_target)
	local t = ReadScript("BehaviorTree") 
	local co = coroutine.create(function()
		--t = ReadScript("BehaviorTree")
		--t.main(id)

		AILoginChat(id)
		AILoginGuild(id)
		while(true) do
			if AllTargetsFinish(id) then
				AI_DEBUG_LOG(string.format("AI %d All target finish", id))
				--cell.UpdateAIActiveTime(id, loop.now())	
				StopAction(id)
				AILogoutChat(id)
				AILogoutGuild(id)
				break
			end

			local target = GetTarget(id, first_target)
			--assert(target ~= 0, string.format("AI %d target cannt be 0 ", id)..debug.traceback()..sprinttb(acting_list[id].targets))
			if target and target == 0 then
				log.error(string.format("AI %d target cannt be 0 ", id))
				break
			end

			if not target then
				AI_WARNING_LOG("get random target fail")
				break
			end

			AI_DEBUG_LOG(string.format("AI %d begin to do target %d", id, target))
			
			AIData.Init(id)
			AIData.SetTarget(id, target)

			--check lv limit
			if not CheckLimit(id, target) then
				AI_DEBUG_LOG(string.format("AI %d level not enough to do target %d", id, target))
				SetTargetFinish(id, target)
			else	
				--EventList.Create(id)
				local finish, stat = t.MAIN(id, target)
				AIData.Unload(id)
				--EventList.Remove(id)
				if finish then
					if stat == "ForceQuit" then
						SetAllTargetFinish(id)
						AI_DEBUG_LOG(string.format("AI %d force quit", id))
					else
						SetTargetFinish(id, target)
						AI_DEBUG_LOG(string.format("AI %d finish target %d", id, target))
					end
				else
					AddTryCount(id, target)
					AI_DEBUG_LOG(string.format("AI %d add try count target %d", id, target))
				end	
			end
		end
	end)

	acting_list[id] =  {
		thread = co,
		acting_time = UnixTimeStampToFormatTime(loop.now()),
		main = t.main,		
		callback = t.onEvent,
		targets = {}
	}

	for k, v in pairs(condition_cfg) do--i = TARGET_MIN, TARGET_MAX, 1 do
		if k == TARGET_TYPE_FREE_MOVE then
			acting_list[id].targets[k] = {try_count = 0, try_count_limit = 3, finish_count = 0, total_round = 20}
		--[[elseif k == 10001 then
			acting_list[id].targets[k] = {finish_count = 0, total_round = 1}
		end--]]
		else
			acting_list[id].targets[k] = {try_count = 0, try_count_limit = 3, finish_count = 0, total_round = 1}
		end
	end 

	

	acting_ai_num = acting_ai_num + 1;

	local success, info = coroutine.resume(co);
	if not success then
		log.error("fail to start coroutine: " .. info);
		co = nil;
		acting_list[id] = nil
		acting_ai_num = acting_ai_num - 1
		return 
	end
end

local function PrintActingAI()
	local str = {}
	local count = 0
	for id, v in pairs(acting_list) do
		count = count + 1
		local idx = math.ceil(count / 50)
		if idx <= 16 then
			str[idx] = str[idx] or "\n"
			str[idx] = str[idx] .. string.format("[STATISTICS]AI %d acting_time: %s count: %d|\n", id, v.acting_time, count)
		end
	end
	
	for k, v in ipairs(str) do
		log.debug(v)
	end	
end

local function Acting(id)
	return acting_list[id]
end

local function GetActingNum(id)
	return acting_ai_num	
end

local function GetCallBack(id)
	return acting_list[id] and acting_list[id].callback or nil
end

local function Dispatch(channel, cmd, ...)
	local callBack = GetCallBack(channel)
	if callBack then
		pcall(callBack, cmd, ...)
	end
end

-- interface
function StopAction(id) 
	if acting_list[id] then
		acting_list[id] = nil
		acting_ai_num = acting_ai_num - 1
	end
end


local login_player_count = 0
local create_co 
local create_list = {}
local need_to_resume = false
local function ActiveAI(count, ref_level, first_target, reason, pid)
	local acting_ai_num = GetActingNum()
	if acting_ai_num > 800 then
		AI_DEBUG_LOG("AI already reach max")
	end

	if count <= 0 then
		AI_WARNING_LOG(string.format("cannt active ai for num %d", count))
		return 
	end

	for i = 1, count, 1 do
		table.insert(create_list, {ref_level = ref_level, first_target = first_target, reason = reason})
	end
	if not create_co then
		create_co = coroutine.create(function()
			while true do
				while(#create_list > 0) do
					local info = create_list[1]
					local ai, true_level = cell.QueryUnactiveAI(info.ref_level)
					if not ai then
						table.remove(create_list, 1)
					else	
						if not Acting(ai) then 
							AI_DEBUG_LOG(string.format("create new ai----------------------------------------> id %d, ref_level %d, true_level %d, first_target %d reason %s", ai, info.ref_level or 0, true_level or 0, info.first_target or 0, info.reason), pid, #create_list)
							Create(ai, info.first_target)
							NotifyAIEnter(ai)
						end

						table.remove(create_list, 1)
					end
					Sleep(2)
				end
				need_to_resume = true
				coroutine.yield()	
			end	
		end)

		local success, info = coroutine.resume(create_co)
		if not success then
			log.error("fail to start create coroutine: " .. info);
		end
	end

	if create_co and coroutine.status(create_co) == "suspended" and need_to_resume then
		need_to_resume = false
		local success, info = coroutine.resume(create_co, "resume right")
		if not success then
			log.error("fail to start coroutine: " .. info);
		end
	end
end

local once = false
local function ActiveAIByNum(ref_level, pid)
	--[[if not once then
		ActiveAI(200, ref_level)
		once = true
	end--]]
	local acting_ai_num = GetActingNum()
	local ratio = acting_ai_num / (login_player_count > 0 and login_player_count or 1)
	if acting_ai_num < 200 then
		if ratio <= 8 then
			ActiveAI(30, ref_level, nil, "LOGIN", pid)
		else
			ActiveAI(30, ref_level, nil, "LOGIN", pid)
		end
	elseif acting_ai_num < 400 then
		if ratio <= 8 then
			ActiveAI(3, ref_level, nil, "LOGIN", pid)
		else
			ActiveAI(1, ref_level, nil, "LOGIN", pid)
		end
	elseif acting_ai_num <700 then
		if ratio <= 5 then
			ActiveAI(2, ref_level, nil, "LOGIN", pid)
		else
			ActiveAI(2, ref_level, nil, "LOGIN", pid)
		end
	end	
end

local service_start = loop.now()
local start 

local function AddLoginPlayerCount()
	login_player_count = login_player_count + 1
end

local function DecreaseLoginPlayerCount()
	if login_player_count > 0 then
		login_player_count = login_player_count - 1
	end
end

local function AIStart()
	return start
end

Scheduler.New(function(t)
	if (loop.now() - service_start > 2) and not start then
		NotifyAIServiceRestart()
		start = true
		ActiveAI(login_player_count * 4)
		--[[co = coroutine.create(function()
			local ai = cell.QueryUnactiveAI()
			if not Acting(ai) then 
				Create(ai, 2)
			end
		end)
		coroutine.resume(co)--]]
	end

	if t % 3600 == 0 then
		local acting_ai_num = GetActingNum()
		log.debug(string.format("[STATISTICS]AI acting_ai_num %d", acting_ai_num))
		PrintActingAI()
		log.debug(string.format("[STATISTICS]online player count %d", login_player_count or 0))
	end
end)

module "AILogic"

AddLoginCount = AddLoginPlayerCount
DecreaseLoginCount = DecreaseLoginPlayerCount
AI_Start = AIStart
ActAIByNum = ActiveAIByNum
ActAI = ActiveAI
