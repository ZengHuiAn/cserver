local class = require "utils.class"
local ID = require "utils.ID"
local default_formula = require "utils.PropertyFormula"

local Property = class()

function Property:_init_(property)
	self.uuid = ID.Next();

	self.property = property or {}
	self.formula = default_formula

	self.merged = {}
	self.cached = {}

	self.change = {}

	self.path = {}

	self.depends = {}

	self.runtime = {}
end

function Property:Formula(key, callback)
	self.formula[key] = callback;
end

function Property:Get(key)
	-- not number value
	local v = rawget(self, key); if v ~= nil then return v; end
	local v = self.runtime[key]; if v ~= nil then return v; end

	if #self.path > 0 then
		self.depends[key] = self.depends[key] or {};
		for _, v in ipairs(self.path) do
			self.depends[key][v] = true;

			-- depend loop check
			if key == v then
				local str = '\n[WARNING] ' .. key .. " depend loop: ";
				for _, v in ipairs(self.path) do
					str = str .. v .. " -> ";
				end
				str = str .. key;
				assert(false, str);
			end
		end
	end

	local change = self.change[key];

	local v = self.cached[key];
	if v ~= nil then 
		if type(v) ~= "number" then
			return v;
		else
			return v + (change or 0); 
		end
	end

	v = self.property[key]
	if type(v) ~= "number" and v ~= nil then
		self.runtime[key] = v;
		return v;
	end

	if change then
		v = v or 0;
	else
		change = 0;
	end

	local c = self.formula[key];
	if c ~= nil then 
		-- calc depend path
		self.path[#self.path + 1] = key;

		local cv = c(self);

		self.path[#self.path] = nil;
		
		if cv ~= nil and type(cv) ~= "number" then
			self.runtime[key] = cv;
			return cv;
		end

		v = (v or 0) + cv;
	end

	if type(key) == "number" or not c then
		for _, m in pairs(self.merged) do
			local mv = m and m[key]
			if mv ~= nil then
				if type(mv) ~= "number" then
					self.runtime[key] = mv;
					return mv;
				end
				v = (v or 0) + mv
			end
		end
	end

	if v then
		self.cached[key] = v;
		return v + change;
	end
end

function Property:_getter_(key)
	local t = self:Get(key);
	if t ~= nil then return t else return 0; end
end

function Property:_setter_(key, value)
	if value == nil then
		if self.change[key] then
			self.change[key] = nil
		elseif self.runtime[key] then
			self.runtime[key] = nil
		elseif self.cached[key] then
			self.cached[key] = nil;
		end
		return;
	end

	if self.runtime[key] or type(value) ~= 'number' then
		self.runtime[key] = value;
		return;
	end

	self.change[key] = (self.change[key] or 0) + (value - self[key]);

	for k, _ in pairs(self.depends[key] or {}) do
		self.cached[k] = nil;
	end
end

function Property:Add(key, property)
	self.merged[key] = property;
	self.cached = {}
end

function Property:Remove(key)
	if self.merged[key] then
		self.merged[key] = nil
		self.cached = {}
	end
end

return Property;
