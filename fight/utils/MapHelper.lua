local TeamModule = require "module.TeamModule"
local BountyModule = require "module.BountyModule"
local ItemHelper = require "utils.ItemHelper"
local playerModule = require "module.playerModule"
local EventManager = require 'utils.EventManager';
local openLevel = require "config.openLevel"

local runing = false;
local function opTaskBag(table, func)
	local obj = UnityEngine.GameObject.FindWithTag("UITopRoot") or UnityEngine.GameObject.FindWithTag("UGUIRootTop") or UnityEngine.GameObject.FindWithTag("UGUIRoot");
	DialogStack.PushPrefStact("mapSceneUI/selectTaskItem", {consumeTab = table, fun = func}, obj);
end

local function opUnionInfo()
    if module.unionModule.Manage:GetUionId() == 0 then
        DialogStack.PushMapScene("newUnion/newUnionList")
        --showDlgError(nil, "未加入公会")
    else
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

local function opUnionActivity()
    if module.unionModule.Manage:GetUionId() == 0 then
        showDlgError(nil, "未加入公会")
    else
        DialogStack.PushMapScene("newUnion/newUnionFrame", 4)
    end
end

local function opUnionShop()
    DialogStack.PushMapScene("newShopFrame", {index = 4})
end

local function opUnionExplore()
    if module.unionModule.Manage:GetUionId() == 0 then
        showDlgError(nil, "未加入公会")
    else
        if openLevel.GetStatus(2102) then
            DialogStack.PushMapScene("newUnion/newUnionExplore", true)
        else
            showDlgError(nil, SGK.Localize:getInstance():getValue("tips_lv_02", openLevel.GetCfg(2102).open_lev))
        end
    end
end

local function opUnionWish()
    if module.unionModule.Manage:GetUionId() == 0 then
        showDlgError(nil, "未加入公会")
    else
        if openLevel.GetStatus(2103) then
            DialogStack.PushMapScene("newUnion/newUnionWish")
        else
            showDlgError(nil, SGK.Localize:getInstance():getValue("tips_lv_02", openLevel.GetCfg(2103).open_lev))
        end
    end
end

local function opUnionList()
	DialogStack.PushMapScene("newUnion/newUnionList")
end

---打开开始战斗
local function opFightInfo(gid, npcId)
    DialogStack.PushMapScene("newSelectMap/newGoCheckpoint", {gid = gid, npcId = npcId})
end

local function quickToUse(itemType, itemId, effectName, effTime, showType, play_icon, play_text, btnName, isAuto, func)
    if itemType and itemId then
        if isAuto then
            local _item = SGK.ResourcesManager.Load("prefabs/effect/UI/"..effectName)
            local _rootObj = UnityEngine.GameObject.FindWithTag("quickToUseRoot") or UnityEngine.GameObject.FindWithTag("UITopRoot") or UnityEngine.GameObject.FindWithTag("UGUIRootTop") or UnityEngine.GameObject.FindWithTag("UGUIRoot")
            local _obj = CS.UnityEngine.GameObject.Instantiate(_item, _rootObj.transform)
			local _view = CS.SGK.UIReference.Setup(_obj)

            _view.fx_woring_ui_1.gzz_ani.text_working[UI.Text].text = play_text
			_view.fx_woring_ui_1.gzz_ani.icon_working[UI.Image]:LoadSprite("icon/" .. play_icon)
			CS.UnityEngine.GameObject.Destroy(_obj, effTime)
			if func then
				StartCoroutine(function()
					WaitForSeconds(effTime or 1)
					func()
				end)
			end
        else
            local obj = UnityEngine.GameObject.FindWithTag("quickToUseRoot") or UnityEngine.GameObject.FindWithTag("UITopRoot") or UnityEngine.GameObject.FindWithTag("UGUIRootTop") or UnityEngine.GameObject.FindWithTag("UGUIRoot");
            DialogStack.PushPref("mapSceneUI/item/quickToUse", {type = itemType, id = itemId, func = func, effectName = effectName, effTime = effTime, showType = showType, play_text = play_text, play_icon = play_icon, btnName = btnName}, obj);
        end
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
		if interval ~= 0 then
			module.ManorManufactureModule.ShowProductSource(nil, interval, true, callback);
		else
			DialogStack.Push("Manor_Overview",{interval = interval, callback = callback});
		end
		-- if module.ManorManufactureModule.GetManorStatus() then
		-- else
		-- 	if interval ~= 0 then
		-- 		showDlgError("只有庄园主人才能进入")
		-- 	else
		-- 		showDlgError("只有庄园主人才能管理庄园")
		-- 	end
		-- end

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

local function OpenSelectMap(data)
    DialogStack.Push("newSelectMap/newSelectMapUp", data)
end

local function OpCreateCharacter(data)
    DialogStack.PushPref("mapSceneUI/guideLayer/createCharacter", data, UnityEngine.GameObject.FindWithTag("UGUIRootTop"))
end

local function EnterOthersManor(pid)
	if utils.SGKTools.GetTeamState() then
		if utils.SGKTools.isTeamLeader() then
			SceneStack.EnterMap(26, {mapid = 26, room = pid})
		else
			showDlgError(nil,"退出队伍后重试")
		end
	else
		SceneStack.EnterMap(26, {mapid = 26, room = pid})
	end
end

local function OpenActivityMonster(data)
    DialogStack.Push("mapSceneUI/activityMonster", data)
end

local function ChangeMapSceneGuideLayerActive(status)
    DispatchEvent("LOCAL_MAPSCENE_CHAGEGUIDELAYER_STATUS", status)
end

local function OpenDrawCard()
    DialogStack.Push("DrawCardFrame", data)
end

local function OpenTrialTower()
    DialogStack.Push("trial/trialTower")
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
    OpSelectMap = OpenSelectMap,

	OpUnionInfo = opUnionInfo,
	OpUnionMember = opUnionMember,
	OpUnionJoin = opUnionJoin,
	OpUnionActivity = opUnionActivity,
	OpUnionShop = opUnionShop,
	OpUnionExplore = opUnionExplore,
	OpUnionWish = opUnionWish,
    OpUnionList = opUnionList,
    OpCreateCharacter = OpCreateCharacter,

	EnterManorBuilding = EnterManorBuilding,
    PlayGuide = PlayGuide,
	ClearGuideCache = ClearGuideCache,
	EnterOthersManor = EnterOthersManor,
    MapSceneGuideLayerActive = ChangeMapSceneGuideLayerActive,
    OpenActivityMonster = OpenActivityMonster,
    OpenDrawCard = OpenDrawCard,
    OpenTrialTower = OpenTrialTower,
}
