--评分计算方式
local function common_capacity(P)
	local role_list = {
		11000,
		11001,
		11002,
		11003,
		11004,
		11007,
		11008,
		11009,
		11012,
		11013,
		11014,
		11022,
		11023,
		11024,
		11028
	}
	local role_id = 1

	--确定当前角色
	for _, v in pairs(role_list) do
		if P[v] > 0 then
			role_id = v
			break
		end
	end

	--确定陆水银钻石
	if role_id == 11000 then
		role_id = tonumber(role_id .. math.max(1, P[21000]))
	end

	--[角色id] = 平均技能段数，物攻系数，法攻系数，每回合平均受击次数，普、群、单、宠伤系数，风、土、水、火、光、暗系
	local role_table = {
		[1] = {1, 1, 1, 2, 0.25, 0.25, 0.25, 0.25, 1, 1, 1, 1, 1, 1},
		[110001] = {1, 1, 0, 2, 0.25, 1, 1, 0, 1, 0, 0, 0, 0, 0},
		[110002] = {1, 0, 1, 2, 0.25, 0, 0, 1, 0, 1, 0, 0, 0, 0},
		[110003] = {1, 1, 0, 2, 0.25, 0, 0, 1, 0, 0, 0, 0, 0, 1},
		[11001] = {1, 0, 1, 2, 0.25, 1, 1, 1, 0, 0, 1, 0, 0, 0},
		[11002] = {1, 1, 0, 2, 0.25, 1, 0, 0, 0, 0, 0, 0, 1, 0},
		[11003] = {1, 0, 1, 2, 0.25, 0, 1, 0, 0, 0, 0, 0, 1, 0},
		[11004] = {1, 0, 1, 2, 0.25, 0, 0, 1, 0, 1, 0, 0, 0, 0},
		[11007] = {1, 0, 1, 2, 0.25, 0, 1, 0, 0, 0, 0, 0, 0, 1},
		[11008] = {1, 0, 1, 2, 0.25, 1, 0, 0, 0, 0, 1, 0, 0, 0},
		[11009] = {1, 0, 1, 2, 0.25, 0, 0, 0, 0, 0, 0, 0, 0, 0},
		[11012] = {1, 0, 1, 4, 0.25, 1, 0, 1, 0, 1, 0, 0, 0, 0},
		[11013] = {1, 1, 0, 4, 0.25, 1, 0, 0, 0, 0, 0, 1, 0, 0},
		[11014] = {1, 0, 1, 2, 0.25, 1, 1, 0, 0, 0, 0, 1, 0, 0},
		[11022] = {1, 1, 0, 2, 0.25, 1, 1, 0, 0, 0, 0, 1, 0, 0},
		[11023] = {1, 1, 0, 2, 0.25, 1, 0, 1, 0, 0, 0, 0, 1, 0},
		[11024] = {1, 1, 0, 4, 0.25, 1, 0, 0, 0, 0, 0, 0, 0, 1},
		[11028] = {1, 1, 0, 2, 0.25, 1, 1, 0, 1, 0, 0, 0, 0, 0}
	}

	--统一数值
	local critPer = P.critPer --暴击率
	local critValue = P.critValue --暴击伤害
	local reduceCritPer = P.reduceCritPer --免暴率
	local reduceCritValue = P.reduceCritValue --免暴伤害
	local hp = P.hpp --生命
	local hp_revert = P.hpRevert --生命回复
	local robust = P.robust --强健
	local hurt_absorb = P.phyDamageAbsorb + P.magicDamageAbsorb + (P[1601] + P[1611] + P[1621] + P[1631]) / 2 --伤害吸收
	local def = P.armor + P.resist --防御
	local hurt_reduceA = P.phyDamageReduce + P.magicDamageReduce --物理/法术伤害减免
	local hurt_reduceB = (P[1602] + P[1612] + P[1622] + P[1632]) / 20000 --普、单、群、宠伤害减免

	local role = role_table[role_id]

	--分歧数值
	local atk = P.ad * role[2] + P.ap * role[3] --攻击
	local addDamage =
		P.addPhyDamage * role[2] + P.addMagicDamage * role[3] + P[1603] * role[5] + P[1613] * role[6] + P[1623] * role[7] +
		P[1633] * role[8] --附加伤害
	local hurt_promoteA = P.phyDamagePromote * role[2] + P.magicDamagePromote * role[3] --物理/法术伤害加成
	local ignore_def = P.ignoreArmor * role[2] + P.ignoreResist * role[3] --无视防御
	local ignore_def_per = P.ignoreArmorPer * role[2] + P.ignoreResistPer * role[3] --无视防御比例
	local suck = P.phySuck * role[2] + P.magicSuck * role[3] --吸血
	local hurt_promoteB =
		P[1604] / 10000 * role[5] + P[1614] / 10000 * role[6] + P[1624] / 10000 * role[7] + P[1634] / 10000 * role[8] --普、群、单、宠伤害加成
	local element =
		P.airPromote * role[9] + P.dirtPromote * role[10] + P.waterPromote * role[11] + P.firePromote * role[12] +
		P.lightPromote * role[13] +
		P.darkPromote * role[14] --元素精通

	--技能树增加战力的属性id
	local skill_tree_id = {
		[110001] = {10001, 10002, 10003},
		[110002] = {10011, 10012, 10013},
		[110003] = {10021, 10022, 10023}
		--{10031,10032,10033},
		--{10041,10042,10043},
		--{10051,10052,10053},
		--{10061,10062,10063}
	}

	local capacity_skill = P[10000]
	if role_id >= 110001 and role_id <= 110007 then
		local skill = skill_tree_id[role_id]
		capacity_skill = capacity_skill + P[skill[1]] + P[skill[2]] + P[skill[3]]
	else
		capacity_skill = capacity_skill + P[10001] + P[10002] + P[10003]
	end

	--套装战力
	local capacity_suit_atk = P[10008] / 10000
	local capacity_suit_def = P[10009] / 10000

	local capacity_atk =
		(atk * 2 + addDamage + ignore_def) * (1 + hurt_promoteA + hurt_promoteB + suck + ignore_def_per + critPer + critValue) *
		(1 + element) *
		(1 + capacity_suit_atk)
	local capacity_def =
		(hp * 0.3 + hp_revert + def + hurt_absorb) *
		(1 + reduceCritPer + reduceCritValue + robust + hurt_reduceA + hurt_reduceB) *
		(1 + capacity_suit_def)

	local capacity = capacity_skill / 2 + capacity_atk + capacity_def
	return capacity / 2
end

--计算装备评分
local function calc_score(P)
	--ERROR_LOG(P.ad.."------"..P.baseAd.."------"..P.extraAd.."==="..P[1004]..P[1008])
	local score =
		(P.ad + P.ap) * 2 + (P.addPhyDamage + P.addMagicDamage + P.addTrueDamage) + (P.ignoreArmor + P.ignoreResist) +
		(P.armor + P.resist) + (P.phyDamageAbsorb + P.magicDamageAbsorb) + P.hpp * 0.3 + P.hpRevert + P[1211] * 100
	return score / 2
end

--属性值计算
return {
	capacity = function(P)
		return math.ceil(common_capacity(P))
	end,
	calc_score = function(P)
		return math.ceil(calc_score(P))
	end,

	--攻击
	ad = function(P)
		return (P.baseAd + P.extraAd) * (1 + P[1014] / 10000)
	end,
	baseAd = function(P)
		return P[1001] * (1 + P[1011] / 10000)
	end,
	extraAd = function(P)
		return P[1002] * (1 + P[1012] / 10000) + P[1003] + P.baseAd * P[1013] / 10000
	end,

	--防御
	armor = function(P)
		return (P.baseArmor + P.extraArmor) * (1 + P[1314] / 10000)
	end,
	baseArmor = function(P)
		return P[1301] * (1 + P[1311] / 10000)
	end,
	extraArmor = function(P)
		return P[1302] * (1 + P[1312] / 10000) + P[1303] + P.baseArmor * P[1313] / 10000
	end,

	--生命,改变hpp时hp也会增加，hp是hpp减去伤害后的值
	hp = function(P)
		return P.hpp - P[1599]
	end,
	hpp = function(P)
		return (P.baseHp + P.extraHp) * (1 + P[1514] / 10000)
	end,
	baseHp = function(P)
		return P[1501] * (1 + P[1511] / 10000)
	end,
	extraHp = function(P)
		return P[1502] * (1 + P[1512] / 10000) + P[1503] + P.baseHp * P[1513] / 10000
	end,

	--每回合生命回复
	hpRevert = function(P)
		return P[1521] * (1 + (P[1522]) / 10000)
	end,

	--速度
	speed = function(P)
		return P[1211]
	end,

	--穿透
	ignoreArmor = function(P)
		return P[1031]
	end,
	ignoreArmorPer = function(P)
		return math.min(0.6, P[1032] / 10000)
	end,

	--吸血
	suck = function(P)
		return math.min(0.4, P[1251] / 10000)
	end,

	--伤害加成
	damageAdd = function(P)
		return P[1021]
	end,
	damagePromote = function(P)
		return P[1022] / 10000
	end,

	--伤害减免
	damageAbsorb = function(P)
		return P[1321]
	end,
	damageReduce = function(P)
		return P[1322] / 10000
	end,

	--暴击和免暴
	critPer = function(P)
		return P[1201] / 10000
	end,
	critValue = function(P)
		return math.min(6, 1.5 + P[1202] / 10000)
	end,
	reduceCritPer = function(P)
		return P[1203] / 10000
	end,
	reduceCritValue = function(P)
		return P[1204] / 10000
	end,

	--韧性:降低被控制的概率
	tenacity = function(P)
		return math.min(1, math.max(0, P[1261] /10000))
	end,

	--治疗效果提升
	healPromote = function(P)
		return P[1221] / 10000
	end,

	--接受治疗的效果提升
	beHealPromote = function(P)
		return P[1222] / 10000
	end,

	--护盾效果提升
	shieldPromote = function(P)
		return P[1231] / 10000
	end,

	--元素伤害加成
	airPromote = function(P)
		return (P[1881] + P[1887]) / 10000
	end,
	dirtPromote = function(P)
		return (P[1882] + P[1887]) / 10000
	end,
	waterPromote = function(P)
		return (P[1883] + P[1887]) / 10000
	end,
	firePromote = function(P)
		return (P[1884] + P[1887]) / 10000
	end,
	lightPromote = function(P)
		return (P[1885] + P[1887]) / 10000
	end,
	darkPromote = function(P)
		return (P[1886] + P[1887]) / 10000
	end,

	--元素伤害减免
	airReduce = function(P)
		return (P[1891] + P[1897]) / 10000
	end,
	dirtReduce = function(P)
		return (P[1892] + P[1897]) / 10000
	end,
	waterReduce = function(P)
		return (P[1893] + P[1897]) / 10000
	end,
	fireReduce = function(P)
		return (P[1894] + P[1897]) / 10000
	end,
	lightReduce = function(P)
		return (P[1895] + P[1897]) / 10000
	end,
	darkReduce = function(P)
		return (P[1896] + P[1897]) / 10000
	end,

	--元素伤害治疗
	airHeal = function(P)
		return (P[1871] + P[1877]) / 10000
	end,
	dirtHeal = function(P)
		return (P[1872] + P[1877]) / 10000
	end,
	waterHeal = function(P)
		return (P[1873] + P[1877]) / 10000
	end,
	fireHeal = function(P)
		return (P[1874] + P[1877]) / 10000
	end,
	lightHeal = function(P)
		return (P[1875] + P[1877]) / 10000
	end,
	darkHeal = function(P)
		return (P[1876] + P[1877]) / 10000
	end,

	--护盾（程序使用）
	shield = function(P)
		return P[7096]
	end,
	
	-- 每轮恢复行动力点数(程序使用)
	dizzy = function(P)
		return math.max(0, 1 - P[7008])
	end,

	--放逐（无法被选到，程序使用）
	exile = function(P)
		return P[7097]
	end,
	
	--混乱
	chaos = function(P)
		return P[7098]
	end,	

	--失控（程序使用）
	outcontrol = function(P)
		return P[7099]
	end,
	
	--沉默（程序使用）
	silence = function(P)
		return P[7003]
	end,	

	--技能cd
	skill_cast_cd = function(P)
		return P[2001]
	end,
	skill_init_cd = function(P)
		return P[2002]
	end,

	--能量energy
	ep = function(P)
		return P.initEp
	end,
	epp = function(P)
		return P[1721]
	end,
	--能量回复
	epRevert = function(P)
		return P[1722]
	end,
	--初始能量
	initEp = function(P)
		return P[1723]
	end,

	--法力消耗类型
	skill_consume_mp = function(P)
		return P[8000]
	end,
	skill_consume_ep = function(P)
		return P[8001]
	end,
	skill_consume_fp = function(P)
		return P[8002]
	end,
	
	--陆水银钻石属性
	diamond_index = function(P)
		return P[21000]
	end,

	--升星计数
	star_count = function(P)
		return P[10100]
	end,

	--入场脚本
	enter_script = function(P)
		return "enter_script"
	end
}