local network=network;
local ipairs=ipairs;
local pairs=pairs;
local log=log;
local string=string;
local table=table;
local coroutine=coroutine;
local os=os;
local io=io;
local assert=assert;
local print=print;
local type = type;

local Command   = require "Command"
local AMF       = require "AMF"
local protobuf  = require "protobuf"
local Class     = require "Class"
local Scheduler = require "Scheduler"
local bit32 = require "bit32"
local debugx = require "debug"

module "ServiceManager"

debug = false;

function DEBUG(...)
	if debug then
		log.debug(string.format(...));
	end
end

-- * protocol
local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		log.warning(string.format(" * encode %s failed", protocol));		
		return nil;
	end
	return code;
end

local function decode(protocol, code)
	local msg = protobuf.decode("com.agame.protocol." .. protocol, code);
	if msg == nil then
		--log.warning(string.format(" * decode %s failed", protocol));		
		return nil;
	end
	return msg;
end

local function onClosed(conn)
	local service = conn.service;
	local remote = service._remote[conn.index];
	log.warning(string.format("service %s remote[%d] %s:%u closed", service.name, conn.index, remote.addr.host, remote.addr.port));
	remote.conn = nil;

	if service.onClosed then
		service:onClosed();
	end
end

local function onConnected(conn)
	local service = conn.service;
	local remote = service._remote[conn.index];
	log.info(string.format("service %s remote[%d] %s:%u connected, fd = %u",
						service.name, conn.index,
						remote.addr.host, remote.addr.port, conn.fd));
	conn.connecting = nil;

	if service.onConnected then
		service:onConnected();
	end
end

local function onMessage(conn, flag, cmd, channel, sid, data)
	-- assert(flag == 2);
        -- log.info("ServiceManager onMessage sid : ", sid);
	local service = conn.service;
	local remote  = service._remote[conn.index];

	DEBUG("service %s remote[%d] %s:%u recv message, cmd = %u",
			service.name, conn.index,
			remote.addr.host, remote.addr.port, cmd);

	local respond;
	local sn;

	if flag == 1 then
		respond = AMF.decode(data);
		sn = respond[1];
	elseif flag == 2 then
		if service._cmd[cmd] == nil then
			DEBUG("    unknown cmd %u, drop", cmd);
			return;
		end

		local protocol = service._cmd[cmd].protocol;
		if protocol == nil then
			DEBUG("    unknown protocol of cmd %u, drop", cmd);
			return;
		end
		
		respond = decode(protocol, data);
		sn = respond.sn;
	else
		DEBUG("    unknown flag %d", flag);
	end

	local callback = service._callback[cmd]
	if callback then
		callback(cmd, channel, respond)
	end
	
	callback = service._callback["*"]
	if callback then
		callback(cmd, channel, respond)
	end

	if remote._co[sn] == nil then
		DEBUG("    unknown co of sn %d", sn);
		return;
	end

	if flag == 1 then
		respond[1] = remote._co[sn].sn;
	else
		respond.sn = remote._co[sn].sn;
	end

	local co = remote._co[sn].co;
	remote._co[sn] = nil;

	if co then
		--log.debug("#####resume cmd =%d, channel =%d", cmd, channel)
		local status, info = coroutine.resume(co, respond);
		if status == false then
			log.error(info);
			return;
		end
	end

end

local Service = {};
function Service:_init_(name, ...)
	self.name = name;

	self._remote = {};		
	self._cmd = {};
	self._callback = {};

	for k, addr in ipairs({...}) do
		DEBUG("service %s remote[%d] %s:%u connecting", self.name, k, addr.host, addr.port);
		local c = network.new();

		local remote = {
			addr = addr,
			conn = c,
			_co = {},
		};

		-- connect
		c.service = self;
		c.index   = k;
		c.connecting = true;
		c.handler = {onConnected = onConnected, onMessage = onMessage, onClosed = onClosed};
		if not c:connect(addr.host, addr.port) then
			remote.conn = nil;
		end

		self._remote[k] = remote;
	end
end

function Service:RegisterCallBack(func, cmd)
	self._callback[cmd] = func
end

function Service:Disconnect()
	for k, v in self._remote do
		local conn =v.conn
		conn:close()
	end
end
function Service:RegisterCommand(cmd, protocol)
	self._cmd[cmd] = {protocol = protocol};
end

function Service:RegisterCommands(cmds)
	for _, v in ipairs(cmds) do
		self._cmd[v[1]] = {protocol = v[2]};
	end
end

function Service:nextSN()
	if self._next_sn == nil then
		self._next_sn = 0;
	end

	self._next_sn = self._next_sn + 1;
	return self._next_sn;
end

function Service:isConnected(channel)
	if channel and type(channel) ~= "number" then
		print("!!!!!!", debugx.traceback());
	end

	channel = channel or 0;
	local n = table.maxn(self._remote);
	if n < 1 then
		return false
	end
	local index = channel%n+1;
	local remote = self._remote[index];
	local conn = remote.conn;
	return conn ~= nil and not conn.connecting;
end


local IGNORE_TIMEOUT_COMMAND = {
	[Command.S_PVP_FIGHT_PREPARE_REQUEST] = 5 * 60,
	[Command.S_TEAM_FIGHT_START_REQUEST] = 10 * 60,
}


function Service:Request(cmd, channel, msg, real_channel)
	assert(cmd);

	if not self:isConnected(channel) then
		return
	end
	local real_channel = real_channel or 0;
	local flag = 2;
	local n = table.maxn(self._remote);
	local index = channel%n+1;
	local remote = self._remote[index];
	local conn = remote.conn;
	local protocol = self._cmd[cmd];

	local newsn = self:nextSN();

	DEBUG("service %s remote[%d] %s:%u request (%u, %s), sn = %u",
			self.name, index, remote.addr.host, remote.addr.port,
			cmd, protocol and protocol.protocol or "amf", newsn);

	if protocol == nil then
		DEBUG("    unknown cmd %u", cmd);
		return nil;
	end

	if conn == nil or conn.connecting then
		DEBUG("    failed: not connected");
		return nil;
	end
	
	local co = coroutine.running();
	local oldsn = msg.sn or msg[1] or 0;

	local timeout = IGNORE_TIMEOUT_COMMAND[cmd] or 0;

	remote._co[newsn] = {
		co = co,
		t  = os.time() + timeout,
		sn = oldsn;
	};

	DEBUG("    save sn %u -> %u", oldsn, newsn);

	local code;
	if protocol.protocol then
		msg.sn = newsn;
		code = encode(protocol.protocol, msg);
	else
		msg[1] = newsn;
		flag = 1;
		code = AMF.encode(msg);
	end

	-- log.debug(string.format("code length =%d", #code))
	local ret = false;
	if code then
                local sid = bit32.rshift_long(real_channel, 32);
		ret = conn:sends(flag, cmd, real_channel, sid, code);
	end

	if co then  
		--log.debug("#####yield cmd =%d, channel =%d, real_channel =%d", cmd, channel, real_channel)
		return coroutine.yield();
	else
		return nil;
	end
end

function Service:Notify(cmd, channel, msg, real_channel)
	if not self:isConnected(channel) then
		return
	end
	local real_channel = real_channel or 0

	local flag = 2;
	local n = table.maxn(self._remote);
	local index = channel%n+1;
	local remote = self._remote[index];
	local conn = remote.conn;
	local protocol = self._cmd[cmd];

	local newsn = self:nextSN();

	DEBUG("service %s remote[%d] %s:%u notify  (%u, %s), sn = %u",
			self.name, index, remote.addr.host, remote.addr.port,
			cmd, protocol.protocol or "amf", newsn);

	if protocol == nil then
		DEBUG("    unknown cmd");
		return false;
	end

	if conn == nil or conn.connecting then
		DEBUG("    failed: not connected");
		return false;
	end

	msg.sn = newsn;

	local code;
	if protocol.protocol then
		code = encode(protocol.protocol, msg);
	else
		flag = 1;
		code = AMF.encode(msg);
	end
        local sid = bit32.rshift_long(real_channel, 32);
	return conn:sends(flag, cmd, real_channel, sid, code), msg.sn;
end
function Service:NotifyWithData(cmd, channel, data, real_channel)
	if not self:isConnected(channel) then
		return
	end
	local real_channel = real_channel or 0

	local flag = 2;
	local n = table.maxn(self._remote);
	local index = channel%n+1;
	local remote = self._remote[index];
	local conn = remote.conn;

	local newsn = self:nextSN();

	DEBUG("service %s remote[%d] %s:%u notify  (%u, %s), sn = %u",
			self.name, index, remote.addr.host, remote.addr.port,
			cmd, "json", newsn);

	if conn == nil or conn.connecting then
		DEBUG("    failed: not connected");
		return false;
	end

	local code=data;
        local sid = rshift_long(real_channel, 32);
	return conn:sends(flag, cmd, real_channel, sid, code);
end

local services = {}; 

function New(name, ...)
	local service = Class.New(Service, name, ...);
	if service then
		services[name] = service;
	end
	return service;
end

function Get(name)
	return services[name];
end

-- init protocol
local function loadProtocol(file)
	local f = io.open(file, "rb")
	local protocol= f:read "*a"
	f:close()
	protobuf.register(protocol)
end

loadProtocol("../protocol/agame.pb");

TIMEOUT = 3; -- 请求超时3秒

function onSchedulerUpdate(now)
	local toCo = {};
	local now = os.time();

	for _, s in pairs(services) do
		for k, r in pairs(s._remote) do
			for sn, cv in pairs(r._co) do 
				if (r.conn == nil) or (now - cv.t > TIMEOUT) then
					table.insert(toCo, {sn = sn, co = cv.co});
					r._co[sn] = nil;
				end
			end

			if r.conn == nil then
				DEBUG("service %s remote[%d] %s:%u reconnecting", s.name, k, r.addr.host, r.addr.port);
				local c = network.new();
				r.conn = c;
				r._co = {};

				-- reconnect
				c.service = s;
				c.index   = k;
				c.connecting = true;
				c.handler = {onConnected = onConnected, onMessage = onMessage, onClosed = onClosed};
				if not c:connect(r.addr.host, r.addr.port) then
					r.conn = nil;
				end
			end
		end
	end

	-- 恢复超时或者断开链接的请求
	-- 这一步放到后面是因为可能要执行很久
	for _, value in ipairs(toCo) do
		if value.co and type(value.co) == "thread" and coroutine.status(value.co) == "suspended" then 
			DEBUG("request is timeout");
			local status, info = coroutine.resume(value.co); --{sn = value.sn, result = Command.RET_ERROR});
			if status == false then
				log.error(info);
				return;
			end
		end
	end
end

Scheduler.New(onSchedulerUpdate);
