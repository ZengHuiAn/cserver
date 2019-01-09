local GetItemTipsState = true
local ShowActorLvUpState=true
local ShowActorExpChangestate=true
function SetTipsState(state)
    GetItemTipsState = state
    ShowActorLvUpState = state
    ShowActorExpChangestate= state
end

function SetItemTipsState(state)
    GetItemTipsState = state
end

function SetLvUpTipsState(State)
    ShowActorLvUpState = State
end

local not_show_tips_scene = {
    ['battle'] = true,
}

local saved_item_tips = {}
local saved_actorLv_data={}
local saved_actorExp_data={}
function GetItemTips(id,count,type)
    if not_show_tips_scene[utils.SceneStack.CurrentSceneName()] then
        -- table.insert(saved_item_tips, {id,count,type});--战斗获取道具不再显示获取提示，直接忽略
        return;
    end
    if not GetItemTipsState then
        table.insert(saved_item_tips, {id,count,type});
        return
    end

    local itemTypelist = module.ItemModule.GetItemTypeCfg()
    local ItemHelper = require "utils.ItemHelper"
    if type == ItemHelper.TYPE.HERO then
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
            type = ItemHelper.TYPE.ITEM
        else
            utils.SGKTools.PopUpQueue(4,id)--获得英雄
            return
        end
    end

    local itemconf = module.ItemModule.GetConfig(id)

    if not itemconf then
        ERROR_LOG("道具id->"..id.."在item表中不存在。")
        return
    elseif itemconf.is_show == 0 then
        return
    end

    local _type = itemconf.type
    for i = 1,#itemTypelist do 
        if itemTypelist[i].sub_type == _type then
            utils.SGKTools.PopUpQueue(1,{id,count,type})
            return
        end
    end 
end

function GetFinishQuest()
    -- print("ItemTIps=====94=== 任务完成")
    ShowActorLvUpState=false
    utils.SGKTools.PopUpQueue(1,{})
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

    utils.SGKTools.PopUpQueue(1,{11000,oldExp,Exp}) 
    saved_actorExp_data={}
end

function SetLvUpTipsStateAndShowTips(state)
    ShowActorLvUpState=state
    if state then
        if next(saved_actorLv_data)~=nil then
           utils.SGKTools.PopUpQueue(3,{saved_actorLv_data[1][1],saved_actorLv_data[#saved_actorLv_data][2]}) 
        end    
    end
    saved_actorLv_data={} 
end

function SetItemTipsStateAndShowTips(state)--商店显示GetItemTip等动画播完
    GetItemTipsState=state
    if state then
        for _, v in ipairs(saved_item_tips) do
            GetItemTips(v[1], v[2], v[3]);
        end  
    end
    saved_item_tips={} 
end

utils.EventManager.getInstance():addListener("SCENE_LOADED", function(event, name)
    if not_show_tips_scene[name] then
        return;
    end

    -- for _, v in ipairs(saved_item_tips) do
    --     GetItemTips(v[1], v[2], v[3]);
    -- end

    if next(saved_actorLv_data)~=nil then
       GetActorLvUpData(saved_actorLv_data[1][1],saved_actorLv_data[#saved_actorLv_data][2]) 
    end
        
    saved_item_tips = {}
    saved_actorLv_data={}
    saved_actorExp_data={}
end)