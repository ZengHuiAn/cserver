Common_UnitConsumeActPoint(1);

Common_UnitAddBuff(attacker,99990, 0, {
    icon = "buff_12", 
    round = 1 ,     
    damagereduce = 3000 + attacker[28001] ,
});	
Common_Sleep(attacker, 0.3)
