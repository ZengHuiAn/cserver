require "log"

local Pipe = require "Pipe"

local all = {};

local Agent = {};

local function NewAgent(id)
	if all[id] then
		all[id].stoping = nil;
		return all[id];
	end

	local t = {
		id = id,
		queue = Pipe.New(), -- NewQueue(),
	};

	all[id] = t;
	setmetatable(t, {__index=Agent});

	t.thread = coroutine.create(Agent.Loop);
	local success, info = coroutine.resume(t.thread, t);
	if not success then
		log.error(info);
	end

	return t;
end

local function GetAgent(id)
	return all[id];	
end

function Agent:Loop()
	while true do
		local proc, argv = self.queue:Pop();
		if proc == 'STOP' then
			if self.stoping then
				break;
			end
		else
			local ok, err =pcall(proc, unpack(argv))
			if not ok then
				log.error("Agent.Loop error:" .. err)
			end
		end
	end
	self.thread  = nil;
	all[self.id] = nil;
end

--[[
function Agent:Start() 
	if self.thread then
		return true;
	end

	self.thread = coroutine.create(Agent.Loop);
	local success, info = coroutine.resume(self.thread, self);
	if not success then
		log.error(info);
	end
	return success;
end
--]]

function Agent:Dispatch(proc, args)
	if proc == 'STOP' then
		self.stoping = true;
	end

	self.queue:Push(proc, args)
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

function Agent:Notify(...)
	if self.conn then
		sendClientRespond(self.conn, 104, self.id, {0, 0, ...});
	end
end

module "Agent"

New = NewAgent;
Get = GetAgent;
