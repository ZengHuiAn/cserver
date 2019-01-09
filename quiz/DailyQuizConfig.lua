local log = require "log"
local BinaryConfig = require "BinaryConfig"
require "printtb"

local dailyQuizConfig = nil
function LoadDailyQuizConfig()
	local rows = BinaryConfig.Load("config_meiridati", "quiz")	
	dailyQuizConfig = {count = 0}

	for _, row in ipairs(rows) do
		dailyQuizConfig.count = dailyQuizConfig.count + 1	
		dailyQuizConfig[row.id] = {
			id = row.id,
			type = row.type,
			right_answer1 = row.right_answer1,
			right_answer2 = row.right_answer2,
			right_answer3 = row.right_answer3
		}
	end
end

LoadDailyQuizConfig()

function GetQuizConfigSize()
	return dailyQuizConfig.count
end

function GetQuestion(id)
	return dailyQuizConfig[id]
end

function GetIdList()
	local ret = {}

	for id, _ in ipairs(dailyQuizConfig or {}) do
		table.insert(ret, id)	
	end

	return ret
end

local function insertRewardItem(t, reward_type, reward_id, reward_value)
	if reward_type == 0 or reward_id == 0 or reward_id == 0 then
		return	
	end

	table.insert(t, {type = reward_type, id = reward_id, value = reward_value})
end

local dailyQuizRewardConfig = nil
function LoadDailyQuizRewardConfig()
	local rows = BinaryConfig.Load("config_reward_meiridati", "quiz")	
	dailyQuizRewardConfig = {}

	for _, row in ipairs(rows) do
		dailyQuizRewardConfig[row.dati_type] = {} 
		insertRewardItem(dailyQuizRewardConfig[row.dati_type], row.reward_type1, row.reward_id1, row.reward_value1)
		insertRewardItem(dailyQuizRewardConfig[row.dati_type], row.reward_type2, row.reward_id2, row.reward_value2)
	end
end

LoadDailyQuizRewardConfig()

function GetQuizReward(type)
	return dailyQuizRewardConfig[type]
end
