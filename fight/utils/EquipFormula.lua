local FormulaList = {}

--[[ function FormulaList:Formula_11000_0(list)
    return 0
end

function FormulaList:Formula_11000_1(list)
    return 0
end

function FormulaList:Formula_11000_2(list)
    return 0
end
function FormulaList:Formula_11001(list)
    return 0
end
]]
--[角色id] = 物理攻击、法术攻击  物伤附加、法伤附加  无视物防、无视法防  物理防御、法术防御  物伤吸收、法伤吸收 生命、生命回复
    --           风、土、水、火、光、暗精通 全系精通优先判断陆水银
   --[[  local capacity = (capacity_skill / 2 + atk + addDamage * 2 + ignore_def + element) *
    (1 + hurt_promoteA + hurt_promoteB + suck + ignore_def_per + critPer + critValue) +
    (hp * 0.5 + hp_revert * 2 + def + hurt_absorb * 2) *
    (1 + reduceCritPer + reduceCritValue + robust + hurt_reduceA + hurt_reduceB) ]]
local coefficient_table = {
    [1] = {1,0,2,0,1,0,1,1,2,2,0.5,2,1,0,0,0,0,0,1.5},   --陆水银红钻
    [2] = {0,1,0,2,0,1,1,1,2,2,0.5,2,0,1,0,0,0,0,1.5},  --陆水银黄钻
    [3] = {1,0,2,0,1,0,1,1,2,2,0.5,2,0,0,0,0,0,1,1.5},  --陆水银紫钻
    [4] = {1,0,2,0,1,0,1,1,2,2,0.5,2,0,0,0,1,0,0,1.5},
    [5] = {1,0,2,0,1,0,1,1,2,2,0.5,2,0,0,0,0,1,0,1.5},
    [6] = {1,0,2,0,1,0,1,1,2,2,0.5,2,0,0,0,0,0,1,1.5},

    [11001] = {0,1,0,2,0,1,1,1,2,2,0.5,2,0,0,1,0,0,0,1},  --阿尔
	[11002] = {1,0,2,0,1,0,1,1,2,2,0.5,2,0,0,0,0,1,0,1},  --华羚
    [11003] = {0,1,0,2,0,1,1,1,2,2,0.5,2,0,0,0,0,1,0,1},  --双子星
	[11004] = {0,1,0,2,0,1,1,1,2,2,0.5,2,0,1,0,0,0,0,1},  --伊赛菲亚
	[11007] = {0,1,0,2,0,1,1,1,2,2,0.5,2,0,0,0,0,0,1,1},  --西风
	[11008] = {0,1,0,2,0,1,1,1,2,2,0.5,2,0,0,1,0,0,0,1},  --贝克
	[11009] = {0,1,0,2,0,1,1,1,2,2,0.5,2,1,0,0,0,0,0,1},  --紫冥
	[11012] = {0,0.5,0,1,0,0.5,1.5,1.5,3,3,0.5,2,0,1,0,0,0,0,1},  --陆伯
	[11013] = {0.5,0,1,0,0.5,0,1.5,1.5,3,3,0.5,2,0,0,0,1,0,0,1},  --陆游七
	[11014] = {0,1,0,2,0,1,1,1,2,2,0.5,2,0,0,0,1,0,0,1},  --蓝琪儿
	[11022] = {1,0,2,0,1,0,1,1,2,2,0.5,2,0,0,0,1,0,0,1},  --蓝田玉
	[11023] = {1,0,2,0,1,0,1,1,2,2,0.5,2,0,0,0,0,1,0,1},  --梁三郎
	[11024] = {0.5,0,1,0,0.5,0,1.5,1.5,3,3,0.5,2,0,0,0,0,0,1,1},  --焱青
	[11028] = {1,0,2,0,1,0,1,1,2,2,0.5,2,1,0,0,0,0,0,1},  --钛小峰
}
--属性类型  和上表位置对应  最后一位为全系精通
local equip_pro_type = {
    ["xinpian"]={1008,1108,1024,1124,1011,1111,1307,1407,1322,1422,1507,1512,
                1818,1819,1820,1821,1822,1823,1824},
    ["shouhu"]={1002,1102,1022,1122,1011,1111,1302,1402,1322,1422,1502,1512,
                1801,1802,1803,1804,1805,1806,1807}
}



local function Score_EquiptoRole(Equip_pro, role_id, equip_type_bool)
    local score = 0
    local equip_type = "xinpian"
    local pro_value = 0   --属性值
    local coe_value = 0   --对应系数
   -- local pro_extra_value = 0 --全系精通额外属性值
    if equip_type_bool == 1 then
        equip_type = "shouhu"
    end
    local coe_value_table = coefficient_table[role_id]
    --ERROR_LOG("########",equip_type_bool, equip_type)
    for i = 1 , #equip_pro_type[equip_type] do
        pro_value = Equip_pro[equip_pro_type[equip_type][i]] or 0
        coe_value = coe_value_table[i]
        score = score + pro_value * coe_value
        --ERROR_LOG(sprinttb(Equip_pro))
        if Equip_pro[equip_pro_type[equip_type][i]] then
            --ERROR_LOG("@@@@@@"..i, score, role_id, "属性类型", equip_pro_type[equip_type][i] , "属性", pro_value, "系数", coe_value)
        end
    end
    --ERROR_LOG("role_id="..role_id, "score="..score, sprinttb(Equip_pro))
    return score
    --sprinttb(Equip_pro)
end

function FormulaList:Formula_11000(Equip_pro, diamond, equip_type_bool)
    local score = Score_EquiptoRole(Equip_pro, diamond + 1, equip_type_bool)
    return score
end

function FormulaList:Formula(Equip_pro, role_id, equip_type_bool)
    local score = Score_EquiptoRole(Equip_pro, role_id, equip_type_bool)
    return score
end

local function getProperty(uuid)
    local _cfg = module.equipmentModule.GetByUUID(uuid or 0)
    if not _cfg then
        return {}
    end
    local _list = {}
    if _cfg.type == 0 then
        for i,v in ipairs(module.equipmentModule.GetAttribute(_cfg.uuid)) do
            if not _list[v.key] then
                _list[v.key] = 0
            end
            _list[v.key] = v.allValue + _list[v.key]
        end
        return _list
    elseif _cfg.type == 1 then
        for i,v in ipairs(module.equipmentModule.GetIncBaseAtt(_cfg.uuid)) do
            if not _list[v.key] then
                _list[v.key] = 0
            end
            _list[v.key] = v.allValue + _list[v.key]
        end
        for k,v in pairs(module.equipmentModule.GetAttribute(_cfg.uuid)) do
            if not _list[v.key] then
                _list[v.key] = 0
            end
            _list[v.key] = v.allValue + _list[v.key]
        end
        return _list
    end
    return {}
end

local function GetScore(data)
    local _heroId = data.heroId
    local _uuid = data.uuid
    local _score = 0
    local _diamond = 0
    local _propertyList = getProperty(_uuid)
    local _equipCfg = module.equipmentModule.GetByUUID(_uuid or 0)
    local _type = 0
    if _equipCfg then
        _type = _equipCfg.type
    end
    if _heroId == 11000 then
        local _hero = module.HeroModule.GetManager():Get(_heroId)
        _diamond = _hero.proprety_value
        _score = FormulaList:Formula_11000(_propertyList, _diamond, _type)
    else
        _score = FormulaList:Formula(_propertyList, _heroId, _type)
    end
    return _score
end

return {
    GetScore = GetScore,
}
