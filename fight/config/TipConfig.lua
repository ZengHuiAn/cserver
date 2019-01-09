local AssistDescConfig=nil
local function loadAssistDescConfig(id)
	AssistDescConfig= AssistDescConfig or LoadDatabaseWithKey("function_info", "function_id") or {}
	if not AssistDescConfig[id] then
		ERROR_LOG(id.."在配置表function_info的function_id列不存在")
	end
   return AssistDescConfig[id] or {}
end

local Tips_list_Config = nil
local function GetTipsConfig(gid)
	if Tips_list_Config== nil then
		Tips_list_Config = {}
		DATABASE.ForEach("tips", function(row)
			Tips_list_Config[row.gid] = row.tips
		end)
	end
	if gid then
		return Tips_list_Config[gid]
	else
		return Tips_list_Config
	end
end

local consume_Config=nil
local function loadConsumeConfig(id)
    consume_Config = consume_Config or LoadDatabaseWithKey("common_consume", "id") or {}
   return consume_Config[id] or {}
end

local showItemDescConfig = nil;--节日商店类型描述
local function GetShowItemDescConfig(type)
	if showItemDescConfig == nil then
		showItemDescConfig = LoadDatabaseWithKey("show_wenzi", "type");
	end
	if type then
		return showItemDescConfig[type];
	else
		return showItemDescConfig;
	end
end

return {
    GetAssistDescConfig = loadAssistDescConfig,--获取描述Text
    GetTipsConfig=GetTipsConfig,--获取提示配置
    GetConsumeConfig=loadConsumeConfig,
    GetShowItemDescConfig=GetShowItemDescConfig,
}
