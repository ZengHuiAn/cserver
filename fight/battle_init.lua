

package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";


require "protobuf"

local registedProtocol = {}

local function loadConfig(configFile, protocol, protocolFile)
	if protocolFile and not registedProtocol[protocolFile] then
		local f = io.open(protocolFile, "rb")
		local protocol= f:read "*a"
		f:close()
		protobuf.register(protocol)
	end

	print(configFile);

	local f = io.open(configFile, "rb")

	assert(f, configFile .. " con't open " .. debug.traceback());


	local config = f:read "*a"
	f:close()

	return protobuf.decode(protocol, config);
end


function LoadDatabaseWithKey(table, key, forder)
	local path = forder and forder .. "/config_" .. table or table

	local config = loadConfig('../etc/config/' .. path .. ".pb", 'com.agame.config.config_' .. table, '../protocol/config.pb');

	local t = {}
	
	for _, row in ipairs(config.rows) do
		t[row[key]] = row;
	end

	return t;
end

local WELLRNG512a_ = require "WELLRNG512a"
function WELLRNG512a(seed)
	local rng = WELLRNG512a_.new(seed);
	return setmetatable({rng=rng, c=0}, {__call=function(t) 
			t.c = t.c + 1;
			local v = WELLRNG512a_.value(t.rng);
			return v;
	end})
end

function WARNING_LOG(...)
	print(...);
end

function ERROR_LOG(...)
	print(...)
end

function ASSERT(success, ...)
	if not success then
		log.error(...);
	end
end

local file = nil


local table_pack = table.pack or function(...)
	return {n = select("#", ...); ...}	
end

function BATTLE_LOG(...)
	if file == nil then
		file = io.open("../log/sgk.battle.log", "a")
	end

	if file then
		local t = table_pack(...)
		for i = 1, t.n do
			file:write(tostring(t[i]));
			file:write("\t");
		end

		file:write("\n");
		file:flush();
	end
end

SkillConfig = require "config.skill"
battle_config = require "config.battle"
