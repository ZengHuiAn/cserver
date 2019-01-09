--宠物称号效果(以及生命恢复和吸血)
local script_data = GetBattleData()

local function debug_log(...)
    -- print(...)
end

function onStart(target, buff)
    debug_log("信息===========!!!!!!!!!!!!  角色名字",target.name,"角色id",target.id ,target.aromor , target.resist)
    attacker[1201] = attacker[1201] + attacker.owner[29017]
    attacker[1031] = attacker[1031] + attacker.owner.Title_SXMW 
    attacker[1131] = attacker[1131] + attacker.owner.Title_SXMW
    attacker[1201] = attacker[1201] + attacker.owner.Title_DT
    attacker[1202] = attacker[1202] + attacker.owner.Title_ZWXJ
end

--生命恢复，魔法恢复
function onTick(target, buff)
    local bullet_hprevert = CreateBullet_Bytype(6)
    bullet_hprevert.healValue = math.floor(target.hpRevert)
    BulletFire(bullet_hprevert, target, 0)
    --每回合恢复最大生命
    if attacker.owner[29015] > 0 then
        local bullet = CreateBullet_Bytype(6)
        bullet.healValue = attacker.hpp * attacker.owner[29015] / 10000 /attacker.count
        BulletFire(bullet,attacker, 0);
    end
end

function attackerBeforeHit(target, buff, bullet)
    if attacker.owner[660218] > 0 then
        local lowest = attacker.owner[660218]
        local per = RAND(lowest, 10000 + (10000 - lowest) * 2)/10000
        bullet.physicalHurt = bullet.physicalHurt * per
        bullet.magicHurt = bullet.magicHurt * per
    end
     --生命值低于60%时增伤
    if attacker.owner[29018] > 0 then 
        if attacker.hp_type == 2 and attacker.hp/attacker.hpp <= 0.6 then
            bullet.phyDamagePromote = bullet.phyDamagePromote + attacker.owner[29018] / 10000
            bullet.magicDamagePromote = bullet.magicDamagePromote + attacker.owner[29018] / 10000
        elseif attacker:first_hp()/attacker.hpp*attacker.count <= 0.6 and bullet.time == 1 then
            bullet.phyDamagePromote = bullet.phyDamagePromote + attacker.owner[29018] / 10000
            bullet.magicDamagePromote = bullet.magicDamagePromote + attacker.owner[29018] / 10000
        end               
	end
end

function attackerAfterHit(target, buff, bullet)  
    --处理吸血                          
    local suckValue = (target.phySuck + bullet.phySuck) * bullet.physicalHurt + (target.magicSuck + bullet.magicSuck) * bullet.magicHurt;          
    if suckValue > 0 then
        local beTreatPromote =	(1 + target.robust) * (1 - target[7090] * 0.0005);  
        --群体效果减半 
        if bullet.skilltype == 1 then
            local finalHeal = math.floor(suckValue * beTreatPromote * 0.5)
            local bullet = CreateBullet(0, 0);
            bullet.hurt_disabled = 1;
            bullet.heal_enable = 1;
            bullet.healValue = math.floor(finalHeal)
            BulletFire(bullet,target, 0.1)
        else
            local finalHeal = math.floor(suckValue * beTreatPromote);
            local bullet = CreateBullet(0, 0);
            bullet.hurt_disabled = 1;
            bullet.heal_enable = 1;
            bullet.healValue = math.floor(finalHeal)
            BulletFire(bullet,target, 0.1)
        end
    end

    if attacker.owner.TanLang > 0 then
        local value = bullet.hurt_final_value
        local bullet2 = CreateBullet(0, 0);
        bullet2.hurt_disabled = 1;
        bullet2.heal_enable = 1;
        bullet2.healValue = math.floor(value * attacker.owner.TanLang/10000)
        BulletFire(bullet2,target, 0.1)
    end

    --[黄金圣碑，援助]
    if script_data.Pet_HJSB and script_data.Pet_HJSB[target.side] then
        local Pet_HJSB = script_data.Pet_HJSB[target.side]
        if bullet.attacker ~= Pet_HJSB then
            if Pet_HJSB.owner[37204] > 0 and bullet.time == 1 and bullet.target.hp > 0 and bullet.hurt_disabled == 0 then
                local bullet_2 = CreateBullet(0, 0, "light_fa_nomal_ball", {scale = 1}, "light_fa_nomal_ball_hit", {scale = 1})
                bullet_2.magicHurt = Pet_HJSB.ad * 0.3
                bullet_2.attacker = Pet_HJSB
                bullet_2.num_text = "圣碑援助"
                bullet_2.element = 3
                bullet_2.skilltype = 3
                BulletFire(bullet_2, bullet.target, 0.12)
            end

            if Pet_HJSB.owner[37205] > 0 and bullet.time == 1  then
                UnitChangeMP(target.owner, 50)
            end

            if Pet_HJSB.owner[37206] > 0 and bullet.time == 1 and bullet.hurt_disabled == 0 then
                local bullet_hprevert = CreateBullet_Bytype(6)
                bullet_hprevert.healValue = Pet_HJSB.ad * 0.1
                BulletFire(bullet_hprevert, target.owner, 0)
            end
        end
    end
end


function attackerBeforeAttack(target, buff, bullet) 
    if attacker.owner.Pet_Extra_magic > 0 then
        bullet.magicHurt = bullet.magicHurt + attacker.owner.ap * attacker.owner.Pet_Extra_magic/10000
    end

    local rand_hit = ""
    if bullet.cfg or bullet.hit.cfg then
        rand_hit = "hit"..RAND(1,5)
        if bullet.cfg then bullet.cfg.hitpoint = rand_hit end
        if bullet.hit.cfg then bullet.hit.cfg.hitpoint = rand_hit end
    end

    if bullet.hit and bullet.hit.cfg and bullet.hit.cfg.scale and not bullet.hit.cfg.invariable then
        if bullet.target.side == 1 then
            if bullet.target.owner and bullet.target.owner ~= 0 then
                bullet.hit.cfg.scale = bullet.hit.cfg.scale * 0.5
            else
                bullet.hit.cfg.scale = bullet.hit.cfg.scale * 0.7
            end
        else
            if bullet.target.owner and bullet.target.owner ~= 0 then
                bullet.hit.cfg.scale = bullet.hit.cfg.scale * 1.2
            else
                bullet.hit.cfg.scale = bullet.hit.cfg.scale * 1.6
            end
        end
    end
end

