require "ArenaConfig"
require "yqlog_sys"
require "printtb"
local sprinttb = sprinttb
local yqinfo = yqinfo
local table = table
local ipairs = ipairs
local pairs = pairs
local math = math
local string = string
local tonumber = tonumber
local tostring = tostring
local log = require "log"

local ruleConfig = ruleConfig
local difficultConfig = difficultConfig

module "ArenaConfigManager"

local function str_split(str, pattern)
	local arr ={}
	while true do
		if #str==0 then
			return arr
		end
		local pos,last =string.find(str, pattern)
		if not pos then
			table.insert(arr, str)
			return arr
		end
		if pos>1 then
			table.insert(arr, string.sub(str, 1, pos-1))
		end
		if last<#str then
			str =string.sub(str, last+1, -1)
		else
			return arr
		end
	end
end

function getPowerRange(averagePower, win_rate)
	local cfg 
	local powerRange = {}
	
	for k, v in ipairs(ruleConfig) do
		if  win_rate >= v.win_rate_begin and win_rate < v.win_rate_end then
			cfg = ruleConfig[k]
			break
		end
	end	
	if not cfg then
		return nil
	end
	local ret =str_split(cfg.mode, '[| ]')	
	yqinfo("get proper config by averagePower:%d and win_rate:%d",averagePower, win_rate, sprinttb(cfg))
	for i=1, #ret, 1 do
		if i ~= 1 then
			table.insert(powerRange, { powerLower = math.ceil(averagePower * difficultConfig[i-1].power_rate_begin / 100), 
				powerUpper = math.ceil(averagePower * difficultConfig[i-1].power_rate_end / 100), range = tonumber(ret[i]), 
				powerRateBegin = difficultConfig[i-1].power_rate_begin, powerRateEnd = difficultConfig[i-1].power_rate_end })
		end
	end
	table.insert(powerRange, { powerLower = math.ceil(averagePower * cfg.power_rate_begin / 100), powerUpper = math.ceil(averagePower * cfg.power_rate_end / 100) })
	return powerRange
end

function getDifficulty(enemy_power, average_power)
	if enemy_power >= math.ceil(average_power * 80 / 100) and enemy_power < math.ceil(average_power * 95 / 100) then
		return 1
	elseif enemy_power >= math.ceil(average_power * 95 / 100) and enemy_power < math.ceil(average_power * 110 / 100) then
		return 2
	else
		return 3
	end
end
