local MAX_LOG_COUNT = 20
local database = require "database"
local NetService = require "NetService"
local GuildPrayLog = {}

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

function GuildPrayLog.New(gid)
	local t = {gid = gid, logs = {}, log_count = 0, max_index = 0}	

	local success, result = database.query("select * from guild_pray_log where gid = %d ORDER BY `index` DESC LIMIT %d", gid, MAX_LOG_COUNT)
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

	return setmetatable(t, {__index = GuildPrayLog})	
end

function GuildPrayLog:AddLog(type, content)
	if self.log_count == MAX_LOG_COUNT then
		table.remove(self.logs, 1)
		table.insert(self.logs, {type = type, content = content , index = self.max_index + 1})
		self.max_index = self.max_index + 1
	else
		table.insert(self.logs, {type = type, content = content , index = self.max_index + 1})
		self.log_count = self.log_count + 1
		self.max_index = self.max_index + 1
	end

	self:Notify(content)
	database.update("insert into guild_pray_log(gid, type, content, `index`) values(%d, %d, '%s', %d)", self.gid, type, transformTb2Str(content), self.max_index)
end

function GuildPrayLog:GetLog()
	local ret = {} 

	for k, v in ipairs(self.logs) do
		table.insert(ret, v.content)		
	end

	return ret
end

function GuildPrayLog:Notify(msg)
	--NetService.NotifyClients(cmd, msg, {self.pid});
	local guild = GuildManager.Get(self.gid);
	if guild then
		EventManager.DispatchEvent("GUILD_PRAY_LOG_CHANGE", {guild = guild, message = msg});
	end
end

function process_query_pray_log(conn, pid, request)
	local sn = request[1];

	yqinfo("Player `%d` Begin to query pray log", pid)
	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
	end

	local guild_pray_log = GuildPrayLog.Get(player.guild.id)
	local ret = guild_pray_log:GetLog()
	return conn:sendClientRespond(Command.C_GUILD_QUERY_PRAY_LOG_RESPOND, pid, {sn, Command.RET_SUCCESS, ret});
end

function GuildPrayLog.RegisterCommand(service)
	service:on(Command.C_GUILD_QUERY_PRAY_LOG_REQUEST, function(conn, pid, request)
		local sn = request[1];

		yqinfo("Player `%d` Begin to query pray log", pid)
		local player = PlayerManager.Get(pid);
		-- 玩家不存在
		if player.name == nil then
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
		end

		-- 玩家没有军团
		if player.guild == nil then --or player.level < 10 then
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
		end

		local guild_pray_log = GuildPrayLog.Get(player.guild.id)
		local ret = guild_pray_log:GetLog()
		return conn:sendClientRespond(Command.C_GUILD_QUERY_PRAY_LOG_RESPOND, pid, {sn, Command.RET_SUCCESS, ret});
	end);
end

local guildPrayLog = {}
function GuildPrayLog.Get(gid)
	if not guildPrayLog[gid] then
		guildPrayLog[gid] = GuildPrayLog.New(gid)
	end
	return guildPrayLog[gid]
end


return GuildPrayLog
