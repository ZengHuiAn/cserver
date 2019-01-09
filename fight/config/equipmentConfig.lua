--读取装备 铭文配置表
local CommonConfig = require "config.commonConfig"
local TipCfg = require "config.TipConfig"
local OpenLevel = require "config.openLevel"

local equipmentConfig = {}

local function merge_property(t, a, b)
	if t then
		t.propertys = {}
		for i = a, b do
			local k, v = t["type" .. i], t["value" .. i]
			if k and v and k ~= 0 and v ~= 0 then
				t.propertys[ k ] = (t.propertys[ k ] or 0) + v;
			end
		end
	end
	return t;
end

local function merge_array(t, k, a, b)
	if t then
		local x = {}
		for i = a, b do
			local v = t[k .. i]
			table.insert(x, t[k..i]);
		end
		t[k] = x;
	end
	return t;
end


local _inscriptionCfgTab = nil
local function inscriptionCfgTab(id)
	if _inscriptionCfgTab == nil then
		_inscriptionCfgTab = {raw = LoadDatabaseWithKey("inscription1", "id") }
		setmetatable(_inscriptionCfgTab, {__index=function(t, k)
			local cfg = t.raw[k] or t.raw[math.floor(k/100)]
			if cfg then
				rawset(t, k, merge_property(cfg, 0, 3));
			end
			return cfg;
		end})
	end
	if id == nil then
		return _inscriptionCfgTab
	else
		return _inscriptionCfgTab[id]
	end
end

local _abilityPoolTab = nil
local function abilityPoolTab(id)
	if _abilityPoolTab == nil then
		_abilityPoolTab = LoadDatabaseWithKey("ability_pool1", "pool_id")
	end
	return _abilityPoolTab[id]
end

local _equipmentTab = nil
local function equipmentTab(id)
	if _equipmentTab == nil then
		_equipmentTab = {raw = LoadDatabaseWithKey("equipment1", "id")}
		setmetatable(_equipmentTab, {__index=function(t, k)
			local cfg = t.raw[k] or t.raw[math.floor(k/100)]
			if cfg then
				rawset(t, k, merge_property(cfg, 0, 3));
			end
			return cfg;
		end})
	end

	if id == nil then
		return _equipmentTab
	else
		return _equipmentTab[id] or nil
	end
end

local _equipmentLevTab = nil
local function equipmentLevTab()
	if _equipmentLevTab == nil then
		_equipmentLevTab = {raw = LoadDatabaseWithKey("equipment_lev1", "id")}
		setmetatable(_equipmentLevTab, {__index=function(t, k)
			local cfg = t.raw[k]
			if cfg then
				rawset(t, k, merge_property(cfg, 0, 3));
			end
			return cfg;
		end})
	end
	return _equipmentLevTab
end

local _equipmentLevCoinTab = nil
local function equipmentLevCoinTab()
	if _equipmentLevCoinTab == nil then
		_equipmentLevCoinTab = LoadDatabaseWithKey("equipment_lev_coin", "level")
	end
	return _equipmentLevCoinTab
end

local _equipConfigTab = nil
local function equipConfigTab()
	if _equipConfigTab == nil then
		_equipConfigTab = LoadDatabaseWithKey("config", "id")
	end
	return _equipConfigTab
end

local _equipAdvExpTab = nil
local function equipAdvExpTab(quality)
	if _equipAdvExpTab == nil then
		_equipAdvExpTab = {}
		local _config = equipConfigTab()
		for k,v in pairs(_config) do
			if v.type == 4 then
				_equipAdvExpTab[v.quality] = v
			end
		end
	end
	if quality == nil then
		return _equipAdvExpTab
	else
		return _equipAdvExpTab[quality] or _equipAdvExpTab[3]
	end
end

local _equipExpTab = {}
local function equipExpTab(quality)
	local _config = equipConfigTab()
	for k,v in pairs(_config) do
		if v.type == 3 then
			_equipExpTab[v.quality] = v
		end
	end
	if quality == nil then
		return _equipExpTab
	else
		return _equipExpTab[quality] or _equipExpTab[3]
	end
end

local _levelUpTab = nil
local _equipLeveUpTab = nil
local _upLevelCoin = nil
local _levleUpCfg=nil
local function levelUpTab()
	if _levelUpTab == nil then
		_levelUpTab = {}
		_equipLeveUpTab = {}
		_upLevelCoin = {};
		_levleUpCfg={}
		DATABASE.ForEach("level_up", function(v, i)
			_levelUpTab[i] =v;
			if v.column == 3 then
				_upLevelCoin[v.level] = v
			elseif v.column == 4 then
				_equipLeveUpTab[v.level] = v
			end
			_levleUpCfg[v.column]=_levleUpCfg[v.column] or {}
			_levleUpCfg[v.column][v.level]=v
		end)
	end
	return _levelUpTab
end

local function upLevelCoin(level)
	levelUpTab();


    if not level then
        return _upLevelCoin
    end
	return _upLevelCoin[level]
end

local function equipLeveUpTab(level)
	levelUpTab();

	if level == nil then
		return _equipLeveUpTab
	else
		return _equipLeveUpTab[level]
	end
end
local function GetEquipLvUpByColumnAndLv(column,level)
	if not _levleUpCfg then
		levelUpTab()
	end
	if column and level then
		return _levleUpCfg[column][level]
	end
end
---eq装备 In铭文
local function GetOtherSuitsCfg()
    return {Eq = CommonConfig.Get(12).para1 / 10000, In = CommonConfig.Get(13).para1 / 10000,
            EqSuits = CommonConfig.Get(12).para2, InSuits = CommonConfig.Get(13).para2}
end

local function getConsumeFormTo(from, to)
    local tab = {}
    local _i = 1
    for i = from, to do
        local _tab = TipCfg.GetConsumeConfig(i)
        if _tab then
            tab[_i] = {type = _tab.type, id = _tab.item_id, value = _tab.item_value}
            _i = _i + 1
        end
    end
    return tab
end

local function getInscName(id)
    return TipCfg.GetAssistDescConfig(30001 + id)
end

local eqChangePrice = nil
local inChangePrice = nil
local function ChangePrice(typeId, quality)
    if not eqChangePrice then
        eqChangePrice = getConsumeFormTo(11, 15)
        inChangePrice = getConsumeFormTo(21, 25)
    end
    if typeId == 0 then
        return eqChangePrice[quality]
    elseif typeId == 1 then
        return inChangePrice[quality]
    end
    ERROR_LOG("typeId error")
end

local function GetEquipmentConfig(id)
	return equipmentTab()[id] or inscriptionCfgTab()[id];
end

local function GetEquipOpenLevel(suits, place)
    return OpenLevel.GetEquipOpenLevel(suits, place)
end

return {
	InscriptionCfgTab = inscriptionCfgTab,
	AbilityPoolTab = abilityPoolTab,
	EquipLeveUpTab = equipLeveUpTab,
	EquipmentTab = equipmentTab,
	EquipmentLevTab = equipmentLevTab,
	EquipmentLevCoinTab = equipmentLevCoinTab,
	EquipConfigTab = equipConfigTab,
	EquipAdvExpTab = equipAdvExpTab,
	EquipExpTab = equipExpTab,
	UpLevelCoin = upLevelCoin,

	GetConfig = GetEquipmentConfig,
    GetOtherSuitsCfg = GetOtherSuitsCfg,
    ChangePrice = ChangePrice,
    GetInscName = getInscName,
    GetEquipOpenLevel = GetEquipOpenLevel,

    GetCfgByColumnAndLv=GetEquipLvUpByColumnAndLv,
}
