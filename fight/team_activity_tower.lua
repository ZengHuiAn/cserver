local tower_npc_uuid = 1;
local tower_npc_id   = 1;

local tower_total_hp = 300;
local current_wave   = 0;

if NPC_GetID(tower_npc_uuid) then
	tower_total_hp = NPC_GetValue(tower_npc_uuid, 1);
	current_wave   = NPC_GetValue(tower_npc_uuid, 2);
else
	tower_npc_uuid = NPC_Add(tower_npc_id);
	assert(tower_npc_uuid == 1);

	NPC_SetValue(tower_npc_uuid, 1, tower_total_hp);
	NPC_SetValue(tower_npc_uuid, 2, current_wave);
end

local monsters = {
	{id = 9067101, name = '小型炸弹（土）', countdown = 240, hurt = 5},
	{id = 9067102, name = '小型炸弹（风）', countdown = 240, hurt = 5},
	{id = 9067103, name = '小型炸弹（水）', countdown = 240, hurt = 5},
	{id = 9067104, name = '小型炸弹（火）', countdown = 240, hurt = 5},
	{id = 9067105, name = '强效炸弹（土）', countdown = 240, hurt = 10},
	{id = 9067106, name = '强效炸弹（风）', countdown = 240, hurt = 10},
	{id = 9067107, name = '强效炸弹（水）', countdown = 240, hurt = 10},
	{id = 9067108, name = '强效炸弹（火）', countdown = 240, hurt = 10},
	{id = 9067109, name = '高爆炸弹（风）', countdown = 300, hurt = 20},
	{id = 9067110, name = '高爆炸弹（土）', countdown = 300, hurt = 20},
	{id = 9067111, name = '高爆炸弹（水）', countdown = 300, hurt = 20},
	{id = 9067112, name = '高爆炸弹（火）', countdown = 300, hurt = 20},
	{id = 9067113, name = '战斗补给',       countdown = 300, hurt = 0},
	{id = 9067114, name = '战斗补给',       countdown = 300, hurt = 0},
	{id = 9067115, name = '战斗补给',       countdown = 300, hurt = 0},
	{id = 9067116, name = '战斗补给',       countdown = 300, hurt = 0},
}

local wave_info = {
	[1] = {time =   0, monster_count = 6},
	[2] = {time = 300, monster_count = 7},
	[3] = {time = 600, monster_count = 8},
	[4] = {time = 900, monster_count = 9},
}

local rewards = {
	[1] = { blood_min = 50, blood_max = 150,drop = 501},
	[2] = { blood_min = 150,blood_max = 250,drop = 502},
	[3] = { blood_min = 250,blood_max = 300,drop = 503},
}

local function random_number(n, total)
	local t = {}
	for i = 1, total do
		table.insert(t, i);
	end

	local result = {}
	local c = 0;
	while c < n and #t > 0 do
		local pos = math.random(1, #t);
		local v = t[pos]
		table.remove(t, pos);
		table.insert(result, v);
		c = c + 1
	end

	return result;
end

local function EndToReward()
	for _,v in ipairs(rewards) do
		if tower_total_hp >= v.blood_min and tower_total_hp < v.blood_max then
			local pids = GetTeamMembers()
			SendDropReward(pids, nil,{v.drop})
			break
		elseif tower_total_hp == 300 then
			local pids = GetTeamMembers()
                        SendDropReward(pids, nil,{503})
                        break
		end
	end
end

local function GameOver()
	--TODO:
	Exit();
end

local Limit_time = 20 * 60
local last_wave_count = 0
local is_rewarded = false
function Update(t)
	if tower_total_hp <= 0 then
		return
	end

	local start_time = NPC_GetValue(tower_npc_uuid, 3)
	if start_time == 0 then
		start_time = t;
		NPC_SetValue(tower_npc_uuid, 3, t);
	end
	
	if t - start_time > Limit_time then 
		if not is_rewarded then
			EndToReward()
		end
		GameOver()
		return
	end

	local npcs = NPC_List()
	for _, npc in ipairs(npcs) do
		if NPC_GetID(npc) ~= tower_npc_id then
			local boom_time = NPC_GetValue(npc, 1)
			if boom_time <= t then
				tower_total_hp = tower_total_hp - NPC_GetValue(npc, 2);

				NPC_Remove(npc);
				if current_wave == 4 then
					last_wave_count = last_wave_count - 1
				end
				if tower_total_hp <= 0 then
					NPC_SetValue(tower_npc_uuid, 1, 0);
					GameOver();
					return;
				end
			end
		end
	end

	NPC_SetValue(tower_npc_uuid, 1, tower_total_hp);

	local wave = wave_info[current_wave + 1];
	if not wave or (t - start_time) < wave.time then
		return;
	end

	current_wave = current_wave + 1
	NPC_SetValue(tower_npc_uuid, 2, current_wave);

	local monster_indexs = random_number(wave.monster_count, #monsters);
	for _, k in ipairs(monster_indexs) do
		local monster = monsters[k];
		if monster then
			local npc = NPC_Add(monster.id);
			NPC_SetValue(npc, 1, t + monster.countdown);
			NPC_SetValue(npc, 2, monster.hurt);
			if current_wave == 4 and monster.id < 9067113 then 
				last_wave_count = last_wave_count + 1 
			end
		end
	end
end

local function AfterFight(winner, npc)
	if not NPC_GetID(npc) then
		-- npc is removed
		return;
	end

        NPC_SetValue(npc, 3, 0);

    	if winner ~= 1 then
        	return;
    	end

	local cfg = GetNpcConfig(NPC_GetID(npc));
	if cfg.drop then
		-- TODO: send reward
	end

	NPC_Remove(npc);


	if current_wave == 4 then
		last_wave_count = last_wave_count - 1
		if last_wave_count <= 0 then
			EndToReward()
			is_rewarded = true
		end
	end
end

function Interact(pid, npc, opt)
	if opt == 1 then
		local cfg = GetNpcConfig(NPC_GetID(npc));
		if cfg.fight_id and cfg.fight_id ~= 0 then
			if StartFight({pid}, cfg.fight_id, {}, function(winner) AfterFight(winner, npc); end) then
				NPC_SetValue(npc, 3, 1);
			end
		elseif cfg.drop then
			-- TODO:send reward
			NPC_Remove(npc);
		end
	elseif opt == 2 then
		local cfg = GetNpcConfig(NPC_GetID(npc));
		if cfg.drop then
			local pids = GetTeamMembers()
                        SendDropReward(pids, nil, {cfg.drop})
                        NPC_Remove(npc)
		end
	elseif opt == 3 then
		if IsLeader(pid) then GameOver() end
	end
end
