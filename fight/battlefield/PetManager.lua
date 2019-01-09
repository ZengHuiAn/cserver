
local battle_config = require "config.battle";
local class = require "utils.class"
local SandBox = require "utils.SandBox"
local Property = require "utils.Property"
local Skill = require "battlefield.Skill"

local Pet = class()
function Pet:_init_(game, id, _property, side)

	local cfg = battle_config.load_pet(id)
	if cfg == nil then
		return false;
	end

	self._property = Property(cfg.property_list)

	if _property then
		self._property:Add("init", _property);
	end

	self.property = self._property;

	self.record = {};

	self.side = side
	self.pos = 0
	self.game = game
	self.list = {}
	self.count = 0;
	self.hp = 0;
	self._cfg = cfg;

	local skill_id = _property.skill or cfg.skill;

	self.skill_boxs = {
		[1] = {name = cfg.skill_name , desc = cfg.skill_info}
	}

	if skill_id ~= 0 then
		self.skill_script = SandBox.New(string.format("script/skill/%s.lua", skill_id), self.game, self);  -- Skill(skill_id, self)
		self.skill_script:LoadLib("script/common.lua");
	end
	return self;
end

function Pet:_getter_(key)
	if key == "hpp" then
		return self:total_hp()
	end
	return self._cfg[key] or self._property[key]
end

function Pet:_setter_(key, value)
	if self._cfg[key] then
		self._cfg[key] = value;
	else
		self._property[key] = value;
	end
end

function Pet:DEBUG_LOG(...)
	self.game:DEBUG_LOG(...)
end

function Pet:ConsumeActPoint(n)
	self:DEBUG_LOG("Pet:ConsumeActPoint", n)
end


function Pet:RunScriptFile(script)
	local skill = Skill(nil, self, script);
	skill:Cast();
end

function Pet:ChangeMP(n, typa)
end

function Pet:Add(n, cd)
	for _, v in ipairs(self.list) do
		if v.cd == cd then
			v.count = v.count + n;
			self.count = self.count + n;
			self.hp = self.hp + self:raw_hp() * n; -- 增加血量
			self.game:Dispatch("UpdatePet", self.role, self);
			return
		end
	end

	table.insert(self.list, {count = n, cd = cd});

	self.count = self.count + n;
	self.hp = self.hp + self:raw_hp() * n; -- 增加血量

	self:dump("Pet:Add")
	self.game:Dispatch("UpdatePet", self.role, self);
end

function Pet:Remove(n, notChangeHP)
	if n <= 0 then
		return
	end

	if n >= self.count then
		return self:Clean();
	end

	local old_count = self.count;

	while n > 0 and #self.list > 0 do
		local info = self.list[1];
		if info.count > n then
			info.count = info.count - n
			self.count = self.count - n;
			break;
		else
			n = n - info.count;
			table.remove(self.list, 1);
			self.count = self.count - info.count;
		end
	end

	if not notChangeHP then
		if self.hp_type == 3 then
			self.hp = math.ceil(self.hp * (self.count / old_count))  -- 血量按照百分比扣除
		else
			self.hp = self:raw_hp() * self.count; -- 优先移除第一个，所以血量满了
		end
	end

	if self.count > 0 then
		self.game:Dispatch("UpdatePet", self.role, self);
	else
		self.game:Dispatch("RemovePet", self.role, self, true);
	end
end

function Pet:NextRound()
	local list = {}
	local firstRemoved = false;
	local removeCount = 0;
	for k, v in ipairs(self.list) do
		v.cd = v.cd - 1
		if v.cd ~= 0 then
			table.insert(list, v);
		else
			if k == 1 then
				firstRemoved = true;
			end
			removeCount = removeCount + v.count;
		end
	end

	local leftCount = self.count - removeCount;

	if leftCount <= 0 then
		self:Clean();
	else
		if self.hp_type == 3 then
			self.hp = math.ceil(self.hp * leftCount / self.count); -- 平均血量
		else
			if firstRemoved then
				self.hp = self:raw_hp() * leftCount;     -- 第一个移除了，剩下的全是满血
			else
				self.hp = self.hp - self:raw_hp() * removeCount; -- 第一个没有移除，减少的全是满血的
			end
		end
		self.count = leftCount;
		self.list = list;
	end

	if self.count > 0 then
		self.game:Dispatch("UpdatePet", self.role, self);
	else
		self.game:Dispatch("RemovePet", self.role, self, true);
	end

	return #list > 0;
end


-- 伤害类型......
-- 1 依次掉血 + 溢出
-- 2 依次掉血 - 溢出
-- 3 群体掉血

function Pet:raw_hp()
	if self._property.hp then
		return self._property.hp
	else
		return self._cfg.hp
	end
end

function Pet:total_hp()
	if self.count <= 0 then
		return 0
	end

	return self:raw_hp() * self.count;
end

function Pet:first_hp()
	if self.count <= 0 then
		return 0
	end

	if self.hp_type == 3 then
		return self.hp / self.count;
	else
		return self.hp - self:raw_hp() * (self.count - 1);
	end
end

function Pet:first_cd()
	return self.list[1] and self.list[1].cd or 0;
end

function Pet:second_cd()
	return self.list[2] and self.list[2].cd or 0;
end

function Pet:hp_percent()
	if self.count <= 0 then
		return 0
	end

	return self:first_hp() / self:raw_hp();
end

function Pet:Clean()
	self.list = {}
	self.count = 0;
	self.hp = 0;
end

function Pet:Health(value, valueType)
	
	if self.hp + value > self:total_hp() then
		self.hp = self:total_hp();
	else
		self.hp = self.hp + value;
	end

	self.game:Dispatch("UNIT_Health", self, value, valueType)

	self.game:Dispatch("UpdatePet", self.role, self);

	return value;
end

function Pet:Hurt(value, valueType)
	self:DEBUG_LOG("Pet:Hurt", self.hp_type, self.hp, self:first_hp(), value, self:raw_hp());

	if self.hp_type == 1 then
		if value >= self.hp then
			self:Clean()
		else
			self.hp = self.hp - value;
			local removeCount = self.count - math.ceil(self.hp / self:raw_hp())
			self:DEBUG_LOG("!!! remove count", self.hp, self:raw_hp(), self.count, removeCount);
			self:Remove(removeCount, true)
		end
	elseif self.hp_type == 2 then
		local maxhp = self:first_hp()
		if value >= maxhp then
			self:Remove(1)
		else
			self.hp = self.hp - value;
		end
	elseif self.hp_type == 3 then
		self.hp = self.hp - value;
		if self.hp <= 0 then
			self:Clean()
		end
	else
		assert("unknown hp_type", self.hp_type);
	end

	self.game:Dispatch("UNIT_Hurt", self, value, valueType)

	if self.count > 0 then
		self.game:Dispatch("UpdatePet", self.role, self);
	else
		self.game:Dispatch("RemovePet", self.role, self);
	end
end

function Pet:dump(...)
	self:DEBUG_LOG(..., string.format("id %d, hp_type %d, count %d, first %.2f, hp %s, total %s", self.id, self.hp_type, self.count, self:first_hp(), self.hp, self:total_hp()))
	for k, v in ipairs(self.list) do
		self:DEBUG_LOG("", k, v.count, v.cd);
	end
end

local PetManager = class();
PetManager.next_add_order = 0;

function PetManager:_init_(game,role)
	self.list = {}
	self.game = game
	self.role = role

	game:Watch("TIMELINE_AfterRound", function()
		self:NextRound();
	end)

	return self;
end

function PetManager:Add(id, n, cd, property)
	n = n or 1
	cd = cd or -1
	for _, v in ipairs(self.list) do
		if v.id == id then
			local old_hp = v.hp;
			v:Add(n, cd)

			if old_hp <= 0 then
				self.game:Dispatch("PET_Enter", self.role, v);
			end
			return v
		end
	end

	property = property or {};

	local pet = Pet(self.game, id, property, self.role.side);

	table.insert(self.list, pet);
	-- pet.count = count;

	PetManager.next_add_order = PetManager.next_add_order + 1;
	pet.add_order = PetManager.next_add_order;
	pet.role = self.role;
	pet.pos = self.role.pos;
	pet.owner = self.role;
	pet.level = self.role.level;

	self.game:Dispatch("PET_Enter", self.role, pet);

	pet:Add(n, cd);

	self.game:DEBUG_LOG("PropertyManager:Add", id, pet.name, pet.hp_type, pet:first_hp(), pet.hp, pet.hpp);

	return pet;
end

function PetManager:All()
	local list = {}
	for _, v in ipairs(self.list) do
		if v.hp > 0 then
			table.insert(list, v)
		end
	end
	return list;
end

function PetManager:NextRound()
	local list = {}
	for _,v in ipairs(self.list) do
		if v:NextRound() then
			table.insert(list, v);
		end
	end

	self.list = list;
end

function PetManager:Action()
	local list = {};
	for _, v in ipairs(self.list) do
		if v.count > 0 and v.skill_script and v.skill_script ~= 0 then
			table.insert(list, v);
		end
	end

	if #list == 0 then
		return;
	end
	self.game:Dispatch("PET_ACTION", list, self.role)
	local threadCounter = SandBox.ThreadCounter.New(1);

	for _, v in ipairs(list) do
		threadCounter:Retain();
        local pet = v;
		self.game:Dispatch("PET_BeforeAction", pet)
        self.game:DEBUG_LOG('PET_BeforeAction', pet.owner.name, pet.name);
		coroutine.resume(coroutine.create(function()
			ASSERT(pcall(v.skill_script.Call, v.skill_script));
			self.game:Dispatch("PET_AfterAction", pet)
            self.game:DEBUG_LOG('PET_AfterAction', pet.owner.name, pet.name);
			threadCounter:Release();
		end))
	end
	threadCounter:Release();
end

return PetManager;
