#!../bin/server 
package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

require "log"
require "XMLConfig"
if log.open then
	local l = log.open(
		XMLConfig.FileDir and XMLConfig.FileDir .. "/manor_%T.log" or
		"../log/manor_%T.log");
	log.debug    = function(...) l:debug   (...) end;
	log.info     = function(...) l:info   (...)  end;
	log.warning  = function(...) l:warning(...)  end;
	log.error    = function(...) l:error  (...)  end;
end
require "AMF"
require "Command"

require "NetService"
local ManorLog = require "ManorLog"
local ManorEvent = require "ManorEvent"
local DayQuest = require "DayQuest"
local BossProxy = require "BossProxy"

local service = {};
local os = os;
local _now = os.time();
local loading = true;

math.randomseed(os.time());
math.random();

local function sendClientRespond(conn, cmd, channel, msg)
	assert(conn,debug.traceback());
	assert(cmd,debug.traceback());
	assert(channel,debug.traceback());
	assert(msg and (table.maxn(msg) >= 2),debug.traceback());

	local code = AMF.encode(msg);

	local sid = tonumber(bit32.rshift_long(channel, 32))
	assert(sid > 0)

	if code then conn:sends(1, cmd, channel, sid, code) end
end

local function make_manor_id(manor_id, playerId)
	manor_id =manor_id or 0 
	if manor_id == 0 then
		manor_id =playerId
	end
	return manor_id
end

function onLoad()
end

function onUnload()
end

-- listen
local cfg = XMLConfig.Social["Manor"];
service = NetService.New(cfg.port, cfg.host, cfg.name or "Manor");
assert(service, "listen on " .. cfg.host .. ":" .. cfg.port .. " failed");

service:on("accept", function (client)
	client.sendClientRespond = sendClientRespond;
	log.debug(string.format("Service: client %d connected", client.fd));
end);

service:on("close", function(client)
	log.debug(string.format("Service: client %d closed", client.fd));
end);

-- service:on(Command.S_GM_HOT_UPDATE_BONUS_REQUEST,   "GmHotUpdateBonusRequest", Bonus.OnGmHotUpdateBonus);

local function loadModule(name)
	log.debug("loadModule", name);
	assert(loadfile(name .. ".lua"))(service);
end

loadModule("Manufacture");
loadModule("ManorHeroInPub");
loadModule("CityContruct");
ManorLog.RegisterCommand(service)

--local ManorWorkman = require "ManorWorkman"

service:on(Command.C_LOGIN_REQUEST, function(conn, playerId, request)
	-- leave_manor(playerId)
end);

service:on(Command.C_LOGOUT_REQUEST, function(conn, playerId, request)
	-- leave_manor(playerId)
	UnloadManufacture(playerId)
	ManorWorkman.Unload(playerId)
end);

ManorEvent.RegisterCommand(service)
DayQuest.RegisterCommands(service)
BossProxy.RegisterCommands(service)

