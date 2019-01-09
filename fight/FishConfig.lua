local BinaryConfig = require "BinaryConfig"

math.randomseed(os.time())

FishConfig = { }
local rows1 = BinaryConfig.Load("config_fish", "fish")
if rows1 then
	for i, v in ipairs(rows1) do
		local reward = {}
		if v.reward_item_type ~= 0 then
			reward = { type = v.reward_item_type, id = v.reward_item_id, value = v.reward_item_value }
		end
		local reward2 = { }
		if v.help_reward1_type ~= 0 then
			table.insert(reward2, { type = v.help_reward1_type, id = v.help_reward1_id, value = v.help_reward1_value })
		end
		if v.help_reward2_type ~= 0 then
			table.insert(reward2, { type = v.help_reward2_type, id = v.help_reward2_id, value = v.help_reward2_value })
		end

		FishConfig[v.power_id] = FishConfig[v.power_id] or { total = 0 }
		FishConfig[v.power_id].total = FishConfig[v.power_id].total + v.weight
		table.insert(FishConfig[v.power_id], { reward = reward, reward2 = reward2, is_help = v.is_help, probability = v.trigger_probability, fight_id = v.fight_id, weight = v.weight })
	end
end

-- 随机获得一条鱼
function FishConfig.RandomFish(power)
	local config = FishConfig[power]
	
	if not config then
		log.warning("RandomFish: random fish failed, power = ", power)
		return	
	end
	local n = math.random(config.total)
	for i, v in ipairs(config) do	
		if n <= v.weight then
			return v, i
		else
			n = n - v.weight
		end
	end
end

FishConsume = { }
local rows2 = BinaryConfig.Load("config_fish_consume", "fish")
if rows2 then
	if rows2[1] then
		local v = rows2[1]
		FishConsume.consume = { type = v.fish_consume_type_free, id = v.fish_consume_id_free, value = v.fish_consume_value_free }
		FishConsume.consume2 = { type = v.fish_consume_type, id = v.fish_consume_id, value = v.fish_consume_value }
		FishConsume.gofish_time_max = v.gofish_time_max
		FishConsume.gofish_time_min = v.gofish_time_min
		FishConsume.walkfish_time = v.walkfish_time
		FishConsume.helpfish_time = v.helpfish_time
		FishConsume.qtefish_time = v.qtefish_time
		FishConsume.effective_time = v.effective_time
	end
end

RankRewardConfig = {}
local rows3 = BinaryConfig.Load("config_fish_reward", "fish")
if rows3 then
	for i, v in ipairs(rows3) do
		local reward = { { type = v.reward_type1, id = v.reward_id1, value = v.reward_value1 }, { type = v.reward_type2, id = v.reward_id2, value = v.reward_value2 } }
		table.insert(RankRewardConfig, { min = v.fish_number_min, max = v.fish_number_max, reward = reward })
	end
end

function get_rank_reward(rank)
	for i, v in ipairs(RankRewardConfig) do
		if rank >= v.min and rank <= v.max then
			return v.reward	
		end
	end
	return nil
end
