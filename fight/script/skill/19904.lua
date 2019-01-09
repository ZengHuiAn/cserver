local battle_script_data = GetBattleData()

if battle_script_data.win_type == 1 and not battle_script_data.not_add_warning then
    ShowBattleWarning(2, {0, 6, 0})
    battle_script_data.not_add_warning = true
end

if not battle_script_data.not_add_warning then
    ShowBattleWarning(1, {0, 6, 0})
end

if attacker.pos > 100 then Common_Sleep(attacker, 1) end

local temp = math.random(20,100)/100;
Common_Sleep(attacker, temp)

if GetFightType() == 2 then
    attacker[7013] = 10000
end

if attacker.mode == 11030 then
    ShowUI(false)    
    Common_AddStageEffect("hetishu", {duration = 4.5, scale=1, rotation = 0, offset = {0, 0, 0}});
    Common_Sleep(attacker, 4.65);
    ShowUI(true)    
end

if attacker.mode >= 11000 and attacker.mode <= 11050 and attacker.mode ~= 11030 and attacker.side ~= 1 then
    Common_UnitAddEffect(attacker, "UI/fx_jues_ruchang", {scale = 1.0, duration = 3.0 , speed = 0.5 ,offset = {0, 0, 0} ,  hitpoint = "root" })
end

UnitShow();
UnitPlay(attacker, "ruchang", 0, {speed=1.0, duration =2.0 });

common_enter(attacker)
Common_Sleep(attacker, 0.75)

attacker.Show_Monster_info = 1
--print("it is OK !--!方块小妖入场了！");
