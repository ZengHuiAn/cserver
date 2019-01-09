local class = require "utils.class"
local SandBox = require "utils.SandBox"
local Property = require "utils.Property"
local SkillConfig = require "config.skill"

local consume_type_map = {
	[8000] = {"mp", "法力"},
	[8001] = {"ep", "能量"},
	[8002] = {"fp", "怒气"},
}

local Skill = class()

Skill.ID_AUTO    = 0
Skill.ID_DEF     = 11
Skill.ID_IDLE    = 12
Skill.ID_DIAMOND = 13

local function loadScript(name, skill)
	local box = SandBox.New(string.format("script/skill/%s.lua", name), skill.owner.game, skill.owner);
	if box then
		box:LoadLib("script/common.lua");
		box._Skill = skill
	end
	return box;
end

function Skill:_init_(id, owner, script_file_name)
	assert(class.check(owner.property, Property), 'skill owner must have property');

	self.cfg = script_file_name and {} or SkillConfig.GetConfig(id);

	--[[
	if script_file_name == "idle" then
		self.cfg = SkillConfig.GetConfig(9002)
	elseif script_file_name == "def" then
		self.cfg = SkillConfig.GetConfig(9001)
	end
	]]

	assert(self.cfg, "skill config not found (" .. (id or script_file_name) .. ")");

	self.property = Property(self.cfg.property_list);

	self.owner = owner;
	self.property_add_to_owner = false;

	if self.cfg.check_script_id and self.cfg.check_script_id ~= 0 then
		self.check_script = loadScript(self.cfg.check_script_id, self)
	elseif not script_file_name then
		self.check_script = loadScript("find_one_enemy1", self);
	end

	assert(self.cfg.script_id ~= 0, owner.name);

	self.script = loadScript(script_file_name or self.cfg.script_id, self);

	self.current_cd = self.property.skill_init_cd;

	self.target_list = {}

	self._origin_id = id;

	local this = self;
	

	self.owner.game:Watch("TIMELINE_AfterRound", function()
		if this.current_cd and this.current_cd > 0 and owner.is_Active == 1 then
			this.current_cd = this.current_cd - 1
		end
	end)
end

function Skill:ChangeID(id)
	local cfg = SkillConfig.GetConfig(id);	
	assert(cfg, "skill config not found (" .. id .. ")");
	self.cfg = cfg or {};

	local old_uuid = self.property.uuid;

	self.property = Property(self.cfg.property_list);

	if self.cfg.check_script_id and self.cfg.check_script_id ~= 0 then
		self.check_script = loadScript(self.cfg.check_script_id, self)
	else
		self.check_script = loadScript("find_one_enemy1", self);
	end

	assert(self.cfg.script_id ~= 0, self.owner.name);

	self.script = loadScript(self.cfg.script_id, self);

	if self.property_add_to_owner then
		self.owner.property:Remove(old_uuid);
		self.owner.property:Add(self.property.uuid, self.cfg.property_list or {});
	end

	self.target_list = {}
end

function Skill:_getter_(key)
	return self.property:Get(key) or self.cfg[key];
end

function Skill:_setter_(key, value)
	-- assert(not self.cfg[key], "can't modify skill cfg");
	self.property[key] = value
end
local unpack = unpack or table.unpack;
local function TRACE(...)
--[[
	local t = {...}
	table.insert(t, "</color>");
	print("<color=red>", unpack(t))
--]]
end

function Skill:Check(simpleCheck)
	self.target_list = {}

	TRACE("Skill:Check", self.name, simpleCheck and "simple" or "");

	self.owner.property:Add(self.property.uuid, self.cfg.property_list or {});

	if self.current_cd > 0 then -- check cooldown
		self.error_info = "技能冷却中";
		self.owner.property:Remove(self.property.uuid);
		return false;
	end

	local consume_type = consume_type_map[self.cfg.consume_type];
	if consume_type and
		self.property[ self.cfg.consume_type ] > self.owner.property[ consume_type[1] ] then -- check consume
		self.error_info = string.format("%s不足", consume_type[2]);
		TRACE(self.error_info)
		self.owner.property:Remove(self.property.uuid);
		return false;
	end

	if self.owner[7002] > 0 and self._origin_id ~= 0 then
		if self.check_script then
			self.target_list = self.check_script:Call() or {};
		end
		
		if self.target_list == nil or #self.target_list == 0 then
			self.error_info = "封印状态下无法使用该技能";
			TRACE(self.error_info)
			return false;
		end
	end

	if self.check_script and not simpleCheck then
		self.target_list = self.check_script:Call() or {};
		TRACE("#target_list = ", #self.target_list);

		if self.target_list == nil or #self.target_list == 0 then
			self.error_info = "没有可用目标";
			TRACE(self.error_info)
			return false;
		end
	end

	self.owner.property:Remove(self.property.uuid);

	return true;
end

function Skill:Cast(choosen)
	self.owner.property:Add(self.property.uuid, self.cfg.property_list or {});
	self.property_add_to_owner = true;

	--[[
	if consume_type_map[self.cfg.consume_type] then -- do consume
		local mp = self.owner.property[ consume_type_map[self.cfg.consume_type][1] ];
		self.owner.property[ consume_type_map[self.cfg.consume_type][1] ] = mp - self.property[self.cfg.consume_type];
	end
	]]
	
	-- set cd
	self.current_cd = self.property.skill_cast_cd;

	self.script:Call(choosen);

	self.owner.property:Remove(self.property.uuid);
	self.property_add_to_owner = false;
end

return Skill;
