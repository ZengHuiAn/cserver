local math = math
local next = next
local loop = loop
local log  = log
local table = table
local tostring = tostring
local tonumber = tonumber
local Scheduler = require "Scheduler"
local database = require "database"
local Class = require "Class"
local ipairs = ipairs
local pairs = pairs
require "Thread"
local Sleep = Sleep
local os = os
require "yqlog_sys"
local yqinfo = yqinfo
local yqerror = yqerror
require "printtb"
local printtb = printtb
local sprinttb = sprinttb
local StableTime = require "StableTime"

module "timeControl"

local timeControl = {} 
local id2instance = {} 
local reference_time = 1487174400 --2017-2-16 
local openServerTime = StableTime.get_open_server_time()--1487606400 --2017-2-21

function timeControl:_init_(activity_type)
	self.timeConfig = {}
	local now = loop.now()
	local ok, result = database.query("SELECT id, activity_type, UNIX_TIMESTAMP(begin_time) as begin_time, UNIX_TIMESTAMP(end_time) as end_time, duration_per_period, valid_time_per_period,trading_rate FROM timeControl WHERE activity_type=%d AND end_time>%d ORDER BY begin_time ASC",activity_type,now);
	if ok then
		yqinfo("database query success")
	else
		yqinfo("database query fail")
	end
    if ok and #result >= 1 then
	   	for i = 1, #result do
           	local row = result[i];
			self.timeConfig[row.id] = self.timeConfig[row.id] or {}
			table.insert(self.timeConfig[row.id], {begin_time = (row.begin_time < reference_time) and (StableTime.get_begin_time_of_day(openServerTime) + row.begin_time) or row.begin_time, end_time = (row.end_time < reference_time) and (StableTime.get_begin_time_of_day(openServerTime) + row.end_time) or row.end_time, duration_per_period = row.duration_per_period, valid_time_per_period = row.valid_time_per_period, trading_rate = row.trading_rate})
        end
   	else
		yqinfo("fail to init timeControl for activity_type:%d",activity_type)
	end 
end

function timeControl:getTime(id)
	if not id then
		return self.timeConfig
	else
		return self.timeConfig[id] and self.timeConfig[id] or nil 
	end
end

function timeControl:onTime(id)
	local onTime = false
	local now = loop.now()
	if id then
		for _,cfg in ipairs(self.timeConfig[id] or {}) do	
			local beginTime = cfg.begin_time
			local endTime = cfg.end_time
			local nowPeriod = math.ceil((now - beginTime) / cfg.duration_per_period)
			local validBeginTime = beginTime + (nowPeriod - 1) * cfg.duration_per_period
			local validEndTime = validBeginTime + cfg.valid_time_per_period
			yqinfo("timeControl beginTime %d endTime %d validBeginTime:%d validEndTime:%d",beginTime,endTime,validBeginTime, validEndTime)
			if (not (now < beginTime or now > endTime)) and (now >= validBeginTime and now <= validEndTime) then
				onTime = true 
				break
			end
		end
	else
		for _,v in ipairs(self.timeConfig or {}) do	
			for _,cfg in ipairs(v or {}) do 
				local beginTime = cfg.begin_time
				local endTime = cfg.end_time
				local nowPeriod = math.ceil((now - beginTime) / cfg.duration_per_period)
				local validBeginTime = beginTime + (nowPeriod - 1) * cfg.duration_per_period
				local validEndTime = validBeginTime + cfg.valid_time_per_period
				if (not (now < beginTime or now > endTime)) and (now >= validBeginTime and now <= validEndTime) then
					onTime = true 
					break
				end
			end
		end
	end
	return onTime
end

function timeControl:getPeriod(id)
	if (not id) or (not self.timeConfig[id]) then
		return -1,"cannt get id or time config"
	else
		if #self.timeConfig[i] >= 1 then 
			local now = loop.now()
			local cfg = self.timeConfig[i]
			local beginTime = cfg.begin_time
			local endTime = cfg.end_time
			local duration_per_period = cfg.duration_per_period
			local vaild_time_per_period = cfg.valid_time_per_period
			local nowPeriod = math.ceil((now - beginTime) / duration_per_period)
			if now < beginTime or now > endTime then
				return -1, "out of date"
			else
				return nowPeriod, nil
			end
		else
			return -1,"cannt get time config" 
		end
	end
end

function Get(activity_type)
	local instance = id2instance[activity_type]
	if not instance then
		instance = Class.New(timeControl, activity_type);
		id2instance[activity_type] = instance
	end
	return instance;
end
