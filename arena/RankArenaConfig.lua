package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

local xml = require "xml"
--local Bonus = require "Bonus"
local database = require "database"

require "printtb"
local sprinttb =sprinttb
require "log"
local log =log
local assert =assert
local string = string;
local ipairs = ipairs;
local pairs = pairs;
local type = type;
local tonumber = tonumber;
local tostring = tostring;
local print = print;
local table = table;
local math = math;
local XMLConfig = require "XMLConfig"
local BinaryConfig = require "BinaryConfig"
local SGK_Game = SGK_Game

module "RankArenaConfig"
-- 每天购买体力机会上限
FIGHT_COUNT_PER_DAY = 100;

-- 挑战冷却
FIGHT_CD_WHEN_WIN = 10;
FIGHT_CD_WHEN_LOSS = 10;

-- 挑战消耗物品
FIGHT_COST_ITEM_TYPE = 41
FIGHT_COST_ITEM_ID = 90002 
if SGK_Game() then
	FIGHT_COST_ITEM_ID = 90169
end
FIGHT_COST_ITEM_VALUE = 1
FIGHT_COST_ITEM_MAX_VALUE = 6

--购买体力消耗物品
ADD_FC_CONSUME_TYPE = 41
ADD_FC_CONSUME_ID = 90002  

CD_DEPEND_VIPLV = 3;
ADD_FC_DEPEND_VIPLV = 0;
ADD_FC_CONSUME_BASE = 1;
ADD_FC_CONSUME_COEF = 0;
ADD_FC_CONSUME_MAX = 20;
QUERY_TOP = 20;
NOTIFY_TOP = 20;
REWARD_YB_RATIO_BY_PRESTIGE =40 
REWARD = {
	WIN = {
		{type = 90, id = 7, value = 20}, -- 威望
		{type = 90, id = 2, value = 4000} -- 银币

	},

	LOST = {
		{type = 90, id = 7, value = 10}, -- 威望
		{type = 90, id = 2, value = 2000}, -- 威望
	};
}
RANK_PERSTIGE = {
	3000,
	2800,
	2600,
	2400,
	2300,
	2200,
	2150,
	2100,
	2050,
	2000
}
function GetRankPerstige(rank)
	if not rank then
		return 0
	end
	if rank <= 0 then
		return 0
	elseif rank <= 10 then                  -- [1, 10]
		return RANK_PERSTIGE[rank]
	elseif rank <= 50 then                  -- [11, 50]
		return 2000 - (rank-10)*10          
	elseif rank <= 100 then                 -- [51, 100]
		return 1600 - (rank-50)*5
	elseif rank <= 150 then                 -- [101, 150]
		return 1350 - (rank-100)*4
	elseif rank <= 200 then                 -- [151, 200]
		return 1150 - (rank-150)*3
	elseif rank <= 250 then                 -- [201, 250]
		return 1000 - (rank-200)*2
	elseif rank <= 300 then                 -- [251, 300]
		return 900 - (rank-250)
	elseif rank <= 400 then                 -- [301, 400]
		return 850 - math.ceil((rank-300)/2)
	elseif rank <= 500 then                 -- [401, 500]
		return 800 - math.ceil((rank-400)/3)
	elseif rank <= 700 then                 -- [501, 700]
		return 767 - math.ceil((rank-500)/4)
	elseif rank <= 1000 then                -- [701, 1000]
		return 717 - math.ceil((rank-700)/5)
	elseif rank <= 2000 then                -- [1001, 2000]
		return 657 - math.ceil((rank-1000)/6)
	elseif rank <= 3000 then                -- [2001, 3000]
		return 490 - math.ceil((rank-2000)/7)
	elseif rank <= 4000 then                -- [3001, 4000] 
		return 347 - math.ceil((rank-3000)/8)
	elseif rank <= 5000 then                -- [4001, 5000]
		return 224 - math.ceil((rank-4000)/9)
	else                                    -- [5001, INF)
		return 110
	end
end

local function insertItem(t, type, id, value)
    if type == 0 or id == 0 or value == 0 then
        return
    end

    table.insert(t, {type = type, id = id, value = value})
end

local rank_reward_config 
local function load_rank_arena_reward()
    local rows = BinaryConfig.Load("config_rank_jjc", "arena")
	rank_reward_config = {}

    for _, row in ipairs(rows) do
		table.insert(rank_reward_config, {lower = row.Rank1, upper = row.Rank2, rewards = {}})
        insertItem(rank_reward_config[#rank_reward_config].rewards, row.reward_type1, row.reward_id1, row.reward_value1)
        insertItem(rank_reward_config[#rank_reward_config].rewards, row.reward_type2, row.reward_id2, row.reward_value2)
        insertItem(rank_reward_config[#rank_reward_config].rewards, row.reward_type3, row.reward_id3, row.reward_value3)
    end
end
load_rank_arena_reward()

function GetRankReward(rank)
	for _, v in ipairs(rank_reward_config) do
		if rank >= v.lower and rank <= v.upper then
			return v.rewards
		end
	end	
	--[[if not rank then
		return nil
	end
	local reward ={}

	-- 威望
	local perstige =GetRankPerstige(rank)
	if perstige > 0 then
		table.insert(reward, { type=90, id=7, value=perstige })
	end

	-- 额外奖励 --
	-- 240215
	if rank == 1 then
		table.insert(reward, { type=41, id=240215, value=4})
	elseif rank == 2 then
		table.insert(reward, { type=41, id=240215, value=2})
	elseif rank <= 20 then 
		table.insert(reward, { type=41, id=240215, value=1})
	end
	-- 240205
	if rank <= 20 then
		table.insert(reward, { type=41, id=240205, value=5})
	elseif rank <= 50 then
		table.insert(reward, { type=41, id=240205, value=4})
	elseif rank <= 100 then
		table.insert(reward, { type=41, id=240205, value=3})
	elseif rank <= 150 then
		table.insert(reward, { type=41, id=240205, value=2})
	elseif rank <= 200 then
		table.insert(reward, { type=41, id=240205, value=1})
	end

	-- return nil if empty
	if #reward > 0 then
		return reward
	else
		return nil
	end--]]
end

function getFightCountPerDay()
	local ratio = 1--Bonus.get_count_ratio(Bonus.BONUS_ARENA_FIGHT)
	log.debug(string.format("getFightCountPerDay, ratio = %d", ratio))
	return ratio * FIGHT_COUNT_PER_DAY
end
function getFightReward(is_winner)
	local src =is_winner and REWARD.WIN or REWARD.LOST
	local reward ={}
	for i=1, #src do
		local item =src[i]
		local ratio = 1--Bonus.get_reward_ratio(Bonus.BONUS_ARENA_FIGHT)
		log.debug(string.format("getFightReward, ratio = %d", ratio))
		table.insert(reward, { type=item.type, id=item.id, value=ratio*item.value })
	end
	return reward
end

REWARD_TIME = 22 * 3600;
FIGHT_COUNT_REFRESH = 0 --22 * 3600;

REWARD_COIN_MIN = 1000;
ARENA_OPEN_LEVEL = 1;

function GetDailyReward(index)
	return {condition = 3, reward = {}}
end

-- 每24小时结算一次排名，每天晚上22时结算。
-- 每天5时更新竞技场次数

--
-- 名次达成奖励
--
--[[RankReachReward ={}
do
	local ok, result =database.query("SELECT `rank`, `reward1_type`, `reward1_id`, `reward1_value`, `reward2_type`, `reward2_id`, `reward2_value`, `reward3_type`, `reward3_id`, `reward3_value` FROM arena_rank_reach_reward_config ORDER BY `rank` DESC")
	assert(ok)
	for i=1, #result do
		local row =result[i]
		local reward ={}
		for j=1, 3 do
			local k_type =string.format("reward%d_type", j)
			local k_id =string.format("reward%d_id", j)
			local k_value =string.format("reward%d_value", j)
			
			if row[k_type]~=0 and row[k_id]~=0 and row[k_value]~=0 then
				table.insert(reward, {
					type  =row[k_type],
					id    =row[k_id],
					value =row[k_value],
				})
			end
		end
		table.insert(RankReachReward, { Rank =row.rank, Reward =reward })
	end
	log.debug(sprinttb(RankReachReward))
end--]]

--local ServiceName = {"Arena"};
--------------------------------------------------------------------------------
-- load config from xml
--
--[[FightDetailLocation  = XMLConfig.FightDetailLocation;

listen = {};
for idx, name in ipairs(ServiceName) do
	listen[idx] = {};
	listen[idx].host = XMLConfig.Social[name].host;
	listen[idx].port = XMLConfig.Social[name].port;
	listen[idx].name = name;
end

Listen = listen;
Social = XMLConfig.Social;--]]
