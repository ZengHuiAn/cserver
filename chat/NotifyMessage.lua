local loop = loop;
local string = string;
local ipairs = ipairs;
local table = table;
local print = print;

local database = require "database"
local Class = require "Class"
local base64 = require "base64"

module "NotifyMessage"

local MessageClass = {};

function MessageClass:_init_(id, time, to, type, data)
	self.id = id;
	self.time = time;
	self.to = to;
	self.type = type;
	self.data = data;
end

function MessageClass:Save()
	if self.id ~= nil then
		return self.id;
	end

	local success = database.update(string.format("insert into NotifyMessage(`time`, `to`, `type`, `data`) values(from_unixtime_s(%u), %u, %u, '%s')", self.time, self.to, self.type, base64.encode(self.data)));

	if not success then
		return nil;
	end

	self.id = database.last_id();
	return self.id;
end

function MessageClass:Delete()
	if self.id == nil then
		return true;
	end

	local success, result = database.update(string.format("delete from NotifyMessage where id = %u", self.id));
	if not success then
		return false;
	end
end

function New(...)
	local id   = nil;
	local time = loop.now();
	return Class.New(MessageClass, id, time, ...);
end

function LoadByPlayerID(pid)
	local success, result = database.query(string.format("select `id`, unix_timestamp(`time`) as `time`, `to`, `type`, `data` from NotifyMessage where `to` = %u", pid));
	if not success then
		return nil;	
	end

	local t = {};
	for _, v in ipairs(result) do
		local msg = Class.New(MessageClass, v.id, v.time, v.to, v.type, base64.decode(v.data));
		table.insert(t, msg);
	end
	return t;
end
