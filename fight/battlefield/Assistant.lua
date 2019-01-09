local class = require "utils.class"
local Property = require "utils.Property"
local Skill = require "battlefield.Skill"

local Assistant = class()

function Assistant:_init_(game, side)
	self.game = game

	self.roles = {}

	self.property = Property({
		name = "assistant",
		pos = 100 + side,
		side = side,
		hp = 100,
		mp = 100,
		hpp = 100,
		mpp = 100,
		icon = "assistant",
	})

	self.record = {};
end

function Assistant:SetActive() 
end

function Assistant:_getter_(key)
	return self.property[key];
end

function Assistant:_setter_(key, value)
	self.property[key] = value;
end

function Assistant:DEBUG_LOG(...)
	self.game:DEBUG_LOG(...)
end

function Assistant:RunScriptFile(...)
	self:DEBUG_LOG("Assistant:RunScriptFile", ...)
end

function Assistant:Add(role)
	table.insert(self.roles, role);
end

function Assistant:Dispatch(event, ...)
	return self.game:Dispatch(event, self, ...);
end

function Assistant:PrepareCommand()
	return true;
end

local function assistant_skill_init(skill)
	skill.current_cd = 0;
	skill.cfg.consume_type = nil;
end

function Assistant:Action()
	self.running_count = self.running_count + 1;

	self:DEBUG_LOG("Assistant:Action", self.running_count)
	
	if self.running_count > 1 then
		self:Dispatch("UNIT_FINISHED");
		return;
	end

	for _, v in ipairs(self.roles) do
		self:DEBUG_LOG("", v.name, "cd", v.current_assit_cd, "skill_count", #v.skill_boxs);
		if v.current_assit_cd <= 0 and #v.skill_boxs > 0 then
			local skill = v.skill_boxs[self.game:RAND(1, #v.skill_boxs)];
			assistant_skill_init(skill);
			skill:Check();
			self:DEBUG_LOG("-->", "skill", skill.name, "target_count", #skill.target_list);
			if #skill.target_list > 0 then
				self:DEBUG_LOG("---->", "choose");
				local value = self.game:RAND(1, #skill.target_list);
				local select_info = skill.target_list[value];
				if select_info and not select_info.targets then
					if select_info.target == "enemy" then
						select_info.targets = self.game:API_FindAllEnemy(self);
					elseif select_info.target == "partner" then
						select_info.targets = self.game:API_FindAllPartner(self);
					else
						select_info.targets = {select_info.target}
					end
				end

				v.current_assit_cd = v.assist_cd;
				self:Dispatch("ASSISTANT_BEFORE_ACTION", v);
				self.game:API_Sleep(self, 0.5);
				self:Dispatch("ASSISTANT_ACTION", v);				
				skill:Cast(select_info);
				break;
			end
		end
	end
end

function Assistant:Renew()
	self:DEBUG_LOG("Assistant:Renew");
	self.running_count = 0;
	for _, v in ipairs(self.roles) do
		if v.current_assit_cd > 0 then
			v.current_assit_cd = v.current_assit_cd - 1;
		end
	end
	return true;
end

function Assistant:Hurt()

	-- print("Assistant:Hurt ???");
	return 0, 0;
end

return Assistant;