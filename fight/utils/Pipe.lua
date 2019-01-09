local Queue = require "utils.Queue"

local safe_pack = table.pack or function(...)
	local r = {...}
	r.n = select('#', ...)
	return r;
end

local safe_unpack = table.unpack or function(arg)
	return unpack(arg, 1, arg.n);
end

local safe_resume = function(co, ...)
	local success, info = coroutine.resume(co, ...);
	if not success then
		ERROR_LOG('pipe resume failed', info)
	end
end

local Pipe = {}
function Pipe.New()
	return setmetatable({
		queue = Queue.New(),
		waiting = Queue.New(),
	}, {__index=Pipe});
end

function Pipe:Push(...)
	if not self.waiting then return end

	local co = self.waiting:pop();
	if co then
		safe_resume(co, ...);
	else
		self.queue:push(safe_pack(...));
	end
end

function Pipe:Pop()
	if not self.queue then return end

	if not self.queue:empty() then
		return safe_unpack(self.queue:pop());
	end

	local co = coroutine.running();
	if coroutine.isyieldable and coroutine.isyieldable() or co then
		self.waiting:push(co);
		return coroutine.yield();
	end
end

function Pipe:Close()
	while not self.waiting:empty() do
		local co = self.waiting:pop()
		safe_resume(co);
	end

	self.queue = nil;
	self.waiting = nil;
end

function Pipe:isEmpty()
	return self.queue:empty();
end

Pipe.Write = Pipe.Push
Pipe.Read  = Pipe.Pop

return Pipe;