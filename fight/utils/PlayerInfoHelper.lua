local NetworkService = require "utils.NetworkService"
local EventManager = require 'utils.EventManager';
local UnionConfig = require "config.unionConfig"

local function GetSelfBaseInfo(fun)
    local selfPid=module.playerModule.GetSelfID()
    if module.playerModule.IsDataExist(selfPid) then
        local player=module.playerModule.Get(selfPid);
        fun(player)
    else
        module.playerModule.Get(selfPid,function ( ... )
            local player=module.playerModule.Get(selfPid);
            fun(player)
        end)
    end
end

local function GetSelfUnionInfo()
    local _unionInfo={}
    local uninInfo=module.unionModule.Manage:GetSelfUnion()
    if uninInfo then
        for k,v in pairs(uninInfo) do
            _unionInfo[k]=v
        end
        _unionInfo["showMemberNumber"]=string.format("%s/%s",uninInfo.mcount,UnionConfig.GetNumber(uninInfo.unionLevel).MaxNumber + uninInfo.memberBuyCount)
    end
    return _unionInfo
end

local function GetSelfUnionMemberTitle()
    local titleIdx=module.unionModule.Manage:GetSelfTitle()
    local unionInfo=GetSelfUnionInfo()
    return unionInfo and next(unionInfo)~=nil and UnionConfig.GetCompetence(titleIdx).Name or "无"
end

local function GetLocalPvpInfo(pvpInfo)
   return string.format("%s 第%s名",module.PVPArenaModule.GetRankName(pvpInfo.wealth),pvpInfo.rank)
end

local PlayersSnFunction = {}
local function GetSelfPvpInfo(fun)
    local pvpInfo=module.PVPArenaModule.GetPlayerInfo()
    if pvpInfo then
        local info=GetLocalPvpInfo(pvpInfo)
        fun(info,pvpInfo) 
    else
        PlayersSnFunction["GetSelfPvpInfo"] =fun
    end
end

local playerProvince=nil
local function loadPlayerProvince()
    if not playerProvince then
        playerProvince = LoadDatabaseWithKey("wanjia_province","gid")
    end
    return playerProvince
end

--个人信息面板统计资源
local totalShowTab = nil
local function GetTotalShow()
    if not totalShowTab then
        totalShowTab = {}
        DATABASE.ForEach("role_rewardinfo", function(data)
            if data.id~=2 then--屏蔽血海争锋
               table.insert(totalShowTab,data)
            end
        end)
    end
    return totalShowTab
end

local totalShowInfo={}
local function GetTotalShowInfo()
    local totalInfo=GetTotalShow()
    for i=1,#totalInfo do
        totalShowInfo[i]={   
            totalInfo[i].double_id~=0 and module.ItemModule.GetItemCount(totalInfo[i].double_id) or nil,
            totalInfo[i].single_id~=0 and module.ItemModule.GetItemCount(totalInfo[i].single_id) or nil,
            totalInfo[i].info,totalInfo[i].name
        }
    end
    return totalShowInfo
end

--更换玩家 hero 和道具 排序改变
local function SortListByGetted(list)
    local info = {};
    for _,v in pairs(list) do
        if v.hero==0 then
            table.insert(info,setmetatable({order = 1,index=v.index,isLocked=false},{__index=v}));
        elseif v.hero==1 then
            if module.HeroModule.GetManager():Get(tonumber(v.id)) then
                table.insert(info,setmetatable({order = 2,index=v.index,isLocked=false},{__index=v}));
            else
                table.insert(info,setmetatable({order = 4,index=v.index,isLocked=true},{__index=v}));
            end
        else 
            local _hero=module.HeroModule.GetManager():Get(v.id)
            if _hero and _hero.items[v.hero] and _hero.items[v.hero]>0 then
                table.insert(info,setmetatable({order = 3,index=v.index,isLocked=false},{__index=v}));
            else
                local canExchange=false
                if _hero then
                    local product = module.ShopModule.GetManager(8,v.hero) and module.ShopModule.GetManager(8,v.hero)[1];
                    if product then
                        local consumeId=product.consume_item_id1
                        local consumePrice=product.consume_item_value1
                        local targetGid=product.gid
                        local ownCount=module.ItemModule.GetItemCount(consumeId)
                        if ownCount>=consumePrice then
                            module.ShopModule.BuyTarget(8,targetGid,1,_hero.uuid)
                            table.insert(info,setmetatable({order = 3,index=v.index,isLocked=true},{__index=v}));
                            canExchange=true
                        end
                    end
                end
                if not canExchange then
                    table.insert(info,setmetatable({order = 5,index=v.index,isLocked=true},{__index=v}));
                end
            end
        end
    end
    table.sort(info,function(a,b)
        if a.order~=b.order then
            return a.order<b.order
        end
        return tonumber(a.index)<tonumber(b.index)
    end)
    return info
end

local ShowModeTab = nil
local function GetPlayerModeCfg(mode)
    if not ShowModeTab then
        ShowModeTab = {}
        DATABASE.ForEach("role_chose", function(data)
            ShowModeTab[data.mode]=data
        end);
    end
    if mode then
        return  ShowModeTab[mode] --and ShowModeTab[mode] or ShowModeTab[11048]
    else
        return SortListByGetted(ShowModeTab)
    end   
end

local ShowHeadIconTab = nil
local function GetHeadIconCfg(headIcon)
    if not ShowHeadIconTab then
        ShowHeadIconTab = {}
        DATABASE.ForEach("avatar_picture", function(data)
            ShowHeadIconTab[data.icon]=data
        end);
    end
    if headIcon then
        return ShowHeadIconTab[headIcon] --and  ShowHeadIconTab[headIcon] or ShowHeadIconTab[11048]
    else
        return SortListByGetted(ShowHeadIconTab) 
    end
end

local showItemsList={}
local showItemByActivityType={}
local function GetShowItemList(type)
    if showItemsList[type] == nil then
        showItemsList[type]={}
        showItemByActivityType[type]={}
        
        local list={}
        if type ==99 then
            list=module.ItemModule.GetShowItemCfg(nil,70)
            local list_2=module.ItemModule.GetShowItemCfg(nil,75)
          
            for k,v in pairs(list_2) do
                list[#list+1]=v
            end
        else
            list=module.ItemModule.GetShowItemCfg(nil,type)
        end
        
        for i,v in ipairs(list) do
            local cfg=utils.ItemHelper.Get(utils.ItemHelper.TYPE.ITEM,v.id)
            local _temp=setmetatable({type=utils.ItemHelper.TYPE.ITEM,effect=v.effect,effect_type=v.effect_type,group=v.group},{__index=cfg})
            table.insert(showItemsList[type],_temp)
            if v.group then
                showItemByActivityType[type][v.group]=showItemByActivityType[type][v.group] or {}
                table.insert(showItemByActivityType[type][v.group],_temp)
            end
        end
    end
    if showItemsList[type] then
        table.sort(showItemsList[type],function(a,b)
            local count1=module.ItemModule.GetItemCount(a.id)
            local count2=module.ItemModule.GetItemCount(b.id)
            if count1~=count2 then
                return count1>count2
            end
            return a.id<b.id  
        end)
    end
    
    return showItemsList[type] or {}
end

local function GetShowItemByActivityType(type,group)
    if not showItemsList[type] then
        GetShowItemList(type)
    end
    if group then
        return showItemByActivityType[type][group]        
    end
    return showItemByActivityType[type]
end

utils.EventManager.getInstance():addListener("ARENA_GET_PLAYER_INFO_SUCCESS", function(event, uuid)
    local pvpInfo=module.PVPArenaModule.GetPlayerInfo()
    if pvpInfo then
        local info=GetLocalPvpInfo(pvpInfo)
        if PlayersSnFunction["GetSelfPvpInfo"] then
           PlayersSnFunction["GetSelfPvpInfo"](info,pvpInfo)
           PlayersSnFunction["GetSelfPvpInfo"]=nil 
        end  
    end
end)

--72头像框   73 "心悦头衔"  74"心悦挂件" 75 "心悦足迹" 76气泡框
local ServerAddDataType= {
    BASEDATA=1,
    HEADFRAME = 2,--头像框
    WIDGETANDFOOTPRINT = 3,--挂件 =75,--足迹
    BUBBLE=4,--气泡框
    -- FASHIONSUIT=9,--时装
    UNIONANDTEAMSTATUS=10001,--自动拒绝加入公会     自动拒绝组队
    
    TITLEFOLLOWID=6,--被追踪的称号Id
    ACTIVITYSTATUS=7,--活动状态 开启状态1组队 2好友 3公会
    ACTORSHOW=8,--主角当前形象
    COMMUNICATIONREFUSESTATUS=9,--拒绝1组队 2好友 3公会
    PVPARENASTATUS=10,--竞技场开启状态

    ALLADDDATA=99,--全类型
};

local ChangePlayerAddDataSn = {}
local playerAddData={}
local PlayerAddDataSnFunction = {}
local function updatePlayerAddData(pid,data)
    local _data={}--按type存
    for i=1,#data do
        _data[data[i][1]]=data[i]
    end

    playerAddData[pid]=playerAddData[pid] or {}
    
    local playerOldData={}
    for k,v in pairs(playerAddData[pid]) do
        playerOldData[k]=v
    end

    playerAddData[pid].Area=_data[ServerAddDataType.BASEDATA] and _data[ServerAddDataType.BASEDATA][2] or playerAddData[pid].Area or 0
    playerAddData[pid].Sex=_data[ServerAddDataType.BASEDATA] and _data[ServerAddDataType.BASEDATA][3] or playerAddData[pid].Sex or 0
    playerAddData[pid].PersonDesc=_data[ServerAddDataType.BASEDATA] and _data[ServerAddDataType.BASEDATA][5] or playerAddData[pid].PersonDesc or ""

    playerAddData[pid].HeadFrameId=_data[ServerAddDataType.HEADFRAME] and _data[ServerAddDataType.HEADFRAME][2] or playerAddData[pid].HeadFrameId or 0
    
    local headIconCfg = module.ItemModule.GetShowItemCfg(playerAddData[pid].HeadFrameId)
    playerAddData[pid].HeadFrame=headIconCfg and headIconCfg.effect or ""

    playerAddData[pid].Widget=_data[ServerAddDataType.WIDGETANDFOOTPRINT] and _data[ServerAddDataType.WIDGETANDFOOTPRINT][2] or playerAddData[pid].Widget or 0
    playerAddData[pid].FootPrint=_data[ServerAddDataType.WIDGETANDFOOTPRINT] and _data[ServerAddDataType.WIDGETANDFOOTPRINT][3] or playerAddData[pid].FootPrint or 0

    playerAddData[pid].Bubble=_data[ServerAddDataType.BUBBLE] and _data[ServerAddDataType.BUBBLE][2] or playerAddData[pid].Bubble or 0       
    
    playerAddData[pid].TeamStatus=playerAddData[pid].TeamStatus or false
    playerAddData[pid].FriendStatus=playerAddData[pid].FriendStatus or false
    playerAddData[pid].UnionStatus=playerAddData[pid].UnionStatus or false
    if _data[ServerAddDataType.ACTIVITYSTATUS] then
        playerAddData[pid].TeamStatus=_data[ServerAddDataType.ACTIVITYSTATUS][2]==1 and true or false
        playerAddData[pid].FriendStatus=_data[ServerAddDataType.ACTIVITYSTATUS][3]==1 and true or false
        playerAddData[pid].UnionStatus=_data[ServerAddDataType.ACTIVITYSTATUS][4]==1 and true or false
    end

    playerAddData[pid].UnionAndTeamInviteStatus=playerAddData[pid].UnionAndTeamInviteStatus or false
    if _data[ServerAddDataType.UNIONANDTEAMSTATUS] then
        playerAddData[pid].UnionAndTeamInviteStatus=_data[ServerAddDataType.UNIONANDTEAMSTATUS][2]==1 and true or false
    end

    --false为不拒绝
    playerAddData[pid].RefuseTeam=playerAddData[pid].RefuseTeam or false
    playerAddData[pid].RefuseFriend=playerAddData[pid].RefuseFriend or false
    playerAddData[pid].RefuseUnion=playerAddData[pid].RefuseUnion or false
    if _data[ServerAddDataType.COMMUNICATIONREFUSESTATUS] then--默认同意 false
        playerAddData[pid].RefuseTeam=_data[ServerAddDataType.COMMUNICATIONREFUSESTATUS][2]==1 and true or false
        playerAddData[pid].RefuseFriend=_data[ServerAddDataType.COMMUNICATIONREFUSESTATUS][3]==1 and true or false
        playerAddData[pid].RefuseUnion=_data[ServerAddDataType.COMMUNICATIONREFUSESTATUS][4]==1 and true or false
    end

    playerAddData[pid].FollowTitleId=_data[ServerAddDataType.TITLEFOLLOWID] and _data[ServerAddDataType.TITLEFOLLOWID][2] or playerAddData[pid].FollowTitleId or 0
    playerAddData[pid].FollowHero=_data[ServerAddDataType.TITLEFOLLOWID] and _data[ServerAddDataType.TITLEFOLLOWID][3] or playerAddData[pid].FollowHero or 0
    
    playerAddData[pid].ActorShow=_data[ServerAddDataType.ACTORSHOW] and _data[ServerAddDataType.ACTORSHOW][2] or playerAddData[pid].ActorShow 
    
    if not playerAddData[pid].ActorShow or playerAddData[pid].ActorShow==0 then
        if pid <100000 then--Npc
            if module.playerModule.IsDataExist(pid) then
                local player=module.playerModule.Get(pid);
                if player then--npc 通过头像去 获得对应mode      
                    playerAddData[pid].ActorShow=GetHeadIconCfg(player.head).npc_mode
                else
                    playerAddData[pid].ActorShow=11048
                end
            else
                module.playerModule.Get(pid,function ( ... )
                    local player=module.playerModule.Get(pid);
                    if player then      
                        playerAddData[pid].ActorShow=GetHeadIconCfg(player.head).npc_mode
                    else
                        playerAddData[pid].ActorShow=11048
                    end
                    DispatchEvent("PLAYER_ADDDATA_CHANGE",pid);
                end)
            end
        else
            playerAddData[pid].ActorShow=11048
        end
    end 
    
    playerAddData[pid].PvpArenaStatus=_data[ServerAddDataType.PVPARENASTATUS] and _data[ServerAddDataType.PVPARENASTATUS][2]==1 and true or false
  
    local changeDataTab={}
    for k,v in pairs(playerAddData[pid]) do
        if playerOldData[k]==nil or (playerOldData[k]~=v )then
            changeDataTab[k]=v
        end
    end
    DispatchEvent("PLAYER_ADDDATA_CHANGE",pid,changeDataTab);--玩家的附加信息改变
end

local PlayerQueryTimeTab={}
local PlayerAddDataSnFunction = {}
local delayTime=60*5
local function QueryPlayerAddData(pid,type,func,Reget)--Reget是否重新获取
    if not pid or pid == 0 then
        pid =module.playerModule.GetSelfID()
    end
    local typeTab={}
    if type then
        if type==99 then
            typeTab={
                        ServerAddDataType.BASEDATA,
                        ServerAddDataType.HEADFRAME,
                        ServerAddDataType.WIDGETANDFOOTPRINT,
                        ServerAddDataType.BUBBLE,
                        ServerAddDataType.UNIONANDTEAMSTATUS,
                        ServerAddDataType.ACTIVITYSTATUS,
                        ServerAddDataType.TITLEFOLLOWID,
                        ServerAddDataType.ACTORSHOW,
                        ServerAddDataType.COMMUNICATIONREFUSESTATUS,
                        ServerAddDataType.PVPARENASTATUS,
                    }
        else
            typeTab={type}
        end
    end
    if not PlayerQueryTimeTab[pid] or (PlayerQueryTimeTab[pid] and module.Time.now()-PlayerQueryTimeTab[pid]<delayTime) then
        if playerAddData[pid] == nil or Reget  then
            local sn=NetworkService.Send(17081, {nil,pid,typeTab})
            PlayerAddDataSnFunction[sn]=func
            return nil
        else
            if type then
                local addData={}
                if type==ServerAddDataType.BASEDATA then
                    addData.Area=playerAddData[pid].Area or 2
                    addData.Sex=playerAddData[pid].Sex or 0
                    addData.PersonDesc=playerAddData[pid].PersonDesc or ""
                    if func then
                        func(addData)
                    end
                    return addData
                elseif type==ServerAddDataType.HEADFRAME then
                    addData.HeadFrameId=playerAddData[pid].HeadFrameId or 0
                    addData.HeadFrame=playerAddData[pid].HeadFrame or ""
                    -- addData.HonorFrame=playerAddData[pid].HonorFrame or 0
                    if func then
                        func(addData)
                    end
                    return addData
                elseif type==ServerAddDataType.WIDGETANDFOOTPRINT then
                    addData.Widget  = playerAddData[pid].Widget or 0
                    addData.FootPrint = playerAddData[pid].FootPrint or 0

                    if func then
                        func(addData)
                    end
                    return addData
                elseif type==ServerAddDataType.BUBBLE then
                    addData.Bubble=playerAddData[pid].Bubble or 0
                    if func then
                        func(addData)
                    end
                    return addData
                elseif type==ServerAddDataType.TITLEFOLLOWID then
                    addData.FollowTitleId=playerAddData[pid].FollowTitleId or 0
                    addData.FollowHero=playerAddData[pid].FollowHero or 0
                    if func then
                        func(addData)
                    end
                    return addData
                elseif type==ServerAddDataType.ACTIVITYSTATUS then
                    addData.TeamStatus=playerAddData[pid].TeamStatus or false
                    addData.FriendStatus=playerAddData[pid].FriendStatus or false
                    addData.UnionStatus=playerAddData[pid].UnionStatus or false

                    if func then
                        func(addData)
                    end
                    return addData
                elseif type==ServerAddDataType.ACTORSHOW then
                    addData.ActorShow=playerAddData[pid].ActorShow or 11048
                    if func then
                        func(addData)
                    end
                    return addData    
                elseif type==ServerAddDataType.UNIONANDTEAMSTATUS then
                    addData.UnionAndTeamInviteStatus=playerAddData[pid].UnionAndTeamInviteStatus or false
                    if func then
                        func(addData)
                    end
                    return addData
                elseif type==ServerAddDataType.COMMUNICATIONREFUSESTATUS then
                    addData.RefuseTeam= playerAddData[pid].RefuseTeam or false
                    addData.RefuseFriend=playerAddData[pid].RefuseFriend or false
                    addData.RefuseUnion=playerAddData[pid].RefuseUnion or false
                    if func then
                        func(addData)
                    end
                    return addData
                elseif type==ServerAddDataType.PVPARENASTATUS then--默认显示为未开启
                    addData.PvpArenaStatus=playerAddData[pid].PvpArenaStatus or false
                    if func then
                        func(addData)
                    end
                    return addData
                else
                    if func then
                        func(playerAddData[pid])
                    end
                    return playerAddData[pid]; 
                end     
            else
                if func then
                    func(playerAddData[pid])
                end
                return playerAddData[pid]; 
            end 
        end
    else 
        local sn=NetworkService.Send(17081, {nil,pid,typeTab})
        PlayerAddDataSnFunction[sn]=func
        return nil
    end
end

EventManager.getInstance():addListener("server_respond_17082", function(event, cmd, data)
    local err = data[2];
    if err == 0 then
        if data[3] and data[4]  then
            PlayerQueryTimeTab[math.floor(data[3])]=module.Time.now()
            updatePlayerAddData(math.floor(data[3]),data[4])

            if PlayerAddDataSnFunction[data[1]] then
                PlayerAddDataSnFunction[data[1]](playerAddData[math.floor(data[3])])
                PlayerAddDataSnFunction[data[1]]=nil
            end
        end
    else
        showDlgError(nil,"查询失败 "..err)
        return;
    end 
end)

local PlayerAddDataSnData = {}
EventManager.getInstance():addListener("server_respond_17084", function(event, cmd, data)
    -- ERROR_LOG("修改成功",sprinttb(data))
    local sn = data[1]
    local err = data[2];
    if err == 0 then
        if data[3] and data[4]  then
            local _pid = data[3]
            NetworkService.Send(18046, {nil,{3,_pid}})--向地图中其他人发送刷新玩家装饰信息
            updatePlayerAddData(math.floor(data[3]),{data[4]})
            if PlayerAddDataSnData[sn] or PlayerAddDataSnData[sn]==false then
                --ERROR_LOG(PlayerAddDataSnData[sn] )
                DispatchEvent("PLAYER_ADDDATA_CHANGE_SUCCED",PlayerAddDataSnData[sn],data[4][1]);--修改成功 
                PlayerAddDataSnData[sn]=nil
            end 
        end  
    else
        showDlgError(nil,"修改失败 "..err)
    end
end)

local function ChangeArea(Idx)
    local sn=NetworkService.Send(17083, {nil,ServerAddDataType.BASEDATA,{1,Idx}})
    PlayerAddDataSnData[sn]=Idx
end

local function ChangeSex(Idx)
    local sn=NetworkService.Send(17083, {nil,ServerAddDataType.BASEDATA,{2,Idx}})
    PlayerAddDataSnData[sn]=Idx
end

local function ChangePlayerDesc(desc)
    local sn=NetworkService.Send(17083, {nil,ServerAddDataType.BASEDATA,{4,desc}})
    PlayerAddDataSnData[sn]=desc
end

local function ChangeHeadFrame(Id)
    local sn=NetworkService.Send(17083, {nil,ServerAddDataType.HEADFRAME,{1,Id}})
    PlayerAddDataSnData[sn]=Id
end

local function ChangeWidgetShow(Id)
    local sn=NetworkService.Send(17083, {nil,ServerAddDataType.WIDGETANDFOOTPRINT,{1,Id}})
    PlayerAddDataSnData[sn]=Id
end

local function ChangeFootPrintShow(Id)
    local sn=NetworkService.Send(17083, {nil,ServerAddDataType.WIDGETANDFOOTPRINT,{2,Id}})
    PlayerAddDataSnData[sn]=Id
end

local function ChangeBubbleShow(Id)
    local sn=NetworkService.Send(17083, {nil,ServerAddDataType.BUBBLE,{1,Id}})
    PlayerAddDataSnData[sn]=Id
end
--72头像框   73 "心悦头衔"  74"心悦挂件" 75 "心悦足迹" 76气泡框
local function ChangePlayerShowItem(sub_type,Id)
    if sub_type== 74 then
        ChangeWidgetShow(Id)
    elseif sub_type== 75  or sub_type== 70 then
        ChangeFootPrintShow(Id)
    elseif sub_type== 76 then
        ChangeBubbleShow(Id)
    end
end

local function ChangeActorShow(Id)
    local sn=NetworkService.Send(17083, {nil,ServerAddDataType.ACTORSHOW,{1,Id}})
    PlayerAddDataSnData[sn]=Id
end

local function ChangeRefuseTeam(status)
    local value=status and 1 or 0
    local sn=NetworkService.Send(17083, {nil,ServerAddDataType.COMMUNICATIONREFUSESTATUS,{1,value}})
    PlayerAddDataSnData[sn]=status
end

local function ChangePvpArenaStatus(status)
    local value=status and 1 or 0
    local sn=NetworkService.Send(17083, {nil,ServerAddDataType.PVPARENASTATUS,{1,value}})
    PlayerAddDataSnData[sn]=status
end

local function ChangeRefuseFriend(status)
    local value=status and 1 or 0
    local sn=NetworkService.Send(17083, {nil,ServerAddDataType.COMMUNICATIONREFUSESTATUS,{2,value}})
    PlayerAddDataSnData[sn]=status
end

local function ChangeRefuseUnion(status)
    local value=status and 1 or 0
    local sn=NetworkService.Send(17083, {nil,ServerAddDataType.COMMUNICATIONREFUSESTATUS,{3,value}})
    PlayerAddDataSnData[sn]=status
end

local function ChangeUnionAndTeamInviteStatus(status)
    local value=status and 1 or 0
    local sn=NetworkService.Send(17083, {nil,ServerAddDataType.UNIONANDTEAMSTATUS,{1,value}})
    PlayerAddDataSnData[sn]=status

    ChangeRefuseTeam(status)
    ChangeRefuseFriend(status)
    ChangeRefuseUnion(status) 
end

local function changeTitleFollowId(titleId,roleId)
    local sn=NetworkService.Send(17083, {nil,ServerAddDataType.TITLEFOLLOWID,{1,titleId}})
    NetworkService.Send(17083, {nil,ServerAddDataType.TITLEFOLLOWID,{2,roleId}})
    ERROR_LOG(titleId,roleId)
    PlayerAddDataSnData[sn]={titleId,roleId}
end

local function SetActivityStatus(type,index,value)
    -- ERROR_LOG(type,index,value)
    if index==1 then--组队
        if  playerAddData[module.playerModule.GetSelfID()].TeamStatus==value then
            return
        end
    elseif index==2 then--好友
        if  playerAddData[module.playerModule.GetSelfID()].FriendStatus==value then
            return
        end
    elseif index==3 then--公会
        if  playerAddData[module.playerModule.GetSelfID()].UnionStatus==value then
            return
        end
    end
    local sn=NetworkService.Send(17083, {nil,type,{index,value}})
end
--[[
utils.EventManager.getInstance():addListener("HERO_INFO_CHANGE", function(event, data)
    local pid=data
    if playerAddData[pid] then
        if module.playerModule.IsDataExist(pid) then
            local player=module.playerModule.Get(pid);
            playerAddData[pid].ActorShow=module.HeroHelper.GetModeCfg(player.head,pid)
            DispatchEvent("PLAYER_ADDDATA_CHANGE",pid,playerAddData[pid])
        else
            module.playerModule.Get(pid,function ( ... )
                local player=module.playerModule.Get(selfPid);
                playerAddData[pid].ActorShow=module.HeroHelper.GetModeCfg(player.head,pid)
                DispatchEvent("PLAYER_ADDDATA_CHANGE",pid,playerAddData[pid])
            end)
        end 
    end
end)
--]]

return {
    GetSelfBaseInfo=GetSelfBaseInfo,
    GetSelfUnionInfo=GetSelfUnionInfo,

    GetSelfPvpInfo=GetSelfPvpInfo,
    GetSelfUnionMemberTitle= GetSelfUnionMemberTitle,
    GetTotalShow = GetTotalShow,
    GetTotalShowInfo=GetTotalShowInfo,

    GetShowItemList=GetShowItemList,
    --GetHeadIconList=GetHeadIconList,

    GetHeadCfg=GetHeadIconCfg,--获取玩家头像配置
    GetModeCfg=GetPlayerModeCfg,--获取玩家模型配置

    GetShowItemByActivityType=GetShowItemByActivityType,
    GetPlayerProvince=loadPlayerProvince,

    GetPlayerAddData=QueryPlayerAddData,--获取玩家的附加信息

    ServerAddDataType=ServerAddDataType,--信息类型Type

    ChangeArea=ChangeArea,
    ChangeSex=ChangeSex,
    ChangeDesc=ChangePlayerDesc,

    ChangeHeadFrame=ChangeHeadFrame,

    ChangePlayerShowItem=ChangePlayerShowItem,

    ChangeUnionAndTeamInviteStatus=ChangeUnionAndTeamInviteStatus,

    SetActivityStatus=SetActivityStatus,--修改玩家活动状态
    ChangeFollowTitle=changeTitleFollowId,--更改称号追踪

    ChangeActorShow=ChangeActorShow,--主角形象
    ChangePvpArenaStatus=ChangePvpArenaStatus,
}
