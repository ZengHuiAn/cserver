local database = require "database"
local log = require "log"
local PlayerManager = require "PlayerManager"
require "GuildPermissionConfig"
require "GuildSummaryConfig"
require "printtb"
local GuildBuilding = {}

local MIN_BUILDING_TYPE = 1
local BUILDING_SHOP = 1
local BUILDING_COURTYARD = 2 
local MAX_BUILDING_TYPE = 2 

local function calcLevel(exp, building_type)
	local lv = 0 
	local cfg = GetGuildBuildingLevelConfig(building_type)
	
	if not cfg then
		log.debug("fail to get building level config")
		return 1 
	end
	
	for k, v in ipairs(cfg) do
		if k ~= #cfg then
			if exp >= v and exp < cfg[k+1] then
				return k
			end
		else
			return #cfg
		end
	end
	return 1 
end

local function costGuildWealth(guild, value)
	assert(guild)
	return guild:CostWealth(player,value)	
end

function GuildBuilding.New(gid)
	local t = {
		gid = gid,
		buildings = {},
	}
	
	local success, result = database.query("select * from guild_buildings where gid = %d", gid)	
	if success and #result > 0 then
		for _, row in ipairs(result) do
			t.buildings[row.building_type] = {
				exp = row.exp,
				level = calcLevel(row.exp, row.building_type),
				db_exists = true,
			}
		end
	end
		
	return setmetatable(t, {__index = GuildBuilding})
end

function GuildBuilding:GetBuildingData(building_type)
	if not self.buildings[building_type] then
		self.buildings[building_type] = {
			exp = 0,
			level = 1,
			db_exists = false,
		}
	end
end

function GuildBuilding:AddExp(opt_id, building_type, add_exp)
	log.debug(string.format("Player %d begin addExp to building %d in guild %d, add_exp %d", opt_id, building_type, self.gid, add_exp))

	local player = PlayerManager.Get(opt_id)
	if not player then
		log.debug("player not exist")
		return false
	end
	
	local guild = player.guild
	if not guild then
		log.debug("player not in guild")
		return false
	end

	if guild.id ~= self.gid then
		log.debug("player not in this guild")
		return false
	end

	--guild level up
	if building_type == 0 then
		if costGuildWealth(guild, add_exp) then
			guild:AddExpOnly(player, add_exp, false, 5)
		end	
		return true
	end

	if building_type < MIN_BUILDING_TYPE or building_type > MAX_BUILDING_TYPE then
		log.debug(string.format("building_type %d too big or too small", building_type))
		return false
	end

	self:GetBuildingData(building_type)
	
	local current_level = self.buildings[building_type].level
	local current_exp = self.buildings[building_type].exp
	local exp = current_exp + add_exp
	
	if costGuildWealth(guild, add_exp) then
		if not self.buildings[building_type].db_exists then
			database.update("insert into guild_buildings(gid, building_type, exp) values(%d, %d, %d)", self.gid, building_type, exp) 
			self.buildings[building_type].db_exists = true
		else
			database.update("update guild_buildings set exp = %d where gid = %d and building_type = %d", exp, self.gid, building_type) 
		end
		self.buildings[building_type].exp = exp 
		self.buildings[building_type].level = calcLevel(exp, building_type)	
		return true
	else
		log.debug("cost wealth fail")
		return false
	end	
end

function GuildBuilding:GetLevel(opt_id, building_type)
	log.debug(string.format("Player %d begin GetLevel of building %d in guild %d", opt_id, building_type, self.gid))

	if building_type < MIN_BUILDING_TYPE or building_type > MAX_BUILDING_TYPE then
		log.debug(string.format("building_type %d too big or too small", building_type))
		return false
	end

	self:GetBuildingData(building_type)

	return self.buildings[building_type].level, self.buildings[building_type].exp
end

local guildBuilding = {}
function GuildBuilding.Get(gid)
	if not guildBuilding[gid] then
		guildBuilding[gid] = GuildBuilding.New(gid)
	end
	return guildBuilding[gid]
end

function process_guild_query_building_info(conn, pid, req)
	local cmd = Command.C_GUILD_QUERY_BUILDING_INFO_RESPOND
	local sn = req[1] 

	log.debug(string.format("Player %d begin to query guild building info", pid))
	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
	end

	local guild_building = GuildBuilding.Get(player.guild.id)
	if not guild_building then
		log.debug(string.format("cannot get guild_building"))
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
	end	

	local ret = {}
	for i = MIN_BUILDING_TYPE, MAX_BUILDING_TYPE, 1 do
		local lv, exp = guild_building:GetLevel(pid, i)
		table.insert(ret, {i, lv, exp})
	end

	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, ret});
end

function process_guild_level_up_building(conn, pid, req)
	local cmd = Command.C_GUILD_LEVEL_UP_BUILDING_RESPOND
	local sn = req[1] 
	local building_type = req[2]
	local exp = req[3]
	
	if not building_type or not exp then
		log.debug("param error")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	log.debug(string.format("Player %d begin to level up building %d, exp %d", pid, building_type, exp))
	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
	end

	if not HasPermission(player.title, "upgrade_building") then
		log.debug("no permission")	
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_PREMISSIONS})
	end

	local guild_building = GuildBuilding.Get(player.guild.id)
	if not guild_building then
		log.debug(string.format("cannot get guild_building"))
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
	end	

	local success = guild_building:AddExp(pid, building_type, exp)

	return conn:sendClientRespond(cmd, pid, {sn, success and Command.RET_SUCCESS or Command.RET_ERROR});
end

return GuildBuilding
