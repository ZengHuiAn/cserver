local commonConfig = nil;
local function GetCommonConfigConfig(id)
	if commonConfig == nil then
		commonConfig = LoadDatabaseWithKey("common", "id");
	end
	if id then
		return commonConfig[id];
	else
		return commonConfig;
	end
end

return {
    Get = GetCommonConfigConfig
}