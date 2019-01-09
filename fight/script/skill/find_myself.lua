if attacker[7003] > 0 and _Skill[8001] > 0 then
	return
end

local list = {}
-- 自己
table.insert(list, {target = attacker, button = Check_Button(attacker, attacker, _Skill.skill_type)});

return list

