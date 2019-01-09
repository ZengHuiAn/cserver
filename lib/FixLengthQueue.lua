-- 

local Queue = {};

function Queue.New(length, cb, ctx)
	local t = {length = length, content = {}, head = length, cb = cb, ctx = ctx};
	return setmetatable(t, Queue);
end

function Queue:__index(key)
	if type(key) == "number" and key > 0 and key <= self.length then
		local pos = ((self.head - key + self.length) % self.length) + 1;
		return self.content[pos];
	end
	return Queue[key];
end

function Queue:__newindex(key, value)
	-- assert(false);
	if type(key) == "number" and key > 0 and key <= self.length then
		self.content[key] = value;
		self.head = key;
	elseif Queue[key] then
		assert(false, "can't set key [" .. key .. "] to Queue");
	else
		rawset(self, key, value);
	end
end

function Queue:push(value)
	local nextPos = self.head % self.length + 1;
	local old = self.content[nextPos]
	self.content[nextPos] = value;
	self.head = nextPos;
	if self.cb and type(self.cb) == "function" then
		self.cb(self, value, nextPos, old, self.ctx);
	end
end

function Queue:clear()
	self.content = {};
	self.head = self.length;
end

function Queue:next(key)
	key = key or 1;
	if type(key) == "number" and key > 0 and key <= self.length then
		return self.content[key+1];
	end
end

function Queue:dump(func)
	func = func or function(v) return v;  end 

	print('dump queue', self);
	for idx = 1, self.length do
		if self[idx] then
			print(idx, func(self[idx]));
		else
			print(idx, "nil");
		end
	end	
end


--------------------------------------------------------------------------------
-- Test start
local ncb = 0;
local function onPush(queue, value, rindex, old)
	ncb = ncb + 1;
end

local queue = Queue.New(5, onPush);

for idx = 1, 10 do 
	queue:push(idx);
end
assert(ncb == 10, 'Queue call back system error');
for idx = 1, queue.length do
	assert(queue[idx] == (11 - idx), 'Queue index failed');
end

for idx = 1, queue.length  do
	queue[idx] = idx;
end

for idx = 1, queue.length  do
	assert(queue[idx] == (5 - idx + 1), 'Queue set failed');
end
-- Test end
--------------------------------------------------------------------------------

local mname = select(1, ...);
if mname == nil then
	return;	
end

-- build module
module(mname);

-- export function
New = Queue.New;
