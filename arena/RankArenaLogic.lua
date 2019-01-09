local PlayerManager = require "RankArenaPlayerManager"
local VPosition = require "VPosition"
local ArenaConfig = require "RankArenaConfig"
local RankArenaLog = require "RankArenaLog"
local ArenaFormation = require "ArenaFormation"
local ArenaEnemyConfigManager = require "ArenaEnemyConfigManager"
local OpenlevConfig = require "OpenlevConfig"
require "AMF"
require "printtb"

local function encode(protocol, msg)
    local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
    if code == nil then
        print(string.format(" * encode %s failed", protocol));
        loop.exit();
        return nil;
    end
    return code;
end

local function DOReward(pid, reward, consume, reason, manual, limit, name)
	assert(reason and reason ~= 0)

	local respond = cell.sendReward(pid, reward, consume, reason, manual, limit, name)
	if respond == nil or respond.result ~= 0 then
		return false;
	end
	return true;
end

local ArenaQueue = {}
function add_player_to_arena_queue(pos, player)
    ArenaQueue[pos] =player
end

local playerEnemyPool = {}
local function add_player_enemy_pool(pid, enemy_list)
	playerEnemyPool[pid] = enemy_list	
end

local function get_player_enemy_pool(pid)
	return playerEnemyPool[pid]
end

-- 添加角色
local function addPlayer(id)
    local player = PlayerManager.Get(id);
    if  player == nil then
        log.debug("addPlayer " .. id);
        player = PlayerManager.Create(id);
        if player then
            assert(ArenaQueue[player.order] == nil);
            ArenaQueue[player.order] = player;
			PlayerManager.UpdateMaxOrder(player.order)
        end

		if not ArenaEnemyConfigManager.AllAIJoinRankArena() then
			local ais = ArenaEnemyConfigManager.genRankArenaAIEnemy()
			local ai
			for _, id in ipairs(ais) do
				ai = PlayerManager.Create(id)	
				if ai then
					assert(ArenaQueue[ai.order] == nil);
            		ArenaQueue[ai.order] = ai;
					PlayerManager.UpdateMaxOrder(ai.order)
				end
			end
		end
    end
    return player;
end

-- 查询角色
local function getPlayer(playerid)
    return PlayerManager.Get(playerid);
end

local function getPlayerByPos(pos)
    return ArenaQueue[pos];
end

local function dumpTable(t, prefix)
    prefix = prefix or "";

    for k, v in pairs(t) do
        print(string.format("%s%s\t%s", prefix, tostring(k), tostring(v)));
        if type(v) == "table" then
            dumpTable(v, prefix .. "\t");
        end
    end
end

-- 下次重置时间
local function getArenaRefreshTime()
        local at = ArenaConfig.REWARD_TIME;
        local round = 3600 * 24;

    local now = loop.now();
    local cday, csec = Time.ROUND(now - at, round);

    return now - csec + round;
end

-- set ArenaQueue
for pid, player in pairs(PlayerManager.all) do
    --log.debug(string.format("order %u, player %u", player.order, player.id));
    ArenaQueue[player.order] = player;
end

local robot_fight_data_cache = {}

local ROBOT_MIN_ID = 100001
local ROBOT_MAX_ID = 110000 
local function getPlayerFightData(pid, attacker)
	local fight_data
	if pid >= ROBOT_MIN_ID and pid <= ROBOT_MAX_ID then
		if robot_fight_data_cache[pid] then
			fight_data = robot_fight_data_cache[pid]
		else
			fight_data, err = cell.QueryPlayerFightInfo(pid, true, attacker and 0 or 100)
			if err then
				return 
			end
			robot_fight_data_cache[pid] = fight_data

			local player_formation = ArenaFormation.Get(pid)
			if not player_formation then
				return 
			end

			if not player_formation:Query(1, attacker) then
				player_formation:Update(1, fight_data)
			end
		end

		if not fight_data then
			return
		end

		if attacker then
			for k, role in pairs(fight_data.roles) do
				if role.refid >= 100 then
					role.refid = role.refid - 100
				end	
			end
		else
			for k, role in pairs(fight_data.roles) do
				if role.refid < 100 then
					role.refid = role.refid + 100
				end	
			end
		end	

		return fight_data 
	else
		local player_formation = ArenaFormation.Get(pid)
		if not player_formation then
			return 
		end

		fight_data = player_formation:Query(1, attacker)
		return fight_data
	end
end

local function onArenaQuery(conn, playerid, request)
    log.debug("onArenaQuery " .. playerid);
    assert(coroutine.running());

    local sn  = request[1];
    local target = request[2] or playerid;

    local cmd = Command.C_ARENA_QUERY_RESPOND;
    local player = getPlayer(target);
    if player == nil then
        local msg = {
            sn,
            Command.RET_SUCCESS,
            0,
            target,
            --0,
            ArenaConfig.getFightCountPerDay(),
            --0,
            --0,
            --getArenaRefreshTime(),
            --ArenaConfig.getFightCountPerDay(),
            --ArenaConfig.ADD_FC_CONSUME_BASE,
			0,
			0,
			{},
			0,
			""
        };
		return conn:sendClientRespond(cmd, playerid, msg);
    end

    local pos = player.order;

    local cost = ArenaConfig.ADD_FC_CONSUME_BASE + player.addFightCount * ArenaConfig.ADD_FC_CONSUME_COEF;
    if cost > ArenaConfig.ADD_FC_CONSUME_MAX then
        cost = ArenaConfig.ADD_FC_CONSUME_MAX;
    end
    local t_now =os.time()
    local cd =player.fight_cd < t_now and 0 or player.fight_cd - t_now

	local fight_data = getPlayerFightData(playerid, false)
    local respond = {
        sn,     -- sn
        Command.RET_SUCCESS,    -- result
        -- self
        pos,
        player.id,
        --player.cwin,        -- 连胜
        ArenaConfig.getFightCountPerDay() - player.addFightCount, --- player.fight_count + player.addFightCount,  -- 剩余购买体力次数
        --cd, -- 挑战cd
        --player.xorder,      -- 昨天排名
        --player.reward_cd,   -- 领奖cd
        --ArenaConfig.getFightCountPerDay(),
        --cost,   -- 下次体力购买价格
		player.daily_reward_flag,
		player.last_refresh_enemy_list_time,
		player.formation_data.formation,
		player.today_win_count,
		fight_data and encode('FightPlayer', fight_data) or ""
    }

    log.info("fight cd =", cd)
    return conn:sendClientRespond(cmd, playerid, respond);
end

local function onArenaJoin(conn, playerid, request)
    log.info("onArenaJoin " .. playerid);
    assert(coroutine.running());

    local sn  = request[1];

    local cmd = Command.C_ARENA_JOIN_RESPOND;
    local player = addPlayer(playerid);
    if player == nil then
        local msg = {sn, Command.RET_CHARACTER_NOT_EXIST, "add player failed"};
		return conn:sendClientRespond(cmd, playerid, msg);
    end

    -- 记录连接
    PlayerManager.Login(playerid, conn)

    local pos = player.order;

    local respond = {
        sn,     -- sn
        Command.RET_SUCCESS,    -- result
        pos,    -- self
        {},             -- neighbors
        --{},         -- fight
    }

    -- 加载附近的人
    local neighbor = respond[4];

    --local vpos = VPosition.Neighbor(pos);

	--init player fight data
	if not getPlayerFightData(playerid, false) then
		local fight_data, err = cell.QueryPlayerFightInfo(playerid, false, 0)
		if not err then
			local player_formation = ArenaFormation.Get(playerid)
			if player_formation then
				player_formation:Update(1, fight_data)
			end
		end
	end

	if SGK_Game() then
		if not OpenlevConfig.isLvOK(playerid, 1902) then
			log.debug(string.format("%d level not enough", playerid))
			return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR});
		end

		local enemy_list = player.enemy_list--get_player_enemy_pool(pid)
		if enemy_list and #enemy_list > 0 then
			for _, pos in ipairs(enemy_list) do
				local enemy = getPlayerByPos(pos)
				if enemy then
					local fight_data = getPlayerFightData(enemy.id, false)
					table.insert(neighbor, {enemy.order, enemy.id, fight_data and encode('FightPlayer', fight_data) or ""});
				end
			end
		else	
			local max_pos = PlayerManager.GetMaxOrder()
			local vpos = VPosition.GetRankArenaEnemyList_sgk(pos, max_pos)
			local epool = {}
			for _, idx in pairs(vpos) do
				local target = getPlayerByPos(idx)
				if target then
					local t = {
						idx,
						target.id,
					};
					local fight_data = getPlayerFightData(target.id, false)
					table.insert(neighbor, t);
					table.insert(epool, idx)
					table.insert(t, fight_data and encode('FightPlayer', fight_data) or "")
				end

			end
			
			player:refreshEnemyList(epool)
		end
	else
		local enemy_list = player.enemy_list--get_player_enemy_pool(pid)
		if enemy_list and #enemy_list > 0 then
			for _, pid in ipairs(enemy_list) do
				local enemy = getPlayer(pid)
				if enemy then
					table.insert(neighbor, {enemy.order, pid, encode('FightPlayer', enemy.formation_data.fight_data)});
				end
			end
		else	
			local vpos = VPosition.GetRankArenaEnemyList(pos)
			local epool = {}
			for _, idx in pairs(vpos) do
				local target = getPlayerByPos(idx)
				if target then
					local t = {
						idx,
						target.id,
					};
					table.insert(neighbor, t);
					table.insert(epool, target.id)
				end

			end
			
			player:refreshEnemyList(epool)
			--add_player_enemy_pool(playerid, epool)
		end
	end

    return conn:sendClientRespond(cmd, playerid, respond);
end

local function onArenaAttack_sgk(conn, playerid, request)
	yqinfo("onArenaAttack_sgk %d", playerid)
	local cmd = Command.C_ARENA_ATTACK_SGK_RESPOND
	local sn = request[1]
	local target_pos = request[2]
	local target_id = request[3]

	local attacker = getPlayer(playerid)
	local target = getPlayer(target_id)
	if not attacker then
		log.debug("attacker not exist")
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_CHARACTER_NOT_EXIST});
	end

	if not target then
		log.debug("target not exist")
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_CHARACTER_NOT_EXIST});
	end

	if target.order ~= target_pos then
		log.debug(string.format("player %d not in pos %d", target_id, target_pos))
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_PARAM_ERROR});
	end

	local epool = attacker.enemy_list
	local has_enemy = false
	for _, pos in ipairs(epool) do
		if pos == target_pos then
			has_enemy = true
			break
		end
	end

	if not has_enemy then
		log.debug(string.format("player %d not has enemy in pos %d", playerid, target_pos))
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR});
	end

	
	if not OpenlevConfig.isLvOK(playerid, 1902) then
        log.debug(string.format("%d level not enough", playerid))
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR});
	end

	--[[if attacker.level < ArenaConfig.ARENA_OPEN_LEVEL then--Command.OPEN_LEVEL_ARENA then
        log.debug(string.format("%d level not enough", playerid))
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR});
    end--]]

	--检查体力
	if not DOReward(playerid, nil, {{type = ArenaConfig.FIGHT_COST_ITEM_TYPE, id = ArenaConfig.FIGHT_COST_ITEM_ID, value = ArenaConfig.FIGHT_COST_ITEM_VALUE}}, Command.REASON_RANK_ARENA_CONSUME, false)  then
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_NOT_ENOUGH});
	end

    -- 条件满足
    log.debug(string.format("onArenaAttack (%u,%d) -> (%u,%d)", attacker.id, attacker.order, target.id, target.order));

	local attacker_data, err = cell.QueryPlayerFightInfo(attacker.id, false, 0)
	if err then
		log.debug(string.format('prepare rank arena fightdata fail, get attack fight data of player %d error %s', attacker.id, err))
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR});
	end

	local defender_data = getPlayerFightData(target.id, false)
	if not defender_data then
		log.debug(string.format('prepare rank arena fightdata fail, get defender fight data of player %d error %s', target.id, err))
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR});
	end

	local opt = {
		attacker_data = attacker_data,
		defender_data = defender_data,
		auto = true
	}
	local winner, fight_id, seed, roles = SocialManager.PVPFightPrepare(attacker.id, target.id, opt)	
	if winner then
        local fightData = {
            attacker = opt.attacker_data,
            defender = opt.defender_data,
            seed = seed,
            scene = "18hao"
        }

		RankArenaLog.AddLog(attacker, target, winner, fight_id, fightData)

        local code = encode('FightData', fightData)
		local pos11 = attacker.order;
		local pos21 = target.order;

		if winner == 1 then
			local o1 = attacker.order;
			local o2 = target.order;

			if o1 > o2 then
				-- 交换排名
				o1, o2 = o2, o1;
			end

			-- 挑战胜利: 减少次数，记录时间，增加连胜, 更改排位
			attacker:setArenaInfo(attacker.fight_count + 1, loop.now(), attacker.cwin + 1, o1, ArenaConfig.FIGHT_CD_WHEN_WIN, attacker.addFightCount, nil, attacker.today_win_count + 1);

			-- 被挑战失败: 连胜清零, 更改排位, 不改变cd
			target:setArenaInfo(nil, nil, 0, o2, nil);

			ArenaQueue[target.order] = target;
			ArenaQueue[attacker.order] = attacker;

			-- 刷新对手列表
			-- attacker
			local max_pos = PlayerManager.GetMaxOrder()
			local vpos = VPosition.GetRankArenaEnemyList_sgk(o1, max_pos)
			local epool = {}
			for _, idx in pairs(vpos) do
				local target = getPlayerByPos(idx)
				if target then
					table.insert(epool, idx)
				end
			end
			attacker:refreshEnemyList(epool)

			--target
			vpos = VPosition.GetRankArenaEnemyList_sgk(o2, max_pos)
			epool = {}
			for _, idx in pairs(vpos) do
				local target = getPlayerByPos(idx)
				if target then
					table.insert(epool, idx)
				end
			end
			target:refreshEnemyList(epool)

			--发积分	
			DOReward(attacker.id, {{type = 41, id = 90170, value = 2}}, nil, Command.REASON_RANK_ARENA_REWARD, false)
		else
			-- 挑战失败: 减少次数，记录时间, 清零连胜, 5 分钟CD
			attacker:setArenaInfo(attacker.fight_count + 1, loop.now(), 0, nil, attacker.vip < ArenaConfig.CD_DEPEND_VIPLV and ArenaConfig.FIGHT_CD_WHEN_LOSS, attacker.addFightCount);
			--发积分	
			DOReward(attacker.id, {{type = 41, id = 90170, value = 1}}, nil, Command.REASON_RANK_ARENA_REWARD, false)
		end

		local cd =attacker.fight_cd < loop.now() and 0 or attacker.fight_cd - loop.now() 
		local msg = {
			sn,
			Command.RET_SUCCESS,
		}
		conn:sendClientRespond(cmd, playerid, {sn, Command.RET_SUCCESS, code});
		log.info("fight cd =", cd)
		yqinfo("`%d` success to C_ARENA_ATTACK_SGK_REQUEST", playerid)

		local pos12 = attacker.order;
		local pos22 = target.order;

		-- 个人奖励
		--cell.sendReward(attacker.id, reward, nil, Command.REWARD_TYPE_ARENA_FIGHT);

		-- 通知
		msg = {
			-- 进攻方
			attacker.id,
			pos12,
			pos11,
			-- 防守方
			target.id,
			pos22,
			pos21,

			--fight_data, -- 战斗数据
			--winner, -- 胜利方
			--loop.now(),     -- 时间
		}

		local pids = {attacker.id, target.id};
		log.debug(string.format("竞技场排名变化:%s %d -> %d", attacker.name, pos11, pos12));
		--[[if pos12 < pos11 and pos12 <= ArenaConfig.NOTIFY_TOP and winner == 1 then
			pids = nil;
			log.debug("worldNotify");
		else
			if pos11 ~= pos12 or pos21 ~= pos22 then
				-- 排名变化  通知邻居
				if winner == 1 and (pos11 > pos21) then
					-- notify neighbors
					local watcher = VPosition.Watcher(pos11);
					for _, idx in pairs(watcher) do
						local target = getPlayerByPos(idx)
						if target and not sended[target.id] then
							table.insert(pids, target.id)
							sended[target.id] = true;
						end
					end

					watcher = VPosition.Watcher(pos12);
					for _, idx in pairs(watcher) do
						local target = getPlayerByPos(idx)
						if target and not sended[target.id] then
							table.insert(pids, target.id)
							sended[target.id] = true;
						end
					end
				end
			end
		end--]]
		log.debug("broadcast attack notification");
		if pos11 ~= pos12 then
			NetService.NotifyClients(Command.NOTIFY_ARENA_ATTACK, msg, pids);
		end

	else
		conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR});
	end	
end

local fight_list = {}
local function onArenaAttack(conn, playerid, request)
    yqinfo("BEGIN: C_ARENA_ATTACK_REQUEST %d", playerid)
    local sn  = request[1];
    local target_id = request[2];

    local cmd = Command.C_ARENA_ATTACK_RESPOND;

	-- 玩家不存在
    local attacker = getPlayer(playerid);
    local target = getPlayer(target_id);
    if target == nil or attacker == nil then
        log.debug("attacker or target not exist");
        -- 目标不存在
        local msg = { sn, Command.RET_CHARACTER_NOT_EXIST, "attacker or target not exist", }
		return conn:sendClientRespond(cmd, playerid, msg);
    end

	local epool = attacker.enemy_list--get_player_enemy_pool(playerid)
	local has_enemy = false 
	for _, epid in ipairs(epool or {}) do
		if epid == target_id then
			has_enemy = true
		end
	end
	
	if not has_enemy then
		log.debug(string.format("onArenaAttack player %u not has enemy %u", playerid, target_id));
        local msg = {sn, Command.RET_ERROR, ""}
		return conn:sendClientRespond(cmd, playerid, msg);
	end

    -- 参数错误
    --[[if target <= 0 or ArenaQueue[pos] == nil then
        log.debug(string.format("onArenaAttack param error: %u %u", playerid, target));
        local msg = {sn, Command.RET_PARAM_ERROR, "param error"}
        local code = AMF.encode(msg);
        if code then conn:sends(1, cmd, playerid, code); end
        return;
    end--]]

    
    -- 检查开放等级
	print("attacker level", attacker.level)
    if attacker.level < ArenaConfig.ARENA_OPEN_LEVEL then--Command.OPEN_LEVEL_ARENA then
        log.error(string.format("%d fail to attack, level limit", attacker.id))
        local msg = { sn, Command.RET_ERROR, "level limit", }
		return conn:sendClientRespond(cmd, playerid, msg);
    end

    -- 检查战斗次数和数量
    --[[if (attacker.fight_count - attacker.addFightCount >= ArenaConfig.getFightCountPerDay()) then
        log.debug("get fight limit");
        local msg = { sn, Command.RET_ARENA_LIMIT, "get fight limit" };
        local code = AMF.encode(msg);
        if code then conn:sends(1, cmd, playerid, code); else assert(false); end
        return;
    end--]]

    --[[if (attacker.fight_cd > loop.now()) then
        log.debug(string.format("cd:%d",  attacker.fight_cd-loop.now()));
        local msg = { sn, Command.RET_ARENA_COOLDOWN, "fighting" };
        local code = AMF.encode(msg);
        if code then conn:sends(1, cmd, playerid, code); else assert(false); end
        return;
    end--]]

	--检查体力
	if not DOReward(playerid, nil, {{type = ArenaConfig.FIGHT_COST_ITEM_TYPE, id = ArenaConfig.FIGHT_COST_ITEM_ID, value = ArenaConfig.FIGHT_COST_ITEM_VALUE}}, Command.REASON_RANK_ARENA_CONSUME, false)  then
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR});
	end

    -- 条件满足
    log.info(string.format("onArenaAttack (%u,%d) -> (%u,%d)", attacker.id, attacker.order, target.id, target.order));

	local attacker_formation = attacker.formation_data.formation
	local default_formation = true
	for k, v in ipairs(attacker_formation) do
		if v ~= 0 then
			default_formation = false
		end
	end

	--TODO
	local attacker_data, err = cell.QueryPlayerFightInfo(attacker.id, false, 0, not default_formation and attacker_formation or nil)
	if err then
		log.debug(string.format('prepare rank arena fightdata fail, get attack fight data of player %d error %s', attacker.id, err))
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR});
	end
	attacker:reloadFormationData(attacker_data)

	local defender_formation = target.formation_data.formation
	default_formation = true
	for k, v in ipairs(defender_formation) do
		if v ~= 0 then
			default_formation = false
		end
	end

	defender_data, err = cell.QueryPlayerFightInfo(target.id, false, 100, not default_formation and defender_formation or nil)
	if err then
		log.debug(string.format('prepare rank arena fightdata fail, get defender fight data of player %d error %s', defender.id, err))
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR});
	end
	target:reloadFormationData(defender_data)

	local scene = "18hao"
	local fightData = {
		attacker = attacker_data,--attacker,
		defender = defender_data, --defender,
		seed = math.random(1, 0x7fffffff),
		scene = scene,
	}

	local code = encode('FightData', fightData);
	if code == nil then
		log.debug(string.format('encode fight data failed'));
		return false
	end

	fight_list[playerid] = target_id

	local msg = {
        sn,
        Command.RET_SUCCESS,
		code,
	}
    conn:sendClientRespond(cmd, playerid, msg);

end

local function onArenaFightCheck(conn, playerid, request)
	local sn = request[1]
	local target_id = request[2]
	local winner = request[3]
	local cmd = Command.C_ARENA_FIGHT_CHECK_RESPOND

	if not target_id or not winner then
		log.debug(string.format('check rank arena fight result fail, param 2nd or param 3rd is nil'))
        local msg = {sn, Command.RET_ERROR};
		return conn:sendClientRespond(cmd, playerid, msg);
	end

	if not fight_list[playerid] or fight_list[playerid] ~= target_id then
		log.debug(string.format('check rank arena fight result fail, player %d donnt has fight for target %d', playerid, target_id))
        local msg = {sn, Command.RET_ERROR};
		return conn:sendClientRespond(cmd, playerid, msg);
	end 

	log.debug(string.format("Player %d begin to check RankArena fight result for target %d, winner %d", playerid, target_id,  winner))
    --[[local success, winner, fight_data, fight_record_id, cool_down = FightManager.pvp_fight_wrap(attacker, target);
	-- 战斗失败
    if not success then
        local msg = {sn, Command.RET_FIGHT_FAILED, "start fight failed", }
        local code = AMF.encode(msg);
        if code then conn:sends(1, cmd, playerid, code); end
        yqinfo("`%d` fail to C_ARENA_ATTACK_REQUEST", playerid)
        return;
    end--]]

	local attacker = getPlayer(playerid)
	local target = getPlayer(target_id)

	if not attacker or not target then
		log.debug(string.format('check rank arena fight result fail, get attacker or get target fail'))
        local msg = {sn, Command.RET_ERROR};
		return conn:sendClientRespond(cmd, playerid, msg);
	end

    local pos11 = attacker.order;
    local pos21 = target.order;

    if winner == 1 then
        local o1 = attacker.order;
        local o2 = target.order;

        if o1 > o2 then
            -- 交换排名
            o1, o2 = o2, o1;
        end

        -- 挑战胜利: 减少次数，记录时间，增加连胜, 更改排位
        attacker:setArenaInfo(attacker.fight_count + 1, loop.now(), attacker.cwin + 1, o1, ArenaConfig.FIGHT_CD_WHEN_WIN, attacker.addFightCount, nil, attacker.today_win_count + 1);

        -- 被挑战失败: 连胜清零, 更改排位, 不改变cd
        target:setArenaInfo(nil, nil, 0, o2, nil);

        ArenaQueue[target.order] = target;
        ArenaQueue[attacker.order] = attacker;

		-- 刷新对手列表
		local vpos = VPosition.GetRankArenaEnemyList(o1)
		local epool = {}
		for _, idx in pairs(vpos) do
			local target = getPlayerByPos(idx)
			if target then
				table.insert(epool, target.id)
			end
		end
		attacker:refreshEnemyList(epool)
    else
        -- 挑战失败: 减少次数，记录时间, 清零连胜, 5 分钟CD
        attacker:setArenaInfo(attacker.fight_count + 1, loop.now(), 0, nil, attacker.vip < ArenaConfig.CD_DEPEND_VIPLV and ArenaConfig.FIGHT_CD_WHEN_LOSS, attacker.addFightCount);
    end

	-- enemy_list
	local amf_enemy_list = {}
	local enemy_list = attacker.enemy_list
	if enemy_list and #enemy_list > 0 then
		for _, pid in ipairs(enemy_list) do
			local enemy = getPlayer(pid)
			if enemy then
        		table.insert(amf_enemy_list, {enemy.order, pid, encode('FightPlayer', enemy.formation_data.fight_data)});
			end
		end
	end

    -- 先返回消息， 不太可靠
    --[[local reward =  ArenaConfig.getFightReward(winner == 1)
    local reward_list_amf ={}
    for i=1, #reward do
        local item =reward[i]
        table.insert(reward_list_amf, {item.type, item.id, item.value})
    end--]]
    local t_now =os.time()
    local cd =attacker.fight_cd < t_now and 0 or attacker.fight_cd - t_now
    local msg = {
        sn,
        Command.RET_SUCCESS,
		--amf_enemy_list,
        --fight_record_id,        -- 战斗记录ID
        --fight_data,             -- 战斗数据
        --winner,
        --attacker.order,     -- 打完之后的位置
        --cd,
        --ArenaConfig.getFightCountPerDay() - attacker.fight_count + attacker.addFightCount,
        --attacker.cwin,
        --reward_list_amf
	}
    conn:sendClientRespond(cmd, playerid, msg);
    log.info("fight cd =", cd)
    yqinfo("`%d` success to C_ARENA_ATTACK_REQUEST", playerid)

    local pos12 = attacker.order;
    local pos22 = target.order;

    -- 个人奖励
    --cell.sendReward(attacker.id, reward, nil, Command.REWARD_TYPE_ARENA_FIGHT);

    -- 通知
    msg = {
        -- 进攻方
        attacker.id,
        pos12,
        pos11,
        -- 防守方
        target.id,
        pos22,
        pos21,

        --fight_data, -- 战斗数据
        --winner, -- 胜利方
        --loop.now(),     -- 时间
    }

    --local sended = {};
    --sended[attacker.id] = true;
    --sended[target.id] = true;

    local pids = {attacker.id, target.id};
    log.debug(string.format("竞技场排名变化:%s %d -> %d", attacker.name, pos11, pos12));
    --[[if pos12 < pos11 and pos12 <= ArenaConfig.NOTIFY_TOP and winner == 1 then
        pids = nil;
        log.debug("worldNotify");
    else
        if pos11 ~= pos12 or pos21 ~= pos22 then
            -- 排名变化  通知邻居
            if winner == 1 and (pos11 > pos21) then
                -- notify neighbors
                local watcher = VPosition.Watcher(pos11);
                for _, idx in pairs(watcher) do
                    local target = getPlayerByPos(idx)
                    if target and not sended[target.id] then
                        table.insert(pids, target.id)
                        sended[target.id] = true;
                    end
                end

                watcher = VPosition.Watcher(pos12);
                for _, idx in pairs(watcher) do
                    local target = getPlayerByPos(idx)
                    if target and not sended[target.id] then
						table.insert(pids, target.id)
                        sended[target.id] = true;
                    end
                end
            end
        end
    end--]]
    log.debug("broadcast attack notification");
    NetService.NotifyClients(Command.NOTIFY_ARENA_ATTACK, msg, pids);

    --SocialManager.SendPlayerRecordChangeNotify(playerid, 1100, 0, 1);

    -- ai patch
    --aiserver.NotifyAIAction(playerid, Command.ACTION_ARENA_ATTACK)

    -- add mail
    --[[if winner == 1 then
        send_arena_mail(attacker.id, YQSTR.ARENA_FIGHT, string.format(YQSTR.ARENA_FIGHT_WIN_INFO, util.make_player_rich_text(target.id, target.name)))
        send_arena_mail(target.id, YQSTR.ARENA_FIGHT, string.format(YQSTR.ARENA_FIGHT_LOSS_INFO, util.make_player_rich_text(attacker.id, attacker.name)))
    elseif winner == 2 then
        send_arena_mail(attacker.id, YQSTR.ARENA_FIGHT, string.format(YQSTR.ARENA_FIGHT_LOSS_INFO, util.make_player_rich_text(target.id, target.name)))
        send_arena_mail(target.id, YQSTR.ARENA_FIGHT, string.format(YQSTR.ARENA_FIGHT_WIN_INFO, util.make_player_rich_text(attacker.id, attacker.name)))
    elseif winner == 0 then
        send_arena_mail(attacker.id, YQSTR.ARENA_FIGHT, string.format(YQSTR.ARENA_FIGHT_DEUCE_INFO, util.make_player_rich_text(target.id, target.name)))
        send_arena_mail(target.id, YQSTR.ARENA_FIGHT, string.format(YQSTR.ARENA_FIGHT_DEUCE_INFO, util.make_player_rich_text(attacker.id, attacker.name)))
    end--]]
end

local function onArenaReward(conn, playerid, request)
	local sn = request[1]
	local index = request[2]
	local cmd = Command.C_ARENA_REWARD_RESPOND

	if not index then
		log.debug(string.format('Player %d get rank arena daily reward fail, param 2nd is nil'))
        local msg = {sn, Command.RET_ERROR};
		return conn:sendClientRespond(cmd, playerid, msg);
	end

	local player = getPlayer(playerid)
	if not player then
		log.debug(string.format('Player %d get rank arena daily reward fail, cannt get player', playerid))
        local msg = {sn, Command.RET_ERROR};
		return conn:sendClientRespond(cmd, playerid, msg);
	end

	local mask = 2 ^ (index - 1)
	if bit32.band(player.daily_reward_flag, mask) ~= 0 then
		log.debug(string.format('Player %d get rank arena daily reward fail, already draw reward for index %d today', playerid, index))
        local msg = {sn, Command.RET_ERROR};
		return conn:sendClientRespond(cmd, playerid, msg);
	end

	--check conditon
	local today_win_count = player.today_win_count
	local reward_cfg = ArenaConfig.GetDailyReward(index)
	if not reward_cfg then
		log.debug(string.format('Player %d get rank arena daily reward fail for index %d, get reward config fail', playerid, index))
        local msg = {sn, Command.RET_ERROR};
		return conn:sendClientRespond(cmd, playerid, msg);
	end

	if today_win_count < reward_cfg.condition then
		log.debug(string.format('Player %d get rank arena daily reward fail for index %d, check win count fail', playerid, index))
        local msg = {sn, Command.RET_ERROR};
		return conn:sendClientRespond(cmd, playerid, msg);
	end

	--send reward
	local reward = reward_cfg.reward
	if reward and #reward > 0 then
		DOReward(info.pid, reward, nil, Command.REASON_RANK_ARENA_REWARD, true, 0, "排名竞技场奖励")
	end

	local flag = bit32.bor(player.daily_reward_flag, mask)
    player:setArenaInfo(nil, nil, nil, nil, nil, nil, flag, nil);

    conn:sendClientRespond(cmd, playerid, {sn, Command.RET_SUCCESS});
end

local function onArenaResetCooldown(conn, playerid, request)
    log.info(string.format("onArenaResetCooldown %u", playerid));
    local sn  = request[1];

    local cmd = Command.C_ARENA_RESET_CD_RESPOND;

    local player = getPlayer(playerid);
    if player == nil then
        local msg = { sn, Command.RET_CHARACTER_NOT_EXIST, "player not exists" }
		return conn:sendClientRespond(cmd, playerid, msg);
    end

    if (player.fight_count - player.addFightCount >= ArenaConfig.getFightCountPerDay()) or (player.fight_cd <= loop.now()) then
        local msg = { sn, Command.RET_SUCCESS}
		return conn:sendClientRespond(cmd, playerid, msg);
    end

    local consume = {
        {
            id = RESOURCES_MONEY,
            value = 5,
        }
    };

    respond = cell.sendReward(player.id, nil, consume, Command.REASON_ARENA_RESET_CD);
    if (respond.result ~= "RET_SUCCESS") then
        local msg = { sn, Command.RET_RESOURCE_MONEY_NOT_ENOUGH_2, "not enough" }
		return conn:sendClientRespond(cmd, playerid, msg);
    end

    player.fight_time = player.fight_time - 5 * 60; -- TODO: hack
    local msg = {
        sn,
        Command.RET_SUCCESS,
    }

    return conn:sendClientRespond(cmd, playerid, msg);
end

local function onArenaAddFightCount(conn, playerid, request)
    log.info(string.format("onArenaAddFightCount %u", playerid));
    local sn  = request[1];
	local value = request[2] or 1
	--[[if value > ArenaConfig.FIGHT_COST_ITEM_MAX_VALUE then
		value = ArenaConfig.FIGHT_COST_ITEM_MAX_VALUE
	end--]]

    local cmd = Command.C_ARENA_ADD_FIGHTCOUNT_RESPOND;

    local player = getPlayer(playerid);
    if player == nil then
        log.error("fail to onArenaAddFightCount, RET_CHARACTER_NOT_EXIST")
        local msg = { sn, Command.RET_CHARACTER_NOT_EXIST, "player not exists" }
		return conn:sendClientRespond(cmd, playerid, msg);
    end

    if player.vip < ArenaConfig.ADD_FC_DEPEND_VIPLV then
        log.error(string.format("fail to onArenaAddFightCount, RET_ARENA_NOT_VIP, vip=%d", player.vip))
        local msg = { sn, Command.RET_ARENA_NOT_VIP};
		return conn:sendClientRespond(cmd, playerid, msg);
    end

	if player.addFightCount >= ArenaConfig.FIGHT_COUNT_PER_DAY then
		log.error(string.format("fail to onArenaAddFightCount, today add count is max"))
        local msg = { sn, Command.RET_ERROR};
		return conn:sendClientRespond(cmd, playerid, msg);
	end

    local cost = ArenaConfig.ADD_FC_CONSUME_BASE + player.addFightCount * ArenaConfig.ADD_FC_CONSUME_COEF;
    if cost > ArenaConfig.ADD_FC_CONSUME_MAX then
        cost = ArenaConfig.ADD_FC_CONSUME_MAX;
    end

    local consume = {
        {
			type = ArenaConfig.ADD_FC_CONSUME_TYPE,
			id = ArenaConfig.ADD_FC_CONSUME_ID,
            value = 1 * value--cost,
        }
    };
	local reward = {{type = ArenaConfig.FIGHT_COST_ITEM_TYPE, id = ArenaConfig.FIGHT_COST_ITEM_ID, value = value}}

	if not DOReward(player.id, reward, consume, Command.REASON_RANK_ARENA_REWARD, false, nil, nil) then
		log.error("fail to onArenaAddFightCount, consume fail")
        local msg = { sn, Command.RET_ERROR }
		return conn:sendClientRespond(cmd, playerid, msg);
	end
    --[[respond = cell.sendReward(player.id, nil, consume, Command.REASON_ARENA_ADD_FIGHT_COUNT);
    if (respond.result ~= "RET_SUCCESS") then
        log.error("fail to onArenaAddFightCount, RET_RESOURCE_MONEY_NOT_ENOUGH_2")
        local msg = { sn, Command.RET_RESOURCE_MONEY_NOT_ENOUGH_2, "not enough" }
        local code = AMF.encode(msg);
        if code then conn:sends(1, cmd, playerid, code); end
        return ;
    end--]]

    player:setArenaInfo(nil, nil, nil, nil, nil, player.addFightCount + 1, nil, nil, nil, loop.now());
    --[[cost = ArenaConfig.ADD_FC_CONSUME_BASE + player.addFightCount * ArenaConfig.ADD_FC_CONSUME_COEF;
    if cost > ArenaConfig.ADD_FC_CONSUME_MAX then
        cost = ArenaConfig.ADD_FC_CONSUME_MAX;
    end

    local msg = {
        sn,
        Command.RET_SUCCESS,
        cost,
        ArenaConfig.getFightCountPerDay() - player.fight_count + player.addFightCount,
    }--]]

    return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_SUCCESS});
end

local function onArenaQueryTop(conn, playerid, request)
    log.info(string.format("onArenaQueryTop %u", playerid));
    local sn  = request[1];

    local cmd = Command.C_ARENA_QUERY_TOP_RESPOND;

    local player = getPlayer(playerid);
    if player == nil then
        local msg = { sn, Command.RET_CHARACTER_NOT_EXIST, "player not exists" }
		print(">>>>>>>>>  player not exist")
		return conn:sendClientRespond(cmd, playerid, msg);
    end

    local rt = {};
    for i = 1, ArenaConfig.QUERY_TOP do
        local tempPlayer = getPlayerByPos(i);
        if tempPlayer then
            if tempPlayer.id then
				local fight_data = getPlayerFightData(tempPlayer.id, false)
                table.insert(rt, {tempPlayer.id, fight_data and encode('FightPlayer', fight_data) or ""});
            end
        end
    end

    local msg = {
        sn,
        Command.RET_SUCCESS,
        rt,
    }

    return conn:sendClientRespond(cmd, playerid, msg);
end

local REFRESH_CD = 5 
local function onArenaRefreshEnemyList(conn, playerid, request)
	local sn = request [1]
	local cmd = Command.C_ARENA_REFRESH_ENEMY_LIST_RESPOND
	log.debug(string.format("Player %d begin to refresh enemy list", playerid))

	local player = getPlayer(playerid)
	if not player then
		log.debug("fail to refresh enemy list, cannot get player")
		local msg = {sn, Command.RET_CHARACTER_NOT_EXIST}
		return conn:sendClientRespond(cmd, playerid, msg);
	end

	if loop.now() - player.last_refresh_enemy_list_time <  REFRESH_CD then
		log.debug("fail to refresh enemy list, cooldown")
		local msg = {sn, Command.RET_ERROR}
		return conn:sendClientRespond(cmd, playerid, msg);
	end

	local amf_enemy_list = {}
	if SGK_Game() then
		if not OpenlevConfig.isLvOK(playerid, 1902) then
			log.debug(string.format("%d level not enough", playerid))
			return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR});
		end

		local max_pos = PlayerManager.GetMaxOrder()
		local vpos = VPosition.GetRankArenaEnemyList_sgk(player.order, max_pos)
		local epool = {}
		for _, idx in pairs(vpos) do
			local target = getPlayerByPos(idx)
			if target then
				local t = {
					idx,
					target.id,
				};
				local fight_data = getPlayerFightData(target.id, false)
				table.insert(amf_enemy_list, t);
				table.insert(epool, idx)
				table.insert(t, fight_data and encode('FightPlayer', fight_data) or "")
			end

		end
		
		player:refreshEnemyList(epool)
	else
		local vpos = VPosition.GetRankArenaEnemyList(player.order)
		local epool = {}
		for _, idx in pairs(vpos) do
			local target = getPlayerByPos(idx)
			if target then
				table.insert(epool, target.id)
			end
		end
		player:refreshEnemyList(epool)
		player:setArenaInfo(nil, nil, nil, nil, nil, player.addFightCount, nil, nil, loop.now());

		local amf_enemy_list = {}
		local enemy_list = player.enemy_list
		if enemy_list and #enemy_list > 0 then
			for _, pid in ipairs(enemy_list) do
				local enemy = getPlayer(pid)
				if enemy then
					table.insert(amf_enemy_list, {enemy.order, pid, encode('FightPlayer', enemy.formation_data.fight_data)});
				end
			end
		end
	end

    return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_SUCCESS, amf_enemy_list});
end

local function onArenaChangeFormation(conn, playerid, request)
	local sn = request [1]
	local formation = request[2]
	local cmd = Command.C_ARENA_CHANGE_FORMATION_RESPOND
	
	log.debug(string.format("Player %d begin to change formation", playerid))

	if SGK_Game() then
		if not OpenlevConfig.isLvOK(playerid, 1902) then
			log.debug(string.format("%d level not enough", playerid))
			return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR});
		end

		local default_formation = true
		for k, v in ipairs(formation) do
			if v ~= 0 then
				default_formation = false
			end
		end

		local fight_data, err = cell.QueryPlayerFightInfo(playerid, false, 0, not default_formation and formation or nil)
		if err then
			log.debug(string.format('prepare rank arena fightdata fail, get attack fight data of player %d error %s', attacker.id, err))
			return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR});
		end
		
		local player_formation = ArenaFormation.Get(playerid)
		if not player_formation then
			log.debug("cant get player formation")
			return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR});
		end

		player_formation:Update(1, fight_data)
	else
		if type(formation) ~= 'table' or #formation < 5 then
			log.debug("fail to change formation, param error")
			local msg = {sn, Command.RET_ERROR}
			return conn:sendClientRespond(cmd, playerid, msg);
		end

		local player = getPlayer(playerid)
		if not player then
			log.debug("fail to change formation, cannot get player")
			local msg = {sn, Command.RET_CHARACTER_NOT_EXIST}
			return conn:sendClientRespond(cmd, playerid, msg);
		end

		--check
		for k, uuid in ipairs(formation) do
			if uuid ~= 0 then
				local playerHeroInfo = cell.getPlayerHeroInfo(playerid, 0, uuid)	
				if not playerHeroInfo then
					yqinfo("fail to change formation, player %d donnt own hero :%d", playerid, uuid)	
					local msg = {sn, Command.RET_CHARACTER_NOT_EXIST}
					return conn:sendClientRespond(cmd, playerid, msg);
				end
			end
		end	

		player:changeFormation(formation)
	end

    return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_SUCCESS});
end

local function onArenaQueryLog(conn, playerid, request)
	local sn = request [1]
	local cmd = Command.C_ARENA_QUERY_LOG_RESPOND
	
	log.debug(string.format("Player %d begin to query arena log", playerid))
	local logs = RankArenaLog.QueryLog(playerid)

    return conn:sendClientRespond(cmd, playerid, {sn, logs and Command.RET_SUCCESS or Command.RET_ERROR, logs});
end

local function onArenaQueryPlayerFormation(conn, playerid, request)
	local sn = request [1]
	local target = request[2]
	local cmd = Command.C_ARENA_QUERY_FORMATION_RESPOND
	
	log.debug(string.format("Player %d begin to query formation or player %d", playerid, target))
	local fight_data = getPlayerFightData(target, false)

    return conn:sendClientRespond(cmd, playerid, {sn, fight_data and Command.RET_SUCCESS or Command.RET_ERROR, fight_data and encode('FightPlayer', fight_data) or ""});
end


local function registerCommand(service)
	service:on(Command.C_ARENA_QUERY_REQUEST, onArenaQuery);
    service:on(Command.C_ARENA_JOIN_REQUEST, onArenaJoin);
    service:on(Command.C_ARENA_ATTACK_REQUEST, onArenaAttack);
    service:on(Command.C_ARENA_REWARD_REQUEST, onArenaReward);
    service:on(Command.C_ARENA_RESET_CD_REQUEST, onArenaResetCooldown);
    service:on(Command.C_ARENA_ADD_FIGHTCOUNT_REQUEST, onArenaAddFightCount);
    service:on(Command.C_ARENA_QUERY_TOP_REQUEST, onArenaQueryTop);
    service:on(Command.C_ARENA_FIGHT_CHECK_REQUEST, onArenaFightCheck);
    service:on(Command.C_ARENA_REFRESH_ENEMY_LIST_REQUEST, onArenaRefreshEnemyList);
    service:on(Command.C_ARENA_CHANGE_FORMATION_REQUEST, onArenaChangeFormation);
    service:on(Command.C_ARENA_ATTACK_SGK_REQUEST, onArenaAttack_sgk);
    service:on(Command.C_ARENA_QUERY_LOG_REQUEST, onArenaQueryLog);
    service:on(Command.C_ARENA_QUERY_FORMATION_REQUEST, onArenaQueryPlayerFormation);
end

module "RankArenaLogic"

RegisterCommand = registerCommand


