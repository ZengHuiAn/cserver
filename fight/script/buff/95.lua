--[[蓄力通用buff
	sing_type 类型
	1.最差吟唱条：会被打断，会被击退

	2.普通吟唱条：会被打断，不会被击退，打断时技能释放失败

	3.特殊吟唱条：不会被打断，但被攻击时会减少进度

	4.无敌吟唱条：不会被打断，不会被减少进度

]]
local sing_type_list = {
	[1] = {BeatBack = 1 , Break = 1 },
	[2] = {BeatBack = 0 , Break = 1 },
	[3] = {BeatBack = 1 , Break = 0 },
	[4] = {BeatBack = 0 , Break = 0 },
}

function onStart(target, buff)
	target.Aciton_Sing = 1
	Common_UnitAddEffect(target, "UI/status_xuli", {
		duration = 3,
		hitpoint = "head",
	})	
	ChangeBuffEffect(buff, {
		name = "xuli",
		hitpoint = "root",
		scale = 1.2
	})

	--固定的成长格和可击退格
	buff.BeatBack_count = 1 + target.Sing_Speed_Change
	buff.Certainly_Increase = 1
	
	buff.Sing_Speed = buff.BeatBack_count + buff.Certainly_Increase

	buff.Next_Progress = buff.Sing_Speed
	buff.Total_Progress = buff.cfg ~= 0 and buff.cfg.value_2 or 2
	buff.sing_type = buff.cfg ~= 0 and buff.cfg.value_1 or 1

	buff.Current_Progress = 0
	buff.Current_BeatBack_count = buff.BeatBack_count
	
	buff.Is_BeatBack = sing_type_list[buff.sing_type].BeatBack
	buff.Is_Break = sing_type_list[buff.sing_type].Break

	SetSingBar(target, true, {
		type = buff.sing_type,
		current = buff.Current_Progress,
		total =  buff.Total_Progress,
		name = buff.Sing_Skill.name,
		beat_back = buff.Current_BeatBack_count,
		certainly_increase = buff.Certainly_Increase
	})
	UnitPlayLoopAction(target, "skill")
end

function onEnd(target, buff)
	SetSingBar(target, nil)
	UnitPlay(target, "idle")
	target.Aciton_Sing = 0

	if buff.tag_buff and buff.tag_buff ~= 0 then
		UnitRemoveBuff(buff.tag_buff)
	end
end

function onTick(target, buff)
	if target.hp <= 0 then
		return
	end

	buff.Current_BeatBack_count = buff.BeatBack_count  --可击退计数
	Common_UnitConsumeActPoint(1);
	buff.Current_Progress = buff.Current_Progress + buff.Next_Progress

	target.Current_Progress = buff.Current_Progress
	target.Total_Progress = buff.Total_Progress

	if buff.Current_Progress >= buff.Total_Progress then
		SetSingBar(target, true, {
			current = buff.Current_Progress,
			beat_back = buff.Current_BeatBack_count,
			certainly_increase = buff.Certainly_Increase
		})
		Sleep(0.5)
		buff.Sing_Skill:action()
		SetSingBar(target, nil)
		UnitRemoveBuff(buff);
		return
	end
	buff.Next_Progress = buff.Sing_Speed

	SetSingBar(target, true, {
		current = buff.Current_Progress,
		beat_back = buff.Current_BeatBack_count,
		certainly_increase = buff.Certainly_Increase
	})

end

function targetAfterHit(target, buff, bullet)
	if buff.Is_BeatBack == 1 then
		if buff.Current_BeatBack_count > 0 and bullet.skilltype == 4 then
			buff.Next_Progress = buff.Next_Progress - 1
			buff.Current_BeatBack_count = buff.Current_BeatBack_count - 1

			SetSingBar(target, true, {
				current = buff.Current_Progress,
				beat_back = buff.Current_BeatBack_count,
				certainly_increase = buff.Certainly_Increase
			})
		end
	end

	if target.Singup_waterhit == 1 
	and bullet.element == 1 
	and bullet.skilltype ~= 0 
	and bullet.skilltype <= 4 then
		buff.Current_Progress = buff.Current_Progress + 1
		SetSingBar(target, true, {
			current = buff.Current_Progress,
			beat_back = buff.Current_BeatBack_count,
			certainly_increase = buff.Certainly_Increase
		})
	end
end