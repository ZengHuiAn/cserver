require "timeControl"
require "timeControlActivityType"
require "yqlog_sys"
local BinaryConfig = require "BinaryConfig"

-- shop type
SHOP_TYPE_NORMAL =1 				-- 普通商店
SHOP_TYPE_DIAMOND =2 				-- 钻石商店
SHOP_TYPE_EXP =3 					-- 经验书商店
SHOP_TYPE_GUILD =4
SHOP_TYPE_COMPOSE = 6 --合成商店
SHOP_TYPE_CONVERT = 7 --兑换商店
SHOP_TYPE_MANOR_LIMIT1 = 32         --庄园限时商人（出售）
SHOP_TYPE_MANOR_LIMIT2 = 33         --庄园限时商人（收购）

-- reward pool sub type
REWARD_POOL_SUB_TYPE_NORMAL =1      -- 普通抽奖奖池
REWARD_POOL_SUB_TYPE_FIRST_GOLD =2  -- 首次金币抽检奖池
REWARD_POOL_SUB_TYPE_GUARANTEE =3   -- 保底奖池
REWARD_POOL_SUB_TYPE_RANDOM = 4     --概率奖池
REWARD_POOL_SUB_TYPE_FIRST_DRAW = 5     --首次抽奖奖池

consume_condition_config = {}
local function CheckLevel(player_info, product_item, now)
	return (player_info and product_item) and player_info.level >= product_item.player_lv_min and player_info.level <= product_item.player_lv_max
end

local function CheckVip(player_info, product_item, now)
	return (player_info and product_item) and player_info.vip >= product_item.vip_min and player_info.vip <= product_item.vip_max
end

local function CheckProductItemActive(player_info, product_item, now)
	return product_item and product_item.is_active ~= 0
end

local function CheckProductItemValid(player_info, product_item, now)
	return product_item and now >= product_item.begin_time and now <= product_item.end_time
end

local shopConfig = nil
function LoadShopConfig()
    local rows = BinaryConfig.Load("config_shop_fresh", "shop")
   	shopConfig = {}

    for _, row in ipairs(rows) do
        shopConfig[row.shop_type] = {
			fresh_count = row.fresh_count,
			can_force_fresh = row.can_force_fresh,
			fresh_consume_type = row.fresh_consume_type,
			fresh_consume_id = row.fresh_consume_id,
			fresh_consume_value = row.fresh_consume_value		
        }
	
		if row.fresh_count > 0 then
			consume_condition_config[row.shop_type] = {
				conditions = {CheckProductItemActive, CheckProductItemValid, CheckLevel},
				actions = {}
			}
		else
			consume_condition_config[row.shop_type] = {
				conditions = {CheckProductItemActive, CheckProductItemValid},
				actions = {}
			}
		end
    end
end

LoadShopConfig()

--insert offset freshPeriod into consume_config;
local function insert_into_consume_config()
	for shop_type, v in pairs(ConsumeConfig.Buy) do 
		local time_control = timeControl.Get(timeControlActivityType.TYPE_SHOP)
		local time_tb = time_control:getTime(shop_type) 
		if not time_tb then
			v.Offset = 1525622400 -- 2018-05-07 00:00:00
			v.FreshPeriod = 24*3600
		elseif #time_tb > 1 then
			yqwarn("shop %d has more than one config, it may bring some mistakes", shop_type)
			v.Offset = time_tb[1].begin_time 
			v.FreshPeriod = time_tb[1].duration_per_period
		else	
			v.Offset = time_tb[1].begin_time 
			v.FreshPeriod = time_tb[1].duration_per_period
		end
	end
end

local function generateConsumeConfig()
	for shop_type, v in pairs(shopConfig) do
		ConsumeConfig.Buy[shop_type] = {
			FreshCount = v.fresh_count,
			CanForceFresh = v.can_force_fresh == 1 and true or false,
			CanRandomBuy = false,
			ForceFreshConsume = (v.fresh_consume_type ~= 0) and {
				{Type = v.fresh_consume_type, Id = v.fresh_consume_id, Value = v.fresh_consume_value},
			} or nil;
		}
	end
end


local ConsumeConfig_Buy_metatable = {__index = function(t, shop_type)
	return {
		FreshCount    = 0,
		CanForceFresh = false,
		CanRandomBuy = false,
		ForceFreshConsume = nil,
		Offset = 1525622400, -- 2018-05-07 00:00:00
		FreshPeriod = 24 * 3600,
	}
end}

-- config
ConsumeConfig = {
	Buy = setmetatable({}, ConsumeConfig_Buy_metatable)
}

function notHasSubTypeRandom()
	local f = io.open("not_has_sub_type_random", "r")
	if f then
		f:close()
		return true
	else
		return false
	end
end
--[[ConsumeConfig ={
	Buy ={ 							--购买配置
		[SHOP_TYPE_NORMAL] ={
            --Offset = '1979-01-01 05:00:00',
			ForceFreshConsume ={    --强制刷新可以消耗的物品
			--	{ Type =90, Id =6, Value =20 },
				{ Type =41, Id =90011, Value =1 },
			},
			--FreshPeriod =7200, 		-- 刷新周期
			FreshCount =0, 			-- 刷出个数
			CanForceFresh =true, 	-- 是否可以强制刷新
			CanRandomBuy = false,   -- 是否可以随机购买
            --VipFreshLimitCount = {};
            --VipFreshLimitParams = {init = 2, incr = 2},
            --CommonLimitID = 34,
		},
		[SHOP_TYPE_DIAMOND] ={
            --Offset = '1979-01-01 05:00:00',
			--FreshPeriod =86400,
			ForceFreshConsume ={    --强制刷新可以消耗的物品
			--	{ Type =90, Id =6, Value =20 },
				{ Type =41, Id =90011, Value =1 },
			},
			FreshCount =0,
			CanForceFresh =true, 	-- 是否可以强制刷新
			CanRandomBuy = false,   -- 是否可以随机购买
		},
		[SHOP_TYPE_EXP] ={
            --Offset = '1979-01-01 05:00:00',
			--FreshPeriod =86400,
			FreshCount =0,
			CanForceFresh =false, 	-- 是否可以强制刷新
			CanRandomBuy = false,   -- 是否可以随机购买
		},
		[SHOP_TYPE_GUILD] ={
			ForceFreshConsume ={    --强制刷新可以消耗的物品
			--	{ Type =90, Id =6, Value =20 },
				{ Type =41, Id =90011, Value =1 },
			},
			FreshCount =0,
			CanForceFresh =true,
			CanRandomBuy = false,
		},
		[SHOP_TYPE_COMPOSE] ={
			FreshCount =0,
			CanForceFresh =false,
			CanRandomBuy = false,
		},
		[SHOP_TYPE_CONVERT] ={
			FreshCount =0,
			CanForceFresh =false,
			CanRandomBuy = false,
		},
		[SHOP_TYPE_MANOR_LIMIT1] ={
			FreshCount =0,
			CanForceFresh =false,
			CanRandomBuy = false,
		},
		[SHOP_TYPE_MANOR_LIMIT2] ={
			FreshCount =0,
			CanForceFresh =false,
			CanRandomBuy = false,
		},
	},
}--]]

generateConsumeConfig()
insert_into_consume_config()
