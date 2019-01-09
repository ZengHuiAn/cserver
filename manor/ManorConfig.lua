require "protobuf"
local log = require "log"
local BinaryConfig = require "BinaryConfig"

local manorSpeedUpConsumeConfig = nil
local function LoadManorSpeedUpConsumeConfig()
    local rows = BinaryConfig.Load("config_manor_accelerate_consum", "manor")
    manorSpeedUpConsumeConfig = {}

    for _, row in ipairs(rows) do
        manorSpeedUpConsumeConfig.type = row.type
        manorSpeedUpConsumeConfig.id = row.id
    end
end

LoadManorSpeedUpConsumeConfig()

function GetSpeedUpConsumeConfig()
    return manorSpeedUpConsumeConfig
end

local percent_property_config
local effect_config 
local function LoadPercentPropertyConfig() 
	local rows = BinaryConfig.Load("config_work_type", "manor")
	percent_property_config = {}
	effect_config = {}

    for _, row in ipairs(rows) do
		if row.effect_work_id > 0 then
			percent_property_config[row.effect_work_id] = row.id	
		end

		if row.effect_work_id == 0 then
			effect_config[row.id] = row.formula_type
		end
    end
end

function GetPropertyConfig(property_id)
	return percent_property_config[property_id] and percent_property_config[property_id] or nil
end

function GetEffectConfig()
	return effect_config
end

LoadPercentPropertyConfig()

local manor_pool_config
local function LoadManufacturePoolConfig()
	local rows = BinaryConfig.Load("config_manor_manufacture_pool", "manor")
	manor_pool_config = {}
	for _,row in ipairs(rows) do
		manor_pool_config[row.pool_id] = manor_pool_config[row.pool_id]	or {}
		manor_pool_config[row.pool_id][row.item_type] = manor_pool_config[row.pool_id][row.item_type] or {}
		manor_pool_config[row.pool_id][row.item_type][row.item_id] = { item_value = row.item_value , weight = row.weight }
	end
end

function GetManufacturePoolConfig(pool_id)
	return manor_pool_config[pool_id] 
end

LoadManufacturePoolConfig()

local manor_event_pool_config 
local function LoadManorEventPoolConfig()
	local rows = BinaryConfig.Load("beltline_quest_pool", "manor")
	manor_event_pool_config = {}
	for _, row in ipairs(rows) do
		manor_event_pool_config[row.line] = manor_event_pool_config[row.line] or {}
		table.insert(manor_event_pool_config[row.line], {event_type = row.type, weight = row.weight, cd = row.interval})	
	end	
end

function GetManorEventPool(line)
	return manor_event_pool_config[line]
end

LoadManorEventPoolConfig()

local manor_events_config
local function LoadManorEventsConfig()
	local rows = BinaryConfig.Load("config_manor_event", "manor")	
	manor_events_config = {}
	for _, row in ipairs(rows) do
		manor_events_config[row.pool_type] = manor_events_config[row.pool_type] or {
			total_weight = 0,
			pool = {},
		}
		manor_events_config[row.pool_type].total_weight = manor_events_config[row.pool_type].total_weight + row.weight
		table.insert(manor_events_config[row.pool_type].pool, {id = row.id, weight = row.weight, duration = row.interval, effect_percent = math.floor(row.output_percent / 100), fight_id = row.fight_id})
	end
end

function GetManorRandomEventParam(event_type)
	if manor_events_config[event_type] then
		local rand = math.random(0, manor_events_config[event_type].total_weight)
		for _, v in ipairs(manor_events_config[event_type].pool or {}) do
			if rand <= v.weight then
				return v
			end	

			rand = rand - v.weight
		end
	else
		return nil
	end	
end

LoadManorEventsConfig()

local manor_laze_event_config
local function LoadManorLazeEventConfig()
	local rows = BinaryConfig.Load("config_manor_life1", "manor")
	manor_laze_event_config = {}
	for _, row in ipairs(rows) do
		manor_laze_event_config[row.role_id] = manor_laze_event_config[row.role_id] or {}
		manor_laze_event_config[row.role_id][row.line] = manor_laze_event_config[row.role_id][row.line] or {
			total_weight = 0,
			events = {}	
		}	
		manor_laze_event_config[row.role_id][row.line].total_weight = manor_laze_event_config[row.role_id][row.line].total_weight + row.event_rate
		table.insert(manor_laze_event_config[row.role_id][row.line].events, {event_type = row.type, weight = row.event_rate, effect_time = row.effect_time, max_time = row.max_time})
	end
end

function GetManorLazeEventConfig(gid, line)
	if manor_laze_event_config[gid] then
		return manor_laze_event_config[gid][line]
	end	

	return nil
end

LoadManorLazeEventConfig()
