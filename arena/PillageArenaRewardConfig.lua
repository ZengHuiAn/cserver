local PillageArenaRewardConfig = nil

local log = require "log"
local BinaryConfig = require "BinaryConfig"
require "printtb"

local function insertItem(t, type, id, value)
	if type == 0 or id == 0 or value == 0 then
		return
	end

	table.insert(t, {type = type, id = id, value = value})
end

local function load_pillage_arena_reward_config()
	local rows = BinaryConfig.Load("config_arena_rank", "arena")	
	PillageArenaRewardConfig = {}

	for _, row in ipairs(rows) do
		PillageArenaRewardConfig[row.Order] = PillageArenaRewardConfig[row.Order] or  {}
		local t = {
			rank_begin = row.Rank1,
			rank_end = row.Rank2,
			reward = {}	
		}
		insertItem(t.reward, row.Item_type1, row.Item_id1, row.Item_value1)
		insertItem(t.reward, row.Item_type2, row.Item_id2, row.Item_value2)
		table.insert(PillageArenaRewardConfig[row.Order], t)
	end
end

load_pillage_arena_reward_config()

function GetPillageArenaReward(rank, type) 
	for k, v in ipairs(PillageArenaRewardConfig[type] or {}) do
		if rank >= v.rank_begin and rank <= v.rank_end then
			return v.reward
		end
	end		
end
