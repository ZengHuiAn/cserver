local string = string;
local coroutine = coroutine;
local pairs = pairs;
local print = print;
local assert= assert;
local error = error;
local typeof = type;
local io = io;
local dofile = dofile;
local tb=debug.traceback
local network = network;
local log = log;

local Class    = require "Class";
local AMF      = require "AMF"
local protobuf = require "protobuf"
local Command  = require "Command"
local Agent    = require "Agent"
local bit32    = require "bit32";

module "NetService"

DEBUG = false;

local function debug(...)
	if DEBUG then
		debug(...);
	end
end

----------------------------------------
-- remote service manage
local VirtualService = {name="VirtualService"};
local function registerRemoteServiceTo(obj, type, id, conn)
	if type == nil or id == nil then
		return;
	end

	conn.rstype = type;
	conn.rsid   = id;

	if obj._remote_service == nil then
		obj._remote_service = {};
	end

	if obj._remote_service[type] == nil then
		obj._remote_service[type] = {};
	end

	-- 增加服务记录
	obj._remote_service[type][id] = {conn = conn};

	if obj ~= VirtualService then
		registerRemoteServiceTo(VirtualService, type, id, conn);
	else
		debug("registerRemoteService", type, id);
	end
end

local function unregisterRemoteServiceFrom(obj, conn)
	if conn.rstype == nil or conn.rsid == nil then
		return;
	end

	local type = conn.rstype;
	local id   = conn.rsid;

	if obj._remote_service and obj._remote_service[type] then
		obj._remote_service[type][id] = nil;
	end

	if obj ~= VirtualService then
		unregisterRemoteServiceFrom(VirtualService, conn);
	else
		debug("unregisterRemoteService", type, id);
	end
end

local function getRemoteService(type, obj)
	obj = obj or VirtualService;
	if obj._remote_service then
		return obj._remote_service[type];
	end
end
-- end
--------------------------------------------------------------------------------


local Service = {}; 

local function setHandler(service, conn)
	conn.agents = {}

	-- init connection handler
	conn.handler = {
		-- cleint message
		onMessage = function (conn, flag, cmd, channel, sid, data)
			-- log.info("NetService onMessage sid : ", sid);
			if service.dispatch[cmd] == nil or service.dispatch[cmd][1] == nil then
				log.warning(string.format("service %s unknown command %u", service.name, cmd));
				return;
			end
			local proc = service.dispatch[cmd][1];
			local protocol = service.dispatch[cmd][2];

			-- decode message
			local request;
			if flag == 1 then
				request = AMF.decode(data);
			elseif flag == 2 then
				if protocol == nil then
					log.warning(string.format("service %s unknown protocol of command %u", service.name, cmd));
					return;
				end
				request = protobuf.decode("com.agame.protocol." .. protocol, data);
			else
				log.warning(string.format("service %s unknown message flag %u of command %u", service.name, flag, cmd));
				return;
			end

			if not request then
				log.warning(string.format("service %s decode message of command %u flag %u failed, protocol = [%s]",
				service.name, cmd, flag, protocol or ""));
				return;
			end

			if channel ~= 0 then --转换pid
				channel = bit32.lshift_long(sid, 32) + channel;
			end

			if cmd == Command.S_SERVICE_REGISTER_REQUEST and channel == 0 and request.type == "GATEWAY" then
				for _, v in pairs(request.players) do
					conn.agents[v] = true;
					Agent.New(v).conn = conn;
				end
			end

			local agent = Agent.New(channel)
			if agent then
				if channel ~= 0 then
					conn.agents[channel] = true
					agent.conn = conn;
				end

				agent:Dispatch(proc, {conn, channel, request});

				if cmd == Command.C_LOGOUT_REQUEST then
					agent.conn = nil;
					agent:Dispatch('STOP');
				end
			end
		end,

		-- client closed
		onClosed = function(conn)
			-- 移除服务记录
			unregisterRemoteServiceFrom(service, conn);

			for channel,_ in pairs(conn.agents) do
				local agent = Agent.Get(channel);	
				if agent and agent.conn == conn then
					agent.conn = nil;
					agent:Dispatch('STOP');
				end
			end
			conn.agents = {}

			if service.dispatch and service.dispatch.close and service.dispatch.close[1] then
				service.dispatch.close[1](conn);
			else
				debug(string.format("service %s client %u closed", service.name, conn.fd));
			end
		end,
	};
end

-- add dispatch table
function Service:on(cmd, protocol, proc)
	if proc == nil and typeof(protocol) == "function" then
		proc = protocol;
		protocol = nil;
	end

	assert(cmd, tb(0));


	if (cmd == Command.S_SERVICE_REGISTER_REQUEST) then
		self.on_service_register = proc;
	else
		self.dispatch[cmd] = {proc, protocol};
	end
end

function Service:listen()
	if self.conn then		
		self.conn:close();
	end

	self.conn = network.new();
	self.conn.handler = {
		onAccept = function (conn)
			setHandler(self, conn);

			-- call accept
			if self.dispatch and self.dispatch.accept and self.dispatch.accept[1] then
				self.dispatch.accept[1](conn);
			else
				debug(string.format("self %s client %u connected", self.name, conn.fd));
			end
		end,

		onClosed = function(conn)
			log.warning(string.format("self %s listing socket closed", self.name));
		end
	};

	-- 注册服务 自动处理
	self.dispatch[Command.S_SERVICE_REGISTER_REQUEST] = {function(conn, channel, request)
		log.warning(string.format("sevice %s recv register request with channel %u", self.name, channel));
		if channel ~= 0 then
			log.warning(string.format("    error"));
			return;
		end

		if self.service == nil then
			self.service = {};
		end

		local type = request.type;
		local id   = request.id;
		log.warning(string.format("    type %s id %u", type, id));

		registerRemoteServiceTo(self, type, id, conn)

		if (self.on_service_register) then
			self.on_service_register(conn, channel, request);
		end

		local msg = protobuf.encode("com.agame.protocol.ServiceRegisterRespond", {sn = sn, result = Command.RET_SUCCESS});
		conn:send(2, Command.S_SERVICE_REGISTER_RESPOND, 0, msg);
	end, "ServiceRegisterRequest"};

	self.dispatch[Command.S_SERVICE_BROADCAST_RESPOND] = {function(conn, channel, request)
		debug(conn.rstype, conn.rsid, "broad cast return");
	end, "ServiceBroadcastRespond"};

	-- start listen
	if self.conn:listen(self.host, self.port) then
		debug(string.format("service %s listen on %s:%u success", self.name, self.host, self.port));
		return true;
	else
		debug(string.format("service %s listen on %s:%u failed", self.name, self.host, self.port));
		return false;
	end
end

local function broadcastByService(service, name, flag, cmd, code, pids)
	debug(string.format("service %s broadcast to %s, cmd = %u, flag = %u", service.name, name, cmd, flag));
	remotes = getRemoteService(name, service);
	if remotes == nil then
		log.warning(string.format("    service %s not exist", name));		
		return;
	end

	local msg = protobuf.encode("com.agame.protocol.ServiceBroadcastRequest", {cmd = cmd, flag = flag, msg = code, pid = pids});
	for _, remote in pairs(remotes) do
		debug("   send", remote.conn.rsid, string.len(msg));
		remote.conn:sends(2, Command.S_SERVICE_BROADCAST_REQUEST, 0, 0, msg);
	end
	return true;
end

function Service:Broadcast(name, flag, cmd, code, pids)
	return broadcastByService(self, name, flag, cmd, code, pids);
end

function BroadcastEx(name, flag, cmd, code, to)
	local remotes = getRemoteService(name);
	if remotes == nil then
		log.warning(string.format("%s not exist", name));		
		return;
	end
	for k, v in pairs(to) do
		debug(string.format("service %s broadcast to gateway %d, cmd = %u, flag = %u", name, k, cmd, flag));
		local remote =remotes[k]
		if remote and remote.conn then
			local msg = protobuf.encode("com.agame.protocol.ServiceBroadcastRequest", {cmd = cmd, flag = flag, msg = code, pid = v.pids});
			remote.conn:sends(2, Command.S_SERVICE_BROADCAST_REQUEST, 0, 0, msg);
		else
			log.warning(string.format("%s %d not exist", name, k));		
		end
	end
	return true;
end

function NotifyClientEx(cmd, msg, to)
	return BroadcastEx("GATEWAY", 1, cmd, AMF.encode({0, 0, {cmd,msg}}), to);
end
function Service:BroadcastToClient(flag, cmd, code, pids)
	if pids and #pids == 0 then
		-- empty pids
		return true;
	end
	return self:Broadcast("GATEWAY", flag, cmd, code, pids);
end

function Service:NotifyClients(cmd, msg, clients)
	if clients and #clients == 0 then
		-- empty pids
		return true;
	end
	return self:Broadcast("GATEWAY", 1, cmd, AMF.encode({0, 0, {cmd,msg}}), clients);
end

local g_service_id = 0;
local function nextID()
	g_service_id = g_service_id + 1;
	return g_service_id;
end

accept_hotfix = true;

local services = {};
local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));		
		loop.exit();
		return nil;
	end
	return code;
end

local function sendServiceRespond(conn, cmd, channel, protocol, msg)
	local code = encode(protocol, msg);
	if code then
		return conn:sends(2, cmd, channel, 0, code);
	else
		return false;
	end
end

local function go(proc, ...)
	local co = coroutine.create(proc);
	local status, info = coroutine.resume(co, ...);
	return status, info;
end

local function onRunScript(conn, channel, request)
	local cmd   = Command.S_RUN_SCRIPT_RESPOND;
	local proto = "aGameRespond";

	if not accept_hotfix then
		print(Command.RET_ERROR);
		return sendServiceRespond(conn, cmd, channel, proto,
			{result = Command.RET_ERROR, sn = request.sn or 0});
	end

	local respond = {cmd = Command.RET_SUCCESS, sn = request.sn or 0};

	if request.file and request.file ~= "" then
		log.info("run script", request.file);

		local success, info = go(function() dofile(request.file); end);
		if not success then
			log.error("run script %s failed: %s", request.file, info);
			respond = {result = Command.RET_ERROR, sn = request.sn or 0};
		end
	end

	sendServiceRespond(conn, cmd, channel, proto, respond);
end

function Service:_init_(port, host, name)
	self.port = port;
	self.host = host;
	self.id   = nextID();
	self.name = name or ("NetService_" .. self.id);

	self.dispatch = {};

	self.dispatch[Command.S_RUN_SCRIPT_REQUEST] = {onRunScript, "RunScriptRequest"};

	services[self.name] = self;

	-- start
	return Service.listen(self);
end

function BroadcastToClient(flag, cmd, msg, pids)
	if pids and #pids == 0 then
		-- empty pids
		return true;
	end
	return broadcastByService(VirtualService, "GATEWAY", flag, cmd, AMF.encode(msg), pids);
end

function BroadcastToClientAMF(cmd, msg, pids)
	return BroadcastToClient(1, cmd, msg, pids)
end

function NotifyClients(cmd, msg, pids)
	return BroadcastToClient(1, Command.C_PLAYER_DATA_CHANGE, {0,0,{cmd,msg}}, pids);
end

function Get(name)
	return services[name];
end

-- reset dispatch table
function Service:reset()
	self.dispatch = {};
end

function Service:stop()
	self.conn:close();
	services[self.name] = nil;
	self.conn = nil;
end

function New(port, host, name)
	host = host or "0.0.0.0";
	return Class.New(Service, port, host, name);
end

-- init protocol
local function loadProtocol(file)
	local f = io.open(file, "rb")
	local protocol= f:read "*a"
	f:close()
	protobuf.register(protocol)
end

loadProtocol("../protocol/agame.pb");
