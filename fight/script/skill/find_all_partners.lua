if attacker[7003] > 0 and _Skill[8001] > 0 then
	return
end

local list = {}

local partners = FindAllPartner();	

table.insert(list, {target = "partner", button = Check_Button(attacker, v, _Skill.skill_type)})

return list;
