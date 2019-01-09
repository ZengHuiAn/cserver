local BinaryConfig = require "BinaryConfig"
local database = require "database"
local cell = require "cell"

local goodfeelConsume = nil
local expandfieldConsume = nil
local function loadUnlockConfig()       -- 场地&好感度解锁消耗
	local rows = BinaryConfig.Load("config_unlock","quiz")
	goodfeelConsume = {}
	expandfieldConsume = {}
        for _,v in ipairs(rows) do
                if v.type == 1 then     -- 好感度培养槽解锁
			goodfeelConsume[v.id] =
                        {
                                consume_item_type = v.consume_item1_type,
                                consume_item_id = v.consume_item1_id,
                                consume_item_value = v.consume_item1_value
                        }
                elseif v.type == 2 then -- 场地扩建消耗
			expandfieldConsume[v.id] =
                        {
                                consume_item_type = v.consume_item1_type,
                                consume_item_id = v.consume_item1_id,
                                consume_item_value = v.consume_item1_value
                        }
                end
        end
end
function GetExpandfieldConsume(id)
	return expandfieldConsume[id]
end
function GetGoodfeelConsume(id)
	return goodfeelConsume[id]
end

local furnitureProperty = nil
local function loadFurnitureConfig()    -- 加载家具属性值
	local rows = BinaryConfig.Load("config_furniture","quiz")
	furnitureProperty = {}
        for _,v in ipairs(rows) do
                furnitureProperty[v.id] =
                {
                        comfort_value = v.comfort_value,
                        put_position  = v.put_position,
                        belong_suit   = v.belong_suit ,
                }
        end
end
function GetFurniture(id)
	return furnitureProperty[id]
end

local suitComfortable = nil
local function loadComfortableConfig()          -- 舒适度套装加成
	local rows = BinaryConfig.Load("config_furniture_suit","quiz")
	suitComfortable = {}
        for _,v in ipairs(rows) do
                suitComfortable[v.suit_id] = suitComfortable[v.suit_id] or {}
                suitComfortable[v.suit_id][v.number] = { increase_number = v.increase_number  }
        end
end
function GetComfortable(suit_id,number)
	return suitComfortable[suit_id][number]
end

local goodfeelSpeed = nil
local function loadGoodfeelConfig()     -- 好感度培养速度 相关数据
	local rows = BinaryConfig.Load("config_goodfeel","quiz")
        goodfeelSpeed =
        {
                basic_inc =  rows[1].basic_inc,
                put_max_time = rows[1].put_max_time,
                comfort_coefficient = rows[1].comfort_coefficient/10000
        }
end
function GetGoodfeelSpeed()
	return goodfeelSpeed	
end

--[[
loadUnlockConfig()
loadFurnitureConfig()
loadComfortableConfig()
loadGoodfeelConfig()--]]
