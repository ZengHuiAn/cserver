local cfgType = {
    Build = 1,
}

local titleType = {
    Activity = 1,
    Task = 2,
    Team = 3,
}

local activityActiveTab = nil
local function activeCfg(gid)
    activityActiveTab = activityActiveTab or LoadDatabaseWithKey("huoyuedu", "gid") or {}
    return activityActiveTab[gid]
end

local activityCfgTab = nil
local activityCfgByCategory=nil
local activityCfgByQuest = nil;
local activityGroup = nil
local function activityCfg(id)
    if not activityCfgTab then
        activityCfgTab ={}
        activityCfgByCategory={}
        activityCfgByQuest = {}
        activityGroup = {}
        DATABASE.ForEach("all_activity", function(data)
            activityCfgTab[data.id]=data
            activityCfgByCategory[data.category]=activityCfgByCategory[data.category] or {}
            table.insert(activityCfgByCategory[data.category],data)
            if data.related_quest_id and data.related_quest_id ~= 0 then
                activityCfgByQuest[data.related_quest_id] = data;
            end
            if data.activity_group and data.activity_group ~= 0 then
                activityGroup[data.activity_group] = activityGroup[data.activity_group] or {}
                table.insert(activityGroup[data.activity_group], data)
            end
        end);
    end
    if not id then return activityCfgTab end
    return activityCfgTab[id]
end

local function GetCfgByGroup(groupId)
    if not activityGroup then
        activityCfg()
    end
    return activityGroup[groupId]
end

local function GetActivityCfgByCategory(Category)
    if not activityCfgByCategory then
        activityCfg()
    end
    return activityCfgByCategory[Category]
end

local function GetActivityCfgByQuest(quest_id)
    local t = activityCfgByQuest[quest_id] or {}
    return t.id;
end

local activityTitleTab = nil
local function getActivityTitle(type, titileId, id)
    if not activityCfgTab then
        activityCfg()
    end
    if not activityTitleTab then
        activityTitleTab = {}
        for k,v in pairs(activityCfgTab) do
            for i = 1, 4 do
                if v["up_tittle"..i] > -1 then
                    if not activityTitleTab[i] then activityTitleTab[i] = {} end
                    if not activityTitleTab[i][v["up_tittle"..i]] then activityTitleTab[i][v["up_tittle"..i]] = {} end
                    table.insert(activityTitleTab[i][v["up_tittle"..i]], v)
                end
            end
        end
    end
    if not titileId then
        return activityTitleTab[type]
    end
    if not id then
        return activityTitleTab[type][titileId]
    end
    return activityTitleTab[type][titileId][id]
end

local activityRewardTab = nil
local function getActivityReward(id)
    if not activityCfgTab then
        activityCfg()
    end
    if not activityRewardTab then
        activityRewardTab = {}
        for k,v in pairs(activityCfgTab) do
            for i = 1, 3 do
                local _temp = {}
                _temp.type = v["reward_type"..i]
                _temp.id = v["reward_id"..i]
                if _temp.id ~= 0 and _temp.type ~= 0 then
                    if not activityRewardTab[k] then activityRewardTab[k] = {} end
                    table.insert(activityRewardTab[k], _temp)
                end
            end
        end
    end
    if not id then return {} end
    return activityRewardTab[id]
end

local allTitle = nil
local function getBaseTittleByType(showType)
    if allTitle == nil then
        allTitle = {}
        DATABASE.ForEach("all_tittle", function(row)
            if row.up_tittle == 0 then
                if not allTitle[row.show] then allTitle[row.show] = {} end
                if not allTitle[row.show][row.id] then allTitle[row.show][row.id] = {} end
                allTitle[row.show][row.id] = row
            else
                print(row.show, row.up_tittle, allTitle[row.show][row.up_tittle])
            end
        end)
    end
    return allTitle[showType]
end

local activitylist = nil
local function GetActivitylist()
    if activitylist == nil then
        activitylist = {}
        DATABASE.ForEach("all_tittle", function(row)
            if row.show == 3 then
                activitylist[row.id] = {id = row.id,TitleData = row,IsTittle = true,ChildNode = {}}
            end
        end);

        DATABASE.ForEach("all_activity", function(row)
            if row.up_tittle3 > -1 then
                if row.up_tittle3 == 0 then
                    activitylist[row.id] = {id = row.id,TitleData = row,IsTittle = false,ChildNode = {}}
                else
                    activitylist[row.up_tittle3].ChildNode[#activitylist[row.up_tittle3].ChildNode + 1] = row
                end
            end
        end)
    end
    return activitylist
end

local all_activity = nil
local function Get_all_activity(id)
    all_activity = all_activity or LoadDatabaseWithKey("all_activity", "id") or {}
    return all_activity[id]
end

local function getFinishCount(_tab, _quest)
    local _finishCount = 0
    if _tab.id == 4 then
        local _list = module.CemeteryModule.GetTeamPveFightList(1)
        if _list and _list.count then
            _finishCount = _list.count
        end
    elseif _tab.id == 5 then
        local _list = module.CemeteryModule.GetTeamPveFightList(2)
        if _list and _list.count then
            _finishCount = _list.count
        end
    elseif _tab.id == 7 then
        if module.answerModule.GetWeekCount() then
            _finishCount = module.answerModule.GetWeekCount()
        end
    else
        if _tab.huoyuedu ~= 0 and _quest then
            _finishCount = _quest.finishCount
        end
    end
    return _finishCount
end

local function getActiveCount(_tab, _quest, _finishCount)
    local _active = 0
    if _quest then
        if _tab.id then
            if _quest.reward_value1 then
                _active = _finishCount * _quest.reward_value1
            else
                ERROR_LOG("reward_value1 nil")
            end
        end
    end
    return _active
end

local function GetActiveCountById(id)
    local _tab = activityCfg(id)
    if not _tab then
        return 0, 0
    end
    local _quest = module.QuestModule.Get(_tab.huoyuedu)
    local _finishCount = getFinishCount(_tab, _quest)
    local _active = getActiveCount(_tab, _quest, _finishCount)
    return {count = _active,
            maxCount = _tab.vatality,
            finishCount = _finishCount,
            joinLimit = _tab.join_limit}
end

local function CheckActivityOpen(id)
    local _cfg = activityCfg(id)
    if not _cfg then
        return false
    end
    if _cfg.begin_time >= 0 and _cfg.end_time >= 0 and _cfg.period >= 0 then
        local total_pass = module.Time.now() - _cfg.begin_time
        local period_pass = total_pass - math.floor(total_pass / _cfg.period) * _cfg.period
        local period_begin = module.Time.now() - period_pass
        if (module.Time.now() > period_begin and module.Time.now() < (period_begin + _cfg.loop_duration)) then
            return true
        end
    end
    return false
end

local _smallTeamDungeonConf = require "config.SmallTeamDungeonConf"
local _battle = require "config.battle"
local function loadFightCfg(cfg)
    if cfg then
        local _fightCfg = _smallTeamDungeonConf.GetTeamPveMonsterList(cfg.fight_id)
        cfg.squad = {}
        for k,v in pairs(_fightCfg) do
            table.insert(cfg.squad, {roleId = v.role_id, level = v.role_lev,pos=v.role_pos})
        end
	end
	return cfg
end

local activityMonsterCfg = nil
local function GetActivityMonsterCfg(monsterId)
    if not activityMonsterCfg then
        activityMonsterCfg = {raw = LoadDatabaseWithKey("activity_monster", "npc")}

        setmetatable(activityMonsterCfg, {__index = function(t, k)
            local _cfg = t.raw[k]
            if _cfg then
                rawset(t, k, loadFightCfg(_cfg))
            end
            return _cfg
        end})
    end
    if monsterId then
        return activityMonsterCfg[monsterId]
    else
        return activityMonsterCfg
    end
end

--建设城市
local cityBuildingCfg=nil
local monsterGroup=nil
local function GetCityBuildingCfg(type,dcity_lv)
    if not cityBuildingCfg then
        cityBuildingCfg ={}
        monsterGroup={}
        local _cityBuildingCfg={}
        DATABASE.ForEach("activity_buildcity", function(data)
            _cityBuildingCfg[data.type]=_cityBuildingCfg[data.type] or {}  
            _cityBuildingCfg[data.type][data.dcity_lv]=data

            monsterGroup[data.npc_id]=data
        end)

        local max=0
        for _k,_v in pairs(_cityBuildingCfg) do
            local _budileCfg = {}
            local _cfg = {}
            for k,v in pairs(_v) do
                _budileCfg[k]={squad=loadFightCfg(v).squad,dcity_lv =v.dcity_lv,dcity_exp =v.dcity_exp,fight_id=v.fight_id}
                _cfg ={ 
                        npc_id=v.npc_id,
                        describe=v.describe,
                        picture=v.picture,
                        quest_npc=v.quest_npc,
                        quest_id=v.quest_id,
                    }
            end
            cityBuildingCfg[_k] = {cfg=_budileCfg,npc_id=_cfg.npc_id,describe=_cfg.describe,picture=_cfg.picture,quest_npc=_cfg.quest_npc,quest_id=_cfg.quest_id}
        end
    end
    if type then
        return cityBuildingCfg[type]
    else
        return cityBuildingCfg
    end
end
local function GetMonsterGroup(monstId)
    if not monsterGroup then
        GetCityBuildingCfg()
    end
    if monstId then
        return monsterGroup[monstId]
    else
        return monsterGroup
    end
end

return {
        TitleType = titleType,
        GetActivity = activityCfg,
        GetReward = getActivityReward,
        ActiveCfg = activeCfg,                      --活跃度配置
        GetBaseTittleByType = getBaseTittleByType,
        GetAllActivityTitle = getActivityTitle,
        GetCfgByGroup = GetCfgByGroup,
        GetActivityMonsterCfg = GetActivityMonsterCfg,

        GetActivitylist = GetActivitylist,
        GetActivityCfgByCategory=GetActivityCfgByCategory,
        GetActivityCfgByQuest=GetActivityCfgByQuest,
        Get_all_activity = Get_all_activity,
        GetActiveCountById = GetActiveCountById,
        CheckActivityOpen = CheckActivityOpen,

        GetCityBuildingCfg=GetCityBuildingCfg,
        GetMonsterGroup=GetMonsterGroup,
}
