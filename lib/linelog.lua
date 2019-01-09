local io = io
local log = log
local loop = loop

local origin_time = 1502859600 		-- 2017/8/16/13:0:0
local prefix = "../log/"
local interval = 60 * 60

-- convert unix time to "20170816_11" format time
local function timeformat(time)
	assert(time)
	local t = os.date("*t", time)
	local str = t.year
	if t.month < 10 then
		str = str .. "0" .. t.month
	else
		str = str .. t.month
	end
	if t.day < 10 then
		str = str .. "0" .. t.day
	else
		str = str .. t.day
	end
	str = str .. "_"
	if t.hour < 10 then
		str = str .. "0" .. t.hour
	else
		str = str .. t.hour
	end
	return str
end

-- 整点时间
local function wholeHour(time)
	assert(time)
	local n = math.floor((loop.now() - origin_time) / interval)
	return origin_time + n * interval
end

local LoggerList = {}
local Logger = {}
function Logger:new(module)
	local o = { module = module }
	return setmetatable(o, {__index = Logger})
end	

function Logger:open()
	self.filename = prefix .. self.module .. "_" .. timeformat(loop.now()) .. ".log"
	self.file = io.open(self.filename, "a")
	self.time = wholeHour(loop.now())
end

function Logger:reopen()
	self.file:close()
	self:open()
end

function Logger:close()
	if self.file then
		self.file:close()
		LoggerList[self.module] = nil
	end
end

function Logger:write(t)
	local time = self.time or 0
	if loop.now() - time > interval then
		self:reopen()
	end
	local str = ""
	for i, v in ipairs(t) do
		str = str .. v
		if i < #t then
			str = str .. ","
		end
	end
	str = str .. "\n"	

	self.file:write(str)
end

local function getLogger(module)
	if not LoggerList[module] then
		local logger = Logger:new(module)
		logger:open()
		LoggerList[module] = logger
	end
	return LoggerList[module]
end

return {
	getLogger = getLogger,
}
