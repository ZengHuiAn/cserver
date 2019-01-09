attacker[7015] = 1
attacker[7010] = 100000

if attacker.mode == 19999 then
    Common_UnitAddBuff(attacker,19999,0,{effect = {name = "buff_fanshepingzhang", scale = 3,invarible = true}})
end

if attacker.id == 31051 then
    Common_UnitAddBuff(attacker, 660005);
end

if attacker.mode == 19038 then
    Common_UnitAddBuff(attacker, 98025);
end

if attacker.mode == 19027 then
    Common_UnitAddBuff(attacker, 98022);
end