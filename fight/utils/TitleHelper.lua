local PlayerInfoHelper = require "utils.PlayerInfoHelper"
local TitleModule=require "module.titleModule"
local openLevel = require "config.openLevel"

local TitleQuestType=60
local followTitle=0
local HeroId=0

utils.EventManager.getInstance():addListener("PLAYER_ADDDATA_CHANGE", function(event,pid,data)
    --变化的为玩家自己，并且有 变化才刷新
    if pid==module.playerModule.GetSelfID() and next(data)~=nil then
        if openLevel.GetStatus(1102) then
            UpdateFollowStatus()
        end
    end
end)

local lastChangeTime=0
utils.EventManager.getInstance():addListener("QUEST_INFO_CHANGE", function(event, data,status)
    if not status then
        SGK.Action.DelayTime.Create(0.5):OnComplete(function()
            if openLevel.GetStatus(1102) then
                UpdateFollowStatus()--每次任务变化都刷新
            end
        end)
    end
end)

function UpdateFollowStatus()
    local _TitleQuestList=module.QuestModule.GetList(TitleQuestType,0)--进行中称号任务
    if #_TitleQuestList>0 then--有接到的称号任务
        PlayerInfoHelper.GetPlayerAddData(0,6,function (addData)   
            followTitle=addData.FollowTitleId
            HeroId=addData.FollowHero
            --ERROR_LOG(followTitle,HeroId)

            if HeroId==0 then--未设置过，称号追踪，默认追踪陆水银正在进行的任务
                local _followHeroId=11000--默认称号陆水银
                local roleTitles=TitleModule.GetRoleTitleCfg(_followHeroId)
                --ERROR_LOG(sprinttb(roleTitles))

                local _canFollowTitleId=nil
                for i=1,#roleTitles.titleIds do--陆水银所有称号
                    local titleId=roleTitles.titleIds[i]
                    local titleCfg=TitleModule.GetCfg(titleId)
                    if titleCfg then
                        local ItemCount=module.ItemModule.GetItemCount(titleCfg.itemID)
                        if ItemCount<1 then--未获得的称号
                            --ERROR_LOG("未获得的称号",titleCfg.name)
                            for j=#titleCfg.conditions,1,-1 do--称号的所有条件
                                if not _canFollowTitleId then
                                    local ConditionId=titleCfg.conditions[j]
                                    local funcTab=TitleModule.GetConditionCfg(ConditionId)
                                    -- print(ConditionId)
                                    if funcTab then--该条件对应的任务链
                                        for _i=1,#funcTab do
                                            local _quest = module.QuestModule.Get(funcTab[_i])
                                            if _quest and _quest.status ==0 then--该条件下正在进行的任务
                                                print("设置追踪",titleId,_followHeroId)
                                                _canFollowTitleId=titleId
                                                PlayerInfoHelper.ChangeFollowTitle(titleId,_followHeroId)--设置追踪称号为陆水银
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        if _canFollowTitleId then
                            break
                        end
                    else
                        ERROR_LOG("称号配置不存在==>>",titleId)
                    end
                    if _canFollowTitleId then
                        break
                    end
                end                  
            elseif HeroId~=0 then--追踪过
                --ERROR_LOG("--追踪过")
                if followTitle~=0 then--有正在追踪的称号
                    --ERROR_LOG("正在追踪的称号",followTitle)
                    local titleCfg=TitleModule.GetCfg(followTitle)
                    if titleCfg then
                        local ItemCount=module.ItemModule.GetItemCount(titleCfg.itemID)
                        if ItemCount<1 then--称号未获得
                            --ERROR_LOG("称号未获得",titleCfg.name)
                            for i=#titleCfg.conditions,1,-1 do
                                local ConditionId=titleCfg.conditions[i]
                                local funcTab=TitleModule.GetConditionCfg(ConditionId)
                                if funcTab then--将未获得称号的任务 设为可见
                                    for j=1,#funcTab do
                                        local _quest = module.QuestModule.Get(funcTab[j])
                                        if _quest and _quest.status ==0 then  
                                            if _quest.is_show_on_task==1 then--0为可见,1为不可见
                                                _quest.is_show_on_task=0
                                                --用以区分任务变化引起的INFO_CHANGE,只在21行使用
                                                local DonUpdateFollowStatus=true
                                                utils.EventManager.getInstance():dispatch("QUEST_INFO_CHANGE",_quest,DonUpdateFollowStatus);
                                                --ERROR_LOG("设置正在追踪称号的可进行任务为可见")
                                            end
                                            --break
                                        end
                                    end
                                end
                            end
                        else--如果追踪的称号已完成,遍历该角色的所有称号
                            --ERROR_LOG("追踪的称号已完成")
                            local _followHeroId=HeroId
                            local roleTitles=TitleModule.GetRoleTitleCfg(_followHeroId)
                            local AllGetTed=true
                            local _canFollowTitleId=nil
                            if not _canFollowTitleId then
                                for i=1,#roleTitles.titleIds do--将该角色正在进行中的称号设为追踪称号
                                    local titleId=roleTitles.titleIds[i]
                                    local titleCfg=TitleModule.GetCfg(titleId)
                                    local ItemCount=module.ItemModule.GetItemCount(titleCfg.itemID)
                                    if ItemCount<1 then
                                        --ERROR_LOG("未获得的称号",titleCfg.name)
                                        for j=#titleCfg.conditions,1,-1 do
                                            if not _canFollowTitleId then
                                                local ConditionId=titleCfg.conditions[j]
                                                local funcTab=TitleModule.GetConditionCfg(ConditionId)
                                                if funcTab then
                                                    for _i=1,#funcTab do
                                                        local _quest = module.QuestModule.Get(funcTab[_i])
                                                        if _quest and _quest.status ==0 then
                                                            --ERROR_LOG("开始追踪的称号",titleCfg.name)
                                                            AllGetTed=false
                                                            _canFollowTitleId=titleId
                                                            PlayerInfoHelper.ChangeFollowTitle(titleId,HeroId)--设置追踪称号为陆水银
                                                            break
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    if _canFollowTitleId then
                                        break
                                    end
                                end
                            end
                          
                            if AllGetTed then--如果该角色的所有能完成的称号,寻找品质最高的进行中任务
                                --ERROR_LOG("切换角色")
                                local _questList=module.QuestModule.GetList(TitleQuestType,0)--称号任务
                                local goingQuestTab={}
                                for i=1,#_questList do
                                    goingQuestTab[_questList[i].id]=true
                                end

                                local AllTitleTab=TitleModule.GetCfg()--获取所有的称号
                                table.sort(AllTitleTab, function(a, b)--称号品质从高到低排
                                    if a.quality ~= b.quality then
                                        return a.quality > b.quality
                                    end
                                    return a.gid<b.gid
                                end)
                                local _canFollowTitleId=nil
                                if not _canFollowTitleId then
                                    for k,v in pairs(AllTitleTab) do
                                        local _titleCfg=v
                                        local ItemCount=module.ItemModule.GetItemCount(_titleCfg.itemID)
                                        if ItemCount<1 then
                                            for i=#_titleCfg.conditions,1,-1 do
                                                local ConditionId=_titleCfg.conditions[i]
                                                local funcTab=TitleModule.GetConditionCfg(ConditionId)
                                                if funcTab then
                                                    for _i=1,#funcTab do
                                                        if goingQuestTab[funcTab[_i]] then--查找品质最高的进行中任务

                                                            local owners=TitleModule.GetTitleOwners(_titleCfg.gid)
                                                            table.sort(owners, function(a, b)--获取Id最小的 role
                                                                return a<b 
                                                            end)
                                                            --ERROR_LOG("设置追踪",_titleCfg.gid,owners[1])
                                                            PlayerInfoHelper.ChangeFollowTitle(_titleCfg.gid,owners[1])--设置追踪称号为陆水银
                                                            _canFollowTitleId=_titleCfg.gid
                                                            break
                                                        end
                                                    end
                                                end
                                                if _canFollowTitleId then
                                                    break
                                                end

                                            end
                                        end
                                        if _canFollowTitleId then
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    else
                        ERROR_LOG("称号配置不存在==>>",followTitle)
                    end
                else
                    --ERROR_LOG("无追踪称号")
                    return
                end
            end
        end)
    else
        --ERROR_LOG("暂未拥有称号任务")
    end
end

local titleChangeTab={}
local newGetTitleTab={}
local newFinishTitleTab={}
function GetAllTitleStatus()--获取称号状态
    local _TitleQuestGoingList=module.QuestModule.GetList(TitleQuestType,0)--进行中称号任务
    local _TitleQuestFinishList=module.QuestModule.GetList(TitleQuestType,1)--进行中称号任务
    for i=1,#_TitleQuestGoingList do
        local _questId=_TitleQuestGoingList[i].id
        local titleGoing=TitleModule.GetTitleByQuest(_questId)--每个称号对应任务不重复
        if titleGoing then
            newGetTitleTab[titleGoing]=true
        else
            --ERROR_LOG(_questId,"is nil",titleGoing)
        end
    end
    for i=1,#_TitleQuestFinishList do
        local _questId=_TitleQuestFinishList[i].id
        local titleFinished=TitleModule.GetTitleByQuest(_questId)--每个称号对应任务不重复
        
        if titleFinished then
            newFinishTitleTab[titleFinished]=true
        else
            --ERROR_LOG(_questId,"is nil",titleFinished)
        end
    end
end
--称号状态改变
function GetTitleStatusChangeTab()
    local _TitleQuestGoingList=module.QuestModule.GetList(TitleQuestType,0)--进行中称号任务
    local _TitleQuestFinishList=module.QuestModule.GetList(TitleQuestType,1)--进行中称号任务
    for i=1,#_TitleQuestGoingList do
        local _questId=_TitleQuestGoingList[i].id
        local titleGoing=TitleModule.GetTitleByQuest(_questId)--每个称号对应任务不重复
        
        if titleGoing then
            if not newGetTitleTab[titleGoing] then
                titleChangeTab[titleGoing]=true
                newGetTitleTab[titleGoing]=true
            end
        else
            --ERROR_LOG(_questId,"is nil",titleGoing)  
        end
    end
    for i=1,#_TitleQuestFinishList do
        local _questId=_TitleQuestFinishList[i].id
        local titleFinished=TitleModule.GetTitleByQuest(_questId)--每个称号对应任务不重复
        
        if titleFinished then
            if not newFinishTitleTab[titleFinished] then
                titleChangeTab[titleFinished]=true
                newFinishTitleTab[titleFinished]=true
            end
        else
            --ERROR_LOG(_questId,"is nil",titleFinished)
        end
    end
    return titleChangeTab
end
function RemoveTitleChangeTab(titleId)
    titleChangeTab[titleId]=nil
    DispatchEvent("TITLE_INFO_CHANGE");
end