local PlayerModule = require "module.playerModule"
local ItemHelper = require "utils.ItemHelper"
local UnionModule = require "module.unionModule"
local PVPArenaModule = require "module.PVPArenaModule";
local UnionConfig = require "config.unionConfig"
local ItemModule=require"module.ItemModule"
local HeroModule = require "module.HeroModule"
local ShopModule = require "module.ShopModule"

local function GetSelfBaseInfo(fun)
    PlayerModule.Get(PlayerModule.GetSelfID(),function ( ... )
        local player=PlayerModule.Get(PlayerModule.GetSelfID());
        fun(player)
    end)
end

local function GetSelfUnionInfo()
    local _unionInfo={}
    local uninInfo=UnionModule.Manage:GetSelfUnion()
    if uninInfo then
        for k,v in pairs(uninInfo) do
            _unionInfo[k]=v
        end
        _unionInfo["showMemberNumber"]=string.format("%s/%s",uninInfo.mcount,UnionConfig.GetNumber(uninInfo.unionLevel).MaxNumber + uninInfo.memberBuyCount)
    end
    return _unionInfo
end

local function GetSelfUnionMemberTitle()
    local titleIdx=UnionModule.Manage:GetSelfTitle()
    local unionInfo=GetSelfUnionInfo()
    return unionInfo and next(unionInfo)~=nil and UnionConfig.GetCompetence(titleIdx).Name or "无"
end
local function GetSelfResources()
    return PlayerModule.GetShowSource()
end

local function GetLocalPvpInfo(pvpInfo)
   return string.format("%s 第%s名",PVPArenaModule.GetRankName(pvpInfo.wealth),pvpInfo.rank)
end

local PlayersSnFunction = {}
local function GetSelfPvpInfo(fun)
    local pvpInfo=PVPArenaModule.GetPlayerInfo()
    if pvpInfo then
        local info=GetLocalPvpInfo(pvpInfo)
        fun(info) 
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

local totalShowTab = nil
local function GetTotalShow()
    if not totalShowTab then
        totalShowTab = {}
        totalShowTab= LoadDatabaseWithKey("role_rewardinfo","id")
    end
    return totalShowTab
end

local totalShowInfo={}
local function GetTotalShowInfo()
    local totalInfo=GetTotalShow()
    for i=1,#totalInfo do
        totalShowInfo[i]={   
            totalInfo[i].double_id~=0 and ItemModule.GetItemCount(totalInfo[i].double_id) or nil,
            totalInfo[i].single_id~=0 and ItemModule.GetItemCount(totalInfo[i].single_id) or nil,
            totalInfo[i].info,totalInfo[i].name
        }
    end
    return totalShowInfo
end

local HonorModule = require "module.honorModule"

local honorInfo=nil
local function GetHonorList()
    if not honorInfo then
        honorInfo={}
        local honorConfig = HonorModule.GetCfg();
        for k,v in pairs(honorConfig) do
            if HonorModule.CheckHonor(v.gid) then
                table.insert(honorInfo, v);
            end
        end
        table.sort(honorInfo,function ( a,b )
            return a.gid < b.gid;
        end)
    end
    return honorInfo
end

local function GetSelfHonor(honorId)
    if honorId then
        return HonorModule.GetCfg(honorId)
    end
    return PlayerModule.Get().honor or 0
end
local function ChangeHonor(honorId)
    PlayerModule.ChangeHonor(honorId);
end

local function ChangeHeadIcon(idx)
    PlayerModule.ChangeIcon(idx)
end

-- local function GetHeadIconList()
--     local IconTab = {}
--     for i,v in pairs(HeroModule.GetManager():Get()) do
--         table.insert(IconTab, {id = i, cfg = v})
--     end
--     return IconTab
-- end
local heroTab=nil
local function GetHeadIcon(id)
    if not heroTab then
        heroTab=HeroModule.GetManager():Get()
    end
    return heroTab[id]
end

local HeroTab=nil
local function GetHeroList()
    if not HeroTab then
        HeroTab={}
        local cfg = HeroModule.GetConfig();
        for k,v in pairs(cfg) do
            table.insert(HeroTab,v)
        end
    end
    table.sort(HeroTab,function(b,a)
        local p1 = GetHeadIcon(b.__cfg.id)
        local p2 = GetHeadIcon(a.__cfg.id)
        if not not p1 and not not  p2  or p1==p2 then
            return b.__cfg.id<a.__cfg.id
        end
        return p1 and true or  false;  
    end)
    return HeroTab
end

ShopModule.GetManager(6)
local function GetHeroFrameInfo(id)
    local product = ShopModule.GetManager(6,id) and ShopModule.GetManager(6,id)[1];
    local info={}
   
    info.piece_id = product and product.consume_item_id1 or 0;
    info.piece_type =product and  product.consume_item_type1 or 0;

    return info
end

local function GetItemCount(id)
    local count=ItemModule.GetItemCount(id) or 0
    return count
end

local showItemsList=nil
local showItemByActivityType={}
local function GetShowItemList(sub_type)
    if showItemsList == nil then
        showItemsList={}
        
        DATABASE.ForEach("touxiangkuang", function(data)
            showItemsList[data.type] =showItemsList[data.type] or {};
            showItemByActivityType[data.type]=showItemByActivityType[data.type] or {}

            local cfg=ItemHelper.Get(ItemHelper.TYPE.ITEM,data.id)
            local Tab={cfg=cfg,name=cfg.name,effect=data.effect,sub_type=data.type}
            table.insert(showItemsList[data.type],Tab);
            if data.group then
                showItemByActivityType[data.type][data.group]=showItemByActivityType[data.type][data.group] or {}
                table.insert(showItemByActivityType[data.type][data.group],Tab);
            end
        end)
    end
    if showItemsList[sub_type] then
        table.sort(showItemsList[sub_type],function(a,b)
            local count1=GetItemCount(a.cfg.id)
            local count2=GetItemCount(b.cfg.id)
            if count1~=count2 then
                return count1>count2
            end
            return a.cfg.id<b.cfg.id  
        end)
    end

    return showItemsList[sub_type] or {}
end

local function GetShowItemByActivityType(type,group)
    if not showItemsList then
        GetShowItemList(type)
    end
    return group and showItemByActivityType[type][group] or showItemByActivityType[type]
end

utils.EventManager.getInstance():addListener("ARENA_GET_PLAYER_INFO_SUCCESS", function(event, uuid)
    local pvpInfo=PVPArenaModule.GetPlayerInfo()
    if pvpInfo then
        local info=GetLocalPvpInfo(pvpInfo)
        PlayersSnFunction["GetSelfPvpInfo"](info) 
    end
end)

return {
    GetSelfBaseInfo=GetSelfBaseInfo,
    GetSelfUnionInfo=GetSelfUnionInfo,
    GetSelfResources=GetSelfResources,
    GetSelfPvpInfo=GetSelfPvpInfo,
    GetSelfUnionMemberTitle= GetSelfUnionMemberTitle,
    GetTotalShow = GetTotalShow,
    GetTotalShowInfo=GetTotalShowInfo,

    GetHonorList=GetHonorList,
    ChangeHonor=ChangeHonor,
    GetSelfHonorId=GetSelfHonor,

    GetShowItemList=GetShowItemList,
    GetItemCount=GetItemCount,

    ChangeHeadIcon=ChangeHeadIcon,
    --GetHeadIconList=GetHeadIconList,
    GetHeroList=GetHeroList,
    GetHeadIcon=GetHeadIcon,
    GetHeroFrameInfo=GetHeroFrameInfo,

    GetShowItemByActivityType=GetShowItemByActivityType,
    GetPlayerProvince=loadPlayerProvince,
}
