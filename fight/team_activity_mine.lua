local fighting_npc = {};
local opened_count = 0;
local manager_npc_uuid = 1;
local manager_npc_id = 1600001;
local fighting_pid = {}


-- 计算开过的格子数量
if NPC_GetID(manager_npc_uuid) then
    for i = 1, 5 do
        local value = NPC_GetValue(manager_npc_uuid, i);
        for j = 0, 19 do
            if bit32.band(value, 2 ^ j) ~= 0 then
                opened_count = opened_count + 1;
            end
        end
    end
else
    local npc = NPC_Add(manager_npc_id); assert(npc == manager_npc_uuid);
end


-- 预先生成npc出现数据
local npc_create_list = {}; --存放npc出现在哪个格子里面    

local boss_id = 1601106;  --boss在70格之后刷
local npc1 = {1601100,1601101,1601102,1601103,1601104,1601105,1601300,1601302,1601305,1601306,1601400,1601400,1601400,1601400,1601400,1601401,1601402, 1601403} -- 元素领主和功能npc 20-100
local npc2 = {1601200,1601201,1601202,1601203,1601204,1601205} -- 数量不固定的元素小怪 10-100
local npc3 = {1601301,1601303,1601304,1601307}  --偏指引性质的npc 1-30

local RAND = RAND or math.random

local monsternum = RAND(12, 18)  --小怪出现的次数
local NPCnum = monsternum + #npc1 + #npc3 + 1 --总计要刷出多少npc
for i =7,monsternum do
    local idx = (i - 1) % 6 + 1
    table.insert(npc2, npc2[idx])
end

local boss_pos = RAND(70,100);
npc_create_list[boss_pos] = boss_id; --西风刷在哪个格子里  

for _, npc_id in ipairs(npc3) do
    repeat 
        local npc1_pos = RAND(2,30)
        if not npc_create_list[npc1_pos] then
                npc_create_list[npc1_pos] = npc_id;
                break;
        end
    until false
end

for _, npc_id in ipairs(npc1) do
    repeat 
        local npc1_pos = RAND(20,100)
        if not npc_create_list[npc1_pos] then
                npc_create_list[npc1_pos] = npc_id;
                break;
        end
    until false 
end

for _, npc_id in ipairs(npc2) do
    repeat 
        local npc1_pos = RAND(10,100)
        if not npc_create_list[npc1_pos] then
                npc_create_list[npc1_pos] = npc_id;
                break;
        end
    until false 
end

print("npc_create_list >>>>>>>>>>>")
for pos, npc_id in pairs(npc_create_list) do
	print("pos  npc", pos, npc_id)
end

-- 移除所有npc战斗状态
local npc_list = NPC_List();
for _, npc in ipairs(npc_list) do
    if npc ~= manager_npc_id then
        NPC_SetValue(npc, 2, 0);
    end
end

local function SetNPCBuffValid(npc, buff_id)
    return NPC_SetValue(npc, 3, buff_id);
end

local function TryAddBuff(npc, npc_id, pid) --普通元素怪加载buff
	local cfg = GetConfig("config_team_activity_mine", npc_id)
	if not cfg then
		return 2
	end
    if  cfg.born_buff_id~= 0 then
	    SetNPCBuffValid(npc, cfg.born_buff_id);
    end
end

local function TryOpenGrid(pid, opt)
    print('player', pid, 'TryOpenGrid', opt);
    opt = opt - 1;

    local key = math.floor(opt / 20) + 1;
    local idx = opt % 20;

    print('key', key, 'idx', idx);

    local value = NPC_GetValue(1, key);

    if bit32.band(value, 2 ^ idx) ~= 0 then -- grid is opened
        print('grid is opened');
        return 7;
    end

    NPC_SetValue(1, key, bit32.bor(value, 2 ^ idx));

    opened_count = opened_count + 1;

	print("opened_count >>>>>>>>>", opened_count, npc_create_list[opened_count])
    local npc_id = npc_create_list[opened_count]
    if not npc_id then
        return;
    end

    local npc = NPC_Add(npc_id);

    NPC_SetValue(npc, 1, opt + 1);
    TryAddBuff(npc, npc_id, pid);
end

local function AfterFight(winner, npc, pids)
    NPC_SetValue(npc, 2, 0);

	for _, id in ipairs(pids) do
		if fighting_pid[id] then
			fighting_pid[id] = nil
		end
	end

    if winner ~= 1 then
        if NPC_GetID(npc) == 1601300 or NPC_GetID(npc) == 1601302 then --阿尔，苟富贵无论输赢战斗都会消失
            NPC_Remove(npc);
		end

		return 
    end
    NPC_Remove(npc);    --战斗胜利都会会消失
    SetNPCBuffValid(npc, 0); --战斗胜利buff都会消失

    --[[if NPC_GetID(npc) == boss_id then -- boss胜利则结束
        --TODO: send reward
        NPC_SetValue(npc, 5, 1);
        Exit();
    end]]
    return;
end


--[[local function TryFightNPC(npc, pid)
    if NPC_GetValue(npc, 2) ~= 0 then
        -- error: npc is fighting
        return
    end

    local cfg = GetNpcConfig(NPC_GetID(npc));
    if not cfg then
        return;
    end

    local fight_id = cfg.fight_id;
    if fight_id == 0 then
        local drop = cfg.drop;

        -- TODO: npc is reward box,  send reward
		SendDropReward({pid}, nil, {drop})

        NPC_Remove(npc);
        return;
    end

    local pids = {pid};

    if NPC_GetID(npc) == boss_id then -- is boss
        -- TODO: check pid is team leader
        pids = GetTeamMembers();
    end

    if StartFight(pids, fight_id, {}, function(winner) AfterFight(winner); end) then
        NPC_SetValue(npc, 2, 1);
    end
end]]


local function LockOpt(npc, opt)
    local value = NPC_GetValue(npc, 4);
	return NPC_SetValue(npc, 4, bit32.bor(value, 2^(opt-1)));
end

local function OptLocked(npc, opt)
    local value = NPC_GetValue(npc, 4);
	if bit32.band(value, 2^(opt-1)) ~= 0 then	
		return true	
	end
	return false
end
--local pids = GetTeamMems()  --{pid1, pid2...}
local function TrySendReward(pid,npc_id)
    local pids = GetTeamMembers()
    local cfg = GetConfig("config_team_activity_mine", npc_id)
	print("try send reward >>>>>>>>>>>", pid, npc_id, cfg.drop_id)
	SendDropReward(pids, nil, {cfg.drop_id})  --{{type = 41, id = 90006, value = 100}}
end

local function CalcBuff()
	local buff = {buff_list = {}}
	local info = NPC_Info_List()
	for _, v in ipairs(info) do
		if v.id ~= 0 then
			if v.data[3] ~= 0 then
				print("v.data3 >>>>>>>>>>", v.data[3])
				buff.buff_list[v.data[3]] = buff.buff_list[v.data[3]] or 0 
				buff.buff_list[v.data[3]] = buff.buff_list[v.data[3]] + 1 
			end	
		end
	end
	return buff
end

local function TryFight(npc, npc_id, pid, opt)
	local cfg = GetConfig("config_team_activity_mine", npc_id)--GetNpcFightCfg(npc_id)
	print("try start fight >>>>npc, npc_id, pid, opt", npc, npc_id, pid, opt)
	if not cfg then
		return 2
	end
    if NPC_GetValue(npc, 2) ~= 0 then
		-- npc fighting
		return 3
	end

	local buff = CalcBuff()
	--[[for type, value in pairs(buff.buff_list) do
		print("buff type value >>>>>>>>>>>>>>>>>>>>>>>>>", type, value)
	end--]]

    local pids = {pid};
	if cfg.depend_npc_id == 0 then
    	if StartFight(pids, cfg.fight_id1, buff, function(winner) AfterFight(winner, npc, pids); end) then
        	NPC_SetValue(npc, 2, 1);
			fighting_pid[pid] = true
		end
		return 
	else
		if NPC_GetDeadNum(cfg.depend_npc_id) >= 1 then
            if StartFight(pids, cfg.fight_id1, buff, function(winner) AfterFight(winner, npc, pids); end) then
				NPC_SetValue(npc, 2, 1);
				fighting_pid[pid] = true
			end
			return 
		else
			if StartFight(pids, cfg.fight_id2, buff, function(winner) AfterFight(winner, npc, pids); end) then
				NPC_SetValue(npc, 2, 1);
				fighting_pid[pid] = true
			end
			return 
		end	
	end	
end

local function TryFightBoss(npc, npc_id, pid, opt)  --尝试boss战，判定6个领主全部击杀过1次
	print("fight boss >>>>>>>>>>>>>", npc_id)
	local cfg = GetConfig("config_team_activity_mine", npc_id)--GetNpcFightCfg(npc_id)
    local Lord_list = {1601100,1601101,1601102,1601103,1601104,1601105}
    if NPC_GetValue(npc, 2) ~= 0 then
		return 3
	end

	local buff = CalcBuff()
    local pids = GetTeamMembers()

	for _, id in ipairs(pids) do
		if fighting_pid[id] then
			print("someone in fight, cant fight boss")
			return 6 
		end
	end


    if  NPC_GetID(npc) == boss_id then
	    for _, v in ipairs(Lord_list) do
            if  NPC_GetDeadNum(v) < 1 then
                return 4
            end
        end
        if StartFight(pids, cfg.fight_id1, buff, function(winner) AfterFight(winner, npc, pids); end) then  
            NPC_SetValue(npc, 2, 1);
			for _, id in ipairs(pids) do
				fighting_pid[id] = true
			end
        end
        return 
    end
end

--西风战斗逻辑
local function logic_for_Boss_monster(npc, npc_id, pid, opt)
	if opt ~= 1 then
		return 5
	end		
	return TryFightBoss(npc, npc_id, pid, opt)
end 

local Monster_ID = {
    [1601100] = 1,[1601101] = 1,[1601102] = 1,[1601103] = 1,[1601104] = 1,[1601105] = 1,[1601200] = 1,[1601201] = 1,[1601202] = 1,[1601203] = 1,[1601204] = 1,[1601205] = 1,[1601402] = 1
}                       --元素怪物战斗
local function logic_for_normal_monster(npc, npc_id, pid, opt)
	if opt ~= 1 then
		return 5
	end		
	
	print("try fight >>>>>>>>>>>>")
	return TryFight(npc, npc_id, pid, opt);
end

local Gfg_npc = 1601300 --苟富贵
local function logic_for_Gfg_npc(npc, npc_id, pid, opt)
	if opt == 1 then        --选1，全体发奖励移除
        TrySendReward(pid,npc_id)
        NPC_Remove(npc);
        return 	
	elseif opt == 2 then    --选2，战斗，战斗后移除
		TryFight(npc, npc_id, pid, opt)
        return 
	else
        return 5
    end
end

local Jxm_npc = 1601301 --金晓明
local function logic_for_Jxm_npc(npc, npc_id, pid, opt)
	if opt == 1 then        --选1，消失
        NPC_Remove(npc);
        return 	
	else
        return 5
    end
end

local Aer_npc = 1601302 --阿尔
local function logic_for_Aer_npc(npc, npc_id, pid, opt)
	local cfg = GetConfig("config_team_activity_mine", npc_id)
	if opt == 1 then        --选1，加buff，移除
		SetNPCBuffValid(npc, cfg.buff_id1);
        NPC_Remove(npc);
        return 	
	elseif opt == 2 then    --选2，战斗，战斗后移除
		TryFight(npc, npc_id, pid, opt)
        return 
    elseif opt == 3 and NPC_GetDeadNum(cfg.depend_npc_id) >= 1 then --选3，加buff2，移除
		SetNPCBuffValid(npc, cfg.buff_id2);
        NPC_Remove(npc);
        return 
	else
        return 5
    end
end

local Wz_npc = 1601303  --无贼
local function logic_for_Wz_npc(npc, npc_id, pid, opt)
	local cfg = GetConfig("config_team_activity_mine", npc_id)
	if opt == 2 then        --选2，给buff 锁定该选项，无法继续获取该buff
        SetNPCBuffValid(npc, cfg.buff_id1);
        LockOpt(npc, opt);
        return 
	else
        return 5
    end
end

local Bk_npc = 1601304  --贝克、李硅平
local Lgp_npc = 1601307
local function logic_for_Bk_npc(npc, npc_id, pid, opt)
	if opt then        
        return 
    end
end

local Tmz_npc = 1601305 --铁木真
local function logic_for_Tmz_npc(npc, npc_id, pid, opt)
	local cfg = GetConfig("config_team_activity_mine", npc_id)
	if opt == 2 then        --选1，加buff，移除该选项
        TrySendReward(pid,npc_id)
        LockOpt(npc, opt)
        return 
	else
        return 5
    end
end

local Lb_npc = 1601306 --陆伯
local function logic_for_Lb_npc(npc, npc_id, pid, opt)
	local cfg = GetConfig("config_team_activity_mine", npc_id)
	if opt == 2 then        --选2，且击杀了土元素，发奖励，移除
        if  NPC_GetDeadNum(cfg.depend_npc_id) >= 1 then
            TrySendReward(pid,npc_id)
            NPC_Remove(npc);
            return 
        end
	
		return 1
	else
        return 5
    end
end

local Reward_box = {[1601400] = 1,[1601403] = 1} --奖励宝箱处理
local function logic_for_reward_box(npc, npc_id, pid, opt)
	if opt == 1 then        --发奖励，移除
		TrySendReward(pid,npc_id)
        NPC_Remove(npc);
        return 
	else
        return 5
    end
end

local Buff_box = 1601401 --buff宝箱处理
local function logic_for_Buff_box(npc, npc_id, pid, opt)
	local cfg = GetConfig("config_team_activity_mine", npc_id)
	if opt == 1 then        --发buff1，移除
		SetNPCBuffValid(npc, cfg.buff_id1);
        NPC_Remove(npc);
        return 
	elseif  opt == 2 then   --发buff2，移除
        SetNPCBuffValid(npc, cfg.buff_id2);
        NPC_Remove(npc);
        return 
    end
end

local function TryInteractWithNPC(npc, pid, opt)    
	local id = NPC_GetID(npc)
	print("lock >>>>>>>>>>>>", npc, opt, tostring(OptLocked(npc, opt)))
	if OptLocked(npc, opt) then
		return 1    --被锁定时返回错误号1
	end
    if  id == boss_id then
        return logic_for_Boss_monster(npc, id, pid, opt)
    end
    if Monster_ID[id] == 1 then
        return logic_for_normal_monster(npc, id, pid, opt)
    end
    if id == Aer_npc then
        return logic_for_Aer_npc(npc, id, pid, opt)
	end	
    if id == Gfg_npc then
        return logic_for_Gfg_npc(npc, id, pid, opt)
	end
    if id == Jxm_npc then
        return logic_for_Jxm_npc(npc, id, pid, opt)
	end
    if id == Wz_npc then
        return logic_for_Wz_npc(npc, id, pid, opt)
	end
    if id == Bk_npc or id == Lgp_npc then
        return logic_for_Bk_npc(npc, id, pid, opt)
	end
    if id == Lb_npc then
		return logic_for_Lb_npc(npc, id, pid, opt)
	end
    if id == Tmz_npc then
        return logic_for_Tmz_npc(npc, id, pid, opt)
	end
    if Reward_box[id] == 1 then
        return logic_for_reward_box(npc, id, pid, opt)
    end
    if id == Buff_box then
        return logic_for_Buff_box(npc, id, pid, opt)
	end
end


function Interact(pid, npc, opt)
    local id = NPC_GetID(npc);
    if id == manager_npc_id then
        return TryOpenGrid(pid, opt)
    else
		return TryInteractWithNPC(npc, pid, opt)
    end
end
