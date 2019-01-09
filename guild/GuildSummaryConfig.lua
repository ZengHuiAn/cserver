require "protobuf"
local log = require "log"
local BinaryConfig = require "BinaryConfig"
GuildSummaryConfig = {}

-- init protocol
local function loadProtocol(file)
	local f = io.open(file, "rb")
	local protocol= f:read "*a"
	f:close()
	protobuf.register(protocol)
end

loadProtocol("../protocol/config.pb");

local function readFile(fileName, protocol)
	local f = io.open(fileName, "rb")
	local content = f:read "*a"
	f:close()

	return protobuf.decode("com.agame.config." .. protocol, content);
end

local cfg = readFile("../etc/config/guild/config_team_summary.pb", "config_team_summary");
for _, v in ipairs(cfg.rows) do
	--GuildSummaryConfig.CreateConsume = {}
	--table.insert(GuildSummaryConfig.CreateConsume, {type = v.Create_consume_type, id = v.Create_consume_id, value = v.Create_consume_value})
	--GuildSummaryConfig.CreateConsume2 = {}
	--table.insert(GuildSummaryConfig.CreateConsume2, {type = v.Create_consume_type2, id = v.Create_consume_id2, value = v.Create_consume_value2})
	GuildSummaryConfig.DailyMaxDonateCount = v.daily_max_donate_count or 1
	GuildSummaryConfig.GuildShopDiscount = v.guild_shop_discount or 5 
end

local cfg = readFile("../etc/config/hero/config_common.pb", "config_common");
for _, v in ipairs(cfg.rows) do
	if v.id == 11 then
		GuildSummaryConfig.CoolDown = v.para1
		break
	end	
end

local cfg = readFile("../etc/config/hero/config_common_consume.pb", "config_common_consume")
for _, v in ipairs(cfg.rows) do
	if v.id == 3 then
		GuildSummaryConfig.CreateConsume  = { { type = v.type, id = v.item_id, value = v.item_value } }
	elseif v.id == 4 then
		GuildSummaryConfig.CreateConsume2 = { { type = v.type, id = v.item_id, value = v.item_value } }
	end
end

GuildNumberConfig = {}

local cfg = readFile("../etc/config/guild/config_team_number.pb", "config_team_number");
for k, v in ipairs(cfg.rows) do
	GuildNumberConfig[k] = v
end

local function insertItem(t, type, id, value)
    if not type or type == 0 then
        return
    end

    if not id or id == 0 then
        return
    end

    if not value or value == 0 then
        return
    end

    table.insert(t, {type = type, id = id, value = value})
end

GuildBoxConfig = {}

local cfg = readFile("../etc/config/guild/config_team_award.pb", "config_team_award")
for k, v in ipairs(cfg.rows) do
	GuildBoxConfig[v.award_type] = GuildBoxConfig[v.award_type] or {}	
	GuildBoxConfig[v.award_type][v.team_level] = GuildBoxConfig[v.award_type][v.team_level] or {}
	GuildBoxConfig[v.award_type][v.team_level][v.sort] = GuildBoxConfig[v.award_type][v.team_level][v.sort] or {}	
	GuildBoxConfig[v.award_type][v.team_level][v.sort].condition = v.condition_value
	GuildBoxConfig[v.award_type][v.team_level][v.sort].reward = GuildBoxConfig[v.award_type][v.team_level][v.sort].reward or {} 
	insertItem(GuildBoxConfig[v.award_type][v.team_level][v.sort].reward, v.product_type, v.product_id, v.product_value)
	insertItem(GuildBoxConfig[v.award_type][v.team_level][v.sort].reward, v.product_type2, v.product_id2, v.product_value2)
	insertItem(GuildBoxConfig[v.award_type][v.team_level][v.sort].reward, v.product_type3, v.product_id3, v.product_value3)
end

function GetBoxReward(type, level, id)
	if not GuildBoxConfig[type] or not GuildBoxConfig[type][level] or not GuildBoxConfig[type][level][id] then
		return nil
	end
	return GuildBoxConfig[type][level][id]
end


local guildBuildingLevelConfig = nil
local function LoadGuildBuildingLevelConfig()
    local rows = BinaryConfig.Load("config_guild_building_level", "guild")
    guildBuildingLevelConfig = {}

    for _, row in ipairs(rows) do
        guildBuildingLevelConfig[row.building_type] = guildBuildingLevelConfig[row.building_type] or {}
		guildBuildingLevelConfig[row.building_type][row.level] = row.exp	
    end
end

LoadGuildBuildingLevelConfig()

function GetGuildBuildingLevelConfig(building_type)
    return guildBuildingLevelConfig[building_type] and guildBuildingLevelConfig[building_type] or nil
end

local heroPropertyConfig = nil
local function LoadHeroProperty()
	local rows = BinaryConfig.Load("config_role", "hero")
    heroPropertyConfig = {}

    for _, row in ipairs(rows) do
        heroPropertyConfig[row.id] = row.type
    end
end
LoadHeroProperty()

function GetHeroProperty(id)
	return heroPropertyConfig[id] and heroPropertyConfig[id] or nil
end

local ExploreMapConfig = {}
local function LoadExploreMapConfig()
	local rows = BinaryConfig.Load("config_exploremap_message", "guild")
	for _, row in ipairs(rows) do
		ExploreMapConfig[row.Mapid] = row
	end
end
LoadExploreMapConfig()

function GetExploreMapConfig(map_id)
	return ExploreMapConfig[map_id]
end
