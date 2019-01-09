
local Game = require "battlefield.Logic";
local game = Game.New()

VMListen(function(event, ...)
	print("VM", event, ...)
	VMDispatch(event, ...);
end)

local Hero = class()
function Hero:_init_(property)
	self.property = property or {}
	self.formula = {}
	self.runtime = {}
	self.merged = {}
	self.cached = {}
end

function Hero:Formula(key, callback)
	self.formula[key] = callback;
end

function Hero:_getter_(key)
	local v = self.runtime[key];  if v ~= nil then return v end
	local v = self.cached[key];   if v ~= nil then return v end

	local c = self.formula[key];
	if c ~= nil then 
		local cv = c(self);
		self.cached[key] = cv;
		return cv;
	end

	v = self.property[key];
	if type(v) ~= "number" and v ~= nil then
		return v 
	end

	for _, m in ipairs(self.merged) do
		local mv = m[key];
		if mv ~= nil then
			v = (v or 0) + mv
		end
	end

	self.cached[key] = v;

	return v;
end

function Hero:_setter_(key, value)
	self.runtime[key] = value;
	self.cached = {}
end

function Hero:Reset()
	self.runtime = {}
	self.formula = {}
	self.merged = {}
	self.cached = {}
end

function  Hero:Merge(property)
	self.merged[#self.merged+1] = property;
	self.cached = {}
end

function Hero:UnMerge()
	self.merged = {}
	self.cached = {}
end


local hero = Hero({[1]=10,[2]=20})
hero:Formula("hp", function(P)
	return P[1] + P[2];
end)

hero:Formula("mp", function(P)
	return P[1] * P[2];
end)

print("!!!", hero.hp, hero.mp);

print("VM end");
