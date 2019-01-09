local AIData = require "AIData"
local ActionNode = require "ActionNode"
local ConditionNode = require "ConditionNode"
require "ConditionConfig"
local EventList = require "EventList"
local AI = {waiting = {}, timeout_list = {}}


local target_name = {
	[1] = "每日副本 10级副本",
	[2] = "每日副本 30级副本",
	[3] = "每周副本 10级副本",
	[4] = "每周副本 30级副本",
}

local function CheckCondition(conditions, id)
	if not conditions then
		return false
	end

	for _, name in ipairs (conditions) do
		local condition = ConditionNode.GetCondition(name)
		if not condition then
			--log.error(string.format("cannt find cfg for condition %s", name))
			return false
		end
		if not condition(id) then
			--AI_DEBUG_LOG(string.format("AI %d check conditon %s fail", id, name))
			return false, name
		end
		--AI_DEBUG_LOG(string.format("AI %d check conditon %s success", id, name))
	end

	return true
end

function AI.MAIN(id)
	local target = AIData.GetTarget(id)
	if not target then
		AI_DEBUG_LOG(string.format("AI %d has no target", id))
		return 
	end

	AI_DEBUG_LOG(string.format("AI %d  目标: %s", id, target_name[target]))

	local cfg = condition_cfg[target]	
	if not cfg then
		return 
	end

	while (true) do
		AI_DEBUG_LOG("---------------------------------------------------")
		local nothing_to_do = true
		for k, v in ipairs(cfg) do
			--print(string.format("AI %d check event list ", id))
			--EventList.Pop(id)

			AI_DEBUG_LOG(string.format("AI %d check condition for action %s,  %s", id, v.action, v.log or ""))
			local success, fail_condition_name = CheckCondition(v.condition, id)
			if success then
				AI_DEBUG_LOG(string.format("AI %d check all condition success, action %s %s", id, v.action, v.log or ""))
				--AI_DEBUG_LOG("")

				local action = ActionNode.GetAction(v.action)
				if not action then
					AI_DEBUG_LOG(string.format("donnt has action %s", v.action))
				end
				if v.asleep then
					AIData.SetSleepTime(id)
				else
					AIData.ClearSleepTime(id)
				end	
		
			 	local ret = action(id)	
				nothing_to_do = false
				Sleep(1)

				if ret == "Logout" then
					return 
				elseif ret == "Finish" then
					return true
				elseif ret == "ForceQuit" then
					return true, "ForceQuit"
				else	
					break;
				end
			else	
			    AI_DEBUG_LOG(string.format("AI %d check condition for action %s fail, one of condition %s check fail", id, v.action, fail_condition_name or " "))
			end
			AI_DEBUG_LOG("")
			AI_DEBUG_LOG("")
		end
		
		if nothing_to_do then
			AI_DEBUG_LOG("nothing to do, sleep")
			AIData.SetSleepTime(id)
			Sleep(3)
		end
	end
end

--[[function AI.onEvent(event, ...)
	if event == "FIGHT_FINISH" then
		if AI.waiting[event] then
			AI.waiting[event] = nil
			local co = AI.co
			AI.co = nil
			coroutine.resume(co, ...)
		end
	end

	if event == "MEMBER_READY" then
		if AI.waiting[event] then
			AI.waiting[event] = nil
			local co = AI.co
			AI.co = nil
			
			AI.UnRegisterTimeout("MEMBER_READY")
			coroutine.resume(co, ...)
		end
	end
end--]]

--[[Scheduler.New(function(t)
	if t % 5 == 0 then
		AI.CheckTimeout(t)
	end
end)--]]

return AI 

