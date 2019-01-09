local timeModule = require "module.Time"
local UserDefault = require "utils.UserDefault"
local numberTab = nil
local function getNumber(level)
    if numberTab == nil then
        numberTab = LoadDatabaseWithKey("team_number", "TeamLevel")
    end
    if level ~= nil then
        return numberTab[level]
    else
        return numberTab
    end
end

local competenceTab = nil
local function getCompetence(jobCode)
    if competenceTab == nil then
        competenceTab = LoadDatabaseWithKey("team_competence", "JobCode")
    end
    if jobCode ~= nil then
        return competenceTab[jobCode]
    else
        return competenceTab
    end
end

local unionActivityCfg = nil
local function GetActivity(id)
    if not unionActivityCfg then
        unionActivityCfg = LoadDatabaseWithKey("guild_activity", "id")
    end
    if id then
        return unionActivityCfg[id]
    end
    return unionActivityCfg
end

local donateTab = nil
local function getDonate(donateType)
    if donateTab == nil then
        donateTab = LoadDatabaseWithKey("team_donate", "DonateType")
    end
    if donateType ~= nil then
        return donateTab[donateType]
    else
        return donateTab
    end
end

local unionAward = nil
local function getAward()
    if unionAward == nil then
        unionAward = DATABASE.Load("team_summary")[1]
    end
    return unionAward
end

local teamFortune = nil
local tortuneTab = nil
local function getTeamFortune()
    if not teamFortune then
        teamFortune = {}
        DATABASE.ForEach("team_fortune", function(_row)
            if not teamFortune.suitable then teamFortune.suitable = {} end
            if not teamFortune.taboo then teamFortune.taboo = {} end
            table.insert(teamFortune.suitable, _row.Suitable1)
            table.insert(teamFortune.taboo, _row.Taboo)
        end)
    end
    if not tortuneTab then
        tortuneTab = {}
        local _nowDay = timeModule.day()
        local _day = UserDefault.Load("unionFortune", true).day or 0
        local _rand = 1
        local _tabooRand = 1
        local _star = 1
        if _day == _nowDay and UserDefault.Load("unionFortune", true).rand then
            _rand = UserDefault.Load("unionFortune", true).rand
            _tabooRand = UserDefault.Load("unionFortune", true).tabooRand
            _star = UserDefault.Load("unionFortune", true).star
        else
            math.randomseed(os.time())
            _rand = math.random(1, #teamFortune.suitable)
            _tabooRand = math.random(1, #teamFortune.taboo)
            _star = math.random(1, 5)
            UserDefault.Load("unionFortune", true).rand = _rand
            UserDefault.Load("unionFortune", true).tabooRand = _tabooRand
            UserDefault.Load("unionFortune", true).star = _star
            UserDefault.Load("unionFortune", true).day = _nowDay
        end
        local _suitable = teamFortune.suitable[_rand]
        local _taboo = teamFortune.taboo[_tabooRand]
        tortuneTab.star = _star
        tortuneTab.suitable = _suitable
        tortuneTab.taboo = _taboo
    end
    return tortuneTab
end

local teamAward = nil
local function getTeamAward(index, level)
    if teamAward == nil then
        teamAward = {}
        DATABASE.ForEach("team_award", function(_row)
            if _row.award_type == 1 then
                if teamAward[_row.team_level] == nil then
                    teamAward[_row.team_level] = {}
                end
                teamAward[_row.team_level][_row.sort] = _row
            end
        end)
    end
    if index and level then
        if teamAward[level] then
            return teamAward[level][index]
        else
            return {}
        end
    else
        return {}
    end
end

local exploremapMessage = nil
local exploremapIdTab = nil
local function loadExploremapMessage()
    if not exploremapMessage then
        exploremapMessage = {}
        exploremapIdTab = {}
        DATABASE.ForEach("exploremap_message", function(_row)
            local _tempTab = {}
            _tempTab.mapId = _row.Mapid
            _tempTab.name = _row.name
            _tempTab.picture = _row.picture
            _tempTab.mapDes = _row.map_des
            _tempTab.mapType = _row.map_type
            _tempTab.favorable = BIT(_row.Map_property1)
            _tempTab.restraint = BIT(_row.Map_property2)
            _tempTab.bgMap = _row.bg_map
            _tempTab.teamLevel = _row.team_level
            _tempTab.reward = {}
            for i = 1, 3 do
                local _rewardTab = {}
                _rewardTab.type = _row["Type"..i]
                _rewardTab.id = _row["Item_id"..i]
                _rewardTab.valude = 0
                table.insert(_tempTab.reward, _rewardTab)
            end
            exploremapMessage[_row.Mapid] = _tempTab
            if _tempTab.mapType == 1 then
                table.insert(exploremapIdTab, _tempTab)
            end
        end)
    end
end

local function getExploremapMessage(id)
    loadExploremapMessage()
    local _cfgTab = {}
    for i,v in ipairs(exploremapMessage) do
        if v.teamLevel <= module.unionModule.Manage:GetSelfUnion().unionLevel then
            table.insert(_cfgTab, v)
        end
    end
    if not id then
        return _cfgTab
    end
    return _cfgTab[id] or {}
end

local function getAllExploremapMessage(id)
    if not id then
        return exploremapMessage
    end
    return exploremapMessage[id]
end

local elementCfgTab = nil
local function getElement(id)
    if not elementCfgTab then
        elementCfgTab = LoadDatabaseWithKey("yuansu", "Id")
    end
    return elementCfgTab[id]
end

local teamAccident = nil
local function getTeamAccident(eventId)
    if not teamAccident then
        teamAccident = LoadDatabaseWithKey("team_accident", "id")
    end
    return teamAccident[eventId]
end

local exploreTalkingTab = nil
local exploreTalkingTabById = nil
local function loadExploreTalking()
    if not exploreTalkingTab then
        exploreTalkingTab = {}
        exploreTalkingTabById = {}
        DATABASE.ForEach("explore_talking", function(_row)
            if not exploreTalkingTab[_row.map_id] then exploreTalkingTab[_row.map_id] = {} end
            if not exploreTalkingTab[_row.map_id][_row.role_id] then exploreTalkingTab[_row.map_id][_row.role_id] = {} end
            table.insert(exploreTalkingTab[_row.map_id][_row.role_id], _row)
            exploreTalkingTabById[_row.id] = _row
        end)
    end
end

local function GetExploreTalkingTabById(id)
    loadExploreTalking()
    return exploreTalkingTabById[id]
end

local function GetExploreTalking(mapId, heroTab)
    loadExploreTalking()
    local _mapCfg = exploreTalkingTab[mapId]
    local _talkTab = {}
    local _allTalkTab = {}
    local _heroTabHash = {}
    for i,v in ipairs(heroTab) do
        _heroTabHash[v] = true
    end
    if _mapCfg then
        for k,v in ipairs(heroTab) do
            if _mapCfg[v] then
                for i,p in ipairs(_mapCfg[v]) do
                    if p.condition == "0" then
                        table.insert(_talkTab, p)
                    else
                        if p.next_id ~= 0 then
                            local unitPlace = math.floor(p.id / 1 % 10)
                            local tenPlace = math.floor(p.id / 10 % 10)
                            if unitPlace == 1 and tenPlace == 0 then
                                local _tab = StringSplit(p.condition, "|")
                                local _flag = 0
                                if _tab and #_tab > 0 then
                                    for i,v in ipairs(_tab) do
                                        if _heroTabHash[tonumber(v)] then
                                            _flag = _flag + 1
                                        end
                                    end
                                    if _flag == #_tab then
                                        table.insert(_allTalkTab, p)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    local _randomType = math.random(1, 100)
    if _randomType <= 20 then
        if #_allTalkTab >= 1 then
            return _allTalkTab[math.random(1, #_allTalkTab)], true
        end
    end
    return _talkTab[math.random(1, #_talkTab)], false
end

return {
    GetNumber = getNumber,
    GetCompetence = getCompetence,
    GetDonate = getDonate,
    GetAward = getAward,
    GetTeamAward = getTeamAward,
    GetTeamFortune = getTeamFortune,
    GetExploremapMessage = getExploremapMessage,
    GetAllExploremapMessage = getAllExploremapMessage,
    GetElement = getElement,
    GetTeamAccident = getTeamAccident,
    GetExploreTalking = GetExploreTalking,
    GetExploreTalkingTabById = GetExploreTalkingTabById,
    GetActivity = GetActivity,
}
