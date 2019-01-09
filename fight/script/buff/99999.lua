local is_Common_Sleep = 0
local script_data = GetBattleData()

function onStart(target, buff)
    -- print("信息===========!!!!!!!!!!!!  角色名字",target.name,"角色id",target.id, target.ad, target.ap)
    attacker.round_count = 1
end

function onRoundStart(target, buff)
        Common_ChangeEp(target, -100)


    if attacker.Show_Monster_info == 1 and attacker.round_count == 1 and attacker.side == 2 then
        ShowMonsterInfo()        
        Common_Sleep(attacker, 0.1)
    end
end

--生命恢复，魔法恢复
function onTick(target, buff)
    attacker[99999] = RAND(1,100)
    --超过回合，移除目标
    if attacker.round_count >= 50 and attacker.side == 2 then
        RemoveMonster(attacker)
    end 
end

local element_list = {
    [1] = {name = "水系"},
    [2] = {name = "火系"},
    [3] = {name = "土系"},
    [4] = {name = "风系"},
    [5] = {name = "光系"},
    [6] = {name = "暗系"},
}

--受到反弹伤害 延迟回合结束 防止伤害飘字跑偏
function targetAfterHit(target, buff, bullet)    
    if Hurt_Effect_judge(bullet) then
        if target.Aciton_Sing ~= 1 then
            UnitPlay(target, "hit", {speed = 1})
        end
    end

    if bullet.skilltype <= 4 and bullet.skilltype ~= 0 then
        target.hit_counts_byround = target.hit_counts_byround + 1
    end

    if bullet.isPhyResist == 1 then
        UnitShowNumber(bullet.target, "", "hitpoint", "hurt_dun", "免疫")
    elseif bullet.element_resist == 1 then
        UnitShowNumber(bullet.target, "", "hitpoint", "hurt_dun", element_list[bullet.element].name .. "免疫")
    end
end    

function onPostTick(target, buff)
    target.action_count = target.round_count
end

function onRoundEnd(target, buff)
    attacker.round_count = attacker.round_count + 1   
    target.hit_counts_byround = 0 
end

function attackerAfterHit(target, buff, bullet) 
    --处理吸血                          
    local suckValue = (target.suck + bullet.suck) * bullet.hurt          
    if suckValue > 0 and Hurt_Effect_judge(bullet) then
        --群体效果减半 
        if bullet.skilltype == 3 then
            local finalHeal = suckValue * 0.5;
            Common_Heal(target, {target}, 0, finalHeal)
        else
            local finalHeal = suckValue
            Common_Heal(target, {target}, 0, finalHeal)
        end
    end

    if bullet.ChuanCi > 0 and Hurt_Effect_judge(bullet) then
        local Hurt = bullet.hurt_final_value * bullet.ChuanCi

        if bullet.target.owner and bullet.target.owner ~= 0 then
            Common_Hurt(attacker, {bullet.target}, 0, Hurt, {Name = "穿刺"})
        else
            local pets = UnitPetList(bullet.target)
            Common_Hurt(attacker, {pets}, 0, Hurt, {Name = "穿刺"})
        end
    end
end

function attackerBeforeAttack(target, buff, bullet) 
    -- local rand_hit = ""
    -- if bullet.cfg or bullet.hit.cfg then
    --     rand_hit = "hit"..RAND(1,5)
    --     if bullet.cfg then bullet.cfg.hitpoint = rand_hit end
    --     if bullet.hit.cfg and bullet.hit.cfg.hitpoint ~= "root" then 
    --         bullet.hit.cfg.hitpoint = rand_hit 
    --     end
    -- end

    -- if bullet.hit and bullet.hit.cfg and bullet.hit.cfg.scale and not bullet.hit.cfg.invariable then
    --     if bullet.target.side == 1 then
    --         if bullet.target.owner and bullet.target.owner ~= 0 then
    --             bullet.hit.cfg.scale = bullet.hit.cfg.scale * 0.5
    --         else
    --             bullet.hit.cfg.scale = bullet.hit.cfg.scale * 0.7
    --         end
    --     else
    --         if bullet.target.owner and bullet.target.owner ~= 0 then
    --             bullet.hit.cfg.scale = bullet.hit.cfg.scale * 1.2
    --         else
    --             bullet.hit.cfg.scale = bullet.hit.cfg.scale * 1.8
    --         end
    --     end
    -- end

    if attacker.beat_back > 0 and bullet.hurt_disabled == 0 then
        bullet.num_text = "反击"
    end
end
