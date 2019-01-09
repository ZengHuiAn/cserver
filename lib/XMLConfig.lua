package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

local xml = require "xml"

local string = string;
local ipairs = ipairs;
local pairs = pairs;
local type = type;
local tonumber = tonumber;
local tostring = tostring;
local print = print;

module "XMLConfig"

local function dumpTable(t, prefix)
	prefix = prefix or "";

	for k, v in pairs(t) do
		print(string.format("%s%s\t%s", prefix, tostring(k), tostring(v)));
		if type(v) == "table" then
			dumpTable(v, prefix .. "\t");
		end
	end
end


local cfg = xml.open("../etc/lksg.xml")

ServerId =cfg["@id"] and tonumber(cfg["@id"])
Environment = cfg["@environment"] 
FightDetailLocation  = cfg.HTMLBase["@text"];
Database = cfg.Database;
FileDir = cfg.Log.FileDir["@text"];

-- print('FightDetailLocation');
-- print('', FightDetailLocation);

PortBase = tonumber(cfg.PortBase["@text"]);

--[[
listen = {};

for idx, name in ipairs(ServiceName) do
	local scfg = cfg.Social[name];

	local id = tonumber(scfg["@id"]);

	listen[idx] = {};
	listen[idx].host = scfg.host and scfg.host["@text"] or "localhost"
	listen[idx].port = scfg.port and tonumber(scfg.port["@text"]) or (PortBase + id);
end

print('listen config');
dumpTable(listen, "\t");

Listen = listen;
--]]

Social = {};

for k, scfg  in ipairs(cfg.Social) do
	local id = tonumber(scfg["@id"]);
	local social = {};
	social.host = scfg.host and scfg.host["@text"] or "localhost"
	social.port = scfg.port and tonumber(scfg.port["@text"]) or (PortBase + id);
	social.id   = id;

	local name = scfg["@name"];
	if (name == nil) or (name == "") then
		name = scfg["@"];
	end

	Social[name] = social;
end

GlobalService = {};
for k, scfg  in ipairs(cfg.GlobalService) do
	local id = tonumber(scfg["@id"]);
	if id then
		local social = {};
		social.host = scfg.host and scfg.host["@text"] or "localhost"
		social.port = scfg.port and tonumber(scfg.port["@text"]) or (PortBase + id);
		social.id   = id;

		local name = scfg["@name"];
		if (name == nil) or (name == "") then
			name = scfg["@"];
		end

		GlobalService[name] = social;
	end
end



-- print('social');
-- dumpTable(Social, '\t');
