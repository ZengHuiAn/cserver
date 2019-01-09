--各类计数
--AddRecord(id, type, value)
local count_byid_32 = 0
local count_byid_33 = 0
local only_magic = true
local only_phy = true
local partner_count_enter = 0

function attackerAfterHit(target, buff, bullet)
    if target.side ~= 1 then return end

    if bullet.skilltype ~= 0 and bullet.skilltype <= 4 then
        if bullet.magicHurt > bullet.physicalHurt then only_magic = false end
        if bullet.magicHurt < bullet.physicalHurt then only_phy = false end     
    end

    AddRecord(1, "add", bullet.magicHurt)
    AddRecord(2, "add", bullet.physicalHurt)
    AddRecord(7, "max", bullet.magicHurt)
    AddRecord(8, "max", bullet.physicalHurt)

    if bullet.magicHurt > bullet.physicalHurt then AddRecord(5, "add", 1) AddRecord(9, "add", 1) end
    if bullet.magicHurt < bullet.physicalHurt then AddRecord(6, "add", 1) AddRecord(10, "add", 1) end

    --普攻类
    if bullet.skilltype == 4 then
        AddRecord(3, "add", bullet.magicHurt)
        AddRecord(4, "add", bullet.physicalHurt)
        if bullet.time > 1 then AddRecord(56, "add", 1) end
        if bullet.time > 1 and bullet.target.hp <= 0 then AddRecord(58, "add", 1) end
    end

    if bullet.element == 1 then AddRecord(13, "add", bullet.hurt_final_value) end
    if bullet.element == 2 then AddRecord(14, "add", bullet.hurt_final_value) end
    if bullet.element == 3 then AddRecord(15, "add", bullet.hurt_final_value) end
    if bullet.element == 4 then AddRecord(17, "add", bullet.hurt_final_value) end
    if bullet.element == 5 then AddRecord(16, "add", bullet.hurt_final_value) end
    if bullet.element == 6 then AddRecord(18, "add", bullet.hurt_final_value) end

    --击杀类
    if bullet.target.hp <= 0 then
        AddRecord(19, "add", 1)
        if bullet.magicHurt > bullet.physicalHurt then AddRecord(23, "add", 1) end
        if bullet.magicHurt < bullet.physicalHurt then AddRecord(24, "add", 1) end
        if bullet.element == 1 then AddRecord(25, "add", 1) end
        if bullet.element == 2 then AddRecord(26, "add", 1) end
        if bullet.element == 3 then AddRecord(27, "add", 1) end
        if bullet.element == 4 then AddRecord(28, "add", 1) end
        if bullet.element == 5 then AddRecord(29, "add", 1) end
        if bullet.element == 6 then AddRecord(30, "add", 1) end
        if bullet.target.lightMaster > 0 then AddRecord(50, "add", 1) end
        if target.rount_count == 1 then AddRecord(51, "add", 1) end
        if target.level < bullet.target.level then AddRecord(67, "add", 1) end
        if bullet.target.mode == 19002 then AddRecord(81, "add", 1) end
        if bullet.num_text == "寒冰光环" and bullet.target.mode == 11040 then AddRecord(82, "add", 1) end 
        if bullet.attacker.id == 11001 and bullet.target.mode == 19007 and bullet.attacker.hp == bullet.attacker.hpp then AddRecord(83, "add", 1) end 
    end

    if bullet.time == 1 and bullet.skilltype == 1 then AddRecord(37, "add", 1) end
    
    --暴击
    if bullet.isCrit == 1 then 
        AddRecord(43, "add", 1)
        AddRecord(58, "add", 1)
        if bullet.magicHurt > bullet.physicalHurt then AddRecord(59, "add", 1) end
        if bullet.magicHurt < bullet.physicalHurt then AddRecord(60, "add", 1) end
        if bullet.target.hp <= 0 then AddRecord(61, "add", 1) end
    end

    --宠物
    if target.owner and target.owner ~= 0 then
        AddRecord(11, "add", bullet.hurt_final_value)
        AddRecord(22, "add", 1)
        if bullet.target.hp <= 0 then AddRecord(43, "add", 1) end
        if bullet.target.mode == 19054 then AddRecord(80, "add", 1) end
    end

end

function targetAfterHit(target, buff, bullet)    
    if target.side ~= 1 then return end
    if bullet.hurt_disabled == 0 then count_byid_32 = count_byid_32 + bullet.hurt_final_value end
    if bullet.skilltype <= 4 and bullet.skilltype ~= 0 then count_byid_33 = count_byid_33 + 1 end


    if target[7002] > 0 then 
        AddRecord(36, "add", 1) 
        AddRecord(37, "add", bullet.hurt_final_value) 
    end 
end

function targetAfterCalc(target, buff, bullet)    
    if target.side ~= 1 then return end

    if bullet.heal_enable == 1 then AddRecord(71, "add", math.min(bullet.finalHeal, bullet.target.hpp - bullet.target.hp)) end
    if bullet.heal_enable == 1 then AddRecord(78, "add", math.min(bullet.finalHeal, bullet.target.hpp - bullet.target.hp)) end
end

function attackerAfterCalc(target, buff, bullet)    
    if target.side ~= 1 then 
        if bullet.heal_enable == 1 then AddRecord(77, "add", math.min(bullet.finalHeal, bullet.target.hpp - bullet.target.hp)) end        
    else
        return 
    end

    if bullet.heal_enable == 1 then AddRecord(72, "add", math.min(bullet.finalHeal, bullet.target.hpp - bullet.target.hp)) end
    if bullet.heal_enable == 1 then AddRecord(73, "max", math.min(bullet.finalHeal, bullet.target.hpp - bullet.target.hp)) end
    if bullet.heal_enable == 1 and bullet.finalHeal > bullet.target.hpp then AddRecord(79, "add", 1) end

    if target.owner and target.owner ~= 0 then
        if bullet.heal_enable == 1 then AddRecord(70, "add", math.min(bullet.finalHeal, bullet.target.hpp - bullet.target.hp)) end
    end
end

function onPetEnter(_, buff, role, pet)
    if pet.side == 1 then AddRecord(47, "add", 1) end
end

function onRoundStart(target, buff)
    local partners = FindAllPartner()
    partner_count_enter = #partners
end

function onFightEnd(target, buff, winner)
    if winner == 1 then
        AddRecord(32, "add", count_byid_32)
        AddRecord(33, "add", count_byid_33)
        AddRecord(34, "add", count_byid_32)
        AddRecord(35, "add", count_byid_33)
        if target.rount_count == 1 then
            AddRecord(52, "max", 1)
        end
    
        if target.rount_count == 2 then
            AddRecord(50, "max", 1)
        end
    
        if only_magic then AddRecord(53, "max", 1) end
        if only_phy then AddRecord(54, "max", 1) end
        local partners = FindAllPartner()
        if #partners == partner_count_enter then
            local all_half = 1
            AddRecord(63, "max", 1)
            for _, v in ipairs(partners) do
                if v.hp/v.hpp > 0.5 then
                    all_half = 0
                end
            end
            if all_half == 1 then AddRecord(62, "max", 1) end
        end
    end
end

function onSkillCast(role, buff, skill)
	if skill.skill_element == 2 and skill.name and skill.name ~= "普通攻击" then
        AddRecord(49, "add", 1)
    end
end
