local database = require "database"
local RankManager = require "RankManager"
local cell = require "cell"
local Agent = require "Agent"
local cell = require "cell"
local SocialManager = require "SocialManager"
local OpenlevConfig = require "OpenlevConfig" 
require "ArenaEnemyConfig"
local ArenaEnemyConfigManagerrequire = require "ArenaEnemyConfigManager"
require "PillageArenaRewardConfig"
require "Thread"
local util = require "util"
require "NetService"

local ArenaFightConfig = require "ArenaFightConfig"

local Time = require "Time"
local WEALTH_LEVEL_MIN = 1 
local WEALTH_LEVEL_MAX = 27
local AI_RANGE = 110000
local PVP_AI_RANGE = 100000
local DAILY_MAX_ATTACK_COUNT = 10

local PVP_SUCCESS_DROP_ID = 11000002 
local PVP_FAILED_DROP_ID = 11000003
local PVE_SUCCESS_DROP_ID = 11000000
local PVE_FAILED_DROP_ID = 11000001

math.randomseed(os.time())

SocialManager.Connect("Fight")

local player_online = {}
local PillageArena = {}

-- pvp匹配池
local match_pool = {
	wait_list = {},				-- 等待匹配的玩家
	fight_list = {},			-- 正在战斗中的玩家
	co = nil,	
}

local PveManager = { map = {} }

SocialManager.Connect("Fight")
local function encode(protocol, msg)
    local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
    if code == nil then
        print(string.format(" * encode %s failed", protocol));
        loop.exit();
        return nil;
    end
    return code;
end

-- static func
local function getRefreshTime(otime, now, at, loop)
    at = at or 0;           -- 默认0点重置
    loop = loop or Time.DSEC;   -- 默认每天重置

    local oday, osec = Time.ROUND(otime - at, loop);
    local cday, csec = Time.ROUND(now - at, loop);

    if oday < cday then
        return cday - oday, now - csec + loop
    elseif oday > cday then
        return false, otime - osec + loop;
    else
        return false, now - csec + loop;
    end
end

local OFFSET_TIME = 1498838399 -- 2017 06-30 23:59:59
local DURATION = 7 * 24 * 3600
local DAY_TIME = 24 * 3600
local REWARD_TIME = 22 * 3600 
function getCurrentPeriod(time)
	time = time or loop.now()

	return math.ceil((time - OFFSET_TIME) / DURATION)
end

local function getBeginTime(time)
	time = time or loop.now()

	return OFFSET_TIME + (getCurrentPeriod(time) - 1) * DURATION 
end

local function getEndTime(time)
	return getBeginTime(time) + DURATION
end

local function getEndTimeByPeriod(period)
	return OFFSET_TIME + period * DURATION
end

local function getSubPeriod(time)
	time = time or loop.now()

	local begin_time = getBeginTime()
	
	return math.ceil((time - begin_time) / DAY_TIME)
end

local function rewardTime()
	local time = loop.now()
	local day = math.ceil((time - getBeginTime(time)) / DAY_TIME)

	return (time - getBeginTime(time) - (day - 1) * DAY_TIME) > REWARD_TIME 
end

local function finalDay()
	local time = loop.now()
	local total_day = math.floor(DURATION / DAY_TIME)
	local day = math.ceil((time - getBeginTime(time)) / DAY_TIME)
	
	return day >= total_day
end

local function sameDay(t1, t2)
	local time = t2 or loop.now()
	local day = math.ceil((t1 - getBeginTime()) / DAY_TIME)
	local cday = math.ceil((time - getBeginTime()) / DAY_TIME)

	return day == cday
end

local function alreadyDrawReward(reward_time, t)
	local time = t or loop.now()
    local oday, osec = Time.ROUND(reward_time - REWARD_TIME, DAY_TIME);
    local cday, csec = Time.ROUND(time - REWARD_TIME, DAY_TIME);
	
	return oday == cday 
end

local rule_cfg = {
	poor = {
		{win_rate_lower = 80, win_rate_upper = 101, rate_list = {20, 10, 60, 10,  0,  0}},
		{win_rate_lower = 60, win_rate_upper =  80, rate_list = {10, 20, 50, 20,  0,  0}},
		{win_rate_lower = 40, win_rate_upper =  60, rate_list = { 0, 20, 50, 20, 10,  0}},
		{win_rate_lower =  0, win_rate_upper =  40, rate_list = { 0, 10, 40, 30, 10, 10}},
	},
	rich = {
		{win_rate_lower = 80, win_rate_upper = 101, rate_list = {20,  0, 20, 10, 30, 30}},
		{win_rate_lower = 60, win_rate_upper =  80, rate_list = {10,  0, 20,  0, 30, 40}},
		{win_rate_lower = 40, win_rate_upper =  60, rate_list = { 0,  0, 30,  0, 20, 50}},
		{win_rate_lower =  0, win_rate_upper =  40, rate_list = { 0,  0, 20,  0, 20, 60}},
	}
}

local function getLevel(wealth)
	if wealth < 2000000 then
		return 1
	end

	if wealth >= 2000000 and wealth < 10000000 then
		return math.floor(wealth / 1000000) 
	end

	if wealth >= 10000000 and wealth < 100000000 then
		return 9 + math.floor(wealth / 10000000)
	end

	if wealth >= 100000000 then
		return 18 + math.floor(wealth / 100000000)
	end

	return WEALTH_LEVEL_MAX
end

--[[	
	找到一个在等级lv范围range内的玩家
--]]
local function find_player(list, lv, range, except)
	local t = {}

	for _, v in ipairs(list or {}) do
		if v.pid ~= except and OpenlevConfig.abs(lv - v.lv) <= range then
			table.insert(t, v)
		end
	end	
		
	if #t == 0 then
		return nil
	end
		
	local i = math.random(#t)		
	t[i].valid = false
	
	return t[i].pid
end

--[[ 
	找到一个等级lv范围range内的ai玩家
--]]
local function find_ai_player(list, lv, range)
	local t = {}

	for _, v in ipairs(list or {}) do
		local ai_lv = OpenlevConfig.get_level(v.pid)
		if OpenlevConfig.abs(lv - ai_lv) <= range and not match_pool.is_fight(v.pid) then
			table.insert(t, v.pid)
		end
	end

	if #t == 0 then
		return nil
	end
	
	local i = math.random(#t)

	return t[i]
end

local function find_fake_player(list, lv, range)
	local t = {}

	for _, v in ipairs(list or {}) do
		local info = ArenaEnemyConfigManager.getEnemyInfoByPid(v.pid)
		if info and OpenlevConfig.abs(lv - info.level) <= range then
			table.insert(t, v.pid)
		end
	end

	if #t == 0 then
		return nil
	end
		
	local i = math.random(#t)
	local pillage_arena = PillageArena.Get(getCurrentPeriod())
	if pillage_arena then
		pillage_arena:BalanceWealth(t[i])
	end

	return t[i]
end

local function getTargetLevel(wealth, win_rate)
	local level = getLevel(wealth)

	log.debug("getTargetLevel: wealth, win_rate, level ", wealth, win_rate, level)

	local key

	local cfg
	if level < 19 then
		cfg = rule_cfg.poor		
	else
		cfg = rule_cfg.rich
	end 

	for k, v in ipairs(cfg) do
		if win_rate >= v.win_rate_lower and win_rate < v.win_rate_upper then
			cfg = v.rate_list
			break
		end	
	end

	local rand_num = math.random(1, 100)
	for k, v in ipairs(cfg) do
		if rand_num <= v then
			key = k	
			break
		else
			rand_num = rand_num - v
		end	
	end
	
	log.debug("getTargetLevel: key = ", key)

	if key == 1 then
		return math.min(level + 1, WEALTH_LEVEL_MAX), false
	elseif key == 2 then
		return math.min(level + 1, WEALTH_LEVEL_MAX), true 
	elseif key == 3 then
		return level, false
	elseif key == 4 then
		return level, true
	elseif key == 5 then
		return math.max(level - 1, WEALTH_LEVEL_MIN), false
	else
		return math.max(level - 1, WEALTH_LEVEL_MIN), true
	end
end

local function checkPlayerOwnHero(pid, uuid)
	local playerHeroInfo = cell.getPlayerHeroInfo(pid, 0, uuid)	
	if not playerHeroInfo then
		yqinfo("player %d donnt own hero :%d", pid, uuid)	
		return true--false
	else
		return true
	end
end

local function serialize(obj)  
    local lua = ""  
    local t = type(obj)  
    if t == "number" then  
        lua = lua .. obj  
    elseif t == "boolean" then  
        lua = lua .. tostring(obj)  
    elseif t == "string" then  
        lua = lua .. string.format("%q", obj)  
    elseif t == "table" then  
        lua = lua .. "{\n"  
    for k, v in pairs(obj) do  
        lua = lua .. "[" .. serialize(k) .. "]=" .. serialize(v) .. ",\n"  
    end  
    local metatable = getmetatable(obj)  
        if metatable ~= nil and type(metatable.__index) == "table" then  
        for k, v in pairs(metatable.__index) do  
            lua = lua .. "[" .. serialize(k) .. "]=" .. serialize(v) .. ",\n"  
        end  
    end  
        lua = lua .. "}"  
    elseif t == "nil" then  
        return nil  
    else  
        error("can not serialize a " .. t .. " type.")  
    end  
    return lua  
end  
  
local function unserialize(lua)  
    local t = type(lua)  
    if t == "nil" or lua == "" then  
        return nil  
    elseif t == "number" or t == "string" or t == "boolean" then  
        lua = tostring(lua)  
    else  
        error("can not unserialize a " .. t .. " type.")  
    end  
    lua = "return " .. lua  
    local func = loadstring(lua)  
    if func == nil then  
        return nil  
    end  
    return func()  
end  

local function DOReward(pid, reward, consume, reason, manual, limit, name)
	assert(reason and reason ~= 0)

	local respond = cell.sendReward(pid, reward, consume, reason, manual, limit, name)
	if respond == nil or respond.result ~= 0 then
		return false;
	end
	return true;
end

--log
local MAX_LOG_COUNT = 100 
local ArenaLog = {}
function ArenaLog.New(pid, period)
	local t = {pid = pid, period = period, logs = {}, log_count = 0, max_index = 0}	

	local success, result = database.query("select pid, period, `index`, attacker, defender, wealth_change, extra_wealth from pillage_arena_player_log where pid = %d and period = %d ORDER BY `index` DESC LIMIT %d", pid, period, MAX_LOG_COUNT)
	if success then
		for _, row in ipairs(result) do
			local log = {attacker = row.attacker, defender = row.defender, wealth_change = row.wealth_change, extra_wealth = row.extra_wealth, index = row.index}	
			t.log_count = t.log_count + 1
			if row.index > t.max_index then
				t.max_index = row.index
			end
			table.insert(t.logs, 1, log)
		end
	end

	return setmetatable(t, {__index = ArenaLog})	
end

function ArenaLog:AddLog(attacker, defender, wealth_change, extra_wealth)
	extra_wealth = extra_wealth or 0
	if self.log_count == MAX_LOG_COUNT then
		table.remove(self.logs, 1)
		table.insert(self.logs, {attacker = attacker, defender = defender, wealth_change = wealth_change, extra_wealth = extra_wealth, index = self.max_index + 1})
		self.max_index = self.max_index + 1
	else
		table.insert(self.logs, {attacker = attacker, defender = defender, wealth_change = wealth_change, extra_wealth = extra_wealth, index = self.max_index + 1})
		self.log_count = self.log_count + 1
		self.max_index = self.max_index + 1
	end

	database.update("insert into pillage_arena_player_log(pid, period, `index`, attacker, defender, wealth_change, extra_wealth) values(%d, %d, %d, %d, %d, %d, %d)", self.pid, self.period, self.max_index, attacker, defender, wealth_change, extra_wealth)

	self:Notify(Command.NOTIFY_ARENA_LOG_CHANGE, {attacker, defender, wealth_change, extra_wealth})
end

function ArenaLog:Notify(cmd, msg)
	local agent = Agent.Get(self.pid);
	if agent then
		agent:Notify({cmd, msg});
	end
end

function ArenaLog:GetLog()
	local ret = {} 

	for k, v in ipairs(self.logs) do
		table.insert(ret, {v.attacker, v.defender, v.wealth_change, v.extra_wealth})		
	end

	return ret
end

local playerArenaLog = {}
function ArenaLog.Get(period, pid)
	if not playerArenaLog[period] then
		playerArenaLog[period] = {}
	end

	if not playerArenaLog[period][pid] then
		playerArenaLog[period][pid] = ArenaLog.New(pid, period)
	end

	return playerArenaLog[period][pid]
end

function ArenaLog.Clear(period) 
	if playerArenaLog[period] then
		playerArenaLog[period] = nil
	end 
end

local ArenaFormation = {}
function ArenaFormation.New(pid)
	local t = {
		pid = pid, 
		attack_formation = { -1, -1, -1, -1, -1 },
		defend_formation = { -1, -1, -1, -1, -1 },
		attack_fight_data = nil,
		defend_fight_data = nil,
		attack_data_change = true,
		defend_data_change = true,
		last_ref_time = 0,		-- 上一次攻击数据刷新的时间
		is_ai = pid > PVP_AI_RANGE and pid < AI_RANGE,
		db_exists = false,
	}

	if not t.is_ai then
		local success, result = database.query([[select pid, attack_role1, attack_role2, attack_role3, attack_role4, attack_role5, 
			defend_role1, defend_role2, defend_role3, defend_role4, defend_role5 from pillage_arena_player_formation where pid = %d]], pid)
		if success then
			for _, row in ipairs(result) do
				t.attack_formation = {
					row.attack_role1,
					row.attack_role2,
					row.attack_role3,
					row.attack_role4,
					row.attack_role5,
				}
				t.defend_formation = {
					row.defend_role1,	
					row.defend_role2,	
					row.defend_role3,	
					row.defend_role4,	
					row.defend_role5,	
				}				

				t.db_exists = true
			end
		end
	end

	return setmetatable(t, {__index = ArenaFormation})
end

function ArenaFormation:all_roles(t)
	for i, v in ipairs(t) do
		if v == -1 then
			return true
		end
	end

	return false
end

local CD = 2 * 60
function ArenaFormation:GetAttackFightData()
	if self.is_ai then 
		if self.attack_fight_data == nil then
			local fight_data, err = cell.QueryPlayerFightInfo(self.pid, true, 0)
			if err then
				log.debug(string.format('get attack fight data of player %d(ai) error %s', self.pid, err))
				return 
			end

			self.attack_fight_data = fight_data
		end

		return self.attack_fight_data
	else
		if self.attack_fight_data == nil or self.attack_data_change or self.last_ref_time + CD < loop.now() then
			local formation = nil
			if not self:all_roles(self.attack_formation) then -- 是否需要查询所有的角色
				formation = self.attack_formation
			end
				
			local fight_data, err = cell.QueryPlayerFightInfo(self.pid, false, 0, formation)
			if err then
				log.debug(string.format('get attack fight data of player %d error %s', self.pid, err))
				return 
			end

			for i, v in ipairs(fight_data.roles) do
				self.attack_formation[v.pos] = v.uuid
			end
			for i = 1, 5 do
				if self.attack_formation[i] == -1 then
					self.attack_formation[i] = 0
				end
			end 

			self.attack_fight_data = fight_data
			self.attack_data_change = false
			self.last_ref_time = loop.now()
		end

		return self.attack_fight_data
	end	
end

function ArenaFormation:GetDefendFightData()
	if self.is_ai then 
		if self.defend_fight_data == nil then
			local fight_data, err = cell.QueryPlayerFightInfo(self.pid, true, 100)
			if err then
				log.debug(string.format('get defend fight data of player %d(ai) error %s', self.pid, err))
				return 
			end
	
			self.defend_fight_data = fight_data
		end

		return self.defend_fight_data
	else
		if self.defend_fight_data == nil or self.defend_data_change then
			local formation = nil
			if not self:all_roles(self.defend_formation) then
				formation = self.defend_formation
			end

			local fight_data, err = cell.QueryPlayerFightInfo(self.pid, false, 100, formation)
			if err then
				log.debug(string.format('get defend fight data of player %d error %s', self.pid, err))
				return 
			end
	
			for i, v in ipairs(fight_data.roles) do
				self.defend_formation[v.pos] = v.uuid
			end	
			for i = 1, 5 do
				if self.defend_formation[i] == -1 then
					self.defend_formation[i] = 0
				end
			end 

			self.defend_fight_data = fight_data
			self.defend_data_change = false
		end

		return self.defend_fight_data
	end
end

function ArenaFormation:QueryFormation(type)
	log.debug(string.format("Player %d begin to query arena formation for ", self.pid)..(type == 1 and "attack" or "defend"))

	if type == 1 then	
		local fight_data = self:GetAttackFightData()
		local code = encode('FightPlayer', fight_data)
		return { self.attack_formation, code }
	elseif type == 2 then
		local defender_data = self:GetDefendFightData()
		local code = encode('FightPlayer', defender_data)
		return { self.defend_formation, code } 	
	elseif type == 3 then
		local info1 = self:QueryFormation(1)	
		local info2 = self:QueryFormation(2)
	
		return { info1, info2 }
	end	
end

function ArenaFormation:ChangeFormation(type, role1, role2, role3, role4, role5)
	log.debug(string.format("Player %d begin to change arena formation for ", self.pid)..(type == 1 and "attack" or "defend")..string.format("%d, %d, %d, %d, %d", role1, role2, role3, role4, role5))
	
	local hero_count = 0

	if role1 ~= 0 then
		hero_count = hero_count + 1
		if not checkPlayerOwnHero(self.pid, role1) then
			return false
		end
	end

	if role2 ~= 0 then
		hero_count = hero_count + 1
		if not checkPlayerOwnHero(self.pid, role2) then
			return false
		end
	end

	if role3 ~= 0 then
		hero_count = hero_count + 1
		if not checkPlayerOwnHero(self.pid, role3) then
			return false
		end
	end

	if role4 ~= 0 then
		hero_count = hero_count + 1
		if not checkPlayerOwnHero(self.pid, role4) then
			return false
		end
	end

	if role5 ~= 0 then
		hero_count = hero_count + 1
		if not checkPlayerOwnHero(self.pid, role5) then
			return false
		end
	end

	if hero_count == 0 then
		log.debug("role count should not be 0")
		return false
	end

	if type == 1 then
		self.attack_formation[1] = role1
		self.attack_formation[2] = role2
		self.attack_formation[3] = role3
		self.attack_formation[4] = role4
		self.attack_formation[5] = role5
		self.attack_data_change = true
	else
		self.defend_formation[1] = role1
		self.defend_formation[2] = role2
		self.defend_formation[3] = role3
		self.defend_formation[4] = role4
		self.defend_formation[5] = role5
		self.defend_data_change = true
	end

	if self.db_exists then
		if type == 1 then
			database.update("update pillage_arena_player_formation set attack_role1 = %d, attack_role2 = %d, attack_role3 = %d, attack_role4 = %d, attack_role5 = %d where pid = %d", 
				role1, role2, role3, role4, role5, self.pid)
		else
			database.update("update pillage_arena_player_formation set defend_role1 = %d, defend_role2 = %d, defend_role3 = %d, defend_role4 = %d, defend_role5 = %d where pid = %d", 
				role1, role2, role3, role4, role5, self.pid)
		end
	else
		if type == 1 then
			database.update([[insert into pillage_arena_player_formation (pid, attack_role1, attack_role2, attack_role3, attack_role4, attack_role5, 
				defend_role1, defend_role2, defend_role3, defend_role4, defend_role5) values(%d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d)]], 
				self.pid, role1, role2, role3, role4, role5, -1, -1, -1, -1, -1)		
		else
			database.update([[insert into pillage_arena_player_formation (pid, attack_role1, attack_role2, attack_role3, attack_role4, attack_role5, 
				defend_role1, defend_role2, defend_role3, defend_role4, defend_role5) values(%d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d)]], 
				self.pid, -1, -1, -1, -1, -1, role1, role2, role3, role4, role5)
		end
		self.db_exists = true
	end

	return true
end

local playerArenaFormation = {}
function ArenaFormation.Get(pid)
	if not playerArenaFormation[pid] then
		playerArenaFormation[pid] = ArenaFormation.New(pid)
	end
	
	return playerArenaFormation[pid]
end

-- pillage_arena reward settle status
local reward_settle_status = {}
local function finishRewardSettle(period, sub_period)
	return reward_settle_status[period] and reward_settle_status[period][sub_period] or nil
end

local function setRewardSettleFinish(period, sub_period)
	reward_settle_status[period] = reward_settle_status[period] or {} 
	reward_settle_status[period][sub_period] = true
	database.update("insert into pillage_arena_reward_settle_status (period, sub_period, finish) values(%d, %d, %d)", period, sub_period, 1)
end

local function load_reward_settle_status() 
	local success, result = database.query("select period, sub_period , finish from pillage_arena_reward_settle_status")
	if success then
		for _, row in ipairs(result) do
			reward_settle_status[row.period] = reward_settle_status[row.period] or {}
			reward_settle_status[row.period][row.sub_period] = true
		end
	end
end

load_reward_settle_status()

local function get_ai_wealth(level)
	local base = 1000000
	local base2 = 10000000
	if level == 1 then
		return math.random(base, 2 * base - 1)
	elseif level >= 2 and level <= 9 then
		return math.random(level * base, (level + 1) * base - 1)
	elseif level >= 10 and level <= 18 then
		return math.random((level - 9) * base2, (level - 8) * base2 - 1)
	else 
		return math.random(100000000 * (level - 18) , 100000000 * (level - 17) - 1)
	end
end

local function get_random_ai_level()
	local rate = {	8, 
			7, 7, 7, 7, 7, 7, 7, 7, 
			3, 3, 3, 3, 3, 3, 3, 3, 3, 
			1, 1, 1, 1, 1, 1, 1, 1, 1 }
	local n = math.random(100)
	for i, v in ipairs(rate) do
		if n <= v then
			return i
		else		
			n = n - v 
		end 
	end	
	 
	return 1
end

local function InsertArene(info)
	local ok = database.update([[insert into pillage_arena_player_pool(pid, period, wealth, win_count, fight_count, defend_win_count, defend_fight_count, today_win_streak_count, 
		win_streak_update_time, update_time, reward_time, compensation_count, depot, today_attack_count, attack_time, xwealth, xwealth_time, match_count, match_time, pvp_win_count, 
		pvp_const_win_count, pvp_fight_count, const_win_count) values(%d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), %d, '%s', %d, 
		from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, %d, %d, %d)]], 
		info.pid, info.period, info.wealth, info.win_count, info.fight_count, info.defend_win_count, info.defend_fight_count, info.today_win_streak_count, info.win_streak_update_time, 
		info.update_time, info.reward_time, info.compensation_count, serialize(info.depot), info.today_attack_count, info.attack_time, info.xwealth, info.xwealth_time, info.match_count, 
		info.match_time, info.pvp_win_count, info.pvp_const_win_count, info.pvp_fight_count, info.const_win_count)

	return ok
end

-- pillage arena
local function loadAI(t1, t2, t3, period)
	local enemy_list = ArenaEnemyConfigManager.getAllEnemy() or {}

	for i, v in ipairs(enemy_list) do
		local info = {
			pid = v.pid,
			period = period,
			wealth = 0,
			win_count = 0,
			fight_count = 0,
			defend_win_count = 0,
			defend_fight_count = 0,
			today_win_streak_count = 0,
			win_streak_update_time = 0,
			update_time = OFFSET_TIME + (period -1) * DURATION + 1, 
			reward_time = 0,
			compensation_count = 0,
			depot = {},
			today_attack_count = 0,
			attack_time = 0,
			xwealth = 0,
			xwealth_time = loop.now(),
			match_count = 0,
			match_time = 0,
			pvp_win_count = 0,
			pvp_const_win_count = 0,
			pvp_fight_count = 0,
			const_win_count = 0,
			db_exist = false,
		}
		local level = get_random_ai_level()
		local wealth = get_ai_wealth(level) 
		info.wealth = wealth

		t1[level][info.pid] = info
		t3[info.pid] = info
	end
end

function PillageArena:loadPvpAI(id)
	if type(id) ~= "number" then
		log.warning("loadPvpAI: id is not a number.")
		return
	end

	local period = getCurrentPeriod()	
	local wealth = 1000000
	local level = getLevel(wealth)
	local info = {
		pid = id,
		period = period,
		wealth = wealth,
		win_count = 0,
		fight_count = 0,
		defend_win_count = 0,
		defend_fight_count = 0,
		today_win_streak_count = 0,
		win_streak_update_time = 0,
		update_time = OFFSET_TIME + (period -1) * DURATION + 1, 
		reward_time = 0,
		compensation_count = 0,
		depot = {},
		today_attack_count = 0,
		attack_time = 0,
		xwealth = 0,
		xwealth_time = loop.now(),
		match_count = 0,
		match_time = 0,
		pvp_win_count = 0,
		pvp_const_win_count = 0,
		pvp_fight_count = 0,
		const_win_count = 0,
		db_exist = false,
	}
		
	if self.ai_pool[level][info.pid] == nil then
		self.ai_pool[level][info.pid] = info
		self.rank:setValue(info.pid, info.wealth, info.update_time)
		self.map[info.pid] = info
	end
end

function PillageArena.New(period)
	local t = {period = period, player_pool = {}, ai_pool = {}, map = {}, rank = RankManager.New()}

	for i = 1, WEALTH_LEVEL_MAX, 1 do
		table.insert(t.player_pool, {})
		table.insert(t.ai_pool, {})
	end

	-- load ai
	loadAI(t.ai_pool, t.rank, t.map, period)

	-- load player
	local success, result = database.query("select pid, period, wealth, win_count, fight_count, defend_win_count, defend_fight_count, today_win_streak_count, unix_timestamp(win_streak_update_time) as win_streak_update_time, unix_timestamp(update_time) as update_time, unix_timestamp(reward_time) as reward_time, compensation_count, depot, today_attack_count, unix_timestamp(attack_time) as attack_time,xwealth, unix_timestamp(xwealth_time) as xwealth_time, match_count, unix_timestamp(match_time) as match_time, pvp_win_count, pvp_const_win_count, pvp_fight_count, const_win_count from pillage_arena_player_pool where period = %d ORDER BY wealth DESC, update_time ASC", period)
	
	local max_level = 200			
	local res = cell.getServerInfo()
	if res then
		max_level = res.max_level
	end
	if success then
		for _, row in ipairs(result or {}) do
			local level = getLevel(row.wealth)
			if row.pid > AI_RANGE then
				local info = {
					pid = row.pid,
					period = row.period,
					wealth = row.wealth,
					win_count = row.win_count,
					fight_count = row.fight_count,
					defend_win_count = row.defend_win_count,
					defend_fight_count = row.defend_fight_count,
					today_win_streak_count = row.today_win_streak_count,
					win_streak_update_time = row.win_streak_update_time,
					update_time = row.update_time,
					reward_time = row.reward_time,
					compensation_count = row.compensation_count,
					depot = unserialize(row.depot),
					today_attack_count = row.today_attack_count,
					attack_time = row.attack_time,
					xwealth = row.xwealth,
					xwealth_time = row.xwealth_time,
					match_count = row.match_count,
					match_time = row.match_time,				
					pvp_win_count = row.pvp_win_count,
					pvp_const_win_count = row.pvp_const_win_count,
					pvp_fight_count = row.pvp_fight_count,
					const_win_count = row.const_win_count,
					db_exists = true
				}
				t.player_pool[level][row.pid] = info
				t.map[row.pid] = info
				t.rank:setValue(info.pid, info.wealth, info.update_time)	
			else	
				if not t.ai_pool[1][row.pid] then
					t.ai_pool[1][row.pid] = {pid = row.pid}
					t.map[row.pid] = t.ai_pool[1][row.pid] 
				end

				t.ai_pool[1][row.pid].period = row.period
				t.ai_pool[1][row.pid].wealth = row.wealth
				t.ai_pool[1][row.pid].win_count = row.win_count
				t.ai_pool[1][row.pid].fight_count = row.fight_count
				t.ai_pool[1][row.pid].defend_win_count = row.defend_win_count
				t.ai_pool[1][row.pid].defend_fight_count = row.defend_fight_count
				t.ai_pool[1][row.pid].today_win_streak_count = row.today_win_streak_count
				t.ai_pool[1][row.pid].win_streak_update_time = row.win_streak_update_time
				t.ai_pool[1][row.pid].update_time = row.update_time
				t.ai_pool[1][row.pid].reward_time = row.reward_time
				t.ai_pool[1][row.pid].compensation_count = row.compensation_count
				t.ai_pool[1][row.pid].depot = unserialize(row.depot)
				t.ai_pool[1][row.pid].today_attack_count = row.today_attack_count 
				t.ai_pool[1][row.pid].attack_time = row.attack_time 
				t.ai_pool[1][row.pid].xwealth = row.xwealth 
				t.ai_pool[1][row.pid].xwealth_time = row.xwealth_time 
				t.ai_pool[1][row.pid].match_count = row.match_count
				t.ai_pool[1][row.pid].match_time = row.match_time
				t.ai_pool[1][row.pid].pvp_win_count = row.pvp_win_count
				t.ai_pool[1][row.pid].pvp_const_win_count = row.pvp_const_win_count
				t.ai_pool[1][row.pid].pvp_fight_count = row.pvp_fight_count
				t.ai_pool[1][row.pid].const_win_count = row.const_win_count
				t.ai_pool[1][row.pid].db_exists = true 

				if level > 1 then
					t.ai_pool[level][row.pid] = t.ai_pool[1][row.pid]	
					t.map[row.pid] = t.ai_pool[level][row.pid]	
					t.ai_pool[1][row.pid] = nil
		
				end
				if row.pid < PVP_AI_RANGE then
					t.rank:setValue(row.pid, row.wealth, row.update_time)
				elseif row.pid > 109000 and row.pid < AI_RANGE then
					local enemy = ArenaEnemyConfigManager.getEnemyInfoByPid(row.pid)
					if enemy then
						enemy.level = math.floor(max_level * 0.8)	-- 记录等级
					end
					t.map[row.pid].is_game_role = true
					t.rank:setValue(row.pid, row.wealth, row.update_time)
				end
			end	
		end

		if #result == 0 and period ~= getCurrentPeriod() then
			t.ai_pool = {}
			for i = 1, WEALTH_LEVEL_MAX, 1 do
				table.insert(t.ai_pool, {})
			end
			t.rank:ClearRank()
		end

		-- 加载游戏角色
		local role_list = ArenaEnemyConfigManager.get_main_role_list()
		for _, v in ipairs(role_list) do
			if not t.map[v.pid] then
				local info = {
					pid = v.pid,
					period = period,
					wealth = 0,
					win_count = 0,
					fight_count = 0,
					defend_win_count = 0,
					defend_fight_count = 0,
					today_win_streak_count = 0,
					win_streak_update_time = 0,
					update_time = OFFSET_TIME + (period -1) * DURATION + 1, 
					reward_time = 0,
					compensation_count = 0,
					depot = {},
					today_attack_count = 0,
					attack_time = 0,
					xwealth = 0,
					xwealth_time = loop.now(),
					match_count = 0,
					match_time = 0,
					pvp_win_count = 0,
					pvp_const_win_count = 0,
					pvp_fight_count = 0,
					const_win_count = 0,
					db_exist = false,
				}
				local level = getLevel(v.wealth)
				info.wealth = v.wealth
				info.is_game_role = true	-- 标记为漫画中的人物
				if InsertArene(info) then
					info.db_exist = true
				end
				t.rank:setValue(info.pid, info.wealth, info.update_time)
				t.map[v.pid] = info
				t.ai_pool[level][v.pid] = info
				v.level = math.floor(max_level * 0.8)	-- 记录等级
			end
		end
	end

	return setmetatable(t, {__index = PillageArena})
end

function PillageArena:SetWealth(pid, wealth)
	if self.period ~= getCurrentPeriod() then
		return false
	end

	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end

	if wealth == self.map[pid].wealth then return end

	local nxwealth, nxwealth_time = self:GetXWealth(pid)
	if nxwealth then
		self.map[pid].nxwealth = nxwealth
		self.map[pid].nxwealth_time = nxwealth_time
	end

	local level = getLevel(wealth)
	local old_level = getLevel(self.map[pid].wealth)
	local now = loop.now()

	log.debug("SetWealth: level, old_level, pid ", level, old_level, pid)

	if level ~= old_level then
		if pid > AI_RANGE then
			self.player_pool[level][pid] = self.player_pool[old_level][pid]	
			self.player_pool[level][pid].wealth = wealth
			self.player_pool[level][pid].update_time = now 
			self.player_pool[old_level][pid] = nil 
		else
			self.ai_pool[level][pid] = self.ai_pool[old_level][pid]	
			self.ai_pool[level][pid].wealth = wealth
			self.ai_pool[level][pid].update_time = now 
			self.ai_pool[old_level][pid] = nil
		end		
	else
		if pid > AI_RANGE then
			self.player_pool[level][pid].wealth = wealth
			self.player_pool[level][pid].update_time = now 
		else
			self.ai_pool[level][pid].wealth = wealth 
			self.ai_pool[level][pid].update_time = now 
		end
	end

	local event_list = {}
	if pid > AI_RANGE or pid < PVP_AI_RANGE or self.map[pid].is_game_role then
		local old_rank = self.rank:getRank(pid)
		local new_rank = self.rank:setValue(pid, wealth, now)
		if new_rank then
			table.insert(event_list, {type = 73, id = 9, count = new_rank})
			-- 进入前10名，全服广播
			if old_rank > 10 and new_rank <= 10 then
				local name = pid
				if pid > AI_RANGE or pid < PVP_AI_RANGE then
					local player = cell.getPlayerInfo(pid)
					if player then
						name = player.name
					end
				elseif self.map[pid].is_game_role then
					local player = ArenaEnemyConfigManager.getEnemyInfoByPid(pid)
					if player then
						name = player.name
					end
				end
				NetService.NotifyClients(Command.NOTIFY_DISPLAY_MESSAGE, { 14, name, new_rank })
			end
		end
	end
	
	if self.map[pid].db_exists then
		database.update("update pillage_arena_player_pool set wealth = %d, update_time = from_unixtime_s(%d), xwealth = %d, xwealth_time = from_unixtime_s(%d) where pid = %d and period = %d ", wealth, now, nxwealth, nxwealth_time, pid, self.period)   --select pid, period, wealth, win_count, fight_count, unix_timestamp(update_time) as update_time from pillage_arena_player_pool where period = %d
		else
		database.update("insert into pillage_arena_player_pool(pid, period, wealth, win_count, fight_count, defend_win_count, defend_fight_count, today_win_streak_count, win_streak_update_time, update_time, reward_time, compensation_count, depot, today_attack_count, attack_time, xwealth, xwealth_time, match_count, match_time, pvp_win_count, pvp_const_win_count, pvp_fight_count, const_win_count) values(%d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), %d, '%s', %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, %d, %d, %d)", pid, self.period, wealth, self.map[pid].win_count, self.map[pid].fight_count, self.map[pid].defend_win_count, self.map[pid].defend_fight_count, self.map[pid].today_win_streak_count, self.map[pid].win_streak_update_time, self.map[pid].update_time, self.map[pid].reward_time, self.map[pid].compensation_count, serialize(self.map[pid].depot), self.map[pid].today_attack_count, self.map[pid].attack_time, self.map[pid].xwealth, self.map[pid].xwealth_time, self.map[pid].match_count, self.map[pid].match_time, self.map[pid].pvp_win_count, self.map[pid].pvp_const_win_count, self.map[pid].pvp_fight_count, self.map[pid].const_win_count)
		self.map[pid].db_exists = true
	end

	table.insert(event_list, {type = 73, id = 4, count = wealth})
	--cell.NotifyQuestEvent(pid, {{type = 73, id = 4, count = wealth}})
	cell.NotifyQuestEvent(pid, event_list)
	return true
end

function PillageArena:GetWealth(pid)
	if self.period ~= getCurrentPeriod() then
		return false
	end

	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end

	return self.map[pid].wealth
end

function PillageArena:GetXWealth(pid, t)
	if not self.map[pid] then
		return false
	end

	local round = DAY_TIME
	local refresh_time = REWARD_TIME

	local time = t or loop.now()

    -- 查看昨日排名是否过期 
    local refreshed = getRefreshTime(self.map[pid].xwealth_time, time, refresh_time, round);
	if not refreshed then
        return self.map[pid].xwealth, self.map[pid].xwealth_time
    end

    -- 过期了
    return self.map[pid].wealth, loop.now() 
end

function PillageArena:UpdateAttackFightResult(pid, is_win)
	if self.period ~= getCurrentPeriod() then
		return false
	end

	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end

	if is_win == 1 then
		self.map[pid].win_count = self.map[pid].win_count + 1
		
		-- 连胜次数	
		 local old_win_streak_count = self:GetTodayWinStreakCount(pid)
		 self.map[pid].today_win_streak_count = old_win_streak_count + 1
		 self.map[pid].const_win_count = self.map[pid].const_win_count + 1 
	else
		 self.map[pid].today_win_streak_count = 0
		 self.map[pid].const_win_count = 0
	end	

	-- quests
	local quests = {}
	table.insert(quests, { type = 73, id = 7, count = self.map[pid].today_win_streak_count })
	table.insert(quests, { type = 73, id = 6, count = self.map[pid].const_win_count })
	cell.NotifyQuestEvent(pid, quests)

	self.map[pid].win_streak_update_time = loop.now()	
	self.map[pid].fight_count = self.map[pid].fight_count + 1

	if self.map[pid].db_exists then
		database.update("update pillage_arena_player_pool set win_count = %d, fight_count = %d, today_win_streak_count = %d, win_streak_update_time = from_unixtime_s(%d), const_win_count = %d where pid = %d and period = %d", self.map[pid].win_count , self.map[pid].fight_count, self.map[pid].today_win_streak_count, self.map[pid].win_streak_update_time, self.map[pid].const_win_count, pid, self.period)
	else
		database.update("insert into pillage_arena_player_pool(pid, period, wealth, win_count, fight_count, defend_win_count, defend_fight_count, today_win_streak_count, win_streak_update_time, update_time, reward_time, compensation_count, depot, today_attack_count, attack_time, xwealth, xwealth_time, match_count, match_time, pvp_win_count, pvp_const_win_count, pvp_fight_count, const_win_count) values(%d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), %d, '%s', %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, %d, %d, %d)", pid, self.period, self.map[pid].wealth, self.map[pid].win_count, self.map[pid].fight_count, self.map[pid].defend_win_count, self.map[pid].defend_fight_count, self.map[pid].today_win_streak_count, self.map[pid].win_streak_update_time, self.map[pid].update_time, self.map[pid].reward_time, self.map[pid].compensation_count, serialize(self.map[pid].depot), self.map[pid].today_attack_count, self.map[pid].attack_time, self.map[pid].xwealth, self.map[pid].xwealth_time, self.map[pid].match_count, self.map[pid].match_time,self.map[pid].pvp_win_count, self.map[pid].pvp_const_win_count, self.map[pid].pvp_fight_count, self.map[pid].const_win_count)
		self.map[pid].db_exists = true
	end

	return true
end

function PillageArena:UpdateDefendFightResult(pid, is_win)
	if self.period ~= getCurrentPeriod() then
		return false
	end

	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end

	if is_win == 1 then
		self.map[pid].defend_win_count = self.map[pid].defend_win_count + 1
	end	

	self.map[pid].defend_fight_count = self.map[pid].defend_fight_count + 1

	if self.map[pid].db_exists then
		database.update("update pillage_arena_player_pool set defend_win_count = %d, defend_fight_count = %d where pid = %d and period = %d", self.map[pid].defend_win_count , self.map[pid].defend_fight_count, pid, self.period)
	else
		database.update("insert into pillage_arena_player_pool(pid, period, wealth, win_count, fight_count, defend_win_count, defend_fight_count, today_win_streak_count, win_streak_update_time, update_time, reward_time, compensation_count, depot, today_attack_count, attack_time, xwealth, xwealth_time, match_count, match_time, pvp_win_count, pvp_const_win_count, pvp_fight_count, const_win_count) values(%d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), %d, '%s', %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, %d, %d, %d)", pid, self.period, self.map[pid].wealth, self.map[pid].win_count, self.map[pid].fight_count, self.map[pid].defend_win_count, self.map[pid].defend_fight_count, self.map[pid].today_win_streak_count, self.map[pid].win_streak_update_time, self.map[pid].update_time, self.map[pid].reward_time, self.map[pid].compensation_count, serialize(self.map[pid].depot), self.map[pid].today_attack_count, self.map[pid].attack_time, self.map[pid].xwealth, self.map[pid].xwealth_time, self.map[pid].match_count, self.map[pid].match_time, self.map[pid].pvp_win_count, self.map[pid].pvp_const_win_count, self.map[pid].pvp_fight_count, self.map[pid].const_win_count)
		self.map[pid].db_exists = true
	end

	return true
end

function PillageArena:UpdatePvpFightCount(pid, is_win)	
	if self.period ~= getCurrentPeriod() then
		return false
	end
	
	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end
	
	self.map[pid].pvp_fight_count = self.map[pid].pvp_fight_count + 1
	if is_win then
		self.map[pid].pvp_win_count = self.map[pid].pvp_win_count + 1	
		self.map[pid].pvp_const_win_count = self.map[pid].pvp_const_win_count + 1
		self.map[pid].const_win_count = self.map[pid].const_win_count + 1
	else	
		self.map[pid].pvp_const_win_count = 0
		self.map[pid].const_win_count = 0
	end
	
	-- quests
	local quests = {}
	table.insert(quests, { type = 73, id = 8, count = self.map[pid].pvp_const_win_count })
	table.insert(quests, { type = 73, id = 6, count = self.map[pid].const_win_count })
	cell.NotifyQuestEvent(pid, quests)

	if self.map[pid].db_exists then	
		database.update("update pillage_arena_player_pool set pvp_win_count = %d, pvp_const_win_count = %d, pvp_fight_count = %d, const_win_count = %d where pid = %d and period = %d", self.map[pid].pvp_win_count, self.map[pid].pvp_const_win_count, self.map[pid].pvp_fight_count, self.map[pid].const_win_count, pid, self.period)
	else
		database.update("insert into pillage_arena_player_pool(pid, period, wealth, win_count, fight_count, defend_win_count, defend_fight_count, today_win_streak_count, win_streak_update_time, update_time, reward_time, compensation_count, depot, today_attack_count, attack_time, xwealth, xwealth_time, match_count, match_time, pvp_win_count, pvp_const_win_count, pvp_fight_count, const_win_count) values(%d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), %d, '%s', %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, %d, %d, %d)", pid, self.period, self.map[pid].wealth, self.map[pid].win_count, self.map[pid].fight_count, self.map[pid].defend_win_count, self.map[pid].defend_fight_count, self.map[pid].today_win_streak_count, self.map[pid].win_streak_update_time, self.map[pid].update_time, self.map[pid].reward_time, self.map[pid].compensation_count, serialize(self.map[pid].depot), self.map[pid].today_attack_count, self.map[pid].attack_time, self.map[pid].xwealth, self.map[pid].xwealth_time, self.map[pid].match_count, self.map[pid].match_time, self.map[pid].pvp_win_count, self.map[pid].pvp_const_win_count, self.map[pid].pvp_fight_count, self.map[pid].const_win_count)
		self.map[pid].db_exists = true
	end

end

function PillageArena:Enter(pid)
	log.debug(string.format("Player %d begin enter pillage arena period:%d", pid, self.period))

	if self.period ~= getCurrentPeriod() then
		log.debug(string.format("pillage arena of period %d is already finish or not begin", self.period))	
		return false
	end

	if self.map[pid] then
		log.debug("already enter pillage_arena")
		return true
	end	

	local now = loop.now()

	local t = {
		pid = pid,
		period = self.period,
		wealth = 1000000,
		win_count = 0,
		fight_count = 0,
		defend_win_count = 0,
		defend_fight_count = 0,
		today_win_streak_count = 0,
		win_streak_update_time = 0,
		update_time = now,
		reward_time = 0,
		compensation_count = 0,
		depot = {},
		today_attack_count = 0,
		attack_time = 0,
		xwealth = 0,
		xwealth_time = loop.now(),
		match_count = 0,
		match_time = 0,
		pvp_win_count = 0,
		pvp_const_win_count = 0,
		pvp_fight_count = 0,
		const_win_count = 0,
		db_exists = false,
	}

	self.map[pid] = t
	self.player_pool[1][pid] = t

	if pid > AI_RANGE or pid < PVP_AI_RANGE then
		self.rank:setValue(pid, 1000000, loop.now())
	end

	database.update("insert into pillage_arena_player_pool(pid, period, wealth, win_count, fight_count, defend_win_count, defend_fight_count,today_win_streak_count, win_streak_update_time, update_time, reward_time, compensation_count, depot, today_attack_count, attack_time, xwealth, xwealth_time, match_count, match_time, pvp_win_count, pvp_const_win_count, pvp_fight_count, const_win_count) values(%d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), %d, '%s', %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, %d, %d, %d)", pid, self.period, 1000000, 0, 0, 0, 0, 0, 0, now, 0, 0, "{}", 0, 0, 0, loop.now(), 0, 0, 0, 0, 0, 0)

	self.player_pool[1][pid].db_exists = true
	return true
end

function PillageArena:GetTodayWinStreakCount(pid)
	if self.period ~= getCurrentPeriod() then
		return false 
	end

	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end
	
	--if not sameDay(self.map[pid].win_streak_update_time) then
	--	return 0
	--else
		return self.map[pid].today_win_streak_count
	--end
end

function PillageArena:GetRankList()
	local rank = {}

	for k, v in ipairs(self.rank:GetTopK() or {}) do
		table.insert(rank, {v[1], v[2]})
	end

	return rank 
end

function PillageArena:GetCompensationCount(pid)
	if self.period ~= getCurrentPeriod() then
		return false 
	end

	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end

	return self.map[pid].compensation_count
end

function PillageArena:SetCompensationCount(pid, count)
	if self.period ~= getCurrentPeriod() then
		return false 
	end

	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end

	if self.map[pid].compensation_count == count then return end

	self.map[pid].compensation_count = count

	if self.map[pid].db_exists then
		database.update("update pillage_arena_player_pool set compensation_count = %d where pid = %d and period = %d", self.map[pid].compensation_count , pid, self.period)
	else
		database.update("insert into pillage_arena_player_pool(pid, period, wealth, win_count, fight_count, defend_win_count, defend_fight_count, today_win_streak_count, win_streak_update_time, update_time, reward_time, compensation_count, depot, today_attack_count, attack_time, xwealth, xwealth_time, match_count, match_time, pvp_win_count, pvp_const_win_count, pvp_fight_count, const_win_count) values(%d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), %d, '%s', %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, %d, %d, %d)", pid, self.period, self.map[pid].wealth, self.map[pid].win_count, self.map[pid].fight_count, self.map[pid].defend_win_count, self.map[pid].defend_fight_count, self.map[pid].today_win_streak_count, self.map[pid].win_streak_update_time, self.map[pid].update_time, self.map[pid].reward_time, compensation_count, serialize(self.map[pid].depot), self.map[pid].today_attack_count, self.map[pid].attack_time, self.map[pid].xwealth, self.map[pid].xwealth_time, self.map[pid].match_count, self.map[pid].match_time, self.map[pid].pvp_win_count, self.map[pid].pvp_const_win_count, self.map[pid].pvp_fight_count, self.map[pid].const_win_count)
		self.map[pid].db_exists = true
	end	
end

function PillageArena:Info(pid)
	if self.period ~= getCurrentPeriod() then
		return false 
	end

	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end

	return {
		self.map[pid].wealth, self.map[pid].win_count, self.map[pid].fight_count, 
		self:GetTodayWinStreakCount(pid), 
		self.map[pid].defend_win_count, self.map[pid].defend_fight_count, self.rank:getRank(pid), 
		self:GetTodayAttackCount(pid),
		self:GetTodayMatchCount(pid)
	}
end

function PillageArena:UpdateDepot(pid, t)
	if self.period ~= getCurrentPeriod() then
		return false 
	end

	if not self.map[pid] then
		return false
	end

	table.insert(self.map[pid].depot,t)

	if self.map[pid].db_exists then
		database.update("update pillage_arena_player_pool set depot = '%s' where pid = %d and period = %d", serialize(self.map[pid].depot) , pid, self.period)
	else
		database.update("insert into pillage_arena_player_pool(pid, period, wealth, win_count, fight_count, defend_win_count, defend_fight_count, today_win_streak_count, win_streak_update_time, update_time, reward_time, compensation_count, depot, today_attack_count, attack_time, xwealth, xwealth_time, match_count, match_time, pvp_win_count, pvp_const_win_count, pvp_fight_count, const_win_count) values(%d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), %d, '%s', %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, %d, %d, %d)", pid, self.period, self.map[pid].wealth, self.map[pid].win_count, self.map[pid].fight_count, self.map[pid].defend_win_count, self.map[pid].defend_fight_count, self.map[pid].today_win_streak_count, self.map[pid].win_streak_update_time, self.map[pid].update_time, self.map[pid].reward_time, self.map[pid].compensation_count, serialize(self.map[pid].depot), self.map[pid].today_attack_count, self.map[pid].attack_time, self.map[pid].xwealth, self.map[pid].xwealth_time, self.map[pid].match_count, self.map[pid].match_time,self.map[pid].pvp_win_count, self.map[pid].pvp_const_win_count, self.map[pid].pvp_fight_count, self.map[pid].const_win_count)
		self.map[pid].db_exists = true
	end
end

function PillageArena:ClearDepot(pid)
	if not self.map[pid] then
		return false
	end

	if not self.map[pid].depot or not next(self.map[pid].depot) then
		return false
	end

	self.map[pid].depot = {}
	
	if self.map[pid].db_exists then
		database.update("update pillage_arena_player_pool set depot = '%s' where pid = %d and period = %d", serialize(self.map[pid].depot) , pid, self.period)
	else
		database.update("insert into pillage_arena_player_pool(pid, period, wealth, win_count, fight_count, defend_win_count, defend_fight_count, today_win_streak_count, win_streak_update_time, update_time, reward_time, compensation_count, depot, today_attack_count, attack_time, xwealth, xwealth_time, match_count, match_time, pvp_win_count, pvp_const_win_count, pvp_fight_count, const_win_count) values(%d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), %d, '%s', %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, %d, %d, %d)", pid, self.period, self.map[pid].wealth, self.map[pid].win_count, self.map[pid].fight_count, self.map[pid].defend_win_count, self.map[pid].defend_fight_count, self.map[pid].today_win_streak_count, self.map[pid].win_streak_update_time, self.map[pid].update_time, self.map[pid].reward_time, self.map[pid].compensation_count, serialize(self.map[pid].depot), self.map[pid].today_attack_count, self.map[pid].attack_time, self.map[pid].xwealth, self.map[pid].xwealth_time, self.map[pid].match_count, self.map[pid].match_time,self.map[pid].pvp_win_count, self.map[pid].pvp_const_win_count, self.map[pid].pvp_fight_count, self.map[pid].const_win_count)
		self.map[pid].db_exists = true
	end
end

function PillageArena:UpdateRewardTime(pid, t)
	--[[if self.period ~= getCurrentPeriod() then
		return false 
	end--]]

	if not self.map[pid] then
		return false
	end

	self.map[pid].reward_time = t or loop.now()

	if self.map[pid].db_exists then
		database.update("update pillage_arena_player_pool set reward_time = from_unixtime_s(%d) where pid = %d and period = %d", self.map[pid].reward_time , pid, self.period)
	else
		database.update("insert into pillage_arena_player_pool(pid, period, wealth, win_count, fight_count, defend_win_count, defend_fight_count, today_win_streak_count, win_streak_update_time, update_time, reward_time, compensation_count, depot, today_attack_count, attack_time, xwealth, xwealth_time, match_count, match_time, pvp_win_count, pvp_const_win_count, pvp_fight_count, const_win_count) values(%d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), %d, '%s', %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, %d, %d)", pid, self.period, self.map[pid].wealth, self.map[pid].win_count, self.map[pid].fight_count, self.map[pid].defend_win_count, self.map[pid].defend_fight_count, self.map[pid].today_win_streak_count, self.map[pid].win_streak_update_time, self.map[pid].update_time, self.map[pid].reward_time, self.map[pid].compensation_count, serialize(self.map[pid].depot), self.map[pid].today_attack_count, self.map[pid].attack_time, self.map[pid].xwealth, self.map[pid].xwealth_time, self.map[pid].match_count, self.map[pid].match_time, self.map[pid].pvp_win_count, self.map[pid].pvp_const_win_count, self.map[pid].pvp_fight_count, self.map[pid].const_win_count)
		self.map[pid].db_exists = true
	end
end

function PillageArena:GetTodayAttackCount(pid)
	if self.period ~= getCurrentPeriod() then
		return false 
	end

	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end
	
	if not sameDay(self.map[pid].attack_time) then
		return 0
	else
		return self.map[pid].today_attack_count
	end
end

function PillageArena:SetTodayAttackCount(pid, count)
	if self.period ~= getCurrentPeriod() then
		return false 
	end

	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end

	local attack_count = self:GetTodayAttackCount(pid)

	if attack_count == count then return end

	self.map[pid].today_attack_count = count
	self.map[pid].attack_time = loop.now()	

	if self.map[pid].db_exists then
		database.update("update pillage_arena_player_pool set today_attack_count = %d, attack_time = from_unixtime_s(%d) where pid = %d and period = %d", self.map[pid].today_attack_count, self.map[pid].attack_time, pid, self.period)
	else
		database.update("insert into pillage_arena_player_pool(pid, period, wealth, win_count, fight_count, defend_win_count, defend_fight_count, today_win_streak_count, win_streak_update_time, update_time, reward_time, compensation_count, depot, today_attack_count, attack_time, xwealth, xwealth_time, match_count, match_time, pvp_win_count, pvp_const_win_count, pvp_fight_count, const_win_count) values(%d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), %d, '%s', %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, %d, %d, %d)", pid, self.period, self.map[pid].wealth, self.map[pid].win_count, self.map[pid].fight_count, self.map[pid].defend_win_count, self.map[pid].defend_fight_count, self.map[pid].today_win_streak_count, self.map[pid].win_streak_update_time, self.map[pid].update_time, self.map[pid].reward_time, self.map[pid].compensation_count, serialize(self.map[pid].depot), self.map[pid].today_attack_count, self.map[pid].attack_time, self.map[pid].xwealth, self.map[pid].xwealth_time, self.map[pid].match_count, self.map[pid].match_time, self.map[pid].pvp_win_count, self.map[pid].pvp_const_win_count, self.map[pid].pvp_fight_count, self.map[pid].const_win_count)
		self.map[pid].db_exists = true
	end
end

function PillageArena:GetTodayMatchCount(pid)
	if self.period ~= getCurrentPeriod() then
		return nil 
	end

	if not self.map[pid] then
		if not self:Enter(pid) then
			return nil
		end
	end
	
	if not sameDay(self.map[pid].match_time) then
		return 0
	else
		return self.map[pid].match_count
	end
end

function PillageArena:SetTodayMatchCount(pid, count)
	if self.period ~= getCurrentPeriod() then
		return false 
	end

	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end

	local n = self:GetTodayMatchCount(pid)

	if n == count then return end

	self.map[pid].match_count = count
	self.map[pid].match_time = loop.now()	

	if self.map[pid].db_exists then
		database.update("update pillage_arena_player_pool set match_count = %d, match_time = from_unixtime_s(%d) where pid = %d and period = %d", self.map[pid].match_count, self.map[pid].match_time, pid, self.period)
	else
		database.update("insert into pillage_arena_player_pool(pid, period, wealth, win_count, fight_count, defend_win_count, defend_fight_count, today_win_streak_count, win_streak_update_time, update_time, reward_time, compensation_count, depot, today_attack_count, attack_time, xwealth, xwealth_time, match_count, match_time, pvp_win_count, pvp_const_win_count, pvp_fight_count, const_win_count) values(%d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), %d, '%s', %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d, %d, %d, %d)", pid, self.period, self.map[pid].wealth, self.map[pid].win_count, self.map[pid].fight_count, self.map[pid].defend_win_count, self.map[pid].defend_fight_count, self.map[pid].today_win_streak_count, self.map[pid].win_streak_update_time, self.map[pid].update_time, self.map[pid].reward_time, self.map[pid].compensation_count, serialize(self.map[pid].depot), self.map[pid].today_attack_count, self.map[pid].attack_time, self.map[pid].xwealth, self.map[pid].xwealth_time, self.map[pid].match_count, self.map[pid].match_time,self.map[pid].pvp_win_count, self.map[pid].pvp_const_win_count, self.map[pid].pvp_fight_count, self.map[pid].const_win_count)
		self.map[pid].db_exists = true
	end
end

function PillageArena:CheckAndSendReward()
	if rewardTime() and not finishRewardSettle(self.period, getSubPeriod()) then
		for _, v in pairs(self.player_pool) do
			for pid, info in pairs(v) do
				if not alreadyDrawReward(info.reward_time) then
					--local rank = self.rank:getRank(info.pid)
					local xwealth = self:GetXWealth(info.pid)
					local level = getLevel(xwealth)
					if player_online[info.pid] and (xwealth ~= 0) then
						-- sendReward
						log.debug(string.format("send reward for player %d period %d subPeriod %d xwealth %d  level %d", info.pid, self.period, getSubPeriod(), xwealth, level))
						local reward 
						if not finalDay() then
							reward = GetPillageArenaReward(level, 1)
						else
							reward = GetPillageArenaReward(level, 2)
						end
						DOReward(info.pid, reward, nil, Command.REASON_PILLAGE_ARENA_REWARD, true, 0, "竞技场奖励")
						self:UpdateRewardTime(info.pid)
					else
						-- reward depot
						--[[log.debug(string.format("update reward depot for player %d period %d subPeriod %d rank %d", info.pid, self.period, getSubPeriod(), rank))
						local reward 
						if not finalDay() then
							reward = GetPillageArenaReward(rank, 1)
						else
							reward = GetPillageArenaReward(rank, 2)
						end
						self:UpdateDepot(pid, {rank = rank, reward = reward})--]]
					end	
				end
			end
		end
		setRewardSettleFinish(self.period, getSubPeriod())
	end
end

function PillageArena:SendRemainReward(pid)
	--[[if not self.map[pid] then
		return 
	end

	if not self.map[pid].depot or not next(self.map[pid].depot) then
		return 
	end

	for k, v in ipairs(self.map[pid].depot) do
		DOReward(pid, v.reward, nil, Command.REASON_PILLAGE_ARENA_REWARD, false, nil, nil)
	end	

	self:ClearDepot(pid)--]]

	if not self.map[pid] then
		return 
	end

	log.debug(string.format("send remain reward in pillagearena for player %d period %d", pid, self.period))
	if self.period ~= getCurrentPeriod() then
		local xwealth = self:GetXWealth(pid, getEndTimeByPeriod(self.period))
		if xwealth > 0 and not alreadyDrawReward(self.map[pid].reward_time, getEndTimeByPeriod(self.period)) then
			local level = getLevel(xwealth)
			local reward = GetPillageArenaReward(level, 2)
			DOReward(pid, reward, nil, Command.REASON_PILLAGE_ARENA_REWARD, true, 0, "竞技场奖励")
			self:UpdateRewardTime(pid, getEndTimeByPeriod(self.period))
			log.debug(string.format("send last period remain reward xwealth %d level %d", xwealth, level))
		end
	else
		local xwealth = self:GetXWealth(pid)
		--log.debug(">>>>>>>>>>>>>", xwealth, self.map[pid].reward_time, tostring(alreadyDrawReward(self.map[pid].reward_time)))
		if xwealth > 0 and not alreadyDrawReward(self.map[pid].reward_time) then
			local level = getLevel(xwealth)
			local reward 
			if finalDay() then
				reward = GetPillageArenaReward(level, 2)
			else
				reward = GetPillageArenaReward(level, 1)
			end	
			DOReward(pid, reward, nil, Command.REASON_PILLAGE_ARENA_REWARD, true, 0, "竞技场奖励")
			self:UpdateRewardTime(pid)
			log.debug(string.format("send current period remain reward xwealth %d level %d", xwealth, level))
		end
	end	
end

function PillageArena:GetPveAI(level)
	local ret = {}

	for pid, v in pairs(self.ai_pool[level]) do
		if pid > PVP_AI_RANGE and not v.is_game_role then
			table.insert(ret, v)	
		end
	end 

	return ret
end

function PillageArena:GetPvpAI(level)
	local ret = {}

	for pid, v in pairs(self.ai_pool[level]) do
		if pid < PVP_AI_RANGE then
			table.insert(ret, v)	
		end
	end 

	return ret	
end

function PillageArena:Compensate(pid)
	if self.period ~= getCurrentPeriod() then
		return false 
	end

	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end

	if self.map[pid].compensation_count <= 0 then return end

	if not self.map[pid].next_compensation_time then
		self.map[pid].next_compensation_time = loop.now() + math.random(60, 80)
	end

	if loop.now() < self.map[pid].next_compensation_time then
		return 	
	end

	local level = getLevel(self.map[pid].wealth)
	local target_level = math.max(level - 1, WEALTH_LEVEL_MIN)

	local enemy_id 
	local lv = OpenlevConfig.get_level(pid)	-- 玩家等级
	for i = target_level, WEALTH_LEVEL_MIN, -1 do
		local t = self:GetPveAI(target_level)
		enemy_id = find_fake_player(t, lv, 5)
		if enemy_id then
			break
		end
	end

	if enemy_id then
		log.debug(string.format("begin compensate  bot %d  player %d", enemy_id, pid))
		if math.random(1, 100) < 90 then
			--player win
			log.debug("compensate player win")
			self:UpdateFight(enemy_id, pid, 0)	
		else
			--player fail
			log.debug("compensate player fail")
			self:UpdateFight(enemy_id, pid, 1)	
		end	

		self:SetCompensationCount(pid, self.map[pid].compensation_count - 1)

		if self.map[pid].compensation_count - 1 == 0 then
			self.map[pid].next_compensation_time = nil
		else
			self.map[pid].next_compensation_time = loop.now() + math.random(1, 60) 
		end	
	else
		self.map[pid].next_compensation_time = loop.now() + math.random(1, 70)
	end	
end

function PillageArena:CheckAndCompensate()
	for k, v in pairs(self.player_pool) do
		for pid, info in pairs(v) do
			self:Compensate(info.pid)
		end
	end
end

function PillageArena:UpdateFight(pid, enemy_id, result)
	if self.period ~= getCurrentPeriod() then
		return false 
	end

	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end

	if not self.map[enemy_id] then
		if not self:Enter(enemy_id) then
			return false
		end
	end

	local player_wealth = self.map[pid].wealth			
	local enemy_wealth = self.map[enemy_id].wealth			

	local player_log 
	local enemy_log
	if pid > AI_RANGE then
		player_log = ArenaLog.Get(self.period, pid)
	end

	if enemy_id > AI_RANGE then
		enemy_log = ArenaLog.Get(self.period, enemy_id)
	end

	if result == 1 then
		local new_player_wealth = player_wealth + math.ceil(enemy_wealth * 0.02)
		local new_enemy_wealth = enemy_wealth - math.ceil(enemy_wealth * 0.01)

		if not self:SetWealth(pid, new_player_wealth) then
			log.debug("set player wealth fail")
			return false
		end

		if not self:SetWealth(enemy_id, new_enemy_wealth) then
			log.debug("set enemy wealth fail")
			return false
		end

		if not self:UpdateAttackFightResult(pid, 1) then
			log.debug("update attack fight result fail")
			return false
		end

		if not self:UpdateDefendFightResult(enemy_id, 0) then
			log.debug("update defend fight result fail")
			return false
		end

		if player_log then
			player_log:AddLog(pid, enemy_id, math.ceil(enemy_wealth * 0.02)) 
		end

		if enemy_log then
			enemy_log:AddLog(pid, enemy_id, -math.ceil(enemy_wealth * 0.01))
		end
	else
		local new_player_wealth = player_wealth - math.ceil(player_wealth * 0.01)
		local new_enemy_wealth = enemy_wealth + math.ceil(player_wealth * 0.02) 

		if not self:SetWealth(pid, new_player_wealth) then
			log.debug("set player wealth fail")
			return false
		end

		if not self:SetWealth(enemy_id, new_enemy_wealth) then
			log.debug("set enemy wealth fail")
			return false
		end

		if not self:UpdateAttackFightResult(pid, 0) then
			log.debug("update attack fight result fail")
			return false
		end

		if not self:UpdateDefendFightResult(enemy_id, 1) then
			log.debug("update defend fight result fail")
			return false
		end
		
		if player_log then
			player_log:AddLog(pid, enemy_id, -math.ceil(player_wealth * 0.01))
		end

		if enemy_log then
			enemy_log:AddLog(pid, enemy_id, math.ceil(player_wealth * 0.02)) 
		end
	end

	return true
end

function PillageArena:SelectEnemy(pid)
	if not self.map[pid] then
		if not self:Enter(pid) then
			return false
		end
	end

	local today_attack_count = self:GetTodayAttackCount(pid)
	if today_attack_count and today_attack_count >= ArenaFightConfig.get_match_count(1) then
		log.debug("today attack count already max")
		return false
	end

	local player_info = self.map[pid]
	
	local wealth = player_info.wealth
	local win_rate = player_info.fight_count > 0 and math.ceil((player_info.win_count / player_info.fight_count) * 100) or 100 

	local target_level, is_ai = getTargetLevel(wealth, win_rate)
	local min_level = math.max(target_level - 3, WEALTH_LEVEL_MIN)
	if is_ai then
		min_level = WEALTH_LEVEL_MIN
	end
	if PveManager.map[pid] and PveManager.map[pid].time + 5 >= loop.now() then
		is_ai = true
	end

	for i = target_level, min_level, -1 do
		if is_ai then	
			local t = self:GetPveAI(target_level)
			local lv = OpenlevConfig.get_level(pid)	-- 玩家等级
			local ret = find_fake_player(t, lv, 5)
			if ret then
				return true, ret 
			end
		else
			local lv = OpenlevConfig.get_level(pid)
			local ret = find_player(self.player_pool[i], lv, 5, pid)
			if ret then
				return true, ret 
			end
		end
	end

	return true 
end

function PillageArena:GetAttackWinRate(pid)
	if not self.map[pid] then
		return false
	end	

	return self.map[pid].fight_count ~= 0 and (self.map[pid].win_count / self.map[pid].fight_count * 100) or 100
end

function PillageArena:GetDefendWinRate(pid)
	if not self.map[pid] then
		return false
	end

	return self.map[pid].defend_fight_count ~= 0 and (self.map[pid].defend_win_count / self.map[pid].defend_fight_count * 100) or 100
end

-- 让配置的ai财力值不能超过排行榜最后一个人
function PillageArena:BalanceWealth(pid)
	local old_wealth = self:GetWealth(pid)
	if not old_wealth then
		return
	end
	local ranklist = self:GetRankList()
	if old_wealth > ranklist[#ranklist][2] then
		self:SetWealth(pid, ranklist[#ranklist][2])
	end
end

local Periods = {}
function PillageArena.Get(period) 
	if not Periods[period] then
		Periods[period] = PillageArena.New(period)
	end

	return Periods[period]
end

-- 是否已经处于等待队列中
function match_pool.is_wait(index, level, pid)
	if match_pool.wait_list[index] and match_pool.wait_list[index][level] then
		local list = match_pool.wait_list[index][level]
		for i, v in ipairs(list) do
			if v.pid == pid then
				return true, i
			end
		end
	end
	
	return false
end

-- 是否正在战斗
function match_pool.is_fight(pid)
	for i, v in ipairs(match_pool.fight_list) do
		if v[1] == pid or v[2] == pid then
			return true, i
		end
	
	end
	return false
end

function match_pool.get_index_level(pid)
	local pillage_arena = PillageArena.Get(getCurrentPeriod())
	local playerInfo = pillage_arena.map[pid]
	if not playerInfo then
		return 0, 0
	end			
	
	local win_rate = playerInfo.pvp_fight_count > 0 and math.ceil((playerInfo.pvp_win_count / playerInfo.pvp_fight_count) * 100) or 100 
	local level = getLevel(playerInfo.wealth)
	local index = 0	
	if win_rate < 40 then
		index = 1
	elseif win_rate >= 40 and win_rate < 80 then
		index = math.floor(win_rate / 10) - 2
	else
		index = 6
	end
	
	return index, level
end

function match_pool.add(pid)
	assert(pid)	
	local index, level = match_pool.get_index_level(pid)
	log.debug(string.format("match_pool.add: index = %d, level = %d", index, level))

	if index == 0 or level == 0 then	
		log.warning(string.format("match_pool.add: the player of %d is not exist.", pid))
		return Command.RET_NOT_EXIST 
	end

	if match_pool.is_wait(index, level, pid) or match_pool.is_fight(pid) then
		log.warning(string.format("match_pool.add: the player of %d was in pool.", pid))
		return Command.RET_EXIST 
	end

	local lv = OpenlevConfig.get_level(pid)	-- 玩家等级
	match_pool.wait_list[index] = match_pool.wait_list[index] or {}
	match_pool.wait_list[index][level] = match_pool.wait_list[index][level] or {}

	table.insert(match_pool.wait_list[index][level], { pid = pid, time = loop.now(), lv = lv, valid = true })	

	return Command.RET_SUCCESS
end

function match_pool.is_exist(pid)
	local index, level = match_pool.get_index_level(pid)

	if match_pool.is_wait(index, level, pid) or match_pool.is_fight(pid) then
		return true 
	end

	return false
end

function match_pool.remove(pid)
	assert(pid)

	local index, level = match_pool.get_index_level(pid)	
	log.debug("match_pool.remove: ", index, level, pid)
	if index == 0 or level == 0 then	
		log.debug(string.format("match_pool.remove: the player of %d is not exist.", pid))
		return Command.RET_NOT_EXIST 
	end

	local flag, i = match_pool.is_wait(index, level, pid)

	if not flag then
		log.debug(string.format("match_pool.remove: the player of %d was not in pool.", pid))
		return Command.RET_NOT_EXIST 
	end	

	table.remove(match_pool.wait_list[index][level], i)

	return Command.RET_SUCCESS
end

-- 将玩家加入战斗队列中
function match_pool.add2(o)
	if match_pool.is_fight(o[1]) then
		return false
	end
	table.insert(match_pool.fight_list, o)
	return true	
end

-- 将玩家从战斗队列中移出来
function match_pool.remove2(pid)
	local flag, index = match_pool.is_fight(pid)
	if flag then
		table.remove(match_pool.fight_list, index)
		return true
	end
	return false
end

-- 移除已经在战斗队列中，但还没有开始战斗的玩家
function match_pool.removeNotFightPlayer(pid)	
	local flag, index = match_pool.is_fight(pid)
	if flag and match_pool.fight_list[index].is_start == false then
		table.remove(match_pool.fight_list, index)
		return true
	end

	return false
end

function match_pool.clearInvalid(index)
	local list = match_pool.wait_list[index]
	
	local temp = {}

	for level, plist in pairs(list or {}) do
		local temp = {}
		for _, v in ipairs(plist) do
			if v.valid then
				table.insert(temp, v)
			end
		end	
		
		match_pool.wait_list[index][level] = temp
	end
end

-- 匹配玩家
function match_pool.do_match()
	while true do
		for i, v in pairs(match_pool.wait_list) do
			if i == 1 then					-- 胜率小于40%的玩家	
				match_pool.match_1(i)
			elseif i > 1 and i < 6 then			-- 胜率位于[40, 80)的玩家
				match_pool.match_2(i)
			elseif i == 6 then				-- 胜率 >= 80%的玩家
				match_pool.match_3(i)
			end
		end

		Sleep(1)
	end
end

local function NotifyMatch(pid, id)
	if pid < AI_RANGE then
		return true
	end

	local agent = Agent.Get(pid)
	if agent then
		local info1 = ArenaFormation.Get(pid)
		if not info1 then
			log.debug(string.format("NotifyMatch: get player1 %d formation fail.", pid))
			return false
		end
		local attacker = info1:GetAttackFightData()
		if not attacker then
			log.debug("NotifyMatch: attacker is nil.")
			return false
		end

		local info2 = ArenaFormation.Get(id)
		if not info2 then
			log.debug(string.format("NotifyMatch: get player2 %d formation fail.", id))
			return false
		end

		local defender = info2:GetDefendFightData()	
		if not defender then
			log.debug("NotifyMatch: defender is nil.")
			return false
		end
	
		local scene = "shuma_jjc"

		local fightData = {
			attacker = attacker,--attacker,
			defender = defender, --defender,
			seed = math.random(1, 0x7fffffff),
			scene = scene,
		}

		local code = encode('FightData', fightData);
		if code == nil then
			log.debug(string.format('encode fight data failed'));
			return false
		end
	
		local pillage_arena = PillageArena.Get(getCurrentPeriod())
		local enemy_wealth = pillage_arena:GetWealth(id)
	
		agent:Notify( { Command.NOTIFY_MATCH_SUCCESS, { 1, Command.RET_SUCCESS, code, enemy_wealth } })

		return true
	end
end

-- 战斗结算
local function fight_result(pid, result, is_pve)
	local pillage_arena = PillageArena.Get(getCurrentPeriod())
	if not pillage_arena then
		log.debug("get pillage arena fail")
		return false
	end

	local drop_reward = { } 

	local quests = {}
	if is_pve then		
		local enemy_id = PveManager.map[pid] and PveManager.map[pid].enemy_id or nil
		if not enemy_id or enemy_id == 0 then
			log.warning(string.format("fight_result failed, player %d has no enemy_id.", pid))
			return false
		end

		if not pillage_arena:UpdateFight(pid, enemy_id, result) then
			return false
		end

		if enemy_id > AI_RANGE then
			local defend_win_rate = pillage_arena:GetDefendWinRate(enemy_id)
			if defend_win_rate and defend_win_rate < 40 then
				pillage_arena:SetCompensationCount(enemy_id, pillage_arena:GetCompensationCount(enemy_id) + 1)
			end
	
			if defend_win_rate and defend_win_rate < 20 then
				pillage_arena:SetCompensationCount(enemy_id, pillage_arena:GetCompensationCount(enemy_id) + 1)
			end
		end

		local today_attack_count = pillage_arena:GetTodayAttackCount(pid)
		if today_attack_count then
			pillage_arena:SetTodayAttackCount(pid, today_attack_count + 1)
		end

		PveManager.map[pid] = nil

		if result == 1 then
			table.insert(quests, { type = 73, id = 3, count = 1 })
			table.insert(quests, { type = 73, id = 1, count = 1 })
			drop_reward[pid] = cell.sendDropReward(pid, { PVE_SUCCESS_DROP_ID }, Command.REASON_PVE_DROP)
		else	
			table.insert(quests, { type = 73, id = 5, count = 1 })	
			drop_reward[pid] = cell.sendDropReward(pid, { PVE_FAILED_DROP_ID }, Command.REASON_PVE_DROP)
		end
	else
		local flag, index = match_pool.is_fight(pid)
		local t = match_pool.fight_list[index]
		if not flag then
			log.warning(string.format("fight_result failed, player %d has no pvp enemy_id.", pid))
			return false
		end
		local enemy_id = pid ~= t[1] and t[1] or t[2]
		local win_info
		local lose_info
		if result == 1 then					
			win_info = pillage_arena.map[pid]
			lose_info = pillage_arena.map[enemy_id]
		else
			win_info = pillage_arena.map[enemy_id]
			lose_info = pillage_arena.map[pid]	
		end	

		local win_wealth = math.ceil(lose_info.wealth * 0.1) 		-- 获胜奖励
		local ext_wealth = 0						-- 连胜奖励
		if win_info.pvp_const_win_count > 0 then
			ext_wealth = math.ceil(lose_info.wealth * (win_info.pvp_const_win_count - 1) * 0.01)
		end	

		local lose_wealth = math.ceil(lose_info.wealth * 0.05)		-- 损失的财力

		-- 胜利者增加财力
		pillage_arena:SetWealth(win_info.pid, win_info.wealth + win_wealth + ext_wealth)
		-- 失败者损失财力
		pillage_arena:SetWealth(lose_info.pid, lose_info.wealth - lose_wealth)
		
		-- 更新pvp战斗次数
		pillage_arena:UpdatePvpFightCount(win_info.pid, true)	
		pillage_arena:UpdatePvpFightCount(lose_info.pid, false)	
	
		if win_info.pid > AI_RANGE then
			local win_log = ArenaLog.Get(pillage_arena.period, win_info.pid)	
			win_log:AddLog(win_info.pid, lose_info.pid, win_wealth, ext_wealth)
		end

		if lose_info.pid > AI_RANGE then
			local lose_log = ArenaLog.Get(pillage_arena.period, lose_info.pid)
			lose_log:AddLog(lose_info.pid, win_info.pid, -lose_wealth)
		end			
			
		-- 增加匹配次数
		local count1 = pillage_arena:GetTodayMatchCount(win_info.pid)
		local count2 = pillage_arena:GetTodayMatchCount(lose_info.pid)
		pillage_arena:SetTodayMatchCount(win_info.pid, count1 + 1)
		pillage_arena:SetTodayMatchCount(lose_info.pid, count2 + 1)

		match_pool.remove2(pid)
	
		if result == 1 then
			table.insert(quests, { type = 73, id = 2, count = 1 })
			table.insert(quests, { type = 73, id = 1, count = 1 })
			drop_reward[pid] = cell.sendDropReward(pid, { PVP_SUCCESS_DROP_ID }, Command.REASON_PVP_DROP)
			drop_reward[enemy_id] = cell.sendDropReward(enemy_id, { PVP_FAILED_DROP_ID }, Command.REASON_PVP_DROP)
		else
			table.insert(quests, { type = 73, id = 5, count = 1 })	
			drop_reward[pid] = cell.sendDropReward(pid, { PVP_FAILED_DROP_ID }, Command.REASON_PVP_DROP)
			drop_reward[enemy_id] = cell.sendDropReward(enemy_id, { PVP_SUCCESS_DROP_ID }, Command.REASON_PVP_DROP)
		end
	end

	table.insert(quests, { type = 4, id = 15, count = 1 })

	-- 通知客户端奖励内容
	for pid, rewards in pairs(drop_reward) do
		if #rewards > 0 then
			local msg = {}
			for _, v in ipairs(rewards) do
				table.insert(msg, {v.type, v.id, v.value});
			end

			local agent = Agent.Get(pid);
			if agent then
				agent:Notify({Command.NOTIFY_FIGHT_REWARD, {Command.FIGHT_REWARD_TYPE_ARENA_PVP, msg}})
			end
		end
	end

	--quest
	cell.NotifyQuestEvent(pid, quests)

	return true
end

-- 启动战斗
local function prepare_fight(id1, id2)
	log.debug("prepare_fight: ", id1, id2)
	Sleep(1)	
	local opt = {}
	local info1 = ArenaFormation.Get(id1)
	local info2 = ArenaFormation.Get(id2)
	local attacker1 = info1:GetAttackFightData()	
	local attacker2	= info2:GetDefendFightData()	

	if attacker1 and attacker2 then 
		opt.attacker_data = attacker1
		opt.defender_data = attacker2
	end
	
	local result, _ = SocialManager.PVPFightPrepare(id1, id2, opt)
	-- 启动战斗成功
	if result then
		log.debug(string.format("start fight success: %d, %d", id1, id2))		
		local is_pve = true
		local flag  = match_pool.is_fight(id1)
		if flag then
			is_pve = false	
		end		
		fight_result(id1, result, is_pve)
	
		local cmd = Command.NOTIFY_FIGHT_RESULT
		if id1 > AI_RANGE then
			local agent = Agent.Get(id1)			
			agent:Notify( { cmd, { id2, result } })
		end
		if id2 > AI_RANGE then
			local agent = Agent.Get(id2)
			agent:Notify( { cmd, { id1, result == 2 and 1 or 2 } })
		end	
	else
		log.error(string.format("prepare fight failed: %d, %d", id1, id2))
		-- 启动战斗失败时，移除在战斗队列中的玩家
		match_pool.remove2(id1)
		PveManager.map[id1] = nil
	end
end

local function auto_fight(id1, id2)
	local opt = {}
	local info1 = ArenaFormation.Get(id1)
	local info2 = ArenaFormation.Get(id2)
	local attacker1 = info1:GetAttackFightData()	
	local attacker2	= info2:GetDefendFightData()	

	if attacker1 and attacker2 then 
		opt.attacker_data = attacker1
		opt.defender_data = attacker2
	end
	opt.auto = true
	
	local result, _ = SocialManager.PVPFightPrepare(id1, id2, opt)
	if result then
		log.debug(string.format("auto fight success: %d, %d", id1, id2))
		fight_result(id1, result, true)	
	else
		log.error(string.format("auto fight failed: %d, %d.", id1, id2))
		PveManager.map[id1] = nil
	end
end

-- 为胜率小于40%的玩家进行匹配
function match_pool.match_1(index)
	local pillage_arena = PillageArena.Get(getCurrentPeriod())
	for level, plist in pairs(match_pool.wait_list[index] or {}) do
		for _, v in ipairs(plist) do
			local sec = math.random(3, 10)
			if v.valid and v.time + sec <= loop.now() then			
				local t = pillage_arena:GetPveAI(level)
				local id = find_fake_player(t, v.lv, 5)
				-- 通知用户匹配成功
				if id and NotifyMatch(v.pid, id) then
					match_pool.add2({ v.pid, id, is_start = false })
					v.valid = false
				end
			end
		end
	end

	match_pool.clearInvalid(index)		
end

-- 为胜率位于[40, 80)的玩家进行匹配
function match_pool.match_2(index)
	local pillage_arena = PillageArena.Get(getCurrentPeriod())
	
	for level, plist in pairs(match_pool.wait_list[index] or {}) do
		for _, v in ipairs(plist) do
			if v.valid then
				local pvp_list = pillage_arena:GetPvpAI(level)
				local id1 = find_player(plist, v.lv, 5, v.pid)
				local id2 = find_ai_player(pvp_list, v.lv, 5)
				local id = id1 or id2
				if id then	-- 优先匹配同等级的		
					if NotifyMatch(v.pid, id) and NotifyMatch(id, v.pid) then	
						match_pool.add2({ v.pid, id, is_start = false })
						v.valid = false
					end
				else		
					if loop.now() <= v.time + 15 then 							-- 1级范围内查找					
						local pvp_list = pillage_arena:GetPvpAI(level + 1)
						local next_list = match_pool.wait_list[index][level + 1]		
						local id1 = find_player(next_list, v.lv, 5, v.pid)
						local id2 = find_ai_player(pvp_list, v.lv, 5)
						local id = id1 or id2						
						if id and NotifyMatch(v.pid, id) and NotifyMatch(id, v.pid) then
							match_pool.add2({ v.pid, id, is_start = false })
							v.valid = false	
						end
					elseif loop.now() <= v.time + 25 then							-- 2级范围内查找	
						local pvp_list = pillage_arena:GetPvpAI(level + 1)
						local next_list = match_pool.wait_list[index][level + 1]
						local id1 = find_player(next_list, v.lv, 5, v.pid)
						local id2 = find_ai_player(pvp_list, v.lv, 5)
						local id = id1 or id2
						if id then
							if NotifyMatch(v.pid, id) and NotifyMatch(id, v.pid) then
								match_pool.add2({ v.pid, id, is_start = false })
								v.valid = false	
							end
						else				
							local pvp_list = pillage_arena:GetPvpAI(level + 2)
							local next_list2 = match_pool.wait_list[index][level + 2]
							local id1 = find_player(next_list2, v.lv, 5, v.pid)
							local id2 = find_ai_player(pvp_list, v.lv, 5)
							local id = id1 or id2				
							if id then
								if NotifyMatch(v.pid, id) and NotifyMatch(id, v.pid) then
									match_pool.add2({ v.pid, id, is_start = false })
									v.valid = false	
								end
							end
						end				
					else											-- 匹配假数据
						local t = pillage_arena:GetPveAI(level)
						local id = find_fake_player(t, v.lv, 5)
						-- 通知用户匹配成功
						if id and NotifyMatch(v.pid, id) then
							match_pool.add2({ v.pid, id, is_start = false })
							v.valid = false
						end	
					end	
				end
			end
		end
	end
		
	match_pool.clearInvalid(index)		
end

-- 为胜率大于或等于80%的玩家进行匹配
function match_pool.match_3(index)
	local pillage_arena = PillageArena.Get(getCurrentPeriod())	
	for level, plist in pairs(match_pool.wait_list[index] or {}) do
		for _, v in ipairs(plist) do	
			if v.valid then
				local pvp_list = pillage_arena:GetPvpAI(level)
				local id1 = find_player(plist, v.lv, 5, v.pid)
				local id2 = find_ai_player(pvp_list, v.lv, 5)
				local id = id1 or id2	
				if id then											-- 优先匹配同等级的		
					if NotifyMatch(v.pid, id) and NotifyMatch(id, v.pid) then	
						match_pool.add2({ v.pid, id, is_start = false })
						v.valid = false
					end
				else		
					if loop.now() <= v.time + 25 then 							-- 1级范围内查找					
						local pvp_list = pillage_arena:GetPvpAI(level + 1)
						local next_list = match_pool.wait_list[index][level + 1]
						local id1 = find_player(next_list, v.lv, 5, v.pid)
						local id2 = find_ai_player(pvp_list, v.lv, 5)
						local id = id1 or id2
						if id and NotifyMatch(v.pid, id) and NotifyMatch(id, v.pid) then
							match_pool.add2({ v.pid, id, is_start = false })
							v.valid = false	
						end
					else											-- 匹配假数据
						local t = pillage_arena:GetPveAI(level + 1)	
						local id = find_fake_player(t, v.lv, 5)
						-- 通知用户匹配成功
						if id and NotifyMatch(v.pid, id) then
							match_pool.add2({ v.pid, id, is_start = false })
							v.valid = false
						end	
					end	
				end
			end
		end
	end
	
	match_pool.clearInvalid(index)		
end

Scheduler.Register(function(now)
	local period = getCurrentPeriod()
	--local pillage_arena = PillageArena.Get(period)
	local pillage_arena = Periods[period]
	if not pillage_arena then
		return
	end

	if now % 5 == 0 then
		-- reward settle
		pillage_arena:CheckAndSendReward()	
		-- compensation
		pillage_arena:CheckAndCompensate()
	end
	if now % 300 == 0 then
		for i = 1, 27 do
			local list = pillage_arena:GetPvpAI(i)	
			if #list >= 2 then 
				local index = math.random(#list - 1)
				local index2 = math.random(#list)
				if index == index2 then
					index2 = index + 1
				end
				local n = math.random(100)
				local win_info
				local lose_info

				if n <= 50 then
					win_info = pillage_arena.map[list[index].pid]
					lose_info = pillage_arena.map[list[index2].pid]	
				else
					win_info = pillage_arena.map[list[index2].pid]
					lose_info = pillage_arena.map[list[index].pid]	
				end

				local win_wealth = math.ceil(lose_info.wealth * 0.1) 		-- 获胜奖励
				local ext_wealth = 0						-- 连胜奖励
				if win_info.pvp_const_win_count > 0 then
					ext_wealth = math.ceil(lose_info.wealth * (win_info.pvp_const_win_count - 1) * 0.01)
				end	

				local lose_wealth = math.ceil(lose_info.wealth * 0.05)		-- 损失的财力

				-- 胜利者增加财力
				pillage_arena:SetWealth(win_info.pid, win_info.wealth + win_wealth + ext_wealth)

				if lose_info.wealth > 500000 then
					-- 失败者损失财力
					pillage_arena:SetWealth(lose_info.pid, lose_info.wealth - lose_wealth)
				end
			end
		end
	end
end)

local function isCompelete(pid)
	local cfg = ArenaFightConfig.get_consume(26)
	if not cfg then
		return true
	end

	local respond = cell.sendReward(pid, nil, { { type = cfg.type, id = cfg.item_id, value = cfg.item_value }, }) 
	if respond and respond.result == 0 then
		return true
	else
		return false
	end
end

function PillageArena.RegisterCommand(service)
	service:on(Command.C_PILLAGE_ARENA_FIGHT_PERPARE_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local cmd = Command.C_PILLAGE_ARENA_FIGHT_PERPARE_RESPOND
		log.debug(string.format("Player %d begin to prepare for fight in pillage arena", pid))

		-- 等级限制
		if not OpenlevConfig.isLvOK(pid, 1901) then
			log.debug("open arena level not enough.")
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
		end

		-- 判断是否完成新手引导任务
		if not isCompelete(pid) then
			log.debug(string.format("cmd: %d, player %d didn't complete fresh task.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end

		local player_formation = ArenaFormation.Get(pid)
		if not player_formation then
			log.debug("get player formation fail")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end

		local attacker = player_formation:GetAttackFightData()
		if not attacker then
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end

		local pillage_arena = PillageArena.Get(getCurrentPeriod())
		if not pillage_arena then
			log.debug("fail to get pillage arena for current period")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end
	
		-- 开启时间判断
		if not ArenaFightConfig.is_range(1) then
			log.warning(string.format("cmd: %d, pve match not in range time.", cmd))	
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end

		-- 判断是否已经开始进行pvp匹配
		if match_pool.is_exist(pid) then
			log.warning(string.format("cmd: %d, player %d have been start pvp.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
		
		-- 记录pve第一次的开始匹配的时间
		if PveManager.map[pid] == nil then
			PveManager.map[pid] = { pid = pid, enemy_id = 0, time = loop.now() }	
		else
			if PveManager.map[pid].enemy_id ~= 0 then
				log.warning(string.format("cmd: %d, player %d has a fight to finish, please wait, enemy_id is %d.", cmd, pid, PveManager.map[pid].enemy_id))
				RunThread(auto_fight, pid, PveManager.map[pid].enemy_id)		 
				return conn:sendClientRespond(cmd, pid, { sn, Command.RET_INPROGRESS });
			end
		end
		
		local success, enemy_id = pillage_arena:SelectEnemy(pid)
		if not success then
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end

		if success and not enemy_id then
			log.debug("fail to select enemy")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_NOT_ENEMY});
		end

		local enemy_formation = ArenaFormation.Get(enemy_id)
		if not enemy_formation then
			log.debug("get enemy formation fail")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end	

		local defender = enemy_formation:GetDefendFightData()	
		if not defender then
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end

		scene = "18hao"

		local fightData = {
			attacker = attacker,--attacker,
			defender = defender, --defender,
			seed = math.random(1, 0x7fffffff),
			scene = scene,
		}

		local code = encode('FightData', fightData);
		if code == nil then
			log.debug(string.format('encode fight data failed'));
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end

		local enemy_wealth = pillage_arena:GetWealth(enemy_id)

		PveManager.map[pid].enemy_id = enemy_id 

		conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, code, enemy_wealth });
	end);

	service:on(Command.C_PILLAGE_ARENA_FIGHT_CHECK_REQUEST, function (conn, pid, request)
		local cmd = Command.C_PILLAGE_ARENA_FIGHT_CHECK_RESPOND 
		if #request < 2 then
			log.warning(string.format("cmd: %d, param error.", cmd))
			return conn:sendClientRespond(cmd, pid, { request[1] or 1, Command.RET_PARAM_ERROR })
		end
		local sn = request[1]
		local fightResult = request[2]

		log.debug(string.format("cmd: %d, player %d check fight, fightResult is %d", cmd, pid, fightResult))	
		-- 等级限制
		if not OpenlevConfig.isLvOK(pid, 1901) then
			log.debug("open arena level not enough.")
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
		end
		
		-- 判断是否完成新手引导任务
		if not isCompelete(pid) then
			log.debug(string.format("cmd: %d, player %d didn't complete fresh task.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end

		if fight_result(pid, fightResult, true) then	
			conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
		else
			log.warning(string.format("cmd: %d, player %d check fight failed.", cmd, pid))
			conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
	end)

	service:on(Command.C_PILLAGE_ARENA_QUERY_RANK_LIST_REQUEST, function(conn, pid, request)
		local sn = request[1]
		local cmd = Command.C_PILLAGE_ARENA_QUERY_RANK_LIST_RESPOND
		log.debug("Player %d begin to query ranklist", pid)
		
		-- 等级限制
		--[[if not OpenlevConfig.isLvOK(pid, 1901) then
			log.debug("open arena level not enough.")
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
		end
		
		-- 判断是否完成新手引导任务
		if not isCompelete(pid) then
			log.debug(string.format("cmd: %d, player %d didn't complete fresh task.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end--]]
			
		local pillage_arena = PillageArena.Get(getCurrentPeriod())
		if not pillage_arena then
			log.debug("get pillage arena fail")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end

		local rank_list = pillage_arena:GetRankList()

		conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, rank_list});
	end)

	service:on(Command.C_PILLAGE_ARENA_QUERY_LAST_PERIOD_CHAMPION_REQUEST, function(conn, pid, request)
		local sn = request[1]
		local cmd = Command.C_PILLAGE_ARENA_QUERY_LAST_PERIOD_CHAMPION_RESPOND
		log.debug("Player %d begin to query last period champion", pid)
	
		-- 等级限制
		--[[if not OpenlevConfig.isLvOK(pid, 1901) then
			log.debug("open arena level not enough.")
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
		end--]]
	
		-- 判断是否完成新手引导任务
		--[[if not isCompelete(pid) then
			log.debug(string.format("cmd: %d, player %d didn't complete fresh task.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end--]]

		local pillage_arena = PillageArena.Get(getCurrentPeriod() - 1)
		if not pillage_arena then
			log.debug("get pillage arena fail")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end

		local rank_list = pillage_arena:GetRankList()
		local t = {}

		for i =1 ,3, 1 do
			table.insert(t, {rank_list[i].id, rank_list[i].value})
		end

		conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, t});
	end)

	service:on(Command.C_PILLAGE_ARENA_QUERY_FORMATION_REQUEST, function(conn, pid, request)
		local sn = request[1]
		local type = request[2]
		local cmd = Command.C_PILLAGE_ARENA_QUERY_FORMATION_RESPOND

		if not type then
			log.debug("2nd param type is nil")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end

		log.debug("Player %d begin to query formation type %d", pid, type)
	
		-- 等级限制
		if not OpenlevConfig.isLvOK(pid, 1901) then
			log.debug("open arena level not enough.")
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
		end
	
		-- 判断是否完成新手引导任务
		if not isCompelete(pid) then
			log.debug(string.format("cmd: %d, player %d didn't complete fresh task.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
	
		local player_formation = ArenaFormation.Get(pid)
		if not player_formation then
			log.debug("get formation fail")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end

		local ret = player_formation:QueryFormation(type)

		conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, ret});
	end)

	service:on(Command.C_PILLAGE_ARENA_CHANGE_FORMATION_REQUEST, function(conn, pid, request)
		local sn = request[1]
		local type = request[2]
		local role1 = request[3]
		local role2 = request[4]
		local role3 = request[5]
		local role4 = request[6]
		local role5 = request[7]

		local cmd = Command.C_PILLAGE_ARENA_CHANGE_FORMATION_RESPOND

		if not type or not role1 or not role2 or not role3 or not role4 or not role5 then
			log.debug("param is nil")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end

		log.debug(string.format("Player %d begin to change formation (%d, %d, %d, %d, %d)", pid, type, role1, role2, role3, role4, role5))
			
		-- 等级限制
		if not OpenlevConfig.isLvOK(pid, 1901) then
			log.debug("open arena level not enough.")
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
		end
	
		-- 判断是否完成新手引导任务
		if not isCompelete(pid) then
			log.debug(string.format("cmd: %d, player %d didn't complete fresh task.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end

		local player_formation = ArenaFormation.Get(pid)
		if not player_formation then
			log.debug("get formation fail")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end

		local ret 
		if type ~= 3 then
		 	ret = player_formation:ChangeFormation(type, role1, role2, role3, role4, role5)
		else
		 	ret = player_formation:ChangeFormation(1, role1, role2, role3, role4, role5)
		 	ret = player_formation:ChangeFormation(2, role1, role2, role3, role4, role5)
		end

		conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR});
	end)	

	service:on(Command.C_PILLAGE_ARENA_QUERY_PLAYER_INFO_REQUEST, function(conn, pid, request)
		local sn = request[1]
		local target = request[2] or pid
		local cmd = Command.C_PILLAGE_ARENA_QUERY_PLAYER_INFO_RESPOND

		log.debug(string.format("Player %d begin to query pillage arena player info", pid))
	
		-- 等级限制
		if not OpenlevConfig.isLvOK(target, 1901) then
			log.debug("open arena level not enough.")
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
		end
	
		-- 判断是否完成新手引导任务
		if not isCompelete(target) then
			log.debug(string.format("cmd: %d, player %d didn't complete fresh task.", cmd, target))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
	
		local pillage_arena = PillageArena.Get(getCurrentPeriod())
		if not pillage_arena then
			log.debug("get pillage arena fail")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end

		local ret = pillage_arena:Info(target)

		log.debug(sprinttb(ret))

		conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR, ret});
	end)

	service:on(Command.C_PILLAGE_ARENA_QUERY_PLAYER_LOG_REQUEST, function(conn, pid, request)
		local sn = request[1]
		local cmd = Command.C_PILLAGE_ARENA_QUERY_PLAYER_LOG_RESPOND

		log.debug("Player %d begin to query pillage arena player log", pid)
	
		-- 等级限制
		if not OpenlevConfig.isLvOK(pid, 1901) then
			log.debug("open arena level not enough.")
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
		end
		
		-- 判断是否完成新手引导任务
		if not isCompelete(pid) then
			log.debug(string.format("cmd: %d, player %d didn't complete fresh task.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
	
		local player_log = ArenaLog.Get(getCurrentPeriod(), pid)
		if not player_log then
			log.debug("get player log fail")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
		end

		local ret = player_log:GetLog(pid)

		conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, ret});
	end)
	
	-- 开始pvp匹配
	service:on(Command.C_PILLAGE_MATCH_REQUEST, function(conn, pid, request)
		local cmd = Command.C_PILLAGE_MATCH_RESPOND

		log.debug(string.format("cmd: %d, player %d start pvp match.", cmd, pid))

		if type(request) ~= "table" or #request < 1 then
			log.warning(string.format("cmd: %d, param error", cmd))			
			return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
		end
		local sn = request[1]	
	
		-- 等级限制
		if not OpenlevConfig.isLvOK(pid, 1901) then
			log.debug("open arena level not enough.")
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
		end
			
		-- 判断是否完成新手引导任务
		if not isCompelete(pid) then
			log.debug(string.format("cmd: %d, player %d didn't complete fresh task.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end

		-- 查看匹配次数是否满足要求	
		local pillage_arena = PillageArena.Get(getCurrentPeriod())
		local today_match_count = pillage_arena:GetTodayMatchCount(pid)
		if today_match_count and today_match_count >= ArenaFightConfig.get_match_count(2) then
			log.warning(string.format("cmd: %d, match count can not beyond 10", cmd))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
		end		

		-- 判断是否处于开启时间
		if not ArenaFightConfig.is_range(2) then
			log.warning(string.format("cmd: %d, not in start time.", cmd))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })	
		end

		-- 判断是否已经开始pve匹配
		if PveManager.map[pid] then
			log.warning(string.format("cmd: %d, player %d have been start pve.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end

		-- 添加到匹配池中
		local code = match_pool.add(pid)
		if match_pool.co == nil then
			match_pool.co = RunThread(match_pool.do_match)
		end
	
		return conn:sendClientRespond(cmd, pid, { sn, code })	
	end)

	-- 取消匹配
	service:on(Command.C_PILLAGE_MATCH_CANCEL_REQUEST, function(conn, pid, request)
		local cmd = Command.C_PILLAGE_MATCH_CANCEL_RESPOND
		log.debug(string.format("%d, player %d cancel match.", cmd, pid))

		if type(request) ~= "table" or #request < 1 then
			log.warning(string.format("cmd: %d, param error", cmd))			
			return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
		end

		local sn = request[1]
	
		-- 等级限制
		if not OpenlevConfig.isLvOK(pid, 1901) then
			log.debug("open arena level not enough.")
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
		end
		
		-- 判断是否完成新手引导任务
		if not isCompelete(pid) then
			log.debug(string.format("cmd: %d, player %d didn't complete fresh task.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
		
		-- 从匹配池中移出玩家
		local code = match_pool.remove(pid)
		return conn:sendClientRespond(cmd, pid, { sn, code })		
	end)

	-- 申请开始战斗
	service:on(Command.C_PILLAGE_APPLY_FIGHT_REQUET, function(conn, pid, request)
		local cmd = Command.C_PILLAGE_APPLY_FIGHT_RESPOND 
		if type(request) ~= "table" or #request < 1 then
			log.warning(string.format("cmd: %d, param error", cmd))	
			return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
		end
		local sn = request[1]
	
		-- 等级限制
		if not OpenlevConfig.isLvOK(pid, 1901) then
			log.debug("open arena level not enough.")
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
		end
		
		-- 判断是否完成新手引导任务
		if not isCompelete(pid) then
			log.debug(string.format("cmd: %d, player %d didn't complete fresh task.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
		
		local flag, index = match_pool.is_fight(pid)
		local t = match_pool.fight_list[index]
		if flag and t.is_start == false then
			t.is_start = true
			RunThread(prepare_fight, t[1], t[2])	
			conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })		
		else
			log.warning(string.format("cmd: %d, there is no pvp fight.", cmd))
			conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
	end)

	service:on(Command.NOTIFY_ARENA_AI_ENTER, "ArenaAIEnterNotify", function(conn, channel, request)
		local id = request.id 
		--log.debug("ai id is ", id)	
		local pillage_arena = PillageArena.Get(getCurrentPeriod())
		pillage_arena:loadPvpAI(id)
	end)
	
	service:on(Command.C_PILLAGE_ADD_WEALTH_REQUEST, function(conn, pid, request)
		local cmd = Command.C_PILLAGE_ADD_WEALTH_RESPOND 
		log.debug(string.format("cmd: %d, add wealth, pid is %d.", cmd, pid))

		if type(request) ~= "table" or #request < 2 then
			log.warning(string.format("cmd: %d, param error.", cmd))	
			return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })		
		end
	
		local sn = request[1] or 0
		local wealth = request[2]

		local filename = "../log/enable_reward_from_client"
		if not util.file_exist(filename) then
			log.warning(string.format("cmd: %d, file %s is not exist.", cmd, filename))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
		end	
					
		local pillageArena = PillageArena.Get(getCurrentPeriod())
		local old = pillageArena:GetWealth(pid) or 0

		if pillageArena and pillageArena:SetWealth(pid, wealth + old) then
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
		else
			log.warning(string.format("cmd: %d, add wealth failed, pid = %d, wealth = %d", cmd, pid, wealth))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
	end)	

	service:on(Command.C_PILLAGE_CLOSE_PVE_FIGHT_REQUEST, function (conn, pid, request)
		local cmd = Command.C_PILLAGE_CLOSE_PVE_FIGHT_RESPOND
		log.debug(string.format("cmd: %d, attempt close last pve fight.", cmd, pid))

		if type(request) ~= "table" or #request < 1 then
			log.warning(string.format("cmd: %d, param error.", cmd))	
			return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })			
		end
		local sn = request[1] or 0

		if PveManager.map[pid] and PveManager.map[pid].enemy_id ~= 0 then
			RunThread(auto_fight, pid, PveManager.map[pid].enemy_id)			
		end

		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
	end)
end

function PillageArena.Login(pid)
	player_online[pid] = true

	for i = getCurrentPeriod(), getCurrentPeriod() - 1, -1 do
		local pillage_arena = PillageArena.Get(i)
		if pillage_arena then
			pillage_arena:SendRemainReward(pid)
		end
	end


end

function PillageArena.Logout(pid)
	if player_online[pid] then
		player_online[pid] = nil
	end

	log.info(string.format("%d logout.", pid))	
	-- 从匹配池中移出玩家
	match_pool.remove(pid)
	-- 从战斗队列中移除已经准备开始战斗，但是还没收到客户端开始战斗的通知的玩家
	match_pool.removeNotFightPlayer(pid)
end

function add_wealth(conn, channel, request)
	local protocol = "aGameRespond"
	local sn = request.sn
	local pid = request.pid
	local wealth = request.wealth
	local cmd = Command.S_ARENA_ADD_WEALTH_RESPOND
	
	log.debug("gm add wealth, pid, wealth = ", pid, wealth)

	if channel ~= 0 then
		log.warning(string.format("cmd: %d, gm add wealth failed, channel is not 0."), cmd)
		return sendServiceRespond(conn, cmd, channel, protocol, { sn = sn, result = Command.RET_ERROR })
	end	
		
	local pillageArena = PillageArena.Get(getCurrentPeriod())
	local respond = { sn = sn }	
	local old = pillageArena:GetWealth(pid) or 0
	if pillageArena and pillageArena:SetWealth(pid, wealth + old) then
		respond.result = Command.RET_SUCCESS
	else
		log.warning(string.format("cmd: %d, gm add wealth failed, pid = %d, wealth = %d", cmd, pid, wealth))
		respond.result = Command.RET_ERROR
	end

	sendServiceRespond(conn, cmd, channel, protocol, respond)
end

return PillageArena
