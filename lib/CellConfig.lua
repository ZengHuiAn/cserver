#!../bin/server

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

module "CellConfig"


-- load from ../etc/lksg.xml
local cfg = xml.open("../etc/lksg.xml")


local function dumpTable(t, prefix)
	prefix = prefix or "";

	for k, v in pairs(t) do
		print(string.format("%s%s\t%s", prefix, tostring(k), tostring(v)));
		if type(v) == "table" then
			dumpTable(v, prefix .. "\t");
		end
	end
end

cells = {};

local PortBase = tonumber(cfg.PortBase["@text"]);

for k, v in ipairs(cfg.Cells) do
	cells[k] = {};
	cells[k].host = v.host and v.host["@text"] or "localhost";
	cells[k].port = v.port and v.port["@text"]  or PortBase + k;
end
