if attacker[7003] > 0 and _Skill[8001] > 0 then
	return
end

local list = {}
local skill_see_id = 7103;

local enemys = FindAllEnemy();	
local choose_list,value = All_target_list(enemys, skill_see_id);

if not choose_list then return end

table.insert(list, {target = "enemy", button = Check_Button_All(_Skill.skill_type)});		

return list;
