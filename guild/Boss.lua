local EventManager = require "EventManager"
local Class = require "Class"
require "printtb"
require "yqlog_sys"
local yqinfo = yqinfo
local sprinttb = sprinttb
local PlayerManager = require "PlayerManager"
local BinaryConfig = require "BinaryConfig"

local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));		
		return nil;
	end
	return code;
end

Event = {
	CHANGE = "change",
};

local Rank = {}

function Rank:_init_(...)
	self.items = {};
	self.ranks = {};
	self.em = EventManager.New();
end

function Rank:getRank(id)
	if self.items[id] then
		return self.items[id].rank;
	else
		return nil;
	end
end

function Rank:RegisterEvent(event, func)
	local listener = self.em:CreateListener();
	listener:RegisterEvent(Event.CHANGE, func) 
end

function Rank:getValue(id)
	if self.items[id] then
		return self.items[id].value;
	else
		return nil;
	end
end

function Rank:add(id)
	assert(self.items[id] == nil);

	local pos = table.maxn(self.ranks) + 1;
	local item = {
		id = id;
		value = 0;
		rank = pos
	};

	self.items[id] = item;
	self.ranks[pos] = item;

	return pos;
end
	
function Rank:setValue(id, value)
	local oldrank = self:getRank(id) or self:add(id);
	local newrank = oldrank;

	local item = self.items[id];
	if value == item.value then
		return item.rank;
	end

	local step = -1;
	local change = 1;
	local stop = 1;

	if value < item.value then
		step = 1;
		change = -1;
		stop = table.maxn(self.ranks);
	end

	item.value = value;

	for ite = oldrank, stop, step do
		local front = self.ranks[ite + step];
		if front == nil or front.value >= value then
			self.ranks[ite] = item;
			self.em:DispatchEvent(Event.CHANGE, {id = id, o = item.rank, n = ite});
			item.rank = ite;
			break;
		else
			self.ranks[ite] = front;
			self.em:DispatchEvent(Event.CHANGE, {id = front.id, o = ite - 1, n = ite});
			front.rank = ite;
		end
	end
	return item.rank;
end

function Rank:remove(id)
	local item = self.items[id];
	if item == nil then
		return;
	end

	self.items[id] = nil;

	local total = table.maxn(self.ranks);
	for ite = item.rank, total do
		local back = self.ranks[ite + 1];
		self.ranks[ite] = back;

		if back then
			self.em:DispatchEvent(Event.CHANGE, {id = back.id, o = ite - 1, n = ite});
			back.rank = ite;
		end
	end
end

function Rank:dump()
	print("Rank dump");
	for _, item in ipairs(self.ranks) do
		print("", item.rank, item.id, item.value);
	end
end

function Rank:GetTop(count)
    local max_count = count;
    local t = {}
    for _, item in ipairs(self.ranks) do
        if max_count and #t + 1 > max_count then
            break;
        end
        table.insert(t, {item.id,item.value})
    end
    return t
end

function Rank.New(...)
	return Class.New(Rank, ...);
end

local BossConfig 
local function LoadBossConfig()
	local rows = BinaryConfig.Load("guild_boss", "guild")
	BossConfig = {}

	for _, row in ipairs(rows) do
        	BossConfig[row.activity_id] = BossConfig[row.activity_id] or {
			activity_id = row.activity_id,
			type = row.type,
			begin_time = row.begin_time,
			end_time = row.end_time,
			period = row.period,
			duration = row.duration,
			boss_id = row.boss_id,
			boss_last_time = row.boss_last_time,
			max_fight_count = row.max_fight_count,
			wealth_cost	= row.wealth_cost,
			boss_id_client = row.boss_id_client,
		}
	print("-----" .. row.wealth_cost)
    end
end

LoadBossConfig()

function GetBossConfig(activity_id)
	if not activity_id then
		return BossConfig
	end

	return BossConfig[activity_id]
end

local function insertItem(t, type, id, value)
	if not type or type == 0 then
		return 
	end

	if not id or id == 0 then
		return 
	end

	if not value or value == 0 then
		return 
	end

	table.insert(t, {type = type, id = id, value = value})
end

local BossRewardConfig
local function LoadBossRewardConfig()
	local rows = BinaryConfig.Load("config_guild_boss_reward", "guild")
	BossRewardConfig = {}
	
	for _, row in ipairs(rows) do
		BossRewardConfig[row.activity_id] = BossRewardConfig[row.activity_id] or {}
		table.insert(BossRewardConfig[row.activity_id], {lower_limit = row.lower_limit, upper_limit = row.upper_limit, reward = {} })
		local idx = #BossRewardConfig[row.activity_id]
		insertItem(BossRewardConfig[row.activity_id][idx].reward, row.reward_type1, row.reward_id1, row.reward_value1)
		insertItem(BossRewardConfig[row.activity_id][idx].reward, row.reward_type2, row.reward_id2, row.reward_value2)
		insertItem(BossRewardConfig[row.activity_id][idx].reward, row.reward_type3, row.reward_id3, row.reward_value3)
	end
end

LoadBossRewardConfig()

function GetBossRewardConfig(activity_id, rank)
	if not BossRewardConfig[activity_id] then
		return nil
	end	

	for k, v in ipairs(BossRewardConfig[activity_id]) do
		if rank >= v.lower_limit and rank <= v.upper_limit then
			return v.reward
		end
	end

	return nil
end

local online = {}
local function PlayerOnline(pid)
	return online[pid]
end

local ONE_WEEK = 7 * 3600 * 24

local BOSS_TYPE_WORLD = 1 
local BOSS_TYPE_GUILD = 2 

local BossOpenManager = {}

function BossOpenManager.New(activity_id, period, group_id, begin_time, end_time, settle_reward)
	log.debug(string.format("load Boss open info for activity_id %d, period %d, group_id %d", activity_id, period, group_id))
	local cfg = GetBossConfig(activity_id)
	if not cfg then
		log.error(string.format("Fail to load Boss open info for activity %d, config is nil", activity_id))
		return nil
	end
	
	local t = {
		activity_id = activity_id,
		period = period,
		group_id = group_id,
		type = cfg.type,
		begin_time = begin_time,
		end_time = end_time,
		settle_reward = settle_reward,
	}

	return setmetatable(t, {__index = BossOpenManager})
end

function BossOpenManager:IsOpen()
	local now = loop.now()
	if now < self.begin_time or now >= self.begin_time then
		return false
	end

	return true
end

local function DOReward(pid, reward, consume, reason, manual, limit, name)
	assert(reason and reason ~= 0)

	local respond = cell.sendReward(pid, reward, consume, reason, manual, limit, name)
	if respond == nil or respond.result ~= 0 then
		return false;
	end
	return true;
end

function BossOpenManager:SettleReward(pid)
	if self.type == BOSS_TYPE_GUILD then
		if not PlayerOnline(pid) then
			return
		end

		local boss = GetBoss(self.activity_id, self.period, self.group_id) 
		if not boss then
			return 
		end

		if loop.now() < self.end_time then
			return 
		end

		local player_reward_flag = boss:GetPlayerRewardFlag(pid)
		if not player_reward_flag or player_reward_flag == 1 then
			return 
		end

		--send reward
		local rank = boss:GetPlayerRank(pid)
		local reward = GetBossRewardConfig(self.activity_id, rank)
		print("reward>>>>>>>>>>>>>>>>>>>>>", sprinttb(reward))
		if reward then
			DOReward(pid, reward, nil, Command.REASON_GUILD_BOSS_REWARD, false, 0)
		end
		boss:SetPlayerRewardFlag(pid, 1)	
	end
end

function BossOpenManager:AlreadySettleReward()
	return self.settle_reward == 1
end

function BossOpenManager:SetSettleReward(value)
	self.settle_reward = value 
	database.update("update boss_open set settle_reward = %d where activity_id = %d and period = %d and group_id = %d", value, self.activity_id, self.period, self.group_id)
end

function BossOpenManager:DeleteSelf()
	DeleteBossOpen(self.activity_id, self.group_id, self.period)
end

local BossOpen = {}
local function GetBossOpen(activity_id, group_id, period)
	if not BossOpen[activity_id] then
		return nil
	end

	if not BossOpen[activity_id][group_id] then
		return nil
	end

	if not BossOpen[activity_id][group_id][period] then
		return nil
	end

	return BossOpen[activity_id][group_id][period]
end

function DeleteBossOpen(activity_id, group_id, period)
	if BossOpen[activity_id] and BossOpen[activity_id][group_id] and BossOpen[activity_id][group_id][period] then
		BossOpen[activity_id][group_id][period] = nil
	end
end

local function InitBossOpen(activity_id, group_id, period, begin_time, end_time, settle_reward)
	BossOpen[activity_id] = BossOpen[activity_id] or {}	
	BossOpen[activity_id][group_id] = BossOpen[activity_id][group_id] or {}	
	BossOpen[activity_id][group_id][period] = BossOpen[activity_id][group_id][period] or BossOpenManager.New(activity_id, period, group_id, begin_time, end_time, settle_reward)	
end

local function LoadBossOpenInfo()
	local success, result = database.query("select activity_id, period, group_id, settle_reward, unix_timestamp(begin_time) as begin_time, unix_timestamp(end_time) as end_time from boss_open where end_time > from_unixtime_s(%d)", loop.now() - ONE_WEEK)
	if success then
		if #result > 0 then
			for i = 1, #result, 1 do
				local row = result[i]
				InitBossOpen(row.activity_id, row.group_id, row.period, row.begin_time, row.end_time, row.settle_reward)
			end
		end
	end

	--auto open boss
end

-- lan add
local function Notify(gid,msg)  
	print('===========================Notify')
	local guild = GuildManager.Get(gid);
	print('===========================Notify')
        if guild then
                EventManager.DispatchEvent("GUILD_BOSS_OPEN", {guild = guild, message = msg});
        end
end

local function OpenBoss(activity_id, period, group_id, begin_time, end_time)
	if BossOpen[activity_id] and BossOpen[activity_id][group_id] and BossOpen[activity_id][group_id][period] then
		log.error(string.format("boss for activity_id %d, group %d, period %d already open", activity_id, group_id, period))
		return false
	end

	InitBossOpen(activity_id, group_id, period, begin_time, end_time, 0)	
	database.update("insert into boss_open(activity_id, period, group_id, settle_reward, begin_time, end_time) values(%d, %d, %d, 0, from_unixtime_s(%d), from_unixtime_s(%d))", activity_id, period, group_id, begin_time, end_time)

	return true
end

LoadBossOpenInfo()

local Boss = {}
function Boss.New(activity_id, period, group_id)
	log.debug(string.format("load Boss activity_id %d, period %d, group_id %d", activity_id, period, group_id))
	local cfg = GetBossConfig(activity_id)
	if not cfg then
		log.error(string.format("Fail to load Boss for activity %d, config is nil", activity_id))
		return nil
	end

	local t = {
		activity_id = activity_id,
		period = period,
		group_id = group_id,
		type = cfg.type,
		rank_list = Rank.New(),
		reward_flag = {}, 
		fight_count = {}
	}

	local success, result = database.query("select activity_id, period, group_id, id, damage, reward_flag, fight_count, unix_timestamp(update_time) as update_time from Boss where activity_id = %d and period = %d and group_id = %d", activity_id, period, group_id);

	if success then
		if #result > 0 then
			for i = 1, #result, 1 do
				local row = result[i]
				t.rank_list:setValue(row.id, row.damage)
				t.reward_flag[row.id] = row.reward_flag
				t.fight_count[row.id] = row.fight_count
			end
		end
	end

	return setmetatable(t, {__index = Boss})
end

function Boss:GetPlayerDamage(id)
	return self.rank_list:getValue(id)
end

function Boss:GetPlayerRewardFlag(id)
	return self.reward_flag[id]
end

function Boss:SetPlayerRewardFlag(id, flag)
	if not self.reward_flag[id] then
		return 
	end

	self.reward_flag[id] = flag
	database.update("update Boss set reward_flag = %d where activity_id = %d and period = %d and group_id = %d and id = %d", flag, self.activity_id, self.period, self.group_id, id)
end

function Boss:GetPlayerRank(id)
	return self.rank_list:getRank(id)	
end

function Boss:GetRankList(count)
	return self.rank_list:GetTop(count)
end

function Boss:GetAttendPlayers()
	return self.rank_list:GetTop()
end

function Boss:AttendActivity(id)
	return self.rank_list:getValue(id) ~= nil
end

function Boss:UpdatePlayerDamage(id, damage)
	if not self.rank_list:getValue(id) then
		database.update("insert into Boss(activity_id, period, group_id, id, damage, update_time, reward_flag, fight_count) values(%d, %d, %d, %d, %d, from_unixtime_s(%d), %d, %d)", self.activity_id, self.period, self.group_id, id, damage, loop.now(), 0, 0)
		self.reward_flag[id] = 0
		self.fight_count[id] = 0
	else
		database.update("update Boss set damage = %d, update_time = from_unixtime_s(%d) where activity_id = %d and period = %d and group_id = %d and id = %d", damage, loop.now(), self.activity_id, self.period, self.group_id, id)
	end

	self.rank_list:setValue(id, damage)
end

function Boss:GetPlayerFightCount(id)
	return self.fight_count[id]
end

function Boss:SetPlayerFightCount(id, value)
	if not self.fight_count[id] then
		return 
	end

	self.fight_count[id] = value
	database.update("update Boss set fight_count = %d, update_time = from_unixtime_s(%d) where activity_id = %d and period = %d and group_id = %d and id = %d", value, loop.now(), self.activity_id, self.period, self.group_id, id)

end

local AllBoss = {}
function GetBoss(activity_id, period, group_id) 
	if not AllBoss[activity_id] then
		AllBoss[activity_id] = {}
	end	

	if not AllBoss[activity_id][group_id] then
		AllBoss[activity_id][group_id] = {}
	end

	if not AllBoss[activity_id][group_id][period] then
		AllBoss[activity_id][group_id][period] = Boss.New(activity_id, period, group_id)
	end

	return AllBoss[activity_id][group_id][period]
end

local function CheckAndSendReward(pid)
	for activity_id, v1 in pairs(BossOpen) do
		for group_id, v2 in pairs(v1) do
			for period, manager in pairs(v2) do
				local boss = GetBoss(manager.activity_id, manager.period, manager.group_id)
				if loop.now() > manager.end_time and boss:AttendActivity(pid) then
					manager:SettleReward(pid)
				end	
			end
		end
	end
end

Scheduler.Register(function(now)
	if now % 5 == 0 then
		local t = {}
		for activity_id, v1 in pairs(BossOpen) do
			for group_id, v2 in pairs(v1) do
				for period, manager in pairs(v2) do
					if loop.now() > manager.end_time and not manager:AlreadySettleReward() then
						local boss = GetBoss(manager.activity_id, manager.period, manager.group_id)
						local player_list = boss:GetAttendPlayers()	
						if player_list then
							for k, v in ipairs(player_list) do
								if PlayerOnline(v.id) then
									manager:SettleReward(v.id)
									print(string.format("send reward for player %d", v.id))
								end
							end
						end

						manager:SetSettleReward(1)
					end	

					-- 删除过期数据
					if loop.now() - manager.end_time > ONE_WEEK then
						table.insert(t, manager)	
					end
				end
			end
		end		

		if #t > 0 then
			for _, manager in ipairs(t) do
				manager:DeleteSelf()
			end
		end
	end
end)

function Boss.Login(pid)
	online[pid] = true;
	CheckAndSendReward(pid)
end

function Boss.Logout(pid)
	online[pid] = nil
end



local function GetNowPeriod(activity_id)
	local cfg = GetBossConfig(activity_id)
	if not cfg then
		return nil
	end

	local begin_time = cfg.begin_time
	local end_time = cfg.end_time
	local period = cfg.period
	local duration = cfg.duration

	return math.ceil((loop.now() + 1 - begin_time) / period)
end

local function CanOpenBoss(activity_id)
	local cfg = GetBossConfig(activity_id)
	if not cfg then
		return false 
	end

	local begin_time = cfg.begin_time
	local end_time = cfg.end_time
	local period = cfg.period
	local duration = cfg.duration

	if loop.now() < begin_time or loop.now() >= end_time then
		return false
	end
	
	if (loop.now() + 1 - begin_time ) % period > duration then
		return false
	end 
	
	return true
end

--logic
local function getGuildid(playerid)
	local player = PlayerManager.Get(playerid)
        if not player then
		return false
	end
	local guild = player.guild
	if not guild then
		log.debug(string.format("player %d donnt has guild", playerid))
		return false
	end

        return guild.id
	
end

local function query_boss_open_config()
	local cfg = GetBossConfig()
	local amf = {}	
	for k, v in pairs(cfg) do
		print('====================================v.wealth_cost:' .. v.wealth_cost )
		table.insert(amf, {v.activity_id, v.type, v.begin_time, v.end_time, v.period, v.duration ,v.boss_id,v.wealth_cost, v.boss_id_client })
	end

	return amf
end

local function query_boss_info(playerid, activity_id)
	log.debug(string.format("player %d query boss info for activity_id %d", playerid, activity_id))
	local cfg = GetBossConfig(activity_id)
	if not cfg then
		return false
	end

	local group_id = 1
	if cfg.type == BOSS_TYPE_GUILD then
		local player = PlayerManager.Get(playerid)
		if not player then
			return false
		end

		local guild = player.guild 
		if not guild then
			log.debug(string.format("player %d donnt has guild", playerid))
			return false
		end

		group_id = guild.id
	end

	local period = GetNowPeriod(activity_id)	
	if not period then
		return false
	end

	local open_manager = GetBossOpen(activity_id, group_id, period)
	if not open_manager then
		log.debug("boss not open")
		return false
	end

	return {open_manager.activity_id, open_manager.group_id, open_manager.period, open_manager.begin_time, open_manager.end_time}
end

local function open_boss(playerid, activity_id)
	log.debug(string.format("player %d open boss for activity_id %d", playerid, activity_id))
	local cfg = GetBossConfig(activity_id)
	if not cfg then
		return false
	end

	local group_id = 1
	if cfg.type == BOSS_TYPE_GUILD then
		local player = PlayerManager.Get(playerid)
		if not player then
			return false
		end

		local guild = player.guild 
		if not guild then
			log.debug(string.format("player %d donnt has guild", playerid))
			return false
		end

		group_id = guild.id
	
		if guild.leader.id ~= playerid then
			log.debug('player not leader')
			return false
		end
	end

--	if not CanOpenBoss(activity_id) then
--		log.debug("not on time to open boss")	
--		return false
--	end	
	
	local period = GetNowPeriod(activity_id)
	return OpenBoss(activity_id, period, group_id, loop.now(), loop.now() + cfg.boss_last_time)
end

local fight = {}
local function RecordFight(pid, activity_id)
	fight[pid] = fight[pid] or {}	
	fight[pid][activity_id] = true
end

local function HasFight(pid, activity_id)
	if not fight[pid] then
		return false
	end

	if not fight[pid][activity_id] then
		return false
	end

	return true
end

local function CleanFight(pid, activity_id)
	if fight[pid] then
		fight[pid][activity_id] = nil
	end
end

local function fight_prepare(playerid, activity_id)
	log.debug(string.format("player %d query boss fight data for activity_id %d", playerid, activity_id))

	local cfg = GetBossConfig(activity_id)
	if not cfg then
		return false
	end

	local group_id = 1
	if cfg.type == BOSS_TYPE_GUILD then
		local player = PlayerManager.Get(playerid)
		if not player then
			return false
		end

		local guild = player.guild 
		if not guild then
			log.debug(string.format("player %d donnt has guild", playerid))
			return false
		end

		group_id = guild.id
	end

	local period = GetNowPeriod(activity_id)
	local open_manager = GetBossOpen(activity_id, group_id, period)
	if not open_manager then
		log.debug("boss not open")
		return false
	end

	local boss = GetBoss(activity_id, period, group_id)
	local fight_count = boss:GetPlayerFightCount(playerid)
	if fight_count and fight_count >= cfg.max_fight_count then
		log.debug("fight count not enough")
		return false
	end

	attacker, err = cell.QueryPlayerFightInfo(playerid, false, 0)
	if err then
		log.debug(string.format('load fight data of player %d error %s', playerid, err))
		return false
	end

	defender, err = cell.QueryPlayerFightInfo(cfg.boss_id, true, 100)
	if err then
		log.debug(string.format('load fight data of fight %d error %s', cfg.boss_id, err))
		return false
	end
	
	scene = "18hao"

	local fightData = {
		attacker = attacker,
		defender = defender,
		seed = math.random(1, 0x7fffffff),
		scene = scene,
	}

	local code = encode('FightData', fightData);
	RecordFight(playerid, activity_id)

	return code
	--local fight_data = cell.
end

local function fight_check(playerid, activity_id, damage)
	log.debug(string.format("player %d fight check(guild boss) for activity_id %d damage %d", playerid, activity_id, damage))

	if not HasFight(playerid, activity_id) then
		log.debug("player not has fight for boss, fight check fail")
		return false
	end

	local cfg = GetBossConfig(activity_id)
	if not cfg then
		return false
	end

	local group_id = 1
	if cfg.type == BOSS_TYPE_GUILD then
		local player = PlayerManager.Get(playerid)
		if not player then
			return false
		end

		local guild = player.guild 
		if not guild then
			log.debug(string.format("player %d donnt has guild", playerid))
			return false
		end

		group_id = guild.id
	end

	local period = GetNowPeriod(activity_id)
	local open_manager = GetBossOpen(activity_id, group_id, period)
	if not open_manager then
		log.debug("boss not open")
		return false
	end

	local boss = GetBoss(activity_id, period, group_id)
	local old_damage = boss:GetPlayerDamage(playerid)
	if not old_damage then
		old_damage = 0
	end
	boss:UpdatePlayerDamage(playerid, old_damage + damage)

	local old_fight_count = boss:GetPlayerFightCount(playerid)
	if not fight_count then
		fight_count = 0
	end
	boss:SetPlayerFightCount(playerid, old_fight_count + 1)

	return true
end

local function query_rank_list(playerid, activity_id, period)
	log.debug(string.format("player %d query ranklist for activity_id %d period %d", playerid, activity_id, period))

	local cfg = GetBossConfig(activity_id)
	if not cfg then
		return false
	end

	local group_id = 1
	if cfg.type == BOSS_TYPE_GUILD then
		local player = PlayerManager.Get(playerid)
		if not player then
			return false
		end

		local guild = player.guild 
		if not guild then
			log.debug(string.format("player %d donnt has guild", playerid))
			return false
		end

		group_id = guild.id
	end

	local boss = GetBoss(activity_id, period, group_id)
	if not boss then
		return {}
	end

	local rank_list = boss:GetRankList(30)
	return rank_list
end

--test
--[[print("test begin >>>>>>>>>>")
local cfg = query_boss_open_config()
print("boss open cfg >>>>>>>>>>>>>>>", sprinttb(cfg))

print("open boss>>>>>>>>>>>>>>>")
open_boss(146028988202, 1)

local info = query_boss_info(146028988202, 1)
print("boss info >>>>>>>>>>>>>>>>", sprinttb(info))

print("boss fight prepare >>>>>>>>>>>>>")
fight_prepare(146028988202, 1)
fight_check(146028988202, 1, 1000)

fight_prepare(146028988218, 1)
fight_check(146028988218, 1, 50000)

local rank_list = query_rank_list(146028988202, 1, 1)
print("rank_list >>>>>>>>>>>>>>>>>", sprinttb(rank_list))

print("send reward >>>>>>>>>>>>>>>>>>")
Boss.Login(146028988202)--]]

local function queryBossCurInfo(playerid, activity_id)
	local cfg = GetBossConfig(activity_id)
        if not cfg then
                return false
        end

        local group_id = 1
        if cfg.type == BOSS_TYPE_GUILD then
                local player = PlayerManager.Get(playerid)
                if not player then
			log.debug(string.format("player %d is not exsist", playerid))
                        return false
                end

                local guild = player.guild
                if not guild then
                        log.debug(string.format("player %d donnt has guild", playerid))
			return false
                end

                group_id = guild.id
        end

        local period = GetNowPeriod(activity_id)
        local open_manager = GetBossOpen(activity_id, group_id, period)
        if not open_manager then
                log.debug("boss not open")
		return false
        end

        local boss = GetBoss(activity_id, period, group_id)
        local _damage = boss:GetPlayerDamage(playerid)
        if not _damage then
                _damage = 0
        end
	
	return { isOpen = true, damage = _damage ,activity_id = activity_id }
end

local function queryAllBossCurInfo(playerid)
	for id,v in pairs(BossConfig) do
		local res = queryBossCurInfo(playerid,id)
		if res then
			return res	
		end
	end

	return { isOpen = false, damage = 0,activity_id = 0 }
end

local function costGuildWealth(pid, activity_id)
	print('==============================wealth cost start')
	local player = PlayerManager.Get(pid)
	if not player then
                        log.debug(string.format("player %d is not exsist", pid))
                        return false
        end	
	print('---------------------------------------')
	local guild = player.guild
        assert(guild)
	
	print('=============================costwealth ............')
	local value = BossConfig[activity_id].wealth_cost

        return guild:CostWealth(player,value)
end

function Boss.RegisterCommand(service)
	service:on(Command.C_GUILD_BOSS_QUERY_OPEN_CONFIG_REQUEST, function(conn, playerid, request)
		local cmd = Command.C_GUILD_BOSS_QUERY_OPEN_CONFIG_RESPOND
		local sn = request[1]
		local ret = query_boss_open_config()

		return conn:sendClientRespond(cmd, playerid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR, ret})
	end)

	service:on(Command.C_GUILD_BOSS_QUERY_INFO_REQUEST, function(conn, playerid, request)
		local cmd = Command.C_GUILD_BOSS_QUERY_INFO_RESPOND	
		local sn = request[1]
		local activity_id = request[2]
		if not activity_id then
			log.debug("param 2nd activity_id is nil")
			return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_PARAM_ERROR})
		end

		local ret = query_boss_info(playerid, activity_id)
		return conn:sendClientRespond(cmd, playerid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR, ret})
	end)

	service:on(Command.C_GUILD_BOSS_OPEN_REQUEST, function(conn, playerid, request)
		local cmd = Command.C_GUILD_BOSS_OPEN_RESPOND
		local sn = request[1]
		local activity_id = request[2]
		if not activity_id then
			log.debug("param 2nd activity_id is nil")
			return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_PARAM_ERROR})
		end
		
		local guild_id = getGuildid(playerid)


		
		local cost = costGuildWealth(playerid, activity_id)
		if cost then
			local ret = open_boss(playerid, activity_id)
			if ret then
				local msg = activity_id
				
				conn:sendClientRespond(cmd, playerid, {sn, Command.RET_SUCCESS})
				return Notify(guild_id,msg)  ---- broadcast
			end
		end

		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR })
	end)

	service:on(Command.C_GUILD_BOSS_QUERY_RANKLIST_REQUEST, function(conn, playerid, request)
		local cmd = Command.C_GUILD_BOSS_QUERY_RANKLIST_RESPOND	
		local sn = request[1]
		local activity_id = request[2]
		if not activity_id then
			log.debug("param 2nd activity_id is nil")
			return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_PARAM_ERROR})
		end

		local period = GetNowPeriod(activity_id)
		local ret = query_rank_list(playerid, activity_id, period)
		return conn:sendClientRespond(cmd, playerid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR, ret})
	end)

	service:on(Command.C_GUILD_BOSS_FIGHT_PREPARE_REQUEST, function(conn, playerid, request)
		local cmd = Command.C_GUILD_BOSS_FIGHT_PREPARE_RESPOND
		local sn = request[1]
		local activity_id = request[2]
		if not activity_id then
			log.debug("param 2nd activity_id is nil")
			return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_PARAM_ERROR})
		end

		local ret = fight_prepare(playerid, activity_id)
		return conn:sendClientRespond(cmd, playerid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR, ret})
	end)	

	service:on(Command.C_GUILD_BOSS_FIGHT_CHECK_REQUEST, function(conn, playerid, request)
		local cmd = Command.C_GUILD_BOSS_FIGHT_CHECK_RESPOND		
		local sn = request[1]
		local activity_id = request[2]
		local damage = request[3]
		if not activity_id or not damage then
			log.debug("param 2nd or 3rd activity_id damage is nil")
			return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_PARAM_ERROR})
		end

		local ret = fight_check(playerid, activity_id, damage)
		return conn:sendClientRespond(cmd, playerid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR})
	end)
	
	------------------------------------------------------------------------------------------------ lan add
	service:on(Command.C_GUILD_BOSS_CURINFO_REQUEST,function(conn, playerid, request)
		local cmd = Command.C_GUILD_BOSS_CURINFO_RESPOND
		local sn = request[1]
	        local ret = queryBossCurInfo(playerid)
		
		return conn:sendClientRespond(cmd, playerid, {sn,ret and Command.RET_SUCCESS or Command.RET_ERROR,ret })
	end)
	
end

return Boss
