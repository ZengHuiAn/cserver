if attacker[7003] > 0 and _Skill[8001] > 0 then
	return
end

local dead_list = GetDeadList()

local list = {}

for _, v in ipairs(dead_list) do
	if v.side == attacker.side then
		table.insert(list, {target = v, button = Check_Button(attacker, v, _Skill.skill_type)})
	end
end

return list
