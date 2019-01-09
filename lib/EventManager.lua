local Class = require "Class"
local assert = assert
local pairs = pairs;
local type = type;
local print = print;
local log = log;
local pcall = pcall;

module "EventManager"

local function nextID(manager)
	manager.next_id = (manager.next_id or 0) + 1;
	return manager.next_id;
end

-- * listener

local EventListener = {};
function EventListener:_init_(manager, name)
	assert(manager, "create EventListener without manager");
	self.id = nextID(manager);
	self.manager = manager;
	self.name = name or "EventListener";
	self.events = {};
end

function EventListener:RegisterEvent(event, func)
	if (self.manager.events[event] == nil) then
		self.manager.events[event] = {};
	end
	self.manager.events[event][self.id] = self;
	self.events[event] = func;
end

function EventListener:UnregisterEvent(event)
	self.manager.events[event][self.id] = nil;
	self.events[event] = nil;
end

function EventListener:Release()
	for k, v in pairs(self.events) do
		self.manager.events[event][self.id] = nil;
	end
	self.events = nil;
	self = nil;
end

-- * manager
local instance;
local allManager = {};

local function getInstance()
	if instance == nil then
		instance = New();
	end
	return instance;
end

function _init_(self, name)
	self.events = {};
	if name then
		allManager[name] = self;
		self.name = name;
	end
end

function CreateListener(self, ...)
	if type(self) == "table" then
		return Class.New(EventListener, self, ...)
	else
		-- shift params
		return Class.New(EventListener, getInstance(), self, ...)
	end
end

local function DispatchEventR(manager, event, ...)
	local ls = manager.events[event];
	if ls then
		for _, listener in pairs(ls) do
			-- listener.events[event](event, ...);
			local status, info = pcall(listener.events[event], event, ...);
			if not status then
				log.error(info);
			end
		end
	end
end

function DispatchEvent(self, event, ...)
	local manager = self;
	if type(manager) == "table" then
		DispatchEventR(self, event, ...);
	else
		-- shift params
		DispatchEventR(getInstance(), self, event, ...);
	end
end

function New(...)
	return Class.New(_M, ...);
end

function Get(name)
	return allManager[name];
end
