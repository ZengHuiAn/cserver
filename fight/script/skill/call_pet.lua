if attacker[7003] > 0 and _Skill[8001] > 0 then
	return
end

local enemys = FindAllEnemy();
local list = {}

table.insert(list, {target="enemy", button="UI/fx_pet_fz_run" ,value=1});

return list