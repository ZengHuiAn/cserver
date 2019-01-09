local skills = attacker.skill_boxs;
if skills == nil or skills == 0 then
    skills = attacker.Skill.script;
end
--[[
    find_all_enemys
    table.insert(list, {targets = choose_list, target = "enemy", button = "UI/fx_butten" ,value = value});

    find_one_enemy
    table.insert(list, {targets = {v}, target = v, button = "UI/fx_butten" ,value = value});
]]

--寻找某属性最低的目标，适用于find_one_enemy的对象
local function lessPropertyTarget(list,p)
    local idx = nil;
    for k,v in ipairs(list) do
        if idx == nil or v.targets[1][p] < list[idx].targets[1][p] then
            idx = k;
        end
    end
    return idx;
end

function GetRoleMaster(role)
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

	if role.mode == 11000 or role.mode == 11048 then
		local diamond_list = {
			[1] = "airMaster",
			[2] = "dirtMaster",
			[3] = "darkMaster"
		}

		role._Max_Master = diamond_list[attacker.diamond_index] or role_master

		return role._Max_Master
	end

	role._Max_Master = role_master
	return role._Max_Master
end

--是否需要进行单体治疗，适用于find_one_enemy对象
local function needHeal(list,per)
    local idx,hpPer,minHpPer = nil;
    local cordon = per or 0.6

    for k,v in ipairs(list) do
        hpPer = v.targets[1].hp / v.targets[1].hpp
        if hpPer <= cordon then
            if idx == nil or hpPer < minHpPer then
                idx = k;
                minHpPer = hpPer;
            end
        end
    end
    return idx;
end

local function Find_one(list,per)
    local target_list = {}
    local indx = 0
    for k,v in ipairs(list) do
        if  v.targets[1]._Focus_tag == 1 then
            return k
        end
        table.insert(target_list, { target = v.targets[1], former_key = k })
    end

    table.sort(target_list, function(a, b)
        if a.target.hp/a.target.hpp ~= b.target.hp/b.target.hpp then
            return a.target.hp/a.target.hpp < b.target.hp/b.target.hpp
        end
        return a.target.uuid < a.target.uuid
    end)

    indx = target_list[1].former_key
    return indx;
end


--是否需要进行群体治疗，适用于find_all_enemys
local function needGroupHeal(list,per)
    local needHealNum = 0 
    local cordon = per or 0.6

    targets = list[1].targets

    for _,v in ipairs(targets) do

        if v.hp < v.hpp * cordon then
            needHealNum = needHealNum + 1 
        end

        if needHealNum > 1 then
            return true;
        end
    end

    return false;
end

--寻找某属性最高的目标，适用于find_one_enemy的对象
local function higherPropertyTarget(list,p1,p2)
    local idx = nil;
    local highestProperty,vProperty = nil;
    for k,v in ipairs(list) do
        if  v.targets[1]._Focus_tag == 1 then
            return k
        end

        if p2 then
            vProperty = (v.targets[1][p1] >= v.targets[2][p2]) and v.targets[1][p1] or v.targets[2][p2]
        else
            vProperty = v.targets[1][p1]
        end
        if idx == nil or vProperty > highestProperty then
            idx = k;
            highestProperty = vProperty
        end
    end
    return idx;
end

--找到加点最多的技能
local function Max_tree_count()
    local list = {}
    local tree_list = {10001, 10002, 10003}
    local max_count = math.max(attacker[10001], attacker[10002], attacker[10003])
    return max_count
end


local function cast_aoe(skill)
    local targets = skill.target_list[1].targets
    if #targets >= 2 then
        return true
    else
        return false
    end
end


local function Change_diamond(list, current_diamond, next_Diamond)
    if attacker.auto_Change_diamond_round == attacker.round_count then
        return false
    end

    local index = Find_one(list)

    local target = list[index].targets[1]

	local master_kezhi_list = {
		[1]  = {kezhi = "dirtMaster",  beikezhi = "fireMaster"},
		[2]  = {kezhi = "waterMaster", beikezhi = "airMaster"},
		waterMaster = {kezhi = "fireMaster",  beikezhi = "dirtMaster"},
		fireMaster  = {kezhi = "airMaster",   beikezhi = "waterMaster"},
		lightMaster = {kezhi = "darkMaster",  beikezhi = ""},
		[3]  = {kezhi = "lightMaster", beikezhi = ""},
    }
    
	local target_master = GetRoleMaster(target)

    if master_kezhi_list[next_Diamond].kezhi == target_master then
        attacker.auto_Change_diamond_round = attacker.round_count
		return true
    elseif master_kezhi_list[current_diamond].beikezhi == target_master then
        attacker.auto_Change_diamond_round = attacker.round_count
		return true
	else
		return false
    end
    
end

-----------------------------------------------
--通用技能释放
local function NormalAction()
    for i = #skills, 1, -1 do
        if not skills[i].disabled and not skills[i].script._script_file_not_exists then
            return i, RAND(1,#skills[i].target_list);
        end
    end
    return "def", 0;
end

local actions = {}

--陆水银
actions[11000] = function()
    local max_count = Max_tree_count()        
    --红钻
    local function redDiamond()
        --刀鞘守护
        if not skills[3].disabled and attacker.ShouHu_buff == 0 then
            return 3, needHeal(skills[3].target_list, 1)
        end

        if Change_diamond(skills[1].target_list, attacker.diamond_index, attacker.nextDiamond) then
            return 13
        end

        --水银流星
        if not skills[4].disabled and cast_aoe(skills[4]) then
            return 4, 1
        end

        --水银弯刀
        if not skills[2].disabled then
            return 2, Find_one(skills[2].target_list, 1)
        end

        --普通攻击
        if not skills[1].disabled then
            return 1, Find_one(skills[1].target_list, 1)
        end

        --啥都做不了时防御
        return "def", 0;
    end

    --紫钻
    local function purpleDiamond()
        --冥王星
        if not skills[3].disabled then
            return 3, 1
        end
    
        --技能解析：120022
        if not skills[2].disabled and skills[2].id == 11000310 and attacker.mp >= 200 then
            return 2, higherPropertyTarget(skills[2].target_list,"hp")
        end

        if Change_diamond(skills[1].target_list, attacker.diamond_index, attacker.nextDiamond) then
            return 13
        end

        --影子强化
        if not skills[4].disabled then
            return 4, 1
        end

        --普通攻击
        if not skills[1].disabled then
            return 1, Find_one(skills[1].target_list, 1)
        end

        --啥都做不了时防御
        return "def", 0;
    end

    --黄钻
    local function yellowDiamond()
        if Change_diamond(skills[1].target_list, attacker.diamond_index, attacker.nextDiamond) then
            return 13
        end
        
        --召唤僵尸
        if not skills[2].disabled then
            return 2, 1
        end

        --黄金圣碑
        if not skills[3].disabled then
            return 3, 1
        end
        
        --千坟禁地:110042光环技标记
        if not skills[4].disabled 
        and skills[4].id == 11000230
        and attacker.mp >= 200 then
            return 4, 1
        end

        --普通攻击
        if not skills[1].disabled then
            return 1, Find_one(skills[1].target_list, 1)
        end

        --啥都做不了时防御
        return "def", 0;

    end

    local diamond_list = {
        redDiamond,
        yellowDiamond,
        purpleDiamond,
        --greenDiamond,blackDiamond,pinkDiamond,blueDiamond
    }

    if diamond_list[attacker.diamond_index] then
        return diamond_list[attacker.diamond_index]()
    else
        return redDiamond()
    end
end



--阿尔
actions[11001] = function()
    local max_count = Max_tree_count()    
    --有水元素时释放水元素
    if not skills[3].disabled then
        return 3, 1
    end

    --有寒冰光环且目标超过2个时释放寒冰光环
    if not skills[4].disabled and cast_aoe(skills[4]) then
        return 4, 1
    end

    --有寒冰脉动时对魔法防御最低的目标释放寒冰脉动
    if not skills[2].disabled then
        return 2, Find_one(skills[2].target_list, 1)
    end
    
    --有普攻时对魔法防御最低的目标释放普攻
    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 1)
    end

    --啥都做不了时防御
    return "def", 0;
end

--华羚
actions[11002] = function()
    local max_count = Max_tree_count()
    
    --流光疾步
    if not skills[3].disabled then
        return 3, 1
    end

    --星星大灭除
    if not skills[4].disabled and cast_aoe(skills[4]) then
        return 4, 1
    end

    --三消斩
    if not skills[2].disabled then
        return 2, Find_one(skills[2].target_list, 1)
    end

    --有普攻时对魔法防御最低的目标释放普攻
    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 1)
    end

    --啥都做不了时防御
    return "def", 0;
end

--双子星
actions[11003] = function () 
    local max_count = Max_tree_count()    
    
    --群体治疗
    if not skills[4].disabled and needGroupHeal(skills[4].target_list) then
        return 4, 1
    end

    --单体治疗
    if not skills[2].disabled then
        local heal_index = needHeal(skills[2].target_list)
        if heal_index then
            return 2, heal_index
        end
    end
    
    --惩戒
    if not skills[3].disabled then
        return 3, Find_one(skills[3].target_list, 1)
    end

    --有普攻时对魔法防御最低的目标释放普攻
    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 1)
    end

    --啥都做不了时防御
    return "def", 0;
end

--贝克
actions[11008] = function ()
    local max_count = Max_tree_count()    
    --有护盾时给生命最低的目标释放护盾
    if not skills[2].disabled then
        return 2, needHeal(skills[2].target_list, 1)
    end

    --如果没有开冰天雪地光环技则开启
    if not skills[4].disabled 
    and skills[4].id == 1100830
    and attacker.mp >= 200 then
        return 4, 1
    end

    --单体暴风雪
    if skills[3].id == 1100822 and not skills[3].disabled then
        return 3, Find_one(skills[1].target_list, 1)
    end

    --有暴风雪且目标超过2个时释放暴风雪
    if not skills[3].disabled and cast_aoe(skills[3]) then
        return 3, 1
    end

    --有普攻时对魔法防御最低的目标释放普攻
    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 1)
    end

    --啥都做不了时防御
    return "def", 0;
end

--陆伯
actions[11012] = function ()
    local max_count = Max_tree_count()    
    --先召唤坚果
    if not skills[3].disabled then
        return 3, 1
    end

    --再召唤鬼牙草
    if not skills[2].disabled then
        return 2, 1
    end

    --释放殷桃炸弹
    if not skills[4].disabled and cast_aoe(skills[4]) then
        return 4, 1
    end

    --普攻
    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 2)
    end

    --啥都做不了时防御
    return "def", 0;
end

--蓝琪儿
actions[11014] = function()
    local max_count = Max_tree_count()    
    --炽天使
    if not skills[3].disabled then
        return 3, 1
    end

    --恒星女王
    if not skills[4].disabled then
        return 4, 1
    end

    --十字星爆
    if not skills[2].disabled and cast_aoe(skills[2]) then
        return 2, 1
    end

    --普攻
    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 1)
    end

    --啥都做不了时防御
    return "def", 0;
end

--蓝田玉
actions[11022] = function()
    local max_count = Max_tree_count()        
    --猎神狙杀
    if not skills[4].disabled and cast_aoe(skills[4]) then
        return 4, 1
    end

    --天兵箭刺:102221(0：一段  1：二段)
    if not skills[2].disabled  then
        return 2, Find_one(skills[2].target_list, 1)
    end

    --六道轮回:102231(0：一段  1：二段  2：三段)
    if not skills[3].disabled then
        return 3, 1
    end
    
    --普攻
    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 1)
    end

    --啥都做不了时防御
    return "def", 0;
end


--刹血修罗
actions[11024] = function()
    local max_count = Max_tree_count()    

    --如果没有开光环技则开启
    if not skills[4].disabled and skills[4].id == 1102430 then
        return 4, 1
    end

    --有召唤物时释放召唤物
    if not skills[3].disabled and skills[3].id == 1102420 then
        return 3, 1
    end

    --有群体技且目标超过2个时释放群体技
    if not skills[2].disabled 
    and #skills[2].target_list[1].targets >= 2 then
        return 2, 1
    end

    --有普攻时对魔法防御最低的目标释放普攻
    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 1)
    end

    --啥都做不了时防御
    return "def", 0;
end

--钛小峰
actions[11028] = function ()
    local max_count = Max_tree_count()    

    --驱魔风暴
    if not skills[2].disabled and cast_aoe(skills[2]) then
        return 2, 1
    end

    --泰伯坦之刃
    if not skills[4].disabled then
        return 4, Find_one(skills[4].target_list, 1)
    end

    --舍身
    if not skills[3].disabled and attacker.skill3_count < 1 then
        return 3, Find_one(skills[3].target_list, 1)
    end
    
    --有普攻时对魔法防御最低的目标释放普攻
    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 1)
    end

    --啥都做不了时防御
    return "def", 0;
end

--伊赛菲亚
actions[11004] = function ()
    local max_count = Max_tree_count()    
    --有护盾时给生命最低的目标释放护盾
    if not skills[3].disabled then
        return 3, needHeal(skills[3].target_list, 1)
    end

    --有召唤物时释放召唤物 僵尸
    if not skills[4].disabled then
        return 4, 1
    end
    
    --有召唤物时释放召唤物 蜈蚣
    if not skills[2].disabled and skills[2].id == 1100410 then
        return 2, 1
    end

    --有普攻时对魔法防御最低的目标释放普攻
    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 1)
    end

    --啥都做不了时防御
    return "def", 0;

end


--西风
actions[11007] = function ()
    local max_count = Max_tree_count()    
    --解封魔镜
    if not skills[2].disabled then
        return 2, 1
    end
    
    --虚空之握
    if not skills[4].disabled then
        return 4, Find_one(skills[4].target_list, 1)
    end

    --回蓝
    if not skills[3].disabled and attacker.mp <250  then
        return 3, needHeal(skills[3].target_list, 1)
    end
    
    --有普攻时对魔法防御最低的目标释放普攻
    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 1)
    end

    --啥都做不了时防御
    return "def", 0;

end
    
--紫冥
actions[11009] = function ()
    local max_count = Max_tree_count()    
    --治疗术
    if not skills[2].disabled then
        local heal_index = needHeal(skills[2].target_list)
        if heal_index then
            return 2, heal_index
        end
    end

    --解析
    if not skills[3].disabled then
        return 3, 1
    end
    
    --驱散
    if not skills[4].disabled then
        return 4, Find_one(skills[4].target_list, 1)
    end

    --有普攻时对魔法防御最低的目标释放普攻
    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 1)
    end

    --啥都做不了时防御
    return "def", 0;

end
    

--陆游七
actions[11013] = function ()
    local max_count = Max_tree_count()    
    --嘲讽
    if not skills[2].disabled and skills[2].id == 1101310 then
        return 2, 1
    end

    --召唤
    if not skills[3].disabled then
        return 3, 1
    end
    
    --大招
    if not skills[4].disabled and cast_aoe(skills[4]) then
        return 4, 1
    end

    --有普攻时对魔法防御最低的目标释放普攻
    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 1)
    end

    --啥都做不了时防御
    return "def", 0;
        
end
    
--良三郎
actions[11023] = function ()
    local max_count = Max_tree_count()    
    
    --召唤米莎
    if not skills[2].disabled then
        return 2, 1
    end

    --召唤圣堂
    if not skills[3].disabled then
        return 3, 1
    end

    --无事可做时放二段大招
    if not skills[4].disabled then
        return 4, Find_one(skills[4].target_list, 1)
    end

    --有普攻时对魔法防御最低的目标释放普攻
    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 1)
    end

    --啥都做不了时防御
    return "def", 0;

end
    

actions[11102501] = function ()
    if not skills[4].disabled and cast_aoe(skills[4]) then
        return 4, 1
    end
    
    if not skills[2].disabled then
        return 2, 1
    end

    if not skills[3].disabled then
        return 3, 1
    end

    if not skills[1].disabled then
        return 1, Find_one(skills[1].target_list, 1)
    end

    return "def", 0;

end

return NormalAction() --(actions[attacker.id] or NormalAction)()