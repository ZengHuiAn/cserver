require "consume_config" 
require "GuildInfo"
local BinaryConfig = require "BinaryConfig"

function ShopCheckCondition(shop_type, player_info, product_item, now)
	local success = true 
	if not consume_condition_config[shop_type] then
		return success
	end

	for _,checkFunc in ipairs (consume_condition_config[shop_type].conditions or {}) do
		success = checkFunc(player_info, product_item, now)	
		if not success then
			return success
		end
	end

	--do action

	return success
end

local guildShopLimitConfig = nil
local function LoadGuildShopLimitConfig()
    local rows = BinaryConfig.Load("config_guild_shop_limit", "shop")
   	guildShopLimitConfig = {}

    for _, row in ipairs(rows) do
        guildShopLimitConfig[row.gid] = {
			building_type = row.building_type,
			building_level_limit = row.building_level_limit
        }
    end
end

LoadGuildShopLimitConfig()

local function GetGuildShopLimitConfig(gid)
	return guildShopLimitConfig[gid] and guildShopLimitConfig[gid] or nil
end

local GuildSummaryConfig = nil 
local function LoadGuildSummaryConfig()
	local rows = BinaryConfig.Load("config_team_summary", "guild")
	GuildSummaryConfig = {}

	for _, v in ipairs(rows) do
		GuildSummaryConfig.CreateConsume = {}
		table.insert(GuildSummaryConfig.CreateConsume, {type = v.Create_consume_type, id = v.Create_consume_id, value = v.Create_consume_value})
		GuildSummaryConfig.CreateConsume2 = {}
		table.insert(GuildSummaryConfig.CreateConsume2, {type = v.Create_consume_type2, id = v.Create_consume_id2, value = v.Create_consume_value2})
		GuildSummaryConfig.CoolDown = v.apply_time
		GuildSummaryConfig.DailyMaxDonateCount = v.daily_max_donate_count or 1
		GuildSummaryConfig.GuildShopDiscount = v.guild_shop_discount or 5 
	end
end
LoadGuildSummaryConfig()

local playerGuildBuildingLevel = {}
local function GetPlayerGuildBuildingLevel(pid, building_type, client_lv)
	if not playerGuildBuildingLevel[pid] or not playerGuildBuildingLevel[pid][building_type] or playerGuildBuildingLevel[pid][building_type] ~= client_lv then
		playerGuildBuildingLevel[pid] =  playerGuildBuildingLevel[pid] or {}
		local guild_building_info = GetGuildBuildingLevel(pid, building_type)
		if not guild_building_info then
			return nil
		end
		playerGuildBuildingLevel[pid][building_type] = guild_building_info.level 
	end	

	return playerGuildBuildingLevel[pid][building_type]
end

local function CheckGuildBuildingLevel(pid, gid, client_building_type, client_lv)
	local cfg = GetGuildShopLimitConfig(gid)
	if not cfg then
		if client_building_type ~= 0 and client_lv ~= 0 then
			log.debug("guild shop limit config is nil")
		end
		return true 
	end

	if cfg.building_type ~= client_building_type then
		log.debug("client building type donnt fit with server cfg")
		return false
	end

	local player_building_lv = GetPlayerGuildBuildingLevel(pid, cfg.building_type, client_lv)

	if not player_building_lv then
		log.debug("cannt get guild building level")
		return false
	end

	return player_building_lv >= cfg.building_level_limit
end

function ProductItemCanBuy(shop_type, gid, pid, client_building_type, client_lv)
	if shop_type == 8 or shop_type == 9 then
		if (not client_building_type or not client_lv) and (not next(guildShopLimitConfig)) then
			return true
		end

		return CheckGuildBuildingLevel(pid, gid, client_building_type, client_lv)
	end
	return true 
end

function GetConsumeByShopType(shop_type, gid, consume, pid, client_building_type, client_lv)
	if shop_type == SHOP_TYPE_GUILD then
		if (not client_building_type or not client_lv) and (not next(guildShopLimitConfig)) then
			return consume
		end	

		local cfg = GetGuildShopLimitConfig(gid)

		if not cfg then
			log.debug("guild shop limit config is nil")
			return consume 
		end

		if cfg.building_type ~= client_building_type then
			log.debug("client building type donnt fit with server cfg")
			return false
		end

		local player_building_lv = GetPlayerGuildBuildingLevel(pid, cfg.building_type, client_lv)
		for k, v in ipairs(consume) do
			if v.value > 0 then
				v.value = math.ceil(v.value * (100 - GuildSummaryConfig.GuildShopDiscount * (player_building_lv - 1)) / 100)
			end
		end

		return consume
	end

	return consume
end


--[[
condition_group = {
	{ condition1, condition2, actionGroup },
	{ condition1, condition2, actionGroup },
	{ condition1, condition2, actionGroup },
	{ condition1, condition2, actionGroup },
	defaultActionGroup,
}


action_group = {
	action1,
	action2,
}
]]



