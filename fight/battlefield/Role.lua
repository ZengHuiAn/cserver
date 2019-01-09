local class = require "utils.class"
local Property = require "utils.Property"
local Pipe = require "utils.Pipe"
local SandBox = require "utils.SandBox"

local Skill = require "battlefield.Skill"
local PetManager = require "battlefield.PetManager"

local Role = class()

local function default_reader(role, skills, targets)
	if targets then
		return "target", role.game:RAND(1, #targets)
	end

	for i = #skills, 1, -1 do
		if not skills[i].disabled then
			return "skill", i
		end
	end
end

local skill_list_11000 = {
	11000100,11000110,11000120,11000130,
	11000200,11000210,11000220,11000230,11000231,
	11000300,11000310,11000311,11000320,11000330
}

function Role:_init_(game, property_list, cfg, reader)
	self.property_list = {}

	for k, v in pairs(property_list) do
		self.property_list[k] = v
	end

	self.property = Property(self.property_list)

	self.cfg = cfg or {}
	self.pipe = Pipe.New()

	self.reader = reader

	self.record = {}
	self.petManager = PetManager(game, self)

	self.game = game
	self.skill_boxs = {saved = {}}

	self.UNIT_PropertyChange = true

	self.runtime = {act_point = 0}

	for k, v in ipairs(cfg.skills) do
		self.skill_boxs[k] = Skill(v.id, self)
		self.skill_boxs.saved[v.id] = self.skill_boxs[k]
		self.skill_boxs[k].sort_index = k
	end

	self.skill_boxs[Skill.ID_IDLE] = Skill(0, self, "idle")
	self.skill_boxs[Skill.ID_DEF] = Skill(0, self, "def")

	--[[
	if self.cfg.id == 11000 and self.cfg.side == 1 then
		self.skill_boxs[Skill.ID_DIAMOND] = Skill(0, self, "diamond")
		-- self.property.diamond_index = 1;

		for _, id in ipairs(skill_list_11000) do
			self.skill_boxs.saved[id] = self.skill_boxs.saved[id] or Skill(id, self)
		end
	end
	]]

	assert(self.property.hp > 0, "role need hp ")
	assert(self.property.hpp > 0, "role need hpp")
end

function Role:SetActive()
	self.is_Active = 1
end

function Role:DEBUG_LOG(...)
	self.game:DEBUG_LOG(...)
end

function Role:Clone()
	self:DEBUG_LOG(" Role:Clone", self.id, self.refid)
	return Role(self.game, self.property_list, self.cfg)
end

function Role:_getter_(key)
	return self.cfg[key] or self.property[key]
end

local fight_parameter_calc = require "battlefield.fight_parameter_calc"

function Role:_setter_(key, value)
	assert((self.cfg[key] == nil) or (self.cfg.v and self.cfg.v[key]), "role config " .. key .. " can't be modify")
	if self.cfg[key] ~= nil then
		self.cfg[key] = value
		return
	end

	if key == "speed" then
		self:Dispatch("UNIT_SPEED_CHANGE")
	end

	self.UNIT_PropertyChange = true

	value = fight_parameter_calc:Role_calc(self.property, key, value)
	self.property[key] = value
	-- self:Dispatch("UNIT_PropertyChange");
end

function Role:Dispatch(event, ...)
	self.game:Dispatch(event, self, ...)
end

function Role:DispatchSync(event, ...)
	return self.game:DispatchImmediately(event, self, ...)
end

function Role:Dead()
	self:DEBUG_LOG("Role:Dead>>>", self.id, self.refid, self.name)
	self:Dispatch("UNIT_DEAD")
	self.game.buffManager:Clean(self);
	self:DispatchSync("UNIT_DEAD_SYNC")
end

function Role:CheckSkillStatus(index)
	if index then
		local skill = self.skill_boxs[index]
		if skill then
			local sok = skill:Check()
			skill.disabled = not sok
			return sok
		end
		return
	end

	local ok = false
	for _, skill in ipairs(self.skill_boxs) do
		local sok = skill:Check()
		skill.disabled = not sok
		ok = sok or ok
	end
	return ok
end

function Role:GetAutoScript()
	if self._auto_input_script == 0 then
		self._auto_input_script = SandBox.New("script/autoAction.lua", self.game, self)
	end
	return self._auto_input_script
end

function Role:AutoInput()
	self:DEBUG_LOG("Role:AutoInput", self.id, self.refid, self.name)

	for _, skill in ipairs(self.skill_boxs) do
		skill.disabled = not skill:Check()
		self.game:API_Sleep(self, 0)
	end

	-- self:CheckSkillStatus();

	if self._auto_input_script == 0 then
		self._auto_input_script = SandBox.New("script/autoAction.lua", self.game, self)
	end

	local skill_index, target_index = self._auto_input_script:Call()

	if skill_index == "def" then
		skill_index = Skill.ID_DEF
	elseif skill_index == "idle" then
		skill_index = Skill.ID_IDLE
	end

	if skill_index then
		self:DEBUG_LOG("auto input get ", skill_index, target_index)
		return skill_index, target_index
	else
		ERROR_LOG("skill auto script return nothing", self.id, self.name)
		return Skill.ID_DEF, 0
	end
end

function Role:ChosInput()
	self:DEBUG_LOG("Role:ChosInput", self.id, self.refid, self.name)

	for _, skill in ipairs(self.skill_boxs) do
		skill.disabled = not skill:Check()
		self.game:API_Sleep(self, 0)
	end

	local skills = {}
	for _, v in ipairs(self.skill_boxs) do
		if not v.disabled then
			table.insert(skills, v)
		end
	end

	if #skills == 0 then
		return Skill.ID_DEF, 0
	end

	local skill_index, target_index = self.game:RAND(1, #skills), 0
	local select_skill = skills[skill_index]
	if #select_skill.target_list > 0 then
		target_index = self.game:RAND(1, #select_skill.target_list)
	end
	return skill_index, target_index
end

--[[
function Role:SelectSkillAndTarget()
	local select_skill = nil;
	local skill_index = nil;

	assert(self.reader ~= 0);

	print("Role:SelectSkillAndTarget", self.name, "from reader");

	for i = 1, 10 do
		local skill, target = self.reader(self, self.skill_boxs);
		if not skill then
			print(self.name, "reader return nothing")
		elseif skill == "auto" then
			return self:AutoInput();
		elseif skill == "cancel" then
			print(self.name, "read skill canceled");
			return;
		else
			return skill, target
		end
	end
end
--]]
function Role:CastSkill(skill_index, target_index)
	self:DEBUG_LOG("Role:CastSkill", self.id, self.refid, self.name, skill_index, target_index)

	if not skill_index then
		return
	end

	local is_auto_input = skill_index == Skill.ID_AUTO
	if is_auto_input then
		skill_index, target_index = self:AutoInput()
	end

	local select_skill = self.skill_boxs[skill_index]

	if not select_skill then
		self:DEBUG_LOG("-->", "skill no found", skill_index)
		return
	end

	if not is_auto_input then
		select_skill.disabled = not select_skill:Check()
	end

	if select_skill.disabled then
		self:DEBUG_LOG("-->", select_skill.id, select_skill.name, "disabled", select_skill.error_info)
		select_skill = self.skill_boxs[Skill.ID_DEF]
	end

	if target_index == nil then
		target_index = self.game:RAND(1, #select_skill.target_list)
	end

	self:DEBUG_LOG("-->", select_skill.id, select_skill.name, target_index)

	local select_info = select_skill.target_list[target_index]
	if select_info and not select_info.targets then
		if select_info.target == "enemy" then
			select_info.targets = self.game:API_FindAllEnemy(self)
		elseif select_info.target == "partner" then
			select_info.targets = self.game:API_FindAllPartner(self)
		else
			select_info.targets = {select_info.target}
		end
	end

	select_skill.index = skill_index
	self:Dispatch("UNIT_CAST_SKILL", select_skill)
	self.select_skill = select_skill
	select_skill:Cast(select_info)
	self.select_skill = nil
end

function Role:SelectSkill(...)
	for k, v in ipairs(self.skill_boxs) do
		self.skill_boxs.saved[v._origin_id] = v
		self.skill_boxs[k] = nil
	end

	for k, id in ipairs({...}) do
		local skill = self.skill_boxs.saved[id]
		if not skill then
			skill = Skill(id, self)
			self.skill_boxs.saved[skill._origin_id] = skill
		end
		self.skill_boxs[k] = skill
	end

	self:Dispatch("SKILL_CHANGE")
end

function Role:RunScriptFile(script)
	local skill = Skill(nil, self, script)
	skill:Cast()
end

function Role:ConsumeActPoint(n)
	self:DEBUG_LOG("Role:ConsumeActPoint", self.id, self.refid, self.name, n)
	self.runtime.act_point = self.runtime.act_point - n
end

function Role:RegainActPoint(n)
	self:DEBUG_LOG("Role:RegainActPoint", self.id, self.refid, self.name, n)
	self.runtime.act_point = self.runtime.act_point + n
end

local function range(v, min, max)
	return (v > max) and max or ((v < min) and min or v)
end

function Role:ChangeMP(n, typa)
	typa = typa or "mp"
	local pp = typa .. "p"

	local v = self.property[typa] + n

	if v < 0 then
		v = 0
	elseif v > self.property[pp] then
		v = self.property[pp]
	end
	self.property[typa] = v
end

function Role:ConsumeMP(n, typa)
	self:ChangeMP(-n, typa)
end

function Role:RestoreMP(n, typa)
	self:ChangeMP(n)
end

function Role:ChangeHP(value)
	self:DEBUG_LOG("Role:ChangeHP", self.id, self.refid, self.name, self.hp, value)

	local oldHP = self.hp
	self.hp = range(self.hp + value, 0, self.hpp)
	-- print(self.name, "ChangeHP", value, self.hp, self.hp <= 0 and "DEAD" or "");
	if oldHP > 0 and self.hp <= 0 then
		self:Dead()
	end
end

function Role:Hurt(value, valueType, num_text)
	self:DEBUG_LOG("Role:Hurt", self.id, self.refid, self.name, self.hp, value, valueType)
	self:ChangeHP(-value)
	self:Dispatch("UNIT_Hurt", value, valueType, num_text)
	return value, 0
end

function Role:Health(value, valueType, num_text)
	self:DEBUG_LOG("Role:Health", self.id, self.refid, self.name, self.hp, value, valueType)
	self:ChangeHP(value)
	self:Dispatch("UNIT_Health", value, valueType, num_text)
	return value
end

function Role:Relive(hp)
	self.hp = hp or 1
	self:Dispatch("UNIT_RELIVE")
end

function Role:Input(...)
	self.pipe:Push(...)
end

function Role:Renew()
	self.runtime.act_point = self.property.dizzy
	self.reading = false

	self.checking_skill_index = 0
	return true
end

function Role:PrepareCommand(prepared)
	if UnityEngine then
		self.checking_skill_index = (self.checking_skill_index or 0) + 1
		if self.skill_boxs[self.checking_skill_index] then
			self.skill_boxs[self.checking_skill_index].disabled = not self.skill_boxs[self.checking_skill_index]:Check(true)
			return false, true
		end
	else
		if not prepared then
			for _, skill in ipairs(self.skill_boxs) do
				skill.disabled = not skill:Check(true)
			end
		end
	end

	if self.reader == 0 then
		-- self:CheckSkillStatus();
		return true
	elseif self.property.outcontrol > 0 or self.property.chaos > 0 then
		-- self:CheckSkillStatus();
		return true
	elseif self.runtime.act_point <= 0 then
		return true
	end

	if not self.reading then
		self.reading = true
		-- self:CheckSkillStatus();
		if self.pipe:isEmpty() then
			self:reader()
		end
	end

	return not self.pipe:isEmpty()
end

function Role:Action(skill, target)
	self.reading = false

	if self.runtime.act_point <= 0 then
		self.petManager:Action()
		self:Dispatch("UNIT_FINISHED")
		return
	end

	if self.reader == 0 then
		self:CastSkill(self:AutoInput())
	elseif self.property.outcontrol > 0 or self.property.chaos > 0 then
		self:CastSkill(self:ChosInput())
	else
		self:CastSkill(self.pipe:Pop())
	end

	self.checking_skill_index = nil
	for _, skill in ipairs(self.skill_boxs) do
		skill.disabled = not skill:Check(true)
	end
end

function Role:Wait()
	self:Dispatch("UNIT_WAIT")
end

return Role
