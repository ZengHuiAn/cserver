local database = require "database"
require "yqlog_sys"
require "printtb" 

require "ArenaRewardConfig"

local player = {}

local function TransformReward(reward_id, level)
	local reward = {}
	local cfg = GetArenaBoxRewardConfig(reward_id)
	
	if not cfg then
		return reward
	end

	for k, v in ipairs(cfg.reward or {}) do
		if k == 1 then
			table.insert(reward, {type = v.type, id = v.id, value = v.value + math.floor(level * cfg.reward_factor1)})
		else
			table.insert(reward, {type = v.type, id = v.id, value = v.value})
		end	
	end

	print("reward_id , drop_id >>>>>>>", reward_id, cfg.drop_id)
	return reward, cfg.drop_id
end

local ArenaPlayerBoxReward = {}
function ArenaPlayerBoxReward.Get(pid)
	local t = { pid = pid, reward_list = {reward1 = {}, reward2 = {}, reward3 = {}}, reward_id1 = 0, reward_id2 = 0, reward_id3 = 0, level = 0}
	local ok, result = database.query("select * from arena_player_box_reward where pid = %d", pid)
	if ok and #result > 0 then
		for i = 1, #result do
			local row = result[i]
			t.reward_list.reward1, t.drop_id1 = TransformReward(row.reward_id1, row.level)
			t.reward_list.reward2, t.drop_id2 = TransformReward(row.reward_id2, row.level)
			t.reward_list.reward3, t.drop_id3 = TransformReward(row.reward_id3, row.level)
		
			t.reward_id1 = row.reward_id1	
			t.reward_id2 = row.reward_id2	
			t.reward_id3 = row.reward_id3	

			t.level = row.level	
		end
	end
	return setmetatable(t, {__index = ArenaPlayerBoxReward})
end

function ArenaPlayerBoxReward:GetRewardList(idx)
	if #self.reward_list.reward1 == 0 or #self.reward_list.reward2 == 0 or #self.reward_list.reward3 == 0 then
		return nil
	end

	if idx then
		print("pid   level   drop_id", self.pid, self.level, idx, self["drop_id"..idx])
		return self.reward_list["reward"..idx], self["drop_id"..idx] > 0 and { { id = self["drop_id" .. idx], level = self.level }, } or {}
	end
end

function ArenaPlayerBoxReward:UpdatePlayerBoxReward(reward_id1, reward_id2, reward_id3, level)
	if self.reward_id1 == reward_id1 and self.reward_id2 == reward_id2 and self.reward_id3 == reward_id3 and self.level == level then
		return 
	end

	self.reward_list.reward1, self.drop_id1 = TransformReward(reward_id1, level)
	self.reward_list.reward2, self.drop_id2 = TransformReward(reward_id2, level)
	self.reward_list.reward3, self.drop_id3 = TransformReward(reward_id3, level)
	self.level = level
	database.update("replace into arena_player_box_reward(pid, reward_id1, reward_id2, reward_id3, level) values(%d, %d, %d, %d, %d)", self.pid, reward_id1, reward_id2, reward_id3, level)
end

function ArenaPlayerBoxReward.GetPlayerBoxReward(pid)
	if not player[pid] then
		player[pid] = ArenaPlayerBoxReward.Get(pid)
	end
	return player[pid]
end

return ArenaPlayerBoxReward
