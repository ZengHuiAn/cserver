#!../bin/server 

package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

math.randomseed(os.time());
math.random();

require "log"
require "cell"
require "NetService"
require "XMLConfig"
require "protobuf"
require "cell"

if log.open then
	local l = log.open(XMLConfig.FileDir and XMLConfig.FileDir .. "/ai_%T.log" or "../log/ai_%T.log");
	log.debug    = function(...) l:debug   (...) end;
	log.info     = function(...) l:info   (...)  end;
	log.warning  = function(...) l:warning(...)  end;
	log.error    = function(...) l:error  (...)  end;
end

local function sendClientRespond(conn, cmd, channel, msg)
	assert(conn);
	assert(cmd);
	assert(channel);
	assert(msg and (table.maxn(msg) >= 2));

	local sid = tonumber(bit32.rshift_long(channel, 32))
	assert(sid > 0)

	local code = AMF.encode(msg);

	if code then conn:sends(1, cmd, channel, sid, code) end
end

local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));		
		loop.exit();
		return nil;
	end
	return code;
end

function sendServiceRespond(conn, cmd, channel, protocol, msg)
    local code = encode(protocol, msg);
	local sid = tonumber(bit32.rshift_long(channel, 32))
    if code then
        return conn:sends(2, cmd, channel, sid, code);
    else
        return false;
    end
end

local function decode(code, protocol)
	return protobuf.decode("com.agame.protocol." .. protocol, code);
end

local cfg = XMLConfig.Social["AI"];
service = NetService.New(cfg.port, cfg.host, cfg.name);
assert(service, "listen on " .. cfg.host .. ":" .. cfg.port .. " failed");

local function onServiceRegister(conn, channel, request)
	if request.type == "GATEWAY" then
		for k, v in pairs(request.players) do

		end
	end
end

local debug = false 
local f = io.open("../log/ai_debug", "rb")
if f then
    debug = true 
	f:close()
end

function AI_DEBUG_LOG(...)
	if debug then
		return log.debug(...)
	else
		return print(...)
	end	
end

function AI_WARNING_LOG(...)
	if debug then
		return log.warning(...)
	else
		return print(...)
	end
end

require "AISocialManager"
local AIData = require "AIData"
local FriendData = require "AIFriend"
local GuildData = require "AIGuild"
local SocialManager = require "SocialManager"
local DataThread = require "DataThread"
local BattleConfig = require "BattleConfig"
local AIName = require "AIName"
	
service:on("accept", function (client)
	client.sendClientRespond = sendClientRespond;
	log.debug(string.format("Service: client %d connected", client.fd));
end);

service:on("close", function(client)
	log.debug(string.format("Service: client %d closed", client.fd));
end);

SocialManager.Connect("AI")

local AILogic = require "AILogic"

service:on(Command.C_LOGIN_REQUEST, function(conn, pid, request)
	if AILogic.AI_Start() then
		AILogic.AddLoginCount()
		local player_info = cell.getPlayer(pid)
		if player_info then
			AILogic.ActAIByNum(player_info.player.level, pid)	
		end
	end
end);

service:on(Command.C_LOGOUT_REQUEST, function(conn, pid, request) 
	if AILogic.AI_Start() then
		AILogic.DecreaseLoginCount()
	end
end);

service:on(Command.S_SERVICE_REGISTER_REQUEST,	onServiceRegister);

service:on(Command.S_NOTIFY_ACTIVE_AI, "NotifyActiveAI",  function(conn, pid, request)
	if AILogic.AI_Start() then
		local ref_level = request.level
		local first_target = request.first_target

		print("NotifyActiveAI >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>", ref_level, first_target)
		local activity_cfg = BattleConfig.GetActivityConfig(first_target)
		if activity_cfg then
			ref_level = math.random(math.max(ref_level - 5, activity_cfg.lv_limit), ref_level + 5)
		end

		AILogic.ActAI(1, ref_level, first_target, "AUTOMATCH")	
	end
end)

AIData.RegisterCommand(service)

--local data_thread = coroutine.create(function()
	DataThread.getInstance():Start()
--end)
--coroutine.resume(data_thread)

