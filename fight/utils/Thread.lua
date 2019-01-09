local Pipe = require "utils.Pipe"


local threadRef = setmetatable({}, {__mode = 'kv'})

local Thread = { }

local xpcall = xpcall
if not table.unpack and not ( type(jit) == 'table' ) then
	xpcall = function(func, cc, ...)
		return true, func(...);
	end
end

function Thread.Self()
	return threadRef[coroutine.running()];
end

function Thread.Create(func)
	local t = { input = Pipe.New(), output = Pipe.New() }

	local co = coroutine.create(function(...)
		-- print(coroutine.running(), 'start');

		local success, info = xpcall(func, function(...)
			ERROR_LOG('thread error', ..., debug.traceback(''));
		end, ...)

		-- threadRef[t.co] = nil;

		t.input:Close();
		t.output:Close();
		t.co = nil;

		-- print(coroutine.running(), 'stop');

		t.status = "dead"
	end)

	t.co = co;
	t = setmetatable(t, {__index=Thread});

	t.status = "idle"

	threadRef[co] = t;

	return t;
end

function Thread:Start(...)
	if self.status == "idle" then
		self.status = "running"
		assert(coroutine.resume(self.co, ...));
	end
	return self;
end

function Thread:send_message(...)
	self.input:Push(...);
end

function Thread:read_message(...)
	return self.input:Pop();
end

function Thread:peek_message(...)
	if self.input:empty() then
		return nil;
	end
	return self.input:Pop();
end

function Thread:resume(...)
	if coroutine.status(self.co) == 'suspended' then
		local success, info = coroutine.resume(self.co, ...);
		if not success then
			ERROR_LOG(info)
		end
	end
end

function Thread:recv_message()
	return self.output:Pop();
end

function Thread:dispatch_message(...)
	return self.output:Push(...);
end

function Thread.Call(func, ...)
	Thread.Create(func):Start(...);
end

function Thread.Eval(func, ...)
	-- local func = loadstring(script)
	if func then
		Thread.Call(func, ...);
	end
end

--[[ 
local thread ;
thread = Thread.Create(function()
	while true do
		print('!!!', thread, Thread.Self());
		print(thread:read_message())
	end
end)

thread:Start()

for i = 1, 10 do
	thread:send_message(i, nil, nil, math.random(1000, 9999));
end

thread = nil

print('before collectgarbage');
for k, v in pairs(threadRef) do
	print('', k, v);
end

collectgarbage('collect');

print('after collectgarbage');
for k, v in pairs(threadRef) do
	print('', k, v);
end

--]]

return Thread;
