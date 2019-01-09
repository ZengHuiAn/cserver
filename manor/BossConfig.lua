local BinaryConfig = require "BinaryConfig"
local OpenlevConfig = require "OpenlevConfig"

local BossConfig = { map = {}, levelList = {} }
local rows1 = BinaryConfig.Load("public_quests", "quest")
if rows1 then
	for _, v in ipairs(rows1) do
		BossConfig.map[v.id] = BossConfig.map[v.id] or {}
		table.insert(BossConfig.map[v.id], v)
		BossConfig.levelList[v.id] = v.depend_level
	end
end

-- id是用来区别是世界boss还是军团boss
function BossConfig.Random(id)
	local list = BossConfig.map[id]
	local time = loop.now()
	local pool = {}

	for _, v in ipairs(list) do
		local begin_time = BeginTime(v.begin_time, v.period, time)
		local end_time = EndTime(v.end_time, v.period, time)
	
		if end_time - begin_time > 24 * 3600 then
			end_time = end_time - 24 * 3600
		end
		if time >= v.begin_time and time < v.end_time and time >= begin_time and time < end_time then
			table.insert(pool, v)
		end
	end

	if #pool == 0 then
		return nil
	end

	return pool[math.random(#pool)]
end

function BossConfig.GetRewardByIdAndTime(id, npc_id, time)
	local list = BossConfig.map[id]	
	for _, v in ipairs(list) do
		local begin_time = BeginTime(v.begin_time, v.period, time)
		local end_time = EndTime(v.end_time, v.period, time)
		if end_time - begin_time > 24 * 3600 then
			end_time = end_time - 24 * 3600
		end
		if v.npc_id == npc_id and time >= begin_time and time < end_time then
			local rewards = {}
			for i = 1, 3 do
				if v["reward_type" .. i] > 0 then
					table.insert(rewards, { type = v["reward_type" .. i], id = v["reward_id" .. i], value = v["reward_value" .. i] })
				end
			end
			return rewards, v.drop_id, v.drop_surprise
		end
	end
	
	return nil, 0, 0
end

function BossConfig.IsLevel(id, pid)
	local level = OpenlevConfig.get_level(pid)
	if BossConfig.levelList[id] < level then
		return true
	end

	return false
end

-----------------------------------------------------------------------------------------------
local PhaseRewardConfig = { map = {} }
local rows2 = BinaryConfig.Load("config_phase_reward", "quest")
if rows2 then
	for _, v in ipairs(rows2) do
		PhaseRewardConfig.map[v.type_id] = PhaseRewardConfig.map[v.type_id] or {}
		table.insert(PhaseRewardConfig.map[v.type_id], v)
	end
end

--[[function PhaseRewardConfig.GetPhaseRewardByRate(id, pid, old_rate, new_rate)
	local index = 0

	local rewards = {}
	local drop_id = 0
	local lv = OpenlevConfig.get_level(pid)
	local list = PhaseRewardConfig.map[id]
	for _, v in ipairs(list) do
		if lv >= v.lv_min and lv <= v.lv_max and new_rate >= v.damage_limit and old_rate < v.damage_limit then		
			for i = 1, 3 do
				if v["reward_type" .. i] > 0 then
					table.insert(rewards, { type = v["reward_type" .. i], id = v["reward_id" .. i], value = v["reward_value" .. i] })
				end
			end
		
			drop_id = v.drop_id
		end
	end
	
	return rewards, drop_id
end--]]

local function CheckRewardFlag(reward_flags, reward_id)
    local key = math.floor(reward_id / 30) + 1
    local idx = reward_id % 30

    local flag = reward_flags[key]
    if not flag then
        return false
    end

	local not_has_receive_reward = bit32.band(flag, 2^idx) == 0
	
	if not_has_receive_reward then
		reward_flags[key] = bit32.bor(flag, 2^idx)
	end

    return not_has_receive_reward 
end

--[[function PhaseRewardConfig.GetPhaseRewardByRate(id, pid, new_rate, reward_flags)
    local rewards = {}
    local drop_ids = {}
    local lv = OpenlevConfig.get_level(pid)
    local list = PhaseRewardConfig.map[id]
	local flag_change = false
	print(string.format("new_rate >>>>>>>>>>>>>>>> %f", new_rate))
    for _, v in ipairs(list) do
		print(">>>>>>>>>>>>", v.reward_interval, v.lv_min, v.damage_limt)
        if lv >= v.lv_min and lv <= v.lv_max and new_rate >= v.damage_limit and CheckRewardFlag(reward_flags, v.reward_interval) then
            for i = 1, 3 do
                if v["reward_type" .. i] > 0 then
                    table.insert(rewards, {type = v["reward_type" .. i], id = v["reward_id" .. i], value = v["reward_value" .. i] })
                end
            end

            if v.drop_id > 0 then
                table.insert(drop_ids, v.drop_id)
            end

			flag_change = true
        end
    end

    return rewards, drop_ids, flag_change 
end--]]

function PhaseRewardConfig.GetPhaseRewardByRate(id, pid, damage, reward_flags)
    local rewards = {}
    local drop_ids = {}
    local lv = OpenlevConfig.get_level(pid)
    local list = PhaseRewardConfig.map[id]
	local flag_change = false
    for _, v in ipairs(list) do
        if lv >= v.lv_min and lv <= v.lv_max and damage >= v.damage and CheckRewardFlag(reward_flags, v.reward_interval) then
            for i = 1, 3 do
                if v["reward_type" .. i] > 0 then
                    table.insert(rewards, {type = v["reward_type" .. i], id = v["reward_id" .. i], value = v["reward_value" .. i] })
                end
            end

            if v.drop_id > 0 then
                table.insert(drop_ids, v.drop_id)
            end

			flag_change = true
        end
    end

    return rewards, drop_ids, flag_change 
end

---------------------------------------------------------------------------------------------
local RankRewardConfig = { map = {} }
local rows3 = BinaryConfig.Load("rank_boss", "quest")
if rows3 then
	for _, v in ipairs(rows3) do
		RankRewardConfig.map[v.Order] = RankRewardConfig.map[v.Order] or {}
		table.insert(RankRewardConfig.map[v.Order], v)
	end
end

function RankRewardConfig.GetRankReward(id, rank)
	for _, v in ipairs(RankRewardConfig.map[id] or {}) do
		if v.Rank1 <= rank and rank <= v.Rank2 then
			local rewards = {}
			for i = 1, 3 do
				if v["reward_type" .. i] > 0 then
					table.insert(rewards, { type = v["reward_type" .. i], id = v["reward_id" .. i], value = v["reward_value" .. i] })
				end
			end
			return rewards
		end
	end

	return nil
end


return {
	Random = BossConfig.Random,
	GetRewardByIdAndTime = BossConfig.GetRewardByIdAndTime,
	GetPhaseRewardByRate = PhaseRewardConfig.GetPhaseRewardByRate,
	GetRankReward = RankRewardConfig.GetRankReward,
	GetOpenLevel = BossConfig.GetOpenLevel,
	IsLevel = BossConfig.IsLevel,
}
