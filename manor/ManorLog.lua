local MAX_LOG_COUNT = 100
local database = require "database"
local NetService = require "NetService"
local ManorLog = {}

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

--[[local function transformTb2Str(t)
	local str 
	for k, v in ipairs(t or {}) do
		if type(v) == 'table' then
			transformTb2Str(v)
		end
		str = str and str..","..tostring(v) or tostring(v)
	end
	return str
end--]]

local function transformTb2Str(t)
    local str = "{"
    for k, v in ipairs(t or {}) do
        if type(v) == 'table' then
            str = str..transformTb2Str(v)..","
        else
        	str = str..tostring(v)..","
		end
    end
	str = str .. "}"
    return str
end

local function transformStr2Tb(lua)  
    local t = type(lua)  
    if t == "nil" or lua == "" then  
        return nil  
    elseif t == "number" or t == "string" or t == "boolean" then  
        lua = tostring(lua)  
    else  
        error("can not unserialize a " .. t .. " type.")  
    end  
    lua = "return " .. lua  
    local func = loadstring(lua)  
    if func == nil then  
        return nil  
    end  
    return func()  
end

--[[local function transformStr2Tb(str)
	local tb = {}
	
	local ret = str_split(str, ",")
	for k, v in ipairs(ret or {}) do
		table.insert(tb, v)
	end

	return tb
end--]]

function ManorLog.New(pid)
	local t = {pid = pid, logs = {}, log_count = 0, max_index = 0, cache_sql = ""}	

	local success, result = database.query("select * from player_manor_log where pid = %d ORDER BY `index` DESC LIMIT %d", pid, MAX_LOG_COUNT)
	if success then
		for _, row in ipairs(result) do
			local log = {type = row.type, content = transformStr2Tb(row.content), index = row.index}	
			t.log_count = t.log_count + 1
			if row.index > t.max_index then
				t.max_index = row.index
			end
			table.insert(t.logs, 1, log)
		end
	end

	return setmetatable(t, {__index = ManorLog})	
end

function ManorLog:AddLog(type, content, cache)
	if self.log_count == MAX_LOG_COUNT then
		table.remove(self.logs, 1)
		table.insert(self.logs, {type = type, content = content , index = self.max_index + 1})
		self.max_index = self.max_index + 1
	else
		table.insert(self.logs, {type = type, content = content , index = self.max_index + 1})
		self.log_count = self.log_count + 1
		self.max_index = self.max_index + 1
	end

	self:Notify(Command.NOTIFY_MANOR_LOG_CHANGE, {type, content})
	if cache then
		self.cache_sql = self.cache_sql .. string.format("(%d, %d,'%s', %d),", self.pid, type, transformTb2Str(content), self.max_index)
		--print("cache >>>>>>", self.cache_sql)
	else
		database.update("insert into player_manor_log(pid, type, content, `index`) values(%d, %d, '%s', %d)", self.pid, type, transformTb2Str(content), self.max_index)
	end	
end

function ManorLog:FlushCache()
	--print("flush  >>>>>>>>", self.cache_sql)
	if self.cache_sql ~= "" then
		database.update("insert into player_manor_log (pid, type, content, `index`) values"..string.sub(self.cache_sql, 1, -2))
		self.cache_sql = ""
	end
end

function ManorLog:GetLog()
	local ret = {} 

	for k, v in ipairs(self.logs) do
		table.insert(ret, {v.type, v.content})		
	end

	return ret
end

function ManorLog:Notify(cmd, msg)
	NetService.NotifyClients(cmd, msg, {self.pid});
end

function ManorLog.RegisterCommand(service)
	service:on(Command.C_MANOR_QUERY_LOG_REQUEST, function(conn, pid, request)
		local sn = request[1];

		local manor_log = ManorLog.Get(pid)
		local ret = manor_log:GetLog()
		return conn:sendClientRespond(Command.C_MANOR_QUERY_LOG_RESPOND, pid, {sn, Command.RET_SUCCESS, ret});
	end);
end

local playerManorLog = {}
function ManorLog.Get(pid)
	if not playerManorLog[pid] then
		playerManorLog[pid] = ManorLog.New(pid)
	end
	return playerManorLog[pid]
end

return ManorLog
