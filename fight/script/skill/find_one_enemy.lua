if attacker[7003] > 0 and _Skill[8001] > 0 then
	return
end

local enemys = FindAllEnemy()
local list = {}
local script_data = GetBattleData()

local skill_see_id = 7103;
local skill_fanchaofeng_id = 7104;
local skill_ignore_def_order = 7105;

local choose_list,value = Target_list(enemys, skill_see_id, skill_fanchaofeng_id, skill_ignore_def_order)
local jianshe = attacker[7006] + attacker[7106] > 0;
local chuanci = attacker[7007] + attacker[7107] > 0;

for _, v in ipairs(choose_list) do
	table.insert(list, {target = v, button = Check_Button(attacker, v, _Skill.skill_type)})
end

return list