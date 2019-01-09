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

local Team = require "Team"

local MapManager = require "MapManager"

if log.open then
	local l = log.open(XMLConfig.FileDir and XMLConfig.FileDir .. "/fight_%T.log" or "../log/fight_%T.log");
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
	-- log.debug(string.format("send %d byte to conn %u", string.len(code), conn.fd));
	-- log.debug("sendClientRespond", cmd, string.len(code));

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

local cfg = XMLConfig.Social["Map"];
service = NetService.New(cfg.port, cfg.host, cfg.name);
assert(service, "listen on " .. cfg.host .. ":" .. cfg.port .. " failed");
	
service:on("accept", function (client)
	client.sendClientRespond = sendClientRespond;
	log.debug(string.format("Service: client %d connected", client.fd));
end);

service:on("close", function(client)
	log.debug(string.format("Service: client %d closed", client.fd));
end);


service:on(Command.C_LOGIN_REQUEST, function(conn, pid, request)
	MapManager.OnPlayerLogin(pid);
	Team.OnPlayerLogin(pid)
end);

service:on(Command.C_LOGOUT_REQUEST, function(conn, pid, request) 
	MapManager.OnPlayerLogout(pid);
	Team.OnPlayerLogout(pid);
end);

service:on(Command.S_SERVICE_REGISTER_REQUEST, function(conn, channel, request)
	if request.type == "GATEWAY" then
		for k, v in pairs(request.players) do
			Team.OnPlayerLogin(v)	
			MapManager.OnPlayerLogin(v);
		end
	end
end)

service:on(Command.S_MAP_LOGIN_REQUEST, "MapLoginRequest", function(conn, channel, request) 
	local cmd = Command.S_MAP_LOGIN_RESPOND;
	local proto = "aGameRespond";

	if channel ~= 0 then
		log.error(id .. "Fail to `S_MAP_LOGIN_REQUEST`, channel ~= 0")
		sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
		return;
	end

	local pid = request.pid
	MapManager.OnPlayerLogin(pid)
	Team.OnPlayerLogin(pid)

	log.info("Success `S_MAP_LOGIN`")
	sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
end)

service:on(Command.S_MAP_LOGOUT_REQUEST, "MapLogoutRequest", function(conn, channel, request) 
	local cmd = Command.S_MAP_LOGOUT_RESPOND;
	local proto = "aGameRespond";

	if channel ~= 0 then
		log.error(id .. "Fail to `S_MAP_LOGOUT_REQUEST`, channel ~= 0")
		sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
		return;
	end

	local pid = request.pid
	MapManager.OnPlayerLogout(pid)
	Team.OnPlayerLogout(pid);

	log.info("Success `S_MAP_LOGOUT`")
	sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
end)

MapManager.registerCommand(service);
Team.registerCommand(service);
