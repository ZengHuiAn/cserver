local BinaryConfig = require "BinaryConfig"
local GuildItem = require "GuildItem"
local GuildQuestConfig = {}

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

local EVENT_TYPE_CONSUME_ITEM = 41

local function LoadGuildQuestConfig()
	local rows = BinaryConfig.Load("config_guild_quest", "guild")
	GuildQuestConfig.cfg = {}

	local cfg = GuildQuestConfig.cfg
    for _, row in ipairs(rows) do
        cfg[row.quest_id] = cfg[row.quest_id] or {
			quest_id = row.quest_id,
			type = row.type,
			auto_accept = row.auto_accept,
			only_accept_by_other_activity = row.only_accept_by_other_activity,
			permission = row.permission,
			accept_limit = row.accept_limit,
			depend_quest_id = row.depend_quest_id,
			depend_level = row.depend_level,
			depend_item = row.depend_item,
			event_type1 = row.event_type1,
			event_id1 = row.event_id1,
			event_count1 = row.event_count1,
			event_type2 = row.event_type2,
			event_id2 = row.event_id2,
			event_count2 = row.event_count2,
			event_type3 = row.event_type3,
			event_id3 = row.event_id3,
			event_count3 = row.event_count3,
			reward = {},
			drop_id = row.drop_id,
			consume = {},
			begin_time = row.begin_time,
			end_time = row.end_time,
			period = row.period,
			duration = row.duration,
			count_limit = row.count,								
			finish_count = row.finish_count,
			time_limit = row.time_limit,
			refresh_time_min = row.refresh_time_min,
			refresh_time_max = row.refresh_time_max,
			overtime = row.overtime,
			need_reset = ((row.need_reset == 0) and 1 or row.need_reset),
			next_quest = row.next_quest,
			cost_wealth = row.cost_wealth,
			share_refresh_time = row.share_refresh_time or 0,
			team_fight_id = row.team_fight_id,
			auto_send_step_reward = row.auto_send_step_reward,
			only_attender_receive_reward = row.only_attender_receive_reward,
			team_members_limit = row.team_members_limit,
			rank_type = row.rank_type,
			rank_score = row.rank_score,
			relative_quest = row.relative_quest,
			fast_pass_condition1 = row.fast_pass_condition1,
			fast_pass_value1 = row.fast_pass_value1,
			fast_pass_condition2 = row.fast_pass_condition2,
			fast_pass_value2 = row.fast_pass_value2,
		}

		insertItem(cfg[row.quest_id].reward, row.reward_type1, row.reward_id1, row.reward_value1)
		insertItem(cfg[row.quest_id].reward, row.reward_type2, row.reward_id2, row.reward_value2)
		insertItem(cfg[row.quest_id].reward, row.reward_type3, row.reward_id3, row.reward_value3)

		insertItem(cfg[row.quest_id].consume, row.consume_type1, row.consume_id1, row.consume_value1)
		insertItem(cfg[row.quest_id].consume, row.consume_type2, row.consume_id2, row.consume_value2)
		insertItem(cfg[row.quest_id].consume, row.consume_type3, row.consume_id3, row.consume_value3)

		if row.quest_id == 20012001 then
			print("iiiiii", row.consume_type3, row.consume_id3, row.consume_value3, sprinttb(cfg[row.quest_id].consume))
		end
    end
end

LoadGuildQuestConfig()

function GuildQuestConfig.Get(quest_id)
	return GuildQuestConfig.cfg[quest_id]
end


local GuildQuest = {}
local QUEST_TYPE_GUILD = 1
local QUEST_TYPE_PLAYER = 2

local QUEST_STATUS_INIT = 0
local QUEST_STATUS_FINISH = 1 
local QUEST_STATUS_CANCEL = 2 

local Quest = {}
local function GetQuestManager(gid)
	if not Quest[gid] then
		Quest[gid] = GuildQuest.New(gid)
	end

	return Quest[gid]
end

local players = {}
local function GetPlayer(pid, force)
	if not pid  then
		log.error('GetPlayer error', pid, force, debug.traceback());
	end
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

local function SeparateItems(items)
	if not items then
		return 
	end

	local common_items = {}
	local guild_items = {}
	for k, v in ipairs(items) do
		if v.type == 95 then
			table.insert(guild_items, {type = v.type, id = v.id, value = v.value, empty = v.empty})
		else
			table.insert(common_items, {type = v.type, id = v.id, value = v.value, empty = v.empty})
		end	
	end

	return common_items, guild_items
end

local function CheckGuildItemEnough(guild, items)
	local guild_item = GuildItem.Get(guild.id)
	if not guild_item then
		log.debug("check guild item enough fail, cannt get guild item")
		return false
	end

	for _, item in ipairs(items) do
		if not guild_item:CheckEnough(item.id, item.value, item.empty) then
			return false
		end
	end

	return true
end

local function DOGuildItemReward(guild, rewards, consumes)
	local guild_item = GuildItem.Get(guild.id)	
	if not guild_item then
		log.debug("DOGuildItemReward fail, cannt get guild item")
		return false
	end

	print("guild item reward >>>>>>>>>", sprinttb(rewards), sprinttb(consumes))
	for _, reward in ipairs(rewards or {}) do
		guild_item:IncreaseItem(reward.id, reward.value)
	end

	for _, consume in ipairs(consumes or {}) do
		if consume.empty then
			guild_item:RemoveItem(consume.id)
		else
			guild_item:DecreaseItem(consume.id, consume.value)
		end
	end
end

local function DOReward(pid, reward, consume, reason, manual, limit, name)
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
	
	local common_reward, guild_item_reward = SeparateItems(reward)
	local common_consume, guild_item_consume = SeparateItems(consume)

	print("reward   consume", sprinttb(reward), sprinttb(consume))
	local player = PlayerManager.Get(pid)
	if not player or not player.guild then
		log.debug("DOReward fail , player not has guild")
		return false
	end

	print("guild_item_consume >>>>>>>>>", sprinttb(guild_item_consume))
	if guild_item_consume and #guild_item_consume > 0 and not CheckGuildItemEnough(player.guild, guild_item_consume) then
		return false
	end

	local respond = cell.sendReward(pid, common_reward, common_consume, reason, manual, limit, name)
	if respond == nil or respond.result ~= 0 then
		return false;
	end

 	DOGuildItemReward(player.guild, guild_item_reward, guild_item_consume)	

	return true;
end

local function DORewardForGuild(guild, reward, consume, reason, manual, limit, name)
	assert(guild)

	local common_reward, guild_item_reward = SeparateItems(reward)
	local common_consume, guild_item_consume = SeparateItems(consume)
	if guild_item_consume and #guild_item_consume > 0 and not CheckGuildItemEnough(guild, guild_item_consume) then
		return false
	end

	for _, m in pairs(guild.members) do
		print("send guild reward >>>>>>>>>>>>>>>", m.id, sprinttb(reward))
		DOReward(m.id, common_reward, common_consume, Command.REASON_GUILD_QUEST, false, 0, nil) 
	end

	print("aaaaaaaaaaaaaaa", sprinttb(reward), sprinttb(consume), sprinttb(guild_item_reward), sprinttb(guild_item_consume))
 	DOGuildItemReward(guild, guild_item_reward, guild_item_consume)	

	return true
end

local function LoadAttendList(gid, t)
	local success, result = database.query("select gid, pid, quest_id, attender_pid, attender_reward_flag, contribution from guild_quest_attenders where gid = %d", gid)
	if success then
		if #result > 0 then
			for i = 1, #result, 1 do
				local row = result[i]
				local cfg = GuildQuestConfig.Get(row.quest_id)
				if cfg then
					if cfg.type == QUEST_TYPE_GUILD then
						if t.guild_quests[row.quest_id] then
							t.guild_quests[row.quest_id].attender_list[row.attender_pid] = {attender_pid = row.attender_pid, attender_reward_flag = row.attender_reward_flag, contribution = row.contribution}
						end
					elseif cfg.type == QUEST_TYPE_PLAYER then
						if t.player_quests[row.quest_id] and t.player_quests[row.quest_id][row.pid] then
							t.player_quests[row.quest_id][row.pid].attender_list[row.attender_pid] = {attender_pid = row.attender_pid, attender_reward_flag = row.attender_reward_flag, contribution = row.contribution}
						end
					end	
				end
			end
		end
	end
end

local function PlayerInGuild(pid, guild_id)
	local player = PlayerManager.Get(pid)
	
	if not player then
		log.debug("cant get player from PlayerManager")
		return false
	end

	if not player.guild or (player.guild.id ~= guild_id) then
		log.debug(string.format("player not in guild %d", guild_id))
		return false
	end

	return true
end

function GuildQuest.New(gid)
	local t = {
		gid = gid,
		player_quests = {},
		guild_quests = {},
	}
	local success, result = database.query("select gid, pid, quest_id, status, count, record1, record2, record3, consume_item_save1, consume_item_save2, unix_timestamp(accept_time) as accept_time, unix_timestamp(submit_time) as submit_time, unix_timestamp(next_time_to_accept) as next_time_to_accept, step_reward_flag from guild_quest where gid = %d", gid)	
	if success then
		if #result > 0 then
			for i = 1, #result, 1 do
				local row = result[i]
				local cfg = GuildQuestConfig.Get(row.quest_id)
				if cfg then
					if cfg.type == QUEST_TYPE_GUILD then
						t.guild_quests[row.quest_id] = t.guild_quests[row.quest_id] or {
							pid = 0,
							id = row.quest_id,
							status = row.status,
							count = row.count,
							record1 = row.record1,
							record2 = row.record2,
							record3 = row.record3,
							consume_item_save1 = row.consume_item_save1,
							consume_item_save2 = row.consume_item_save2,
							accept_time = row.accept_time,
							submit_time = row.submit_time,
							next_time_to_accept = row.next_time_to_accept,	
							step_reward_flag = row.step_reward_flag,
							attender_list = {},
						}
					elseif cfg.type == QUEST_TYPE_PLAYER then
						t.player_quests[row.quest_id] = t.player_quests[row.quest_id] or {}
						if PlayerInGuild(row.pid, gid) then
							t.player_quests[row.quest_id][row.pid] = {
								pid = row.pid,
								id = row.quest_id,
								status = row.status,
								count = row.count,
								record1 = row.record1,
								record2 = row.record2,
								record3 =  row.record3,
								consume_item_save1 = row.consume_item_save1,
								consume_item_save2 = row.consume_item_save2,
								accept_time = row.accept_time,
								submit_time = row.submit_time,
								next_time_to_accept = row.next_time_to_accept,
								step_reward_flag = row.step_reward_flag,
								attender_list = {}
							}
						end
					end
				end
			end
		end
	else
		return nil
	end

	LoadAttendList(gid, t)

	return setmetatable(t, {__index = GuildQuest})
end

function GuildQuest:GetQuestNum(pid, quest_id, cfg)
	if cfg.type == QUEST_TYPE_GUILD then
		local quest = self:GetQuest(pid, quest_id, cfg)
		if not quest then
			return 0
		end
	elseif cfg.type == QUEST_TYPE_PLAYER then
		local count = 0
		for id, v in pairs(self.player_quests[quest_id] or {}) do
			local quest = self:GetQuest(id, quest_id, cfg)
			if quest.status == QUEST_STATUS_INIT then
				count = count + 1
			end
		end	

		return count
	end	

	return 0
end

function GuildQuest:GetNextAcceptTime(pid, quest_id, cfg)
	if cfg.type == QUEST_TYPE_GUILD then
		local quest = self:GetQuest(pid, quest_id, cfg)
		if not quest then
			return 0
		end

		return quest.next_time_to_accept 
	elseif cfg.type == QUEST_TYPE_PLAYER then
		local next_time_to_accept = 0
		if cfg.share_refresh_time == 0 then
			if self.player_quests[quest_id] and self.player_quests[quest_id][pid] then
				next_time_to_accept = self.player_quests[quest_id][pid].next_time_to_accept	
			end
		else
			for id, v in pairs(self.player_quests[quest_id] or {}) do
				local quest = self:GetQuest(id, quest_id, cfg)
				if quest.next_time_to_accept > next_time_to_accept then
					next_time_to_accept = quest.next_time_to_accept
				end
			end
		end

		return next_time_to_accept
	end

	return 0
end

function GuildQuest:GetTotalFinishCount(pid, quest_id, cfg)
	if cfg.type == QUEST_TYPE_GUILD then
		local quest = self:GetQuest(pid, quest_id, cfg)
		if not quest then
			return 0
		end

		return quest.count 
	elseif cfg.type == QUEST_TYPE_PLAYER then
		local total_finish_count = 0
			for id, v in pairs(self.player_quests[quest_id] or {}) do
				local quest = self:GetQuest(id, quest_id, cfg)
				total_finish_count = total_finish_count + quest.count
			end

		return total_finish_count 
	end

	return 0
end

function GuildQuest:GetQuest(pid, quest_id, cfg)
	local quest = self.guild_quests[quest_id]

	cfg = cfg and cfg or GuildQuestConfig.Get(quest_id)
    if not cfg  then
        return nil
   	end 

	if cfg.type == QUEST_TYPE_PLAYER then
		if not self.player_quests[quest_id] or not self.player_quests[quest_id][pid] then
			quest = nil		
		else	
			quest = self.player_quests[quest_id][pid]
		end
	end

	if cfg.type == QUEST_TYPE_GUILD then
		pid = 0
	end

    if cfg.period == 0 then
        return quest 
   	end 

    local now = loop.now() 
    local period = cfg.period > 0 and cfg.period or 0xffffffff

    local total_pass = now - cfg.begin_time;
    local period_pass = total_pass % period;

    local period_begin = now - period_pass;
	local period_end = period_begin + cfg.duration

	
	--if bit32.band(cfg.auto_accept, 1) ~= 0 then
		--[[if (now >= period_begin and now <= period_end) then
			if not quest then
				quest = self:AddQuest(pid, quest_id, QUEST_STATUS_INIT)
			end	

			if quest.accept_time < period_begin then
				log.debug(string.format("  quest %d status reset to cancel by period", quest_id));
				self:UpdateQuestStatus(pid, quest_id, QUEST_STATUS_CANCEL, -1, -1, 0, -1, -1, -1, -1, -1);
			end 
		end00]]
	--else
		if not quest then
			return nil
		end

		if quest.status == QUEST_STATUS_CANCEL then
			return quest
		end

		if quest.accept_time < period_begin then
			log.debug(string.format("  quest %d status reset to cancel by period", quest_id));
			self:UpdateQuestStatus(pid, quest_id, QUEST_STATUS_CANCEL, -1, -1, -1, 0, -1, -1, -1, -1, 0, 0);
			self:ClearAttenders(quest)
		end 
	--end

	if quest.status == QUEST_STATUS_INIT and cfg.overtime > 0 and now > quest.accept_time + cfg.overtime then
		log.debug(string.format("  quest %d status reset to cancel because overtime", quest_id));
		self:UpdateQuestStatus(pid, quest_id, QUEST_STATUS_CANCEL, -1, -1, -1, 0, -1, -1, -1, -1, -1, 0);
	end

	print("quest relative_quest", quest_id, cfg.relative_quest)
	if cfg.relative_quest ~= 0 then
		local relative_quest = self.guild_quests[cfg.relative_quest]
		if relative_quest and quest.accept_time < relative_quest.accept_time then
			log.debug(string.format("  quest %d status reset to cancel because relative quest %d", quest_id, cfg.relative_quest));
			self:UpdateQuestStatus(pid, quest_id, QUEST_STATUS_CANCEL, -1, -1, -1, 0, -1, -1, -1, -1, -1, 0);
		end
	end 

    return quest;	
end

function GuildQuest:AddQuest(pid, quest_id, status)
	local cfg = GuildQuestConfig.Get(quest_id)
	if not cfg then
		return false	
	end

	local now = loop.now()
	local t = {
		pid = pid,
		id = quest_id,
		status = status,
		count = 0,
		record1 = 0,
		record2 = 0,
		record3 = 0,
		consume_item_save1 = 0,
		consume_item_save2 = 0,
		accept_time = now,
		submit_time = 0,
		next_time_to_accept = 0,
		step_reward_flag = 0,
		attender_list = {},
	}
	
	if cfg.type == QUEST_TYPE_GUILD then
		pid = 0
		t.pid = 0
		if self.guild_quests[quest_id] then
			log.debug("add quest fail, quest already exist")
			return false
		end	

		self.guild_quests[quest_id] = t	
	elseif cfg.type == QUEST_TYPE_PLAYER then
		if self.player_quests[quest_id] and self.player_quests[quest_id][pid] then
			log.debug("add quest fail, quest already exist")
			return false
		end

		self.player_quests[quest_id] = self.player_quests[quest_id] or {}
		self.player_quests[quest_id][pid] = t
	end
	
	database.update("replace into guild_quest (gid, pid, quest_id, status, count, record1, record2, record3, consume_item_save1, consume_item_save2, accept_time, submit_time, next_time_to_accept, step_reward_flag) values(%d, %d, %d, %d, %d, %d, %d, %d, %d, %d , from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), %d)", self.gid, pid, quest_id, status, 0, 0, 0, 0, 0, 0, now, 0, 0, 0)	

	self:Notify(pid, t)
	return t 
end

local function TRY_UPDATE(quest, key, v)
	assert(v ~= nil, debug.traceback())
	if v >= 0 and quest[key] ~= v then
		quest[key] = v
		return true 
	end

	return false
end

function GuildQuest:Notify(pid, quest)
	local guild = GuildManager.Get(self.gid)
	if guild then
		EventManager.DispatchEvent("GUILD_QUEST_CHANGE", {guild = guild, quest = quest, pid = pid});
	end
end

function GuildQuest:UpdateQuestStatus(pid, quest_id, status, record1, record2, record3, count, consume_item_save1, consume_item_save2, accept_time, submit_time, next_time_to_accept, step_reward_flag)
	local cfg = GuildQuestConfig.Get(quest_id)
	if not cfg then
		return false	
	end

	if cfg.type == QUEST_TYPE_GUILD then
		pid = 0
	end

	local quest
	if cfg.type == QUEST_TYPE_GUILD then
		quest = self.guild_quests[quest_id]	
	elseif cfg.type == QUEST_TYPE_PLAYER then
		quest = self.player_quests[quest_id][pid]
	end

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
	if TRY_UPDATE(quest, "record3", record3) then
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
	if TRY_UPDATE(quest, "next_time_to_accept", next_time_to_accept) then
		change = true
	end
	if TRY_UPDATE(quest, "step_reward_flag", step_reward_flag) then
		change = true
	end
	
	if change then
		database.update("update guild_quest set status = %d, count = %d, record1 = %d, record2 = %d, record3 = %d, consume_item_save1 = %d, consume_item_save2 = %d, accept_time = from_unixtime_s(%d), submit_time = from_unixtime_s(%d), next_time_to_accept = from_unixtime_s(%d), step_reward_flag = %d where gid = %d and pid = %d and quest_id = %d", quest.status, quest.count, quest.record1, quest.record2, quest.record3, quest.consume_item_save1, quest.consume_item_save2, quest.accept_time, quest.submit_time, quest.next_time_to_accept, quest.step_reward_flag, self.gid, pid, quest_id)

		self:Notify(pid, quest)
	end
end

function GuildQuest:QuestInTime(cfg, quest_id)
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

    if period_pass > duration then
        return false;
   	end 

    return true;
end

local function enoughPower(t1, t2)
	if t1 == t2 then
		return true
	end

    if t1 == 0 then
        return false;
    end

    if t2 == 0 then
        return true;
    end

    if t1 < t2 then
        return true;
    end
    return false;
end

function GuildQuest:QueryInfo(pid)
	log.debug(string.format("player %d query quest info", pid))

	local guild_quests = {}
	for quest_id, v in pairs(self.guild_quests) do
		local cfg = GuildQuestConfig.Get(quest_id)
		if cfg then
			local quest = self:GetQuest(pid, quest_id, cfg)
			local attenders = {}
			for id, v in pairs(quest.attender_list) do
				table.insert(attenders, {id, v.attender_reward_flag, v.contribution})
			end
			table.insert(guild_quests, {0, quest.id, quest.status, quest.count, quest.record1, quest.record2, quest.record3, quest.consume_item_save1, quest.consume_item_save2, quest.accept_time, quest.submit_time, quest.next_time_to_accept, attenders})
		end
	end

	local player_quests = {}
	for quest_id, v in pairs(self.player_quests) do
		for playerid, v2 in pairs(v) do
			--if playerid == pid then
				local cfg = GuildQuestConfig.Get(quest_id)
				if cfg then
					local quest = self:GetQuest(playerid, quest_id, cfg)
					local attenders = {}
					for id, v in pairs(quest.attender_list) do
						table.insert(attenders, {id, v.attender_reward_flag, v.contribution})
					end
					--print("^^^^^^^^^^^^^^^^", sprinttb(quest))
					table.insert(player_quests, {playerid, quest.id, quest.status, quest.count, quest.record1, quest.record2, quest.record3, quest.consume_item_save1, quest.consume_item_save2, quest.accept_time, quest.submit_time, quest.next_time_to_accept, attenders})
				end
			--end	
		end
	end 	

	return guild_quests, player_quests 
end

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


function GuildQuest:HasPermission(pid, cfg)
	if not cfg then
		return false
	end

	if cfg.team_fight_id == 0 then
		return true, {pid}
	end

	local team = getTeamByPlayer(pid) 
	if not team then
		if cfg.team_members_limit == 0 then
			return true, {pid}
		elseif cfg.team_members_limit == 1 then
			return true, {pid}
		else
			return false
		end	
	else
		if team.leader_pid ~= pid then
			return false
		end

		if cfg.team_members_limit == 0 then
			return false
		elseif cfg.team_members_limit == 1 then
			return true, team.members
		else
			if cfg.team_members_limit < cfg.team.members_limit then
				log.debug('team member count not enough')
				return false 
			else
				return true, team.members
			end
		end	
	end	
end


function GuildQuest:Accept(pid, quest_id, from_client)
	log.debug(string.format("Guild %d player %d accept quest %d, from %s", self.gid, pid, quest_id, from_client == 1 and "client" or "server"));
	local now = loop.now()

	local cfg = GuildQuestConfig.Get(quest_id)
	if not cfg then 
		log.debug("quest config not exists")
		return false
	end	

	local guild = GuildManager.Get(self.gid)
	local player = PlayerManager.Get(pid)
	
	if not guild then
		log.debug("guild not exist")
		return false
	end
	
	if not player then
		log.debug("player not exist")
		return false
	end

	if not player.guild or (player.guild.id ~= self.gid) then
		log.debug("player not in a guild or not in this guild")
		return false
	end

	if cfg.only_accept_by_other_activity == 1 and from_client == 1 then 
		log.debug("  quest can't change by client")
		return false
	end	

	if not self:QuestInTime(cfg, quest_id) then
		log.debug("quest not in time")
		return false
	end

	if not enoughPower(player.title, cfg.permission) then
		log.debug(string.format("player don't has permission to accept quest, need title %d player title %d", cfg.permission, player.title))
		return false
	end 

	local has_permission, pids = self:HasPermission(pid, cfg) 
	if not has_permission then
		log.debug("player don't has permission to accept quest")
		return false
	end

	if cfg.type == QUEST_TYPE_PLAYER then
		local player_info = GetPlayer(pid)
		if not player_info then
			log.debug("player not exist")
			return false
		end

		if player_info.level < cfg.depend_level then
			log.debug(" level %d/%d is not enough", level, cfg.depend_level)
			return false
		end
	elseif cfg.type == QUEST_TYPE_GUILD then
		if guild.level < cfg.depend_level then
			log.debug(" level %d/%d is not enough", level, cfg.depend_level)
			return false
		end
	end

	if cfg.type == QUEST_TYPE_PLAYER and cfg.accept_limit ~= 0 then
		local quest_num = self:GetQuestNum(pid, quest_id, cfg)
		if not quest_num then
			return false
		end

		if quest_num >= cfg.accept_limit then
			log.debug(string.format(" quest already reach max %d/%d", quest_num, cfg.accept_limit))
			return false
		end
	end

	local next_accept_time = self:GetNextAcceptTime(pid, quest_id, cfg)
	if next_accpet_time ~= 0 and next_accept_time > loop.now() then
		log.debug(" not time to accept this quest")
		return false
	end

	local total_finish_count = self:GetTotalFinishCount(pid, quest_id, cfg)
	if cfg.finish_count > 0 and total_finish_count >= cfg.finish_count then
		log.debug("already reach finish count ")
		return false
	end

	if cfg.depend_quest_id ~= 0 then
		local dcfg = GuildQuestConfig.Get(cfg.depend_quest_id)
		if not dcfg then
			log.debug(" cannt get depend quest config")
			return false
		end

		local dquest = self:GetQuest(pid, cfg.depend_quest_id, dcfg)
		if dquest.status ~= QUEST_STATUS_FINISH then
			log.debug(" depend quest not finish")
			return false
		end
	end

	if cfg.depend_item ~= 0 then
		--check item
		if not DOReward(pid, nil, {{type = 41, id = cfg.depend_item, value = 0}}, Command.REASON_GUILD_QUEST, false, 0, nil) then
			log.debug("item %d not exists", cfg.depend_item)
			return false
		end
	end

	local quest = self:GetQuest(pid, quest_id, cfg)
	if quest then
		if quest.status == QUEST_STATUS_INIT then
			log.debug("quest already exists")
			return false 
		elseif cfg.count_limit > 0 and quest.count >= cfg.count_limit then
			log.debug("quest reach period count limit %d/%d", quest.count, cfg.count_limit)
			return false
		end				

		self:UpdateQuestStatus(pid, quest_id, QUEST_STATUS_INIT, 0, 0, 0, -1, 0, 0, now, -1, -1, -1)
	else 
		quest = self:AddQuest(pid, quest_id, QUEST_STATUS_INIT)
	end	

	--do consume 
	if bit32.band(cfg.need_reset, 2^2) ~= 0 then
		if not DOReward(pid, nil, cfg.consume, Command.REASON_GUILD_QUEST, false, 0, nil) then
			log.debug("donnt has consume item, cannt accept quest")
			return false
		end
	end

	if bit32.band(cfg.need_reset, 2^3) ~= 0 then
		local consume = {}
		for k, v in ipairs(cfg.consume) do
			table.insert(consume, {type = v.type, id = v.id, value = v.value, empty = 1})	
		end
		DOReward(pid, nil, consume, Command.REASON_GUILD_QUEST, false, 0, nil)	
	end

	return true, cfg, pids, quest
end

function GuildQuest:Cancel(pid, quest_id, from_client)
	log.debug("Guild %d player %d cancel quest %d, from %s", self.gid, pid, self.id, quest_id, from_client == 1 and "client" or "server");

	local cfg = GuildQuestConfig.Get(quest_id)
	if not cfg then
		log.debug("quest config not exists")
		return false
	end

	local guild = GuildManager.Get(self.gid)
	local player = PlayerManager.Get(pid)
	
	if not guild then
		log.debug("guild not exist")
		return false
	end
	
	if not player then
		log.debug("player not exist")
		return false
	end

	if not player.guild or (player.guild.id ~= self.gid) then
		log.debug("player not in a guild or not in this guild")
		return false
	end

	if not enoughPower(player.title, cfg.permission) then
		log.debug("player don't has permission to accept quest, need title")
		return false
	end 

	if cfg.only_accept_by_other_activity == 1 and from_client == 1 then
		log.debug("quest can't change by client")
		return false
	end

	if not self:QuestInTime(cfg, quest_id) then
		log.debug("quest not in time")
		return false
	end

	local quest = self:GetQuest(pid, quest_id)
	if not quest then
		log.debug(" quest not exist")
		return false
	end

	if quest.status ~= QUEST_STATUS_INIT then
		log.debug("quest status can't cancel", quest.status)
		return false
	end

	if cfg.type == QUEST_TYPE_GUILD then
		pid = 0	
	end

	self:UpdateQuestStatus(pid, quest_id, QUEST_STATUS_CANCEL, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0)

	self:ClearAttenders(quest)
	return true
end

function GuildQuest:CheckQuestEvent(record, type, id, count) 
	--特殊type 忽略record的大小
    --[[if type == QuestEventType_PLAYER then
   	end --]]
	if record < count then
        log.debug("  event %d, %d not enough %d/%d", type, id, record, count);
        return false 
   	end 

    return true 
end

function GuildQuest:SendRewardToTeammate(teammates, cfg)
	if teammates and #teammates > 0 then
		for _, pid in ipairs(teammates) do
			if not DOReward(pid, cfg.reward, nil, Command.REASON_GUILD_QUEST, false, 0, nil) then
				log.debug("send reward fail")
				return false
			end

			if bit32.band(cfg.need_reset1, 2^1) ~= 0 then
				local consume = {}
				for k, v in ipairs(cfg.consume) do
					table.insert(consume, {type = v.type, id = v.id, value = v.value, empty = 1})	
				end
				DOReward(pid, nil, consume, Command.REASON_GUILD_QUEST, false, 0, nil)
			end

			-- send drop
			if cfg.drop_id ~= 0 then
				cell.sendDropReward(pid, {cfg.drop_id}, Command.REASON_GUILD_QUEST)	
			end
		end
	end
end

function GuildQuest:Submit(pid, quest_id, from_client, rich_reward, teammates)
	log.debug(string.format("Guild %d player %d submit quest %d, from %s, %s reward", self.gid, pid, quest_id, from_client == 1 and "client" or "server", rich_reward == 1 and "rich" or "normal"));
	local opt_id = pid
	local now = loop.now()

	local cfg = GuildQuestConfig.Get(quest_id)
    if not cfg then 
        log.debug("  quest config not exists");
		return false
	end

	local guild = GuildManager.Get(self.gid)
	local player = PlayerManager.Get(pid)
	
	if not guild then
		log.debug("guild not exist")
		return false
	end
	
	if not player then
		log.debug("player not exist")
		return false
	end

	if not player.guild or (player.guild.id ~= self.gid) then
		log.debug("player not in a guild or not in this guild")
		return false
	end

	if not enoughPower(player.title, cfg.permission) then
		log.debug("player don't has permission to accept quest, need title")
		return false
	end 

	if cfg.only_accept_by_other_activity == 1 and from_client == 1 then
        log.debug("  quest can't change by client")
		return false
	end

	if cfg.team_fight_id > 0 and from_client == 1 then
        log.debug("  quest can't submit by client, because team_fight_id > 0")
		return false
	end

	if not self:QuestInTime(cfg, quest_id) then
		log.debug(" quest not in time")
		return false
	end

	local quest = self:GetQuest(pid, quest_id)
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

	if not self:CheckQuestEvent(quest.record3, cfg.event_type3, cfg.event_id3, cfg.event_count3) then
		return false
	end

	if cfg.type == QUEST_TYPE_GUILD then
		pid = 0
	end

	-- check consume and send reward
	local final_consume
	if bit32.band(cfg.need_reset, 2^0) ~= 0 then
		final_consume = cfg.consume
	end

	if cfg.type == QUEST_TYPE_PLAYER then
		if not DOReward(pid, cfg.reward, final_consume, Command.REASON_GUILD_QUEST, false, 0, nil) then
			log.debug("consume fail")
			return false
		end
	elseif cfg.type == QUEST_TYPE_GUILD then
		if not DORewardForGuild(guild, cfg.reward, final_consume, Command.REASON_GUILD_QUEST, false, 0, nil) then
			log.debug("consume fail2")
			return false
		end
	end


	if bit32.band(cfg.need_reset, 2^1) ~= 0 then
		local consume = {}
		for k, v in ipairs(cfg.consume) do
			table.insert(consume, {type = v.type, id = v.id, value = v.value, empty = 1})	
		end
		
		if cfg.type == QUEST_TYPE_PLAYER then
			DOReward(pid, nil, consume, Command.REASON_GUILD_QUEST, false, 0, nil)
		elseif cfg.type == QUEST_TYPE_GUILD then
			DORewardForGuild(guild, nil, consume, Command.REASON_GUILD_QUEST, false, 0, nil)
		end
	end

	if cfg.cost_wealth ~= 0 then
		if not guild:CostWealth(player,cfg.cost_wealth) then
			log.debug("consume wealth fail")
			return false
		end
	end

	
	-- send drop
	if cfg.drop_id ~= 0 then
		if cfg.type == QUEST_TYPE_PLAYER then
			cell.sendDropReward(pid, {cfg.drop_id}, Command.REASON_GUILD_QUEST)	
		elseif cfg.type == QUEST_TYPE_GUILD then
			for _, m in ipairs(guild.members) do
				cell.sendDropReward(m.id, {cfg.drop_id}, Command.REASON_GUILD_QUEST)	
			end
		end
	end

	local next_time_to_accept = -1
	if cfg.refresh_time_min ~= 0 and cfg.refresh_time_max ~= 0 then
		next_time_to_accept = now + math.random(cfg.refresh_time_min, cfg.refresh_time_max)	
	end
	self:UpdateQuestStatus(pid, quest.id, QUEST_STATUS_FINISH, -1, -1, -1, quest.count + 1, -1, -1, -1, now, next_time_to_accept, -1);

	self:SendRewardToTeammate(teammates, cfg)

	
	-- notify quest reward

    --[[if (rewards[0].type != 0) {
        struct amf_value * msg = amf_new_array(0);
        amf_push(msg, amf_new_integer(quest->id));

        for (i = 0; i < nitem; i++) {
            if (rewards[i].type == 0) {
                break;
            }

            struct amf_value * r = amf_new_array(3);
            amf_set(r, 0, amf_new_integer(rewards[i].type));
            amf_set(r, 1, amf_new_integer(rewards[i].id));
            amf_set(r, 2, amf_new_integer(rewards[i].value));

            amf_push(msg, r);
        }
        notification_add(quest->pid, NOTIFY_QUEST_REWARD, msg);
    }--]]
	self:ClearAttenders(quest)

	-- add score to rank
	-- TODO
	SocialManager.SetRankDatum(opt_id, cfg.rank_type, cfg.rank_score, self.gid)		

    log.debug("  next quest id ", cfg.next_quest);

	if cfg.next_quest ~= 0 then
		local next_cfg = GuildQuestConfig.Get(cfg.next_quest)
        if next_cfg and bit32.band(next_cfg.auto_accept, 1) ~= 0 then
            log.debug("  accept next quest ", cfg.next_quest)
			self:Accept(opt_id, cfg.next_quest, 0)
       	end 
   	end 

    return true
end

local function insertItem(t, type, id, value)
	if type and type ~= 0 and id and id ~= 0 and value and value ~= 0 then
		table.insert(t, {type = type, id = id, value = value})
	end
end

local guild_quest_step_reward = nil
local function LoadGuildQuestStepRewardConfig()
	local rows = BinaryConfig.Load("config_guild_quest_stepreward", "guild")
	guild_quest_step_reward = {}

	for _, row in ipairs(rows) do
		guild_quest_step_reward[row.quest_id] = guild_quest_step_reward[row.quest_id] or {}
		guild_quest_step_reward[row.quest_id][row.index] = {
			condition1 = row.condition1,
			condition2 = row.condition2,
			condition3 = row.condition3,
			reward = {}
		}
		insertItem(guild_quest_step_reward[row.quest_id][row.index].reward, row.reward_type1, row.reward_id1, row.reward_value1)
		insertItem(guild_quest_step_reward[row.quest_id][row.index].reward, row.reward_type2, row.reward_id2, row.reward_value2)
		insertItem(guild_quest_step_reward[row.quest_id][row.index].reward, row.reward_type3, row.reward_id3, row.reward_value3)
    end
end
LoadGuildQuestStepRewardConfig()

local function GetStepRewardCfg(quest_id, idx)
	if not guild_quest_step_reward[quest_id] then
		return nil
	end

	return guild_quest_step_reward[quest_id][idx]
end

local MAX_STEP_REWARD_COUNT = 10
function GuildQuest:CheckAndSendStepReward(pid, quest, cfg)
	if cfg.auto_send_step_reward ~= 1 then
		return
	end

	log.debug(string.format("CheckAndSendStepReward for quest %d, only_attender_receive_reward %d", quest.id, cfg.only_attender_receive_reward))
	local step_reward
	if cfg.only_attender_receive_reward == 1 then
		for i = 1, MAX_STEP_REWARD_COUNT,  1 do
			if self:CheckRewardCondition(quest, i) then
				step_reward = GetStepRewardCfg(quest.id, i)	
				if step_reward and bit32.band(quest.step_reward_flag, 2^(i - 1)) == 0 then
					for pid, v in pairs(quest.attender_list) do
						--print("pid attender_reward_flag   >>>>>", pid, v.attender_reward_flag, sprinttb(step_reward.reward))
						if bit32.band(v.attender_reward_flag, 2^(i-1))  == 0 then
							DOReward(pid, step_reward.reward, nil, Command.REASON_GUILD_QUEST_STEP_REWARD, false, 0, nil) 
							self:UpdateAttenderRewardFlag(quest, pid, bit32.bor(v.attender_reward_flag, 2^(i - 1)))
						end
					end 
					self:UpdateQuestRewardFlag(quest, bit32.bor(quest.step_reward_flag, 2^(i - 1)))
				end
			end
		end
	else
		local guild = GuildManager.Get(self.gid)
		if cfg.type == QUEST_TYPE_GUILD then
			for i = 1, MAX_STEP_REWARD_COUNT,  1 do
				if self:CheckRewardCondition(quest, i) then
					step_reward = GetStepRewardCfg(quest.id, i)	
					if guild and step_reward then
						for _, m in pairs(guild.members) do
							local attender_reward_flag = self:GetAttenderRewardFlag(quest, m.id) or 0
							print("pid attender_reward_flag   >>>>>", m.id, attender_reward_flag, sprinttb(step_reward.reward))
							if bit32.band(attender_reward_flag, 2^(i-1))  == 0 then
								DOReward(m.id, step_reward.reward, nil, Command.REASON_GUILD_QUEST_STEP_REWARD, false, 0, nil) 
								self:UpdateAttender(quest, m.id, bit32.bor(attender_reward_flag, 2^(i - 1)), 0)
							end
						end
					end
					self:UpdateQuestRewardFlag(quest, bit32.bor(quest.step_reward_flag, 2^(i - 1)))
				end
			end
		elseif cfg.type == QUEST_TYPE_PLAYER then
			for i = 1, MAX_STEP_REWARD_COUNT,  1 do
				if self:CheckRewardCondition(quest, i) then
					step_reward = GetStepRewardCfg(quest.id, i)	
					local attender_reward_flag = self:GetAttenderRewardFlag(quest, pid) or 0
					--print("pid attender_reward_flag   >>>>>", pid, attender_reward_flag, sprinttb(step_reward.reward))
					if bit32.band(attender_reward_flag, 2^(i-1))  == 0 then
						DOReward(pid, step_reward.reward, nil, Command.REASON_GUILD_QUEST_STEP_REWARD, false, 0, nil) 
						self:UpdateAttender(quest, pid, bit32.bor(attender_reward_flag, 2^(i - 1)), 0)
						self:UpdateQuestRewardFlag(quest, bit32.bor(quest.step_reward_flag, 2^(i - 1)))
					end
				end
			end
		end
	end	
end

function GuildQuest:AchieveStepReward(pid, quest_id, idx)
	local cfg = GuildQuestConfig.Get(quest_id)
	if cfg.auto_send_step_reward == 1 then
		log.debug("reward cant achieve manual")
		return false
	end

	if not self:QuestInTime(cfg, quest_id) then
		log.debug(string.format("AchieveStepReward fail, quest not on time"))
		return false
	end

	local quest = self:GetQuest(pid, quest_id, cfg)
	if not quest then
		log.debug("not has quest")
		return false	
	end

	
	local step_reward = GetStepRewardCfg(quest.id, idx)	
	if not step_reward then
		log.debug(string.format("not has step reward for idx %d", idx))
		return false
	end

	if cfg.only_attender_receive_reward == 1 then
		if not quest.attender_list[pid] then
			log.debug(string.format("not attender of quest %d", quest.id))
			return false
		end

		if not self:CheckRewardCondition(quest, idx) then
			log.debug(string.format("quest %d check condition fail", quest.id))
			return false
		end

		if bit32.band(quest.attender_list[pid].reward_flag, 2^(i-1))  ~= 0 then
			log.debug(string.format("Player %d already achieve reward", pid))
			return false
		end
	
		DOReward(pid, step_reward.reward, nil, Command.REASON_GUILD_QUEST_STEP_REWARD, false, 0, nil) 
		self:UpdateAttenderRewardFlag(quest, pid, bit32.bor(quest.attender_list[pid].reward_flag, 2^(i - 1)))
		return true
	else
		local attender_reward_flag = self:GetAttenderRewardFlag(quest, pid) or 0
		if bit32.band(attender_reward_flag, 2^(idx-1))  ~= 0 then
			log.debug(string.format("Player %d already achieve reward", pid))
			return false
		end

		DOReward(pid, step_reward.reward, nil, Command.REASON_GUILD_QUEST_STEP_REWARD, false, 0, nil) 
		self:UpdateAttender(quest, pid, bit32.bor(attender_reward_flag, 2^(idx - 1)), 0)
		return true
	end
end

function GuildQuest:CheckRewardCondition(quest, idx)
	local cfg = GetStepRewardCfg(quest.id, idx)	
	if not cfg then
		return false
	end

	if quest.record1 >= cfg.condition1 and quest.record2 >= cfg.condition2 and quest.record3 >= cfg.condition3 then
		return true
	end

	return false 
end

function GuildQuest:UpdateAttenderRewardFlag(quest, pid, flag)
	assert(quest)
	if not quest.attender_list[pid] then
		log.debug("player %d not attend this quest %d", pid, quest.id)	
		return false
	end

	quest.attender_list[pid].attender_reward_flag = flag
	database.update("update guild_quest_attenders set attender_reward_flag = %d where gid = %d and pid = %d and quest_id = %d and attender_pid = %d", flag, self.gid, quest.pid, quest.id, pid)
	self:Notify(quest.pid, quest)
end

function GuildQuest:UpdateQuestRewardFlag(quest, flag)
	assert(quest)
	quest.step_reward_flag = flag	
	database.update("update guild_quest set step_reward_flag = %d where gid = %d and pid = %d and quest_id = %d", flag, self.gid, quest.pid, quest.id)
	self:Notify(quest.pid, quest)
end

function GuildQuest:GetAttenderRewardFlag(quest, pid)
	assert(quest)	
	if not quest.attender_list[pid] then
		return nil
	end

	return quest.attender_list[pid].attender_reward_flag
end

function GuildQuest:ClearAttenders(quest)
	assert(quest)

	if next(quest.attender_list) then
		database.update("delete from guild_quest_attenders where gid = %d and pid = %d and quest_id = %d", self.gid, quest.pid, quest.id)	
		quest.attender_list = {}
		self:Notify(quest.pid, quest)
	end
end

function GuildQuest:UpdateAttender(quest, pid, flag, contribution_add_value)
	assert(quest)
		
	if not quest.attender_list[pid] then
		quest.attender_list[pid] = {attender_pid = pid, attender_reward_flag = flag > 0 and flag or 0, contribution = contribution_add_value}
		database.update("insert into guild_quest_attenders(gid, pid, quest_id, attender_pid, attender_reward_flag, contribution) values(%d, %d, %d, %d, %d, %d)", self.gid, quest.pid, quest.id, pid, flag > 0 and flag or 0, contribution_add_value)
		return 
	end

	if flag > 0 then
		quest.attender_list[pid].attender_reward_flag = flag 
	end

	quest.attender_list[pid].contribution = quest.attender_list[pid].contribution + contribution_add_value 
	database.update("update guild_quest_attenders set attender_reward_flag = %d ,contribution = %d where gid = %d and pid = %d and quest_id = %d and attender_pid = %d", quest.attender_list[pid].attender_reward_flag, quest.attender_list[pid].contribution, self.gid, quest.pid, quest.id, pid)
	self:Notify(quest.pid, quest)
end

function GuildQuest:OnEvent(pid, event_type, event_id, count)
	log.debug(string.format("player %d on quest event %d, id %d, count %d", pid, event_type, event_id, count));

	--print("guild quests >>>>>>", sprinttb(self.guild_quests))
	for quest_id, v in pairs(self.guild_quests) do
		local cfg = GuildQuestConfig.Get(quest_id)
		if cfg then
			local quest = self:GetQuest(pid, quest_id, cfg)
		
			if self:QuestInTime(cfg, quest_id) then
				if quest.status == QUEST_STATUS_INIT then

					local r1 = quest.record1
					local r2 = quest.record2
					local r3 = quest.record3
					if cfg.event_type1 == event_type and cfg.event_id1 == event_id then
						r1 = r1 + count
						if r1 > cfg.event_count1 then
							r1 = cfg.event_count1
						end
					end

					if cfg.event_type2 == event_type and cfg.event_id2 == event_id then
						r2 = r2 + count
						if r2 > cfg.event_count2 then
							r2 = cfg.event_count2
						end
					end

					if cfg.event_type3 == event_type and cfg.event_id3 == event_id then
						r3 = r3 + count
						if r3 > cfg.event_count3 then
							r3 = cfg.event_count3
						end
					end

					self:UpdateQuestStatus(pid, quest.id, quest.status, r1, r2, r3, -1, -1, -1, -1, -1, -1, -1);
					self:UpdateAttender(quest, pid, -1, count)
					self:CheckAndSendStepReward(pid, quest, cfg)
		
					if bit32.band(cfg.auto_accept, 2) ~= 0 and r1 >= cfg.event_count1 and r2 >= cfg.event_count2 and r3 >= cfg.event_count3 then
						self:Submit(pid, quest_id, 0)
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
							local r3 = quest.record3
							if cfg.event_type1 == event_type and cfg.event_id1 == event_id then
								r1 = r1 + count
								if r1 > cfg.event_count1 then
									r1 = cfg.event_count1
								end
							end

							if cfg.event_type2 == event_type and cfg.event_id2 == event_id then
								r2 = r2 + count
								if r2 > cfg.event_count2 then
									r2 = cfg.event_count2
								end
							end

							if cfg.event_type3 == event_type and cfg.event_id3 == event_id then
								r3 = r3 + count
								if r3 > cfg.event_count3 then
									r3 = cfg.event_count3
								end
							end

							self:UpdateQuestStatus(pid, quest.id, quest.status, r1, r2, r3, -1, -1, -1, -1, -1, -1, -1);
							self:UpdateAttender(quest, pid, -1, count)
							self:CheckAndSendStepReward(pid, quest, cfg)

							if bit32.band(cfg.auto_accept, 2) ~= 0 and r1 >= cfg.event_count1 and r2 >= cfg.event_count2 and r3 >= cfg.event_count3 then
								self:Submit(pid, quest_id, 0)
							end
						end
					end
				end
			end	
		end
	end 
end

function GuildQuest:CostItemToUpdateRecord(pid, quest_id, item_id, cost_value)
	local cfg = GuildQuestConfig.Get(quest_id)
	if not cfg then
		log.debug(string.format("CostItemToUpdateRecord fail, not has quest config for quest_id %d", quest_id))
		return false
	end

	--print(">>>>>>>>>", cfg.event_type1, cfg.event_type2, cfg.event_type3, cfg.event_id1, cfg.event_id2, cfg.event_id3, item_id)
	if cfg.event_type1 ~= EVENT_TYPE_CONSUME_ITEM and cfg.event_type2 ~= EVENT_TYPE_CONSUME_ITEM and cfg.event_type3 ~= EVENT_TYPE_CONSUME_ITEM then
		log.debug(string.format("CostItemToUpdateRecord fail, quest_id %d not support cost item to update record", quest_id))
		return false
	end

	if cfg.event_id1 ~= item_id and cfg.event_id2 ~= item_id and cfg.event_id3 ~= item_id then
		log.debug(string.format("CostItemToUpdateRecord fail, item_id send by client not fit with server cfg"))
		return false
	end

	if not self:QuestInTime(cfg, quest_id) then
		log.debug(string.format("CostItemToUpdateRecord fail, quest not on time"))
		return false
	end

	local quest = self:GetQuest(pid, quest_id, cfg)	
	if not quest then
		quest = self:AddQuest(pid, quest_id, QUEST_STATUS_INIT)
	elseif quest.status ~= QUEST_STATUS_INIT then
		if not self:Accept(pid, quest_id, 0) then
			return false
		end
		--self:UpdateQuestStatus(pid, quest_id, QUEST_STATUS_INIT, 0, 0, 0, -1, 0, 0, loop.now(), -1, -1)
	end	

	local update_idx = 0
	if cfg.event_id1 == item_id then
		update_idx = 1
	end

	if cfg.event_id2 == item_id then
		update_idx = 2
	end

	if cfg.event_id3 == item_id then
		update_idx = 3 
	end

	assert(update_idx > 0)

	if quest["record"..tostring(update_idx)] >= cfg["event_count"..tostring(update_idx)] then
		log.debug(string.format("CostItemToUpdateRecord fail, record already max"))
		return false
	end

	local real_cost_value = math.min(cfg["event_count"..tostring(update_idx)] - quest["record"..tostring(update_idx)], cost_value)
	print(">>>>>> consume", cfg["event_id"..tostring(update_idx)], real_cost_value)
	if not DOReward(pid, nil, {{type = 41, id = cfg["event_id"..tostring(update_idx)], value = real_cost_value}}, Command.REASON_GUILD_QUEST_COST_ITEM, false, 0, nil) then
		log.debug("consume fail")
		return false
	end

	self:OnEvent(pid, EVENT_TYPE_CONSUME_ITEM, cfg["event_id"..tostring(update_idx)], real_cost_value)	
	return true
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

local MAX_PROPERTY_COUNT = 6
local function SamePropertyCount(hero_id, condition_property)
	local hero_property = GetHeroProperty(hero_id)
    if not hero_property or not map_property then
        return 0
    end
    local count = 0
    for i = 1, MAX_PROPERTY_COUNT, 1 do
        local mask = 2 ^ (i - 1)
        if (bit32.band(hero_property, mask) ~= 0) and (bit32.band(condition_property, mask) ~= 0) then
            count = count + 1
        end
    end

    return count
end

local function fast_pass(pid, cfg)
	if cfg.fast_pass_condition1 == 0 and cfg.fast_pass_condition2 == 0 then
		return false
	end

	local fight_data, err = cell.QueryPlayerFightInfo(pid, false, 0)
	if not fight_data then
		return false
	end

	local success_rate = 0
	for k, role in ipairs(fight_data.roles) do
		if cfg.fast_pass_condition1 ~= 0 and role.id == cfg.fast_pass_condition1 then
			success_rate = success_rate + cfg.fast_pass_value1
		end

		local count = SamePropertyCount(role.id, cfg.fast_pass_condition2)
		if cfg.fast_pass_condition2 ~= 0 and count > 0 then
			success_rate = success_rate + cfg.fast_pass_value2 * count
		end
	end

	return math.random(1, 100) <= success_rate
end

function GuildQuest.RegisterCommand(service)
	service:on(Command.C_GUILD_QUEST_QUERY_INFO_REQUEST, function(conn, pid, request)
		local cmd = Command.C_GUILD_QUEST_QUERY_INFO_RESPOND
		local sn = request[1]

		local manager = CheckAndGetQuestManager(pid)
		if not manager then
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

		local info1, info2 = manager:QueryInfo(pid)
		return conn:sendClientRespond(cmd, pid, {sn, info1 and Command.RET_SUCCESS or Command.RET_ERROR, info1, info2})
	end)			

	service:on(Command.C_GUILD_QUEST_ACCEPT_REQUEST, function(conn, pid, request)
		local pids = {1}
		local cmd = Command.C_GUILD_QUEST_ACCEPT_RESPOND
		local sn = request[1]
		local quest_id = request[2]
		
		if not quest_id then
			log.debug("param 2nd quest_id is nil")
			return conn:sendClientRespond(cmd, pid, {sn, Command.PARAM_ERROR})
		end

		local manager = CheckAndGetQuestManager(pid)
		if not manager then
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

		local ret, cfg, pids, quest = manager:Accept(pid, quest_id, 1)
		conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR})

		
		if ret and cfg and bit32.band(cfg.auto_accept, 2) ~= 0 and quest.record1 >= cfg.event_count1 and quest.record2 >= cfg.event_count2 and quest.record3 >= cfg.event_count3 then
			manager:Submit(pid, quest_id, 0)
		end

		if not ret then
			return 
		end

		print("team fight id >>>>>>>>>>>>>>>>>>>>>>", cfg.team_fight_id)
		if cfg and cfg.team_fight_id > 0 and pids and #pids > 0 and AllMemberNotInFight(pids) then
			if not AllMemberNotInFight(pids) then	
				log.warning("start guild quest team fight fail, some one in fight")
				return 
			end

			print("fast_pass >>>>>>>>>>>", tostring(fast_pass(pid, cfg)))
			if fast_pass(pid, cfg) then
				return manager:Submit(pid, quest_id, 0, nil, teammates)
			end

			RunThread(function()
				local level = MemberStartFight(pids)
				print("begin fight >>>>>>>>>")
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
					manager:Submit(pid, quest_id, 0, nil, teammates)
				else
					manager:Cancel(pid, quest_id, 0)
				end	
			end)
		end
		
	end)

	service:on(Command.C_GUILD_QUEST_CANCEL_REQUEST, function(conn, pid, request)
		local cmd = Command.C_GUILD_QUEST_CANCEL_RESPOND
		local sn = request[1]
		local quest_id = request[2]
		
		if not quest_id then
			log.debug("param 2nd quest_id is nil")
			return conn:sendClientRespond(cmd, pid, {sn, Command.PARAM_ERROR})
		end

		local manager = CheckAndGetQuestManager(pid)
		if not manager then
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

		local ret = manager:Cancel(pid, quest_id, 1)
		return conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR})
	end)

	service:on(Command.C_GUILD_QUEST_SUBMIT_REQUEST, function(conn, pid, request)
		local cmd = Command.C_GUILD_QUEST_SUBMIT_RESPOND
		local sn = request[1]
		local quest_id = request[2]
		
		if not quest_id then
			log.debug("param 2nd quest_id is nil")
			return conn:sendClientRespond(cmd, pid, {sn, Command.PARAM_ERROR})
		end

		local manager = CheckAndGetQuestManager(pid)
		if not manager then
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

		local ret = manager:Submit(pid, quest_id, 1)
		return conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR})
	end)

	service:on(Command.C_GUILD_QUEST_COST_ITEM_TO_UPDATE_RECORD_REQUEST, function(conn, pid, request)
		local cmd = Command.C_GUILD_QUEST_COST_ITEM_TO_UPDATE_RECORD_RESPOND
		local sn = request[1]
		local quest_id = request[2]
		local item_id = request[3]
		local cost_value = request[4]

		if not quest_id or not item_id or not cost_value then
			log.debug("param error")	
			return conn:sendClientRespond(cmd, pid, {sn, Command.PARAM_ERROR})
		end

		local manager = CheckAndGetQuestManager(pid)
		if not manager then
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

		log.debug(string.format("Player %d begin to cost item %d value %d to update quest %d record", pid, item_id, cost_value, quest_id))
		local ret = manager:CostItemToUpdateRecord(pid, quest_id, item_id, cost_value)

		return conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR, ret and 0 or item_id})
	end)

	service:on(Command.C_GUILD_QUEST_ACHIEVE_STEP_REWARD_REQUEST, function(conn, pid, request)
		local cmd = Command.C_GUILD_QUEST_ACHIEVE_STEP_REWARD_RESPOND
		local sn = request[1]
		local quest_id = request[2]
		local idx = request[3]

		if not quest_id or not idx then
			log.debug("param error")	
			return conn:sendClientRespond(cmd, pid, {sn, Command.PARAM_ERROR})
		end

		local manager = CheckAndGetQuestManager(pid)
		if not manager then
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end

		log.debug(string.format("Player %d to achieve step reward for idx %d", pid, idx))
		local ret = manager:AchieveStepReward(pid, quest_id, idx)

		return conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR})
	end)
end

return GuildQuest
