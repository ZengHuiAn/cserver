--[[
	记录团队活动获得的奖励
--]]
local database = require "database"
local Command = require "Command"
local Agent = require "Agent"
local log = log

local SHILIAN = 1 	-- 试炼活动
local FUBEN = 2		-- 组队副本活动
local YUANSU = 3	-- 元素暴走活动

local MAX_AI_ID = 1000000

local TeamRewardManger = { map = {} }

function TeamRewardManger.Load(pid)
	local ok, result = database.query([[select pid,`th`, quest_id, `type`, id , value, 
		unix_timestamp(reward_time) as reward_time from team_reward where pid = %d;]], pid)
	if ok and #result > 0 then
		return result
	else
		return nil
	end
end

function TeamRewardManger.Insert(info)
	local ok = database.update([[insert into team_reward(pid, `th`, quest_id, `type`, id, value, reward_time) 
		values(%d, %d, %d, %d, %d, %d, from_unixtime_s(%d));]], info.pid, info.th, info.quest_id, info.type, info.id, info.value, info.reward_time)

	return ok
end

function TeamRewardManger.Delete(info)
	local ok = database.update([[delete from team_reward where pid = %d and `th` = %d;]], info.pid, info.th)

	return ok
end

function TeamRewardManger.GetReward(pid)
	if TeamRewardManger.map[pid] == nil then
		local t = TeamRewardManger.Load(pid)
		TeamRewardManger.map[pid] = TeamRewardManger.map[pid] or {}
		for _, v in ipairs(t or {}) do
			TeamRewardManger.map[pid][v.th] = v
		end
	end

	return TeamRewardManger.map[pid]
end

function TeamRewardManger.AddReward(pid, quest_id, rewards, way)
	if pid < MAX_AI_ID then
		return
	end

	local records = TeamRewardManger.GetReward(pid)
	local notify_reward = {}
	for _, reward in ipairs(rewards) do
		local th = table.maxn(records) + 1
		local r = { pid = pid, th = th, quest_id = quest_id, reward_time = loop.now() }
		if way == 1 then
			r.type = reward.type
			r.id = reward.id
			r.value = reward.value
			notify_reward = rewards
			break
		else
			r.type = reward[1]
			r.id = reward[2]
			r.value = reward[3]
			table.insert(notify_reward, { type = r.type, id = r.id, value = r.value })
		end
		if TeamRewardManger.Insert(r) then
			records[th] = r
		end
	end
	
	local cmd = Command.C_ADD_ACTIVITY_REWARD_NOTIFY 
	local agent = Agent.Get(pid);
	if agent then
		agent:Notify({ cmd, { notify_reward, loop.now() } })
	end	
end

function TeamRewardManger.RemoveOldRecords(pid)	
	local records = TeamRewardManger.GetReward(pid)
	local max_index = table.maxn(records)	

	for th, v in pairs(records) do
		if th < max_index - 100 then
			if TeamRewardManger.Delete(v) then
				records[th] = nil
			end
		else
			break
		end
	end
end

function TeamRewardManger.RegisterCommand(service)
	service:on(Command.C_QUERY_ACTIVITY_REWARD_REQUEST, function (conn, pid, request)
		local cmd = Command.C_QUERY_ACTIVITY_REWARD_RESPOND 
		log.debug(string.format("cmd: %d, player %d query activity reward records.", cmd, pid))

		local sn = request[1]
		TeamRewardManger.RemoveOldRecords(pid)
		local records = TeamRewardManger.GetReward(pid)
		local ret = {}
		for _, v in pairs(records) do
			table.insert(ret, { v.quest_id, v.type, v.id, v.value, v.reward_time })	
		end
			
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, ret })	
	end)

	service:on(Command.S_ADD_ACTIVITY_REWARD_NOTIFY, "AddActivityRewardNotify", function (conn, channel, request)
		local pid = request.pid or 0
		local quest_id = request.quest_id or 0
		local rewards = request.rewards
		
		log.debug(string.format("AddActivityRewardNotify: pid = %d, quest_id = %d, rewards is ", pid, quest_id))
		log.debug(sprinttb(rewards))

		TeamRewardManger.AddReward(pid, quest_id, rewards, 1)
	end)

end

return TeamRewardManger
