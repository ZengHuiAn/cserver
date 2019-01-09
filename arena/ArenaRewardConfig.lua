local log = require "log"
local BinaryConfig = require "BinaryConfig"
require "printtb"

local function insertItem(t, type, id, value)
	if type == 0 or id == 0 then
		return
	end

	table.insert(t, {type = type, id = id, value = value})
end

local arena_enemy_reward_config = nil
local arena_enemy_reward_config_by_id = nil
local arena_box_reward_config = nil
local arena_box_reward_config_by_id = nil

local function load_arena_reward_config()
	local rows = BinaryConfig.Load("config_Arena_reward", "arena")	
	arena_enemy_reward_config = {}
	arena_enemy_reward_config_by_id = {} 
	arena_box_reward_config = {}
	arena_box_reward_config_by_id = {} 

	for _, row in ipairs(rows) do
		if row.type == 1 then
			arena_enemy_reward_config[row.condition] = arena_enemy_reward_config[row.condition] or {total_weight = 0 , list = {}}
			table.insert(arena_enemy_reward_config[row.condition].list, {id = row.id, weight = row.weight})

			arena_enemy_reward_config[row.condition].total_weight = arena_enemy_reward_config[row.condition].total_weight + row.weight

			arena_enemy_reward_config_by_id[row.id] = arena_enemy_reward_config_by_id[row.id] or {reward = {},  extra_reward = {}, drop_id = row.drop_id }
			insertItem(arena_enemy_reward_config_by_id[row.id].reward, row.reward_type1, row.reward_id1, row.reward_num1)
			insertItem(arena_enemy_reward_config_by_id[row.id].reward, row.reward_type2, row.reward_id2, row.reward_num2)
			insertItem(arena_enemy_reward_config_by_id[row.id].reward, row.reward_type3, row.reward_id3, row.reward_num3)
			insertItem(arena_enemy_reward_config_by_id[row.id].extra_reward, row.extra_reward_type, row.extra_reward_id, row.extra_reward_num)
		else
			arena_box_reward_config[row.condition] = arena_box_reward_config[row.condition] or {}
			table.insert(arena_box_reward_config[row.condition], {id = row.id, lv_down = row.lv_down, lv_up = row.lv_up})

			arena_box_reward_config_by_id[row.id] = arena_box_reward_config_by_id[row.id] or {lv_down = row.lv_down, lv_up = row.lv_up, reward_factor1 = row.reward_factor1, reward = {},
				drop_id = row.drop_id }
			insertItem(arena_box_reward_config_by_id[row.id].reward, row.reward_type1, row.reward_id1, row.reward_num1)
			insertItem(arena_box_reward_config_by_id[row.id].reward, row.reward_type2, row.reward_id2, row.reward_num2)
			insertItem(arena_box_reward_config_by_id[row.id].reward, row.reward_type3, row.reward_id3, row.reward_num3)
		end	
	end
end

load_arena_reward_config()

function GetArenaEnemyRewardConfig(id)	
	return arena_enemy_reward_config_by_id[id] or nil	
end

function GetArenaBoxRewardConfig(id)	
	return arena_box_reward_config_by_id[id] or nil	
end

function RandomEnemyRewardConfig(difficulty)
	local cfg = arena_enemy_reward_config[difficulty]
	if not cfg then
		log.debug(string.format("random enemy reward fail, cannot get reward config for difficulty:%d", difficulty))
		return nil
	end

	local rand_num = cfg.total_weight >= 1 and math.random(1, cfg.total_weight) or 0
	
	for k, v in ipairs(cfg.list or {}) do
		if rand_num <= v.weight then
			return v.id
		else
			rand_num = rand_num - v.weight
		end
	end
	
	log.warning("total_weight is ", cfg.total_weight)
	return 0
end

function GetBoxRewardID(condition, level)
	local cfg = arena_box_reward_config[condition]
	if not cfg then
		log.debug(string.format("get box reward id fail, cannt get box config for condition:%d", condition))
		return nil
	end

	for k, v in ipairs(cfg or {}) do
		if level >= v.lv_down and level <= v.lv_up then
			return v.id
		end
	end
	
	return 0	
end
