local EventManager = require 'utils.EventManager';
function RegisterEventListener(script)
    if script.listEvent and script.onEvent then
        script.__event_listener_callback = function(...)
            script:onEvent(...);
        end

        script.__event_listener_list = {};

        for _, event in ipairs(script:listEvent()) do
            table.insert(script.__event_listener_list, event);
            -- print('RegisterEventListener', script, event);
            EventManager.getInstance():addListener(event, script.__event_listener_callback);
        end
    end
end

function DispatchEvent(event, ...)
	-- print('DispatchEvent', event, ...);
    EventManager.getInstance():dispatch(event, ...)
end

function RemoveEventListener(script)
    if script.listEvent and script.__event_listener_callback and script.__event_listener_list then
        for _, event in ipairs(script.__event_listener_list) do
            -- print('RemoveEventListener', script, event);
            EventManager.getInstance():removeListener(event, script.__event_listener_callback);
        end
    end
end

local function RETURN_WITH_ERROR_LOG(success, ...)
    if not success then
        ERROR_LOG(...);
    end
    return success, ...
end

local _coroutine_resume = coroutine.resume;
coroutine.resume = function(...)
    return RETURN_WITH_ERROR_LOG(_coroutine_resume(...))
end

--format 1: xx小时xx分xx秒
--format 2: 00:00:00
function GetTimeFormat(time,format,lenth)
    lenth = lenth or 3;
    local time_str = "";
    local day,hour,min,sec = 0,0,0,0;
    if format == 1 then     
        if time < 60 then
            sec = time;
        elseif time < 3600 then
            min = math.floor(time/60);
            sec = time%60;
        elseif time < 86400  then
            hour = math.floor(time/3600);
            min = math.floor((time%3600)/60);
        else
            day = math.floor(time/86400);
            hour = math.floor((time%86400)/3600);
            min = math.floor((time%3600)/60);
        end
        -- day = math.floor(time/86400);
        -- hour = math.floor((time - day * 86400)/3600);
        -- min = math.floor((time - day * 86400 - hour * 3600)/60);
        -- sec = time%60;
        time_str = (day ~= 0 and (day.."天") or "")..(hour ~= 0 and (hour.."小时") or "")..(min ~= 0 and (min.."分") or "")..(sec ~= 0 and (sec.."秒") or "");
    elseif format == 2 then
        
        -- if time < 60 then
        --     sec = time;
        -- elseif time < 3600 then
        --     min = math.floor(time/60);
        --     sec = math.fmod(time,60);
        -- else --if productInfo.time.max < 86400  then
        --     hour = math.floor(time/3600);
        --     min = math.floor(math.fmod(time,3600)/60);
        --     sec =  math.fmod(time,60);
        -- end
        -- time_str = string.format("%02d"..":".."%02d"..":".."%02d",hour,min,sec);
        if lenth == 1 then
            sec = time;
            time_str = string.format("%02d",sec);
        elseif lenth == 2 then
            min = math.floor(time/60);
            sec = time%60;
            time_str = string.format("%02d"..":".."%02d",min,sec);
        elseif lenth == 3 then
            hour = math.floor(time/3600);
            min = math.floor((time%3600)/60);
            sec = time%60;
            time_str = string.format("%02d"..":".."%02d"..":".."%02d",hour,min,sec);
        end
    end
    return time_str;
end

function showPropertyChange(prop_name,delta,hero_name,time,space)
    time = time or 2
    space = space or 0.18
    hero_name = hero_name or ""
    local NGUIRoot = UnityEngine.GameObject.FindWithTag("UGUIRoot") or UnityEngine.GameObject.FindWithTag("NGUIRoot");
    if NGUIRoot == nil then
        return;
    end
    local prefabs = SGK.ResourcesManager.Load("prefabs/CapacityTip")
    for i=1,#prop_name do
        if delta[i] ~= 0 then
            local delay = space * (i - 1);
            local obj = CS.UnityEngine.GameObject.Instantiate(prefabs, NGUIRoot.gameObject.transform)
            local label = obj.transform:Find("Text"):GetComponent(typeof(UnityEngine.UI.Text));
            if delta[i] > 0 then
                label:TextFormat("{0} {1}提升 +{2}", hero_name, prop_name[i], math.floor(delta[i]));
            else
                label:TextFormat("{0} {1}下降 {2}", hero_name, prop_name[i], math.floor(delta[i]));
            end
            
            label:DOFade(1,0.1):SetDelay(delay):OnComplete(function ( ... )
               label:DOFade(0, time):SetDelay(0.5);
                obj.transform:DOLocalMove(Vector3(0,250,0), time):OnComplete(function ( ... )
                    CS.UnityEngine.GameObject.Destroy(obj);
                end);
            end)
        end
    end
end
function TeamStory(storyid)
    module.TeamModule.SyncTeamData(103, storyid)--向队员发送剧情id
end
function TeamQuestModuleAccept(id)
    module.TeamModule.SyncTeamData(104, id)--向队员发送接任务id
end
function TeamQuestModuleSubmit(id)
    module.TeamModule.SyncTeamData(105, id)--向队员发送交任务id
end
function PlayerEnterMap(...)
    DispatchEvent("PlayerEnterMap",...)
end
function LoadMapName(id)
    local tempObj = SGK.ResourcesManager.Load("prefabs/MapName")
    local MapNameObj = GetUIParent(tempObj)
    local MapNameView = CS.SGK.UIReference.Setup(MapNameObj)
    local MapConfig = require "config.MapConfig"
    local mapCfg = MapConfig.GetMapConf(id);
    if not mapCfg then
        ERROR_LOG("mapid->"..id.."->nil\n"..debug.traceback())
        return
    end
    MapNameView.bg.title[UnityEngine.UI.Text].text = mapCfg.title
    MapNameView.bg.name[UnityEngine.UI.Text].text = mapCfg.map_name
    MapNameView.bg.title[UnityEngine.CanvasGroup]:DOFade(1, 0.5)
    MapNameView.bg.title.transform:DOLocalMove(Vector3(-100,25,0),0.5):OnComplete(function ( ... )
        MapNameView.bg.title[UnityEngine.CanvasGroup]:DOFade(0, 0.5):SetDelay(1)
        MapNameView.bg.title.transform:DOLocalMove(Vector3(100,25,0),0.5):OnComplete(function ( ... )

        end):SetDelay(1)
    end)--:SetEase(CS.DG.Tweening.Ease.InQuad)
    ---------------------------------------------------------------------------------------------------
    MapNameView.bg.name[UnityEngine.CanvasGroup]:DOFade(1, 0.5)
    MapNameView.bg.name.transform:DOLocalMove(Vector3(78,-25,0),0.5):OnComplete(function ( ... )
        MapNameView.bg.name[UnityEngine.CanvasGroup]:DOFade(0, 0.5):SetDelay(1)
        MapNameView.bg.name.transform:DOLocalMove(Vector3(-200,-25,0),0.5):OnComplete(function ( ... )
            CS.UnityEngine.GameObject.Destroy(MapNameObj);
        end):SetDelay(1)
    end)
end

require "utils.NPCOperation"

function StringSplit(szFullString, szSeparator)
    if not szFullString then
        return {};
    end
    local nFindStartIndex = 1 
    local nSplitIndex = 1 
    local nSplitArray = {} 
    while true do 
       local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex) 
       if not nFindLastIndex then 
        nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString)) 
        break 
       end 
       nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1) 
       nFindStartIndex = nFindLastIndex + string.len(szSeparator) 
       nSplitIndex = nSplitIndex + 1 
    end 
    return nSplitArray 
end

function GetUIParent(tempObj,parent)
    local obj = nil
    if parent then
        obj = CS.UnityEngine.GameObject.Instantiate(tempObj,parent.gameObject.transform)
    elseif UnityEngine.GameObject.FindWithTag("UITopRoot") then
        obj = CS.UnityEngine.GameObject.Instantiate(tempObj, UnityEngine.GameObject.FindWithTag("UITopRoot").gameObject.transform)
    elseif UnityEngine.GameObject.FindWithTag("UGUIRootTop") then
        obj = CS.UnityEngine.GameObject.Instantiate(tempObj,UnityEngine.GameObject.FindWithTag("UGUIRootTop").gameObject.transform)
    elseif UnityEngine.GameObject.FindWithTag("UGUIRoot") then
        obj = CS.UnityEngine.GameObject.Instantiate(tempObj,UnityEngine.GameObject.FindWithTag("UGUIRoot").gameObject.transform)
    else
        obj = CS.UnityEngine.GameObject.Instantiate(tempObj)
    end
    return obj
end

function showDlgMsg(msg, confirm, cancel, txtConfirm, txtCancel, time)
    DispatchEvent("showDlgMsg", {msg = msg, confirm = confirm, cancel = cancel, txtConfirm = txtConfirm, txtCancel = txtCancel, time = time})
end

function showDlg(parent,msg,confirm,cancel,txtConfirm,txtCancel,layer)
    DispatchEvent("showDlgMsg", {msg = msg, confirm = confirm, cancel = cancel, txtConfirm = txtConfirm, txtCancel = txtCancel})
end

function showDlgError(parent,msg)
    DispatchEvent("showDlgError",{parent,msg})
end

local HelpState = false
function GetHelpFrame(Fun)
    --1帮助2商城3公告4系统5呼叫GM6返回登录7退出游戏
    if HelpState then
        return
    end
    local tempObj = SGK.ResourcesManager.Load("prefabs/helpFrame")
    HelpState = true
    local obj = GetUIParent(tempObj)
    local HelpView = CS.SGK.UIReference.Setup(obj)
    for i = 1 , #HelpView.Group do
        HelpView.Group[i][CS.UGUIClickEventListener].onClick = function ( ... )
            if i == 1 then
                --SceneStack.EnterMap("map_scene");
                local playerModule = require "module.playerModule"
                local TeamModule = require "module.TeamModule"
                local teamInfo = TeamModule.GetTeamInfo();
                if teamInfo.group == 0 or playerModule.Get().id == teamInfo.leader.pid then
                    EventManager.getInstance():dispatch("MAP_CHARACTER_MOVE_Player", {playerModule.GetSelfID(), 0, 0, 0});
                else
                    showDlgError(nil,"无法在队伍中直接脱离卡位")
                end
            elseif i == 2 then
                local Shielding = module.MapModule.GetShielding()
                module.MapModule.SetShielding(not Shielding)
                Shielding = not Shielding
                local MapGetPlayers = module.TeamModule.MapGetPlayers()
                for k,v in pairs(MapGetPlayers)do
                    --ERROR_LOG(k)
                    if module.playerModule.GetSelfID() ~= k then
                        DispatchEvent("PLayer_Shielding",k,(Shielding and 0 or 0.5))
                    end
                end
            elseif i == 3 then
                --utils.SGKTools.StopPlayerMove()
                local GuildPVPGroupModule = require "guild.pvp.module.group"
                local status,fight_status = GuildPVPGroupModule.GetStatus();
                --ERROR_LOG(fight_status)
                if fight_status == 4 then--比赛结束
                    DialogStack.Push("guild_pvp/GuildPVPJoinPanel")
                else
                    SceneStack.Push("GuildPVPPreparation", "view/guild_pvp/GuildPVPPreparation.lua")
                end
                --GetItemTips(11024,1,utils.ItemHelper.TYPE.HERO)
                --DialogStack.Push("PubReward",{list = module.TeamModule.GetPubRewardData()})
            elseif i == 4 then
                local teamInfo = module.TeamModule.GetTeamInfo();
                if teamInfo.id <= 0 then
                    SceneStack.Push("map_chouka", "view/DrawCardTest.lua")
                else
                    DialogStack.Push("DrawCardFrame",nil,"MapSceneUIRootMid")
                end
                --GetItemTips(11002,1,utils.ItemHelper.TYPE.HERO)
                -- GetItemTips(21000,26666,utils.ItemHelper.TYPE.ITEM)
                -- utils.SGKTools.PopUpQueue(2,{})
                -- utils.SGKTools.PopUpQueue(3,{1,5})
                -- GetItemTips(21000,2333,utils.ItemHelper.TYPE.ITEM)
                -- GetItemTips(21000,26666,utils.ItemHelper.TYPE.ITEM)
            elseif i == 5 then
                DialogStack.Push("SubmitForm")
            elseif i == 6 then
                DialogStack.GetPref_list("StoryFrame")
                DialogStack.GetPref_list(tempObj)
                -- for i = 1, 100 do
                --     --DialogStack.PushPref("StoryFrame")
                --     SceneService:LoadPrefabs("prefabs/StoryFrame",function (obj)
                --         UnityEngine.GameObject.Instantiate(obj)
                --     end)
                -- end
            elseif i == 7 then
                showDlg(nil,"确认退出游戏？",function()
                    UnityEngine.Application.Quit();
                end,function()
                end,"退出", "取消");
            end
            CS.UnityEngine.GameObject.Destroy(obj)
            HelpState = false
            if Fun then
                Fun(i)
            end
        end
    end
    HelpView.mask[CS.UGUIClickEventListener].onClick = function ( ... )
        CS.UnityEngine.GameObject.Destroy(obj)
        HelpState = false
        if Fun then
            Fun(0)
        end
    end
end

function ShowChatWarning(msg)
    local tempObj = SGK.ResourcesManager.Load("prefabs/ChatWarning")
    local obj = nil;
    --DlgErrornum = DlgErrornum == 6 and 0 or DlgErrornum + 1 
    local NGUIRoot = UnityEngine.GameObject.FindWithTag("UGUIRoot")
    if NGUIRoot then
         obj = CS.UnityEngine.GameObject.Instantiate(tempObj, NGUIRoot.gameObject.transform)
    elseif UnityEngine.GameObject.FindWithTag("NGUIRoot") then
        obj = CS.UnityEngine.GameObject.Instantiate(tempObj,UnityEngine.GameObject.FindWithTag("NGUIRoot").gameObject.transform)
    else
        obj = CS.UnityEngine.GameObject.Instantiate(tempObj)
    end
    local ErrorView = CS.SGK.UIReference.Setup(obj)
    ErrorView.desc[UnityEngine.UI.Text].text = msg
    --obj.transform:DOScale(Vector3(1,1,1),0.25):SetEase(CS.DG.Tweening.Ease.OutBounce):OnComplete(function( ... )
        obj:GetComponent("CanvasGroup"):DOFade(0,1):SetDelay(1):OnComplete(function( ... )
            CS.UnityEngine.GameObject.Destroy(obj)
        end)
    --end)
end
function WhetherOnline(EndTime,parent)
    local tempObj = SGK.ResourcesManager.Load("prefabs/WhetherOnline")
    local obj = nil;
     if parent then
        obj = CS.UnityEngine.GameObject.Instantiate(tempObj, parent.gameObject.transform)
    else
        local NGUIRoot = UnityEngine.GameObject.FindWithTag("UGUIRoot")
        if NGUIRoot then
             obj = CS.UnityEngine.GameObject.Instantiate(tempObj, NGUIRoot.gameObject.transform)
        elseif UnityEngine.GameObject.FindWithTag("NGUIRoot") then
            obj = CS.UnityEngine.GameObject.Instantiate(tempObj,UnityEngine.GameObject.FindWithTag("NGUIRoot").gameObject.transform)
        else
            obj = CS.UnityEngine.GameObject.Instantiate(tempObj)
        end
    end
    local TeamModule = require "module.TeamModule"
    local Time = require "module.Time"
    local TempView = CS.SGK.UIReference.Setup(obj)
    local time = math.floor(EndTime - Time.now())
    TempView.Slider[UnityEngine.UI.Image]:DOFillAmount(0,time):OnComplete(function ( ... )
        TeamModule.PlayerReady(2,0)
        CS.UnityEngine.GameObject.Destroy(obj)
    end)
    TempView.mask[CS.UGUIClickEventListener].onClick = function ( ... )
        TeamModule.PlayerReady(2,0)
        CS.UnityEngine.GameObject.Destroy(obj)
    end
    TempView.YBtn[CS.UGUIClickEventListener].onClick = function ( ... )
        TeamModule.PlayerReady(1,0)
        CS.UnityEngine.GameObject.Destroy(obj)
    end
end

function Loadcg_comic(name)
    local tempObj = SGK.ResourcesManager.Load("prefabs/cg_comicFrame")
    local CgOBJ = GetUIParent(tempObj,UnityEngine.GameObject.FindWithTag("UGUIRootTop"))
    local CgView = CS.SGK.UIReference.Setup(CgOBJ)
    local animationIdx = 1
    CgView.cg[CS.UGUIClickEventListener].onClick = function ( ... )
        if CgView.cg.animation[CS.Spine.Unity.SkeletonAnimation].skeletonDataAsset:GetSkeletonData():FindAnimation("animation"..animationIdx) then
            CgView.cg.animation[CS.Spine.Unity.SkeletonAnimation].state:SetAnimation(0,"animation"..animationIdx,false);
            animationIdx = animationIdx + 1
        else
             CS.UnityEngine.GameObject.Destroy(CgOBJ)
        end
    end
    CgView.cg.animation[CS.Spine.Unity.SkeletonAnimation].skeletonDataAsset = SGK.ResourcesManager.Load("cg/"..name.."/"..name.."_SkeletonData");
    CgView.cg.animation[CS.Spine.Unity.SkeletonAnimation]:Initialize(true);
    CgView.cg.animation[CS.Spine.Unity.SkeletonAnimation].state:SetAnimation(0,"animation1",false);
    CgView.cg.animation[SGK.BattlefieldObject].onSpineEvent = function(eventName, strValue, intValue, floatValue)
        ERROR_LOG(eventName..">"..strValue..">"..intValue..">"..floatValue)
        if eventName == "u3d" then
           CgView.cg.animation.Effect[CS.FollowSpineBone].boneName = "u3d_"..intValue
            local Effect = GetUIParent(SGK.ResourcesManager.Load("prefabs/effect/UI/fx_box_kai_gold"),CgView.cg.animation.Effect)
            Effect.transform.localPosition = Vector3.zero
        end
    end
    CgView.cg.animation.transform.localPosition = Vector3(0,0,-1)
    CgView.cg.animation.transform.localScale = Vector3(100,100,100)
    CgView.cg:SetActive(true)
    animationIdx = animationIdx + 1
end
function loadRollingSubtitles(id,fun)
    local tempObj = SGK.ResourcesManager.Load("prefabs/RollingSubtitles")
    local RollingSubtitles = GetUIParent(tempObj)
    local RollingSubtitlesView = CS.SGK.UIReference.Setup(RollingSubtitles)
    local StoryConfig = require "config.StoryConfig"
    RollingSubtitlesView.mask.desc[CS.InlineText].text = StoryConfig.GetStoryConf(id).dialog
    RollingSubtitlesView.mask.desc.transform:DOScale(Vector3(1,1,1),0.1):OnComplete(function ( ... )
        local y = RollingSubtitlesView.mask.desc[UnityEngine.RectTransform].sizeDelta.y + 250
        RollingSubtitlesView.mask.desc.transform:DOLocalMove(Vector3(0,y,0), RollingSubtitlesView.mask.desc[UnityEngine.RectTransform].sizeDelta.y/22):OnComplete(function ( ... )
            CS.UnityEngine.GameObject.Destroy(RollingSubtitles)
            if fun then
                fun()
            end
        end)
    end)
    RollingSubtitlesView.skipBtn[CS.UGUIClickEventListener].onClick = function ( ... )
        CS.UnityEngine.GameObject.Destroy(RollingSubtitles)
        if fun then
            fun()
        end
    end
end
-- local StoryFrame = nil
-- function DeleteStory()
--     StoryFrame = nil
-- end
function LoadGuideStory(_id,_Fun,_state)
    --state true是否为对话完毕后执行Function    
    _Fun = _Fun and coroutine.wrap(_Fun);
    local level = module.playerModule.Get() and module.playerModule.Get().level or nil
    local _p = UnityEngine.GameObject.FindWithTag("UGUIGuideRoot") or UnityEngine.GameObject.FindWithTag("UGUIRootTop")
    if not _p then
        _p = UnityEngine.GameObject.FindWithTag("UGUIRoot")
    end
    local StoryFrame = DialogStack.GetPref_list("StoryFrame")
    if StoryFrame then
        if StoryFrame.gameObject then
            StoryFrame:SetActive(true)
        end
        DispatchEvent("STORYFRAME_CONTENT_CHANGE", {id = _id,Function = _Fun,state = _state});
    else
        DialogStack.PushPref("StoryFrame",{id = _id,Function = _Fun,state = _state}, _p)
    end

    --_Fun = _Fun and coroutine.wrap(_Fun);
    -- local level = module.playerModule.Get() and module.playerModule.Get().level or nil
    -- local _p = UnityEngine.GameObject.FindWithTag("UGUIGuideRoot")
    -- if not StoryFrame and level and level <= 100 and  _p then
    --     StoryFrame = DialogStack.PushPref("StoryFrame",{id = _id,Function = _Fun,state = _state}, _p.transform)
    -- else
    --     if level and level > 100 and StoryFrame then
    --         UnityEngine.GameObject.Destroy(StoryFrame.gameObject)
    --         StoryFrame = nil
    --     end
    --     if StoryFrame then
    --         StoryFrame:SetActive(true)
    --         DispatchEvent("STORYFRAME_CONTENT_CHANGE", {id = _id,Function = _Fun,state = _state});
    --     else
    --         if DialogStack.Top() and DialogStack.Top().name == "StoryFrame" then
    --             DispatchEvent("STORYFRAME_CONTENT_CHANGE", {id = _id,Function = _Fun,state = _state});
    --         else
    --             local _p = UnityEngine.GameObject.FindWithTag("UGUIGuideRoot") or UnityEngine.GameObject.FindWithTag("UGUIRootTop")
    --             if _p then
    --                 if DialogStack.Top() and DialogStack.Top().name == "StoryFrame" then
    --                     DialogStack.Pop()
    --                 end
    --                 DialogStack.PushPrefStact("StoryFrame",{id = _id,Function = _Fun,state = _state}, _p.transform)
    --             end
    --         end
    --     end
    -- end
end
function LoadStory(_id,_Fun,_state)
    LoadGuideStory(_id, _Fun, _state)
    --state true是否为对话完毕后执行Function    
    -- _Fun = _Fun and coroutine.wrap(_Fun);
    -- local level = module.playerModule.Get() and module.playerModule.Get().level or nil
    -- local _p = UnityEngine.GameObject.FindWithTag("UGUIGuideRoot") or UnityEngine.GameObject.FindWithTag("UGUIRootTop")
    -- if not _p then
    --     _p = UnityEngine.GameObject.FindWithTag("UGUIRoot")
    -- end
    -- local StoryFrame = DialogStack.GetPref_list("StoryFrame")
    -- if StoryFrame and StoryFrame.gameObject then
    --     StoryFrame:SetActive(true)
    --     DispatchEvent("STORYFRAME_CONTENT_CHANGE", {id = _id,Function = _Fun,state = _state});
    -- else
    --     DialogStack.PushPref("StoryFrame",{id = _id,Function = _Fun,state = _state}, _p.transform)
    -- end
    -- if not StoryFrame and level and level <= 100 and _p then
    --     StoryFrame = DialogStack.PushPref("StoryFrame",{id = _id,Function = _Fun,state = _state}, _p.transform)
    -- else
    --     if level and level > 100 and StoryFrame then
    --         UnityEngine.GameObject.Destroy(StoryFrame.gameObject)
    --         StoryFrame = nil
    --     end
    --     if StoryFrame then
    --         StoryFrame:SetActive(true)
    --         DispatchEvent("STORYFRAME_CONTENT_CHANGE", {id = _id,Function = _Fun,state = _state});
    --     else
    --         if DialogStack.Top() and DialogStack.Top().name == "StoryFrame" then
    --             DispatchEvent("STORYFRAME_CONTENT_CHANGE", {id = _id,Function = _Fun,state = _state});
    --         else
    --             for i = 1,#DialogStack.GetPref_stact() do
    --                 DialogStack.Pop()
    --             end
    --             for i = 1,#DialogStack.GetStack() do
    --                 DialogStack.Pop()
    --             end
    --             DialogStack.Push("StoryFrame",{id = _id,Function = _Fun,state = _state},"UGUIRootTop")
    --         end
    --     end
    -- end
end
local StoryOptionsData = {}
function SetStoryOptions(data,state)
    for i = 1,#data do
        StoryOptionsData[#StoryOptionsData + 1] = data[i]
    end
    if state then
        StoryOptions(data)
    end
end
function LoadStoryOptions()
    StoryOptions(StoryOptionsData)
end
local StoryOptionsObj = nil
function StoryOptions(data)
    -- local StoryOptionsData = {}
    -- if data.Groups ~= nil then
    --     print(sprinttb(data.Groups))
    --     StoryOptionsData = data.Groups
    -- elseif data.path ~= nil then
    --    StoryOptionsData = dofile(UnityEngine.Application.dataPath.."/lua/"..data.path)
    -- end
    if #data == 0 then
        return
    end
    if StoryOptionsObj == nil then
        local tempObj = SGK.ResourcesManager.Load("prefabs/StoryOptionsFrame")
        StoryOptionsObj = GetUIParent(tempObj)
    end
    local StoryView = CS.SGK.UIReference.Setup(StoryOptionsObj)
    local TempData = data and data or StoryOptionsData
    for i = 1,#TempData do
        local descObj = CS.UnityEngine.GameObject.Instantiate(StoryView.border.options[1].gameObject, StoryView.border.options.gameObject.transform)
        local descView = CS.SGK.UIReference.Setup(descObj)
        descView:SetActive(true)
        descView.name[UnityEngine.UI.Text].text = TempData[i].name
        if TempData[i].effect then
            --ERROR_LOG(TempData[i].effect)
            local effect = SGK.ResourcesManager.Load("prefabs/"..TempData[i].effect)
            if effect then
                GetUIParent(effect,descView.transform)
            else
                ERROR_LOG("prefabs/"..TempData[i].effect.."不存在")
            end
        end
        if TempData[i].action then
            descView[CS.UGUIClickEventListener].onClick = function ( ... )
                StoryOptionsData = {}
                CS.UnityEngine.GameObject.Destroy(StoryOptionsObj)
                StoryOptionsObj = nil
                --DispatchEvent("KEYDOWN_ESCAPE")
                assert(coroutine.resume(coroutine.create(TempData[i].action)));
            end
        end
    end
    local count = StoryView.border.options.transform.childCount - 1
    --StoryView.border[UnityEngine.RectTransform].sizeDelta = CS.UnityEngine.Vector2(278.4,62 + count*55)
    StoryView.mask[CS.UGUIClickEventListener].onClick = function ( ... )
        StoryOptionsData = {}
        CS.UnityEngine.GameObject.Destroy(StoryOptionsObj)
        StoryOptionsObj = nil
        DispatchEvent("CloseStoryReset")
        --DialogStack:Pop();
    end
    StoryOptionsObj.gameObject.transform:DOScale(Vector3(1,1,1),0.5):OnComplete(function()
        if count == 1 and TempData[1].auto then
            assert(coroutine.resume(coroutine.create(TempData[1].action)));
            StoryOptionsData = {}
            CS.UnityEngine.GameObject.Destroy(StoryOptionsObj)
            StoryOptionsObj = nil
        end
    end)--:SetDelay(0)
end
function DeleteStoryOptions()
    StoryOptionsData = {}
    CS.UnityEngine.GameObject.Destroy(StoryOptionsObj)
    StoryOptionsObj = nil
    DispatchEvent("CloseStoryReset")
    --DialogStack:Pop();
end
function AssociatedLuaScript(path,...)
    local s = loadfile(path,"bt",_G)(...)
    if s == nil then
        s = true
    end
    return s
end

function PlayerTips(data)
    local tempObj = SGK.ResourcesManager.Load("prefabs/FriendTips")
    --local NGUIRoot = UnityEngine.GameObject.FindWithTag("UGUIRoot");
    local NetworkService = require "utils.NetworkService";
    local unionModule = require "module.unionModule"
    local playerModule = require "module.playerModule"
    local obj = nil;
    --if NGUIRoot then
         obj = GetUIParent(tempObj)
    -- else
    --     return
    -- end
    if data and data.name and data.level and data.pid then
        local TipsView = CS.SGK.UIReference.Setup(obj)

        TipsView.Root.name[UnityEngine.UI.Text].text = data.name..""
        playerModule.GetCombat(data.pid,function ( ... )
            TipsView.Root.combat[UnityEngine.UI.Text].text = "战力:<color=#FEBA00>"..tostring(math.ceil(playerModule.GetFightData(data.pid).capacity)).."</color>"
        end)
        local unionName = unionModule.GetPlayerUnioInfo(data.pid).unionName
        if unionName then
            TipsView.Root.guild[UnityEngine.UI.Text]:TextFormat("军团:{0}", unionName);
        else
            unionModule.queryPlayerUnioInfo(data.pid,(function ( ... )
                unionName = unionModule.GetPlayerUnioInfo(data.pid).unionName or "无"
                TipsView.Root.guild[UnityEngine.UI.Text]:TextFormat("军团:", unionName);
            end))
        end
        local objClone = nil
        if TipsView.Root.hero.transform.childCount == 0 then
            local tempObj = SGK.ResourcesManager.Load("prefabs/newCharacterIcon")
            objClone = CS.UnityEngine.GameObject.Instantiate(tempObj,TipsView.Root.hero.transform)
            objClone.transform.localPosition = Vector3.zero
        else
            objClone = TipsView.Root.hero.transform:GetChild(0)
        end
        local PLayerIcon = SGK.UIReference.Setup(objClone)
        if playerModule.IsDataExist(data.pid) then
            local head = playerModule.IsDataExist(data.pid).head ~= 0 and playerModule.IsDataExist(data.pid).head or 11001
            --TipsView.obj.hero.icon[UnityEngine.UI.Image]:LoadSprite("icon/"..head)
            PLayerIcon[SGK.newCharacterIcon]:SetInfo({head = head,level = playerModule.IsDataExist(data.pid).level,name = "",vip=0},true)
        else
            playerModule.Get(data.pid,(function( ... )
                local head = playerModule.IsDataExist(data.pid).head ~= 0 and playerModule.IsDataExist(data.pid).head or 11001
               --TipsView.obj.hero.icon[UnityEngine.UI.Image]:LoadSprite("icon/"..head)
               PLayerIcon[SGK.newCharacterIcon]:SetInfo({head = head,level = playerModule.IsDataExist(data.pid).level,name = "",vip=0},true)
            end))
        end
        TipsView.Root.Btn1[CS.UGUIClickEventListener].onClick = (function ( ... )
            --加好友
            NetworkService.Send(5013,{nil,1,data.pid})--添加好友
            CS.UnityEngine.GameObject.Destroy(obj)
        end)

        TipsView.Root.Btn2[CS.UGUIClickEventListener].onClick = (function ( ... )
            --邀请入团
            if module.unionModule.Manage:GetUionId() == 0 then
                showDlgError(nil, "您还没有军团")
            elseif module.unionModule.GetPlayerUnioInfo(data.pid).unionId ~= nil and module.unionModule.GetPlayerUnioInfo(data.pid).unionId ~= 0 then
                showDlgError(nil, "该玩家已有军团")
            else
                module.unionModule.Invite(data.pid)
            end
            CS.UnityEngine.GameObject.Destroy(obj)
        end)

        TipsView.Root.Btn3[CS.UGUIClickEventListener].onClick = (function ( ... )
            --拉黑
            NetworkService.Send(5013,{nil,2,data.pid})
            CS.UnityEngine.GameObject.Destroy(obj)
        end)
       
        TipsView.Root.Btn4[CS.UGUIClickEventListener].onClick = (function ( ... )
            --邀请入队
            local teamInfo = module.TeamModule.GetTeamInfo();
            if teamInfo.group ~= 0 then
                module.TeamModule.Invite(data.pid)
            else
                showDlgError(nil,"请先创建一个队伍")
            end
        end)
        TipsView.mask[CS.UGUIClickEventListener].onClick = (function ( ... )
            CS.UnityEngine.GameObject.Destroy(obj)
        end)
    end
end

-- 打印表的格式的方法
local function _sprinttb(tb, tabspace)
    tabspace =tabspace or ''
    local str =string.format(tabspace .. '{\n' )
    for k,v in pairs(tb or {}) do
        if type(v)=='table' then
            if type(k)=='string' then
                str =str .. string.format("%s%s =\n", tabspace..'  ', k)
                str =str .. _sprinttb(v, tabspace..'  ')
            elseif type(k)=='number' then
                str =str .. string.format("%s[%d] =\n", tabspace..'  ', k)
                str =str .. _sprinttb(v, tabspace..'  ')
            end
        else
            if type(k)=='string' then
                str =str .. string.format("%s%s = %s,\n", tabspace..'  ', tostring(k), tostring(v))
            elseif type(k)=='number' then
                str =str .. string.format("%s[%s] = %s,\n", tabspace..'  ', tostring(k), tostring(v))
            end
        end
    end
    str =str .. string.format(tabspace .. '},\n' )
    return str
end

function sprinttb(tb, tabspace)
    local function ss()
        return _sprinttb(tb, tabspace);
    end
    return setmetatable({}, {
        __concat = ss,
        __tostring = ss,
    });
end

function BIT(toNum)
    local tmp = {}
    while toNum > 0 do
        tmp[#tmp+1] = toNum % 2 ;
        toNum = math.floor(toNum / 2);
    end
    return tmp;
end

local ui_reference_metatable = {
    __index = function(t, k)
        if type(k) == "table" and typeof(k) and t.gameObject then
            return t.gameObject:GetComponent(typeof(k));
        else
            local value = t.gameObject[k];
            if type(value) == "function" then
                return function(c, ...)
                    return value( (c == t) and t.gameObject or c, ...)
                end
            else
                return value;
            end
        end
    end,
    __newindex = function(t, k, v)
        local value = t.gameObject[k];
        if value and type(value) ~= "function" then
            t.gameObject = v;
        else
            rawset(t, k, v);
        end
    end
}
local Type_CS_SGK_UIReference = typeof(CS.SGK.UIReference);

local function __get_ref(t)
    local ref = rawget(t, "UIReference");
    if ref == nil then
        ref = t.gameObject:GetComponent(Type_CS_SGK_UIReference);
        rawset(t, "UIReference", ref or false);
    end
    return ref and ref or nil;
end

local function SetupViewByUIReference(root)
    if root == nil then
        return nil
    end

    return setmetatable({gameObject = root}, {__len = function(t)
        local ref = __get_ref(t); 
		return ref and ref.refs.Length or 0;
	end, __index = function(t, k)
        if type(k) == "table" and typeof(k) and t.gameObject then -- GetComponent
            return t.gameObject:GetComponent(typeof(k));
        end

        local ref = __get_ref(t); 

        local child = ref and ref:Get(k);
        if child then
            local childRef = SetupViewByUIReference(child);
            rawset(t, k, childRef);
            return childRef;
        end

        local value = t.gameObject[k];

        if type(value) == "function" then
            return function(c, ...)
                return value( (c == t) and t.gameObject or c, ...)
            end
        else
            return value;
        end
    end, __newindex = function(t, k, v)
        local value = t.gameObject[k];
        if value and type(value) ~= "function" then
            t.gameObject[k] = v;
        else
            rawset(t, k, v);
        end
    end})
end

--中文占2个字符 英文占1个字符
--取出中文字符个数
--总个数加上中文个数
function GetUtf8Len(Str)
    local uc = 0
    for uchar in string.gmatch(Str, "[\\0-\127\194-\244][\128-\191]*") do
        if #uchar ~= 1 then
            uc = uc + 1
        end
    end
    local len  = string.len(Str)
    local left = len
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string.byte(Str, -left)
        local i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
    end
    return cnt + uc
end


-- 5.3 
unpack = unpack or table.unpack

-- Spine
Spine = CS.Spine

-- UnityEngine
UnityEngine = CS.UnityEngine;
Vector3 = CS.UnityEngine.Vector3
Quaternion = UnityEngine.Quaternion
UI = CS.UnityEngine.UI

-- SGK
SGK = CS.SGK

DATABASE = require "utils.ConfigReader";
DATABASE.GetBattlefieldCharacterTransform = SGK.Database.GetBattlefieldCharacterTransform;

function LoadDatabaseWithKey(name, field)
    local data_list = {};
    DATABASE.ForEach(name, function(row, idx)
        local mainkey;
        if field then
            mainkey = row[field];
        else
            mainkey = i;
        end

        if mainkey ~= nil then
            data_list[mainkey] = row;
        end
    end);
    return data_list;
end

rawset(SGK.UIReference, "Setup", function(tag)
    local v;
    if tag == nil or type(tag) == "string" then
        v = SetupViewByUIReference(UnityEngine.GameObject.FindWithTag(tag or "ui_reference_root") );
    else
        v = SetupViewByUIReference(tag)
    end
    return v;    
end);

rawset(SGK.UIReference, "Instantiate", function(prefab)
    return SGK.UIReference.Setup(UnityEngine.GameObject.Instantiate(prefab.gameObject or prefab));
end)

-- coroutine
StartCoroutine = function(func, ...) 
	local success, info = coroutine.resume(coroutine.create(func), ...);
	if not success then
		ERROR_LOG(info)
	end
end

local util = require "xlua.util"
Yield = util.async_to_sync(function(to_yield, cb)
	SGK.CoroutineService.YieldAndCallback(to_yield, cb);
end);

function WaitForEndOfFrame()
	Yield(UnityEngine.WaitForEndOfFrame());
end

function WaitForSeconds(n)
	Yield(UnityEngine.WaitForSeconds(n));
end

function HTTPRequest(url, postData, header)
    local www
    if postData then
        local form = UnityEngine.WWWForm();

        for k, v in pairs(postData) do
            form:AddField(k, v);
        end

        www = UnityEngine.WWW(url, form.data, header or {})
    else
        www = UnityEngine.WWW(url, nil, header or {})
    end

    Yield(www)

    return www.bytes, www.error
end

function Sleep(n, dont_check_scene)
	local co = coroutine.running();
	if co == nil or not coroutine.isyieldable() then
		assert(false, "can't sleep in main thread");
        return;
	end

	local scene_index = SceneService.sceneIndex;

	CS.SGK.CoroutineService.ScheduleOnce(function()
		coroutine.resume(co)
	end, n or 0)

	coroutine.yield();

	if not dont_check_scene and scene_index ~= SceneService.sceneIndex then
		error('scene changed, stop sleeping thread');
	end
end

-- loadfile / loadfile
loadfile = function(file, m, env)
	local str = SGK.FileUtils.LoadStringFromFile(file);
	return load(str, file, m, env);
end

--[[
dofile = function(file, m, env)
	loadfile(file, m, env)();
end
--]]


utils = setmetatable({}, {__index=function(t, k)
    return require ("utils." .. k);
end})

module = setmetatable({}, {__index=function(t, k)
    return require ("module." .. k);
end})

-- require "utils.network";
SceneStack = require "utils.SceneStack"
DialogStack = require "utils.DialogStack"
ThreadEval = function(script, chunkName, ...)
    local func = loadstring(script, chunkName);
    utils.Thread.Eval(func, ...)
end

require "network"
require "utils.class"
local protobuf = require "protobuf"
protobuf.register(SGK.ResourcesManager.Load("proto.pb").bytes)
function ProtobufEncode(msg, protocol)
    return protobuf.encode(protocol, msg);
end

function ProtobufDecode(code, protocol)
    return protobuf.decode(protocol, code);
end


require "WordFilter"
WordFilter.init(SGK.ResourcesManager.Load("Word").text);

require "utils.ItemTips"

local WELLRNG512a_ = require "WELLRNG512a"
function WELLRNG512a(seed)
    local rng = WELLRNG512a_.new(seed);
    return setmetatable({rng=rng}, {__call=function(t)
        return WELLRNG512a_.value(t.rng);
    end})
end

setmetatable(_G, {__index=function(t, k)
    ERROR_LOG("GLOBAL NAME", k, "NOT EXISTS", debug.traceback())
end, __newindex = function(t, k, v)
    ERROR_LOG("SET GLOBAL NAME", k, v, debug.traceback())
    rawset(t, k, v);
end})

require "module.init"

SceneStack.Start("login_scene2", "view/login_scene2.lua");