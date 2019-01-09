--[被动类效果]
-------------------------------------------------
function onStart(target, buff)
    if target.T_tick_hurt == 0 then
        target.T_tick_hurt = {}
    end

    if target.T_tick_heal == 0 then
        target.T_tick_heal = {}
    end
end

-------------------------------------------------
function targetAfterHit(target, buff, bullet)
    --[受到攻击后，概率冰冻对手]
    if target[300010] > 0 and Hurt_Effect_judge(bullet) then
        Common_UnitAddBuff(target, 7009, target[300010] / 10000)
    end

    --[受到攻击后，概率冰冻对手]
    if target[300110] > 0 and Hurt_Effect_judge(bullet) and RAND(1,10000) < target[300110] then
        Common_ChangeEp(bullet.attacker, -(25 + target[300121]), true)
    end

    --[受到攻击时x%概率提升随机一名队友5%的伤害]
    if target[300140] > 0 and Hurt_Effect_judge(bullet) and RAND(1,10000) < target[300140] then
        local partners = FindAllPartner()
        Common_UnitAddBuff(partners[RAND(1, #partners)], 10005)
    end

    --[受到攻击时，x%概率恢复一个随机友军5点能量]
    if target[300210] > 0 and Hurt_Effect_judge(bullet) and RAND(1,10000) < target[300210] then
        local partners = FindAllPartner()
        Common_ChangeEp(partners[RAND(1, #partners)], 5, true)
    end
    
end

-------------------------------------------------
function onTick(target, buff)
    --[持续伤害效果]
    if next(target.T_tick_hurt) then
        for _, v in ipairs(target.T_tick_hurt) do 
            Common_Hurt(target, {target}, 0, v.value, {
                Name = v.name ,
                Type = v.type ,
            })
        end 
    end

    --[常规回血]
    Common_Heal(target, {target}, 0, target.hpRevert)

    --[持续恢复效果]
    if next(target.T_tick_heal) then
        for _, v in ipairs(target.T_tick_heal) do 
            Common_Heal(target, {target}, 0, v.value, {
                Name = v.name ,
                Type = v.type ,
            })
        end
    end
end

-------------------------------------------------
function onPostTick(target, buff)

end
