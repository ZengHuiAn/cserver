local ArenaBuffConfig = nil

local log = require "log"
local BinaryConfig = require "BinaryConfig"
require "printtb"

local function insertBuff(t, buff_type, buff_value)
	if buff_type == 0 or buff_value == 0 then
		return
	end

	table.insert(t, {buff_type = buff_type, buff_value = buff_value})
end

local function load_arena_buff_config()
	local rows = BinaryConfig.Load("config_arena_buff_type", "arena")	
	ArenaBuffConfig = {}

	for _, row in ipairs(rows) do
		ArenaBuffConfig[row.gid] = {
			condition = row.condition,
			buff = {}
		}
		insertBuff(ArenaBuffConfig[row.gid].buff, row.buff_type1, row.buff_value1)	
		insertBuff(ArenaBuffConfig[row.gid].buff, row.buff_type2, row.buff_value2)	
	end
end

load_arena_buff_config()

function GetArenaBuffConfig(gid) 
	return ArenaBuffConfig[gid]
end
