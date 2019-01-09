local BinaryConfig = require "BinaryConfig"
local cell = require "cell"
local log = require "log"

local OpenConfig = {}
local LevMap = {}

local function load_config()
	local rows = BinaryConfig.Load("config_openlev", "item")
	for _, v in ipairs(rows) do
		OpenConfig[v.id] = v.open_lev	
	end
end

load_config()

--[[
	pid 玩家id
	id 功能id
	返回值: 是否满足
--]]
local function isLvOK(pid, id)	
	if not OpenConfig[id] then
		return true;
	end

	return cell.CheckOpenLev(pid, id);
end

local function get_level(pid)
	local player = cell.getPlayerInfo(pid)
	if player and player.level then
		return player.level 
	end

	return 0
end

local function abs(value)
	if value < 0 then
		value = -value
	end

	return value
end

local function get_open_level(id)
	return OpenConfig[id]
end

return {
	isLvOK = isLvOK,
	get_level = get_level,
	abs = abs,
	get_open_level = get_open_level,
}

