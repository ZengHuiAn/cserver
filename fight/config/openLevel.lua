local openLevelCfg = nil
local function GetCfg(id)
    if not openLevelCfg then
        openLevelCfg = LoadDatabaseWithKey("openlev", "id")
    end
    if id then
        return openLevelCfg[id]
    end
    return openLevelCfg
end

local openLevelConfigByLevel
local function loadopenlev()
    local data_list = {};
    openLevelConfigByLevel={}
    local _openLevelConfigByLevel={}
    local level=1

    DATABASE.ForEach("openlev", function(data)
        table.insert(data_list, data);
        if data.isshow_levup==1 then
            _openLevelConfigByLevel[data.open_lev]=_openLevelConfigByLevel[data.open_lev] or {}
            table.insert(_openLevelConfigByLevel[data.open_lev],data)
        end
    end)

    local maxValue=999
    for i=maxValue,1,-1 do
        if _openLevelConfigByLevel[i] then
            maxValue=i
            break
        end
    end

    for i=1,maxValue do
        openLevelConfigByLevel[i]=openLevelConfigByLevel[i] or {}
        for j=i,maxValue do
            if _openLevelConfigByLevel[j] then
                for _k=1,#_openLevelConfigByLevel[j] do
                    table.insert(openLevelConfigByLevel[i],_openLevelConfigByLevel[j][_k])
                end
            end
        end
    end
    return data_list;
end
local function GetOpenLvCfgByLevel(level)
    if not  openLevelConfigByLevel then
        loadopenlev()
    end
    return openLevelConfigByLevel[level] or {}
end

local function getCfgTab(from, to)
    GetCfg()
    local _tempTab = {}
    for i = from, to do
        if GetCfg(i) then
            table.insert(_tempTab, GetCfg(i))
        end
    end
    return _tempTab
end

local eqSuitsCfg = nil
local function GetEqSuitsCfg(id)
    if not eqSuitsCfg then
        eqSuitsCfg = getCfgTab(1181, 1185)
    end
    return eqSuitsCfg[id]
end

local inSuitsCfg = nil
local function GetInSuitsCfg(id)
    if not inSuitsCfg then
        inSuitsCfg = getCfgTab(1191, 1195)
    end
    return inSuitsCfg[id]
end

local rewardList = {}
utils.EventManager.getInstance():addListener("TEAM_QUERY_NPC_REWARD_REQUEST", function(event, data)
    rewardList = data.reward_content or {}
end)

local function checkEvent(cfg)
    local _staus=true
    local _event
    for i = 1, 1 do
        _event = cfg["event_id"..i]
        if cfg["event_type"..i] == 1 then
            if cfg["event_id"..i] ~= 0 then
                local _quest = module.QuestModule.Get(cfg["event_id"..i])
                if _quest then
                    _staus = _quest.status == 1
                else
                    _staus = false
                end
                local _questId = cfg["event_id"..i]
                local _questCfg = module.QuestModule.GetCfg(_questId)
                if _questCfg then
                    _event = SGK.Localize:getInstance():getValue("tips_wanchengrenwu_01", _questCfg.name)
                end
            end
        elseif cfg["event_type"..i] == 2 then
            if cfg["event_id"..i] ~= 0 then
                if cfg["event_id"..i] > (module.playerModule.Get().starPoint or 0) then
                    _staus = false
                end
            end
        elseif cfg["event_type"..i] == 3 then
            local _openLevel = require "config.openLevel"
            return module.QuestModule.GetSevenDayOpen() and _openLevel.GetStatus(1311)
        elseif cfg["event_type"..i] == 4 then
            return #rewardList > 0
        end
    end

    return _staus,_event
end

local openList = {}
local function checkStatus(id, status)
    if status then
        if not openList[id] then
            openList[id] = true
            local _index = nil
            if id == 2101 then --公会
                _index = 3
            elseif id == 2501 then  --好友
                _index = 2
            elseif id == 1601 then --组队
                _index = 1
            end
            if _index then
                utils.PlayerInfoHelper.GetPlayerAddData(nil, 7, function(data)
                    utils.PlayerInfoHelper.SetActivityStatus(7, _index, 1)
                end)
            end
            if id ==1901 then--PvpJJC
                utils.PlayerInfoHelper.ChangePvpArenaStatus(module.ItemModule.GetItemCount(90033) > 0)
            end
        end
    end
    return status
end

local function GetStatus(id, heroLevel)
    if module.playerModule.Get() and module.playerModule.Get().honor == 9999 then
        return true
    else
        local _cfg = GetCfg(id)
        if _cfg then
            local _hero = module.HeroModule.GetManager():Get(11000) or {level = 0}
            local _level = _hero.level
            if heroLevel then
                _level = heroLevel
            end
            return checkStatus(id, _level >= _cfg.open_lev and checkEvent(_cfg))
        end
        return false
    end
end

local function GetCloseInfo(id, heroLevel)
    local _cfg = GetCfg(id)
    if _cfg then
        local _hero = module.HeroModule.GetManager():Get(11000) or {level = 0}
        local _level = _hero.level
        if heroLevel then
            _level = heroLevel
        end
        if _level < _cfg.open_lev then
            return SGK.Localize:getInstance():getValue("tips_lv_02", _cfg.open_lev)
        end
        for i = 1, 1 do
            if _cfg["event_type"..i] == 1 then
                if _cfg["event_id"..i] ~= 0 then
                    local _quest = module.QuestModule.GetCfg(_cfg["event_id"..i])
                    if _quest then
                        return SGK.Localize:getInstance():getValue("tips_wanchengrenwu_01", _quest.name)
                    end
                end
            end
        end
    end
    return ""
end

local equipSuitsOpenLevel = nil
local equipOpenLevel = nil
local function loadEquipOpenLevel()
    if not equipSuitsOpenLevel then
        equipSuitsOpenLevel = getCfgTab(1181, 1185)
    end
    if not equipOpenLevel then
        equipOpenLevel = {}
        --第0套
        local _insc = getCfgTab(1143, 1148)
        for i,v in ipairs(_insc) do
            table.insert(equipOpenLevel, v)
        end
        local _equip = getCfgTab(1124, 1129)
        for i,v in ipairs(_equip) do
            table.insert(equipOpenLevel, v)
        end
        --第1套
        local _insc1 = getCfgTab(6201, 6206)
        for i,v in ipairs(_insc1) do
            table.insert(equipOpenLevel, v)
        end
        local _equip1 = getCfgTab(6101, 6106)
        for i,v in ipairs(_equip1) do
            table.insert(equipOpenLevel, v)
        end
        --第2套
        local _insc2 = getCfgTab(6207, 6212)
        for i,v in ipairs(_insc2) do
            table.insert(equipOpenLevel, v)
        end
        local _equip2 = getCfgTab(6107, 6112)
        for i,v in ipairs(_equip2) do
            table.insert(equipOpenLevel, v)
        end

    end
end

local function GetEquipOpenLevel(suits, place)
    local suits = suits or 0
    loadEquipOpenLevel()
    if suits and suits > 0 then
        local _suitsCfg = equipSuitsOpenLevel[suits]
        if place and place < 7 then
            _suitsCfg = GetInSuitsCfg(suits)
        end
        if _suitsCfg then
            if _suitsCfg.open_lev > module.HeroModule.GetManager():Get(11000).level then
                return false, SGK.Localize:getInstance():getValue("tips_lv_02", _suitsCfg.open_lev)
            end
        else
            return false, SGK.Localize:getInstance():getValue("tips_lv_02", _suitsCfg.open_lev)
        end
    end
    -- if place then
    --     if equipOpenLevel[place] then
    --         if equipOpenLevel[place].open_lev > module.HeroModule.GetManager():Get(11000).level then
    --             return false,equipOpenLevel[place].open_lev
    --         else
    --             return true,equipOpenLevel[place].open_lev
    --         end
    --     end
    -- end
    if place then
        --每套套装对应 Idx 差 12
        local _place = suits*12 +place
        if equipOpenLevel[_place] then
            local _status,_event = checkEvent(equipOpenLevel[_place])
            return _status,_event
        end
    end
end

return {
    GetCfg = GetCfg,
    GetEqSuitsCfg = GetEqSuitsCfg,
    GetInSuitsCfg = GetInSuitsCfg,
    GetStatus = GetStatus,
    GetEquipOpenLevel = GetEquipOpenLevel,
    GetOpenLvCfgByLevel=GetOpenLvCfgByLevel,
    GetCloseInfo = GetCloseInfo,
}
