package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

local loop = loop;
local log  = log;
local Class = require "Class"
local database = require "database"
require "consume_config"
require "Scheduler"
require "cell"
require "printtb"

local StableTime =require "StableTime"
local get_today_begin_time =StableTime.get_today_begin_time
local get_begin_time_of_day = StableTime.get_begin_time_of_day 

local type = type
local pairs = pairs
local ipairs = ipairs
local string = string
local print = print
local math = math
local next = next
local log = log
local loop = loop;
local coroutine = coroutine
local table = table
local tostring = tostring
local tonumber = tonumber;
local Scheduler = require "Scheduler"
local database = require "database"
local Class = require "Class"
require "Thread"
local Sleep = Sleep
local Command = require "Command"
local os = os
require "printtb"
local sprinttb = sprinttb
local yqinfo = yqinfo

local SweepstakePoolConfig = {} 
local cfg = nil

function SweepstakePoolConfig.Get(id)
	if not cfg then
		cfg = {}
		local ok, result = database.query("SELECT id, pool_type, max_draw_count, duration, unix_timestamp(begin_time) as begin_time, min_draw_count FROM sweepstakepoolconfig");
		if ok and #result >= 1 then
			 for i = 1, #result do
				local row = result[i];
				cfg[row.id] =  cfg[row.id] or {}
				cfg[row.id][row.pool_type] = cfg[row.id][row.pool_type] or {}
				cfg[row.id][row.pool_type].max_draw_count = row.max_draw_count
				cfg[row.id][row.pool_type].duration = row.duration
				cfg[row.id][row.pool_type].begin_time = row.begin_time
				cfg[row.id][row.pool_type].min_draw_count = row.min_draw_count
			end
		end
	end

	return cfg[id] and cfg[id] or nil	
end

return SweepstakePoolConfig
