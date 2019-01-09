require "protobuf"

local NpcConfig = {}

local log = require "log"


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


local npc = {}

local cfg = readFile("../etc/config/fight/config_wave_config.pb", "config_wave_config");
for _, v in ipairs(cfg.rows) do
	npc[v.gid] = npc[v.gid] or {} 
	table.insert(npc[v.gid], v)
	--npc[v.gid][v.role_id] = v
end

local npc_cfg = {}

local cfg = readFile("../etc/config/fight/config_npc.pb", "config_npc");
for _, v in ipairs(cfg.rows) do
	npc_cfg[v.id] = v
end

local team_wave_cfg = {}
local cfg = readFile("../etc/config/team/config_team_wave_config.pb", "config_team_wave_config");
for _, v in ipairs(cfg.rows) do
	team_wave_cfg[v.gid] = team_wave_cfg[v.gid] or {} 
	table.insert(team_wave_cfg[v.gid], v)
end

function NpcConfig.Get(gid, wave, role_pos)
	for k, v in ipairs(npc[gid] or {}) do
		if v.wave == wave and v.role_pos == role_pos then
			return v
		end
	end
	return nil;
end

function NpcConfig.GetNpc(id)
	return npc_cfg[id]
end

function NpcConfig.GetWaveConfig(gid, wave, role_pos)
	for k, v in ipairs(team_wave_cfg[gid] or {}) do
		if v.wave == wave and v.role_pos == role_pos then
			return v
		end
	end
	return nil;
end

return NpcConfig
