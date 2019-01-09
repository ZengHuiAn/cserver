local TeamModule = require "module.TeamModule"
local BountyModule = require "module.BountyModule"
local ItemHelper = require "utils.ItemHelper"
local playerModule = require "module.playerModule"
local EventManager = require 'utils.EventManager';

local runing = false;
local function opTaskBag(table, func)
	local obj = UnityEngine.GameObject.FindWithTag("UITopRoot") or UnityEngine.GameObject.FindWithTag("UGUIRootTop") or UnityEngine.GameObject.FindWithTag("UGUIRoot");
	DialogStack.PushPrefStact("mapSceneUI/selectTaskItem", {consumeTab = table, fun = func}, obj);
end

local function opUnionInfo()
    if module.unionModule.Manage:GetUionId() == 0 then
        showDlgError(nil, "未加入公会")
    else
        --DialogStack.PushMapScene("newUnion/mapUnion/mapUnionInfo", 1)
        DialogStack.PushMapScene("newUnion/newUnionFrame", 1)
    end
end

local function opUnionMember()
    if module.unionModule.Manage:GetUionId() == 0 then
        showDlgError(nil, "未加入公会")
    else
        DialogStack.PushMapScene("newUnion/newUnionFrame", 2)
    end
end

local function opUnionJoin()
    if module.unionModule.Manage:GetUionId() == 0 then
        showDlgError(nil, "未加入公会")
    else
        DialogStack.PushMapScene("newUnion/newUnionFrame", 3)
    end
end

local function opUnionShop()
    DialogStack.PushMapScene("newShopFrame", {index = 4})
end

local function opUnionExplore()
    if module.unionModule.Manage:GetUionId() == 0 then
        showDlgError(nil, "未加入公会")
    else
        DialogStack.PushMapScene("newUnion/newUnionExplore", true)
    end
end

local function opUnionWish()
    if module.unionModule.Manage:GetUionId() == 0 then
        showDlgError(nil, "未加入公会")
    else
        DialogStack.PushMapScene("newUnion/newUnionWish")
    end
end

local function opUnionList()
	DialogStack.PushMapScene("newUnion/newUnionList")
end

---打开开始战斗
local function opFightInfo(gid, npcId)
    DialogStack.PushMapScene("newSelectMap/newGoCheckpoint", {gid = gid, npcId = npcId})
end

local function quickToUse(itemType, itemId, effectName, effTime, showType, play_icon, play_text, btnName, func)
    if itemType and itemId then
        local obj = UnityEngine.GameObject.FindWithTag("UITopRoot") or UnityEngine.GameObject.FindWithTag("UGUIRootTop") or UnityEngine.GameObject.FindWithTag("UGUIRoot");
        DialogStack.PushPref("mapSceneUI/item/quickToUse", {type = itemType, id = itemId, func = func, effectName = effectName, effTime = effTime, showType = showType, play_text = play_text, play_icon = play_icon, btnName = btnName}, obj);
    else
        ERROR_LOG("mapHelper quickToUse itemType itemId", itemType, itemId)
    end
end

local function IsInTeam()
	return TeamModule.GetTeamInfo().id > 0
end

local function IsCaptain()
	return TeamModule.GetTeamInfo().leader.pid == playerModule.GetSelfID();
end

local function GetTeamMemberCount()
	return #TeamModule.GetTeamMembers();
end

local function GetItemCount(id)
	return ItemHelper.Get(41, id).count;
end

local function GetBountyCompleteCount()
	return BountyModule.Get().normal_count, BountyModule.Get().double_count
end

local function ShowQuickBuy(id,type,shop_id)
	local obj = UnityEngine.GameObject.FindWithTag("UITopRoot") or UnityEngine.GameObject.FindWithTag("UGUIRootTop") or UnityEngine.GameObject.FindWithTag("UGUIRoot");
	DialogStack.PushPref("easyBuyFrame", {id = id,type = type, shop_id = shop_id}, obj);
end

local table_data = {};
local function GetConfigTable(name,key)
	if table_data[name] == nil then
		table_data[name] = {};
	end
	if table_data[name][key] == nil then
		local database = {};
		DATABASE.ForEach(name, function(row)
			database[row[key]] = database[row[key]] or {}
			table.insert(database[row[key]], row);
		end)
		table_data[name][key] = database;
	end
	return table_data[name][key];
end

local function GetQuestConfigByNPC(...)
	return module.QuestModule.GetQuestConfigByNPC(...)
end

local function EnterManorMain()
	DialogStack.PushMapScene("Manor_Frame");
end

local function EnterManorBuilding(interval)
	interval = interval or 0;
	-- if open_select then
	-- 	DialogStack.PushPrefStact("Manor_SelectFrame",{interval = index}, UnityEngine.GameObject.FindWithTag("UGUIRootTop").gameObject);
	-- else
	-- 	DialogStack.PushMapScene("Manor_DetailFrame",{index = index, dialog_interval = interval});
	-- end
	local callback = function ()
		runing = false;
	end

	if not runing then
		runing = true
		if interval <= 3 and  interval ~= 0 then
			module.ManorManufactureModule.ShowProductSource(nil, interval, true, callback);
		else
			DialogStack.Push("Manor_Overview",{interval = interval, callback = callback});
		end
	end
end

local function PlayGuide(id, time)
    if not time then
        module.guideModule.Play(id)
    else
        module.guideModule.PlayWaitTime(id, nil, time)
    end
end

local function ClearGuideCache(groupId)
    module.guideModule.ClearCacheByGroupId(groupId)
end


return {
	--RunFunction = RunFunction,
	IsInTeam = IsInTeam,
	IsCaptain = IsCaptain,
	GetTeamMemberCount = GetTeamMemberCount,
	GetItemCount = GetItemCount,
	GetBountyCompleteCount = GetBountyCompleteCount,
	ShowQuickBuy = ShowQuickBuy,
	GetConfigTable = GetConfigTable,
	OpTaskBag = opTaskBag,
    QuickToUse = quickToUse,
	GetQuestConfigByNPC = GetQuestConfigByNPC,
	OpFightInfo = opFightInfo,

	OpUnionInfo = opUnionInfo,
	OpUnionMember = opUnionMember,
	OpUnionJoin = opUnionJoin,
	OpUnionShop = opUnionShop,
	OpUnionExplore = opUnionExplore,
	OpUnionWish = opUnionWish,
    OpUnionList = opUnionList,

	EnterManorMain = EnterManorMain,
	EnterManorBuilding = EnterManorBuilding,
    PlayGuide = PlayGuide,
    ClearGuideCache = ClearGuideCache,
}
