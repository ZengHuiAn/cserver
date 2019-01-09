--评分计算方式（真实）
local function true_capacity(P)

	local role_id = nil

	--[角色id] = 平均技能段数，物攻系数，法攻系数，每回合平均受击次数，普、群、单、宠伤系数，风、土、水、火、光、暗系精通
	local role_table = {
		[11000] = {1,1,1,2,0.25,0.25,0.25,0.25,1,1,0,0,0,1},
		[11001] = {2,0.1,1,2,0.25,0.25,0.25,0.25,0,0,1,0,0,0},
		[11002] = {2,1,0.1,2,0.5,0.5,0,0,0,0,0,0,1,0},
		[11003] = {1,0.1,1,2,0.25,0,0.25,0,0,0,0,0,1,0},
		[11004] = {1,0.1,1,2,0.5,0,0,0.5,0,1,0,0,0,0},
		[11007] = {1,0.1,1,2,0.75,0,0.25,0,0,0,0,0,0,1},
		[11008] = {2,0.1,1,2,0.5,0.25,0,0,0,0,1,0,0,0},
		[11009] = {1,0.1,1,2,0.25,0,0.25,0,1,0,0,0,0,0},
		[11012] = {1,0.1,1,4,0.25,0.25,0,0.5,0,1,0,0,0,0},
		[11013] = {1,1,0.1,4,0.25,0.25,0,0,0,0,0,1,0,0},
		[11014] = {3,0.1,1,2,0.25,0.75,0,0,0,0,0,1,0,0},
		[11022] = {2,1,0.1,2,0.25,0.5,0.25,0,0,0,0,1,0,0},
		[11023] = {1,1,0.1,2,0.25,0,0.25,0.25,0,0,0,0,1,0},
		[11024] = {2,1,0.1,4,0.25,0.25,0,0.25,0,0,0,0,0,1},
		[11028] = {2,1,0.1,2,0.5,0.25,0.25,0,1,0,0,0,0,0},
	}

	--确定当前角色
	for k,_ in pairs(role_table) do
		if P[k] > 0 then
			role_id = k
			break
		end
	end

	if not role_id then return 0 end

	--统一数值
	local level = P[99900] + 1 --等级
	local critPer = P.critPer --暴击率
	local critValue = P.critValue --暴击伤害
	local reduceCritPer = P.reduceCritPer --免暴率
	local reduceCritValue = P.reduceCritValue --免暴伤害
	local hp = P.hpp --生命
	local hp_revert = P.hpRevert --生命回复
	local robust = P.robust --强健
	local hurt_absorb = (P.phyDamageAbsorb + P.magicDamageAbsorb + (P[1601] + P[1611] + P[1621] + P[1631]) / 2)  / 2 --伤害吸收
	local def = (P.armor + P.resist) / 2 --防御
	local hurt_reduceA = (P.phyDamageReduce + P.magicDamageReduce) / 2 --物理/法术伤害减免
	local hurt_reduceB = (P[1602] + P[1612] + P[1622] + P[1632]) / 4 --普、单、群、宠伤害减免
	

	--固定数值
	local round = 4 --回合数
	local target_def = 422.5 * level --目标防御
	local target_critPer = 1 --目标暴击率
	local target_critValue = 0.5 --目标暴击伤害

	--分歧数值
	local atk_times = role_table[role_id][1] --平均技能段数
	local atk = P.ad * role_table[role_id][2] + P.ap * role_table[role_id][3] --攻击
	local addDamage = P.addPhyDamage * role_table[role_id][2] + P.addMagicDamage * role_table[role_id][3] +
		P[1603] * role_table[role_id][5] + 
		P[1613] * role_table[role_id][6] +
		P[1623] * role_table[role_id][7] + 
		P[1633] * role_table[role_id][8] --附加伤害
	local hurt_promoteA = P.phyDamagePromote * role_table[role_id][2] + P.magicDamagePromote * role_table[role_id][3] --物理/法术伤害加成
	local ignore_def = (P.ignoreArmor + (P.ignoreArmorPer + P.ignoreExtraArmorPer * 0.75) * target_def)* role_table[role_id][2] + 
		(P.ignoreResist + (P.ignoreResistPer + P.ignoreExtraResistPer * 0.75) * target_def) * role_table[role_id][3] --无视防御
	local suck = P.phySuck * role_table[role_id][2] + P.magicSuck * role_table[role_id][3] --吸血	
	local def_times = role_table[role_id][4] --每回合平均受击次数
	local hurt_promoteB = P[1604] * role_table[role_id][5] + 
		P[1614] * role_table[role_id][6] + 
		P[1624] * role_table[role_id][7] + 
		P[1634] * role_table[role_id][8] --普、群、单、宠伤害加成
	local element = P.airMaster * role_table[role_id][9] + 
		P.dirtMaster * role_table[role_id][10] + 
		P.waterMaster * role_table[role_id][11] + 
		P.fireMaster * role_table[role_id][12] + 
		P.lightMaster * role_table[role_id][13] + 
		P.darkMaster * role_table[role_id][14] --元素精通

	--技能树增加战力的属性id
	local skill_tree_id = { 
		10001,10002,10003,
		10011,10012,10013,
		10021,10022,10023,
		10031,10032,10033,
		10041,10042,10043,
		10051,10052,10053,
		10061,10062,10063
	}
	local capacity_skill = 0
	for k, v in ipairs(skill_tree_id) do
		capacity_skill = capacity_skill + P[v]
	end

	local hurt_value = P[10000] + capacity_skill --技能初始系数+技能树系数
	
	
	local atk_times_adjust = {
		[1] = 1,
		[2] = 0.88,
		[3] = 0.75,
		[4] = 0.64,
		[5] = 0.5,
		[6] = 0.36,
	}

	local atk_valueA = ((atk * 1.2 + hurt_value/round) * atk_times_adjust[atk_times] + addDamage * atk_times) * round
	local atk_valueB = atk_valueA * (critPer * (1.5 + critValue) + (1 - critPer))*(1 + element / 600 / level)*(1 + hurt_promoteA + hurt_promoteB)
	local atk_valueC = atk_valueB * (1 - (target_def - ignore_def)/((target_def - ignore_def) + 300 * level))/(1 - target_def / (target_def + 300 * level))

	local def_valueA = hp + (atk_valueC * suck / 2 + hp_revert * round)*(1 + robust) + hurt_absorb * def_times
	local def_valueB = def_valueA / (1 - def/(level * 300 + def))/(1 - hurt_reduceA)/(1 - hurt_reduceB)
	local def_valueC = def_valueB * ((target_critPer - reduceCritPer)/(1.5 + target_critValue - reduceCritValue) + 1 - (target_critPer - reduceCritPer))/
		(target_critPer/(target_critValue + 1.5) + 1 - target_critPer )

	return (atk_valueC + def_valueC) / 5
end

--评分计算方式（常规）
local function common_capacity(P)
	--[角色id] = 平均技能段数，物攻系数，法攻系数，每回合平均受击次数，普、群、单、宠伤系数，风、土、水、火、光、暗系精通
	local role_table = {
		[11000] = {1,1,1,2,0.25,0.25,0.25,0.25,1,1,0,0,0,1},
		[11001] = {2,0.1,1,2,0.25,0.25,0.25,0.25,0,0,1,0,0,0},
		[11002] = {2,1,0.1,2,0.5,0.5,0,0,0,0,0,0,1,0},
		[11003] = {1,0.1,1,2,0.25,0,0.25,0,0,0,0,0,1,0},
		[11004] = {1,0.1,1,2,0.5,0,0,0.5,0,1,0,0,0,0},
		[11007] = {1,0.1,1,2,0.75,0,0.25,0,0,0,0,0,0,1},
		[11008] = {2,0.1,1,2,0.5,0.25,0,0,0,0,1,0,0,0},
		[11009] = {1,0.1,1,2,0.25,0,0.25,0,1,0,0,0,0,0},
		[11012] = {1,0.1,1,4,0.25,0.25,0,0.5,0,1,0,0,0,0},
		[11013] = {1,1,0.1,4,0.25,0.25,0,0,0,0,0,1,0,0},
		[11014] = {3,0.1,1,2,0.25,0.75,0,0,0,0,0,1,0,0},
		[11022] = {2,1,0.1,2,0.25,0.5,0.25,0,0,0,0,1,0,0},
		[11023] = {1,1,0.1,2,0.25,0,0.25,0.25,0,0,0,0,1,0},
		[11024] = {2,1,0.1,4,0.25,0.25,0,0.25,0,0,0,0,0,1},
		[11028] = {2,1,0.1,2,0.5,0.25,0.25,0,1,0,0,0,0,0},
	}

	--确定当前角色
	local role_id = nil
	for k,_ in pairs(role_table) do
		if P[k] > 0 then
			role_id = k
			break
		end
	end

	if not role_id then return 0 end

	--统一数值
	local critPer = P.critPer --暴击率
	local critValue = P.critValue --暴击伤害
	local reduceCritPer = P.reduceCritPer --免暴率
	local reduceCritValue = P.reduceCritValue --免暴伤害
	local hp = P.hpp --生命
	local hp_revert = P.hpRevert --生命回复
	local robust = P.robust --强健
	local hurt_absorb = (P.phyDamageAbsorb + P.magicDamageAbsorb + (P[1601] + P[1611] + P[1621] + P[1631]) / 2)  / 2 --伤害吸收
	local def = (P.armor + P.resist) / 2 --防御
	local hurt_reduceA = (P.phyDamageReduce + P.magicDamageReduce) / 2 --物理/法术伤害减免
	local hurt_reduceB = (P[1602] + P[1612] + P[1622] + P[1632]) / 4 --普、单、群、宠伤害减免

	--分歧数值
	local atk = P.ad * role_table[role_id][2] + P.ap * role_table[role_id][3] --攻击
	local addDamage = P.addPhyDamage * role_table[role_id][2] + P.addMagicDamage * role_table[role_id][3] +
		P[1603] * role_table[role_id][5] + 
		P[1613] * role_table[role_id][6] +
		P[1623] * role_table[role_id][7] + 
		P[1633] * role_table[role_id][8] --附加伤害
	local hurt_promoteA = P.phyDamagePromote * role_table[role_id][2] + P.magicDamagePromote * role_table[role_id][3] --物理/法术伤害加成
	local ignore_def = P.ignoreArmor * role_table[role_id][2] + P.ignoreResist * role_table[role_id][3] --无视防御
	local ignore_def_per = 	P.ignoreArmorPer * role_table[role_id][2] + P.ignoreResistPer * role_table[role_id][3] --无视防御比例
	local suck = P.phySuck * role_table[role_id][2] + P.magicSuck * role_table[role_id][3] --吸血	
	local hurt_promoteB = P[1604] * role_table[role_id][5] + 
		P[1614] * role_table[role_id][6] + 
		P[1624] * role_table[role_id][7] + 
		P[1634] * role_table[role_id][8] --普、群、单、宠伤害加成
	local element = P.airMaster * role_table[role_id][9] + 
		P.dirtMaster * role_table[role_id][10] + 
		P.waterMaster * role_table[role_id][11] + 
		P.fireMaster * role_table[role_id][12] + 
		P.lightMaster * role_table[role_id][13] + 
		P.darkMaster * role_table[role_id][14] --元素精通

	--技能树增加战力的属性id
	local skill_tree_id = { 
		{10001,10002,10003},
		{10011,10012,10013},
		{10021,10022,10023},
		--{10031,10032,10033},
		--{10041,10042,10043},
		--{10051,10052,10053},
		--{10061,10062,10063}
	}
	local capacity_skill = P[10000]
	local capacity_diamond = {}
	local capacity_max_value = 0
	local capacity_max_index = 1

	for k,v1 in ipairs(skill_tree_id) do
		for _,v2 in ipairs(v1) do
			capacity_diamond[k] = (capacity_diamond[k] or 0) + P[v2]
		end
		if capacity_diamond[k] > capacity_max_value then
			capacity_max_value = capacity_diamond[k]
			capacity_max_index = k
		end
	end

	for k,v in ipairs(capacity_diamond) do
		if k == capacity_max_index then
			capacity_skill = capacity_skill + v
		else
			capacity_skill = capacity_skill + v * 0.2
		end
	end

	local capacity = (capacity_skill / 2 + atk + addDamage * 2 + ignore_def + element) * 
		(1 + hurt_promoteA + hurt_promoteB + suck + ignore_def_per + critPer + critValue) + 
		(hp * 0.5 + hp_revert * 2 + def + hurt_absorb * 2) * 
		(1 + reduceCritPer + reduceCritValue + robust + hurt_reduceA + hurt_reduceB)

	return capacity / 2
end	

--计算装备评分
local function calc_score(P)
	local score = (P.ad + P.ap) * 1 + 
		(P.addPhyDamage + P.addMagicDamage) * 2 +
		(P.ignoreArmor + P.ignoreResist) * 1 +
		(P.armor + P.resist) * 1 + 
		(P.phyDamageAbsorb + P.magicDamageAbsorb) * 2 + 
		P.hpp * 0.5 + P.hpRevert * 2 + 
		(P.airMaster + P.waterMaster + P.fireMaster + P.dirtMaster + P.lightMaster + P.darkMaster) * 1
	
	return score / 2
end

return {
	capacity = function(P) return math.ceil(common_capacity(P)) end,
	calc_score = function(P) return math.ceil(calc_score(P)) end,
	--生命
	--改变hpp时hp也会增加，hp是hpp减去伤害后的值
	hp = function(P) return P.baseHp + P.extraHp + (P.baseAd + P.extraAd) * P[7902] / 10000 + (P.baseAp + P.extraAp) * P[7903] / 10000 end,
	hpp = function(P) return P.baseHp + P.extraHp + (P.baseAd + P.extraAd) * P[7902] / 10000 + (P.baseAp + P.extraAp) * P[7903] / 10000 end,
	baseHp = function(P) return P[1501] * (1 + P[1505] / 10000) end,
	extraHp = function(P) return (P[1502] + P[1507] * (1 + P[1508] / 10000)) * (1 + P[1506] / 10000) end,
	
	--每回合生命回复
	hpRevert = function(P) return (P.baseHpRevert + P.extraHpRevert) *  ( 1 + P[1233] / 10000 ) end,
	baseHpRevert = function(P) return P[1511] * (1 + P[1515] / 10000 + P[1237] / 10000) end,
	extraHpRevert = function(P) return (P[1512] + P[1514] / 10000 * P.hpp) * (1 + P[1516] / 10000) end,
	
	--法力值
	mp = function(P) return P.baseMp + P.extraMp end,
	mpp = function(P) return P.baseMp + P.extraMp end,
	baseMp = function(P) return P[1701] * (1 + P[1705] / 10000) end,
	extraMp = function(P) return P[1702] * (1 + P[1706] / 10000) end,
	
	--每回合法力回复
	mpRevert = function(P) return P.baseMpRevert + P.extraMpRevert end,
	baseMpRevert = function(P) return P[1711] * (1 + P[1715] / 10000) end,
	extraMpRevert = function(P) return (P[1712] + P[1714] / 10000 * P.mpp) * (1 + P[1716] / 10000) end,
	
	--释放技能时法力值消耗量减少比例
	mpSavePer = function(P) return P[1717] / 10000 end,
	
	--能量energy
	ep = function(P) return P.initEp end,
	epp = function(P) return P[1721] end,
	
	--能量回复
	epRevert = function(P) return P[1722] end,
	
	--初始能量
	initEp = function(P) return P[1723] end,
	
	--怒气fury
	fp = function(P) return 0 end,
	fpp = function(P) return P[1731] end,
	
	--怒气增长:攻击时额外增加的怒气
	fpPromote = function(P) return P[1732] end,	
	
	--速度
	speed = function(P) return P[1211] + P[7904] * (P.hpp - P.hp) / math.max(1,P.hpp) * 10 - P[7094] * 0.5 end,
	
	--连击值:提升普通攻击的连击率
	combo = function(P) return math.min(5,math.max(0,(P[1212] + P.speed * 100) / 10000 - 1)) end,
	
	--物理攻击
	ad = function(P) return P.baseAd + P.extraAd  + (P.baseHp + P.extraHp) * P[5003] / 10000 +  (P.baseAd + P.extraAd) * P[5006] / 10000 * (P.hpp - P.hp) / math.max(1,P.hpp) * 100 end,
	baseAd = function(P) return (P[1001] + P[1003])* (1 + P[1005] / 10000) end,
	extraAd = function(P) return (P[1002] + P[1008] * (1 + P[1004] / 10000) + P[1007] / 10000 * P.mpp ) * (1 + P[1006] / 10000) end,
	
	--魔法攻击
	ap = function(P) return P.baseAp + P.extraAp end,
	baseAp = function(P) return (P[1101] + P[1003]) * (1 + P[1105] / 10000) end,
	extraAp = function(P) return (P[1102] + P[1108] * (1 + P[1004] / 10000) + P[1107] / 10000 * P.mpp ) * (1 + P[1106] / 10000) end,
	
	--护甲
	armor = function(P) return P.baseArmor + P.extraArmor + (P.baseHp + P.extraHp) * P[5001] / 10000 + (P.baseAd + P.extraAd) * P[5004] / 10000 end,
	baseArmor = function(P) return P[1301] * (1 + P[1305] / 10000) end,
	extraArmor = function(P) return (P[1302] + P[1307] * (1 + P[1308] / 10000)) * (1 + P[1306] / 10000) end,
	
	--魔抗
	resist = function(P) return P.baseResist + P.extraResist + (P.baseHp + P.extraHp) * P[5002] / 10000 + (P.baseAd + P.extraAd) * P[5005] / 10000 end,
	baseResist = function(P) return P[1401] * (1 + P[1405] / 10000) end,
	extraResist = function(P) return (P[1402] + P[1407] * (1 + P[1408] / 10000)) * (1 + P[1406] / 10000) end,
	
	--物理/魔法伤害减免
	phyDamageReduce = function(P) return P[1321] / 10000 - P[7093] * 0.002 end,
	magicDamageReduce = function(P) return P[1421] / 10000 end,
	
	--物理穿透
	ignoreArmor = function(P) return P[1011] end,
	ignoreArmorPer = function(P) return math.min(0.6, P[1012] / 10000) end,
	ignoreExtraArmorPer = function(P) return math.min(0.6, P[1013] / 10000) end,
	
	--魔法穿透
	ignoreResist = function(P) return P[1111] end,
	ignoreResistPer = function(P) return math.min(0.6, P[1112] / 10000) end,
	ignoreExtraResistPer = function(P) return math.min(0.6, P[1113] / 10000) end,
	
	--物理/法术吸血
	phySuck = function(P) return math.min(0.4, P[1031] / 10000) end,
	magicSuck = function(P) return math.min(0.4, P[1131] / 10000) end,
	
	--物理/魔法伤害加成
	phyDamagePromote = function(P) return P[1021] / 10000 end,
	magicDamagePromote = function(P) return P[1121] / 10000 end,
	
	--附加物理/魔法/真实伤害
	addPhyDamage = function(P) return P[1022] + P[1024] * (1 + P[1025] / 10000) end,
	addMagicDamage = function(P) return P[1122] + P[1124] * (1 + P[1025] / 10000) end,
	addTrueDamage = function(P) return P[1222] + P[1225] * (1 + P[1226] / 10000) end,
	
	--暴击和免暴
	critPer = function(P) return P[1201] / 10000 + P.hp / math.max(1,P.hpp) * P[5007] /10000 + (P.hpp - P.hp)/math.max(1,P.hpp) * P[5008]/100 end,
	critValue = function(P) return math.min(6,P[1202] / 10000) end,
	reduceCritPer = function(P) return P[1203] / 10000 end,
	reduceCritValue = function(P) return P[1204] /10000 end,
	
	--降低攻击者的物理/魔法伤害
	phyDamageDebase = function(P) return P[1023] / 10000 end,
	magicDamageDebase = function(P) return P[1123] / 10000 end,
	
	
	--伤害吸收:承受伤害时降低一定的数值
	phyDamageAbsorb = function(P) return P[1322] end,
	magicDamageAbsorb = function(P) return P[1422] end,
	
	--韧性:降低被控制的概率
	tenacity = function(P) return math.min(100,math.max(0,P[1231] +P[1234]/100 - P[7092] * 0.05)) end,
	
	--祝福：治疗、护盾类技能的效果提升比例
	bless = function(P) return P[1232] / 10000 end,
	
	--强壮：接受治疗、生命回复、生命偷取的效果提升比例
	robust = function(P) return P[1233] / 10000 end,

	-- 每轮恢复行动力点数(程序使用)
	dizzy =  function(P) return math.max(0,1 - P[7010]) end,

	--失控（程序使用）
	outcontrol = function(P) return P[7011] end,
	--混乱
    chaos = function(P) return P[7009] end,

	--风、土、水、火、光、暗系精通
	airMaster = function(P) return (P[1801] +P[1807] +(P[1818] + P[1824])*(1 + P[1831]/10000))*(1 + P[1811]/10000 + P[1817]/10000) - P[7092] * 0.5 end,
	dirtMaster = function(P) return (P[1802] +P[1807] + (P[1819] + P[1824]) *(1 + P[1831]/10000) )*(1 + P[1812]/10000 + P[1817]/10000) end,
	waterMaster = function(P) return (P[1803] +P[1807] + (P[1820] + P[1824]) *(1 + P[1831]/10000) )*(1 + P[1813]/10000 + P[1817]/10000) - P[7094] * 0.5 end,
	fireMaster = function(P) return (P[1804] +P[1807] + (P[1821] + P[1824]) *(1 + P[1831]/10000) )*(1 + P[1814]/10000 + P[1817]/10000) - P[7091] * 0.5 end,
	lightMaster = function(P) return (P[1805] +P[1807] + (P[1822] + P[1824]) *(1 + P[1831]/10000))*(1 + P[1815]/10000 + P[1817]/10000) end,
	darkMaster = function(P) return (P[1806] +P[1807]  + (P[1823] + P[1824]) *(1 + P[1831]/10000) )*(1 + P[1816]/10000 + P[1817]/10000) end,

	--技能cd
	skill_cast_cd = function(P) return P[2001] end,
	skill_init_cd = function(P) return P[2002] end,
	
	--法力消耗类型
	skill_consume_mp = function(P) return P[8000] end,
	skill_consume_ep = function(P) return P[8001] end,
	skill_consume_fp = function(P) return P[8002] end,

	--陆水银钻石属性
	diamond_index = function(P) return P[21000] end,
	
	enter_script = function(P) return "enter_script" end,
}
