local BinaryConfig = require "BinaryConfig"
local loop = loop

local REF_TIME = 1509292800	-- 2017/10/30 00:00:00
local PVE = 1
local PVP = 2

-- 每天活动开启时的开始时间
local function start_time(time)
	local day_sec = 24 * 3600
	-- 凌晨
	local wee = REF_TIME + day_sec * math.floor((loop.now() - REF_TIME) / day_sec)
	return wee + (time - REF_TIME) % day_sec
end

local rows = BinaryConfig.Load("config_arena_property", "arena")	

local config = {}

if rows then
	for _, v in ipairs(rows) do
		if v.pvparena_type == PVE then
			config[PVE] = { count = v.pvparena_times, begin_time = v.begin_time, end_time = v.end_time, period = v.period, duration = v.duration  }				
		else
			config[PVP] = { count = v.pvparena_times, begin_time = v.begin_time, end_time = v.end_time, period = v.period, duration = v.duration  }				
		end
	end
	
end

local ConsumeConfig = {}
local rows2 = BinaryConfig.Load("config_common_consume", "hero")
if rows2 then
	for _, v in ipairs(rows2) do
		ConsumeConfig[v.id] = v
	end
end

local function get_consume(id)
	return ConsumeConfig[id]
end

local function get_match_count(type)
	if type == PVE then
		return config[PVE].count or 0
	else
		return config[PVP].count or 0
	end
end

local function is_range(type)	
	if type == PVE then
		local pve = config[PVE]
		local start = start_time(pve.begin_time)
		local now = loop.now()
		if pve.begin_time < now and now < pve.end_time and start < now and now < start + pve.duration then	
			return true
		end
		return false
	else	
		local pvp = config[PVP]
		local start = start_time(pvp.begin_time)
		local now = loop.now()
		if pvp.begin_time < now and now < pvp.end_time and start < now and now < start + pvp.duration then	
			return true
		end
		return false
	end
end

return {
	get_match_count = get_match_count,
	is_range = is_range,	
	get_consume = get_consume,
}
