local class = {}

local function dome() end
-- class constructor
function class.new(cls, ...)
	local obj = {}

	if cls._init_ and (cls._init_(obj, ...) == false) then
		return nil
	end

	cls._getter_ = cls._getter_ or dome;
	obj = setmetatable(obj, {_class = cls, __index=function(t,k)
		return cls[k] or cls._getter_(t,k)
	end, __newindex=function(t,k,v)
		if cls._setter_ then cls._setter_(t,k,v) else rawset(t, k, v) end
	end})

	return obj
end

function class.declare(super)
	return setmetatable({super=super}, {__index = super, __call = class.new })
end

-- set class() == class.declare()
setmetatable(class, { __call = function(_, super) return class.declare(super) end })

function class.check(obj, cls)
	local meta = getmetatable(obj)
	local ccls = meta and meta._class or nil
	while ccls and ccls ~= cls do
		ccls = ccls.super	
	end
	return ccls ~= nil
end

return class
