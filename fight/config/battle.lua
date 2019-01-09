local npc_property;

local function LoadNPCPropertyList(id)
    if npc_property == nil then
        npc_property = {}
        DATABASE.ForEach("npc_property_config", function(data)
            local id = data.property_id; 

			local xdata = {
				property_id = data.property_id,
				lev = data.lev,
				propertys = {},
			}

            for i = 1, 30 do
                local k, v = data['type' .. i], data['value' .. i]
                if k and v and k ~= 0 and v ~= 0 then
                    xdata.propertys[k] = (xdata.propertys[k] or 0) + v;
                end
            end

            npc_property[id] = npc_property[id] or {list = {}, sorted = false} 
            table.insert(npc_property[id].list, xdata); 
        end)
    end 
 
    if not npc_property[id] then 
        return nil 
    end
 
    if not npc_property[id].sorted then 
        npc_property[id].sorted = true; 
        table.sort(npc_property[id].list, function(a,b) 
            return a.lev < b.lev 
        end)
    end
 
    local list = npc_property[id].list; 
 
    assert(#list >= 2, "npc property count < 2") 
 
    return list 
end 


local function CalcNPCMaxLevel(id)
    local props = LoadNPCPropertyList(id);
    if props == nil then
        return nil;
    end

    return props[#props].lev;
end

local function CalcNPCProperty(npc, id, level)
    local list = LoadNPCPropertyList(id);
    if not list then
        return nil
    end

    local n = #list

    npc.property_list = {}

    for i = 1, n-1 do
        if level >= list[i].lev and level <= list[i+1].lev then
            local lev_min = list[i].lev;
            local lev_max = list[i+1].lev;

            for k, v in pairs(list[i].propertys) do
                local min = v;
                local max = list[i+1].propertys[k] or 0;
                npc.property_list[k] = math.floor(min + (max - min) * (level - lev_min)  / (lev_max - lev_min));
            end

            for k, v in pairs(list[i+1].propertys) do
                if list[i].propertys[k] == nil then
                    local min = 0;
                    local max = v;
                    npc.property_list[k] = math.floor(min + (max - min) * (level - lev_min)  / (lev_max - lev_min));
                end
            end
            npc.level = level;
            return npc;
        end
    end

    return nil;
end


local pet_data = nil;
local function loadPetConfig(id)
    if pet_data == nil then
        pet_data = LoadDatabaseWithKey("pet", "id", "hero")
    end
    
    local pet = pet_data[id];
    if pet and not rawget(pet, 'property_list') then
        pet.property_list = {};
        if pet.type1 ~= 0 then pet.property_list[pet.type1] = (pet.property_list[pet.type1] or 0) + pet.value1; end
        if pet.type2 ~= 0 then pet.property_list[pet.type2] = (pet.property_list[pet.type2] or 0) + pet.value2; end
        if pet.type3 ~= 0 then pet.property_list[pet.type3] = (pet.property_list[pet.type3] or 0) + pet.value3; end
        if pet.type4 ~= 0 then pet.property_list[pet.type4] = (pet.property_list[pet.type4] or 0) + pet.value4; end
        if pet.type5 ~= 0 then pet.property_list[pet.type5] = (pet.property_list[pet.type5] or 0) + pet.value5; end
        if pet.type6 ~= 0 then pet.property_list[pet.type6] = (pet.property_list[pet.type6] or 0) + pet.value6; end
    end
    
    return pet;
end

local skill_data = nil;
local function  loadSkill(id)
    if id == nil  then
        return nil;
    end

    if skill_data == nil then
        skill_data = LoadDatabaseWithKey("skill", "id", "hero");
    end
    return skill_data[id];
end

local npc_data;
local npc_data_keys;
local function loadNPC(id, level)
    if id == nil then
        return nil;
    end

    if npc_data == nil then
        npc_data = LoadDatabaseWithKey("npc", "id", "fight");
    end

    local npc = {}

    local cfg = npc_data[id];
    if not level then
        return cfg
    end

    if not cfg.skills then
        cfg.skills = {};
        if cfg.skill1 ~= 0 then table.insert(cfg.skills, loadSkill(cfg.skill1)) end;
        if cfg.skill2 ~= 0 then table.insert(cfg.skills, loadSkill(cfg.skill2)) end;
        if cfg.skill3 ~= 0 then table.insert(cfg.skills, loadSkill(cfg.skill3)) end;
        if cfg.skill4 ~= 0 then table.insert(cfg.skills, loadSkill(cfg.skill4)) end;
    end

    for k,v in pairs(cfg) do
        npc[k] = v 
    end
            
    npc.skills = cfg.skills;

    return CalcNPCProperty(npc, cfg.property_id, level);
end

local suit_config = nil
local function LoadSuitCfg(id)
    if suit_config == nil then
        local T = LoadDatabaseWithKey("suit", "id", "equip")
        suit_config = {}
        for k, row in ipairs(T) do
			suit_config[row.suit_id] = suit_config[row.suit_id] or {}
			suit_config[row.suit_id][row.count] = suit_config[row.suit_id][row.count] or {}
			suit_config[row.suit_id][row.count][row.quality] = suit_config[row.suit_id][row.count][row.quality] or {}
			suit_config[row.suit_id][row.count][row.quality] = row
        end
    end

    return suit_config[id]
end

local ai_role_cfg = nil
local function LoadAiNpcCfgProperty(id)
    if ai_role_cfg == nil then
        ai_role_cfg = LoadDatabaseWithKey("AI_role_battle", "id", "fight");
    end

    return ai_role_cfg[id]
end

local t_ai_suit_cfg = nil;
local t_ai_title_cfg = nil;
local function LoadAiNpcCfg(level, id)
    if t_ai_suit_cfg == nil then
        t_ai_suit_cfg = {};
        DATABASE.ForEach("AI_battle", function(row)
            if row.type == 1 then
                t_ai_suit_cfg[row.id] = row
            end
        end)
    end

    if t_ai_title_cfg == nil then
        t_ai_title_cfg = {};
        DATABASE.ForEach("AI_battle", function(row)
            if row.type == 2 then
                t_ai_title_cfg[row.id] = row
            end
        end)
    end

    local ai_role_cfg = LoadAiNpcCfgProperty(id)

    if not ai_role_cfg then
        ERROR_LOG("ai_role_cfg not found")
        return {} , {}
    end

    local ai_suits = {}
    local ai_titles = {}

    for _, row in pairs(t_ai_suit_cfg) do
        if row.minlevel < level and level <= row.maxlevel then
            local _applicativeSuit = StringSplit(ai_role_cfg.applicative_suit, "|")
            local suit_list = {}
            for _, v in ipairs(_applicativeSuit) do
                table.insert(suit_list, tonumber(v))
            end
            ai_suits = {num = row.suit_num, quality = row.suit_quality, suit_rand_pool = suit_list}
            break
        end
    end

    for _, row in pairs(t_ai_title_cfg) do
        if row.minlevel < level and level <= row.maxlevel then
            for i = 1, 4, 1 do
                local index = row["title"..i]

                if index > 0 then
                    local title_name = ai_role_cfg["name"..index]
                    local title_script = ai_role_cfg["title"..index]
                    if not title_script or not title_name then
                        ERROR_LOG("index not found in AI_role_battle")
                    else
                        table.insert(ai_titles, {title_name = title_name ,title_script = title_script})
                    end
                end
            end
            break
        end
    end

    return ai_suits, ai_titles
end

local function loadNPCFightData(id, level)
    if npc_data == nil then
        npc_data, npc_data_keys = LoadDatabaseWithKey("npc", "id", "fight");
    end

    if not npc_data[id] then
        return nil;
    end

    local npc = npc_data[id];

    local t = {
        id = id,
        level = level,
        name = cfg.name,
        icon = cfg.icon,
        mode = cfg.mode,
        skills = {cfg.skill1, cfg.skill2, cfg.skill3, cfg.skill4, cfg.enter_script},
        propertys = {}
    }
    
    local npc = CalcNPCProperty({}, cfg.property_id, level);
    for k, v in pairs(npc.property_list) do
        table.insert(t.propertys, {type=k, value=v})
    end
    return t;
end

local battle_list = nil;
local function loadBattleData()
    if battle_list then
        return;
    end

    battle_list = {};

    DATABASE.ForEach("wave_config", function(row)
        battle_list[row.gid] = battle_list[row.gid] or {
            partners = {},
            -- rounds = {},
            enemys_raw = {},
        }

        local cfg = battle_list[row.gid];
        table.insert(cfg.enemys_raw, row);
    end)

    -- clean up
    npc_data = nil;
    skill_data = nil;
end

local function Load(battle_id)
    if battle_list == nil then
        loadBattleData();
    end

    local cfg = battle_list[battle_id];

    assert(cfg, debug.traceback())

    if not cfg.rounds then
        cfg.rounds = {};

        for _, row in ipairs(cfg.enemys_raw or {}) do
            local round = row.wave

            cfg.rounds[round] = cfg.rounds[round] or {
                enemys = {},
            }
    
            local pos = row.role_pos;
            local role_id = row.role_id;
            local level = row.row_level;

            local x, y, z = row.x, row.y, row.z;
            cfg.rounds[round].enemys[pos] = loadNPC(row.role_id, row.role_lev);
            cfg.rounds[round].enemys[pos].x = x;
            cfg.rounds[round].enemys[pos].y = y;
            cfg.rounds[round].enemys[pos].z = z;
            cfg.rounds[round].enemys[pos].pos = pos;

            cfg.enemys_raw = nil;
        end
    end

    return cfg;
end

local  weapon_skill_config = nil;
local function LoadWeaponConfig(weapon)
    if weapon_skill_config == nil then
        weapon_skill_config = LoadDatabaseWithKey("weapon", "id");
    end
    return weapon_skill_config[weapon];
end

local function LoadWeaponSkill(weapon)
    local cfg = LoadWeaponConfig(weapon);
    if not cfg then 
        print("can't load weapon config", weapon);
        return {}
    end

    return {
        loadSkill(cfg.skill0),
        loadSkill(cfg.skill1),
        loadSkill(cfg.skill2),
        loadSkill(cfg.skill3),
        loadSkill(cfg.skill4),
    }

end

local preload_effect_by_id = nil;
local function GetPreloadEffectList(id)
    if preload_effect_by_id == nil then
        preload_effect_by_id = {};
        DATABASE.ForEach("role_texiao", function(row)
            preload_effect_by_id[row.id] = preload_effect_by_id[row.id] or {}
            table.insert(preload_effect_by_id[row.id], row.texiao_name);
        end)
    end
    return preload_effect_by_id[id] or {};
end


local mode_data = nil;
local function GetModeFlip(id, side, pos)
    if mode_data == nil then
        mode_data = LoadDatabaseWithKey("mode", "mode", "fight")
    end
    
    local info = mode_data[id];
    if not info then
        ERROR_LOG(string.format('mode config of %d not exists', id));
        return false;
    end

    if not rawget(info, 'flip') then
        info.flip = { };
        info.flip[101] = info.partner_turn_1;
        info.flip[102] = info.partner_turn_2;
        info.flip[103] = info.partner_turn_3;
        info.flip[104] = info.partner_turn_4;
        info.flip[105] = info.partner_turn_5;

        info.flip[201] = info.enemy_turn_1;
        info.flip[202] = info.enemy_turn_2;
        info.flip[203] = info.enemy_turn_3;
        info.flip[204] = info.enemy_turn_4;
        info.flip[205] = info.enemy_turn_5;

        info.flip[211] = info.enemy_turn_11;
        info.flip[221] = info.enemy_turn_21;
        info.flip[222] = info.enemy_turn_22;
        info.flip[223] = info.enemy_turn_23;
        info.flip[231] = info.enemy_turn_31;
        info.flip[232] = info.enemy_turn_32;
        info.flip[233] = info.enemy_turn_33;
        info.flip[234] = info.enemy_turn_34;

    end

    return (info.flip[side * 100 + pos] ~= 0), info.enemy_scale, info.order or 2;
end

return {
    load = Load,
    load_pet = loadPetConfig,
    LoadSkill = loadSkill,
    LoadWeaponSkill = LoadWeaponSkill,
    LoadNPC = loadNPC,
    LoadNPCFightData = loadNPCFightData,
    GetPreloadEffectList = GetPreloadEffectList,

    GetModeFlip = GetModeFlip,

    LoadAiNpcCfg = LoadAiNpcCfg,
    LoadSuitCfg = LoadSuitCfg,
}
