local database = require "database"
local GuildManager = require "GuildManager"
local PlayerManager = require "PlayerManager"
local BinaryConfig = require "BinaryConfig"
require "printtb"
local GuildItem = {}

local guild_item_config 
local function LoadGuildItemConfig()
	local rows = BinaryConfig.Load("config_guild_item", "guild")
	guild_item_config = {}

    for _, row in ipairs(rows) do
		guild_item_config[row.id] = {
			begin_time = row.begin_time,
			end_time = row.end_time,
			reset = row.reset
		}	
    end
end
LoadGuildItemConfig()

local function GetGuildItemConfig(id)
	return  guild_item_config[id]
end

local function NewPeriod(begin_time, end_time, period, update_time)
	if update_time < begin_time or update_time > end_time then
		return false
	end	
	
	local p1 = math.floor((update_time - begin_time) / period) + 1
	local p2 = math.floor((loop.now() - begin_time) / period) + 1

	return p2 > p1
end


local all = {}
local function Get(gid)
	if not all[gid] then
		all[gid] = GuildItem.Load(gid)
	end

	return all[gid]
end

function GuildItem.Load(gid)
	local success, rows = database.query("select gid, id, `limit`, unix_timestamp(update_time) as update_time from guild_item where gid = %d", gid)
	local t = {
		gid = gid,
		map = {},
		list = {},
	}
	if success and #rows > 0 then
		for _, row in ipairs(rows) do
			local item =  {id = row.id, limit = row.limit, update_time = row.update_time}	
			t.map[row.id] = item
			table.insert(t.list, item)
		end
	end

	return setmetatable(t, {__index = GuildItem})
end

--static func
function GuildItem:CalcItemGrowCount(guild, id, count, update_time)
	local cfg = GetGuildItemConfig(id)
	if not cfg then	
		return count	
	end

	if NewPeriod(cfg.begin_time, cfg.end_time, cfg.reset, update_time) then
		return 0
	end
	
	return count
end

function GuildItem:Notify(item)
	local guild = GuildManager.Get(self.gid)
	if not guild then
		return 
	end

	local pids = {}
	for _, m in pairs(guild.members) do
		table.insert(pids, m.id);
	end

	NetService.NotifyClients(Command.NOTIFY_GUILD_ITEM_CHANGE, {item.id, item.limit}, pids);
end

function GuildItem:Get(id, not_save)
	local guild = GuildManager.Get(self.gid)
	assert(guild)

	local item = self.map[id]
	if item then
		local count, count_change = self:CalcItemGrowCount(guild, id, item.limit, item.update_time)
		if count_change then
			item = self:Update(item, count, not_save)
		end 
	else
		local count, count_change = self:CalcItemGrowCount(guild, id, 0, 0)
		if count_change then
			item = self:Add(id, count)
		end	
	end

	return item
end

function GuildItem:Update(item, value, not_save)
	assert(item)
	log.debug(string.format("update guild item %d id %d->%d", item.id, item.limit, value))

	if not not_save then
		database.update("update guild_item set `limit` = %d, update_time = from_unixtime_s(%d) where gid = %d and id = %d", value, loop.now(), self.gid, item.id)
	end
	item.limit = value
	item.update_time = loop.now()
	self:Notify(item)
end

function GuildItem:Add(id, value)
	assert(not self.map[id])

	log.debug(string.format("add new guild item %d id 0->%d", id, value))
	database.update("insert into guild_item(gid, id, `limit`, update_time) values(%d, %d, %d, from_unixtime_s(%d))", self.gid, id, value, loop.now())
	local item = {id = id, limit = value, update_time = loop.now()}
	self.map[id] = item
	table.insert(self.list, item)
	self:Notify(item)
end

--export func
function GuildItem:GetItem(id)
	return self:Get(id)
end

function GuildItem:GetAMFList()
	local amf = {}
	for k, v in ipairs(self.list) do
		table.insert(amf, {v.id, v.limit})
	end

	return amf
end

function GuildItem:IncreaseItem(id, value)
	local item = self:Get(id, true)
	if item then
		self:Update(item, item.limit + value)		
	else
		item = self:Add(id, value)
	end

	return item
end

function GuildItem:DecreaseItem(id, value)
	local item = self:Get(id, true)
	if not item then
		log.debug(string.format("Guild %d fail to decrease guild item %d, not exist", self.gid, id))
		return 
	end

	if value > item.limit then
		log.debug(string.format("Guild %d fail to decrease guild item %d, limit %d < %d", self.gid, id, item.limit, value))
		return 
	end

	item = self:Update(item, item.limit - value)
	return item
end

function GuildItem:SetItem(id, value)
	local item = self:Get(id, true)	
	if not item then
		log.debug(string.format("Guild %d fail to set guild item %d, not exist", self.gid, id))
		return
	end

	item = self:Update(item, value)
	return item
end

function GuildItem:RemoveItem(id)
	local item = self:Get(id, true)
	if not item or item.limit == 0 then
		log.debug(string.format("Guild %d fail to remove guild item %d, not exist", self.gid, id))	
		return false
	end

	self:Update(item, 0)
	return true
end

function GuildItem:CheckEnough(id, value, empty)
	local item = self:Get(id)
	if empty ~= 1 then
		if not item or item.limit < value or item.limit == 0 then
			return false
		end

		return true
	end

	return true
end

local function consume(pid, consume)
	print("consume >>>>>>>>>>>>", sprinttb(consume))
	local respond = cell.sendReward(pid, nil, consume, Command.REASON_ADD_GUILD_ITEM, 0, 0);
	if respond == nil or respond.result ~= Command.RET_SUCCESS then
		return false 
	end
	return true
end

local function RegisterCommand(service)
	service:on(Command.C_GUILD_ITEM_QUERY_REQUEST, function(conn, pid, request)
        local cmd = Command.C_GUILD_ITEM_QUERY_RESPOND
		local sn = request[1]
		log.debug(string.format("player %d begin to query guild item", pid))

		local player = PlayerManager.Get(pid)
		if not player or not player.guild then
			log.debug("query guild item fail, player not in guild")		
        	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

		local guild_item = Get(player.guild.id)
		if not guild_item then
			log.debug("query guild item fail, get guild item fail")
        	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

       	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, guild_item:GetAMFList()})
    end)

	service:on(Command.C_GUILD_ITEM_ADD_REQUEST, function(conn, pid, request)
		local cmd = Command.C_GUILD_ITEM_ADD_RESPOND
		local sn = request[1]
		local id = request[2]
		local value = request[3]
		log.debug(string.format("player %d begin to add guild item %d", pid, id))

		local player = PlayerManager.Get(pid)
		if not player or not player.guild then
			log.debug("add guild item fail, player not in guild")
        	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

		local guild_item = Get(player.guild.id)
		if not guild_item then
			log.debug("add guild item fail, get guild item fail")
        	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

		-- consume 
		if not consume(pid, {{type = 41, id = id, value = value}}) then
			log.debug("add guild item fail, consume fail")	
        	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

		guild_item:IncreaseItem(id, value)
       	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS})
	end)
end

return {
	Get = Get,
	RegisterCommand = RegisterCommand
}
