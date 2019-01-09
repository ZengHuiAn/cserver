Common_UnitConsumeActPoint(1);
Common_ChangeEp(attacker, _Skill[8001])
local target, all_targets = Common_GetTargets(...)

UnitPlay(attacker, "attack1", {speed = 1});
Common_Sleep(attacker, 0.3);

Common_FireBullet(0, attacker, target, _Skill, {
	-- Duration = 0.1,
	-- Interval = 0.1,
	-- Hurt = 10000,
	-- Type = 1,
	-- Attacks_Total = 3,
	-- Element = 6,
	-- parameter = {
	-- 	damagePromote = 10000,
	-- 	damageReduce = 10000,
	-- 	critPer = 10000,
	-- 	critValue = 10000,
	-- 	ignoreArmor = 10000,
	-- 	ignoreArmorPer = 10000,
	-- 	shieldHurt = 10000,
	-- 	shieldHurtPer = 10000,
	-- 	healPromote = 10000,
	-- 	healReduce = 10000,
	-- 	damageAdd = 10000,
	-- }
})

Common_Sleep(attacker, 0.3)
