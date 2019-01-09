local BinaryConfig = require "BinaryConfig"

local config_team_activity 
local function LoadConfigTeamActivity()
	local rows = BinaryConfig.Load("config_team_activity", "fight")	

	config_team_activity = {}
    for _, row in ipairs(rows or {}) do
		config_team_activity[row.id] = {
			server_script = row.server_script,
			begin_time = row.begin_time,
			end_time = row.end_time,
			period = row.period,
			duration = row.duration,
			raid_duration = row.raid_duration
		}
	end
end
LoadConfigTeamActivity()

local function GetTeamActivityConfig(id)
	return config_team_activity[id]
end

local config_team_activity_npc
local function LoadConfigTeamActivityNpc()
	local rows = BinaryConfig.Load("config_team_activity_npc", "fight")
	
	config_team_activity_npc = {}
	for _, row in ipairs(rows or {}) do
		config_team_activity_npc[row.id] = row 
	end
end
LoadConfigTeamActivityNpc()

local function GetTeamActivityNpcConfig(id)
	return config_team_activity_npc[id]
end

local function GetTeamActivityTime(id)
	local activity_cfg = GetTeamActivityConfig(id)
	if not activity_cfg then
		return false
	end

	local period = activity_cfg.period > 0 and activity_cfg.period or 0xffffffff
	local duration = activity_cfg.duration > 0 and activity_cfg.duration or period
	local total_pass = loop.now() - activity_cfg.begin_time
	local period_pass = total_pass % period

	local current_period_begin_time = loop.now() - period_pass
	local current_period_end_time = current_period_begin_time + activity_cfg.duration

	if loop.now() < current_period_begin_time or loop.now() > current_period_end_time then
		return false
	end

	return true, current_period_begin_time, current_period_end_time, activity_cfg.raid_duration
end


local configs = {}
local function PhaseConfig(name)
	local rows = BinaryConfig.Load(name, "fight")
	configs[name] = {}
	for _, row in ipairs(rows or {}) do
		configs[name][row.id] = row
	end
end

local function LoadLogicConfig()
	local rows = BinaryConfig.Load("config_team_activity_tables", "fight")

	for _, row in ipairs(rows or {}) do
		PhaseConfig(row.tablename)
	end
end
LoadLogicConfig()

local function GetConfigByName(Name, key)
	return configs[Name] and configs[Name][key] or nil
end

return {
	GetTeamActivityTime = GetTeamActivityTime,
	GetTeamActivityConfig = GetTeamActivityConfig,
	GetTeamActivityNpcConfig = GetTeamActivityNpcConfig,
	GetConfigByName = GetConfigByName,
}

