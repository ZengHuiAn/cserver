if attacker[7003] > 0 and _Skill[8001] > 0 then
	return
end

local partners = FindAllPartner()
local list = {}

for _, v in ipairs(partners) do
	table.insert(list, {target = v, button = Check_Button(attacker, v, _Skill.skill_type)})
end

return list
