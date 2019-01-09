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

local XMLConfig = require "XMLConfig"

module "ChatConfig"

FIGHT_COUNT_PER_DAY = 100
CHAT_MESSAGE_SAVE_TIME = 48*3600
QUERY_CHAT_MESSAGE_MAX_COUNT =50
local ServiceName = {"Chat", "Mail"};
--------------------------------------------------------------------------------
-- load config from xml
--
FightDetailLocation  = XMLConfig.FightDetailLocation;

listen = {};
for idx, name in ipairs(ServiceName) do
	listen[idx] = {};
	listen[idx].host = XMLConfig.Social[name].host;
	listen[idx].port = XMLConfig.Social[name].port;
	listen[idx].name = name;
end

Listen = listen;
