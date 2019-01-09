local BinaryConfig = require "BinaryConfig"
local SharedQuestConfig = {}
local SharedQuestPoolConfig = {}
local Pools = {}
require "Thread"

math.randomseed(os.time())

local function getTeamByPlayer(pid)
	local info = SocialManager.GetTeamInfo(nil, pid)
	if info then
		local mems = {}
		for _,v in ipairs(info.members) do
			table.insert(mems, v.pid)
		end
		return {teamid = info.teamid, leader_pid = info.leader, members = mems}
	end

	return 
end

local function insertItem(t, type, id, value)
	if not type or type == 0 then
		return 
	end

	if not id or id == 0 then
		return 
	end

	if not value then
		return 
	end

	table.insert(t, {type = type, id = id, value = value})
end

local function DOReward(pid, reward, consume, reason, manual, limit, name)
	assert(pid and pid ~= 0, debug.traceback())
	assert(reason and reason ~= 0)

	if reward and #reward == 0 then
		reward = nil
	end

	if consume and #consume == 0 then
		consume = nil
	end

	if not reward and not consume then
		return true
	end

	local respond = cell.sendReward(pid, reward, consume, reason, manual, limit, name)
	if respond == nil or respond.result ~= 0 then
		return false;
	end
	return true;
end

local players = {}
local function GetPlayer(pid, force)
	if not players[pid] or force then
		local respond = cell.getPlayer(pid);
		if respond and respond.result == Command.RET_SUCCESS then
			players[pid] = {
				name = respond.player.name,			
				level = respond.player.level,
				update_time = loop.now(),
			}
		end
	end

	return players[pid] 
end

local function LoadSharedQuestConfig()
	local rows = BinaryConfig.Load("config_shared_quest", "guild")
	SharedQuestConfig.cfg = {}

	local cfg = SharedQuestConfig.cfg
    for _, row in ipairs(rows) do
        cfg[row.quest_id] = cfg[row.quest_id] or {
			quest_id = row.quest_id,
			type = row.type,
			only_accept_by_other_activity = row.only_accept_by_other_activity,
			accept_limit = row.accept_limit,
			finish_count = row.finish_count,
			--depend_quest_id = row.depend_quest_id,
			depend_level = row.depend_level,
			depend_item = row.depend_item,
			event_type1 = row.event_type1,
			event_id1 = row.event_id1,
			event_count1 = row.event_count1,
			event_type2 = row.event_type2,
			event_id2 = row.event_id2,
			event_count2 = row.event_count2,
			reward = {},
			drop_id = row.drop_id,
			consume = {},
			begin_time = row.begin_time,
			end_time = row.end_time,
			period = row.period,
			duration = row.duration,
			count_limit = row.count,								
			overtime = row.overtime,
			need_reset1 = ((row.need_reset1 == 0) and 1 or row.need_reset1),
			need_reset2 = ((row.need_reset2 == 0) and 1 or row.need_reset2),
			next_quest = row.next_quest,
			team_fight_id = row.team_fight,
			limit_reward = row.limit_reward,  --限制奖励的计次道具
			activity_type = row.activity_type,
		}

		insertItem(cfg[row.quest_id].reward, row.reward_type1, row.reward_id1, row.reward_value1)
		insertItem(cfg[row.quest_id].reward, row.reward_type2, row.reward_id2, row.reward_value2)
		insertItem(cfg[row.quest_id].reward, row.reward_type3, row.reward_id3, row.reward_value3)

		insertItem(cfg[row.quest_id].consume, row.consume_type1, row.consume_id1, row.consume_value1)
		insertItem(cfg[row.quest_id].consume, row.consume_type2, row.consume_id2, row.consume_value2)
		insertItem(cfg[row.quest_id].consume, row.consume_type3, row.consume_id3, row.consume_value3)
    end
end

LoadSharedQuestConfig()

function SharedQuestConfig.Get(quest_id)
	return SharedQuestConfig.cfg[quest_id]
end

local function LoadSharedQuestPoolConfig()
	local rows = BinaryConfig.Load("shared_quest_pool", "guild")
	SharedQuestPoolConfig.cfg = {}

	local cfg = SharedQuestPoolConfig.cfg
    for _, row in ipairs(rows) do
		Pools[row.pool_id] = true
		cfg[row.pool_id] = cfg[row.pool_id] or {}
		cfg[row.pool_id][row.quest_id] = {
			quest_id = row.quest_id,
			weight = row.weight,
			refresh_time_min = row.refresh_time_min,
			refresh_time_max = row.refresh_time_max,
		}
		--[[table.insert(cfg[row.pool_id], {
			quest_id = row.quest_id,
			weight = row.weight,
			refresh_time_min = row.refresh_time_min,
			refresh_time_max = row.refresh_time_max,
		})--]]
    end
end

LoadSharedQuestPoolConfig()

function SharedQuestPoolConfig.Get(pool_id)
	return SharedQuestPoolConfig.cfg[pool_id]
end

function SharedQuestPoolConfig.GetQuestCfg(pool_id, quest_id)
	if not SharedQuestPoolConfig.cfg[pool_id] then
		return nil
	end

	return SharedQuestPoolConfig.cfg[pool_id][quest_id]
end

local QUEST_STATUS_INIT = 0
local QUEST_STATUS_FINISH = 1 
local QUEST_STATUS_CANCEL = 2 

local AllSharedQuest = {}
local SharedQuest = {}
local AllPlayerQuest = {}
local PlayerQuestByID = {}
local PlayerQuest = {}

local function GetPlayerQuest(pid)
	if not AllPlayerQuest[pid] then
		AllPlayerQuest[pid] = PlayerQuest.New(pid)
	end

	return AllPlayerQuest[pid]
end

local quest_exist = {}
local function QuestExist(quest_id) 
	if quest_exist[quest_id] then
		log.debug(string.format("quest %d exist", quest_id))
	end
	return quest_exist[quest_id]
end

local function SetQuestExist(quest_id)
	quest_exist[quest_id] = true
end

local function CleanQuestExist(quest_id)
	if quest_id > 0 then
		quest_exist[quest_id] = nil
	end
end

local function RecordQuest(player, quest_id)
	PlayerQuestByID[quest_id] = PlayerQuestByID[quest_id] or {}
	table.insert(PlayerQuestByID[quest_id], player)
end

local function GetPlayerQuestByID(quest_id)
	return PlayerQuestByID[quest_id]
end

local function QuestInTime(cfg, t)
	if not cfg then
		return false
	end

	local now = t or loop.now() 

    local begin_time = cfg.begin_time;
    local end_time = cfg.end_time;

    if begin_time and now < begin_time then
        return false 
   	end 

    if end_time and now > end_time then
        return false 
   	end 

    local period = cfg.period > 0 and cfg.period or 0xffffffff
    local duration = cfg.duration > 0 and cfg.duration or period

    local total_pass = now - begin_time
    local period_pass = total_pass % period

    if period_pass > duration then
        return false;
   	end 

    return true;
end

local function GetQuestPeriodTime(cfg)
	local now = loop.now() 

    local begin_time = cfg.begin_time;
    local end_time = cfg.end_time;

    if begin_time and now < begin_time then
        return false 
   	end 

    if end_time and now > end_time then
        return false 
   	end 

    local period = cfg.period > 0 and cfg.period or 0xffffffff
    local duration = cfg.duration > 0 and cfg.duration or period

    local total_pass = now - begin_time
    local period_pass = total_pass % period

	local period_begin = now - period_pass;
	local period_end = period_begin + cfg.duration

    return period_begin, period_end;
end

function SharedQuest.New(id, quest_id, start_time, players, finish_count, db_exists)
	local t = {
		id = id,
		quest_id = quest_id,
		start_time = start_time,
		finish_count = finish_count,
		db_exists = db_exists,
		players = players,	
	}	

	return setmetatable(t, {__index = SharedQuest})
end

function SharedQuest:NewPeriod(calc_time, start_time, quest_id)
	quest_id = quest_id or self.quest_id
	calc_time = calc_time or loop.now()
	start_time = start_time or self.start_time

	log.debug("calc_time start_time quest_id", calc_time, start_time, quest_id)
	local cfg = SharedQuestConfig.Get(quest_id)
    if not cfg  then
		log.debug("newperiod here return 1")
        return false 
   	end 

    if cfg.period == 0 then
		log.debug("newperiod here return 2")
        return false 
   	end 

    local period = cfg.period > 0 and cfg.period or 0xffffffff

    local total_pass = calc_time - cfg.begin_time;
    local period_pass = total_pass % period;

    local period_begin = calc_time - period_pass;
	local period_end = period_begin + cfg.duration

	log.debug("newperiod here", start_time, period_begin)
	if quest_id == 0 or start_time < period_begin then
		return true, period_begin 
	end 

	log.debug("newperiod here return 3")
    return false;	
end

function SharedQuest:GetPeriodBegin(t)
	local t = t or loop.now() 
    local period = cfg.period > 0 and cfg.period or 0xffffffff

    local total_pass = t - cfg.begin_time;
    local period_pass = total_pass % period;

    local period_begin = t - period_pass;
	local period_end = period_begin + cfg.duration

	return period_begin
end

function SharedQuest:RefreshQuest()
	local data_change = false 
	log.debug("refresh quest", self.id)
	local refresh_time = 0 
	if self.quest_id > 0 then
		local qcfg = SharedQuestPoolConfig.GetQuestCfg(self.id, self.quest_id)
		if self.quest_id > 0 and not qcfg then
			log.warning(string.format("cannt get refresh time for pool:%d  quest:%d", self.id, self.quest_id))
			return 
		end

		refresh_time = math.random(qcfg.refresh_time_min, qcfg.refresh_time_max)
	end

	local pcfg = SharedQuestPoolConfig.Get(self.id)
	if not pcfg then
		return
	end

	local t = {total_weight = 0, quest_pool = {}}
	for k, v in pairs(pcfg) do
		local cfg = SharedQuestConfig.Get(v.quest_id)
		if cfg then
			local period_begin, period_end = GetQuestPeriodTime(cfg)
			--if QuestInTime(cfg) and not QuestExist(v.quest_id) and (period_end and (period_end - loop.now() > v.refresh_time_min)) then

			if QuestInTime(cfg, loop.now() + refresh_time) and (not QuestExist(v.quest_id) or self.quest_id == v.quest_id) then
				t.total_weight = t.total_weight + v.weight
				table.insert(t.quest_pool, v)
			end
		end
	end

	print("quest pool>>>>>>", sprinttb(t))

	if t.total_weight > 0 then
		local new_period, period_begin = self:NewPeriod()
		CleanQuestExist(self.quest_id)
		local player_quest_cancel_by_refresh = false
		for k, player_quest in ipairs(self.players) do
			local quest = player_quest:GetQuest(self.quest_id)
			--TODO
			if quest.status == QUEST_STATUS_INIT then
				player_quest:Cancel(self.quest_id)
				player_quest_cancel_by_refresh = true
			end
		end
		if player_quest_cancel_by_refresh then
			self:Notify()
		end

		self.players = {}

		local rand_weight = math.random(1, t.total_weight)
		local rand_quest 
		for k, v in ipairs(t.quest_pool) do
			if rand_weight <= v.weight then
				rand_quest = v
				break 
			else
				rand_weight = rand_weight - v.weight
			end		
		end
	
		if not rand_quest then
			return
		end

		print("random quest >>>>>>>>>>>>>>>>>>>", rand_quest.quest_id)
		self.quest_id = rand_quest.quest_id
		SetQuestExist(self.quest_id)

		local new_period, period_begin = self:NewPeriod(loop.now() + refresh_time, self.start_time, self.quest_id)
		log.debug("NewPeriod >>>>>>>>>>>>", refresh_time, tostring(new_period), period_begin)
		if new_period then
			self.start_time = period_begin--loop.now()
		else
			--local cfg = SharedQuestConfig.Get(rand_quest.quest_id)
			--local period_begin, period_end = GetQuestPeriodTime(cfg)
			--self.start_time = loop.now() + math.random(rand_quest.refresh_time_min, math.min(rand_quest.refresh_time_max, period_end - loop.now()))
			self.start_time = loop.now() + refresh_time 
		end

		self.finish_count = 0
	
		data_change = true
	end

	print("#####################", self.id, self.quest_id, self.db_exists)
	if data_change then
		if not self.db_exists then
			database.update("insert into shared_quest(id, quest_id, start_time, finish_count) values(%d, %d, from_unixtime_s(%d), %d)", self.id, self.quest_id, self.start_time, self.finish_count)
			self.db_exists = true
		else
			database.update("update shared_quest set quest_id = %d, start_time = from_unixtime_s(%d), finish_count = %d where id = %d", self.quest_id, self.start_time, self.finish_count, self.id)
		end

		self:Notify()
	end
end

function SharedQuest:CheckAndUpdate()
	local cfg = SharedQuestConfig.Get(self.quest_id)

	if self.quest_id == 0 or (not QuestInTime(cfg) and self.start_time < loop.now()) or self:NewPeriod() then--or self:NewPeriod() then
		self:RefreshQuest()
	else		
		local remove_list = {}
		for k, player_quest in ipairs(self.players) do
			local quest = player_quest:GetQuest(self.quest_id)
			if quest.status ~= QUEST_STATUS_INIT then
				table.insert(remove_list, k)
			end
		end

		for i = #remove_list, 1, -1 do
			local idx = remove_list[i]
			table.remove(self.players, idx)
		end

		if #remove_list > 0 then
			self:Notify()
		end

	end
end

function SharedQuest:Notify()
	local t = {}
	for _, player_quest in ipairs(self.players) do
		local quest = player_quest:GetQuest(self.quest_id)
		table.insert(t, {player_quest.pid, quest.status, quest.record1, quest.record2, quest.count, quest.accept_time, quest.submit_time})
	end
	print("Notify to all player >>>>>>>>>>>>>>>>>>>>>>>>>>>")
	NetService.NotifyClients(Command.NOTIFY_SHARED_QUEST_CHANGE, {self.id, self.quest_id, self.start_time, self.finish_count, t, {}})
	--return {self.id, self.quest_id, self.start_time, self.finish_count, t}
end

function SharedQuest:Query()
	self:CheckAndUpdate()
	local t = {}
	for _, player_quest in ipairs(self.players) do
		local quest = player_quest:GetQuest(self.quest_id)
		table.insert(t, {player_quest.pid, quest.status, quest.record1, quest.record2, quest.count, quest.accept_time, quest.submit_time})
	end

	return {self.id, self.quest_id, self.start_time, self.finish_count, t}
end

function SharedQuest:PlayerAlreadyAccept(pid)
	print(">>>>>>self.players>>>>>>>>>>>>>>>>", sprinttb(self.players))
	for _, player in ipairs(self.players) do
		if pid == player.pid then
			return true
		end
	end

	return false
end

function SharedQuest:PlayerIndex(pid)
	for k, player in ipairs(self.players) do
		if pid == player.pid then
			return k 
		end
	end

	return 0
end

function SharedQuest:HasPermission(pid, cfg)
	if not cfg then
		return false
	end

	if cfg and cfg.team_fight_id == 0 then
		return true, {pid}
	end

	local team = getTeamByPlayer(pid) 
	if not team then
		return true, {pid}
	end

	if team.leader_pid ~= pid then
		log.debug("not leader")
		return false
	end

	return true, team.members
end

function SharedQuest:Accept(opt_id)
	self:CheckAndUpdate()

	log.debug(string.format("Player %d begin to accept shared quest %d", opt_id, self.id))

	if self.quest_id == 0 then
		log.debug(string.format("fail to accept shared quest %d , quest_id is 0", self.id))
		return false
	end

	if loop.now() < self.start_time then
		log.debug(string.format("fail to accept shared quest %d , not start", self.id))
		return false
	end

	local cfg = SharedQuestConfig.Get(self.quest_id)
	if not cfg then
		log.debug(string.format("fail to accept shared quest %d , cfg is nil", self.id))
		return false
	end

	if self.finish_count >= cfg.finish_count then
		log.debug(string.format("fail to submit shared quest %d , finish count already reach max", self.id))
		return false
	end

	if #self.players >= cfg.accept_limit then
		log.debug(string.format("fail to accept shared quest %d, already reach accept max", self.id))
		return false
	end

	if self:PlayerAlreadyAccept(opt_id) then
		log.debug(string.format("fail to accept shared quest %d, already accept", self.id))
		return false
	end

	local has_permission, pids = self:HasPermission(opt_id, cfg) 
	if not has_permission then
		log.debug(string.format("fail to accept shared quest %d, player not has permission", self.id))
		return
	end

	local player_quest = GetPlayerQuest(opt_id)
	if not player_quest:Accept(self.quest_id) then
		log.debug(string.format("fail to accept shared quest %d, player accept fail", self.id))
		return false
	end 

	table.insert(self.players, player_quest)

	self:Notify()
	return true, cfg, pids
end

function SharedQuest:Cancel(opt_id)
	self:CheckAndUpdate()

	log.debug(string.format("Player %d begin to cancel shared quest %d", opt_id, self.id))
	if self.quest_id == 0 then
		log.debug(string.format("fail to cancel shared quest %d , quest_id is 0", self.id))
		return false
	end

	if not self:PlayerAlreadyAccept(opt_id) then
		log.debug(string.format("fail to cancel shared quest %d, player not has this shared quest", self.id))
		return false
	end

	local player_quest = GetPlayerQuest(opt_id)
	if not player_quest:Cancel(self.quest_id) then
		log.debug(string.format("fail to cancel shared quest %d, player cancel fail", self.id))
		return false
	end

	local idx = self:PlayerIndex(opt_id)
	if idx == 0 then
		log.debug(string.format("fail to cancel shared quest %d, cannt get idx for player", self.id))
		return false
	end

	table.remove(self.players, idx)
	self:Notify()
	return true
end

function SharedQuest:SendRewardToTeammate(pid, cfg)
	if not DOReward(pid, cfg.reward, nil, Command.REASON_SHARED_QUEST, false, 0, nil) then
		log.debug("send reward fail")
		return false
	end

	if bit32.band(cfg.need_reset1, 2^1) ~= 0 then
		local consume = {}
		for k, v in ipairs(cfg.consume) do
			table.insert(consume, {type = v.type, id = v.id, value = v.value, empty = 1})	
		end
		DOReward(pid, nil, consume, Command.REASON_SHARED_QUEST, false, 0, nil)
	end

	-- send drop
	if cfg.drop_id ~= 0 then
		cell.sendDropReward(pid, {cfg.drop_id}, Command.REASON_SHARED_QUEST)	
	end
end

function SharedQuest:Submit(opt_id, teammates, from_client)
	self:CheckAndUpdate()

	log.debug(string.format("Player %d begin to submit shared quest %d", opt_id, self.id))
	if self.quest_id == 0 then
		log.debug(string.format("fail to submit shared quest %d , quest_id is 0", self.id))
		return false
	end

	local cfg = SharedQuestConfig.Get(self.quest_id)
	if not cfg then
		log.debug(string.format("fail to submit shared quest %d , shared quest config is nil", self.id))
		return false
	end

	if self.finish_count >= cfg.finish_count then
		log.debug(string.format("fail to submit shared quest %d , finish count already reach max", self.id))
		return false
	end

	if not self:PlayerAlreadyAccept(opt_id) then
		log.debug(string.format("fail to submit shared quest %d, player not has this shared quest", self.id))
		return false
	end

	local player_quest = GetPlayerQuest(opt_id)
	if not player_quest:Submit(self.quest_id, from_client) then
		log.debug(string.format("fail to submit shared quest %d, player submit fail", self.id))
		return false
	end

	if teammates and #teammates > 0 then
		for _, pid in ipairs(teammates) do
			self:SendRewardToTeammate(pid, cfg)
			cell.NotifyQuestEvent(pid, {{type = 96, id = cfg.activity_type, count = 1}})	
		end
	end

	self.finish_count = self.finish_count + 1
	if not self.db_exists then
		database.update("insert into shared_quest(id, quest_id, start_time, finish_count) values(%d, %d, from_unixtime_s(%d), %d)", self.id, self.quest_id, self.start_time, self.finish_count)
		self.db_exists = true
	else
		database.update("update shared_quest set finish_count = %d where id = %d", self.finish_count, self.id)
	end

	self:Notify()

	local idx = self:PlayerIndex(opt_id)
	if idx == 0 then
		log.debug(string.format("fail to submit shared quest %d, cannt get idx for player", self.id))
		return false
	end

	table.remove(self.players, idx)

	local pcfg = SharedQuestPoolConfig.Get(self.id)
	if not pcfg or not pcfg[self.quest_id] then
		return
	end

	if cfg and self.finish_count >= cfg.finish_count and pcfg[self.quest_id].refresh_time_min > 0 and pcfg[self.quest_id].refresh_time_max > 0 then
		self:RefreshQuest() 
	end

	cell.NotifyQuestEvent(opt_id, {{type = 96, id = cfg.activity_type, count = 1}})	
	return true
end

function PlayerQuest.New(pid)
	local t = {
		pid = pid,
		quests = {},
	}

	return setmetatable(t, {__index = PlayerQuest})
end

function PlayerQuest:InitQuest(quest_id, status, count, record1, record2, consume_item_save1, consume_item_save2, accept_time, submit_time)
	local quest = {
		quest_id = quest_id, 
		status = status, 
		count = count, 
		record1 = record1, 
		record2 = record2, 
		consume_item_save1 = consume_item_save1, 
		consume_item_save2 = consume_item_save2, 
		accept_time = accept_time, 
		submit_time = submit_time,
	}
	self.quests[quest_id] = quest

	self:GetQuest(quest_id)
	if quest.status == QUEST_STATUS_INIT then
		RecordQuest(self, quest_id)
	end
end

function PlayerQuest:Query(quest_id)
	print("Query >>>>>>>   ", quest_id)
	local quest = self:GetQuest(quest_id)
	if quest then
		return {quest.quest_id, quest.status, quest.record1, quest.record2, quest.count, quest.accept_time, quest.submit_time}	
	else
		return {}
	end
end

local function TRY_UPDATE(quest, key, v)
	--print("key v", key, quest[key], v)
	if v >= 0 and quest[key] ~= v then
		quest[key] = v
		return true 
	end

	return false
end

function PlayerQuest:Notify(quest)
	NetService.NotifyClients(Command.NOTIFY_PLAYER_SHARED_QUEST_CHANGE, {quest.quest_id, quest.status, quest.record1, quest.record2, quest.count, quest.accept_time, quest.submit_time}, {self.pid})
end

function PlayerQuest:UpdateQuestStatus(quest_id, status, record1, record2, count, consume_item_save1, consume_item_save2, accept_time, submit_time)
	local cfg = SharedQuestConfig.Get(quest_id)
	if not cfg then
		return false	
	end

	local quest = self.quests[quest_id]
	assert(quest ~= nil)

	local change = false
	if TRY_UPDATE(quest, "status", status) then
		change = true
	end
	if TRY_UPDATE(quest, "record1", record1) then
		change = true
	end
	if TRY_UPDATE(quest, "record2", record2) then
		change = true
	end
	if TRY_UPDATE(quest, "count", count) then
		change = true
	end
	if TRY_UPDATE(quest, "consume_item_save1", consume_item_save1) then
		change = true
	end
	if TRY_UPDATE(quest, "consume_item_save2", consume_item_save2) then
		change = true
	end
	if TRY_UPDATE(quest, "accept_time", accept_time) then
		change = true
	end
	if TRY_UPDATE(quest, "submit_time", submit_time) then
		change = true
	end
	
	if change then
		database.update("update player_shared_quest set status = %d, count = %d, record1 = %d, record2 = %d, consume_item_save1 = %d, consume_item_save2 = %d, accept_time = from_unixtime_s(%d), submit_time = from_unixtime_s(%d) where pid = %d and quest_id = %d", quest.status, quest.count, quest.record1, quest.record2, quest.consume_item_save1, quest.consume_item_save2, quest.accept_time, quest.submit_time, self.pid, quest_id)

		self:Notify(quest)
	end
end

function PlayerQuest:GetQuest(quest_id, cfg)
	local quest = self.quests[quest_id]

	cfg = cfg and cfg or SharedQuestConfig.Get(quest_id)
    if not cfg  then
        return nil
   	end 

    --[[if cfg.period == 0 then
        return quest 
   	end--]]

    local now = loop.now() 
    local period = cfg.period > 0 and cfg.period or 0xffffffff

    local total_pass = now - cfg.begin_time;
    local period_pass = total_pass % period;

    local period_begin = now - period_pass;
	local period_end = period_begin + cfg.duration

	
	if not quest then
		return nil
	end

	if quest.accept_time < period_begin then
		log.debug(string.format("  quest %d status reset to cancel by period", quest_id));
		self:UpdateQuestStatus(quest_id, QUEST_STATUS_CANCEL, -1, -1, 0, -1, -1, -1, -1);
	end 

	if quest.status == QUEST_STATUS_INIT and cfg.overtime > 0 and now > quest.accept_time + cfg.overtime then
		log.debug(string.format("  quest %d status reset to cancel because overtime", quest_id));
		self:UpdateQuestStatus(quest_id, QUEST_STATUS_CANCEL, -1, -1, 0, -1, -1, -1, -1);
	end

    return quest;	
end

function PlayerQuest:CheckLevelLimit(pid, cfg)
	if not cfg then
		return  false
	end

	local player_info = GetPlayer(pid)
	if not player_info then
		log.debug("player not exist")
		return false
	end

	if player_info.level >= cfg.depend_level then
		return true
	end	

	if loop.now() - player_info.update_time < 5 then
		log.debug(" level %d/%d is not enough", player_info.level, cfg.depend_level)
		return false
	end

	player_info = GetPlayer(pid, true)
	if not player_info then
		log.debug("player not exist")
		return false
	end

	if player_info.level < cfg.depend_level then
		log.debug(" level %d/%d is not enough", player_info.level, cfg.depend_level)
		return false
	end

	return true
end

function PlayerQuest:Accept(quest_id, from_client)
	log.debug(string.format("Player %d accept (shared)quest %d, from %s", self.pid, quest_id, from_client == 1 and "client" or "server"));
	local now = loop.now()

	local cfg = SharedQuestConfig.Get(quest_id)
	if not cfg then 
		log.debug("shared quest config not exists")
		return false
	end	

	if cfg.only_accept_by_other_activity == 1 and from_client then 
		log.debug("  quest can't change by client")
		return false
	end	

	if not QuestInTime(cfg) then
		log.debug("quest not in time")
		return false
	end

	if self.CheckLevelLimit(self.pid, cfg) then
		return false
	end

	--[[if cfg.depend_quest_id ~= 0 then
		local dcfg = SharedQuestConfig.Get(cfg.depend_quest_id)
		if not dcfg then
			log.debug(" cannt get depend quest config")
			return false
		end

		local dquest = self:GetQuest(cfg.depend_quest_id, dcfg)
		if dquest.status ~= QUEST_STATUS_FINISH then
			log.debug(" depend quest not finish")
			return false
		end
	end--]]

	if cfg.depend_item ~= 0 then
		--check item
		if not DOReward(self.pid, nil, {{type = 41, id = cfg.depend_item, value = 0}}, Command.REASON_SHARED_QUEST, false, 0, nil) then
			log.debug("item %d not exists", cfg.depend_item)
			return false
		end
	end

	local quest = self:GetQuest(quest_id, cfg)
	if quest then
		if quest.status == QUEST_STATUS_INIT then
			log.debug("quest already exists")
			return false 
		elseif cfg.count_limit > 0 and quest.count >= cfg.count_limit then
			log.debug("quest reach period count limit %d/%d", quest.count, cfg.count_limit)
			return false
		end				

		self:UpdateQuestStatus(quest_id, QUEST_STATUS_INIT, 0, 0, -1, 0, 0, now, -1)
	else 
		self:AddQuest(quest_id, QUEST_STATUS_INIT)
	end	

	--do consume 
	if not self:CheckConsumeWhenAccept(cfg.need_reset1, cfg) then
		return false
	end

	if not self:CheckConsumeWhenAccept(cfg.need_reset2, cfg) then
		return false
	end
	--[[if bit32.band(cfg.need_reset1, 2^2) ~= 0 then
		if not DOReward(self.pid, nil, cfg.consume, Command.REASON_SHARED_QUEST, false, 0, nil) then
			log.debug("donnt has consume item, cannt accept quest")
			return false
		end
	end

	if bit32.band(cfg.need_reset1, 2^3) ~= 0 then
		local consume = {}
		for k, v in iparis(cfg.consume) do
			table.insert(consume, {type = v.type, id = v.id, value = v.value, empty = 1})	
		end
		DOReward(self.pid, nil, consume, Command.REASON_SHARED_QUEST, false, 0, nil)	
	end--]]

	return true
end

function PlayerQuest:AddQuest(quest_id, status)
	local cfg = SharedQuestConfig.Get(quest_id)
	if not cfg then
		return false	
	end

	local now = loop.now()
	local t = {
		quest_id = quest_id, 
		status = status, 
		count = 0, 
		record1 = 0, 
		record2 = 0, 
		consume_item_save1 = 0, 
		consume_item_save2 = 0, 
		accept_time = now, 
		submit_time = 0,
	}

	if self.quests[quest_id] then
		log.debug("add quest fail, quest already exist")
		return false
	end	

	self.quests[quest_id] = t	
	
	database.update("insert into player_shared_quest (pid, quest_id, status, count, record1, record2, consume_item_save1, consume_item_save2, accept_time, submit_time) values(%d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d))", self.pid, quest_id, status, 0, 0, 0, 0, 0, now, 0)	
	self:Notify(t)

	return t 
end

function PlayerQuest:Cancel(quest_id, from_client)
	log.debug(string.format("Player %d cancel (shared)quest %d, from %s", self.pid, quest_id, from_client == 1 and "client" or "server"));

	local cfg = SharedQuestConfig.Get(quest_id)
	if not cfg then
		log.debug("quest config not exists")
		return false
	end

	if cfg.only_accept_by_other_activity == 1 and from_client then
		log.debug("quest can't change by client")
		return false
	end

	if not QuestInTime(cfg) then
		log.debug("quest not in time")
		return false
	end

	local quest = self:GetQuest(quest_id)
	if not quest then
		log.debug(" quest not exist")
		return false
	end

	if quest.status ~= QUEST_STATUS_INIT then
		log.debug("quest status can't cancel", quest.status)
		return false
	end

	self:UpdateQuestStatus(quest_id, QUEST_STATUS_CANCEL, -1, -1, -1, -1, -1, -1, -1)
	return true
end

function PlayerQuest:CheckQuestEvent(record, type, id, count) 
	if record < count then
        log.debug("  event %d, %d not enough %d/%d", type, id, record, count);
        return false 
   	end 

    return true 
end

function PlayerQuest:CheckConsumeWhenAccept(need_reset, cfg)
	if bit32.band(need_reset, 2^2) == 1 and bit32.band(need_reset, 2^3) == 0 then
		if not DOReward(self.pid, nil, cfg.consume, Command.REASON_SHARED_QUEST, false, 0, nil) then
			log.debug("consume fail")
			return false
		end	
	end

	if bit32.band(need_reset, 2^2) == 0 and bit32.band(need_reset, 2^3) == 1 then
		local consume = {}
		for k, v in ipairs(cfg.consume) do
			table.insert(consume, {type = v.type, id = v.id, value = v.value, empty = 1})	
		end
		return DOReward(self.pid, nil, consume, Command.REASON_SHARED_QUEST, false, 0, nil)	
	end

	if bit32.band(need_reset, 2^2) == 1 and bit32.band(need_reset, 2^3) == 1 then
		local consume = {}
		for k, v in ipairs(cfg.consume) do
			table.insert(consume, {type = v.type, id = v.id, value = v.value, empty = 2})	
		end
		return DOReward(self.pid, nil, consume, Command.REASON_SHARED_QUEST, false, 0, nil)	
	end

	return true
end

function PlayerQuest:CheckConsumeWhenSubmit(need_reset, cfg)
	if bit32.band(need_reset, 2^0) == 1 and bit32.band(need_reset, 2^1) == 0 then
		if not DOReward(self.pid, nil, cfg.consume, Command.REASON_SHARED_QUEST, false, 0, nil) then
			log.debug("consume fail")
			return false
		end	
	end

	if bit32.band(need_reset, 2^0) == 0 and bit32.band(need_reset, 2^1) == 1 then
		local consume = {}
		for k, v in ipairs(cfg.consume) do
			table.insert(consume, {type = v.type, id = v.id, value = v.value, empty = 1})	
		end
		return DOReward(self.pid, nil, consume, Command.REASON_SHARED_QUEST, false, 0, nil)	
	end

	if bit32.band(need_reset, 2^0) == 1 and bit32.band(need_reset, 2^1) == 1 then
		local consume = {}
		for k, v in ipairs(cfg.consume) do
			table.insert(consume, {type = v.type, id = v.id, value = v.value, empty = 2})	
		end
		return DOReward(self.pid, nil, consume, Command.REASON_SHARED_QUEST, false, 0, nil)	
	end

	return true
end

function PlayerQuest:Submit(quest_id, from_client)
	log.debug(string.format("Player %d submit (shared)quest %d, from %s", self.pid, quest_id, from_client == 1 and "client" or "server"));
	local now = loop.now()

	local cfg = SharedQuestConfig.Get(quest_id)
    if not cfg then 
        log.debug("  quest config not exists");
		return false
	end

	if cfg.only_accept_by_other_activity == 1 and from_client == 1 then
        log.debug("  quest can't change by client")
		return false
	end

	if not QuestInTime(cfg) then
		log.debug(" quest not in time")
		return false
	end

	local quest = self:GetQuest(quest_id)
    if not quest then 
        log.debug(" quest not exists")
        return false 
   	end 

	if quest.status ~= QUEST_STATUS_INIT then
        log.debug(string.format(" quest status %d can't submit", quest.status));
		return false
	end

	-- check event record
	if not self:CheckQuestEvent(quest.record1, cfg.event_type1, cfg.event_id1, cfg.event_count1) then
		return false
	end

	if not self:CheckQuestEvent(quest.record2, cfg.event_type2, cfg.event_id2, cfg.event_count2) then
		return false
	end

	-- check consume and send reward
	
	if not self:CheckConsumeWhenSubmit(cfg.need_reset1, cfg) then
		return false
	end

	if not self:CheckConsumeWhenSubmit(cfg.need_reset2, cfg) then
		return false	
	end

	print("pid   limit_reward>>>>>>> ", self.pid,   cfg.limit_reward)
	if cfg.limit_reward ~= 0 then
		if not DOReward(self.pid, cfg.reward, {type = 41, id = cfg.limit_reward, value = 0}, Command.REASON_SHARED_QUEST, false, 0, nil) then
			print("player not has limit reward", self.pid)
			return true 
		end

		print("send drop reward >>>>>>", cfg.drop_id)
		if cfg.drop_id ~= 0 then
			cell.sendDropReward(self.pid, {cfg.drop_id}, Command.REASON_SHARED_QUEST)	
		end
	else
		DOReward(self.pid, cfg.reward, nil, Command.REASON_SHARED_QUEST, false, 0, nil) 

		print("send drop reward >>>>>>", cfg.drop_id)
		if cfg.drop_id ~= 0 then
			cell.sendDropReward(self.pid, {cfg.drop_id}, Command.REASON_SHARED_QUEST)	
		end
	end	

	--[[if bit32.band(cfg.need_reset1, 2^0) ~= 0 then
		if not DOReward(self.pid, cfg.reward, cfg.consume, Command.REASON_SHARED_QUEST, false, 0, nil) then
			log.debug("consume fail")
			return false
		end
	else
		if not DOReward(self.pid, cfg.reward, nil, Command.REASON_SHARED_QUEST, false, 0, nil) then
			log.debug("send reward fail")
			return false
		end
	end	

	if bit32.band(cfg.need_reset1, 2^1) ~= 0 then
		local consume = {}
		for k, v in ipairs(cfg.consume) do
			table.insert(consume, {type = v.type, id = v.id, value = v.value, empty = 1})	
		end
		DOReward(self.pid, nil, consume, Command.REASON_SHARED_QUEST, false, 0, nil)
	end--]]

	-- send drop
	--[[if cfg.drop_id ~= 0 then
		cell.sendDropReward(pid, {cfg.drop_id}, Command.REASON_SHARED_QUEST)	
	end--]]

	self:UpdateQuestStatus(quest_id, QUEST_STATUS_FINISH, -1, -1, quest.count + 1, -1, -1, -1, now);

    log.debug(string.format("  next quest id %d", cfg.next_quest));

	--[[if cfg.next_quest ~= 0 then
		local next_cfg = SharedQuestConfig.Get(cfg.next_quest)
        log.debug("  next quest config %p auto_accept %d", next_cfg, next_cfg and next_cfg.auto_accept or 0)
        if next_cfg and bit32.band(next_cfg.auto_accept, 1) ~= 0 then
            log.debug("  accept next quest %d", cfg.next_quest)
			self:Accept(cfg.next_quest, 1)
       	end 
   	end--]]

    return true
end

local function LoadAllSharedQuest()
	for id, _ in pairs(Pools) do
		AllSharedQuest[id] = SharedQuest.New(id, 0, 0, {}, 0, false)
	end

	local success, result = database.query("select id, quest_id, finish_count, unix_timestamp(start_time) as start_time from shared_quest ")	
	if success and #result > 0 then
		for i = 1, #result, 1 do
			local row = result[i]
			if AllSharedQuest[row.id] then
				local p = {}
				local player_quests = GetPlayerQuestByID(row.quest_id)
				for _, player_quest in ipairs(player_quests or {}) do
					local quest = player_quest:GetQuest(row.quest_id)
					local cfg = SharedQuestConfig.Get(row.quest_id) 	
					if cfg and QuestInTime(cfg) and quest.status == QUEST_STATUS_INIT then
						table.insert(p, player_quest)
					end
				end
				
				AllSharedQuest[row.id] = SharedQuest.New(row.id, row.quest_id, row.start_time, p, row.finish_count, true)	
			end
		end
	end

	PlayerQuestByID = nil

	return true
end

local function LoadAllPlayers()
	local success, result = database.query("select pid, quest_id, status, count, record1, record2, consume_item_save1, consume_item_save2, unix_timestamp(accept_time) as accept_time, unix_timestamp(submit_time) as submit_time from player_shared_quest")
	if success and #result > 0 then
		for i = 1, #result, 1 do
			local row = result[i]
			if not AllPlayerQuest[row.pid] then
				AllPlayerQuest[row.pid] = PlayerQuest.New(row.pid)
			end
			AllPlayerQuest[row.pid]:InitQuest(row.quest_id, row.status, row.count, row.record1, row.record2, row.consume_item_save1, row.consume_item_save2, row.accept_time, row.submit_time)
		end
	end

	return true
end


local function LoadAll()
	return LoadAllPlayers() and LoadAllSharedQuest()
end

LoadAll()

local function onEvent(pid, event_type, event_id, count)
	for id, shared_quest in pairs(AllSharedQuest) do
		shared_quest:CheckAndUpdate()
		local cfg = SharedQuestConfig.Get(shared_quest.quest_id) 	
		if cfg then
			if QuestInTime(cfg) then
				for _, player_quest in ipairs(shared_quest.players) do
					if player_quest.pid == pid then
						local quest = player_quest:GetQuest(shared_quest.quest_id)
						if quest.status == QUEST_STATUS_INIT then
							local r1 = quest.record1
							local r2 = quest.record2
							if cfg.event_type1 == event_type and cfg.event_id1 == event_id then
								r1 = r1 + count
								if r1 > cfg.event_count1 then
									r1 = cfg.event_count1
								end
							end

							if cfg.event_type2 == event_type and cfg.event_id2 == event_id then
								r2 = r2 + count
								if r2 > cfg.event_count2 then
									r2 = cfg.event_coun2t
								end
							end

							player_quest:UpdateQuestStatus(shared_quest.quest_id, quest.status, r1, r2, -1, -1, -1, -1, -1);
							shared_quest:Notify()

							--[[if bit32.band(cfg.auto_accept, 2) ~= 0 and r1 >= cfg.event_count1 and r2 >= cfg.event_count2 then
								player_quest:Submit(quest_id)
								shared_quest:CheckAndUpdate()
							end--]]
						end
					end
				end
			end
		end
	end
end

local in_fight = {}
local function AllMemberNotInFight(pids)
	for _, pid in ipairs(pids) do
		if in_fight[pid] then
			return false
		end
	end

	return true
end

local function MemberStartFight(pids)
	local sum_level = 0;
	for _, pid in ipairs(pids) do
		in_fight[pid] = true
		local player = GetPlayer(pid, true);
		if player then
			sum_level = sum_level + player.level
		end
	end

	if sum_level > 0 then
		return sum_level / #pids;
	end
end

local function MemberFinishFight(pids)
	for _, pid in ipairs(pids) do
		in_fight[pid] = nil
	end
end

function registerCommand(service)
	service:on(Command.C_SHARED_QUEST_QUERY_INFO_REQUEST, function(conn, pid, request)
		local cmd = Command.C_SHARED_QUEST_QUERY_INFO_RESPOND
		local sn = request[1]
		local pos = request[2]
		
		if not pos or type(pos) ~= 'table' then
			log.debug("fail to query shared quest info, param 2nd error")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
		end

		log.debug(string.format("Player %d begin to query shared quest", pid))
		local ret = {}
		for _, id in ipairs(pos) do
			if AllSharedQuest[id] then
				local info = AllSharedQuest[id]:Query()
				table.insert(ret, info)
			
				local player_quest = GetPlayerQuest(pid)
				if player_quest then
					table.insert(info, player_quest:Query(AllSharedQuest[id].quest_id) or {})
				end
			end
		end

		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, ret})
	end)

	service:on(Command.C_SHARED_QUEST_ACCEPT_REQUEST, function(conn, pid, request)
		local cmd = Command.C_SHARED_QUEST_ACCEPT_RESPOND
		local sn = request[1]
		local pos = request[2]
		
		if not pos then
			log.debug("fail to accept shared quest, param 2nd is nil")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
		end

		log.debug(string.format("Player %d begin to accept shared quest id:%d", pid, pos))
		local shared_quest = AllSharedQuest[pos]
		if not shared_quest then
			log.debug(string.format("fail to accept shared quest, cannt get shared quest for id %d", pos))
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

		local success, cfg, pids = shared_quest:Accept(pid)
		conn:sendClientRespond(cmd, pid, {sn, success and Command.RET_SUCCESS or Command.RET_ERROR})

		if not success then
			return 
		end

		if cfg and cfg.team_fight_id > 0 and pids and #pids > 0 and AllMemberNotInFight(pids) then
			if not AllMemberNotInFight(pids) then	
				log.warning("some one in fight")
				return 
			end

			RunThread(function()
				local level = MemberStartFight(pids)
				local winner = SocialManager.TeamFightStart(pids, cfg.team_fight_id, level)
				MemberFinishFight(pids)
				local teammates = {}
				for _, playerid in ipairs (pids) do
					if pid ~= playerid then
						table.insert(teammates, playerid)
					end
				end

				print("winner >>>>>>>>>>>>>>>>>>>>", winner)
				if winner and winner == 1 then
					shared_quest:Submit(pid, teammates, 0)
				else
					shared_quest:Cancel(pid)
				end	
			end)
		end
	end)	

	service:on(Command.C_SHARED_QUEST_SUBMIT_REQUEST, function(conn, pid, request)
		local cmd = Command.C_SHARED_QUEST_SUBMIT_RESPOND
		local sn = request[1]
		local pos = request[2]
		
		if not pos then
			log.debug("fail to submit shared quest, param 2nd is nil")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
		end

		log.debug(string.format("Player %d begin to submit shared quest id:%d", pid, pos))
		local shared_quest = AllSharedQuest[pos]
		if not shared_quest then
			log.debug(string.format("fail to submit shared quest, cannt get shared quest for id %d", pos))
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

		local success = shared_quest:Submit(pid, nil, 1)

		return conn:sendClientRespond(cmd, pid, {sn, success and Command.RET_SUCCESS or Command.RET_ERROR})
	end)

	service:on(Command.C_SHARED_QUEST_CANCEL_REQUEST, function(conn, pid, request)
		local cmd = Command.C_SHARED_QUEST_CANCEL_RESPOND
		local sn = request[1]
		local pos = request[2]
		
		if not pos then
			log.debug("fail to cancel shared quest, param 2nd is nil")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
		end

		log.debug(string.format("Player %d begin to cancel shared quest id:%d", pid, pos))
		local shared_quest = AllSharedQuest[pos]
		if not shared_quest then
			log.debug(string.format("fail to cancel shared quest, cannt get shared quest for id %d", pos))
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

		local success = shared_quest:Cancel(pid)

		return conn:sendClientRespond(cmd, pid, {sn, success and Command.RET_SUCCESS or Command.RET_ERROR})
	end)

	service:on(Command.C_SHARED_QUEST_PLAYER_QUEST_QUERY_REQUEST, function(conn, pid, request)
		local cmd = Command.C_SHARED_QUEST_PLAYER_QUEST_QUERY_RESPOND
		local sn = request[1]
		
		log.debug(string.format("Player %d begin to query player quest of shared quest", pid))
		local player_quest = GetPlayerQuest(pid)
		if not player_quest then
			log.debug(string.format("fail to query player quest of shared quest, cannt get player quest for player %d", pid))
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

		local ret = player_quest:Query()
		return conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR, ret})
	end)

end
------------------------------------------------------

--[[function GuildQuest:OnEvent(pid, event_type, event_id, count)
	log.debug(string.format("player %d on quest event %d, id %d, count %d", pid, event_type, event_id, count));

	for quest_id, v in pairs(self.guild_quests) do
		local cfg = GuildQuestConfig.Get(quest_id)
		if cfg then
			local quest = self:GetQuest(pid, quest_id, cfg)
		
			if self:QuestInTime(cfg, quest_id) then
				if quest.status == QUEST_STATUS_INIT then

					local r1 = quest.record1
					local r2 = quest.record2
					if cfg.event_type1 == event_type and cfg.event_id1 == event_id then
						r1 = r1 + count
						if r1 > cfg.event_count1 then
							r1 = cfg.event_count1
						end
					end

					if cfg.event_type2 == event_type and cfg.event_id2 == event_id then
						r2 = r2 + count
						if r2 > cfg.event_count2 then
							r2 = cfg.event_coun2t
						end
					end

					self:UpdateQuestStatus(pid, quest.id, quest.status, r1, r2, -1, -1, -1, -1, -1, -1);
		
					if bit32.band(cfg.auto_accept, 2) ~= 0 and r1 >= cfg.event_count1 and r2 >= cfg.event_count2 then
						self:Submit(pid, quest_id, 1)
					end
				end
			end
		end
	end

	for quest_id, v in pairs(self.player_quests) do
		for playerid, v2 in pairs(v) do
			if playerid == pid then
				local cfg = GuildQuestConfig.Get(quest_id)
				if cfg then
					local quest = self:GetQuest(pid, quest_id, cfg)
				
					if self:QuestInTime(cfg, quest_id) then
						if quest.status == QUEST_STATUS_INIT then

							local r1 = quest.record1
							local r2 = quest.record2
							if cfg.event_type1 == event_type and cfg.event_id1 == event_id then
								r1 = r1 + count
								if r1 > cfg.event_count1 then
									r1 = cfg.event_count1
								end
							end

							if cfg.event_type2 == event_type and cfg.event_id2 == event_id then
								r2 = r2 + count
								if r2 > cfg.event_count2 then
									r2 = cfg.event_coun2t
								end
							end

							self:UpdateQuestStatus(pid, quest.id, quest.status, r1, r2, -1, -1, -1, -1, -1, -1);

							if bit32.band(cfg.auto_accept, 2) ~= 0 and r1 >= cfg.event_count1 and r2 >= cfg.event_count2 then
								self:Submit(pid, quest_id, 1)
							end
						end
					end
				end
			end	
		end
	end 
end

function GuildQuest.QuestOnEvent(pid, t)
	local player = PlayerManager.Get(pid)
	if not player or not player.guild then
		return 
	end

	local manager = GetQuestManager(player.guild.id)
	if not manager then
		return 
	end

	for _, v in ipairs(t) do
		manager:OnEvent(pid, v.type, v.id, v.count)
	end
end

local playerFightInfo = {}

local function CheckAndGetQuestManager(pid)
	local player = PlayerManager.Get(pid)
	if not player or not player.guild then
		log.debug("player not exist or not has guild")
		return false
	end

	local manager = GetQuestManager(player.guild.id)
	if not manager then
		log.debug("get quest manager fail")
		return false
	end

	return manager
end

function GuildQuest.RegisterCommand(service)
	service:on(Command.C_GUILD_QUEST_QUERY_INFO_REQUEST, function(conn, pid, request)
		local cmd = Command.C_GUILD_QUEST_QUERY_INFO_RESPOND
		local sn = request[1]

		local manager = CheckAndGetQuestManager(pid)
		if not manager then
			return conn:sendClientRespond(cmd, pid, {sn, Comamand.RET_ERROR})
		end

		local info1, info2 = manager:QueryInfo(pid)
		return conn:sendClientRespond(cmd, pid, {sn, info1 and Command.RET_SUCCESS or Comamand.RET_ERROR, info1, info2})
	end)			

	service:on(Command.C_GUILD_QUEST_ACCEPT_REQUEST, function(conn, pid, request)
		local cmd = Command.C_GUILD_QUEST_ACCEPT_RESPOND
		local sn = request[1]
		local quest_id = request[2]
		
		if not quest_id then
			log.debug("param 2nd quest_id is nil")
			return conn:sendClientRespond(cmd, pid, {sn, Comamand.PARAM_ERROR})
		end

		local manager = CheckAndGetQuestManager(pid)
		if not manager then
			return conn:sendClientRespond(cmd, pid, {sn, Comamand.RET_ERROR})
		end

		local ret = manager:Accept(pid, quest_id, 1)
		return conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Comamand.RET_ERROR})
	end)

	service:on(Command.C_GUILD_QUEST_CANCEL_REQUEST, function(conn, pid, request)
		local cmd = Command.C_GUILD_QUEST_CANCEL_RESPOND
		local sn = request[1]
		local quest_id = request[2]
		
		if not quest_id then
			log.debug("param 2nd quest_id is nil")
			return conn:sendClientRespond(cmd, pid, {sn, Comamand.PARAM_ERROR})
		end

		local manager = CheckAndGetQuestManager(pid)
		if not manager then
			return conn:sendClientRespond(cmd, pid, {sn, Comamand.RET_ERROR})
		end

		local ret = manager:Cancel(pid, quest_id, 1)
		return conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Comamand.RET_ERROR})
	end)

	service:on(Command.C_GUILD_QUEST_SUBMIT_REQUEST, function(conn, pid, request)
		local cmd = Command.C_GUILD_QUEST_SUBMIT_RESPOND
		local sn = request[1]
		local quest_id = request[2]
		
		if not quest_id then
			log.debug("param 2nd quest_id is nil")
			return conn:sendClientRespond(cmd, pid, {sn, Comamand.PARAM_ERROR})
		end

		local manager = CheckAndGetQuestManager(pid)
		if not manager then
			return conn:sendClientRespond(cmd, pid, {sn, Comamand.RET_ERROR})
		end

		local ret = manager:Submit(pid, quest_id, 1)
		return conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Comamand.RET_ERROR})
	end)
end--]]

--test 
--[[for _, v in pairs(AllSharedQuest) do
	local info = v:Query() 
	print("query shared quest", sprinttb(info))
end

local s_q1 = AllSharedQuest[1]
s_q1:Accept(1)
s_q1:Submit(1)
s_q1:Accept(2)


local s_q2 = AllSharedQuest[2]
s_q2:Accept(2)

onEvent(2, 10, 1, 1)--]]

return {
	RegisterCommand = registerCommand
}
