local RAND = RAND or math.random

--返回可被单体技能选为目标的所有目标
function Target_list(enemys, type)
	enemies = enemies or FindAllEnemy()
	see_rank = 7013
	hide_rand = 7000

	local chaofeng_list = {}
	local normal_list = {}
	local yinshen_list = {}
	local high_chaofeng_list = {}

	local fanchaofeng = false
	if type == "fanchaofeng" then
		fanchaofeng = true
	end

	local fanyin = false
	if type == "fanyin" then
		fanyin = true
	end

	local all_targets = {}
	for _, role in ipairs(enemies) do
		table.insert(all_targets, role)
		for _, pet in ipairs(UnitPetList(role)) do		
			table.insert(all_targets, pet)
		end
	end

	for _, v in ipairs(all_targets) do
		if v[7000] > 10 then
			table.insert(high_chaofeng_list, v)
		end

		if v[hide_rand] > attacker[see_rank] and not fanchaofeng then
			table.insert(chaofeng_list, v)
		elseif v[hide_rand] < attacker[see_rank] and not fanyin then
			table.insert(yinshen_list, v)
		else
			table.insert(normal_list, v)
		end
	end
	
	local choose_list = {}
	if #high_chaofeng_list > 0 then
		choose_list = high_chaofeng_list
	elseif #chaofeng_list > 0 then
		choose_list = chaofeng_list
	elseif #normal_list > 0 then
		choose_list = normal_list
	end
	
	return choose_list
	
end

--返回被aoe技能攻击到的所有目标
function All_target_list(enemys, skill_see_id)
	local enemys = enemys or FindAllEnemy();
	local all_targets = {}
	local high_chaofeng_list = {}

	for _, role in ipairs(enemys) do
		if role[7000] > 10 then
			table.insert(high_chaofeng_list, role)
		end

		table.insert(all_targets, role)
		for _, pet in ipairs(UnitPetList(role)) do		
			table.insert(all_targets, pet)
		end
	end

	if #high_chaofeng_list > 0 then
		return high_chaofeng_list
	end

	return all_targets
end

--护盾计算
function Shield_calc(buff, bullet)
	if bullet.hurt_disabled == 1 then
		return
	end

	if buff[7096] > 0 then
		if buff[7096] > (bullet.ShieldHurt + bullet.hurt_final_value) then
			buff[7096] = buff[7096] - bullet.ShieldHurt - bullet.hurt_final_value;			
			UnitShowNumber(bullet.target, math.floor(bullet.ShieldHurt + bullet.hurt_final_value), "hitpoint", "hurt_dun", "吸收")
			bullet.ShieldHurt = 0
			bullet.hurt_final_value = 0
		else	
			UnitShowNumber(bullet.target, math.floor(buff[7096]), "hitpoint", "hurt_dun", "吸收")
			buff[7096] = 0
			UnitRemoveBuff(buff)

			if bullet.ShieldHurt >= buff[7096] then
				bullet.ShieldHurt = bullet.ShieldHurt - buff[7096]
			else
				bullet.hurt_final_value = bullet.hurt_final_value - (buff[7096] - bullet.ShieldHurt)
			end
		end
	else
		UnitRemoveBuff(buff)
	end
end

--[[
	宠物选择目标
]]
function Pet_targets()
    local partners = FindAllPartner()
	local allTargets = Target_list()

	return allTargets or {}
end

local script_data = nil

function Add_Halo_Buff(target, id, _round, content, icon)
	script_data = script_data or GetBattleData()
	script_data.Halo_Buff_List = script_data.Halo_Buff_List or {}
	local buff = Common_UnitAddBuff(target, id, _round, content, icon)
	table.insert(script_data.Halo_Buff_List , buff)
	return buff
end

function Set_Current_Halo(skill ,value)
	script_data = script_data or GetBattleData()

	if not script_data.current_Halo and not skill then
		return
	end
	
	script_data.current_Halo = nil
	if script_data.Halo_Buff_List then
		for k ,v in pairs(script_data.Halo_Buff_List) do
			UnitRemoveBuff(v)
		end
	end
	script_data.Halo_Buff_List = nil

	if skill then
		ShowBattleHalo(skill)
		script_data.current_Halo = {
			id = skill.id,
			side = skill.owner.side,
			value = value or 5000,
			icon = skill.icon,
			element = skill.skill_element
		}
	else
		ShowBattleHalo()
	end
end
--[[
光环对抗
传入 value_id ，表示光环成功率加成的属性id ,默认0
对抗失败时，返还 1 ，并移除原有得光环
队友的光环必定对抗成功
]]

function Halo_confrontation(attacker, skill, value)

	script_data = script_data or GetBattleData()
	if not script_data.current_Halo then
		Set_Current_Halo(skill, value)
		return 0
	end
	if script_data.current_Halo and script_data.current_Halo.side == attacker.side then
		Set_Current_Halo(skill, value)
		return 0
	end

	if script_data.current_Halo.value == "max" then
		Common_AddStageEffect("UI/fx_ghj_lost", {duration = 3, scale= 1, rotation = 0, offset = {0.42, 0, 0}, Halo_icon = {skill.icon, script_data.current_Halo.icon}});
		Common_Sleep(attacker, 2)
		return 1
	end

	if RAND(1, script_data.current_Halo.value + value) <= value then
		Common_AddStageEffect("UI/fx_ghj_win", {duration = 3, scale= 1, rotation = 0, offset = {0.42, 0, 0}, Halo_icon = {skill.icon, script_data.current_Halo.icon}});
		Common_Sleep(attacker, 2)
		Set_Current_Halo(skill, value)
		return 0
	end

	Common_AddStageEffect("UI/fx_ghj_lost", {duration = 3, scale= 1, rotation = 0, offset = {0.42, 0, 0}, Halo_icon = {skill.icon, script_data.current_Halo.icon}});
	Common_Sleep(attacker, 2)
	return 1
end

function FindEmptyPos(list ,side)
	local side = side or 2 
	local targets = (side == 1 and FindAllEnemy()) or FindAllPartner() 
	for k , v in ipairs(targets) do
		for k2, v2 in ipairs(list) do
			if v.pos == v2 then
				table.remove(list, k2)
			end
		end
	end
	return list
end

--移除某个id的buff若干次
function ReapeatReomveBuff(target, change_num)
	local buffs = UnitBuffList(target)
	if change_num > 0 then
		for k, v in ipairs(buffs) do
			if v.id == buff_id  then
				UnitRemoveBuff(v)
				change_num = change_num - 1
				if change_num == 0 then
					break
				end
			end
		end	
	end
end 

local function NewLine(str, len)
    local final_str = ""
    for i = 1, math.ceil(#str / 3 / len) do
        local offset = (i - 1) * len * 3
        local sub_str = string.sub(str ,offset + 1 , offset + 3 * len)
        final_str = final_str .. sub_str .. "\n"
    end
    return final_str
end

function Show_Dialogue(target, text, duration, effect, pass_random, cfg)	
	local pass_random = pass_random or 0.3
	local cfg = cfg or {offset = {0, -1, 0}, scale = 0.8}

	if target.side == 1 then
		cfg.scale = 0.2
	end

	if RAND(1,100) <= pass_random * 100 then
		text = NewLine(text, 9)
		ShowDialog(target, text, duration, effect, cfg)
	end	
end

function ShowBuffEffect(role, icon, name, isUp, interval)
	UnitShowBuffEffect(role, name, isUp)
end

function common_enter(attacker)
	--角色被动，我方角色根据id，敌方角色根据mode来加buff
	if attacker.id < 19999 then
		Common_UnitAddBuff(attacker, attacker.id);
	else	
		Common_UnitAddBuff(attacker, attacker.mode);
	end
	Common_UnitAddBuff(attacker, 99999);
	Common_UnitAddBuff(attacker, 99998);
	Common_UnitAddBuff(attacker, 99995);
	Common_UnitAddBuff(attacker, 99997);
end

function Common_AddStageEffect(effect_name, cfg)
	AddStageEffect(effect_name, cfg)
end

function Common_UnitAddEffect(role, effect_name, cfg)
	local cfg = cfg or {}
	cfg.scale = cfg.scale or 1

	if role.side == 1 then
		cfg.scale =  cfg.scale * 1
	else
		cfg.scale =  cfg.scale * 1.6
	end

	UnitAddEffect(role, effect_name, cfg)
end

--[[
	处理韧性相关的状态包含：眩晕、沉默的控制效果，流血、灼烧等数值效果
]]
local _debuff_list = {
	[7000] = {},
	[7001] = {resist_id = 7201},
	[7002] = {resist_id = 7202},
	[7003] = {resist_id = 7203},
	[7004] = {resist_id = 7204},
	[7005] = {resist_id = 7205},
	[7006] = {resist_id = 7206},
	[7007] = {resist_id = 7207},
	[7008] = {resist_id = 7208},
	[7009] = {resist_id = 7209},
	[7010] = {resist_id = 7210},
	[7011] = {resist_id = 7211},
	[7012] = {},
	[7013] = {},
	[7097] = {},
	[7098] = {},
	[7099] = {},
}

function Common_UnitAddBuff(target, id, debuff_value, content)
	if target == nil then
		return
	end

	content = content or {}
	content.attacker = attacker

	if content.shield and content.shield ~= 0 then
		content.shield = content.shield * (1 + attacker.bless) 
		if content.shield_name then
			UnitShowNumber(target, math.floor(content.shield), "hitpoint", "hurt_normal", content.shield_name)
		end
		UnitShowBuffEffect(target, "护盾值up", true)
		content[7096] = content.shield
	end

	if content.shield then
		local buffs = UnitBuffList(target)
		for i, v in ipairs(buffs) do
			if v.id == id then
				v[7096] = content.shield or 0
			end
		end
	end

	local cfg = LoadBuffCfg(id)

	if cfg then
		content.round = content.round or cfg.round
		content.isDebuff = content.isDebuff or cfg.isDebuff
		content.isRemove = content.isRemove or cfg.isRemove
	
		if cfg.type >= 2 then
			local buffs = UnitBuffList(target)
			for i, v in ipairs(buffs) do
				if v.id == id then
					if cfg.type == 2 then 
						v.round = content.round 
						v[7096] = v[7096] + (content.shield or 0)
						return v 
					end
					if cfg.type == 3 then v.round = content.round end
					if cfg.type == 4 then v[7096] = v[7096] + (content.shield or 0) return v end
				end
			end
		end

		for i= 1, 3, 1 do
			if attacker.uuid == target.uuid and attacker.pos >= 100 then
				break
			end

			local effect = cfg["buff_effect"..i]
			if effect and effect ~= "" and effect ~= "0" then
				UnitShowBuffEffect(target, effect, string.find(effect,"up"))
			end
		end
	end

	if cfg and _debuff_list[id] then
		local debuff_type = id
		local debuff_value = debuff_value or 1
		local returnPer = debuff_value * (1 - target.tenacity/100)

		if _debuff_list[id].resist_id and target[_debuff_list[id].resist_id] > 0 then
			return false
		end

		if RAND(1, 10000) <= returnPer * 10000 then
			--移除蓄力
			if debuff_type == 7008 or debuff_type == 7009 then
				local buffs = UnitBuffList(target)	
				for _, v  in ipairs(buffs) do
					if v.Is_Break == 1 then
						UnitRemoveBuff(v)
					end
				end		
			end
		else
			return false
		end
	end

	if content and content.effect and not content.effect.invariable then
		if target.side == 1 then
			content.effect.scale = 0.8
		else
			content.effect.scale = 1.5
		end
	end 

	local shield = content.shield or 0
	content.shield = nil;
	return UnitAddBuff(target, id, 0, {[8005] = shield}, content)
end	

function Common_Sleep(attacker, sleep)
	if attacker.not_sleep > 0 then
		return
	end
	Sleep(sleep)
end

function Common_UnitConsumeActPoint(count)
	if attacker.not_consumeActPoint > 0 and (RAND(1,10000) < attacker.not_consumeActPoint_per) then
		attacker.not_consumeActPoint = attacker.not_consumeActPoint - 1
		return
	end

	UnitConsumeActPoint(count)
end

-- 1.物理 2.法术 3.治愈 4.护盾 5.召唤 6.削弱 7.强化
function Check_Button_All(skill_type)
	local button_list = {
		[1] = "UI/fx_butten_all",
		[2] = "UI/fx_butten_all",
		[3] = "UI/fx_butten_all_xue",
		[4] = "UI/fx_butten_dun",
		[5] = "UI/fx_pet_fz_run",
		[6] = "UI/fx_butten_ruo",
		[7] = "UI/fx_butten_qiang"
	}

	return button_list[skill_type] or "UI/fx_butten_all"
end

function GetRoleMaster(role)
	if role.mode == 11000 or role.mode == 11048 then
		local diamond_list = {
			[1] = "airMaster",
			[2] = "dirtMaster",
			[3] = "darkMaster"
		}
		return diamond_list[attacker.diamond_index] or "All_master"
	end

	if role._Max_Master ~= 0 then
		return role._Max_Master
	end

	local master_list = {
		"airMaster",
		"dirtMaster",
		"waterMaster",
		"fireMaster",
		"lightMaster",
		"darkMaster"
	}

    table.sort(master_list, function (a, b)
        if role[a] ~= role[b] then
            return role[a] > role[b]
        end
        return a > b
	end)

	local role_master = master_list[1]
	if role[master_list[1]] == role[master_list[2]] then
		role_master = "All_Master"
	end
	role._Max_Master = role_master
	return role._Max_Master
end


local function Kezhi_button(attacker, target)
	local master_kezhi_list = {
		airMaster   = {kezhi = "dirtMaster",  beikezhi = "fireMaster"},
		dirtMaster  = {kezhi = "waterMaster", beikezhi = "airMaster"},
		waterMaster = {kezhi = "fireMaster",  beikezhi = "dirtMaster"},
		fireMaster  = {kezhi = "airMaster",   beikezhi = "waterMaster"},
		lightMaster = {kezhi = "darkMaster",  beikezhi = "darkMaster"},
		darkMaster  = {kezhi = "lightMaster", beikezhi = "lightMaster"},
	}

	local attacker_master = GetRoleMaster(attacker)
	local target_master = GetRoleMaster(target)

	local is_chaofen = target[7002] > 0 and "_cf" or "" 

	if master_kezhi_list[attacker_master] and master_kezhi_list[attacker_master].kezhi == target_master then
		return "UI/fx_butten_you"..is_chaofen
	elseif master_kezhi_list[attacker_master] and master_kezhi_list[attacker_master].beikezhi == target_master then
		return "UI/fx_butten_lie"..is_chaofen
	else
		return "UI/fx_butten"..is_chaofen
	end

end

-- 1.物理 2.法术 3.治愈 4.护盾 5.召唤 6.削弱 7.强化
function Check_Button(attacker, target, skill_type)
	if attacker.side ~= 1 or attacker.pos >= 100 then
		return ""
	end

	local button_list = {
		[1] = Kezhi_button(attacker, target),
		[2] = Kezhi_button(attacker, target),
		[3] = "UI/fx_butten_xue",
		[4] = "UI/fx_butten_dun",
		[5] = "UI/fx_pet_fz_run",
		[6] = "UI/fx_butten_ruo",
		[7] = "UI/fx_butten_qiang"
	}

	return button_list[skill_type] or "UI/fx_butten"
end

--以某种属性排队
function SortWithParameter(target_list, parameter, opposite)
	table.sort(target_list, function(a,b)
		if not opposite then
			if a[parameter] ~= b[parameter] then
				return a[parameter] < b[parameter]
			end
			return a.uuid < b.uuid
		else
			if a[parameter] ~= b[parameter] then
				return a[parameter] > b[parameter]
			end
			return a.uuid > b.uuid
		end
	end)
	return target_list
end

--找到角色身上某个id的buff
function Common_FindBuff(target, id)
	if not target then
		return
	end

	local buff_list = {}
	local buffs = UnitBuffList(target)
	for _, buff in ipairs(buffs) do
		if buff.id == id then
			table.insert(buff_list, buff)
		end
	end
	
	return buff_list
end

function CreateSingSkill(attacker, type, Hurt)
	local Sing_Skill = {
		Hurt                = Hurt or 0,
		see_id              = attacker[7003] > 0 and "see" or 7003 ,
		fanchaofeng_id      = attacker[7004] > 0 and "fanchaofeng" or 7004,
		ignore_def_order_id = attacker[7005] > 0 and "see" or 7005,
	}

	if type == "one" then
		function Sing_Skill:target_list()
			local list = Target_list(nil, self.see_id, self.fanchaofeng_id, self.ignore_def_order_id)
			local target = list[RAND(1,#list)]
			return {target}
		end
	elseif type == "all" then
		function Sing_Skill:target_list()
			local list = All_target_list(nil, self.see_id)
			return list
		end
	elseif type == "all_partner" then
		function Sing_Skill:target_list()
			local list = FindAllPartner()
			return list
		end
	elseif type == "all_dead_partner" then
		function Sing_Skill:target_list()
			local list = {}
			for k, v in ipairs(GetDeadList()) do
				if v.side == attacker.side then
					table.insert(list, v)
				end
			end
			return list
		end
	end
	return Sing_Skill
end

function add_buff_parameter(target, buff, reverse)
	if buff.cfg and buff.cfg ~= 0 then
		for i = 1, 3, 1 do
			local k = buff.cfg["parameter_"..i]
			local v = buff.cfg["value_"..i]
			target[k] = target[k] + v * reverse
		end
	end
	target["BuffID_"..buff.id] = target["BuffID_"..buff.id] + reverse
end

--[[
function dodge_judge(role, bullet, per)
	if bullet.heal_enable == 1 
	or bullet.hurt_disabled == 1 
	or bullet.skilltype >= 5
	or bullet.skilltype == 0
	then
		return false
	end

	if RAND(1, 10000) < per * 10000 then
		return true
	else
		return false
	end
end
]]

--[新脚本接口封装]---------------------------------------------------------------------------------------------
--[[子弹类型定义！！
	1	普攻
	2	单体攻击
	3	群体攻击
	4	召唤物攻击
	5	dot伤害
	6	反弹伤害
	7	反击伤害
	8	其他伤害来源,溅射,穿刺,链接 
	20	技能治疗
	21  持续治疗
	22  宠物治疗
	23  其他治疗
]]

local ExtraHurt = {
	[1] = 30001,
	[2] = 30002,
	[3] = 30003,
	[4] = 30004,
}

local ExtraAttacks = {
	[1] = 30011,
	[2] = 30012,
	[3] = 30013,
	[4] = 30014,
}

function Common_OriHurt(skill)
	return (attacker[30000]/10000 + attacker[ExtraHurt[skill.sort_index]]/10000) * attacker.ad
end

--发射技能的主要子弹
function Common_FireBullet(id, attacker, targets, skill, content)
	local content = content or {}
	local Duration = content.Duration or 0.15
	local Interval = content.Interval or 0.16

	local Hurt = (skill and skill.skill_type ~= 8) and Common_OriHurt(skill) or 0
	local TrueHurt = (skill and skill.skill_type == 8) and Hurt or 0
	local Type = skill and skill.skill_place_type or 0
	local Attacks_Total = skill and (attacker[ExtraAttacks[skill.sort_index]] + 1) or 1
	local Element = skill and skill.skill_element or 0
	local Name = ""
	if skill and skill.name ~= "普通攻击" then
		Name = skill.owner.pos < 100 and skill.name or "援助"
	end

	Hurt = content.Hurt or Hurt
	TrueHurt = content.TrueHurt or TrueHurt
	Type = content.Type or Type
	Attacks_Total = content.Attacks_Total or Attacks_Total
	Element = content.Element or Element
	Name = content.Name or Name

	for i = 1, Attacks_Total, 1 do 
		for k, target in ipairs(targets) do
			local bullet = CreateBullet()
			bullet.hurt = Hurt
			bullet.trueHurt = TrueHurt
			if Type >= 20 then
				bullet.healValue = Hurt
				bullet.hurt_disabled = 1	
				bullet.heal_enable = 1
			end

			bullet.Type = Type			
			bullet.Element = Element
			bullet.Attacks_Total = Attacks_Total
			bullet.Attacks_Count = i
			bullet.num_text = Name

			if content.parameter then
				for k, v in pairs(content.parameter) do
					bullet[k] = bullet[k] + v
				end
			end

			if Type ~= 21 then
				for k, v in pairs(attacker.property_list) do
					if k >= 300000 and k <= 309999 then
						bullet[k] = bullet[k] + v
					else
						local new_k = k - skill.sort_index * 10000
						if new_k >= 300000 and new_k <= 309999 then
							bullet[new_k] = bullet[new_k] + v
						end
					end
				end
			end
		
			print("----@@@@@!!!!!!         ", attacker.name , "发射到", target.name)
			Common_Sleep(attacker, Interval)
			BulletFire(bullet, target, Duration)
		end
	end
end

--每次对随机目标发射子弹
function FireRadomTarget(id, attacker, targets, skill, content)
	local content = content or {}
	local random_times = content.Attacks_Total
	content.Attacks_Total = 1

	if content.Duration and content.Duration > 0 then
		content.Interval = content.Duration + 0.01
	end

	for i = 1, random_times, 1 do
		local correct_list = {}
		for k, v in ipairs(former_list) do 
			if v.hp > 0 then
				table.remove(correct_list, v)
			end
		end

		if not next(correct_list) then
			break
		end

		local target = correct_list[RAND(1, #correct_list)]
		Common_FireBullet(id, attacker, {target}, skill, content)
	end
end

--对选定目标及额外两个目标发射
function FireRadomTarget(id, attacker, targets, skill, content)
	local content = content or {}
	local random_times = content.Attacks_Total
	content.Attacks_Total = 1

	if content.Duration and content.Duration > 0 then
		content.Interval = content.Duration + 0.01
	end

	for i = 1, random_times, 1 do
		local correct_list = {}
		for k, v in ipairs(former_list) do 
			if v.hp > 0 then
				table.remove(correct_list, v)
			end
		end

		if not next(correct_list) then
			break
		end

		local target = correct_list[RAND(1, #correct_list)]
		Common_FireBullet(id, attacker, {target}, skill, content)
	end
end

function Common_Hurt(attacker, targets, element, value)
	Common_FireBullet(0, attacker, targets, nil, {
		Duration = 0,
		Interval = 0,
		Type = 5,
		Hurt = value,
		Element = element,
	})
end

function Common_Heal(attacker, targets, element, value ,content)
	local content = content or {}
	Common_FireBullet(0, attacker, targets, nil, {
		Duration = 0,
		Interval = 0,
		Type = content.Type or 21,
		Hurt = value,
		Element = element,
		Name = content.Name or ""
	})
end

--伤害子弹触发事件判断
function Hurt_Effect_judge(bullet, per)
	if bullet.Type == 0 or bullet.Type > 4 then
		return false
	end

	if per then
		return RAND(1, 10000) <= per * 10000
	end

	return true
end

--治疗子弹触发事件判断
function Heal_Effect_judge(bullet, per)
	if bullet.Type ~= 20 then
		return false
	end

	if per then
		return RAND(1, 10000) <= per * 10000
	end

	return true
end

--消耗
function Common_ChangeEp(role, value, show)
	if not value then
		ERROR_LOG("=========@@@@@@@  skill[8001] not exist")
		return
	end

	if role[7002] > 0 and value < 0 then
		return
	end

	UnitChangeMP(role, math.floor(value), "ep")
end

--目标选择
function Common_GetTargets(...)
	local info = select(1, ...)
	local target = info.target
	local target_list = {}

	if target == "enemy" then
		target_list = All_target_list()
	elseif target == "partner" then
		target_list = FindAllPartner()
	else	
		target_list = {target}
	end

	return target_list, All_target_list()
end

--从多个目标中 随机选x个
function RandomInTargets(target_list, num)
	local new_list = {}
	local former_list = {}
	for _, v in ipairs(target_list) do
		table.insert(former_list, v)
	end

	for i = 1, num, 1 do
		local index = RAND(1, #former_list)
		table.insert(new_list, former_list[index])
		table.remove(former_list, index)
		if not next(former_list) then
			 break
		end
	end

	return new_list
end

function Common_Relive(target, hp)
	UnitRelive(target, hp)
end

function Common_SummonPet(id, count, round, property)
	local id = id or 1
	local count = count or 1
	local round = round or 3

	local pet = SummonPet(id, count, round, {
		[1001] = attacker[1001],                          --基础攻击
		[1002] = attacker[1002],                          --装备攻击
		[1011] = attacker[1011] + attacker[1243],         --基础攻击加成（来自进阶、升星）
		[1012] = attacker[1012],                          --装备攻击加成
		[1013] = attacker[1013],						  --基础攻击加成2（来自装备00                                             、全局）
		[1022] = attacker[1022] + attacker[1241],	 	  --伤害加成
		[1031] = attacker[1031],						  --无视防御（在穿透前计算）
		[1032] = attacker[1032],							--攻击穿透
		[1201] = attacker[1201],							--暴击率
		[1202] = attacker[1202],							--暴击伤害
		[1203] = attacker[1203],							--免暴率
		[1204] = attacker[1204],							--暴伤减免
		[1211] = attacker[1211],							--速度
		[1221] = attacker[1221],							--治疗效果提升
		[1222] = attacker[1222],							--受到治疗效果提升
		[1231] = attacker[1231],							--护盾效果提升
		[1246] = attacker[1246],							--正值为降低，负值为提升
		[1301] = attacker[1301],							--基础防御
		[1302] = attacker[1302],							--装备防御
		[1311] = attacker[1311] + attacker[1243], 			--基础防御加成
		[1312] = attacker[1312],							--装备防御加成
		[1321] = attacker[1321],							--伤害吸收（在减免后计算）
		[1322] = attacker[1322] + attacker[1242],		    --伤害减免
		[1501] = attacker[1501],							--基础生命
		[1502] = attacker[1502],							--装备生命
		[1511] = attacker[1511] + attacker[1245], 			--基础生命加成
		[1512] = attacker[1512],							--装备生命加成
		[1521] = attacker[1521],							--生命回复
		[1522] = attacker[1522],							--生命回复提升
		[1801] = attacker[1801],							--角色的元素类型
		[1802] = attacker[1802],							--角色的元素类型
		[1803] = attacker[1803],							--角色的元素类型
		[1804] = attacker[1804],							--角色的元素类型
		[1805] = attacker[1805],							--角色的元素类型
		[1806] = attacker[1806],							--角色的元素类型
		[1807] = attacker[1807],							--角色的元素类型
		[1871] = attacker[1871],							--受到风系伤害时回血
		[1872] = attacker[1872],							--受到土系伤害时回血
		[1873] = attacker[1873],							--受到水系伤害时回血
		[1874] = attacker[1874],							--受到火系伤害时回血
		[1875] = attacker[1875],							--受到光系伤害时回血
		[1876] = attacker[1876],							--受到暗系伤害时回血
		[1877] = attacker[1877],							--受到伤害时时回血
		[1881] = attacker[1881],							--风系伤害提升
		[1882] = attacker[1882],							--土系伤害提升
		[1883] = attacker[1883],							--水系伤害提升
		[1884] = attacker[1884],							--火系伤害提升
		[1885] = attacker[1885],							--光系伤害提升
		[1886] = attacker[1886],							--暗系伤害提升
		[1887] = attacker[1887],							--伤害提升
		[1891] = attacker[1891],							--受到的风系伤害降低
		[1892] = attacker[1892],							--受到的土系伤害降低
		[1893] = attacker[1893],							--受到的水系伤害降低
		[1894] = attacker[1894],							--受到的火系伤害降低
		[1895] = attacker[1895],							--受到的光系伤害降低
		[1896] = attacker[1896],							--受到的暗系伤害降低
		[1897] = attacker[1897],							--受到的伤害降低		
	})
end

function Common_RemoveBuffRandom(target, isDebuff, num)
	local buff_list = UnitBuffList(target)
	local fit_list = {}
	for _, buff in ipairs(buff_list) do
		if buff.isRemove == 1 and buff.isDebuff == isDebuff then
			table.insert(fit_list, buff)
		end
	end

	local remove_count = 0
	for i = 1, num, 1 do
		if #fit_list == 0 then
			break
		end

		remove_count = remove_count + 1
		local index = RAND(1, #fit_list)
		UnitRemoveBuff(fit_list[index])
		table.remove(fit_list, index)
	end

	return remove_count
end

function Common_ChangeHp(role, value)
	
	
end

