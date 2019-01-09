local table = table;
local assert = assert;
local ipairs = ipairs;
local print = print;

local EventManager = require "EventManager"
local Class = require "Class"
require "printtb"
require "yqlog_sys"
local yqinfo = yqinfo
local sprinttb = sprinttb
local tostring = tostring
local log = log

module "RankManager"

Event = {
	CHANGE = "change",
};

local Rank = {}

function Rank:_init_(...)
	self.items = {};
	self.ranks = {};
	self.em = EventManager.New();
end

function Rank:getRank(id)
	if self.items[id] then
		return self.items[id].rank;
	else
		return nil;
	end
end

function Rank:RegisterEvent(event, func)
	local listener = self.em:CreateListener();
	listener:RegisterEvent(Event.CHANGE, func) 
end

function Rank:getValue(id)
	if self.items[id] then
		return self.items[id].value;
	else
		return nil;
	end
end

--local MASK_GUILD_ID = 10000000
function Rank:add(id)
	assert(self.items[id] == nil) --and id ~= MASK_GUILD_ID);

	local pos = table.maxn(self.ranks) + 1;
	local item = {
		id = id,
		value = 0,
		rank = pos,
		update_time = 0,
	};

	self.items[id] = item;
	self.ranks[pos] = item;

	return pos;
end
	
function Rank:setValue(id, value, update_time)
	local oldrank = self:getRank(id) or self:add(id);

	local item = self.items[id];
	if value == item.value then
		return item.rank;
	end

	local old_value = item.value
	item.value = value;
	item.update_time = update_time
	
	if value < old_value then
		for ite = oldrank, table.maxn(self.ranks), 1 do
			local back = self.ranks[ite + 1];
			if back == nil or back.value < value or (back.value == value and back.update_time < update_time) or 
			(back.value == value and back.update_time == update_time and back.id < id) then
				self.ranks[ite] = item;
				self.em:DispatchEvent(Event.CHANGE, {id = id, o = item.rank, n = ite});
				item.rank = ite;
				break;
			else
				self.ranks[ite] = back;
				self.em:DispatchEvent(Event.CHANGE, {id = back.id, o = ite + 1, n = ite});
				back.rank = ite;
			end
		end
	else		
		for ite = oldrank, 1, -1 do
			local front = self.ranks[ite - 1];
			if front == nil or front.value > value or (front.value == value and front.update_time > update_time) or 
			(front.value == value and front.update_time == update_time and front.id > id) then
				self.ranks[ite] = item;
				self.em:DispatchEvent(Event.CHANGE, {id = id, o = item.rank, n = ite});
				item.rank = ite;
				break;
			else
				self.ranks[ite] = front;
				self.em:DispatchEvent(Event.CHANGE, {id = front.id, o = ite - 1, n = ite});
				front.rank = ite;
			end
		end
	end

	return item.rank;
end

function Rank:remove(id)
	local item = self.items[id];
	if item == nil then
		return;
	end

	self.items[id] = nil;

	local total = table.maxn(self.ranks);
	for ite = item.rank, total do
		local back = self.ranks[ite + 1];
		self.ranks[ite] = back;

		if back then
			self.em:DispatchEvent(Event.CHANGE, {id = back.id, o = ite - 1, n = ite});
			back.rank = ite;
		end
	end
end

function Rank:dump()
	print("Rank dump");
	for _, item in ipairs(self.ranks) do
		print("", item.rank, item.id, item.value);
	end
end

function Rank:GetTopK()
    local max_count = 50;
    local t = {}
    for _, guild in ipairs(self.ranks) do
        if #t + 1 > max_count then
            break;
        end
        table.insert(t, {guild.id, guild.value})
    end
    return t
end

function Rank:GetTop(count)
    local max_count = count;
    local t = {}
    for _, guild in ipairs(self.ranks) do
        if #t + 1 > max_count then
            break;
        end
        table.insert(t, {guild.id,guild.value})
    end
    return t
end

function Rank:ClearRank()
	self.ranks = {}	
	self.items = {}
end

function New(...)
	return Class.New(Rank, ...);
end
