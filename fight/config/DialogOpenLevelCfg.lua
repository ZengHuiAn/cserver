local RedDotModule = require "module.RedDotModule"
local QuestModule = require "module.QuestModule"

----大地图 左下角按钮栏
local MapSceneBtnInfo = {
    --公会
    {mapName = 25, openLevel = 2101, red = RedDotModule.Type.Union.Union, teamDialog = "newUnion/newUnionFrame"},
    --庄园
    {mapName = 26, openLevel = 9999, teamDialog = "Manor_Overview"},
    --副本
    {dialog = true, openLevel = 2201, dialogName = "newSelectMap/showAllBattle"},
    --英雄比拼
    {dialog = true, openLevel = 1911, dialogName = "PveArenaFrame", red = RedDotModule.Type.Arena.Arena},
    --伙伴
    {dialog = true, openLevel = 9999, dialogName = "Role_Frame", needScale = true, red = RedDotModule.Type.Hero.AllHero},
    --任务
    {dialog = true, prefStact = false, dialogName = "mapSceneUI/newQuestList"},
    --财力竞技场
    {dialog = true, openLevel = 1901, dialogName = "PvpArena_Frame", red = RedDotModule.Type.PVPArena.PVPArena},
    --邮件
    {dialog = true, openLevel = 1501, dialogName = "FriendSystemList", red = RedDotModule.Type.Mail.Mail,data = {idx = 3}},
    --系统
    {dialog = true, prefStact = false, dialogName = "SettingFrame"},
    --成就
    {dialog = true, openLevel = 2701, dialogName = "achievement/achievementFrame", red = RedDotModule.Type.Achievement.Achievement},
    --公会战
    {dialog = true, openLevel = 2105 , dialogName = "guild_pvp/GuildPVPJoinPanel"},
    --交易行
    {dialog = true, openLevel = 5002 , dialogName = "Trade_Dialog"},
    --排行榜
    {dialog = true,  dialogName = "rankList/rankListFrame"},
}

---战斗中出现的按钮
local FightingBtnInfo = {
    ---开服七天
    [2] = {
        ---双子星
        {dialogName = "mapSceneUI/guideLayer/guideFashion", openLevel = 5003, questId = module.guideLayerModule.Type.FashionLayer},
        ---陆游七
        {dialogName = "mapSceneUI/guideLayer/guideOnlineRewards", openLevel = 5007, canOpen = module.guideLayerModule.CheckOnline, redFunc = module.guideLayerModule.CheckOnline},
        ---肖斯塔亚
        {dialogName = "mapSceneUI/guideLayer/guideGetTitle", openLevel = 5004, questId = module.guideLayerModule.Type.Title},
        ---7日计划
        {dialogName = "SevenDaysActivity", canOpen = QuestModule.GetSevenDayOpen},
        ---拍卖行
        {dialogName = "Trade_Dialog", openLevel = 5002},
        ---排行
        {dialogName = "rankList/rankListFrame"},
    },
    [1] = {
        ---福利
        {dialogName = "welfareActivity", openLevel = 1301,red = RedDotModule.Type.WelfareActivity.WelfareActivity},
        ---商店
        {dialogName = "newShopFrame", openLevel = 2401},
        ---招募
        {dialogName = "DrawCardFrame", openLevel = 1801, red = RedDotModule.Type.DrawCard.DrawCardFree},
        ---活动
        {dialogName = "FriendSystemList", red = RedDotModule.Type.Mail.Mail, data = {idx = 3}},
    },
    [3] = {
        ---活动
        {dialogName = "mapSceneUI/newMapSceneActivity", openLevel = 1201, red = RedDotModule.Type.Activity.Activity},
        ---公会
        {dialogName = "newUnion/newUnionFrame", openLevel = 2101, red = RedDotModule.Type.Union.Union},
        ---组队
        {dialogName = "TeamFrame", openLevel = 1601, data = {idx = 1}},
        ---好友
        {dialogName = "FriendSystemList", openLevel = 2501, data = {idx = 2}},
        --
        -- ---基地
        -- {dialogName = "Manor_Overview", openLevel = 2001, red = RedDotModule.Type.Manor.Manor},
        --
        -- ---成就
        -- {dialogName = "achievement/achievementFrame", openLevel = 2701, red = RedDotModule.Type.Achievement.Achievement},
        -- ---邮件
        -- {dialogName = "FriendSystemList", red = RedDotModule.Type.Mail.Mail, data = {idx = 3}},
        -- ---设置
        -- {dialogName = "SettingFrame"},
    },
    [4] = {
        ---背包
        {dialogName = "ItemBag", openLevel = 2301},
        ---伙伴
        {dialogName = "Role_Frame", openLevel = 1101, red = RedDotModule.Type.Hero.AllHero},
        ---阵容
        {dialogName = "FormationDialog", openLevel = 9999},
        ---阵容
        {dialogName = "FormationDialog", openLevel = 9999},
    },
}

local function getMailIdx()
    local _status, _idx = RedDotModule.CheckModlue:checkMailAndAward()
    if _idx then
        return {idx = _idx}
    end
    return {idx = 3}
end

local MapSceneTopBtn = {
    ---零号计划
    {dialog = "mapSceneUI/guideLayer/zeroPlan", openLevel = 5008, red = RedDotModule.Type.MapSceneUI.ZeroPlan},
    ---福利
    {dialog = "welfareActivity", openLevel = 1301, red = RedDotModule.Type.WelfareActivity.WelfareActivity},
    ---每日任务
    {dialog = "mapSceneUI/dailyTask", openLevel = 3201, red = RedDotModule.Type.MapSceneUI.DailyTask},
    ---七日
    {dialog = "SevenDaysActivity", openLevel = 1312, red = RedDotModule.Type.SevenDays.SevenDays},
    ---幸运币
    {dialog = "award/luckyRollToggle", openLevel = 1331, data = {idx = 2}},
}

---大地图 下方角按钮栏
local MapSceneBottomBtn = {
    ---好友
    {dialog = "MapTransfer", red = RedDotModule.Type.MapSceneUI.Map},
    ---背包
    {dialog = "ItemBag", openLevel = 2301},
    ---商店
    {mapName = 26, teamDialog = "Manor_Overview"},
    ---伙伴
    {dialog = "Role_Frame"},
    ---活动
    {dialog = "mapSceneUI/newMapSceneActivity", openLevel = 1201, red = RedDotModule.Type.Activity.Activity},
    ---副本
    {dialog = "newSelectMap/selectMap", openLevel = 2201},
}

---大地图上方展开列表
local MapSceneTopListBtn = {
    ---购买体力
    {dialog = "newShopFrame", openLevel = 2401},
    ---查看成就
    {dialog = "achievement/achievementFrame", openLevel = 2701},
    ---更换形象
    {dialog = "mapSceneUI/newPlayerInfoFrame", openLevel = 2701},
    ---设置
    {dialog = "SettingFrame", openLevel = 2701},
}

local MapSceneBottomMap = {
    ---伙伴
    {dialog = "Role_Frame", openLevel = 1101, red = RedDotModule.Type.Hero.AllHero},
    ---阵容
    {dialog = "FormationDialog", openLevel = 1701},
}

local MapSceneBottomShop = {
    ---抽卡
    {dialog = "DrawCardFrame", openLevel = 1801, red = RedDotModule.Type.DrawCard.DrawCardFree},
    ---商店
    {dialog = "newShopFrame", openLevel = 2401},
    ---拍卖行
    {dialog = "Trade_Dialog", openLevel = 5002},
}

local MapSceneBottomCompetition = {
    {dialog = "traditionalArena/traditionalArenaFrame", openLevel = 1902},
    {dialog = "PveArenaFrame", openLevel = 1911, red = RedDotModule.Type.Arena.Arena},
    {dialog = "trial/trialTower", openLevel = 3101},
    {dialog = "guild_pvp/GuildPVPJoinPanel", openLevel = 2105},
    {dialog = "PvpArena_Frame", openLevel = 1901, red = RedDotModule.Type.PVPArena.PVPArena},
}

local MapSceneBottomLeaveNode = {
    --公会
    {mapName = 25, openLevel = 2101, red = RedDotModule.Type.Union.Union, teamDialog = "newUnion/newUnionFrame"},
    --庄园
    {mapName = 26, openLevel = 2001, teamDialog = "Manor_Overview", red = RedDotModule.Type.Manor.Quest},
}

---大地图 左边按钮栏
local MapSceneLeftBtn = {
    {dialog = "mapSceneUI/newMapSceneActivity", openLevel = 1201, red = RedDotModule.Type.Activity.Activity},
    {dialog = "newUnion/newUnionFrame", openLevel = 2101, red = RedDotModule.Type.Union.Union},
    {dialog = "TeamFrame", openLevel = 1601, data = {idx = 1}, red = RedDotModule.Type.MainUITeam.TeamJoinRequest},
    {dialog = "FriendSystemList", openLevel = 2501, data = {idx = 2}, red = RedDotModule.Type.Mail.Friend},
}

return {
    MapSceneBtnInfo = MapSceneBtnInfo,
    FightingBtnInfo = FightingBtnInfo,
    MapSceneBottomBtn = MapSceneBottomBtn,
    MapSceneLeftBtn = MapSceneLeftBtn,
    MapSceneTopBtn = MapSceneTopBtn,
    MapSceneTopListBtn = MapSceneTopListBtn,
    MapSceneBottomMap = MapSceneBottomMap,
    MapSceneBottomCompetition = MapSceneBottomCompetition,
    MapSceneBottomShop = MapSceneBottomShop,
    MapSceneBottomLeaveNode = MapSceneBottomLeaveNode,
}
