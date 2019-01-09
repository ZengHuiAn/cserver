
function LoadNpc(data,vec3,is_break)
    --local tempAdd = {id = 10001,mode = 11025,mapid = "cemetery_scene",name = "测试npc10001",Position_x = 0,Position_y = 0.5,Position_z = 0}
    --print(SceneStack.GetStack()[SceneStack.Count()].name)
    --if data.map_id == SceneStack.GetStack()[SceneStack.Count()].name then
    if SceneStack.Count() > 0 and data.mapid == SceneStack.GetStack()[SceneStack.Count()].savedValues.mapId then
        if data.is_born ~= "0" and not is_break then
            if not AssociatedLuaScript("guide/"..data.is_born..".lua",data.gid) then
                return nil
            end
        end
        local TipsView = nil
        if module.NPCModule.GetNPCALL(data.gid) then
            if vec3 then
                module.NPCModule.GetNPCALL(data.gid).transform.localPosition = vec3
            end
            module.NPCModule.GetNPCALL(data.gid):SetActive(true)
            TipsView = module.NPCModule.GetNPCALL(data.gid)
        else
            local tempObj = nil
            local skeletonDataAsset = nil
            if data.mode_type == 1 then
                tempObj = SGK.ResourcesManager.Load("prefabs/npc")
                skeletonDataAsset = "roles_small/"..data.mode.."/"..data.mode.."_SkeletonData";
            else
                tempObj = SGK.ResourcesManager.Load("prefabs/monster")
                skeletonDataAsset = "roles/"..data.mode.."/"..data.mode.."_SkeletonData";
            end
            local obj = CS.UnityEngine.GameObject.Instantiate(tempObj)--GetUIParent(tempObj)
            TipsView = CS.SGK.UIReference.Setup(obj)
            TipsView.Root.Canvas.name[UnityEngine.UI.Text].text = data.name
            localNpcStatus(TipsView,data.gid)
            local color = nil--{r=1,g=1,b=1,a=1}
            TipsView.Root.spine:SetActive(false)
            TipsView.Root.box:SetActive(false)
            if data.type == 1 then
                local CemeteryModule = require "module.CemeteryModule"
                if CemeteryModule.GetPlayerRecord(data.gid) and CemeteryModule.GetPlayerRecord(data.gid) > 0 then
                    --如果是已拾取过的怪物
                    --TipsView.Root.Canvas.name[UnityEngine.UI.Text].color = {r=169/255,g=169/255,b=169/255,a=1}
                    color = {r=169/255,g=169/255,b=169/255,a=1}
                else
                    --color = {r=1,g=0,b=0,a=1}
                end
            elseif data.type == 2 then
                --color = {r=104/255,g=1,b=0,a=1}
            elseif data.type == 3 and data.mode ~= 0 then
                --color = {r=1,g=0,b=0,a=1}
                TipsView.Root.box:SetActive(true)
                TipsView.Root.spine:SetActive(false)
                TipsView.Root.box[UnityEngine.SpriteRenderer]:LoadSprite("icon/" .. data.mode)
             elseif data.type == 6 then
                --特效npc
                local NpcTransportConf = require "config.MapConfig";
                local conf = NpcTransportConf.GetNpcTransport(data.mode)
                local modename = conf.modename
                --ERROR_LOG(sprinttb(conf))
                if modename ~= "0" then
                    local effect = UnityEngine.GameObject.Instantiate(SGK.ResourcesManager.Load("prefabs/effect/UI/"..modename),TipsView.transform)
                    effect.transform.localPosition = Vector3.zero
                    --local Collider = effect.transform:Find(typeof(UnityEngine.BoxCollider))
                    local Collider = effect:GetComponent(typeof(UnityEngine.BoxCollider))
                    if tostring(Collider) ~= "null: 0" then
                        Collider = effect:GetComponent(typeof(UnityEngine.BoxCollider))
                        TipsView[UnityEngine.BoxCollider].center = Collider.center
                        TipsView[UnityEngine.BoxCollider].size = Collider.size
                        Collider.enabled = false
                    else
                        TipsView[UnityEngine.BoxCollider].center = Vector3(conf.centent_x,conf.centent_y,conf.centent_z)
                        TipsView[UnityEngine.BoxCollider].size = Vector3(conf.Size_x,conf.Size_y,conf.Size_z)
                    end
                    for i = 1,effect.transform.childCount do
                        if effect.transform:GetChild(i-1).gameObject.tag == "small_point" then
                            TipsView.Root.Canvas.transform:SetParent(effect.transform:GetChild(i-1).gameObject.transform,false)
                            TipsView.Root.Canvas.transform.localPosition = Vector3.zero
                        end
                    end
                else
                    TipsView[UnityEngine.BoxCollider].center = Vector3(conf.centent_x,conf.centent_y,conf.centent_z)
                    TipsView[UnityEngine.BoxCollider].size = Vector3(conf.Size_x,conf.Size_y,conf.Size_z)
                end
                TipsView[CS.FollowCamera].enabled = false
                TipsView.transform.localEulerAngles = Vector3(0,0,0)
                TipsView.Root.Canvas[CS.FollowCamera].enabled = true
            end
            if color ~= nil then
                TipsView.Root.Canvas.name[UnityEngine.UI.Text].color = color
            end
            if data.type == 1 or data.type == 2 or data.type == 5 then
                if data.mode ~= 0 then
                    local scale_rate = TipsView.Root.spine.transform.localScale.x*data.scale_rate
                    TipsView.Root.spine.transform.localScale = Vector3(scale_rate,scale_rate,scale_rate)
                    TipsView.Root.spine:SetActive(true)
                    TipsView.Root.spine[CS.Spine.Unity.SkeletonAnimation]:UpdateSkeletonAnimation(skeletonDataAsset);
                    TipsView.skeletonDataAsset = skeletonDataAsset;
                    if TipsView[SGK.MapPlayer] then
                        --TipsView[SGK.MapPlayer]:SetDirection(data.face_to);
                        TipsView[SGK.MapPlayer].Default_Direction = data.face_to
                    elseif TipsView[SGK.MapMonster] then
                        TipsView.Root.spine.transform.localEulerAngles = Vector3(0,(data.face_to== 0 and 0 or 180),0)
                    end
                end
            end
            -- if data.script == "TransprotList_to" or data.script == "TransprotList_from" then
            --     --(sprinttb(TipsView))
            --     TipsView[UnityEngine.BoxCollider].center = Vector3(0,0.5,0)
            --     TipsView[UnityEngine.BoxCollider].size = Vector3(2,2,0.2)
            -- end

            TipsView[UnityEngine.BoxCollider].enabled = (data.script ~= "0")
            obj.name = "NPC_"..data.gid
            TipsView[CS.SGK.MapInteractableMenu].LuaTextName = tostring(data.script)
            TipsView[CS.SGK.MapInteractableMenu].LuaCondition = tostring(data.is_born)
            TipsView[CS.SGK.MapInteractableMenu].values = {tostring(data.mapid),tostring(data.gid)}
        end

        local NPCModule = require "module.NPCModule"
        NPCModule.SetNPC(data.gid,TipsView)
        if vec3 then
            TipsView.transform.localPosition = vec3
        else
            TipsView.transform.localPosition = Vector3(data.Position_x,data.Position_y,data.Position_z)
        end
        if data.born_script ~= "0" then
            AssociatedLuaScript("guide/"..data.born_script..".lua",TipsView,data.gid)
        end
        if data.is_move ~= "0" then
            SGK.MapNpcScript.Attach(TipsView.gameObject,"guide/npc/"..data.is_move..".lua")
        end
        return TipsView
    end
    return nil
end

function localNpcStatus(TipsView,id)
    local MapConfig = require "config.MapConfig"
    local data = MapConfig.GetMapMonsterConf(id)
    if data.mode == 0 or data.type == 6 then
        return
    end

    TipsView.Root.Canvas.flag:SetActive(false)
    if data.function_icon ~= "0" then
        TipsView.Root.Canvas.flag:SetActive(true)
        TipsView.Root.Canvas.flag.transform.localPosition = Vector3(0,40,0)
        TipsView.Root.Canvas.flag.transform:DOLocalMove(Vector3(0,50,0),0.5):SetLoops(-1,CS.DG.Tweening.LoopType.Yoyo)
        TipsView.Root.Canvas.flag[UnityEngine.UI.Image]:LoadSprite("icon/" .. data.function_icon)
        --ERROR_LOG(id..">"..data.function_icon)
    end

    local _TipsView = TipsView
    module.QuestModule.GetNpcStatus(data.gid,function (NpcStatus,typeid)
        if NpcStatus and typeid and _TipsView and _TipsView.Root then
            local activityConfig = require "config.activityConfig"

            local activityInfo = activityConfig.GetActivity(typeid)
            if activityInfo == nil then
                return;
            end

            local imageName = ""
            if NpcStatus == 1 then--可完成
                imageName = activityInfo.finish_yes
            elseif NpcStatus == 2 then--可接
                imageName = activityInfo.is_accept
            elseif NpcStatus == 3 then--不可完成
                imageName = activityInfo.finish_no
            end

            _TipsView.Root.Canvas.flag:SetActive(true)
            _TipsView.Root.Canvas.flag[UnityEngine.UI.Image]:LoadSprite("icon/" .. imageName)
            _TipsView.Root.Canvas.flag.transform.localPosition = Vector3(0,40,0)
            _TipsView.Root.Canvas.flag.transform:DOLocalMove(Vector3(0,50,0),0.5):SetLoops(-1,CS.DG.Tweening.LoopType.Yoyo)
        end
    end)
end

function LoadNpcDesc(id,desc,fun,type,time)
    if id then
        local NPCModule = require "module.NPCModule"
        local npc_view = NPCModule.GetNPCALL(id)
        if npc_view then
            ShowNpcDesc(npc_view.Root.Canvas.dialogue,desc,fun,type,time)
        else
            ERROR_LOG("NPC"..id.."找不到")
        end
    else
        if not time then
            time = 2
        end
        DispatchEvent("GetplayerCharacter",id,desc,fun,type,time)
    end
end
function ShowNpcDesc(npc_view,desc,fun,type,time)
    --ERROR_LOG(npc_view.gameObject.name)
    npc_view.bg1:SetActive(false)
    npc_view.bg2:SetActive(false)
    npc_view.bg3:SetActive(false)
    npc_view:SetActive(false)
    if type == 2 then
        npc_view.bg2:SetActive(true)
    elseif type == 3 then
        npc_view.bg3:SetActive(true)
    else
        npc_view.bg1:SetActive(true)
    end
    npc_view.desc[UnityEngine.UI.Text].text = desc
    npc_view:SetActive(true)
    SGK.Action.DelayTime.Create(0.1):OnComplete(function()
        npc_view[UnityEngine.RectTransform].sizeDelta = CS.UnityEngine.Vector2(npc_view.desc[UnityEngine.RectTransform].sizeDelta.x+100,72)
        npc_view[UnityEngine.CanvasGroup]:DOFade(1,1):OnComplete(function( ... )
            npc_view[UnityEngine.CanvasGroup]:DOFade(0,1):OnComplete(function( ... )
                npc_view:SetActive(false)
                if fun then
                    fun()
                end
            end):SetDelay(time ~= nil and time or 2)
        end)
    end)
end
