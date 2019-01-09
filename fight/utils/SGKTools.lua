local SmallTeamDungeonConf = require "config.SmallTeamDungeonConf"

local SGKTools = {}
local LockMapObj = nil
local LockMapObj_count = 0;
function SGKTools.LockMapClick(status,time)
	LockMapObj_count = LockMapObj_count + (status and 1 or -1);
	if LockMapObj_count < 0 then
		ERROR_LOG("SGKTools.LockMapClick", debug.traceback())
		LockMapObj_count = 0;
	end

	if LockMapObj_count > 0 then
		if LockMapObj == nil then
			LockMapObj = GetUIParent(SGK.ResourcesManager.Load("prefabs/LockFrame"))
		end
		LockMapObj:SetActive(true)
		module.MapModule.SetMapIsLock(true)
	elseif LockMapObj_count == 0 then
		if LockMapObj then
			LockMapObj:SetActive(false)
		end
		module.MapModule.SetMapIsLock(false)
	end

	if status and time then
		SGK.Action.DelayTime.Create(time):OnComplete(function()
			SGKTools.LockMapClick(false)
		end)
	end
end

local is_open = false
local open_list = {}
function SGKTools.HeroShow(id,fun, delectTime,showDetail)
	if is_open then
		open_list[#open_list+1] = id
	else
		local heroInfo = showDetail and module.HeroModule.GetInfoConfig(id) or module.HeroModule.GetConfig(id)
		if heroInfo then
			is_open = true
			local obj = GetUIParent(SGK.ResourcesManager.Load("prefabs/HeroShow"))
			local view = CS.SGK.UIReference.Setup(obj)
			local _removeFunc = function()
	            CS.UnityEngine.GameObject.Destroy(obj)
	            --CS.UnityEngine.GameObject.Destroy(HeroOBJ)
	            is_open = false
	            if #open_list > 0 then
	                SGKTools.HeroShow(open_list[1])
	                table.remove(open_list,1)
	            elseif fun then
	                fun()
	            end
	            DispatchEvent("stop_automationBtn",{automation = true,mandatory = false})
	        end
			SGK.ResourcesManager.LoadAsync(view[SGK.UIReference],"prefabs/effect/UI/jues_appear",function (temp)
				local HeroOBJ = GetUIParent(temp,obj.transform)
				local HeroView = CS.SGK.UIReference.Setup(HeroOBJ)
				local Animation = HeroView.jues_appear_ani.jues.gameObject:GetComponent(typeof(CS.Spine.Unity.SkeletonAnimation));
				DispatchEvent("stop_automationBtn",{automation = false,mandatory = false})

				local _mode = showDetail and heroInfo.mode_id or heroInfo.__cfg.mode
				local _name = showDetail and heroInfo.name or heroInfo.__cfg.name
				local _title = showDetail and heroInfo.pinYin or heroInfo.__cfg.info_title
				local _info = showDetail and heroInfo.info or heroInfo.__cfg.info

				Animation.skeletonDataAsset = SGK.ResourcesManager.Load("roles/".._mode.."/".._mode.."_SkeletonData");
				Animation:Initialize(true);
				HeroView.jues_appear_ani.name_Text[UnityEngine.TextMesh].text = _name
				HeroView.jues_appear_ani.name_Text[1][UnityEngine.TextMesh].text = _name
				HeroView.jues_appear_ani.name_Text[2][UnityEngine.TextMesh].text = _name
				HeroView.jues_appear_ani.name2_Text[UnityEngine.TextMesh].text = _title

				HeroView.jues_appear_ani.bai_tiao:SetActive(not not showDetail)
				HeroView.jues_appear_ani.bai_tiao.sanj_jsjs_bai.jies_Text[UnityEngine.TextMesh].text = _info
	            if delectTime then
	                HeroView.transform:DOLocalMove(Vector3(0, 0, 0), delectTime):OnComplete(function ( ... )
	                    _removeFunc()
	                end)
	            end
	        end)
			view.Exit[CS.UGUIClickEventListener].onClick = function ( ... )
				_removeFunc()
			end
		else
			ERROR_LOG(nil,"配置表role_info中"..id.."不存在")
		end
	end
end
function SGKTools.CloseFrame()
	DialogStack.Pop()
--[[
	if #DialogStack.GetPref_stact() > 0 or #DialogStack.GetStack() > 0 or SceneStack.Count() > 1 then
		DispatchEvent("KEYDOWN_ESCAPE")
	end
--]]
end
function SGKTools.CloseStory()
	DispatchEvent("CloseStoryReset")
end
function SGKTools.loadEffect(name,id,data)--给NPC或玩家身上加载一个特效
    if id then
    	local _npc = module.NPCModule.GetNPCALL(id)
        if _npc then
        	if _npc.effect_list and _npc.effect_list[name] then
        		_npc.effect_list[name]:SetActive(false)
        		_npc.effect_list[name]:SetActive(true)
        	else
           		module.NPCModule.LoadNpcEffect(id,name)
           end
        end
    else
    	if not data or not data.pid then
    		if not data then
	    		data = {pid = module.playerModule.GetSelfID()}
	    	else
	    		data.pid = module.playerModule.GetSelfID()
	    	end
    	end
    	DispatchEvent("loadPlayerEffect",{name = name,data = data})
    end
end
function SGKTools.DelEffect(name,id,data)--删除npc或玩家身上某个特效
	if id then
    	local _npc = module.NPCModule.GetNPCALL(id)
        if _npc then
        	if _npc.effect_list and _npc.effect_list[name] then
        		if SGKTools.GameObject_null(_npc.effect_list[name]) == false then
	        		UnityEngine.GameObject.Destroy(_npc.effect_list[name].gameObject)
	        	end
	        	_npc.effect_list[name] = nil
           end
        end
    else
    	if not data or not data.pid then
        	DispatchEvent("DelPlayerEffect",{name = name,data = {pid = module.playerModule.GetSelfID()}})
        else
        	DispatchEvent("DelPlayerEffect",{name = name,data = data})
        end
    end
end
function SGKTools.SynchronousPlayStatus(data)
	local NetworkService = require "utils.NetworkService"
    NetworkService.Send(18046, {nil,data})--向地图中其他人发送刷新玩家战斗信息
end
function SGKTools.TeamAssembled()--队伍集结
	module.TeamModule.SyncTeamData(111)
end
function SGKTools.EffectGather(fun,icon,desc,delay)
	if not delay then
		local _item = SGK.ResourcesManager.Load("prefabs/effect/UI/fx_woring_ui")
		local _obj = CS.UnityEngine.GameObject.Instantiate(_item, UnityEngine.GameObject.FindWithTag("UGUIRootTop").transform)
		local _view = CS.SGK.UIReference.Setup(_obj)
		_view.fx_woring_ui_1.gzz_ani.text_working[UI.Text].text = desc or "采集中"
		_view.fx_woring_ui_1.gzz_ani.icon_working[UI.Image]:LoadSprite("icon/" .. icon)
		UnityEngine.GameObject.Destroy(_obj, 2)
	else
		local _item = SGK.ResourcesManager.Load("prefabs/effect/UI/fx_working_ui_n")
		local _obj=CS.UnityEngine.GameObject.Instantiate(_item,UnityEngine.GameObject.FindWithTag("UGUIRootTop").transform)
		local _view = CS.SGK.UIReference.Setup(_obj)

		_view.fx_working_ui_n.gzzing_ani.ui.text_working[UI.Text].text = desc or SGK.Localize:getInstance():getValue("zhuangyuan_caiji_01")
		_view.fx_working_ui_n.gzzing_ani.ui.icon_working[UI.Image]:LoadSprite("icon/" .. icon)

		_view.fx_working_ui_n.gzzing_ani.ui.huan[UI.Image]:DOFillAmount(1,delay):OnComplete(function()
			_view.fx_working_ui_n.gzzing_ani[UnityEngine.Animator]:Play("ui_working_2")
			_item.transform:DOScale(Vector3.one,1):OnComplete(function()
				CS.UnityEngine.GameObject.Destroy(_obj)
			end)
		end)
	end
end

function SGKTools.loadEffectVec3(name,Vec3,time,lock,fun,scale)--加载一个全屏的UI特效
	local eff = GetUIParent(SGK.ResourcesManager.Load("prefabs/effect/"..name),UnityEngine.GameObject.FindWithTag("UGUIRootTop"))
	local _scale = scale or 100
	eff.transform.localScale = Vector3(_scale,_scale,_scale)
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
	if loadSceneEffectArr[name] then
		return;
	end

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
		SGK.Action.DelayTime.Create(time):OnComplete(function()
			if fun then	fun() end
			if lockView then
				UnityEngine.GameObject.Destroy(lockView.gameObject)
			end
		end)
	end
end

function SGKTools.DestroySceneEffect(name,time,fun)
	if not loadSceneEffectArr[name] then
		return;
	end

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
local _PopUpQueueData_now = nil
local _PopUpQueuelock = false
function SGKTools.PopUpQueue(_type,data)
	if _type and data then
		_PopUpQueueData[#_PopUpQueueData + 1] = {_type,data}
	else
		_PopUpQueuelock = false
	end
	--ERROR_LOG(_PopUpQueueType.." "..sprinttb(_PopUpQueueData))
	-- ERROR_LOG(sprinttb(_PopUpQueueData))
	-- ERROR_LOG(#_PopUpQueueData,_PopUpQueueType)
	if (#_PopUpQueueData > 0 and _PopUpQueuelock == false) then
		_PopUpQueueType = _PopUpQueueData[1][1]
		_PopUpQueueData_now = _PopUpQueueData[1]
		table.remove(_PopUpQueueData,1)
		_PopUpQueuelock = true
		if _PopUpQueueType == 1 then--获得物品
			DispatchEvent("GetItemTips",_PopUpQueueData_now[2],function ( ... )
				SGKTools.PopUpQueue()
			end)
			local count = #_PopUpQueueData
			for i = 1,count do
				if _PopUpQueueData[i][1] == 1 then
					local temp = _PopUpQueueData[i]
					table.remove(_PopUpQueueData,i)
					SGKTools.PopUpQueue(temp[1],temp[2])
					break
				end
			end
		elseif _PopUpQueueType == 2 then--完成任务
			DispatchEvent("QUEST_FINISH",function ( ... )
				SGKTools.PopUpQueue()
			end);
		elseif _PopUpQueueType == 3 then--主角升级
			SGKTools.loadEffect("UI/fx_map_lv_up",nil,{fun = function ( ... )
				SGKTools.PopUpQueue()
			end,time = 1.5})
		elseif _PopUpQueueType == 4 then--获得英雄
			SGKTools.HeroShow(_PopUpQueueData_now[2],function ( ... )
				SGKTools.PopUpQueue()
			end)
		elseif _PopUpQueueType == 5 then--获得称号
			SGKTools.ShowTitleInfoChangeTip(_PopUpQueueData_now[2][1],function ( ... )
			 	SGKTools.PopUpQueue()
			end);
		elseif _PopUpQueueType == 6 then--章节结束
			SGKTools.StoryEndEffectCallBack(_PopUpQueueData_now[2],function ( ... )
				SGKTools.PopUpQueue()
			end)
		elseif _PopUpQueueType == 7 then--排行榜超越通知结束
			SGKTools.RankListChangeTipShow(_PopUpQueueData_now[2],function ( ... )
				SGKTools.PopUpQueue()
			end)
        elseif _PopUpQueueType == 8 then--成就
            DialogStack.PushPref("mapSceneUI/achievementNode", _PopUpQueueData_now[2])
        elseif  _PopUpQueueType == 9 then--学会图纸
			SGKTools.LearnedDrawingTipShow(_PopUpQueueData_now[2],function ( ... )
				SGKTools.PopUpQueue()
			end)
		elseif  _PopUpQueueType == 10 then--获得Buff
			SGKTools.GetBuffTipShow(_PopUpQueueData_now[2],function ( ... )
				SGKTools.PopUpQueue()
			end)
		end
	elseif #_PopUpQueueData > 0 and _PopUpQueueType == 1 and _PopUpQueueType == _PopUpQueueData[#_PopUpQueueData][1] then
		DispatchEvent("GetItemTips",_PopUpQueueData[#_PopUpQueueData][2],function ( ... )
			SGKTools.PopUpQueue()
		end)
		table.remove(_PopUpQueueData,#_PopUpQueueData)
		local count = #_PopUpQueueData
		for i = 1,count do
			if _PopUpQueueData[i][1] == 1 then
				local temp = _PopUpQueueData[i]
				table.remove(_PopUpQueueData,i)
				SGKTools.PopUpQueue(temp[1],temp[2])
				break
			end
		end
	elseif #_PopUpQueueData > 0 and _PopUpQueueData[#_PopUpQueueData][1] == 4 then
		local idx = nil
		if _PopUpQueueData_now[2] == _PopUpQueueData[#_PopUpQueueData][2] then
			idx = #_PopUpQueueData
		else
			for i = 1 ,#_PopUpQueueData - 1 do
				if _PopUpQueueData[i][2] == _PopUpQueueData[#_PopUpQueueData][2] then
					idx = #_PopUpQueueData
				end
			end
		end
		if idx then
			table.remove(_PopUpQueueData,idx)
		end
	end
end

function SGKTools.SetNPCTimeScale(id,TimeScale)
	if id then
		module.NPCModule.GetNPCALL(id).Root.spine[CS.Spine.Unity.SkeletonAnimation].timeScale = TimeScale
	end
end

function SGKTools.PLayerConceal(status,duration,delay)
	DispatchEvent("PLayer_Shielding",{pid = module.playerModule.GetSelfID(),x = (status and 0 or 1),status = true,duration = duration,delay = delay})
end

function SGKTools.TeamConceal(status,duration,delay)
	local members = module.TeamModule.GetTeamMembers()
	for k,v in ipairs(members) do
		DispatchEvent("PLayer_Shielding",{pid = v.pid,x = (status and 0 or 1),status = true,duration = duration,delay = delay})
	end
end

function SGKTools.TeamScript(value)--全队执行脚本
	module.TeamModule.SyncTeamData(109,value)
end

function SGKTools.PlayerMoveZERO()--脱离卡位
	DispatchEvent("MAP_CHARACTER_MOVE_Player", {module.playerModule.GetSelfID(), 0, 0, 0, true});
end

function SGKTools.PlayerMove(x, y, z, pid)
	DispatchEvent("MAP_CHARACTER_MOVE_Player", {pid or module.playerModule.GetSelfID(), x, y, z});
end

function SGKTools.PlayerTransfer(x,y,z)--瞬移
	DispatchEvent("MAP_CHARACTER_MOVE_Player", {module.playerModule.GetSelfID(), x, y, z, true});
end

function SGKTools.ChangeMapPlayerMode(mode)
	DispatchEvent("MAP_FORCE_PLAYER_MODE", {pid = module.playerModule.GetSelfID(), mode = mode});
end

local ScrollingMarqueeView = nil
local ScrollingMarqueeOBJ = nil
local ScrollingMarqueeDesc = {}
local ScrollingMarquee_lock = true
local IsMove = false
function SGKTools.ScrollingMarquee_Change(lock)
	ScrollingMarquee_lock = lock
end

function SGKTools.showScrollingMarquee(desc,level)
	if ScrollingMarquee_lock then
		return
	end
	local parent = UnityEngine.GameObject.FindWithTag("UITopRoot")
	if desc then
		if level then
			ScrollingMarqueeDesc[#ScrollingMarqueeDesc+1] = {desc = desc,level = level}
		else
			ScrollingMarqueeDesc[#ScrollingMarqueeDesc+1] = {desc = desc,level = 0}
		end
		table.sort(ScrollingMarqueeDesc,function (a,b)
			return a.level > b.level
		end)
		--ERROR_LOG(sprinttb(ScrollingMarqueeDesc))
	end
	if not parent then
		return
	end
	if #ScrollingMarqueeDesc > 0 then
		if ScrollingMarqueeOBJ == nil then
			ScrollingMarqueeOBJ = GetUIParent(SGK.ResourcesManager.Load("prefabs/ScrollingMarquee"),parent)
			ScrollingMarqueeView = CS.SGK.UIReference.Setup(ScrollingMarqueeOBJ)
		end
		if IsMove == false then
			IsMove = true
			ScrollingMarqueeView.bg.desc[UnityEngine.UI.Text].text = ScrollingMarqueeDesc[1].desc
			table.remove(ScrollingMarqueeDesc,1)
			ScrollingMarqueeView[UnityEngine.CanvasGroup]:DOFade(1,0.5):OnComplete(function( ... )
				if #ScrollingMarqueeDesc == 0 and ScrollingMarqueeOBJ then
					ScrollingMarqueeView[UnityEngine.CanvasGroup]:DOFade(0,3):SetDelay(5)
				end
				ScrollingMarqueeView.bg.desc.transform:DOLocalMove(Vector3(-(276+ScrollingMarqueeView.bg.desc[UnityEngine.RectTransform].sizeDelta.x),0,0),10):OnComplete(function( ... )
					IsMove = false
					ScrollingMarqueeView.bg.desc.transform.localPosition = Vector3(276,0,0)
					SGKTools.showScrollingMarquee()
				end)--:SetEase(CS.DG.Tweening.Ease.InOutQuint)
			end)
		end
	elseif ScrollingMarqueeOBJ then
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
			view.Root.group[Toggle[i]]:SetActive(true)
			if Toggle[i] == 2 then
				local FriendData = module.FriendModule.GetManager(1,pid)
				view.Root.group[Toggle[i]].Text[UnityEngine.UI.Text].text = FriendData and FriendData.care == 1 and "取消关注" or "特别关注"
			elseif Toggle[i] == 5 then
				view.Root.group[Toggle[i]].Text[UnityEngine.UI.Text].text = ""
				module.TeamModule.GetPlayerTeam(pid,true,function( ... )
					local ClickTeamInfo = module.TeamModule.GetClickTeamInfo(pid)
					if ClickTeamInfo and ClickTeamInfo.members and ClickTeamInfo.members[1] and module.TeamModule.GetTeamInfo().id <= 0 then
						view.Root.group[Toggle[i]].Text[UnityEngine.UI.Text].text = "申请入队"
					else
						view.Root.group[Toggle[i]].Text[UnityEngine.UI.Text].text = "邀请入队"
					end
				end)
			end
			view.Root.group[Toggle[i]][CS.UGUIClickEventListener].onClick = function ( ... )
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
					local ChatDataList = {}
					if data then
						for i = 1,#data do
							ChatDataList[i] = data[i]
						end
					end
					local ChatData = module.ChatModule.GetManager(8)
					if ChatData and ChatData[pid] then
						ChatData = ChatData[pid]
						for i = 1,#ChatData do
							if ChatData[i].status == 1 then
								local FriendData = module.FriendModule.GetManager(nil,pid)
								if FriendData and (FriendData.type == 1 or FriendData.type == 3) then
									--utils.NetworkService.Send(5005,{nil,{{ChatData[i].id,2}}})--已读取加好友通知
								end
							else
								ChatDataList[#ChatDataList+1] = ChatData[i]
							end
						end
					end
					table.sort(ChatDataList,function(a,b)
						return a.time < b.time
					end)
					-- local list = {data = ChatDataList,pid = pid}
					-- DialogStack.PushPref("FriendChat",list,UnityEngine.GameObject.FindWithTag("UGUIRootTop").gameObject)
					DispatchEvent("FriendSystemlist_indexChange",{i = 1,pid = pid,name = module.playerModule.IsDataExist(pid).name})
					--SGKTools.FriendChat()
				elseif Toggle[i] == 4 then--邀请入团
					 if module.unionModule.Manage:GetUionId() == 0 then
                        showDlgError(nil, "您还没有公会")
                    elseif module.unionModule.GetPlayerUnioInfo(pid).unionId ~= nil and module.unionModule.GetPlayerUnioInfo(pid).unionId ~= 0 then
                        showDlgError(nil, "该玩家已有公会")
                    else
                    	local PlayerInfoHelper = require "utils.PlayerInfoHelper"
                    	local openLevel = require "config.openLevel"
						PlayerInfoHelper.GetPlayerAddData(pid, 7, function(addData)
							local level = module.playerModule.Get(pid).level
                 			if openLevel.GetStatus(2101,level) then
							--if addData.UnionStatus then
								if addData.RefuseUnion then
                 					showDlgError(nil,"对方已设置拒绝邀请")
                 				else
                        			module.unionModule.Invite(pid)
                        		end
                        	else
                        		showDlgError(nil,"对方未开启公会功能")
                        	end
                        end,true)
                    end
				elseif Toggle[i] == 5 then--邀请入队
					-- local teamInfo = module.TeamModule.GetTeamInfo();
     --            	if teamInfo.group ~= 0 then
					-- 	module.TeamModule.Invite(pid)
					-- else
					-- 	showDlgError(nil,"请先创建一个队伍")
					-- end
					if view.Root.group[Toggle[i]].Text[UnityEngine.UI.Text].text == "申请入队" then
						local ClickTeamInfo = module.TeamModule.GetClickTeamInfo(pid)
                        if ClickTeamInfo.upper_limit == 0 or (module.playerModule.Get().level >= ClickTeamInfo.lower_limit and  module.playerModule.Get().level <= ClickTeamInfo.upper_limit) then
                            module.TeamModule.JoinTeam(ClickTeamInfo.members[3])
                        else
                            showDlgError(nil,"你的等级不满足对方的要求")
                        end
					else
						local PlayerInfoHelper = require "utils.PlayerInfoHelper"
						local openLevel = require "config.openLevel"
						PlayerInfoHelper.GetPlayerAddData(pid, 7, function(addData)
                 			--ERROR_LOG(sprinttb(addData))
                 			--if addData.TeamStatus then
                 			local level = module.playerModule.Get(pid).level
                 			if openLevel.GetStatus(1601,level) then
                 				if addData.RefuseTeam then
                 					showDlgError(nil,"对方已设置拒绝邀请")
                 				else
									if module.TeamModule.GetTeamInfo().id <= 0 then
				                        module.TeamModule.CreateTeam(999,function ( ... )
				                            module.TeamModule.Invite(pid);
				                        end);--创建空队伍并邀请对方
				                    else
				                        module.TeamModule.Invite(pid);
				                    end
			    				end
			                else
			                	showDlgError(nil,"对方未开启组队功能")
		     				end
	                    end,true)
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
				elseif Toggle[i] == 8 then--礼物
					DialogStack.PushPref("FriendBribeTaking",{pid = pid,name = module.playerModule.IsDataExist(pid).name},view.transform.parent.gameObject)
				elseif Toggle[i] == 9 then--进入基地
					utils.MapHelper.EnterOthersManor(pid)
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
	local teamInfo = module.TeamModule.GetTeamInfo() or {}
	return (teamInfo.group ~= 0)
end

---true为队长
function SGKTools.isTeamLeader()
    local teamInfo = module.TeamModule.GetTeamInfo() or {}
    return (teamInfo.leader and teamInfo.leader.pid) and (module.playerModule.Get().id == teamInfo.leader.pid)
end

function SGKTools.CheckPlayerMode(mode)--查询玩家形象是否匹配
	local addData=utils.PlayerInfoHelper.GetPlayerAddData(0,8)
	return addData.ActorShow==mode
end

function SGKTools.ChecHeroFashionSuit(suitId,heroId)--查询Hero时装是否匹配
	local hero=utils.ItemHelper.Get(utils.ItemHelper.TYPE.HERO, heroId)
	return hero.showMode==suitId
end

function SGKTools.InToDefensiveFortress()--进入元素暴走
	print("队长请求进入 元素暴走活动")
	if SceneStack.GetBattleStatus() then
        showDlgError(nil, "战斗内无法进行该操作")
    else
    	local NetworkService = require "utils.NetworkService"
		NetworkService.Send(16127)
    end
end

function SGKTools.CheckDialog()
    if SceneStack.GetBattleStatus() then
        showDlgError(nil, "战斗内无法进行该操作")
        return false
    end
    if utils.SGKTools.GetTeamState() then
        showDlgError(nil, "队伍内无法进行该操作")
        return false
    end
    return true
end

function SGKTools.OpenGuildPvp( ... )
	local teamInfo = module.TeamModule.GetTeamInfo();
	if SceneStack.GetBattleStatus() or teamInfo.id > 0 then
		DialogStack.Push("guild_pvp/GuildPVPJoinPanel")
	else
		if SGKTools.isAlreadyJoined() then
			SceneStack.Push("GuildPVPPreparation", "view/guild_pvp/GuildPVPPreparation.lua")
		else
			DialogStack.Push("guild_pvp/GuildPVPJoinPanel")
		end
	end
end

function SGKTools.isAlreadyJoined( ... )
    local guild = module.unionModule.Manage:GetSelfUnion();
    if guild == nil then
        return false;
    end
    local GuildPVPGroupModule = require "guild.pvp.module.group"
    local list = GuildPVPGroupModule.GetGuildList();
    for _, v in ipairs(list) do
        if v.id == guild.id then
            return true
        end
    end
    return false;
end

function SGKTools.UnionPvpState()
    return true
    -- local GuildPVPGroupModule = require "guild.pvp.module.group"
    -- local status,fight_status = GuildPVPGroupModule.GetStatus();
    -- if GuildPVPGroupModule.GetMinOrder() == nil or GuildPVPGroupModule.GetMinOrder() == 1 or status == 0 then
    --     return true
    -- end
    -- showDlgError(nil, "公会战中无法操作")
    -- return false
end

function SGKTools.ClearMapPlayer(status)--是否清除地图所有玩家并锁定生成
	DispatchEvent("ClearMapPlayer",status)
end

function SGKTools.ShieldingMapPlayer()--屏蔽地图玩家
    local Shielding = module.MapModule.GetShielding()
    module.MapModule.SetShielding(not Shielding)
    Shielding = not Shielding
    local map_list = module.TeamModule.GetMapTeam()--拿到地图上所有队伍数据
    local teamInfo = module.TeamModule.GetTeamInfo()
    --ERROR_LOG(sprinttb(map_list))
    for k,v in pairs(map_list) do
        for i = 1,#v[2] do
            if teamInfo.id <= 0 or (teamInfo.id > 0 and v[3] ~= teamInfo.id) then
                DispatchEvent("PLayer_Shielding",{pid = v[2][i],x = (Shielding and 0 or 0.5)})
            end
        end
    end
    local MapGetPlayers = module.TeamModule.MapGetPlayers()
    for k,v in pairs(MapGetPlayers)do
        --ERROR_LOG(k)
        if module.playerModule.GetSelfID() ~= k then
            DispatchEvent("PLayer_Shielding",{pid = k,x = (Shielding and 0 or 0.5)})
        end
    end
end

function SGKTools.StoryEndEffect(desc1,desc2,desc3)--剧情某一章节结束特效
	utils.SGKTools.PopUpQueue(6,{desc1,desc2,desc3})
end

function SGKTools.StoryEndEffectCallBack(data,fun)
	local desc1,desc2,desc3 = data[1],data[2],data[3]
	local obj = UnityEngine.GameObject.Instantiate(SGK.ResourcesManager.Load("prefabs/Effect/UI/jvqing_end"))
	local LockMapObj = GetUIParent(SGK.ResourcesManager.Load("prefabs/LockFrame"))
	local LockMapObj_view = CS.SGK.UIReference.Setup(LockMapObj)
	local _view = CS.SGK.UIReference.Setup(obj)
	_view.end_ani.tiedoor_2.zhanjie[UnityEngine.TextMesh].text = desc1
	_view.end_ani.tiedoor_2.biaoti[UnityEngine.TextMesh].text = desc2
	_view.end_ani.tiedoor_2.kaiqi[UnityEngine.TextMesh].text = desc3
	LockMapObj_view[CS.UGUIClickEventListener].onClick = function ( ... )
		_view.end_ani[UnityEngine.Animator]:Play("tiedoor_ani2")
		SGK.Action.DelayTime.Create(1):OnComplete(function()
			UnityEngine.GameObject.Destroy(obj)
			UnityEngine.GameObject.Destroy(LockMapObj)
			if fun then
				fun()
			end
		end)
	end
end

function SGKTools.Iphone_18(fun_1,fun_2, info)
	local obj = GetUIParent(SGK.ResourcesManager.Load("prefabs/Iphone18"))
	local _view = CS.SGK.UIReference.Setup(obj)
	local _anim = _view.phone_bg[UnityEngine.Animator]
	if info then
		_view.phone_bg.Text[UI.Text].text = info.text
	end
	SGK.BackgroundMusicService.Pause()
	_anim:Play("phone_ani1")
	SGK.Action.DelayTime.Create(0.3):OnComplete(function()
        if info and info.soundName then
		    _view[SGK.AudioSourceVolumeController]:Play("sound/"..info.soundName)
        end
		_anim:Play("phone_ani2")
	end)
	_view.phone_bg.yBtn[CS.UGUIClickEventListener].onClick = function ( ... )
		_anim:Play("phone_ani3")
		SGK.Action.DelayTime.Create(0.5):OnComplete(function()
			SGK.BackgroundMusicService.UnPause()
            if fun_1 then
    			fun_1()
    		end
            UnityEngine.GameObject.Destroy(obj)
		end)
	end
	_view.phone_bg.nBtn[CS.UGUIClickEventListener].onClick = function ( ... )
		_anim:Play("phone_ani4")
		SGK.Action.DelayTime.Create(0.5):OnComplete(function()
			SGK.BackgroundMusicService.UnPause()
            if fun_2 then
    			fun_2()
    		end
            UnityEngine.GameObject.Destroy(obj)
		end)
	end
end

function SGKTools.ShowTaskItem(conf,fun,parent)
	--ERROR_LOG(sprinttb(conf))
	local ItemList = {}
	if conf.reward_id1 ~= 0 and conf.reward_id1 ~= 90036 then--必得
		ItemList[#ItemList+1] = {type = conf.reward_type1,id = conf.reward_id1,count = conf.reward_value1,mark =1}
	end
	if conf.reward_id2 ~= 0 and conf.reward_id2 ~= 90036 then--必得
		ItemList[#ItemList+1] = {type = conf.reward_type2,id = conf.reward_id2,count = conf.reward_value2,mark = 1}
	end
	if conf.reward_id3 ~= 0 and conf.reward_id3 ~= 90036 then--必得
		ItemList[#ItemList+1] = {type = conf.reward_type3,id = conf.reward_id3,count = conf.reward_value3,mark = 1}
	end
	if conf.drop_id ~= 0 then
		local Fight_reward = SmallTeamDungeonConf.GetFight_reward(conf.drop_id)
		if Fight_reward then
            local _level = module.HeroModule.GetManager():Get(11000).level
			for i = 1,#Fight_reward do
                if _level >= Fight_reward[i].level_limit_min and _level <= Fight_reward[i].level_limit_max then
    				local repetition = false
    				for j = 1,#ItemList do
    					if ItemList[j].id == Fight_reward[i].id then
    						repetition = true
    						break
    					end
    				end
    				if not repetition then
    					ItemList[#ItemList+1] = {type = Fight_reward[i].type,id = Fight_reward[i].id,count = 0,mark = 2}--概率获得
    				end
                end
			end
		end
	end
	local ItemHelper = require "utils.ItemHelper"
	local list = {}
	for i = 1,#ItemList do
        if i > 6 then
            break
        end
		local item = ItemHelper.Get(ItemList[i].type, ItemList[i].id);
		if item.id ~= 199999 and (ItemList[i].type ~= ItemHelper.TYPE.ITEM or item.cfg.is_show == 1) then
			list[#list+1] = ItemList[i]
		end
	end
	DialogStack.PushPrefStact("mapSceneUI/GiftBoxPre", {itemTab = list,interactable = true, fun = fun,textName = "<size=40>任</size>务报酬",textDesc = "",not_exit = true},parent or UnityEngine.GameObject.FindWithTag("UGUIRootTop").gameObject.transform)
end

function SGKTools.NpcTalking(npc_gid)
	--npc对话闲聊
	local npcConfig = require "config.npcConfig"
	local MapConfig = require "config.MapConfig"
	local gid = MapConfig.GetMapMonsterConf(npc_gid).npc_id
	if gid == 0 then
		ERROR_LOG("all_npc表里的gid列的"..npc_gid.."在config_arguments_npc表中的npc_id列中不存在")
		return
	end
	local NpcTalkingList = npcConfig.Get_npc_talking(gid)
	local NpcList = npcConfig.GetNpcFriendList()
	local item_id = NpcList[gid].arguments_item_id
	local value = module.ItemModule.GetItemCount(item_id)
	local name = npcConfig.GetnpcList()[gid].name
	local suitable_npc_list = {}
	--ERROR_LOG(tostring(value),sprinttb(NpcTalkingList))
	if NpcTalkingList then
		local weight_sum = 0
		for i =1,#NpcTalkingList do
			if value >= NpcTalkingList[i].min and value <= NpcTalkingList[i].max then
				weight_sum = weight_sum + NpcTalkingList[i].weight
				suitable_npc_list[#suitable_npc_list+1] = NpcTalkingList[i]
			end
		end
		local rom = math.random(1,weight_sum)
		weight_sum = 0
		for i = 1,#suitable_npc_list do
			weight_sum = weight_sum + suitable_npc_list[i].weight
			if rom <= weight_sum then
				local shop_id = suitable_npc_list[i].shop_type
				local shop_item_gid = suitable_npc_list[i].shop_gid
				if shop_id ~= 0 then
					module.ShopModule.GetManager(shop_id)
				end
				LoadStory(suitable_npc_list[i].story_id,function ( ... )
					--ERROR_LOG(shop_id,shop_item_gid)
					if shop_id ~= 0 then
						local shop_item_list = module.ShopModule.GetManager(shop_id).shoplist[shop_item_gid].product_item_list
						--ERROR_LOG(shop_id,shop_item_gid,sprinttb(module.ShopModule.GetManager(shop_id).shoplist))
						local old_value = value
						module.ShopModule.Buy(shop_id,shop_item_gid,1,nil,function( ... )
							local now_value = module.ItemModule.GetItemCount(item_id) - value
							if now_value >= 1 then
								showDlgError(nil,SGK.Localize:getInstance():getValue("haogandu_npc_tips_01",name,"+"..now_value))
							end
						end)
					end
				end)
				return
			end
		end
	end
end

function SGKTools.FlyItem(pos,itemlist)
	--local parent = UnityEngine.GameObject.FindWithTag("UITopRoot")
	local parent = UnityEngine.GameObject.FindWithTag("UGUIRootTop")
	local IconFrameHelper = require "utils.IconFrameHelper"
	local ItemHelper = require "utils.ItemHelper"
	for i = 1,#itemlist do
		local ItemIconView = nil
		if itemlist[i].type == ItemHelper.TYPE.HERO then
			ItemIconView = IconFrameHelper.Hero({id = itemlist[i].id,count = itemlist[i].count,showDetail = false},parent,nil,0.8)
		else
			ItemIconView = IconFrameHelper.Item({type=itemlist[i].type,id = itemlist[i].id,count = itemlist[i].count,showDetail = false},parent,nil,0.8)
		end
		ItemIconView.transform.position = Vector3(itemlist[i].pos[1],itemlist[i].pos[2],itemlist[i].pos[3])
		ItemIconView.transform:DOMove(Vector3(pos[1],pos[2],pos[3]),1):OnComplete(function( ... )
			ItemIconView:AddComponent(typeof(UnityEngine.CanvasGroup)):DOFade(0,0.5):OnComplete(function( ... )
				UnityEngine.GameObject.Destroy(ItemIconView.gameObject)
			end)--:SetDelay(1)
		end)
	end
end

function SGKTools.GetNPCBribeValue(npc_id)
	local ItemModule = require "module.ItemModule"
	local npcConfig = require "config.npcConfig"
	local npc_Friend_cfg = npcConfig.GetNpcFriendList()[npc_id]
	local relation = StringSplit(npc_Friend_cfg.qinmi_max,"|")
	local relation_desc = StringSplit(npc_Friend_cfg.qinmi_name,"|")
	local relation_value = ItemModule.GetItemCount(npc_Friend_cfg.arguments_item_id)
	local relation_index = 0
	for i = 1,#relation do
		if relation_value >= tonumber(relation[i]) then
			relation_index = i
		end
	end
	return relation_value,relation_index
end

function SGKTools.OpenNPCBribeView(npc_id)
	local ItemModule = require "module.ItemModule"
	local npcConfig = require "config.npcConfig"
	local npc_Friend_cfg = npcConfig.GetNpcFriendList()[npc_id]
	DialogStack.PushPref("npcBribeTaking",{id = npc_Friend_cfg.npc_id,item_id = npc_Friend_cfg.arguments_item_id})
end

function SGKTools.FriendChat(pid,name,desc)
	local ChatManager = require 'module.ChatModule'
	ChatManager.SetManager({fromid = pid,fromname = name,title = desc},1,3)--0聊天显示方向1右2左
end

--好友排行榜名次变化Tip
function SGKTools.RankListChangeTipShow(data,func)
	local tempObj = SGK.ResourcesManager.Load("prefabs/rankList/rankListChangeTip")
	local obj = nil;
	local UIRoot = UnityEngine.GameObject.FindWithTag("UITopRoot")
	if UIRoot then
		obj = CS.UnityEngine.GameObject.Instantiate(tempObj,UIRoot.gameObject.transform)
	end
	local TipsRoot = CS.SGK.UIReference.Setup(obj)
	local _view=TipsRoot.view
	local type=data and data.type
	local pids=data and data.pids

	CS.UGUIClickEventListener.Get(TipsRoot.mask.gameObject, true).onClick = function()
		if func then
			func()
		end
		UnityEngine.GameObject.Destroy(obj);
	end

	local RankListModule = require "module.RankListModule"
	local rankCfg=RankListModule.GetRankCfg(type)

	local desc= SGK.Localize:getInstance():getValue("paihangbang_tongzhihaoyou_01",SGK.Localize:getInstance():getValue(rankCfg.name))
	_view.item.typeText[UI.Text].text=SGK.Localize:getInstance():getValue(rankCfg.name)
	_view.item.Text[UI.Text].text="超越好友!"

	_view.Icon[UI.Image]:LoadSprite("rankList/"..rankCfg.icon)
	_view.item.Icon[UI.Image]:LoadSprite("rankList/"..rankCfg.icon);

	CS.UGUIClickEventListener.Get(_view.Button.gameObject).onClick = function()
		for i=1,#pids do
			local _pid=pids[i]
			local _name=module.playerModule.IsDataExist(_pid).name
			SGKTools.FriendChat(_pid,_name,desc)
		end
		if func then
			func()
		end
		UnityEngine.GameObject.Destroy(obj);
	end
end

--学会图纸Tip
function SGKTools.LearnedDrawingTipShow(data,func)
	local tempObj = SGK.ResourcesManager.Load("prefabs/Tips/LearnedDrawingTip")
	local obj = nil;
	local UIRoot = UnityEngine.GameObject.FindWithTag("UITopRoot")
	if UIRoot then
		obj = CS.UnityEngine.GameObject.Instantiate(tempObj,UIRoot.gameObject.transform)
	end
	local TipsRoot = CS.SGK.UIReference.Setup(obj)
	local _view=TipsRoot.Dialog

	local _id=data and data[1]

	local _item=utils.ItemHelper.Get(utils.ItemHelper.TYPE.ITEM,_id);
	_view.Content.IconFrame[SGK.LuaBehaviour]:Call("Create",{customCfg=setmetatable({count=0},{__index=_item})});
	_view.Content.Image.tip.Text[UI.Text].text=_item.name

	CS.UGUIClickEventListener.Get(_view.Content.Btns.Ensure.gameObject).onClick = function()
		local ManorManufactureModule = require "module.ManorManufactureModule"
		ManorManufactureModule.ShowProductSource(_id)
		if func then
			func()
		end
		UnityEngine.GameObject.Destroy(obj);
	end

	local _DoClosefunc=function()
		if func then
			func()
		end
		UnityEngine.GameObject.Destroy(obj);
	end
	CS.UGUIClickEventListener.Get(_view.Content.Btns.Cancel.gameObject).onClick = _DoClosefunc
	CS.UGUIClickEventListener.Get(TipsRoot.gameObject, true).onClick = _DoClosefunc
	CS.UGUIClickEventListener.Get(_view.Close.gameObject).onClick = _DoClosefunc
end

--获得BuffTip
function SGKTools.GetBuffTipShow(data,func)
	local tempObj = SGK.ResourcesManager.Load("prefabs/Tips/GetBuffTip")
	local obj = nil;
	local UIRoot = UnityEngine.GameObject.FindWithTag("UITopRoot")
	if UIRoot then
		obj = CS.UnityEngine.GameObject.Instantiate(tempObj,UIRoot.gameObject.transform)
	end
	local TipsRoot = CS.SGK.UIReference.Setup(obj)
	local _view = TipsRoot.view

	CS.UGUIClickEventListener.Get(_view.mask.gameObject, true).onClick = function()
		if func then
			func()
		end
		UnityEngine.GameObject.Destroy(obj);
	end
	local _buffId,_value = data[1],data[2]
	local heroBuffModule = require "hero.HeroBuffModule"
	local buffCfg = heroBuffModule.GetBuffConfig(_buffId)
	if buffCfg then
		if buffCfg.hero_id ~=0 then
			_view.item.Icon[UI.Image]:LoadSprite("icon/" ..buffCfg.hero_id)
		end
		local ParameterConf = require "config.ParameterShowInfo";
		_view.item.Image.Text[UI.Text]:TextFormat("{0}<color=#8A4CC7FF>+{1}</color>", ParameterConf.Get(buffCfg.type).name, _value * buffCfg.value);
	end
end
--通过modeId 检查mode是否存在，不存在则返回默认mode
--path="roles_small/"  or "roles/"  or "manor/qipao/"
--suffix="_SkeletonData" or "_Material"
function SGKTools.loadExistSkeletonDataAsset(path,HeroId,mode,suffix)
	HeroId = HeroId or 11000
	suffix = suffix or "_SkeletonData"
	local skeletonDataAsset = SGK.ResourcesManager.Load(path..mode.."/"..mode..suffix);
	if skeletonDataAsset == nil then
		local defaultMode = module.HeroHelper.GetDefaultMode(HeroId) or 11000;
		skeletonDataAsset = SGK.ResourcesManager.Load(path..defaultMode.."/"..defaultMode..suffix) or SGK.ResourcesManager.Load(path.."11000/11000"..suffix)
	end
	return skeletonDataAsset
end

--点击显示 Item name
--ori--0(Arrow target Top) 1(Arrow target bottom)
--off_y
function SGKTools.ShowItemNameTip(node,str,ori,off_y)
	local Arrangement={["Top"]=0,["Bottom"]=1}
	local _orientation=ori or Arrangement.Top
	local _off_y=off_y or 0
	local objClone
	CS.UGUIPointerEventListener.Get(node.gameObject, true).onPointerDown = function(go, pos)
		objClone=CS.UnityEngine.GameObject.Instantiate(SGK.ResourcesManager.Load("prefabs/base/ClickTipItem"),node.transform)
		local view=CS.SGK.UIReference.Setup(objClone)
		view.Text[UI.Text].text=str or ""

		view.topArrow:SetActive(_orientation == Arrangement.Top);
		view.bottomArrow:SetActive(_orientation == Arrangement.Bottom);
		if _orientation == Arrangement.Top then
			view[UnityEngine.RectTransform].pivot = CS.UnityEngine.Vector2(0,1);
			view[UnityEngine.RectTransform].anchoredPosition = CS.UnityEngine.Vector2(-20,-off_y);
		else
			view[UnityEngine.RectTransform].pivot = CS.UnityEngine.Vector2(0.5, 0);
			view[UnityEngine.RectTransform].anchoredPosition = CS.UnityEngine.Vector2(0,_off_y);
		end
		view:SetActive(true)
		view.transform:DOScale(Vector3.one,0.1):OnComplete(function ( ... )
			view[UnityEngine.CanvasGroup].alpha =  1
    	end)
	end
	CS.UGUIPointerEventListener.Get(node.gameObject, true).onPointerUp = function(go, pos)
		if objClone then
			CS.UnityEngine.GameObject.Destroy(objClone)
		end
	end
end

--称号 进度 变换 tip
local GetTitleView = nil
local get_title_tips = nil
local maxQuality = 4
function SGKTools.ShowTitleInfoChangeTip(id,fun)
	local Cfg=module.TitleModule.GetTitleCfgByItem(tonumber(id))
	if GetTitleView == nil then
		if get_title_tips then
			table.insert(get_title_tips, {id, fun});
			return;
		end

		get_title_tips = {}
		table.insert(get_title_tips, {id, fun});

		SGK.ResourcesManager.LoadAsync("prefabs/Tips/GetTitleTip", function(tempObj)
			local _get_title_tips={}
			for k,v in pairs(get_title_tips) do
				_get_title_tips[k]=v
			end
			get_title_tips=nil
			local obj =  CS.UnityEngine.GameObject.Instantiate(tempObj, UnityEngine.GameObject.FindWithTag("UITopRoot").gameObject.transform)
			GetTitleView = CS.SGK.UIReference.Setup(obj)

			for _,v in pairs(_get_title_tips) do
				SGKTools.ShowTitleInfoChangeTip(v[1], v[2]);
			end
			local delay = 6
			for i=delay,1,-1 do
				GetTitleView.transform:DOScale(Vector3.one, i):OnComplete(function()
					GetTitleView.view.bottom.timer[UI.Text].text = string.format("%ss后自动关闭",delay-i)
				end)
			end
			SGK.Action.DelayTime.Create(delay):OnComplete(function()
				if GetTitleView then
					CS.UnityEngine.GameObject.Destroy(GetTitleView.gameObject)
					GetTitleView = nil
					if fun then
						fun()
					end
				end
			end)

			CS.UGUIClickEventListener.Get(GetTitleView.view.bottom.toUseBtn.gameObject).onClick = function (obj)
				CS.UnityEngine.GameObject.Destroy(GetTitleView.gameObject)
				GetTitleView= nil
				if fun then
					fun()
				end
				if Cfg.role_id~=0 then
					local _hero = module.HeroModule.GetManager():Get(Cfg.role_id)
					if _hero then
						DialogStack.PushPrefStact("newRole/roleTitleFrame", {roleID =Cfg.role_id,Idx=1})
					else
						DialogStack.PushPrefStact("newRole/roleTitleFrame", {roleID =11000,Idx=3,quality=Cfg.quality})
					end
				else
					local owners=module.TitleModule.GetTitleOwners(Cfg.gid)
					local _GetOwner = false
					for k,v in pairs(owners) do
						if module.HeroModule.GetManager():Get(v) then
							DialogStack.PushPrefStact("newRole/roleTitleFrame", {roleID =v,Idx=1})
							_GetOwner = true
							break
						end
					end
					if not _GetOwner then
						DialogStack.PushPrefStact("newRole/roleTitleFrame", {roleID =11000,Idx=3,quality=Cfg.quality})
					end
				end
			end

			CS.UGUIClickEventListener.Get(GetTitleView.view.bottom.infoBtn.gameObject).onClick = function (obj)
				CS.UnityEngine.GameObject.Destroy(GetTitleView.gameObject)
				GetTitleView = nil
				if fun then
					fun()
				end
				if Cfg.role_id~=0 then
					local _hero = module.HeroModule.GetManager():Get(Cfg.role_id)
					if Cfg.quality < maxQuality then
						DialogStack.PushPrefStact("newRole/roleTitleFrame", {roleID =_hero and Cfg.role_id or 11000,Idx=2,titleId = Cfg.gid})
					else
						DialogStack.PushPrefStact("newRole/roleTitleFrame", {roleID =_hero and Cfg.role_id or 11000,Idx=1})
					end
				else
					local owners=module.TitleModule.GetTitleOwners(Cfg.gid)
					local _GetOwner = false
					for k,v in pairs(owners) do
						if module.HeroModule.GetManager():Get(v) then
							if Cfg.quality < maxQuality then
								DialogStack.PushPrefStact("newRole/roleTitleFrame", {roleID =v,Idx=2,titleId = Cfg.gid})
							else
								DialogStack.PushPrefStact("newRole/roleTitleFrame", {roleID =v,Idx=1})
							end
							_GetOwner = true
							break
						end
					end
					if not _GetOwner then
						if Cfg.quality < maxQuality then
							DialogStack.PushPrefStact("newRole/roleTitleFrame", {roleID =11000,Idx=2,titleId = Cfg.gid})
						else
							DialogStack.PushPrefStact("newRole/roleTitleFrame", {roleID =11000,Idx=1})
						end
					end
				end
			end

			CS.UGUIClickEventListener.Get(GetTitleView.view.mask.gameObject,true).onClick = function (obj)
				CS.UnityEngine.GameObject.Destroy(GetTitleView.gameObject)
				GetTitleView = nil
				if fun then
					fun()
				end
			end
		end)
		return;
	end
	if Cfg then
		GetTitleView.view.ShowItem.titleItem[SGK.TitleItem]:SetInfo(Cfg)
		GetTitleView.view.ShowItem.info.Text[UI.Text].text = Cfg.name

		local count = module.ItemModule.GetItemCount(id)

		if count<=3 then
			for i=1,count -1 do
				GetTitleView.view.ShowItem.info.status.progress[i][UI.Image].fillAmount = 1
			end
			GetTitleView.transform:DOScale(Vector3.one, 1):OnComplete(function()
				GetTitleView.view.ShowItem.info.status.progress[count][UI.Image]:DOFillAmount(1, 0.5):OnComplete(function()
					GetTitleView.view.bottom.toUseBtn:SetActive(count>=3)
					GetTitleView.view.bottom.infoBtn:SetActive(count<3)
					GetTitleView.view.bottom.timer:SetActive(true)
				end)
			end)
		end
	end
end

function SGKTools.ShowDlgHelp(desc,title,parent)
	local tempObj = SGK.ResourcesManager.Load("prefabs/base/ShowDlgHelp")
	local obj = nil;
    local UIRoot = parent or UnityEngine.GameObject.FindWithTag("UITopRoot")
    if UIRoot then
        obj = CS.UnityEngine.GameObject.Instantiate(tempObj,UIRoot.gameObject.transform)
    end
    local TipsRoot = CS.SGK.UIReference.Setup(obj)
    TipsRoot.Dialog.Btn.Text[UI.Text].text = "知道了"
    if desc then
    	TipsRoot.Dialog.describe[UI.Text].text = desc
    end
    if title then
    	TipsRoot.Dialog.Title[UI.Text].text = title
    end
    TipsRoot.mask[CS.UGUIClickEventListener].onClick = function ( ... )
    	UnityEngine.GameObject.Destroy(obj);
    end
    TipsRoot.Dialog.Close[CS.UGUIClickEventListener].onClick = function ( ... )
    	UnityEngine.GameObject.Destroy(obj);
    end
    TipsRoot.Dialog.Btn[CS.UGUIClickEventListener].onClick = function ( ... )
    	UnityEngine.GameObject.Destroy(obj);
    end
end
function SGKTools.OpenActivityTeamList(Activity_id)
	--showDlgError(nil,"暂无开放")
	local list = {}
	list[2] = {id = Activity_id}
	DialogStack.Push('TeamFrame',{idx = 2,viewDatas = list});
end
function SGKTools.StartActivityMatching(Activity_id)
	local TeamModule = require "module.TeamModule"
	local ActivityTeamlist = require "config.activityConfig"
	if Activity_id then
		local cfg = ActivityTeamlist.Get_all_activity(Activity_id)
		if cfg then
			showDlgError(nil,"正在匹配"..cfg.name)
			TeamModule.playerMatching(Activity_id)
		end
	end
end

function SGKTools.matchingName(name)
    if not name then
        return ""
    end
    if string.len(name) < 12 then
        return name
    end
    local _a = string.sub(name, 1, 5)
    local _b = string.sub(name, -6)
    if _a == "<SGK>" and _b == "</SGK>" then
        return "陆水银"
    end
    return name
end

function SGKTools.PlayDestroyAnim(view)
    if view and utils.SGKTools.GameObject_null(view) == false then
        local _dialogAnim = view:GetComponent(typeof(SGK.DialogAnim))
        --if _dialogAnim and string.sub(tostring(_dialogAnim), 1, 5) ~= "null:" then
        if _dialogAnim and utils.SGKTools.GameObject_null(_dialogAnim) == false then
            local co = coroutine.running()
            _dialogAnim.destroyCallBack = function()
                coroutine.resume(co)
            end
            _dialogAnim:PlayDestroyAnim()
            coroutine.yield()
        end
    end
end
local function ROUND(t)
	local START_TIME = 1467302400
	local PERIOD_TIME = 3600 * 24
    return math.floor((t-START_TIME)/PERIOD_TIME);
end

local function random_range(rng, min, max)
	local WELLRNG512a_ = require "WELLRNG512a"
    assert(min <= max)
    local v  = WELLRNG512a_.value(rng);
    return min + (v % (max - min + 1))
end

function SGKTools.GetTeamPveIndex(id)
	local WELLRNG512a_ = require "WELLRNG512a"
	local Time = require "module.Time"
	return random_range(WELLRNG512a_.new(id + ROUND(Time.now())), 1, 4);
end

function SGKTools.GetGuildTreasureIndex(id,index)
	local WELLRNG512a_ = require "WELLRNG512a"
	local Time = require "module.Time"
	return random_range(WELLRNG512a_.new(id + ROUND(Time.now())), 1, index);
end

function SGKTools.GameObject_null(obj)
	if string.sub(tostring(obj), 1, 5) == "null:" then
		return true
	elseif tostring(obj) == "null: 0" then
		return true
	elseif obj == nil then
		return true
	end
	return false
end
function SGKTools.StartTeamFight(gid)
	utils.NetworkService.Send(16070, {nil,gid})
end
function SGKTools.TaskQuery(id)
	local taskConf = require "config.taskConf"
	local quest_id = module.QuestModule.GetCfg(id).next_quest_menu
	return taskConf.Getquest_menu(quest_id)
end
function SGKTools.NpcChatData(pid,desc)
	local ChatManager = require 'module.ChatModule'
	local npcConfig = require "config.npcConfig"
	local cfg = npcConfig.GetnpcList()[pid]
	if cfg then
		ChatManager.SetData({nil,nil,{pid,cfg.name,1},6,desc})
	else
		showDlgError(nil,"npcid->"..gid.."在true_npc表中不存在")
	end
end
function SGKTools.UpdateNpcDirection(npc_id,pid)
	pid = pid or module.playerModule.Get().id
	DispatchEvent("UpdateNpcDirection_playerinfo",{pid = pid,npc_id = npc_id})
end
function SGKTools.ResetNpcDirection(npc_id)
	DispatchEvent("UpdateNpcDirection_npcinfo",{gid = npc_id})
end
function SGKTools.GetQuestColor(iconName, desc)
	if iconName == "bg_rw_1" then
		desc = string.format("<color=#00A99FFF>%s</color>", desc)
	elseif iconName == "bg_rw_2" then
		desc = string.format("<color=#CC7504FF>%s</color>", desc)
	elseif iconName == "bg_rw_3" then
		--desc = string.format("<color=#CC7504FF>%s</color>", desc)
	elseif iconName == "bg_rw_4" then
		desc = string.format("<color=#D75D67FF>%s</color>", desc)
	elseif iconName == "bg_rw_5" then
		desc = string.format("<color=#1371B2FF>%s</color>", desc)
	elseif iconName == "bg_rw_6" then
		desc = string.format("<color=#9118C3FF>%s</color>", desc)
	elseif iconName == "bg_rw_7" then
		desc = string.format("<color=#898E00FF>%s</color>", desc)
	elseif iconName == "bg_rw_8" then
		desc = string.format("<color=#3AA400FF>%s</color>", desc)
	end
	return desc
end
function SGKTools.get_title_frame(str)
	local title = ""
	local num = string.len(str)
	for i = 1,math.floor(num/3) do
		local start = (i-1) * 3 + 1
		if i == 1 then
			title = "<size=44>"..str:sub(start, start + 2).."</size>"
		else
			title = title..str:sub(start, start + 2)
		end
	end
	return title
end
local activityConfig = require "config.activityConfig";
function SGKTools.GetActivityIDByQuest(quest_id)
	return activityConfig.GetActivityCfgByQuest(quest_id);
end

function SGKTools.MapCameraMoveTo(npc_id)
	local controller = UnityEngine.GameObject.FindObjectOfType(typeof(SGK.MapSceneController));
	if not controller then
		return;
	end

	if not npc_id then
		controller:ControllPlayer(module.playerModule.GetSelfID())
	else
		local obj = module.NPCModule.GetNPCALL(npc_id)
		if obj then
			controller:ControllPlayer(0);
			controller.playerCamera.target = obj.transform;
		end
	end
end

-- event 1 - 10 已经使用
function SGKTools.MapBroadCastEvent(event, data)
	utils.NetworkService.Send(18046, {nil,{event, module.playerModule.GetSelfID(), data}})--向地图中其他人发送消息
end

return SGKTools
