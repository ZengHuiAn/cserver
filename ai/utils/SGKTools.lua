local SGKTools = {}
local LockMapObj = nil
function SGKTools.LockMapClick(status)
	if LockMapObj == nil then
		if status then
			LockMapObj = GetUIParent(SGK.ResourcesManager.Load("prefabs/LockFrame"))
		end
	else
		LockMapObj:SetActive(status)
	end
	module.MapModule.SetMapIsLock(status)
end

local is_open = false
local open_list = {}
function SGKTools.HeroShow(id,fun)
	if is_open then
		open_list[#open_list+1] = id
	else
		local cfg = module.HeroModule.GetInfoConfig()
		if cfg[id] then
			is_open = true
			local obj = GetUIParent(SGK.ResourcesManager.Load("prefabs/HeroShow"))
			local view = CS.SGK.UIReference.Setup(obj)
			local HeroOBJ = GetUIParent(SGK.ResourcesManager.Load("prefabs/effect/UI/jues_appear"))
			local HeroView = CS.SGK.UIReference.Setup(HeroOBJ)
			local Animation = HeroView.jues_appear_ani.jues.gameObject:GetComponent(typeof(CS.Spine.Unity.SkeletonAnimation));
			Animation.skeletonDataAsset = SGK.ResourcesManager.Load("roles/"..cfg[id].mode_id.."/"..cfg[id].mode_id.."_SkeletonData");
			Animation:Initialize(true);
			HeroView.jues_appear_ani.name_Text[UnityEngine.TextMesh].text = cfg[id].name
			HeroView.jues_appear_ani.name_Text[1][UnityEngine.TextMesh].text = cfg[id].name
			HeroView.jues_appear_ani.name_Text[2][UnityEngine.TextMesh].text = cfg[id].name
			HeroView.jues_appear_ani.name2_Text[UnityEngine.TextMesh].text = cfg[id].pinYin
			HeroView.jues_appear_ani.bai_tiao.sanj_jsjs_bai.jies_Text[UnityEngine.TextMesh].text = cfg[id].info
			view.Exit[CS.UGUIClickEventListener].onClick = function ( ... )
				CS.UnityEngine.GameObject.Destroy(obj)
				CS.UnityEngine.GameObject.Destroy(HeroOBJ)
				is_open = false
				if #open_list > 0 then
					SGKTools.HeroShow(open_list[1])
					table.remove(open_list,1)
				elseif fun then
					fun()
				end
			end
		else
			ERROR_LOG(nil,"配置表role_info中"..id.."不存在")
		end
	end
end
function SGKTools.CloseFrame()
	if #DialogStack.GetPref_stact() > 0 or #DialogStack.GetStack() > 0 or SceneStack.Count() > 1 then
		DispatchEvent("KEYDOWN_ESCAPE")
	end
end
function SGKTools.CloseStory()
	DispatchEvent("CloseStoryReset")
end
function SGKTools.loadEffect(name,id)--给NPC或玩家身上加载一个特效
    if id then
        if module.NPCModule.GetNPCALL(id) then
           local eff = GetUIParent(SGK.ResourcesManager.Load("prefabs/effect/"..name),module.NPCModule.GetNPCALL(id))
           eff.transform.localPosition = Vector3.zero
        end
    else
        DispatchEvent("loadPlayerEffect",name)
    end
end
function SGKTools.loadEffectVec3(name,Vec3,time,lock,fun)--加载一个全屏的UI特效
	local eff = GetUIParent(SGK.ResourcesManager.Load("prefabs/effect/"..name),UnityEngine.GameObject.FindWithTag("UGUIRootTop"))
	eff.transform.localScale = Vector3(100,100,100)
    eff.transform.localPosition = Vec3
    local lockObj = nil
    if lock then
    	lockObj = GetUIParent(SGK.ResourcesManager.Load("prefabs/LockFrame"))
    end
    SGK.Action.DelayTime.Create(time):OnComplete(function()
    	if fun then
    		fun()
    	end
    	if lockObj then
	    	UnityEngine.GameObject.Destroy(lockObj.gameObject)
	    end
	    UnityEngine.GameObject.Destroy(eff.gameObject)
    end)
end
local loadSceneEffectArr = {}
function SGKTools.loadSceneEffect(name,Vec3,time,lock,fun)
	local eff = CS.UnityEngine.GameObject.Instantiate(SGK.ResourcesManager.Load("prefabs/effect/"..name))
	if Vec3 then
	    eff.transform.position = Vec3
	end
	local lockView = nil
	if lock then
		lockView = GetUIParent(SGK.ResourcesManager.Load("prefabs/LockFrame"))
	end
	loadSceneEffectArr[name] = {eff,lockView}
    if time then
	    if fun then
			SGK.Action.DelayTime.Create(time):OnComplete(function()
		    	fun()
		    	if lockView then
		    		UnityEngine.GameObject.Destroy(lockView.gameObject)
		    	end
			end)
		end
	end
end
function SGKTools.DestroySceneEffect(name,time,fun)
	if loadSceneEffectArr[name] and loadSceneEffectArr[name][1].activeSelf then
		if time then
			SGK.Action.DelayTime.Create(time):OnComplete(function()
				if fun then
			    	fun()
			    end
			    CS.UnityEngine.GameObject.Destroy(loadSceneEffectArr[name][1].gameObject)
			    if loadSceneEffectArr[name][2] then
				    CS.UnityEngine.GameObject.Destroy(loadSceneEffectArr[name][2].gameObject)
				end
				loadSceneEffectArr[name] = nil
			end)
		end
	end
end
function SGKTools.NPC_Follow_Player(id,type)
	DispatchEvent("NPC_Follow_Player",id,type)
end
function SGKTools.NPCDirectionChange(id,Direction)
	local npc = module.NPCModule.GetNPCALL(id)
	npc[SGK.MapPlayer].Default_Direction = Direction
end
local now_TaskId = nil
function SGKTools.GetTaskId()
	return now_TaskId
end
function SGKTools.SetTaskId(id)
	now_TaskId = id
end
function SGKTools.SetNPCSpeed(id,speed)
	if id then
		module.NPCModule.GetNPCALL(id)[UnityEngine.AI.NavMeshAgent].speed = speed
	end
end
local _PopUpQueueData = {}
local _PopUpQueueType = 0
local _PopUpQueuelock = false
function SGKTools.PopUpQueue(_type,data)
	if _type and data then
		_PopUpQueueData[#_PopUpQueueData + 1] = {_type,data}
	else
		_PopUpQueuelock = false
	end
	-- ERROR_LOG(_PopUpQueueType.." ".._PopUpQueueData[1][1])
	if (#_PopUpQueueData > 0 and _PopUpQueuelock == false) or (#_PopUpQueueData > 0 and _PopUpQueueType == 1 and _PopUpQueueType == _PopUpQueueData[1][1]) then
		_PopUpQueueType = _PopUpQueueData[1][1]
		if _PopUpQueueType == 1 then--获得物品
			DispatchEvent("GetItemTips",_PopUpQueueData[1][2],function ( ... )
				SGKTools.PopUpQueue()
				SetLvUpTipsStateAndShowTips(true)
			end)
			table.remove(_PopUpQueueData,1)
			_PopUpQueuelock = true
			if #_PopUpQueueData > 0 and _PopUpQueueType == _PopUpQueueData[1][1] then
				SGKTools.PopUpQueue()
			end
			if #_PopUpQueueData > 0 and #_PopUpQueueData<= 1 then
				SetLvUpTipsStateAndShowTips(true)
			end
		elseif _PopUpQueueType == 2 then--完成任务
			DispatchEvent("QUEST_FINISH",function ( ... )
				--SetLvUpTipsState(true)--完成任务后再弹升级
				SGKTools.PopUpQueue()
			end);
			table.remove(_PopUpQueueData,1)
			_PopUpQueuelock = true
		elseif _PopUpQueueType == 3 then--主角升级
			DispatchEvent("ShowActorLvUp",_PopUpQueueData[1][2],function ( ... )
				--_PopUpQueueData={}
				-- SetItemTipsState(true)
				SGKTools.PopUpQueue()
			end)
			table.remove(_PopUpQueueData,1)
			_PopUpQueuelock = true
		elseif _PopUpQueueType == 4 then--获得英雄
			SGKTools.HeroShow(_PopUpQueueData[1][2],function ( ... )
				SGKTools.PopUpQueue()
			end)
			table.remove(_PopUpQueueData,1)
			_PopUpQueuelock = true
		end
	end
end
function SGKTools.SetNPCTimeScale(id,TimeScale)
	if id then
		module.NPCModule.GetNPCALL(id).Root.spine[CS.Spine.Unity.SkeletonAnimation].timeScale = TimeScale
	end
end
function SGKTools.PLayerConceal(status,duration,delay)
	DispatchEvent("PLayer_Shielding",module.playerModule.GetSelfID(),(status and 0 or 1),true,duration,delay)
end
function SGKTools.TeamConceal(status,duration,delay)
	local members = module.TeamModule.GetTeamMembers()
	for k,v in ipairs(members) do
		DispatchEvent("PLayer_Shielding",v.pid,(status and 0 or 1),true,duration,delay)
	end
end
function SGKTools.TeamScript(value)--全队执行脚本
	module.TeamModule.SyncTeamData(109,value)
end
function SGKTools.PlayerMoveZERO()--脱离卡位
	DispatchEvent("MAP_CHARACTER_MOVE_Player", {module.playerModule.GetSelfID()});
end

local ScrollingMarqueeView = nil
local ScrollingMarqueeOBJ = nil
local ScrollingMarqueeDesc = {}
local IsMove = false

function SGKTools.showScrollingMarquee(desc)
	if desc then
		ScrollingMarqueeDesc[#ScrollingMarqueeDesc+1] = desc
	end
	if #ScrollingMarqueeDesc > 0 then
		if ScrollingMarqueeOBJ == nil then
			ScrollingMarqueeOBJ = GetUIParent(SGK.ResourcesManager.Load("prefabs/ScrollingMarquee"))
			ScrollingMarqueeView = CS.SGK.UIReference.Setup(ScrollingMarqueeOBJ)
		end
		if IsMove == false then
			IsMove = true
			ScrollingMarqueeView.bg.desc[UnityEngine.UI.Text].text = ScrollingMarqueeDesc[1]
			table.remove(ScrollingMarqueeDesc,1)
			ScrollingMarqueeView.bg.desc.transform:DOScale(Vector3(1,1,1),0.1):OnComplete(function( ... )
				ScrollingMarqueeView.bg.desc.transform:DOLocalMove(Vector3(-(276+ScrollingMarqueeView.bg.desc[UnityEngine.RectTransform].sizeDelta.x),0,0),10):OnComplete(function( ... )
					IsMove = false
					ScrollingMarqueeView.bg.desc.transform.localPosition = Vector3(276,0,0)
					SGKTools.showScrollingMarquee()
				end)--:SetEase(CS.DG.Tweening.Ease.InOutQuint)
			end)
		end
	else
		CS.UnityEngine.GameObject.Destroy(ScrollingMarqueeOBJ)
		ScrollingMarqueeOBJ = nil
	end
end
function SGKTools.Map_Interact(npc_id)
	local MapConfig = require "config.MapConfig"
	local npc_conf = MapConfig.GetMapMonsterConf(npc_id)
	if not npc_conf then
		ERROR_LOG("NPC_id->"..npc_id.."在NPC表中不存在")
		return
	end
	local mapid = npc_conf.mapid
	if SceneStack.GetStack()[SceneStack.Count()].savedValues.mapId ~= mapid then
    	SceneStack.EnterMap(mapid);
    end
    module.EncounterFightModule.GUIDE.Interact("NPC_"..npc_id);
end

function SGKTools.PlayGameObjectAnimation(name, trigger)
	local obj = UnityEngine.GameObject.Find(name);
	if not obj then
		print("object no found", name);
		return;
	end

	local animator = obj:GetComponent(typeof(UnityEngine.Animator));
	if animator then
		animator:SetTrigger(trigger);
	end
end
function SGKTools.StronglySuggest(desc)
	local obj = GetUIParent(SGK.ResourcesManager.Load("prefabs/StronglySuggest"))
	local view = CS.SGK.UIReference.Setup(obj)
	view.desc[UnityEngine.UI.Text].text = desc
	view[UnityEngine.CanvasGroup]:DOFade(1,0.5):OnComplete(function ( ... )
       view[UnityEngine.CanvasGroup]:DOFade(0, 0.5):SetDelay(1):OnComplete(function ( ... )
            CS.UnityEngine.GameObject.Destroy(obj);
        end);
    end)
end
function SGKTools.FriendTipsNew(parent,pid,Toggle,data)
	local obj = GetUIParent(SGK.ResourcesManager.Load("prefabs/FriendTipsNew"),parent[1])

	--obj.transform:SetParent(parent[2].transform,true)
	obj.transform.localScale = Vector3(1,1,1)
	--parent[2]:SetActive(true)
	local view = CS.SGK.UIReference.Setup(obj)
	view.Root.transform.position = parent[2].transform.position
	view.Root[UnityEngine.CanvasGroup]:DOFade(1,0.5)
	view.mask[CS.UGUIClickEventListener].onClick = function ( ... )
		DispatchEvent("FriendTipsNew_close")
		view.Root[UnityEngine.CanvasGroup]:DOFade(0,0.5):OnComplete(function( ... )
			UnityEngine.GameObject.Destroy(obj)
		end)
	end
	if Toggle then
		for i = 1,#Toggle do
			view.Root[Toggle[i]]:SetActive(true)
			if Toggle[i] == 2 then
				local FriendData = module.FriendModule.GetManager(1,pid)
				view.Root[Toggle[i]].Text[UnityEngine.UI.Text].text = FriendData and FriendData.care == 1 and "取消关注" or "特别关注"
			end
			view.Root[Toggle[i]][CS.UGUIClickEventListener].onClick = function ( ... )
				if Toggle[i] == 1 then--加好友
					utils.NetworkService.Send(5013,{nil,1,pid})
				elseif Toggle[i] == 2 then--特别关注
					local FriendData = module.FriendModule.GetManager(1,pid)
					if FriendData and FriendData.care == 1 then
						utils.NetworkService.Send(5013,{nil,1,pid})
					else
						if module.FriendModule.GetcareCount() < 5 then
							utils.NetworkService.Send(5013,{nil,3,pid})
						else
							showDlgError(nil,"特别关注已达上限")
						end
					end
				elseif Toggle[i] == 3 then--私聊
					local list = {data = data,pid = pid}
					DialogStack.PushPref("FriendChat",list,UnityEngine.GameObject.FindWithTag("UGUIRootTop").gameObject)
					--SGKTools.FriendChat()
				elseif Toggle[i] == 4 then--邀请入团
					 if module.unionModule.Manage:GetUionId() == 0 then
                        showDlgError(nil, "您还没有军团")
                    elseif module.unionModule.GetPlayerUnioInfo(pid).unionId ~= nil and module.unionModule.GetPlayerUnioInfo(pid).unionId ~= 0 then
                        showDlgError(nil, "该玩家已有军团")
                    else
                        module.unionModule.Invite(pid)
                    end
				elseif Toggle[i] == 5 then--邀请入队
					-- local teamInfo = module.TeamModule.GetTeamInfo();
     --            	if teamInfo.group ~= 0 then
					-- 	module.TeamModule.Invite(pid)
					-- else
					-- 	showDlgError(nil,"请先创建一个队伍")
					-- end
					if module.TeamModule.GetTeamInfo().id <= 0 then
                        module.TeamModule.CreateTeam(999,function ( ... )
                            module.TeamModule.Invite(pid);
                        end);--创建空队伍并邀请对方
                    else
                        module.TeamModule.Invite(pid);
                    end
				elseif Toggle[i] == 6 then--拉黑
					local FriendData = module.FriendModule.GetManager(1,pid)
					if FriendData then
						utils.NetworkService.Send(5013,{nil,2,pid})--朋友黑名单
					else
						utils.NetworkService.Send(5013,{nil,4,pid})--陌生人黑名单
					end
				elseif Toggle[i] == 7 then--删除好友
					showDlg(nil,"确定要删除该好友吗？",function()
						utils.NetworkService.Send(5015,{nil,pid})
					end,function ( ... )
					end)
				else
					ERROR_LOG("参数错误",Toggle[i])
				end
				--parent[2]:SetActive(false)
				DispatchEvent("FriendTipsNew_close")
				view.Root[UnityEngine.CanvasGroup]:DOFade(0,0.5):OnComplete(function( ... )
					UnityEngine.GameObject.Destroy(obj)
				end)
			end
		end
	end
end

function SGKTools.FormattingNumber(Count)
	if Count > 1000000 then
		return SGKTools.GetPreciseDecimal(Count/1000000,1).."M"
	elseif Count > 1000 then
		return SGKTools.GetPreciseDecimal(Count/1000,1).."K"
	end
	return Count
end
function SGKTools.GetPreciseDecimal(nNum, n)
	if type(nNum) ~= "number" then
		return nNum;
		end
		n = n or 0;
		n = math.floor(n)
		if n < 0 then
		n = 0;
	end
	local nDecimal = 10 ^ n
	local nTemp = math.floor(nNum * nDecimal);
	local nRet = nTemp / nDecimal;
	return nRet;
end
function SGKTools.ChangeNpcDir(obj, direction)
	obj:GetComponent(typeof(SGK.MapPlayer)):SetDirection(direction)
end

function SGKTools.EnterMap(name)
	module.EncounterFightModule.GUIDE.EnterMap(name)
end
function SGKTools.Interact(name)
	module.EncounterFightModule.GUIDE.Interact(name)
end
function SGKTools.Stop()
	module.EncounterFightModule.GUIDE.Stop()
end
function SGKTools.GetCurrentMapName()
	module.EncounterFightModule.GUIDE.GetCurrentMapName()
end
function SGKTools.GetCurrentMapID()
	module.EncounterFightModule.GUIDE.GetCurrentMapID()
end
function SGKTools.StartPVEFight(fightID)
	module.EncounterFightModule.GUIDE.StartPVEFight(fightID)
end
function SGKTools.ON_Interact()
	module.EncounterFightModule.GUIDE.ON_Interact()
end
function SGKTools.GetInteractInfo()
	module.EncounterFightModule.GUIDE.GetInteractInfo()
end
function SGKTools.NPCInit(gameObject)
	module.EncounterFightModule.GUIDE.NPCInit(gameObject)
end
function SGKTools.StopPlayerMove(pid)
    DispatchEvent("LOCAL_MAPSCENE_STOPPLAYER_MOVE")
end

function SGKTools.ScientificNotation(number)
	local _item = number
	if _item >= 1000000 then
	    _item = string.format("%.1f", _item/1000000).."M"
	elseif _item >= 1000 then
	    _item = string.format("%.1f", _item/1000).."K"
	end
	return _item
end

---true为组队中
function SGKTools.GetTeamState()
	local teamInfo = module.TeamModule.GetTeamInfo()
	return (teamInfo.group ~= 0)
end

---true为队长
function SGKTools.isTeamLeader()
    local teamInfo = module.TeamModule.GetTeamInfo();
    return (teamInfo.group == 0 or module.playerModule.Get().id == teamInfo.leader.pid)
end

function SGKTools.InToDefensiveFortress()--进入元素暴走
	--print("队长请求进入 元素暴走活动")
	local NetworkService = require "utils.NetworkService"
	NetworkService.Send(16127)
end

return SGKTools
