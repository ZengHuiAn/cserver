local ItemModule = require "module.ItemModule"
local HeroModule = require "module.HeroModule"
local HeroEvo = require "hero.HeroEvo"
local equipmentModule = require "module.equipmentModule"
local equipmentConfig = require "config.equipmentConfig"

local TYPE = {
    ITEM = 41,
    HERO = 42,
    EQUIPMENT = 43,
    INSCRIPTION = 45,
    HERO_ITEM = 90,
};

local not_exists_id = {};

setmetatable(TYPE, {__index=function(t, k)
    assert(false, "unknown item type " .. k);
end})

local function Item(id, count)
    local cfg = ItemModule.GetConfig(id)
    if not cfg then
        if not not_exists_id[id] and UnityEngine.Application.isEditor then
            print("item config not exist", id);
            not_exists_id[id] = true;
        end
       cfg = {name = "未知物品(" .. id .. ")", icon = "10000", quality = 0,  type = 0};
    end

    return setmetatable({type = TYPE.ITEM, id = id, count = count, cfg = cfg, sub_type = cfg.type}, {__index=function(t, k)
        if k == "type_name" then
            local typeCfg=ItemModule.GetItemType(TYPE.ITEM,cfg.type) or {name = ""};
            return typeCfg.name;
        elseif k == "type_Cfg" then
            local typeCfg=ItemModule.GetItemType(TYPE.ITEM,cfg.type) or {name = "未知物品(" .. id .. ")",pack_order="0",pack_name ="未知物品(" .. id .. ")", sub_pack = "未知物品(" .. id .. ")"}
            return typeCfg
        else
            return (k == "count") and ItemModule.GetItemCount(id) or cfg[k]
        end
    end});
end

local function Hero(id)
    if id == 0 then return nil; end

    local cfg = HeroModule.GetConfig(id)
    if not cfg then
        if not not_exists_id[id] then
            print("hero config not exists ", id);
            not_exists_id[id] = true;
        end
        cfg = {name = "未知角色(" .. id .. ")", icon = "10000", quality = 0,  type = 0};
    end
    return setmetatable({type=TYPE.HERO, id = id, cfg = cfg}, {__index = function(t, k)
        if k == "count" then
            local hero = HeroModule.GetManager():Get(id);
            return hero and 1 or 0;
        elseif k == "quality" then
            local hero = HeroModule.GetManager():Get(id);
            local evoConfig = HeroEvo.GetConfig(id);

            if hero and evoConfig and evoConfig[hero.stage] then
                return evoConfig[hero.stage].quality;
            else
                return 0;
            end
        elseif k == "star" then
            local hero = HeroModule.GetManager():Get(id);
            return hero.star or 0;
        elseif k == "sub_type" then
            return 0;
        elseif k == "type_name" then
            local typeCfg=ItemModule.GetItemType(TYPE.HERO,0) or {name = ""}
            return typeCfg.name;
        elseif k == "type_Cfg" then
            local typeCfg=ItemModule.GetItemType(TYPE.HERO,0) or {name = "未知角色(" .. id .. ")",pack_order="0",pack_name ="未知角色(" .. id .. ")", sub_pack = "未知角色(" .. id .. ")"}
            return typeCfg
        else
            if k ~= "level" and k ~= "capacity" then
                local v = t.cfg[k]
                if v then
                    rawset(t, k, v)
                    return v;
                end
            end

            local hero = HeroModule.GetManager():Get(id);
            return  hero and hero[k]
        end
    end})
end

local function Equipment(uuid, id)
    if uuid then
        local equip = equipmentModule.GetByUUID(uuid);
        if not equip and not id then
            return nil;
        end
        id = id or equip.id;
    end

    return setmetatable({type=TYPE.EQUIPMENT, uuid = uuid, id = id}, {__index=function(t,k)
        local id = rawget(t, "id");
        local uuid = rawget(t, "uuid");
        local equip = nil;

        if uuid then
            equip = equipmentModule.GetByUUID(uuid);
            id = equip.id;
        end

        if k == "count" then
            return equip and 1 or 0;
        elseif k == "sub_type" then
            local cfg = equipmentConfig.EquipmentTab()[id] or {name = "未知装备(" .. id .. ")", icon = "10000", quality = 0,  type = 0}
            return cfg and cfg.type;
        elseif k == "type_name" then
            local _sub_type= equipmentConfig.EquipmentTab()[id] and equipmentConfig.EquipmentTab()[id].type or 0
            local typeCfg=ItemModule.GetItemType(TYPE.EQUIPMENT,_sub_type) or {name = ""}
            return typeCfg.name;
        elseif k == "type_Cfg" then
            local _sub_type= equipmentConfig.EquipmentTab()[id] and equipmentConfig.EquipmentTab()[id].type or 0
            local typeCfg=ItemModule.GetItemType(TYPE.EQUIPMENT,_sub_type) or {name = "未知装备(" .. id .. ")",pack_order="0",pack_name ="未知装备(" .. id .. ")", sub_pack = "未知装备(" .. id .. ")"}
            return typeCfg
        else
            local cfg = equipmentConfig.EquipmentTab()[id] or {name = "未知装备(" .. id .. ")", icon = "10000", quality = 0,  type = 0}
            return cfg and cfg[k];
        end
    end})
end

local function Inscription(uuid, id)
    if uuid then
        local equip = equipmentModule.GetByUUID(uuid);
        if not equip and not id then
            return nil;
        end
        id = id or equip.id;
    end

    return setmetatable({type=TYPE.INSCRIPTION, uuid = uuid, id = id}, {__index=function(t,k)
        local id = rawget(t, "id");
        local uuid = rawget(t, "uuid");

        local equip = nil;
        if uuid then
            equip = equipmentModule.GetByUUID(uuid);
            id = id or equip.id;
        end

        if k == "count" then
            return equip and 1 or 0;
        elseif k == "sub_type" then
            local cfg = equipmentConfig.InscriptionCfgTab()[id] or {name = "未知铭文(" .. id .. ")", icon = "10000", quality = 0,  type = 0}
            return cfg and cfg.type;
        elseif k == "type_name" then
            local _sub_type=equipmentConfig.InscriptionCfgTab()[id] and equipmentConfig.InscriptionCfgTab()[id].type or 0
            local typeCfg=ItemModule.GetItemType(TYPE.INSCRIPTION,_sub_type) or {name = ""}
            return typeCfg.name;
        elseif k == "type_Cfg" then
            local _sub_type=equipmentConfig.InscriptionCfgTab()[id] and equipmentConfig.InscriptionCfgTab()[id].type or 0
            local typeCfg=ItemModule.GetItemType(TYPE.INSCRIPTION,_sub_type) or {name = "未知铭文(" .. id .. ")",pack_order="0",pack_name ="未知铭文(" .. id .. ")", sub_pack = "未知铭文(" .. id .. ")"}
            return typeCfg
        else
            local cfg = equipmentConfig.InscriptionCfgTab()[id] or {name = "未知铭文(" .. id .. ")", icon = "10000", quality = 0,  type = 0}
            return cfg and cfg[k];
        end
    end})
end

local function Get(type, id, uuid, count)
    local v = nil;
    if type == TYPE.ITEM then
        v = Item(id, count)
    elseif type == TYPE.HERO then
        v = Hero(id)
    elseif type == TYPE.EQUIPMENT then
        v = Equipment(uuid, id)
    elseif type == TYPE.INSCRIPTION then
        v = Inscription(uuid, id)
    elseif type == TYPE.HERO_ITEM then
        v = (id > 0) and Item(id, count) or {type = TYPE.HERO_ITEM, id = id, count = 0, name = "角色经验", icon = "90001", sub_type = 0, quality = 0, cfg= {}}
    else
        v = {type = type, id = id,  name = "未知物品", icon = "10000", quality = 0, cfg= {}, count = 0, sub_type = 0}
    end
    return v;
end

local function GetList(type, ...)
    local subTypes = {}
    for _, v in ipairs({...}) do
        subTypes[v] = true;
    end

    local list = {}
    if type == TYPE.ITEM then
        local itemList = ItemModule.GetItemList();
        for _, v in pairs(itemList) do
            local item  = Item(v.id);
            if subTypes[item.sub_type] then
                table.insert(list, item);
            end
        end
    elseif type == TYPE.HERO then
        local heros = HeroModule.GetManager():GetAll();
        for k, v in pairs(heros) do
            table.insert(list, Hero(v.id));
        end
    elseif type == TYPE.EQUIPMENT then
        local equips = equipmentModule.GetEquip();
        for _, v in pairs(equips) do
            local equip = Equipment(v.uuid);
            if subTypes[equip.sub_type] then
                table.insert(list, equip)
            end
        end
    elseif type == TYPE.INSCRIPTION then
        local equips = equipmentModule.InscriptionTab();
        for _, v in pairs(equips) do
            local equip = Inscription(v.uuid);
            if subTypes[equip.sub_type] then
                table.insert(list, equip)
            end
        end
    end

    return list
end
local function IsCanOpen(type,id,num)
    local num=num or 1
    local item=Get(type,id)
    local CanOpen=true
    if item.sub_type == 89 or item.sub_type == 189 then
        local giftItemCfg=ItemModule.GetGiftBagConfig(id)
        if giftItemCfg and giftItemCfg.consume then
            local consumeTab=giftItemCfg.consume
            for i=1,#consumeTab do
                if Get(TYPE.ITEM,consumeTab[i].id).count<consumeTab[i].Count*num then
                    CanOpen=false
                    break
                end
            end
        end
    elseif item.sub_type == 79 then
        CanOpen = true
    else
        CanOpen = false
    end
    return CanOpen
end

local function OpenGiftBag(type,id,num)
    if Get(type,id) and (Get(type,id).sub_type == 89 or Get(type,id).sub_type == 189) then
        local canOpen=IsCanOpen(type,id,num or 1)
        if canOpen then
            ItemModule.OpenGiftBag(id,num or 1)
        end
    end
end



local _qualityConfig = nil;
local function QualityColor(quality, alpha)
    _qualityConfig = _qualityConfig or SGK.QualityConfig.GetInstance();
    local color = _qualityConfig:GetColor(quality);
    color.a = alpha or 1;
    return color;
end

local color_strs_icon = {'#B6B6B6FF', '#17C1A8FF', '#1295CCFF', '#8950DFFF', '#FEA211FF', '#E96651FF'};
local function QualityTextColor(quality)
    return color_strs_icon[quality+1]
end
local function QualityColorIcon(quality, alpha)
    local _, color = UnityEngine.ColorUtility.TryParseHtmlString( color_strs_icon[quality+1] or color_strs_icon[#color_strs] );
    color.a = alpha or 1;
    return color;
end

local function QualityColorAlpha(quality, alpha)
    return QualityColor(quality, alpha);
end
return {
    Get = Get,
    GetList = GetList,
    TYPE = TYPE,
    QualityColor = QualityColor,
    QualityColorIcon = QualityColorIcon,
    QualityColorAlpha = QualityColorAlpha,
    QualityTextColor = QualityTextColor,
    IsCanOpen=IsCanOpen,
    OpenGiftBag=OpenGiftBag,
}
