local skill_config = {};
local skill_config_raw = nil;

local function appendProperty(list, k, v)
	if k and v and k ~= 0 and v ~= 0 then
		list[k] = (list[k] or 0) + v;
	end
end

local consume_type_map = {
	[8000] = "mp",
	[8001] = "ep",
	[8002] = "fp",
}

local function GetSkillConfig(id)
	skill_config_raw = skill_config_raw or LoadDatabaseWithKey("skill", "id", "hero");

	if not skill_config[id] and skill_config_raw[id] then
		local raw = skill_config_raw[id];

		local cfg = {
			id = raw.id,
			name = raw.name,
			desc = raw.desc,
			icon = raw.icon,
			cd = raw.cast_cd,
			consume = raw.consume_value,
			skill_type = raw.skill_type,
			skill_element = raw.skill_element,
			skill_place_type = raw.skill_place_type,

			check_script_id = raw.check_script,
			script_id = raw.script,
			recommend_suit_id = raw.recommend_suit_id,

			

			consume_type = raw.consume_type or 8000,
			property_list = { }
		}

		assert(cfg.consume_type == 0 or consume_type_map[cfg.consume_type] , string.format("skill %s have unknown consume_type %d", id, cfg.consume_type));

		appendProperty(cfg.property_list, 2001, raw.cast_cd);
		appendProperty(cfg.property_list, 2002, raw.init_cd);

		if cfg.consume_type ~= 0 then
			appendProperty(cfg.property_list, cfg.consume_type, raw.consume_value);
		end

		appendProperty(cfg.property_list, raw.type1, raw.value1);
		appendProperty(cfg.property_list, raw.type2, raw.value2);
		appendProperty(cfg.property_list, raw.type3, raw.value3);
		appendProperty(cfg.property_list, raw.type4, raw.value4);
		appendProperty(cfg.property_list, raw.type5, raw.value5);
		appendProperty(cfg.property_list, raw.type6, raw.value6);

		skill_config[id] = cfg;
	end
	
	return skill_config[id];
end


local skill_config_sound = nil;
local skill_config_sound_by_role = {};
local function GetSoundConfig(role_id, skill_id, type)
	if skill_config_sound == nil then
		skill_config_sound_by_role = {};
		local skill_config_sound_raw = LoadDatabaseWithKey("skill_music", "gid", "hero");

		local mt = {}
		mt.__index = function(t, k)
			t[k] = setmetatable({}, mt)
			return t[k];
		end

		skill_config_sound = setmetatable({}, mt);

		for _, v in pairs(skill_config_sound_raw) do
			if v.music_name ~= "" or v.music_name ~= 0 then
				table.insert(skill_config_sound[v.role_id][v.skill_id][v.music_type], v.music_name)
			end
			skill_config_sound_by_role[v.role_id] = skill_config_sound_by_role[v.role_id] or {}
			table.insert(skill_config_sound_by_role[v.role_id], v.music_name);
		end

		mt.__index = nil;
		skill_config_sound_raw = nil;
	end

	if not skill_id then
		return ;
	end

	if skill_config_sound[role_id] and skill_config_sound[role_id][skill_id] then
		return skill_config_sound[role_id][skill_id][type];
	end
end

return{
	GetConfig = GetSkillConfig,
	GetSoundConfig = GetSoundConfig,
}