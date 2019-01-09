local Command = require "Command"
local cell = require "cell"
local base64 = require "base64"
local SocialManager = require "SocialManager"
local NetService = require "NetService"
local Agent = require "Agent"
require "Thread"
require "printtb"
require "MailReward"
local Scheduler = require "Scheduler"
local GuildBoss = require "GuildBoss"
local WorldBoss = require "WorldBoss"
local BossInfo = require "BossInfo"
local BossPlayer = require "BossPlayer"
local BossConfig = require "BossConfig"
local Property = require "Property"

local world_boss = { map = {} }
local guild_boss_map = { map = {} }
local player_map = { map = {} }
local boss_player_map = { map = {} }

local Challenger = {}
local RankManager = { map = {} }	
local Rank = {}
local FightRecord = { map = {} }	-- 战报
local GuildInfoMap = {}		-- 保存军团中的玩家id

local HP_PROPERTY = 1599
local WORLD_BOSS = 1	-- 世界boss
local GUILD_BOSS = 2	-- 军团boss

local GUILD_NOTIFY_REFRESH = 1	-- 军团boss刷新通知
local GUILD_NOTIFY_ESCAPE = 2	-- 军团boss逃跑通知
local GUILD_NOTIFY_KILL = 3	-- 军团boss死亡通知

math.randomseed(os.time())

local CLEAR_DATA_TIME = 1521039600	-- 2018-3-14 23:00:00

-- 世界boss结算
local function PayBack(now)
	local boss_list = world_boss.get_world_boss()

	-- 三场中最好的排名
	local rank_result = {}

	for _, v in ipairs(boss_list) do
		if v.boss_info.refresh_time > now - 23 * 3600 then
			local rank = RankManager.Get(v.id)
			local player_list = player_map.get_players(v.id)
			for pid, _ in pairs(player_list) do
				local th = rank:GetRank(pid)
				if rank_result[pid] == nil or rank_result[pid] > th then
					rank_result[pid] = th
				end
			end
		end
	end

	-- 发放奖励
	for pid, rank in pairs(rank_result) do
		print("rank_result >>>>>>>>>>", pid, rank)
		local rewards = BossConfig.GetRankReward(WORLD_BOSS, rank)
		print("rewards >>>>>>>>>>>", sprinttb(rewards))
		if rewards then
			send_reward_by_mail(pid, "世界boss排名奖励", string.format("今日领主降临活动最高排名为%d，特发以下奖励以兹鼓励!", rank), rewards)
		else
			log.warning("send rank failed: get rewards is nil, id, rank = ", WORLD_BOSS, rank)
		end
	end
end

-- 军团boss结算
local function PayBackGuildBoss(boss)
	local rank = RankManager.Get(boss.id)
	local player_list = player_map.get_players(boss.id)
	for pid, _ in ipairs(player_list) do
		local th = rank:GetRank(pid) 
		local rewards = BossConfig.GetRankReward(GUILD_BOSS, th)
		if rewards then
			send_reward_by_mail(pid, "军团boss排名奖励", string.format("今日军团领主降临活动最高排名为%d，特发以下奖励以兹鼓励!", th), rewards)
		else
			log.warning("send guild boss rank reward failed: get rewards is nil, id, rank = ", GUILD_BOSS, th)
		end
	end	
end

function guild_boss_map.get_guild_boss(guild_id)
	if not guild_boss_map.map[guild_id] or not guild_boss_map.map[guild_id][GUILD_BOSS] then
		guild_boss_map.map[guild_id] = guild_boss_map.map[guild_id] or {}
		guild_boss_map.map[guild_id][GUILD_BOSS] = GuildBoss.Load(guild_id, GUILD_BOSS)
	end

	for _, boss in ipairs(guild_boss_map.map[guild_id][GUILD_BOSS]) do
		-- 将逃跑的boss的状态置1
		if boss.boss_info.refresh_time + boss.boss_info.duration < loop.now() and  
				boss.boss_info.terminator == 0 and boss.boss_info.is_escape ~= 1 then
			boss.boss_info.is_escape = 1
			boss.boss_info.boss_level = math.max(boss.boss_info.boss_level - 1, 1)
			boss:Update()

			-- boss逃跑，通知军团内所有成员
			for _, member_id in ipairs(GuildInfoMap[guild_id].members_id or {}) do
				local agent = Agent.Get(member_id)
				if agent then
					agent:Notify({ Command.NOTIFY_GUILD_BOSS, { GUILD_NOTIFY_ESCAPE, boss.boss_info.npc_id } })			
				end
			end

			-- 军团boss逃跑后，立马进行结算
			PayBackGuildBoss(boss)
		end
	end

	local boss = guild_boss_map.map[guild_id][GUILD_BOSS][1]
	if not boss then
		local b = BossConfig.Random(GUILD_BOSS)
		if not b then
			return nil
		end

		local data, err = cell.QueryPlayerFightInfo(b.fight_id, true, 100)
		if err then
			log.warning("query boss fight level failed, fight_id = ", b.fight_id)
			return nil
		end

		local boss = { boss_info = {} }
		boss.guild_id = guild_id
		boss.type = GUILD_BOSS
		boss.boss_info.refresh_time = loop.now()
		boss.boss_info.npc_id = b.npc_id
		boss.boss_info.fight_id = b.fight_id
		boss.boss_info.fight_data = {}
		boss.boss_info.terminator = 0
		boss.boss_info.is_escape = 0
		boss.boss_info.duration = b.duration
		boss.boss_info.cd = b.interval
		boss.boss_info.boss_level = data.level
		boss.boss_info.is_accu_damage = b.Relation_damage
	
		boss.boss_info = BossInfo.New(boss.boss_info)
		boss = GuildBoss.New(boss)
		boss.is_db = false
		boss.boss_info.is_db = false
		boss:Update()
		table.insert(guild_boss_map.map[guild_id][GUILD_BOSS], boss)

		-- 刷新一个新的boss，通知军团内所有成员
		for _, id in ipairs(GuildInfoMap[guild_id].members_id or {}) do
			local agent = Agent.Get(id)
			if agent then
				agent:Notify({ Command.NOTIFY_GUILD_BOSS, { GUILD_NOTIFY_REFRESH, boss.boss_info.npc_id } })			
			end
		end
	else
		if boss.boss_info.is_escape == 1 or boss.boss_info.terminator ~= 0 then	
			local b = BossConfig.Random(GUILD_BOSS)
			if not b then
				return boss
			end

			local begin_time = BeginTime(b.begin_time, b.period, loop.now())
			local end_time = EndTime(b.end_time, b.period, loop.now())
			if end_time - begin_time > 24 * 3600 then
				end_time = end_time - 24 * 3600
			end
			if boss.boss_info.refresh_time >= begin_time and boss.boss_info.refresh_time < end_time then
				log.debug("boss has escaped or dead, there is no need to refresh a new one.")
				return boss
			end
			boss.guild_id = guild_id 
			boss.type = GUILD_BOSS
			boss.boss_info.refresh_time = begin_time
			boss.boss_info.npc_id = b.npc_id
			boss.boss_info.fight_id = b.fight_id
			boss.boss_info.fight_data = {}
			boss.boss_info.terminator = 0
			boss.boss_info.is_escape = 0
			boss.boss_info.duration = b.duration
			boss.boss_info.cd = b.interval

			local data, err = cell.QueryPlayerFightInfo(b.fight_id, true, 100)
			if boss.boss_info.is_escape == 1 then
				boss.boss_info.boss_level = math.max(boss.boss_info.boss_level - 1, data.level)
			elseif boss.boss_info.terminator ~= 0 then
				boss.boss_info.boss_level = boss.boss_info.boss_level + 1
			end
			boss.boss_info.is_accu_damage = b.Relation_damage
			boss:Update()
		end
	end

	return boss
end

function world_boss.get_current_boss()
	local list = world_boss.get_world_boss()

	for _, v in ipairs(list or {}) do
		if loop.now() >= v.boss_info.refresh_time and loop.now() < v.boss_info.duration + v.boss_info.refresh_time then
			return v
		end
	end

	return nil
end

function world_boss.get_world_boss()
	if not world_boss.map[WORLD_BOSS] then
		world_boss.map[WORLD_BOSS] = WorldBoss.Load(WORLD_BOSS)
	end

	for _, boss in ipairs(world_boss.map[WORLD_BOSS]) do
		-- 将逃跑的boss的状态置1
		if loop.now() >= boss.boss_info.refresh_time + boss.boss_info.duration and  
				boss.boss_info.terminator == 0 and boss.boss_info.is_escape ~= 1 then
			boss.boss_info.is_escape = 1
			--boss.boss_info.boss_level = math.max(boss.boss_info.boss_level - 1, 1)
			boss:Update()
	
			NetService.NotifyClients(Command.NOTIFY_DISPLAY_MESSAGE, { 17, boss.boss_info.npc_id })
		end
	end

	-- 当前时间最接近的boss信息
	--[[local list = world_boss.map[WORLD_BOSS]
	local boss = nil
	for _, v in ipairs(list) do
		if loop.now() >= v.boss_info.refresh_time and loop.now() < v.boss_info.duration + v.boss_info.refresh_time then
			boss = v
			break
		end
	end

	if not boss then
		local b = BossConfig.Random(WORLD_BOSS)
		if not b then
			return world_boss.map[WORLD_BOSS]
		end

		local data, err = cell.QueryPlayerFightInfo(b.fight_id, true, 100)
		if err then
			log.warning("get_world_boss: query boss fight level failed, fight_id = ", b.fight_id)
			return world_boss.map[WORLD_BOSS]
		end

		local begin_time = BeginTime(b.begin_time, b.period, loop.now())
		local end_time = EndTime(b.end_time, b.period, loop.now())
		if end_time - begin_time > 24 * 3600 then
			end_time = end_time - 24 * 3600
		end

		boss = { boss_info = {} }
		boss.type = WORLD_BOSS
		boss.is_db = false
		boss.boss_info.refresh_time = begin_time
		boss.boss_info.npc_id = b.npc_id
		boss.boss_info.fight_id = b.fight_id
		boss.boss_info.fight_data = {}
		boss.boss_info.terminator = 0
		boss.boss_info.is_escape = 0
		boss.boss_info.duration = b.duration
		boss.boss_info.cd = b.interval
		boss.boss_info.boss_level = data.level
		boss.boss_info.is_accu_damage = b.Relation_damage
		boss.boss_info.is_db = false
				
		boss.boss_info = BossInfo.New(boss.boss_info)
		boss = WorldBoss.New(boss)
		boss:Update()

		table.insert(world_boss.map[WORLD_BOSS], boss)
	else
		-- 尝试重新刷新一个Boss
		if boss.boss_info.is_escape == 1 or boss.boss_info.terminator ~= 0 then
			local b = BossConfig.Random(WORLD_BOSS)
			if not b then
				return world_boss.map[WORLD_BOSS]
			end

			local begin_time = BeginTime(b.begin_time, b.period, loop.now())
			local end_time = EndTime(b.end_time, b.period, loop.now())
			if end_time - begin_time > 24 * 3600 then
				end_time = end_time - 24 * 3600
			end
			if boss.boss_info.refresh_time >= begin_time and boss.boss_info.refresh_time < end_time then
				log.debug("boss has escaped or dead, there is no need to refresh a new one.")
				return world_boss.map[WORLD_BOSS]
			end
			boss.boss_info.refresh_time = begin_time
			boss.boss_info.npc_id = b.npc_id
			boss.boss_info.fight_id = b.fight_id
			boss.boss_info.fight_data = {}
			boss.boss_info.terminator = 0
			boss.boss_info.is_escape = 0
			boss.boss_info.duration = b.duration
			boss.boss_info.cd = b.interval
			boss.boss_info.boss_level = boss.boss_info.boss_level--data.level
			boss.boss_info.is_accu_damage = b.Relation_damage
			boss:Update()
		end
	end--]]

	local list = world_boss.map[WORLD_BOSS]
	local has_boss = false
	local last_boss = nil
	local max_refresh_time = 0
	for _, v in ipairs(list) do
		if loop.now() >= v.boss_info.refresh_time and loop.now() < v.boss_info.duration + v.boss_info.refresh_time then
			has_boss = true
		end

		if loop.now() >= v.boss_info.refresh_time and v.boss_info.refresh_time > max_refresh_time then
			last_boss = v
			max_refresh_time = v.boss_info.refresh_time
		end
	end

	if not has_boss then
		local b = BossConfig.Random(WORLD_BOSS)
		if not b then
			return world_boss.map[WORLD_BOSS]
		end

		local data, err = cell.QueryPlayerFightInfo(b.fight_id, true, 100)
		if err then
			log.warning("get_world_boss: query boss fight level failed, fight_id = ", b.fight_id)
			return world_boss.map[WORLD_BOSS]
		end

		local begin_time = BeginTime(b.begin_time, b.period, loop.now())
		local end_time = EndTime(b.end_time, b.period, loop.now())
		if end_time - begin_time > 24 * 3600 then
			end_time = end_time - 24 * 3600
		end

		boss = { boss_info = {} }
		boss.type = WORLD_BOSS
		boss.is_db = false
		boss.boss_info.refresh_time = begin_time
		boss.boss_info.npc_id = b.npc_id
		boss.boss_info.fight_id = b.fight_id
		boss.boss_info.fight_data = {}
		boss.boss_info.terminator = 0
		boss.boss_info.is_escape = 0
		boss.boss_info.duration = b.duration
		boss.boss_info.cd = b.interval
		if last_boss then
			if last_boss.boss_info.is_escape == 1 then
				boss.boss_info.boss_level = math.max(data.level, last_boss.boss_info.boss_level -1)
			elseif last_boss.boss_info.terminator ~= 0 then
				boss.boss_info.boss_level = last_boss.boss_info.boss_level + 1
			end
		else
			boss.boss_info.boss_level = data.level
		end

		boss.boss_info.is_accu_damage = b.Relation_damage
		boss.boss_info.is_db = false
				
		boss.boss_info = BossInfo.New(boss.boss_info)
		boss = WorldBoss.New(boss)
		boss:Update()

		table.insert(world_boss.map[WORLD_BOSS], boss)
	end
		
	return world_boss.map[WORLD_BOSS]
end

function player_map.get_players(id)
	if not player_map.map[id] then
		player_map.map[id] = Challenger.Load(id)
	end

	return player_map.map[id]
end

function player_map.get_player_info(id, pid)
	local m = player_map.get_players(id)

	if not m[pid] then
		m[pid] = Challenger.Load2(id, pid)
	end

	return player_map.map[id][pid]
end

function boss_player_map.get_player(pid)
	if not boss_player_map.map[pid] then
		boss_player_map.map[pid] = BossPlayer.Load(pid)
	end

	return boss_player_map.map[pid]
end

local function get_guild_info(pid)
	local respond = SocialManager.getGuild(pid)
	if not respond or respond.result ~= 0 or respond.guild.id == 0 then
		return nil
	end
	GuildInfoMap[respond.guild.id] = respond.guild

	return GuildInfoMap[respond.guild.id]
end

-- 定期清理过期数据
local function clearOutOfData()
	local interval = 24 * 3600 * 2

	-- 军团boss数据清理
	for _, v in ipairs(guild_boss_map.map or {}) do
		local temp = {}
		for _, boss in ipairs(v[GUILD_BOSS] or {}) do		
			if loop.now() - boss.boss_info.refresh_time > interval and boss:Delete() then
				-- 战报
				FightRecord.Delete(boss.id)
				FightRecord.map[boss.id] = nil
				-- 排行榜
				RankManager.map[boss.id] = nil
				-- 玩家
				Challenger.Delete(boss.id)
				player_map.map[boss.id] = nil
			else
				table.insert(temp, boss)
			end
		end
		if v[GUILD_BOSS] then
			v[GUILD_BOSS] = temp
		end
	end
end

function tranform(player)
	for k, role in pairs(player.roles) do
		local property = {}
		for _, v in ipairs(role.propertys) do
			property[v.type] = (property[v.type] or 0) + v.value
		end
		role.Property = Property(property);
	end
	for k, role in ipairs(player.assists) do
		local property = {}
		for _, v in ipairs(role.propertys) do
			property[v.type] = (property[v.type] or 0) + v.value
		end
		role.Property = Property(property);

		for _, v in ipairs(role.assist_skills) do
			print(v.id, v.weight);
		end
	end
end

local function CurrentHp(fight_data)	
	local hp = 0

	for _, v in ipairs(fight_data.roles) do
		hp = hp + v.Property.hp
	end

	return hp
end

local function TotalHp(fight_data)
	local hpp = 0

	for _, v in ipairs(fight_data.roles) do
		hpp = hpp + v.Property.hpp	
	end

	return hpp
end

-- 更新HP_PROPERTY属性值
local function UpdateProperty(fight_data, t)
	for _, role in ipairs(fight_data.roles) do
		local pos = 0
		for i, v in ipairs(role.propertys) do
			if v.type == HP_PROPERTY then
				pos = i
				break
			end
		end
		if pos == 0 then
			pos = table.maxn(role.propertys) + 1
			table.insert(role.propertys, { type = HP_PROPERTY, value = 0 })
		end
	
		role.propertys[pos].value = t[role.refid] or role.propertys[pos].value
	end
	tranform(fight_data)
end

local function GetPropertyStr(fight_data)
	local str = ""

	for _, v in ipairs(fight_data.roles) do
		str = str .. "|" .. tostring(v.refid) .. ":" .. tostring(v.Property[HP_PROPERTY] or 0)
	end

	if str ~= "" then
		str = string.sub(str, 2)
	end

	return str
end

local function GetProperty(fight_data)
	return formatStrtoTable(GetPropertyStr(fight_data))
end

-----------------------------------------------------------------------
function FightRecord.Get(id)
	if not FightRecord.map[id] then
		FightRecord.map[id] = {}
		local ok, result = database.query([[select id, pid, th, npc_id, fight_id, damage, unix_timestamp(fight_time) as fight_time, 
			fight_data, player_fight_data, seed from boss_fight_record where id = %d;]], id)
		if ok and #result > 0 then	
			for _, v in ipairs(result) do
				local code = base64.decode(v.player_fight_data)
				local player_fight_data = decode(code, 'FightPlayer')
				tranform(player_fight_data)
				FightRecord.map[id][v.pid] = FightRecord.map[id][v.pid] or {}
				v.fight_data = formatStrtoTable(v.fight_data)
				v.player_fight_data = player_fight_data
				table.insert(FightRecord.map[id][v.pid], v)
			end
		end
	end

	return FightRecord.map[id]
end



function FightRecord.Get2(id, pid)
	local records = FightRecord.Get(id, pid)		
	records[pid] = records[pid] or {}

	return records[pid]
end

function FightRecord.Insert(info)
	local records = FightRecord.Get2(info.id, info.pid)
	local n = table.maxn(records)
	info.th = n + 1

	local code = encode('FightPlayer', info.player_fight_data)
	if not code then
		log.warning("FightRecord.Insert: encode failed.")
		return false
	end	

	local c = base64.encode(code)

	local sql = string.format([[insert into boss_fight_record(id, pid, th, npc_id, damage, fight_time, fight_data, player_fight_data, seed) 
		values(%d, %d, %d, %d, %d, from_unixtime_s(%d), '%s', '%s', %d);]], 
		info.id, info.pid, info.th, info.npc_id, info.damage, info.fight_time, tableToFormatStr(info.fight_data), c, info.seed);
	local ok = database.update(sql) 
	if ok then
		table.insert(records, info)
	end

	return ok
end

-- 按照时间来删除
function FightRecord.Delete(id)
	local ok = database.update([[delete from boss_fight_record where id = %d;]], id)

	return ok
end

------------------------------------------------------------------------
function Challenger.New(o)
	o = o or {}
	return setmetatable(o, { __index = Challenger })
end

function Challenger:Update()	
	local ok = false
	if self.is_db then
		ok = database.update([[update world_player set last_fight_time = from_unixtime_s(%d), damage = %d, reward_flag1 = %d, reward_flag2 = %d, reward_flag3 = %d, reward_flag4 = %d where id = %d and pid = %d;]], 
			self.last_fight_time, self.damage, self.reward_flag1, self.reward_flag2, self.reward_flag3, self.reward_flag4, self.id, self.pid)
	else
		ok = database.update([[insert into world_player(id, pid, last_fight_time, damage, reward_flag1, reward_flag2, reward_flag3, reward_flag4) values(%d, %d, from_unixtime_s(%d), %d, %d, %d, %d, %d);]], 
			self.id, self.pid, self.last_fight_time, self.damage, self.reward_flag1, self.reward_flag2, self.reward_flag3, self.reward_flag4)
		if ok then
			self.is_db = true
		end
	end
end

function Challenger.Load(id)
	local ok, result = database.update([[select id, pid, unix_timestamp(last_fight_time) as last_fight_time, damage, reward_flag1, reward_flag2, reward_flag3, reward_flag4 from world_player where id = %d;]], id)

	local ret = {}
	if ok and #result > 0 then
		for _, v in ipairs(result) do
			v.is_db = true
			table.insert(ret, Challenger.New(v))
		end
	end

	return ret
end

function Challenger.Load2(id, pid)
	local ok, result = database.update([[select id, pid, unix_timestamp(last_fight_time) as last_fight_time, 
		damage, reward_flag1, reward_flag2, reward_flag3, reward_flag4 from world_player where id = %d and pid = %d;]], id, pid)
	if ok and #result > 0 then
		result[1].is_db = true
		return Challenger.New(result[1])
	else
		local p = { id = id, pid = pid, last_fight_time = 0, damage = 0, reward_flag1 = 0, reward_flag2 = 0, reward_flag3 = 0, reward_flag4 = 0, is_db = false }
		return Challenger.New(p)
	end
end

function Challenger.Delete(id)
	local ok = database.update("delete from world_player where id = %d;", id)

	return ok
end

--------------------------------------------------------------------------
function Rank.New(o)
	o = o or {}
	return setmetatable(o, { __index = Rank })
end

function Rank:GetRank(pid)
	return self.items[pid] and self.items[pid].rank or nil
end

function Rank:Add(pid, value)
	local rank = table.maxn(self.ranks) + 1

	local info = {
		pid = pid,
		value = value,
		rank = rank, 
	}
	self.ranks[rank] = info
	self.items[pid] = info
			
	return rank
end

function Rank:SetValue(pid, value)
	local oldrank = 0
	local old_value = 0
	if not self.items[pid] then
		oldrank = self:Add(pid, value)
		old_value = 0
	else
		oldrank = self:GetRank(pid) 
		old_value = self.items[pid].value
	end

	local item = self.items[pid]
	item.value = value
	if old_value == value then
		return
	end

	if value < old_value then
		for ite = oldrank, table.maxn(self.ranks), 1 do
			local back = self.ranks[ite + 1];
			if back == nil or back.value < value then
				self.ranks[ite] = item
				item.rank = ite
				break
			else
				self.ranks[ite] = back
				back.rank = ite;
			end
		end
	else		
		for ite = oldrank, 1, -1 do
			local front = self.ranks[ite - 1]
			if front == nil or front.value > value then
				self.ranks[ite] = item
				item.rank = ite
				break
			else
				self.ranks[ite] = front
				front.rank = ite
			end
		end
	end

	return item.rank	
end

function Rank:GetRankList()
	local list = {}

	for i = 1, 50 do
		local v = self.ranks[i]
		if v then
			table.insert(list, { v.pid, v.rank, v.value })
		end
	end

	return list
end

function Rank:GetRankInfo(pid)
	if self.items[pid] then
		return { pid, self.items[pid].rank, self.items[pid].value }
	end

	return {}
end

function RankManager.Get(id)
	if not RankManager.map[id] then
		local records = FightRecord.Get(id)	
		local rank = Rank.New({ id = id, time = time, ranks = {}, items = {} })

		for pid, _ in pairs(records) do
			local challenger = player_map.get_player_info(id, pid)
			rank:SetValue(challenger.pid, challenger.damage)		
		end

		RankManager.map[id] = rank
	end
			
	return RankManager.map[id]
end

function RankManager.GetBestRank(pid)	
	local boss_list = world_boss.get_world_boss()

	-- 三场中最好的排名
	local best_rank = 10000

	for _, v in ipairs(boss_list) do
		if v.boss_info.refresh_time > loop.now() - 23 * 3600 then
			local rank = RankManager.Get(v.id)
			local th = rank:GetRank(pid) or 10000
			if th < best_rank then
				best_rank = th
			end
		end
	end

	return best_rank
end

local function handle_auto_fight(pid1, pid2, opt, id, guild_id)
	log.debug(string.format("handle_auto_fight: player %d begin to challenge boss %d, id is %d.", pid1, pid2, id))
	local boss = nil
	if id == WORLD_BOSS then
		boss = world_boss.get_current_boss()
	elseif id == GUILD_BOSS then
		if not guild_id then
			return 
		end
		boss = guild_boss_map.get_guild_boss(guild_id)
	end

	if not boss or boss.boss_info.is_escape == 1 or boss.boss_info.terminator ~= 0 then
		return
	end
	local winner, _, seed, roles = SocialManager.PVPFightPrepare(pid1, pid2, opt)
	log.debug(string.format("handle_auto_fight: winner = %d, seed = %d", winner, seed))

	if winner then
		local fightData = {
			attacker = opt.attacker_data,
			defender = opt.defender_data,
			seed = seed,
			scene = "18hao"
		}
		local code = encode('FightData', fightData)					

		-- 战斗前的血量
		local hp_before_fight = CurrentHp(opt.defender_data)		-- 战斗前总血量
		-- 更新剩HP_PROPERTY的数值
		local alive = {}
		for _, v in ipairs(roles) do
			log.debug("refid|hp = ", v.refid, v.hp)
			alive[v.refid] = v.hp
		end
		for _, role in ipairs(opt.defender_data.roles) do	
			local pos = 0
			for i, v in ipairs(role.propertys) do
				if v.type == HP_PROPERTY then
					pos = i
					break
				end
			end
			if pos == 0 then		-- 1599属性不存在
				pos = table.maxn(role.propertys) + 1
				table.insert(role.propertys, { type = HP_PROPERTY, value = 0 })		
			end
			if alive[role.refid] then			
				log.debug(string.format("refid = %d, origin hp = %d, remain hp is = %d ", role.refid, role.Property.hp, alive[role.refid]))
				if alive[role.refid] > role.Property.hpp then
					alive[role.refid] = role.Property.hpp		
				end
				role.propertys[pos].value = role.Property.hpp - alive[role.refid]
			else
				role.propertys[pos].value = role.Property.hpp	
			end
		end
		tranform(opt.defender_data)
		
		-- 战斗后的血量
		local hp_after_fight = CurrentHp(opt.defender_data)
		local damage = hp_before_fight - hp_after_fight
		log.debug("hp_before_fight, hp_after_fight, damage = ", hp_before_fight, hp_after_fight, damage)
	
		-- 生成战报
		local info = { id = boss.id, pid = pid1, npc_id = boss.boss_info.npc_id, damage = damage, 
			fight_time = loop.now(), fight_data = boss.boss_info.fight_data, player_fight_data = opt.attacker_data, seed = seed }
		FightRecord.Insert(info)
	
		-- 记录boss HP_PROPERTY值
		boss.boss_info.fight_data = GetProperty(opt.defender_data)

		-- boss被击杀了
		if hp_after_fight == 0 then
			boss.boss_info.terminator = pid1	
			-- 击杀奖励
			local kill_rewards, drop_id, _ = BossConfig.GetRewardByIdAndTime(id, boss.boss_info.npc_id, boss.boss_info.refresh_time)
			if kill_rewards then
				send_reward_by_mail(pid1, "最后一击奖励", "经过广大玩家的不断努力，破封而出的灵兽之王被成功封印！", kill_rewards)
			end
			local drop_rewards, ok = cell.sendDropReward(pid1, { drop_id }, Command.REASON_WORLD_BOSS)
			local t1 = {}
			if ok then
				for _, v in ipairs(drop_rewards) do
					table.insert(t1, { v.type, v.id, v.value })
				end
			end

			-- 只有世界boos，击杀才有跑马灯
			if id == WORLD_BOSS then			
				local player = cell.getPlayerInfo(pid1)
				NetService.NotifyClients(Command.NOTIFY_DISPLAY_MESSAGE, { 16, player and player.name or pid1, boss.boss_info.npc_id, t1, pid1 })
			-- 军团boss被击杀，通知军团所有成员
			elseif id == GUILD_BOSS then
				local guild = get_guild_info(pid1)
				for _, id in ipairs(GuildInfoMap[guild.id].members_id or {}) do
					local agent = Agent.Get(id)
					if agent then
						agent:Notify({ Command.NOTIFY_GUILD_BOSS, { GUILD_NOTIFY_KILL, boss.boss_info.npc_id, t1 } })			
					end
				end
				-- 立即进行结算
				PayBackGuildBoss(boss)	
			end
			--boss.boss_info.boss_level = boss.boss_info.boss_level + 1
		end
		boss:Update()
	
		-- 更新玩家对boss的伤害值
		local challenger = player_map.get_player_info(boss.id, pid1)	
		local totalHp = TotalHp(opt.defender_data) 
		log.debug("damage, totalHp = ", damage, totalHp)
	
		local p = boss_player_map.get_player(pid1)
		if p.time < BeginTime(CLEAR_DATA_TIME, 24 * 3600, loop.now()) then
			p.damage = 0
			p.time = BeginTime(CLEAR_DATA_TIME, 24 * 3600, loop.now())
			p:Update()
		end

		local old_rate = 0
		local new_rate = 0
		local reward_damage = 0
		if boss.boss_info.is_accu_damage > 0 then
			old_rate = math.floor((p.damage / totalHp) * 10000)	
			challenger.damage = challenger.damage + damage
			p.damage = p.damage + damage
			p:Update()
			new_rate = math.floor((p.damage / totalHp) * 10000)	
			reward_damage = p.damage
		else
			old_rate = math.floor((challenger.damage / totalHp) * 10000)
			challenger.damage = challenger.damage + damage
			new_rate = math.floor((challenger.damage / totalHp) * 10000)
			reward_damage =  challenger.damage
		end

		-- 阶段奖励
		--local rewards, drop_id = BossConfig.GetPhaseRewardByRate(id, boss.boss_info.boss_level, old_rate, new_rate)
		local reward_flags = {challenger.reward_flag1, challenger.reward_flag2, challenger.reward_flag3, challenger.reward_flag4}
		--local rewards, drop_ids, flag_change = BossConfig.GetPhaseRewardByRate(id, pid1, new_rate, reward_flags)
		local rewards, drop_ids, flag_change = BossConfig.GetPhaseRewardByRate(id, pid1, reward_damage, reward_flags)
			
		if #rewards > 0 then
			local respond = cell.sendReward(pid1, rewards, nil, Command.REASON_WORLD_BOSS)
			if not respond or respond.result ~= 0 then
				log.warning("send challenge boss reward failed.")
			end
		end
		if #drop_ids > 0 then
			cell.sendDropReward(pid1, drop_ids , Command.REASON_WORLD_BOSS)	
		end

		if flag_change then
			challenger.reward_flag1 = reward_flags[1]
			challenger.reward_flag2 = reward_flags[2]
			challenger.reward_flag3 = reward_flags[3]
			challenger.reward_flag4 = reward_flags[4]
		end

		challenger:Update()
		local rank = RankManager.Get(boss.id)
		rank:SetValue(challenger.pid, challenger.damage)
				
		-- 惊喜奖励
		local _, _, drop_surprise = BossConfig.GetRewardByIdAndTime(id, boss.boss_info.npc_id, boss.boss_info.refresh_time)
		if drop_surprise > 0 then
			cell.sendDropReward(pid1, { drop_surprise }, Command.REASON_WORLD_BOSS)
		end
		-- 发一个广播
		local player_list = player_map.get_players(boss.id)
		for pid, _ in pairs(player_list) do			
			local agent = Agent.Get(pid)
			if agent then
				-- 战报通知
				agent:Notify({ Command.NOTIFY_FIGHT_RECORD, { id, info.npc_id, info.pid, info.damage, info.fight_time, code } })			
				-- 排行榜变化
				agent:Notify({ Command.NOTIFY_RANK_LIST, { id, rank:GetRankList(), rank:GetRankInfo(pid), {challenger.reward_flag1, challenger.reward_flag2, challenger.reward_flag3, challenger.reward_flag4}, p.damage, id == WORLD_BOSS and RankManager.GetBestRank(pid) or nil } })
			end
		end
	else
		log.warning(string.format("start auto fight failed, can not generate fight report: %d, %d", pid1, pid2))
	end
end

local function check_boss_status(boss)
	if not boss then
		log.debug(string.format("boss is nil."))
		return Command.RET_NOT_EXIST
	end
	if boss.boss_info.terminator ~= 0 then
		log.debug(string.format("boss %d is excuted by %d.", boss.boss_info.npc_id, boss.boss_info.terminator))
		return Command.RET_NOT_EXIST
	end
	if boss.boss_info.is_escape == 1 then
		log.debug(string.format("boss %d is escape.", boss.boss_info.npc_id))
		return Command.RET_NOT_EXIST
	end

	return Command.RET_SUCCESS
end


local BossProxy = {}
function BossProxy.RegisterCommands(service)
	-- 查询当前boss信息/（军团开启boss)
	service:on(Command.C_GET_NPC_INFO_REQUEST, function (conn, pid, request)
		local cmd = Command.C_GET_NPC_INFO_RESPOND
		log.debug(string.format("cmd: %d, player %d query current boss info.", cmd, pid))

		if type(request) ~= "table" or #request < 2 then
			return conn:sendClientRespond(cmd, pid, { 1, Command.RET_PARAM_ERROR })	
		end
		local sn = request[1]
		local category = request[2]	-- boss类型，1是世界boss，2是军团boss

		-- 等级是否满足
		if not BossConfig.IsLevel(category, pid) then
			log.debug(string.format("cmd: %d, player %d level not enough.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_DEPEND })
		end

		local boss = nil
		local guild = nil
		if category == GUILD_BOSS then
			guild = get_guild_info(pid)
			if not guild then
				log.debug(string.format("cmd: %d, player %d has no guild.", cmd, pid))
				return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
			end
			boss = guild_boss_map.get_guild_boss(guild.id)
		else
			boss = world_boss.get_current_boss()
		end

		-- 检测boss是否存在
		local check_result = check_boss_status(boss)
		if check_result ~= Command.RET_SUCCESS then
			return conn:sendClientRespond(cmd, pid, { sn, check_result })
		end

		local challenger = player_map.get_player_info(boss.id, pid)
		local next_challenge_time = challenger.last_fight_time + boss.boss_info.cd
		if next_challenge_time < loop.now() then	
			next_challenge_time = loop.now()
		end

		-- 保证军团boss的等级不能超过军团等级
		local lev = boss.boss_info.boss_level
		if category == GUILD_BOSS then
			lev = math.min(GuildInfoMap[guild.id].level, boss.boss_info.boss_level)
		end
		local data, err = cell.QueryPlayerFightInfo(boss.boss_info.fight_id, true, 100, nil, nil, { level = lev }) 
		if err then
			log.warning(string.format("cmd: query %d fight data failed.", cmd, boss.boss_info.fight_id))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end	
			
		UpdateProperty(data, boss.boss_info.fight_data)
		local totalHp = TotalHp(data) 
		local currentHp = CurrentHp(data)

		log.debug("totalHp, currentHp, next_challenge_time = ", totalHp, currentHp, next_challenge_time)

		local respond = { sn, Command.RET_SUCCESS, category, boss.boss_info.npc_id, 
			boss.boss_info.refresh_time, totalHp, currentHp, boss.boss_info.duration, boss.boss_info.boss_level, next_challenge_time }	

	
		conn:sendClientRespond(cmd, pid, respond)
	end)	

	-- 查询战报
	service:on(Command.C_GET_NPC_FIGHT_RESULT, function (conn, pid, request)
		local cmd = Command.C_GET_NPC_FIGHT_RESPOND
		log.debug(string.format("cmd: %d, query fight report.", cmd))
		
		if type(request) ~= "table" or #request < 2 then
			return conn:sendClientRespond(cmd, pid, { 1, Command.RET_PARAM_ERROR })
		end
		local sn = request[1]
		local category = request[2]
	
		-- 等级是否满足
		if not BossConfig.IsLevel(category, pid) then
			log.debug(string.format("cmd: %d, player %d level not enough.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_DEPEND })
		end
	
		local boss = nil
		local guild = nil
		if category == GUILD_BOSS then
			guild = get_guild_info(pid)
			if not guild then
				log.warning(string.format("cmd: %d, player %d has no guild.", cmd, pid))
				return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
			end
			boss = guild_boss_map.get_guild_boss(guild.id)
		else
			boss = world_boss.get_current_boss()
		end

		-- 检测boss是否存在
		local check_result = check_boss_status(boss)
		if check_result ~= Command.RET_SUCCESS then
			return conn:sendClientRespond(cmd, pid, { sn, check_result })
		end
	
		-- 保证军团boss的等级不能超过军团等级
		local lev = boss.boss_info.boss_level
		if category == GUILD_BOSS then
			lev = math.min(GuildInfoMap[guild.id].level, boss.boss_info.boss_level)
		end

		local defender, err = cell.QueryPlayerFightInfo(boss.boss_info.fight_id, true, 100, nil, nil, { level = lev })
		if err then
			log.warning(string.format("cmd: query %d fight data failed.", cmd, boss.boss_info.fight_id))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
		-- 记录一下原始的属性
		local origin_property = GetProperty(defender)
	
		local records = FightRecord.Get(boss.id)
		local list = {}
		for _, v in pairs(records) do
			for _, v2 in ipairs(v) do
				table.insert(list, v2)	
			end
		end
		table.sort(list, function (a, b)
			return a.fight_time > b.fight_time
		end)

		local ret = {}
		for i = 1, 50 do
			local v = list[i]
			if v then
				UpdateProperty(defender, v.fight_data)		
				local fightData = {
					attacker = v.player_fight_data,
					defender = defender,
					seed = v.seed,
					scene = "18hao"
				}

				local code = encode('FightData', fightData)
				table.insert(ret, { v.npc_id, v.pid, v.damage, v.fight_time, code})
				UpdateProperty(defender, origin_property)	-- 恢复
			else
				break
			end
		end	

		conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, category, ret })
	end)

	-- 挑战boss
	service:on(Command.C_CHALLENGE_NPC_REQUEST, function (conn, pid, request)
		local cmd = Command.C_CHALLENGE_NPC_RESPOND
		log.debug(string.format("cmd: %d, player %d begin to challenge boss.", cmd, pid))
		
		if type(request) ~= "table" or #request < 2 then
			log.warning(string.format("cmd: %d, param error.", cmd))
			return conn:sendClientRespond(cmd, pid, { 1, Command.RET_PARAM_ERROR })
		end
		local sn = request[1]
		local category = request[2]
	
		-- 等级是否满足
		if not BossConfig.IsLevel(category, pid) then
			log.debug(string.format("cmd: %d, player %d level not enough.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_DEPEND })
		end
	
		-- 军团id
		local members = { pid }
		local boss = nil
		local guild = nil
		if category == GUILD_BOSS then
			guild = get_guild_info(pid)
			if not guild then
				log.warning(string.format("cmd: %d, player %d has no guild.", cmd, pid))
				return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
			end
			members = guild.members_id
			boss = guild_boss_map.get_guild_boss(guild.id)
		else
			boss = world_boss.get_current_boss()
		end

		-- 检测boss是否存在
		local check_result = check_boss_status(boss)
		if check_result ~= Command.RET_SUCCESS then
			return conn:sendClientRespond(cmd, pid, { sn, check_result })
		end
	
		-- 保证军团boss的等级不能超过军团等级
		local lev = boss.boss_info.boss_level
		if category == GUILD_BOSS then
			lev = math.min(GuildInfoMap[guild.id].level, boss.boss_info.boss_level)
		end

		local last_challenge_time = 0
		-- 挨个挑战boss
		local defender, err = cell.QueryPlayerFightInfo(boss.boss_info.fight_id, true, 100, nil, nil, { level = lev }) 
		if err then
			log.warning(string.format("cmd: %d, player %d challenge boss %d failed, because query boss fight data info failed.", cmd, pid, boss.boss_info.npc_id))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
			
		UpdateProperty(defender, boss.boss_info.fight_data)

		--for _, player_id in ipairs(members) do		
			-- 检查时间是否足够
			local challenger = player_map.get_player_info(boss.id, pid)
			if challenger.last_fight_time + boss.boss_info.cd > loop.now() then
				log.warning(string.format("cmd: %d, there is need wait %d seconds.", cmd, challenger.last_fight_time + boss.boss_info.cd - loop.now()))
				return conn:sendClientRespond(cmd, pid, { sn, Command.RET_COOLDOWN })
			end

			local opt = {}
			local attacker, err = cell.QueryPlayerFightInfo(pid, false, 0)
			if err then
				log.warning(string.format("cmd: %d, player %d challenge boss %d failed, because query player data info failed.", cmd, pid, boss.boss_info.npc_id))
				return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
			end

			opt.attacker_data = attacker
			opt.defender_data = defender
			opt.auto = true
			handle_auto_fight(pid, boss.boss_info.fight_id, opt, category, guild and guild.id or nil)

			challenger.last_fight_time = loop.now()
			challenger:Update()

			last_challenge_time = challenger.last_fight_time
		--end

		local next_challenge_time = last_challenge_time + boss.boss_info.cd
		if next_challenge_time < loop.now() then	
			next_challenge_time = loop.now()
		end

		conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, category, next_challenge_time })
	end)

	-- 查询排行榜
	service:on(Command.C_GET_RANKLIST_REQUEST, function (conn, pid, request)
		local cmd = Command.C_GET_RANKLIST_RESPOND 
		log.debug(string.format("cmd: %d, player %d query rank list.", cmd, pid))
	
		if type(request) ~= "table" or #request < 2 then
			return conn:sendClientRespond(cmd, pid, { 1, Command.RET_PARAM_ERROR })
		end
		local sn = request[1]
		local category = request[2]
	
		-- 等级是否满足
		if not BossConfig.IsLevel(category, pid) then
			log.debug(string.format("cmd: %d, player %d level not enough.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_DEPEND })
		end

		local boss = nil
		local guild = nil
		if category == GUILD_BOSS then
			guild = get_guild_info(pid)
			if not guild then
				log.warning(string.format("cmd: %d, player %d has no guild.", cmd, pid))
				return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
			end
			boss = guild_boss_map.get_guild_boss(guild.id)
		else
			boss = world_boss.get_current_boss()
		end

		if not boss then
			log.warning(string.format("cmd: %d, boss is not exist.", cmd))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
		end

		local rank = RankManager.Get(boss.id)
		local challenger = player_map.get_player_info(boss.id, pid)	

		local p = boss_player_map.get_player(pid)
		if p.time < BeginTime(CLEAR_DATA_TIME, 24 * 3600, loop.now()) then
			p.damage = 0
			p.time = BeginTime(CLEAR_DATA_TIME, 24 * 3600, loop.now())
			p:Update()
		end

		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, category, rank:GetRankList(), rank:GetRankInfo(pid), {challenger.reward_flag1, challenger.reward_flag2, challenger.reward_flag3, challenger.reward_flag4}, p.damage, category == WORLD_BOSS and RankManager.GetBestRank(pid) or nil })
	end)
end

Scheduler.Register(function(now)
	if BeginTime(CLEAR_DATA_TIME, 24 * 3600, now) == now then
		print("begin to send reward >>>>>>>>>>>>>>>>>>>>>>>")
		RunThread(PayBack, now)
	end

	-- recycle memory
	if now % 7200 == 0 then
		-- clearOutOfData()
	end
end)

return BossProxy
