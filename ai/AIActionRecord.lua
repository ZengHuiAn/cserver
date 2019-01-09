local database = require "database"
local StableTime = require "StableTime"
local get_today_begin_time = get_today_begin_time 
local get_begin_time_of_day = get_begin_time_of_day
local AIActionRecord = {}

function AIActionRecord.Get(id)
	local t = {
		pid = id, 
		record = {}
	}
	
	local success, result = database.query("select pid, action_type, unix_timestamp(finish_time) as finish_time from ai_actoin_recrod where pid = %d", id)	
	if success then
		for _, row in ipairs(result) do
			t.record[row.action_type] = t.record[row.action_type] or {}
			t.record[row.action_type].finish_time = row.finish_time
		end
	end

	return setmetatable(t, {__index = AIActionRecord})
end

function AIActionRecord:AlreadyFinishToday(type)
	local record = self.record[type]

	if not record then 
		return false
	end

	local finish_time = record.finish_time

	return get_today_begin_time() == get_begin_time_of_day(finish)
end

function AIActionRecord:UpdateFinishTime(action_type, time)
	time = time or loop.now()

	local record = self.record[action_type]
	if not record then
		self.record[action_type] = {}
		self.record[action_type].finish_time = time
		database.update("insert into ai_action_record(pid, action_type, finish_time) values(%d, %d, from_unixtime_s(%d))", self.pid, action_type, time)
	else	
		self.record[action_type].finish_time = time
		database.update("update ai_action_record set finish_time = from_unixtime_s(%d) where pid = %d and action_type = %d", time, self.pid, action_type)
	end
end
