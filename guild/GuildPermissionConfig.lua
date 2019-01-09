local log = require "log"
local BinaryConfig = require "BinaryConfig"
require "printtb"

local guildPermissionConfig = nil 
local second_min_title = 3
function LoadGuildPermissionConfig()
	local rows = BinaryConfig.Load("config_team_permission", "guild")	
	guildPermissionConfig = {}

	for _, row in ipairs(rows) do
		guildPermissionConfig[row.title] = {
			audit = row.audit and row.audit or 0,
			set_slogan = row.set_slogan and row.set_slogan or 0,
			auto_confirm = row.auto_confirm and row.auto_confirm or 0,
			upgrade_building = row.upgrade_building and row.upgrade_building or 0,
			set_title = row.set_title and row.set_title or 0,
			kick = row.kick and row.kick or 0,	
		}
		if row.title > second_min_title then
			second_min_title = row.title
		end
	end
end

LoadGuildPermissionConfig()

function HasPermission(title, per)
	if not next(guildPermissionConfig) then
		if title == 0 or title > 10 then
			return false 
		else
			return true
		end
	end

	if guildPermissionConfig[title] and guildPermissionConfig[title][per] and guildPermissionConfig[title][per] >= 1 then
		return true
	end	
end

function GetSecondMinTitle()
	return second_min_title
end
