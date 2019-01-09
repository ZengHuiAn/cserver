local type=type;
local setmetatable=setmetatable;
local getmetatable=getmetatable;
local rawget=rawget;
local rawset=rawset;
local unpack=unpack;
local print=print;
local assert=assert;
local pairs=pairs;
local tostring=tostring;

module "Class"

local function getter(t, k)
	local class = rawget(t,"_class");

	-- not class entity or no such property
	if type(class) ~= "table" or class[k] == nil then 
		return rawget(t, k);
	end;

	local acc = class[k];
	if type(acc) ~= "table" or acc.get == nil then
		-- function or static member;
		return acc;
	end

	local get_type = type(acc.get);
	if get_type == "function" then 
		-- call getter
		return acc.get(t);
	elseif get_type == "string" or get_type== "number" then
		-- change hide property
		return rawget(t, acc.get);
	else 
		return acc.get;
	end
end

local function setter(t, k, v)
	local class = rawget(t, "_class");

	-- not class entity or no such property
	if class == nil or class[k] == nil then 
		rawset(t, k, v); 
		return true;
	end;

	-- set function
	local acc = class[k];
	if (type(acc) == "table" and type(acc.set) == "function") then
		-- call setter
		acc.set(t, v);
	else
		-- do nothing
		assert(false, "can't set " .. k .. " to " .. tostring(class));
	end
end

local acc = { __index = getter, __newindex = setter, };

function New(class, ...)
	local t = {};

	if type(class._init_) == "function" then
		if class._init_(t, ...) == false then
			-- 失败 需要显式返回false
			print("call _init_ failed");
			return nil;
		end
	end
	t._class = class;

	local mt = getmetatable(t);
	if mt == nil then
		setmetatable(t, acc);
	else
		assert(mt.__index == nil or mt.__index == getter);
		assert(mt.__newindex == nil or mt.__newindex == setter);

		if mt.__index == nil then
			rawset(mt, "__index", getter);
		end

		if mt.__newindex == nil then
			rawset(mt, "__newindex", setter);
		end
	end
	return t;
end
