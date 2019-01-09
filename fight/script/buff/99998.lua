--[子弹效果]
-------------------------------------------------
function onStart(target, buff)
end

-------------------------------------------------
function onEnd(target, buff)
end

-------------------------------------------------
function onTick(target, buff)
end

-------------------------------------------------
function onRoundEnd(target, buff)
end

-------------------------------------------------
function targetBeforeHit(target, buff, bullet)
end

-------------------------------------------------
function targetAfterHit(target, buff, bullet)
end

-------------------------------------------------
function attackerBeforeAttack(target, buff, bullet)
    --[对嘲讽目标造成额外伤害]
    if bullet[300030] > 0 and Hurt_Effect_judge(bullet) and bullet.target[7000] > 0 then
        bullet.damagePromote = bullet.damagePromote + bullet[300030] / 10000
    end

    --[造成伤害时附加x%目标最大生命的伤害（最大为自身攻击2倍）]
    if bullet[300040] > 0 and Hurt_Effect_judge(bullet) then
        bullet.damageAdd = bullet.damageAdd + math.min(target.ad * 2, bullet.target.hpp * bullet[300040] / 10000)
    end

    --[对冰冻目标造成额外伤害]
    if bullet[300050] > 0 and Hurt_Effect_judge(bullet) and bullet.target[7009] > 0 then
        bullet.damagePromote = bullet.damagePromote + bullet[300050] / 10000
    end
    
    --[对生命值低于30%的，造成额外伤害]
    if bullet[300100] > 0 and Hurt_Effect_judge(bullet) and bullet.target.hp/bullet.target.hpp <= 0.3 then
        bullet.damagePromote = bullet.damagePromote + bullet[300100] / 10000
    end    

    --[攻击时造成x%防御值的额外伤害]
    if bullet[300130] > 0 and Hurt_Effect_judge(bullet) then
        bullet.damageAdd = bullet.damageAdd + bullet[300130] / 10000 * target.armor
    end    
    
    --[治疗效果对生命低于40%的友军提高x%]
    if bullet[300150] > 0 and Heal_Effect_judge(bullet) and bullet.target.hp/bullet.target.hpp <= 0.4 then
        bullet.healPromote = bullet.healPromote + bullet[300150] / 10000
    end    
    
    --[治疗效果x%的概率移除目标1个减益效果]
    if bullet[300230] > 0 and Heal_Effect_judge(bullet) and RAND(1, 10000) <= bullet[300230] then
        local remove_count = Common_RemoveBuffRandom(bullet.target, 1, 1 + bullet[300232])
        if remove_count == 0 then
            bullet.healPromote = bullet.healPromote + bullet[300231] / 10000
        end
    end  

    --[攻击有x%的概率移除一个增益效果]
    if bullet[300240] > 0 and Hurt_Effect_judge(bullet) and RAND(1, 10000) <= bullet[300240] then
        local remove_count = Common_RemoveBuffRandom(bullet.target, 2, 1 + bullet[300242])
        if remove_count == 0 then
            bullet.damagePromote = bullet.damagePromote + bullet[300241] / 10000
        end
    end  


end

-------------------------------------------------
function attackerBeforeHit(target, buff, bullet)
end

-------------------------------------------------
function attackerAfterHit(target, buff, bullet)
    --[攻击后，概率冰冻对手]
    if bullet[300020] > 0 and Hurt_Effect_judge(bullet) then
        if bullet.target[7009] <= 0 then
            Common_UnitAddBuff(bullet.target, 7009, bullet[300010] / 10000)
        else
            --[如果对手冰冻，恢复能量]
            if bullet[300021] > 0 then
                Common_ChangeEp(target, bullet[300021])
            end
            --[如果对手已经冻结，概率延长1回合时间]
            if bullet[300022] > 0 and RAND(1, 10000) < bullet[300022] then
                local buff = Common_FindBuff(bullet.target, 7009)[1]
                buff.round = buff.round + 1
            end
        end
    end    

    --[如果目标未行动，概率降低30点速度，持续1回合]
    if bullet[300060] > 0 
    and Hurt_Effect_judge(bullet) 
    and bullet.target.action_count == bullet.target.round_count
    then
        Common_UnitAddBuff(bullet.target, 7010, bullet[300060] / 10000, {round = 1 + bullet[300062]})
    end    

    --[如果目标未行动，概率降低30点速度，持续2回合]
    if bullet[300070] > 0 and Hurt_Effect_judge(bullet) then
        Common_UnitAddBuff(bullet.target, 7010, bullet[300070] / 10000, {round = 2 + bullet[300071]})
    end    

    --[攻击后，概率重伤对手2回合]
    if bullet[300080] > 0 and Hurt_Effect_judge(bullet) then
        Common_UnitAddBuff(bullet.target, 7001, bullet[300080] / 10000)
    end    
    
    --[攻击时有概率造成麻痹一回合]
    if bullet[300090] > 0 and Hurt_Effect_judge(bullet) then
        Common_UnitAddBuff(bullet.target, 7002, bullet[300090] / 10000)
    end    
    
    --[攻击时有概率降低对手25点能量]
    if bullet[300120] > 0 and Hurt_Effect_judge(bullet) and RAND(1, 10000) <= bullet[300120] then
        Common_ChangeEp(bullet.target, -(25 + bullet[300121]), true)
    end    

    --[攻击时有x%概率封印对手一回合]
    if bullet[300160] > 0 and Hurt_Effect_judge(bullet) then
        Common_UnitAddBuff(bullet.target, 7003, bullet[300160] / 10000)
    end    

    --[攻击时x%概率造成2回合灼烧]
    if bullet[300170] > 0 and Hurt_Effect_judge(bullet) then
        Common_UnitAddBuff(bullet.target, 7007, bullet[300170] / 10000)
    end   

    --[击杀获得对手的能量]
    if bullet[300180] > 0 and Hurt_Effect_judge(bullet) and bullet.target.hp <= 0 then
        Common_ChangeEp(target, bullet.target.ep, true)
    end  
   
    --[攻击时x%概率造成晕眩]
    if bullet[300200] > 0 and Hurt_Effect_judge(bullet) then
        Common_UnitAddBuff(bullet.target, 7008, bullet[300200] / 10000)
    end  

    --[治疗效果x%的概率移除目标一个控制效果]
    if bullet[300220] > 0 and Heal_Effect_judge(bullet) and RAND(1, 10000) <= bullet[300220] then
        Common_RemoveBuffRandom(bullet.target, 1, 1)
    end  
    
    --[攻击时给能量最低的1名队友恢复x点能量]
    if bullet[300250] > 0 and Hurt_Effect_judge(bullet) and RAND(1, 10000) <= bullet[300250] then
        local partners = FindAllPartner()
        local sort_list = SortWithParameter(partners, "ep")
        for i = 1, 1 + bullet[300251], 1 do
            if not sort_list[i] then break end
            Common_ChangeEp(sort_list[i], bullet[300250], true)
        end
    end  

    --[攻击时x%的概率降低20%防御]
    if bullet[300260] > 0 and Hurt_Effect_judge(bullet) and RAND(1, 10000) <= bullet[300260] then
        Common_UnitAddBuff(bullet.target, 10004)
    end








    -------------------------------------------------------------
    if bullet[30030] > 0 then
		Common_UnitAddBuff(target, bullet[30030])
	end

	if bullet[30031] > 0 then
		local partners = FindAllPartner()
		for _, v in ipairs(partners) do 
			Common_UnitAddBuff(v, bullet[30031])
		end
	end

	if bullet[30032] > 0 then
		for _, v in ipairs(All_target_list()) do 
			Common_UnitAddBuff(v, bullet[30032])
		end
	end

	if bullet[30033] > 0 then
		Common_UnitAddBuff(target, bullet[30033])
	end
end

-------------------------------------------------
function onUnitDead(_, buff, target)  
end

