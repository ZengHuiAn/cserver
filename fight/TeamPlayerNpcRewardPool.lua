require "Command"
local database = require "database"
local cell = require "cell"
local NpcRoll = require "NpcRoll"
local getNpcRoll = NpcRoll.Get
local NpcConfig = require "NpcConfig"
local MONSTER_REWARD_MAX_COUNT_DAILY = 2 
local BattleConfig = require "BattleConfig"

local function SendDropReward(pid, consume, reason, drops, heros)
	local ret = cell.sendReward(pid, consume, nil, reason, false, nil, "", drops, heros)
	if type(ret)=='table' then
		if ret.result== Command.RET_SUCCESS then
			local content = {}
			for k, v in ipairs(ret.rewards) do
				table.insert(content, {v.type, v.id, v.value})
			end

			return true, Command.RET_SUCCESS, content 
		else
			if ret.result== Command.RET_NOT_ENOUGH then
				return false, Command.RET_NOT_ENOUGH
			else
				return false, Command.RET_ERROR
			end
		end
	else 
		return false, Command.RET_ERROR
	end
end

local function Exchange(pid, reward, consume, reason)
	local respond = cell.sendReward(pid, reward, consume, reason, false)
	if respond and respond.result == Command.RET_SUCCESS then
		return true
	end

	return false
end

local function insertDrops(tb, ...)
	for i = 1, 3 do
		local drop = select(i, ...)
		if drop.id ~= 0 then
			table.insert(tb, drop)
		end
	end	
end

local function str_split(str, pattern)
	local arr ={}
	while true do
		if #str==0 then
			return arr
		end
		local pos,last =string.find(str, pattern)
		if not pos then
			table.insert(arr, str)
			return arr
		end
		if pos>1 then
			table.insert(arr, string.sub(str, 1, pos-1))
		end
		if last<#str then
			str =string.sub(str, last+1, -1)
		else
			return arr
		end
	end
end

local function insertHeros(tb, heros)
	local ret = str_split(heros, ',')
	if #ret == 0 then
		return
	end
	
	for k, v in ipairs(ret) do
		table.insert(tb, tonumber(v))
	end
end

local function getHerosStr(heros)
	local str 
	if not heros then
		return "" 
	end
	for _, uuid in ipairs(heros) do
		str = str and str .. "," .. tostring(uuid) or tostring(uuid)	
	end
	return str
end


local TeamPlayerNpcRewardPool = {}

local players = {}
local function loadPlayerData(pid)
	
	local success, results = database.query("select gid, pid, fight_id, npc_id, unix_timestamp(fight_time) as fight_time, unix_timestamp(valid_time) as valid_time, drop1, drop2, drop3, level1, level2, level3, heros from player_npc_reward_pool where pid = %d and unix_timestamp(valid_time) > %d", pid, loop.now())
	if not success then return end
	local tb = {
		pid = pid,
		pool = {}	
	}
	for _, row in ipairs(results) do
		tb.pool[row.gid] = {}	
		tb.pool[row.gid].gid      		= row.gid
		tb.pool[row.gid].pid            = row.pid
		tb.pool[row.gid].fight_id       = row.fight_id
		tb.pool[row.gid].npc_id      	= row.npc_id
		tb.pool[row.gid].fight_time     = row.fight_time
		tb.pool[row.gid].valid_time     = row.valid_time
		tb.pool[row.gid].drops          = {}
		tb.pool[row.gid].heros          = {}
		tb.pool[row.gid].db_exists        = true 
		insertDrops(tb.pool[row.gid].drops, {id = row.drop1, level = row.level1}, {id = row.drop2, level = row.level2}, {id = row.drop3, level = row.level3})
		insertHeros(tb.pool[row.gid].heros, row.heros)
	end
	return setmetatable(tb, {__index = TeamPlayerNpcRewardPool})
end

function TeamPlayerNpcRewardPool.Get(pid) 
	if not players[pid] then
		players[pid] = loadPlayerData(pid)
	end
	return players[pid]	
end

function TeamPlayerNpcRewardPool:DiscardStaleData()
	for k, v in pairs (self.pool) do
		if v.valid_time < loop.now() then
			self.pool[k] = nil
		end	
	end
end

function TeamPlayerNpcRewardPool:QueryReward(gid)
	self:DiscardStaleData()
	
	if gid then
		return self.pool[gid]
	else
		return self.pool
	end	
end

function TeamPlayerNpcRewardPool:AddReward(fight_id, npc_id, fight_time, valid_time, drop1, drop2, drop3, heros)
	self:DiscardStaleData()
	
	local heros_str = getHerosStr(heros)
	if database.update("insert into player_npc_reward_pool(pid, fight_id, npc_id, fight_time, valid_time, drop1, drop2, drop3, level1, level2, level3, heros) values(%d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), %d, %d, %d, %d, %d, %d, '%s')", self.pid, fight_id, npc_id, fight_time, valid_time, drop1.id, drop2.id, drop3.id, drop1.level, drop2.level, drop3.level, heros_str) then
		local gid = database.last_id()

		local xDrops = {}	
		local xHeros = {}
		insertDrops(xDrops, drop1, drop2, drop3)
		for k, v in ipairs(heros) do
			table.insert(xHeros, v)
		end

		self.pool[gid] = {gid = gid, pid = self.pid, fight_id = fight_id, npc_id = npc_id, fight_time = fight_time, valid_time = valid_time, drops = xDrops, heros = xHeros, db_exists = true}
		return true, gid
	else
		return false, nil
	end
end

function TeamPlayerNpcRewardPool:DrawReward(gid)
	--self:DiscardStaleData()
	log.debug(string.format("Player %d begin to draw npc reward for gid:%d", self.pid, gid))

	if not self.pool[gid] then
		log.debug("fail draw npc reward , hasnt this reward")
		return false, nil
	end

	if loop.now() > self.pool[gid].valid_time then
		self.pool[gid] = nil
		log.debug("fail draw npc reward , reward out of date")
		return false, nil
	end

	local npc_cfg = NpcConfig.GetNpc(self.pool[gid].npc_id)
	if not npc_cfg then
		log.debug("fail draw npc reward, npc config is nil for %d", self.pool[gid].npc_id)
		return false, nil
	end

	local roll_type = npc_cfg.npc_type or 1 

	local npc_roll = getNpcRoll(self.pid)	
	local pick_count = npc_roll:GetRollCount(roll_type)

	local fight_id = self.pool[gid].fight_id
	if not fight_id then
		log.debug("fail draw npc reward, cannt get fight")
		return false
	end

	local fight_cfg = BattleConfig.Get(fight_id)	
	if not fight_cfg then
		log.debug("fail draw npc reward, cannt get fight cfg for fight:", fight_id)
		return false
	end

	local battle_cfg = BattleConfig.GetBattleConfig(fight_cfg.battle_id)
	if not battle_cfg then
		log.debug("fail draw npc reward, cannt get battle cfg for battle:", fight_cfg.battle_id)
		return false
	end

	--consume 
	local consume = {{type = 41, id = 90023, value = 1}}
	if battle_cfg.difficult == 1 then
		consume = {{type = 41, id = 90023, value = 1}}
	elseif battle_cfg.difficult == 2 then
		consume = {{type = 41, id = 90024, value = 1}}
	end

	if not Exchange(self.pid, nil, consume, Command.REASON_EXTRA_ROLL) then
		log.debug("fail draw npc reward, lucky coin not enough")
		return false
	end

	--check pick count
	--if pick_count >= MONSTER_REWARD_MAX_COUNT_DAILY then
		--log.debug("fail draw npc reward, today count already reach max")
		--return false
	--else
		local success, err, rewards = SendDropReward(self.pid, nil, Command.REASON_TEAM_FIGHT_REWARD, self.pool[gid].drops, heros)
		log.debug(string.format("send drop reward, drop1:%d, drop2:%d , drop3:%d", self.pool[gid].drops[1] and self.pool[gid].drops[1].id or 0, self.pool[gid].drops[2] and self.pool[gid].drops[2].id or 0, self.pool[gid].drops[3] and self.pool[gid].drops[3].id or 0))
		if not success then
			log.debug(string.format("send npc reward fail erro:%d", err))
			return false
		end
		
		--update pick count
		npc_roll:UpdateRollCount(roll_type, pick_count + 1)

		self.pool[gid] = nil
		database.update("delete from player_npc_reward_pool where gid = %d", gid)

		return true , rewards 
	--end
end

function TeamPlayerNpcRewardPool.registerCommand(service)
	service:on(Command.C_TEAM_QUERY_NPC_REWARD_REQUEST, function(conn, pid, request)
		local sn = request[1];

		local npc_reward_pool = TeamPlayerNpcRewardPool.Get(pid)
		local reward_content = npc_reward_pool:QueryReward()
		local amf = {}
		for k, v in pairs(reward_content or {}) do
			table.insert(amf, {v.gid, v.fight_id, v.npc_id, v.valid_time})
		end
		return conn:sendClientRespond(Command.C_TEAM_QUERY_NPC_REWARD_RESPOND, pid, {sn, Command.RET_SUCCESS, amf});
	end);

	service:on(Command.C_TEAM_DRAW_NPC_REWARD_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local gid = request[2]
	
		if not gid then
			log.debug("fail draw npc reward, param 2nd gid is nil")
			return conn:sendClientRespond(Command.C_TEAM_DRAW_NPC_REWARD_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local npc_reward_pool = TeamPlayerNpcRewardPool.Get(pid)
		local ret, reward_content = npc_reward_pool:DrawReward(gid)
		return conn:sendClientRespond(Command.C_TEAM_DRAW_NPC_REWARD_RESPOND, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR, reward_content});
	end);
end

return TeamPlayerNpcRewardPool 
