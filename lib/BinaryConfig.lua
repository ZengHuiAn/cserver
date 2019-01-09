require "protobuf"

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

local function LoadConfig(cfgName, dir)
	dir = dir or ""
	local fileName = string.format("../etc/config/%s/%s.pb", dir, cfgName)
	local cfg = readFile(fileName, cfgName);
	if not cfg then
		log.error(string.format("load config %s failed", fileName));
		return;
	end

	return cfg.rows 
end

return {
	Load = LoadConfig
}
