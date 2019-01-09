
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
        elseif data.type == 4 then
            local tempObj = SGK.ResourcesManager.Load("prefabs/npc_pos")
            local obj = CS.UnityEngine.GameObject.Instantiate(tempObj)
            TipsView = CS.SGK.UIReference.Setup(obj)
        else
            TipsView = CS.UnityEngine.GameObject.Instantiate(SGK.ResourcesManager.Load("prefabs/npc_pos"))
            TipsView = CS.SGK.UIReference.Setup(TipsView)
            DialogStack.PushPref("npcInfo",data,TipsView.gameObject)
        end
        TipsView[UnityEngine.BoxCollider].enabled = (data.script ~= "0")
        TipsView.name = "NPC_"..data.gid
        local Npc_Sctipt = nil
        if data.Trigger == 0 then
            Npc_Sctipt = TipsView[CS.SGK.MapInteractableMenu]
        else
            Npc_Sctipt = TipsView[CS.SGK.MapColliderMenu]
        end
        Npc_Sctipt.enabled = true
        Npc_Sctipt.LuaTextName = tostring(data.script)
        Npc_Sctipt.LuaCondition = tostring(data.is_born)
        Npc_Sctipt.values = {tostring(data.mapid),tostring(data.gid)}
        local NPCModule = require "module.NPCModule"
        NPCModule.SetNPC(data.gid,TipsView)
        if vec3 then
            TipsView.transform.localPosition = vec3
        else
            TipsView.transform.localPosition = Vector3(data.Position_x,data.Position_y,data.Position_z)
        end
        TipsView.transform.localEulerAngles = Vector3(45,0,0)
        return TipsView
    end
    return nil
end

function localNpcStatus(TipsView,id)
   DispatchEvent("localNpcStatus",{gid = id})
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

local function utf8sub(input,size)
    local len  = string.len(input)
	local str = "";
	local cut = 1;
	local nextcut = 1;
    local left = len
    local cnt  = 0
    local _count = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string.byte(input, -left)
        local i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end

        if i ~= 1 then
            _count = _count + i
        else
            cnt = cnt + i
		end

		if left ~= 0 then
			if (cnt + _count) >= (size * cut) then
				str = str..string.sub(input, nextcut, cnt + _count).."\n"
				nextcut = cnt + _count + 1;
				cut = cut + 1;
			end
		else
			str = str..string.sub(input, nextcut, len)
		end
    end
    return str, cut;
end

function ShowNpcDesc(npc_view,desc,fun,type,time,len,color)
    --ERROR_LOG(npc_view.gameObject.name)
    len = len or 39
    npc_view:SetActive(false)
    npc_view.bg1:SetActive(type == 1)
    npc_view.bg2:SetActive(type == 2)
    npc_view.bg3:SetActive(type == 3)
    local _str,row = utf8sub(desc, len);
    time = time or row
    if color then
        _str = "<color="..color..">".._str.."</color>"
    end

    npc_view.desc[UnityEngine.UI.Text].text = _str
    npc_view:SetActive(true)
    SGK.Action.DelayTime.Create(0.1):OnComplete(function()
        npc_view[UnityEngine.RectTransform].sizeDelta = CS.UnityEngine.Vector2(npc_view.desc[UnityEngine.RectTransform].sizeDelta.x + 50, 30 + (npc_view.desc[UnityEngine.UI.Text].fontSize * row) + (row - 1) * 6)
        npc_view[UnityEngine.CanvasGroup]:DOFade(1,1):OnComplete(function( ... )
            npc_view[UnityEngine.CanvasGroup]:DOFade(0,1):OnComplete(function( ... )
                npc_view:SetActive(false)
                if fun then
                    fun()
                end
            end):SetDelay(time)
        end)
    end)
end
