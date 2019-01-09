local propLimitConfig = nil;

local Type = {
	Hero_Level   = 1,
	Weapon_Level = 2,
	Weapon_Star  = 3,
	Equip_Level  = 4,
	Equip_Adv	 = 5,
	Inscription  = 6,
}

local function LoadLevelupConfig(type)
	if propLimitConfig == nil then
		propLimitConfig = {};
		DATABASE.ForEach("propertyLimit", function(row)
			if propLimitConfig[row.limitType] == nil then
				propLimitConfig[row.limitType] = {};
				setmetatable(propLimitConfig[row.limitType], {__index = function ( t,k )
					print(k.."属性在propertyLimit中不存在")
					return 1;
				end })
			end
			propLimitConfig[row.limitType][row.type0] = row.value0;
		end)
	end

	if type ~= nil then
		return propLimitConfig[type];
	end
	return propLimitConfig;
end

return {
    Get = LoadLevelupConfig,
    Type = Type
}
