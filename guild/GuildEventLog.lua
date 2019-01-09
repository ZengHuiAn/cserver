local MAX_LOG_COUNT = 20
local database = require "database"
local NetService = require "NetService"
local GuildEventLog = {}

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

function GuildEventLog.New(gid)
	local t = {gid = gid, logs = {}, log_count = 0, max_index = 0}	

	local success, result = database.query("select gid, type, content, unix_timestamp(time) as time ,`index` from guild_event_log where gid = %d ORDER BY `index` DESC LIMIT %d", gid, MAX_LOG_COUNT)
	if success then
		for _, row in ipairs(result) do
			local log = {type = row.type, content = transformStr2Tb(row.content),time = row.time ,index = row.index}	
			t.log_count = t.log_count + 1
			if row.index > t.max_index then
				t.max_index = row.index
			end
			table.insert(t.logs, 1, log)
		end
	end

	return setmetatable(t, {__index = GuildEventLog})	
end

function GuildEventLog:AddLog(type, content)
	local addtime = loop.now()
	if self.log_count == MAX_LOG_COUNT then
		table.remove(self.logs, 1)
		table.insert(self.logs, {type = type, content = content , time = addtime, index = self.max_index + 1})
		self.max_index = self.max_index + 1
	else
		table.insert(self.logs, {type = type, content = content ,time = addtime, index = self.max_index + 1})
		self.log_count = self.log_count + 1
		self.max_index = self.max_index + 1
	end
	self:Notify({type,content,addtime})
	database.update("insert into guild_event_log(gid, type, content,time,`index`) values(%d, %d, '%s',from_unixtime_s(%d), %d)", self.gid, type, transformTb2Str(content),addtime , self.max_index)
end

function GuildEventLog:GetLog()
	local ret = {} 

	for k, v in ipairs(self.logs) do
		table.insert(ret,{v.type, v.content, v.time})		
	end

	return ret
end

function GuildEventLog:Notify(msg)
	--NetService.NotifyClients(cmd, msg, {self.pid});
	local guild = GuildManager.Get(self.gid);
	if guild then
		EventManager.DispatchEvent("GUILD_EXPLORE_EVENT_LOG_CHANGE", {guild = guild, message = msg});
	end
end

function GuildEventLog.RegisterCommand(service)
	service:on(Command.C_MANOR_QUERY_LOG_REQUEST, function(conn, pid, request)
		local sn = request[1];

		local guild_event_log = GuildEventLog.Get(gid)
		local ret = guild_event_log:GetLog()
		return conn:sendClientRespond(Command.C_MANOR_QUERY_LOG_RESPOND, pid, {sn, Command.RET_SUCCESS, ret});
	end);
end

local guildEventLog = {}
function GuildEventLog.Get(gid)
	if not guildEventLog[gid] then
		guildEventLog[gid] = GuildEventLog.New(gid)
	end
	return guildEventLog[gid]
end

return GuildEventLog
