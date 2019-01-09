local GetItemTipsState = true
local ShowActorLvUpState=true
local ShowActorExpChangestate=true

local saved_item_tips = {}
local saved_actorLv_data={}
local saved_actorExp_data={}

function SetTipsState(state,DontIgnore)
    GetItemTipsState = state
    ShowActorLvUpState = state
    ShowActorExpChangestate= state

    if state then
        -- if DontIgnore then
        --     if next(saved_item_tips)~=nil then
        --         for _, v in ipairs(saved_item_tips) do
        --             GetItemTips(v[1], v[2], v[3]);
        --         end 
        --     end
        -- end
        ShowLvUpTips() 
    end
end

local not_show_tips_scene = {
    ['battle'] = true,
}

function SetItemTipsState(state)
    --ERROR_LOG("设置SetITemTipsState",state,#saved_item_tips)
    GetItemTipsState = state
    if not not_show_tips_scene[utils.SceneStack.CurrentSceneName()] then
        saved_item_tips = {}--改变状态后,清空itemTab
    end
end

function SetLvUpTipsState(State)
    ShowActorLvUpState = State
end

--获得hero 系统广播
function ShowGetHeroSystemChat(heroId)    
    local herolist = module.ActivityModule.GetSortHeroList()
    local hero_exist = false
    for i = 1,#herolist do
        --ERROR_LOG(id..">"..herolist[i].id)
        if herolist[i].id == heroId then
            hero_exist = true
            break
        end
    end
    if not hero_exist then
        module.ChatModule.SystemChat(module.playerModule.Get().id,utils.ItemHelper.TYPE.HERO,heroId,1)
    end
end

function GetItemTips(id,count,type,uuid)
    if not_show_tips_scene[utils.SceneStack.CurrentSceneName()] then
        table.insert(saved_item_tips, {id,count,type});
        --saved_item_tips={}--战斗获取道具不再显示获取提示，直接忽略
        return;
    end

    if not GetItemTipsState then
        table.insert(saved_item_tips, {id,count,type});
        return
    end 

    if type == utils.ItemHelper.TYPE.HERO then
        local herolist = module.ActivityModule.GetSortHeroList()
        local hero_exist = false
        for i = 1,#herolist do
            --ERROR_LOG(id..">"..herolist[i].id)
            if herolist[i].id == id then
                hero_exist = true
                break
            end
        end
        if hero_exist then
            id = id + 10000
            count = 10
           -- type = ItemHelper.TYPE.ITEM
           --类型用来标记是英雄转变的碎片在显示的时候改变type为Item          
        else
            ShowGetHeroSystemChat(id)
            -- utils.SGKTools.PopUpQueue(4,id)--获得英雄
            utils.SGKTools.HeroShow(id)
            return
        end
    end 

    if type == utils.ItemHelper.TYPE.HERO_ITEM then
        return;
    elseif type== utils.ItemHelper.TYPE.EQUIPMENT or type== utils.ItemHelper.TYPE.INSCRIPTION or type== utils.ItemHelper.TYPE.HERO then
        --utils.SGKTools.PopUpQueue(1,{id,count,type,uuid})
        DispatchEvent("GetItemTips",{id,count,type,uuid})
    else
        local itemconf = module.ItemModule.GetConfig(id)
        if not itemconf then
            ERROR_LOG("道具id->"..id.."在item表中不存在。")
            return
        elseif itemconf and itemconf.is_show == 0 then
            if itemconf.type==111 then--称号进度凭证
               utils.SGKTools.PopUpQueue(5,{id})
            elseif itemconf.type==166 then--学会图纸
                utils.SGKTools.PopUpQueue(9,{id})
            end
            return
        end
        DispatchEvent("GetItemTips",{id,count,type,uuid})
    end   
end

function GetFinishQuest()
    DispatchEvent("GetItemTips",{})
    --utils.SGKTools.PopUpQueue(1,{})
end

function GetActorLvUpData(oldLv,lv)
    if not_show_tips_scene[utils.SceneStack.CurrentSceneName()] then
        table.insert(saved_actorLv_data,{oldLv,lv})
        return;
    end

    if not ShowActorLvUpState then
        table.insert(saved_actorLv_data,{oldLv,lv})
        return
    end

    utils.SGKTools.PopUpQueue(3,{oldLv,lv})  
    saved_actorLv_data={} 
end

function GetActorExpChangeData(oldExp,Exp) 
    if not_show_tips_scene[utils.SceneStack.CurrentSceneName()] then
        table.insert(saved_actorExp_data,{oldExp,Exp})
        return;
    end

    if not ShowActorExpChangestate then
        table.insert(saved_actorExp_data,{oldExp,Exp})
        return
    end

    --utils.SGKTools.PopUpQueue(1,{11000,oldExp,Exp})
    DispatchEvent("GetItemTips",{11000,oldExp,Exp})
    --module.ChatModule.SystemChat(module.playerModule.Get().id,utils.ItemHelper.TYPE.ITEM,90000,math.floor(Exp- oldExp))
    saved_actorExp_data={}
end

function ShowLvUpTips()
    if next(saved_actorLv_data)~=nil then
       utils.SGKTools.PopUpQueue(3,{saved_actorLv_data[1][1],saved_actorLv_data[#saved_actorLv_data][2]}) 
    end
    saved_actorLv_data={} 
end

function SetItemTipsStateAndShowTips(state)--商店显示GetItemTip等动画播完
    --ERROR_LOG("设置SetItemTipsStateAndShowTips",state,#saved_item_tips)
    GetItemTipsState=state
    if not not_show_tips_scene[utils.SceneStack.CurrentSceneName()] then
        if state then
            for _, v in ipairs(saved_item_tips) do
                GetItemTips(v[1], v[2], v[3]);
            end 
        end
        saved_item_tips={} 
    end    
end

local fight_result_reward={}--战斗结算显示的获取
utils.EventManager.getInstance():addListener("SCENE_LOADED", function(event, name)
    if not_show_tips_scene[name] then
        return;
    end
    
    if next(saved_item_tips)~=nil then
        if next(fight_result_reward)~=nil then
            for _, v in ipairs(saved_item_tips) do--id,count,type
                local type,id,count=v[3],v[1],v[2]
                if fight_result_reward[type] and fight_result_reward[type][id] then
                    local _count=count-fight_result_reward[type][id]
                    if _count>0 then
                       GetItemTips(id,_count,type); 
                    end
                else
                    GetItemTips(id,count,type);
                end
            end
            fight_result_reward={}
        else
            for _, v in ipairs(saved_item_tips) do
                GetItemTips(v[1], v[2], v[3]);
            end
        end 
    end

    if next(saved_actorLv_data)~=nil then
       GetActorLvUpData(saved_actorLv_data[1][1],saved_actorLv_data[#saved_actorLv_data][2]) 
    end
        
    saved_item_tips = {}
    saved_actorLv_data={}
    saved_actorExp_data={}
end)

utils.EventManager.getInstance():addListener("GET_FIGHT_RESULT_REWARD", function(event,data)
    for k,v in pairs(data) do
        local type,id,count=v[1],v[2],v[3]
        fight_result_reward[type]=fight_result_reward[type] or {}
        fight_result_reward[type][id]=fight_result_reward[type][id] and fight_result_reward[type][id]+count or count
    end
end)

--结算界面 奖励物品的变化
local doubleAwardItemTab={}
utils.EventManager.getInstance():addListener("server_notify_16040", function (event, cmd, data)
    if data[1]==1 then
        local totalShowInfo=utils.PlayerInfoHelper.GetTotalShow()
        for k,v in pairs(totalShowInfo) do
            if v.double_id~=0 then
                doubleAwardItemTab[v.double_id]=module.ItemModule.GetItemCount(v.double_id) or 0
            end
        end
    end
end);

function GetRawardItemChange()
    local _changed=false
    for k,v in pairs(doubleAwardItemTab) do
        local _count=module.ItemModule.GetItemCount(k) or 0
        if v~=_count then
            _changed=true
            break
        end
    end
    return _changed
end