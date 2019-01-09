local DialogCfg = {
    ["newShopFrame"] = {parentTag = "MapSceneUIRootMid"},
    ["Role_Frame"] = {parentTag = "MapSceneUIRootMid"},
    ["PvpArena_Frame"] = {parentTag = "MapSceneUIRootMid"},
    ["NewChatFrame"] = {parentTag = "MapSceneUIRootMid"},
    ["DrawCardFrame"] = {parentTag = "MapSceneUIRootMid"},
    ["HeroComposeFrame"] = {parentTag = "MapSceneUIRootMid"},
    ["mapSceneUI/newMapSceneActivity"] = {parentTag = ""},
    ["mapSceneUI/QuestGuideTip"] = {parentTag = ""},
    ["mapSceneUI/guideLayer/guideLayer"] = {parentTag = ""},
    ["DrawSliderFrame"] = {Ignore = true}
}

local TeamOrFighting = {
    -- ["newSelectMap/newSelectMap"] = {tip = TeamOrFightingTip},
    -- ["newSelectMap/newGoCheckpoint"] = {tip = TeamOrFightingTip},
    -- ["PvpArena_Frame"] = {tip = TeamOrFightingTip},
    -- ["guild_pvp/GuildPVPJoinPanel"] = {tip = TeamOrFightingTip},
    -- ["PveArenaFrame"] = {tip = TeamOrFightingTip},
}

local MapTeamOrFighting = {
    [25] = {Dialog = "newUnion/newUnionFrame"},
    [26] = {Dialog = "Manor_Overview"},
    ["map_chouka"] = {Dialog = "DrawCardFrame"},
    [12] = {Dialog = "DrawCardFrame"},
}

local function GetCfg(name)
    return DialogCfg[name]
end

local function CheckDialog(name)
    if TeamOrFighting[name] then
        if SceneStack.GetBattleStatus() then
            showDlgError(nil, "战斗内无法进行该操作")
            return false
        end
        if utils.SGKTools.GetTeamState() then
            showDlgError(nil, "队伍内无法进行该操作")
            return false
        end
    end
    return  true
end

local function CheckMap(id)
    if MapTeamOrFighting[id] then
        if MapTeamOrFighting[id].Dialog then
            DialogStack.Push(MapTeamOrFighting[id].Dialog)
            return false
        else
            if SceneStack.GetBattleStatus() then
                showDlgError(nil, "战斗内无法进行该操作")
                return false
            end
            if utils.SGKTools.GetTeamState() then
                showDlgError(nil, "队伍内无法进行该操作")
                return false
            end
        end
    end
    return true
end

return {
    GetCfg = GetCfg,
    CheckDialog = CheckDialog,
    CheckMap = CheckMap,
}
