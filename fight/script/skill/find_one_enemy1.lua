if attacker[7003] > 0 and _Skill[8001] > 0 then
	return
end

local enemys = FindAllEnemy()
local list = {}
local script_data = GetBattleData()

local choose_list,value = Target_list(enemys, skill_see_id)

for _, v in ipairs(choose_list) do
	table.insert(list, {target = v, button = Check_Button(attacker, v, _Skill.skill_type)})
end

return list