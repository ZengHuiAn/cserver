local database = require "database"

require "printtb"
--local GuildManager = require "GuildManager"
local GuildEventLog = require "GuildEventLog"
require "GuildSummaryConfig"

local all = {}
local TAG = "GuildExploreEvent"
local function DEBUG_LOG(str)
	log.debug("["..TAG.."]"..str)
end

local function WARNING_LOG(str)
	log.warning("["..TAG.."]"..str)
end

local function ERROR_LOG(str)
	log.error("["..TAG.."]"..str)
end

local FLAG_INIT = 0
local FLAG_ACITVE = 1
local FLAG_DONE = 2

local MAX_EVENT_COUNT = 3

local EVENT_TYPE_REWARD = 1
local EVENT_TYPE_FIGHT = 2 
local EVENT_TYPE_BOSS = 3 
local EVENT_TYPE_MAP = 4 

local function InsertItem(rewards, type, id, value)
	if not rewards or type == 0 or id == 0 or value == 0 then
		return
	end

	table.insert(rewards, {type = type, id = id, value = value})
end

local function Notify(cmd, pid, msg)
	local agent = Agent.Get(pid);
	if agent then
		agent:Notify({cmd, msg});
	end
end

local BinaryConfig = require "BinaryConfig"
local guild_explore_event_config = {}
local function load_guild_explore_event_config()
    local rows = BinaryConfig.Load("config_team_accident", "guild")

	guild_explore_event_config.list = {}
	guild_explore_event_config.map = {}
    if rows then
        for _, row in ipairs(rows) do
			guild_explore_event_config.list[row.explore_mapid] = guild_explore_event_config.list[row.explore_mapid] or {}	
			local t = {
				map_id = row.explore_mapid,
				event_id = row.id,
				event_type = row.accident_type,
				trigger_time_min = row.trigger_time_min,
				trigger_time_max = row.trigger_time_max,
				event_duration = row.accident_duration,
				event_result = row.accident_resultid,
				guild_min_lv = row.team_lv_min,
				next_id = row.next_id,
				weight = row.weight,
				condition_type = row.condition_type,
				condition_para1 = row.condition_para1,
				condition_para2 = row.condition_para2,
				rewards = {}
			}
			InsertItem(t.rewards, row.reward1_type, row.reward1_id, row.reward1_count)
			InsertItem(t.rewards, row.reward2_type, row.reward2_id, row.reward2_count)
			InsertItem(t.rewards, row.reward3_type, row.reward3_id, row.reward3_count)
			table.insert(guild_explore_event_config.list[row.explore_mapid], t)	

			guild_explore_event_config.map[row.id] = t
        end
    end
end

load_guild_explore_event_config()

local function GetGuildExploreEventList(map_id, guild_lv)
	local t = {total_weight = 0, list = {}}
	for k, v in ipairs(guild_explore_event_config.list[map_id] or {}) do
		if guild_lv >= v.guild_min_lv then
			t.total_weight = t.total_weight + v.weight
			table.insert(t.list, v)
		end	
	end

	return t
end

function GetGuildExploreEventMap(event_id)
	return guild_explore_event_config.map[event_id] or nil
end

local GuildExploreEvent = {}

function GuildExploreEvent.Get(pid)
	if not all[pid] then
		all[pid] = GuildExploreEvent.New(pid)
	end

	return all[pid]
end

function GuildExploreEvent.New(pid)
	local t = {
		pid = pid,
		events = {}	
	}
	local success, result = database.query("select uuid, pid, map_id, team_id, event_id, hero_uuid, unix_timestamp(begin_time) as begin_time, unix_timestamp(end_time) as end_time from player_guild_explore_event where pid = %d AND (NOW() <= end_time OR unix_timestamp(end_time) = 0)", pid)
	if success then
		for _, row in ipairs(result) do
			t.events[row.map_id] = t.events[row.map_id] or {}
			t.events[row.map_id][row.team_id] = t.events[row.map_id][row.team_id] or {event_count = 0, event_last_begin_time = 0, events = {}}
			table.insert(t.events[row.map_id][row.team_id].events, {uuid = row.uuid,  event_id = row.event_id, hero_uuid = row.hero_uuid, begin_time = row.begin_time, end_time = row.end_time})
			if row.begin_time > t.events[row.map_id][row.team_id].event_last_begin_time then
				t.events[row.map_id][row.team_id].event_last_begin_time = row.begin_time	
			end
			t.events[row.map_id][row.team_id].event_count = t.events[row.map_id][row.team_id].event_count + 1
		end
	end

	return setmetatable(t, {__index = GuildExploreEvent})
end

local function EventIndex(events, uuid)
	for k , v in ipairs(events) do
		if v.uuid == uuid then
			return k	
		end
	end
end

function GuildExploreEvent:DeleteEvent(map_id, team_id, uuid)
	local delete_list = {}

	if not map_id and not team_id and not uuid then
		DEBUG_LOG(string.format("Player %d delete all explore event ", self.pid))
		for mid, v in pairs(self.events) do
			for team_id, v2 in pairs(v) do
				for _, v3 in ipairs(v2.events) do
					table.insert(delete_list, {mid, team_id, v3.uuid})	
				end
			end
		end
		
		if #delete_list > 0 then
			Notify(Command.NOTIFY_GUILD_MAP_EXPLORE_EVENT_CHANGE, self.pid, {0, {delete_list}} )
		end

		self.events = {}	
		database.update("delete from player_guild_explore_event where pid = %d", self.pid)	
		return true
	end

	if map_id and not team_id and not uuid then
		DEBUG_LOG(string.format("Player %d delete all explore event for map %d", self.pid, map_id))
		for team_id, v in pairs(self.events[map_id] or {}) do
			for _, v2 in ipairs(v.events) do
				table.insert(delete_list, {mid, team_id, v2.uuid})	
			end
		end
		
		if #delete_list > 0 then
			Notify(Command.NOTIFY_GUILD_MAP_EXPLORE_EVENT_CHANGE, self.pid, {0, {delete_list}} )
		end

		if self.events[map_id] then
			self.events[map_id]= {}	
			database.update("delete from player_guild_explore_event where pid = %d AND map_id = %d", self.pid, map_id)	
		end
		return true
	end
	
	if map_id and team_id and not uuid then
		DEBUG_LOG(string.format("Player %d delete all event for map %d team %d", self.pid, map_id, team_id))
		if self.events[map_id] and self.events[map_id][team_id] then
			for k, v in ipairs(self.events[map_id][team_id].events or {}) do
				table.insert(delete_list, {map_id, team_id, v.uuid})
			end
			self.events[map_id][team_id] = nil
			if #delete_list > 0 then
				Notify(Command.NOTIFY_GUILD_MAP_EXPLORE_EVENT_CHANGE, self.pid, {0, delete_list} )
			end
			database.update("delete from player_guild_explore_event where pid = %d and map_id = %d and team_id = %d", self.pid, map_id, team_id)	
		end

		return true
	end

	if map_id and team_id and uuid then
		DEBUG_LOG(string.format("Player %d delete event for map %d team %d uuid %d", self.pid, map_id, team_id, uuid))
		if not self.events[map_id] or not self.events[map_id][team_id] then
			WARNING_LOG(string.format("Player %d fail to DeleteEvent, event not exist", self.pid))
			return false
		end

		local idx = EventIndex(self.events[map_id][team_id].events, uuid) 
		if not idx then
			WARNING_LOG(string.format("Player %d fail to DeleteEvent, event for uuid %d not exist", self.pid, uuid))
			return false
		end	

		table.remove(self.events[map_id][team_id].events, idx)
		self.events[map_id][team_id].event_count = self.events[map_id][team_id].event_count - 1
		database.update("delete from player_guild_explore_event where uuid = %d", uuid)	
		
		Notify(Command.NOTIFY_GUILD_MAP_EXPLORE_EVENT_CHANGE, self.pid, {0, {{map_id, team_id, uuid}}} )

		return true
	end

	
	WARNING_LOG(string.format("Player %d delete event fail, param error", self.pid))
end

function GuildExploreEvent:CheckAndDeleteEvent(map_id, team_id)
	DEBUG_LOG(string.format("Player %d begin to check and delete event", self.pid))
	-- check out of date event
	if not map_id and not team_id then
		local need_delete = {}
		for map_id, v in pairs(self.events) do
			for team_id, v2 in pairs(v) do
				for _, v3 in ipairs(v2.events) do
					if v3.end_time > 0 and loop.now() > v3.end_time then
						table.insert(need_delete, {map_id, team_id, v.uuid})	
					end
				end
			end

			for _, v in ipairs(need_delete) do
				DEBUG_LOG(string.format("Player %d event %d out of date, so delete event", self.pid, uuid))	
				self:DeleteEvent(v[1], v[2], v[3])
			end
		end
	end

	if self.events[map_id] and self.events[map_id][team_id] then
		local need_delete = {}
		for k, v in ipairs(self.events[map_id][team_id].events) do
			if v.end_time > 0 and loop.now() > v.end_time then
				table.insert(need_delete, v.uuid)	
			end	
		end

		for _, uuid in ipairs(need_delete) do
			DEBUG_LOG(string.format("Player %d event %d out of date, so delete event", self.pid, uuid))	
			self:DeleteEvent(map_id, team_id, uuid)
		end
	end	

	--check map event
	local player = PlayerManager.Get(self.pid)
	if not player then
		WARNING_LOG(string.format("Player %d fail to check and replace map event,  player not exist", self.pid))
		return false
	end

	local guild = player.guild
	if not guild then
		WARNING_LOG(string.format("Player %d fail to check and replace map event,  player not has guild", self.pid))
		return false
	end	

	DEBUG_LOG(string.format("guild %d check and replace map event", guild.id))
	local t = {}
	local time = 0
	for _, m in pairs(guild.members) do
		local player_event = GuildExploreEvent.Get(m.id)
		local map_events = player_event:GetDisplayMapEvent()
		for k, v in ipairs(map_events) do
			table.insert(t, v)	
		end
	end

	table.sort(t, function(a, b)
		if a.begin_time ~= b.begin_time then
			return a.begin_time < b.begin_time
		end
	end)


	if HasLimitTimeMap(guild.id) then
		log.debug("Has limit time map >>>>>>>>>>>>>>>>>>>>>>>>>")
		for k, v in ipairs(t) do
			local instance = GuildExploreEvent.Get(v.pid)
			instance:DeleteEvent(v.map_id, v.team_id, v.uuid)	
			instance:FillEvent(v.map_id, v.team_id)
		end
	else
		for i = 2, #t, 1 do
			local instance = GuildExploreEvent.Get(t[i].pid)
			instance:DeleteEvent(t[i].map_id, t[i].team_id, t[i].uuid)	
			instance:FillEvent(t[i].map_id, t[i].team_id)
		end	
	end	
	
	return true
end

function GuildExploreEvent:CheckConditionForEvent(event_id, map_id, team_id)
	DEBUG_LOG(string.format("Player %d begin to check condition for event %d", self.pid, event_id))
	local cfg = GetGuildExploreEventMap(event_id)
	if not cfg then 
		WARNING_LOG(string.format("Player %d fail to check condition, event config is nil"))
		return false
	end

	if cfg.condition_type == 0 then 
		return true, 0
	end

	local team = GetPlayerTeam(self.pid, map_id, team_id)	
	if cfg.condition_type == 1 then
		for i = 1, 5, 1 do
			local hero_uuid = team["formation_role"..i]
			local hero_info = cell.getPlayerHeroInfo(self.pid, 0, hero_uuid)	
			if not hero_info then
				WARNING_LOG(string.format("Player %d fail to check condition, donnt has hero uuid %d", hero_uuid))
				return false
			end
	
			if hero_info.gid == cfg.condition_para1 and hero_info.stage >= cfg.condition_para2 then
				return true, hero_uuid
			end
		end

		return false
	elseif cfg.condition_type == 2 then
		for i = 1, 5, 1 do
			local hero_uuid = team["formation_role"..i]
			if hero_uuid ~= 0 then
				local hero_info = cell.getPlayerHeroInfo(self.pid, 0, hero_uuid)	
				if not hero_info then
					WARNING_LOG(string.format("Player %d fail to check condition, donnt has hero uuid %d", hero_uuid))
					return false
				end
		
				if hero_info.gid == cfg.condition_para1 and hero_info.star >= cfg.condition_para2 then
					return true, hero_uuid
				end
			end
		end
		
		return false	
	end

	return false
end

function GuildExploreEvent:AddEvent(map_id, team_id, guild_level)
	DEBUG_LOG(string.format("Player %d begin AddEvent for map %d team %d", self.pid, map_id, team_id))

	local event_list = GetGuildExploreEventList(map_id, guild_level)		

	if #event_list.list <= 0 or event_list.total_weight == 0 then
		WARNING_LOG(string.format("Player %d fail to AddEvent, event config for map %d is nil", self.pid, map_id))
		return false
	end

	local event_id = 0
	local randnum = math.random(1, event_list.total_weight)
	for k, v in ipairs(event_list.list or {}) do
		if randnum <= v.weight then
			event_id = v.event_id
			break
		else
			randnum = randnum - v.weight
		end	
	end

	if event_id > 0 then
		local cfg = GetGuildExploreEventMap(event_id)
		
		self.events[map_id] = self.events[map_id] or {}	
		self.events[map_id][team_id] = self.events[map_id][team_id] or {event_count = 0, event_last_begin_time = 0, events = {}}	
	
		local interval = math.random(cfg.trigger_time_min, cfg.trigger_time_max)
		local member_count = GetPlayerTeamMemberCount(self.pid, map_id, team_id)
		if member_count then
			math.floor((1 - 0.1 * member_count) * interval)
		end
		
		local hero_uuid = 0
		if cfg.next_id ~= 0 then
			local check_success, uuid = self:CheckConditionForEvent(cfg.next_id, map_id, team_id)
			if check_success then
				event_id = cfg.next_id
				hero_uuid = uuid
			end	
		end

		-- get random hero_uuid    hero_uuid is used for client
		if hero_uuid == 0 then
			local team = GetPlayerTeam(self.pid, map_id, team_id)	
			local random_list = {}
			for i = 1, 5, 1 do
				if team["formation_role"..i] and team["formation_role"..i] ~= 0 then
					table.insert(random_list, team["formation_role"..i])
				end
			end
			
			if #random_list > 0 then
				hero_uuid = random_list[math.random(1, #random_list)]
			end	
		end

		local time = self.events[map_id][team_id].event_last_begin_time > 0 and self.events[map_id][team_id].event_last_begin_time or loop.now() 
		if self.events[map_id][team_id].event_last_begin_time == 0 then
			time = loop.now()
		end

		if self.events[map_id][team_id].event_last_begin_time > 0 and loop.now() > self.events[map_id][team_id].event_last_begin_time then
			time = loop.now()
		end

		if self.events[map_id][team_id].event_last_begin_time > 0 and loop.now() <= self.events[map_id][team_id].event_last_begin_time then
			time = self.events[map_id][team_id].event_last_begin_time
		end
		
		database.update("insert into player_guild_explore_event(pid, map_id, team_id, event_id, hero_uuid, begin_time, end_time) values(%d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d))", self.pid, map_id, team_id, event_id, hero_uuid, time + interval, (cfg.event_duration > 0) and (time + interval + cfg.event_duration) or 0)	
		table.insert(self.events[map_id][team_id].events, {event_id = event_id, uuid = database.last_id(), hero_uuid = hero_uuid, begin_time = time + interval, end_time = (cfg.event_duration > 0) and (time + interval + cfg.event_duration) or 0})

		Notify(Command.NOTIFY_GUILD_MAP_EXPLORE_EVENT_CHANGE, self.pid, { 1, {map_id, team_id, event_id, hero_uuid, database.last_id(), time + interval, (cfg.event_duration > 0) and (time + interval + cfg.event_duration) or 0}} )

		self.events[map_id][team_id].event_count = self.events[map_id][team_id].event_count + 1
		if time + interval > self.events[map_id][team_id].event_last_begin_time then
			self.events[map_id][team_id].event_last_begin_time = time + interval
		end
	
		return true
	end

	WARNING_LOG(string.format("Player %d fail to AddEvent, random error", self.pid))
end

function GuildExploreEvent:GetEvents(map_id, team_id)
	DEBUG_LOG(string.format("Player %d begin to get events for map %d team %d", self.pid, map_id, team_id))
	
	self:CheckAndDeleteEvent(map_id, team_id)

	local amf = {}
	for map_id, v in pairs(self.events) do
		for team_id, v2 in pairs(v) do
			for _, v3 in ipairs(v2.events) do
				table.insert(amf, {map_id, team_id, v3.event_id, v3.hero_uuid, v3.uuid, v3.begin_time, v3.end_time})
			end
		end
	end

	return #amf > 0 and amf or nil
end

function GuildExploreEvent:FillEvent(map_id, team_id)
	DEBUG_LOG(string.format("Player %d begin FillEvent for map %d team %d", self.pid, map_id, team_id))
	
	self.events[map_id] = self.events[map_id] or {}
	self.events[map_id][team_id] = self.events[map_id][team_id] or {event_count = 0, event_last_begin_time = 0, events = {}}

	self:CheckAndDeleteEvent(map_id, team_id)

	local team = GetPlayerTeam(self.pid, map_id, team_id)	
	if not team then
		WARNING_LOG(string.format("Player %d fail to FillEvent, donnt has team in this map", self.pid))
		return false
	end

	local player = PlayerManager.Get(self.pid)
	if not player then
		WARNING_LOG(string.format("Player %d fail to FillEvent, player not exist", self.pid))
		return false
	end

	if not player.guild then
		WARNING_LOG(string.format("Player %d fail to FillEvent, player not has guild", self.pid))
		return false
	end

	if self.events[map_id] and self.events[map_id][team_id] and self.events[map_id][team_id].event_count >= MAX_EVENT_COUNT then
		WARNING_LOG(string.format("Player %d fail to FillEvent, event count already max in map %d", self.pid, map_id))
		return false
	end

	local guild = player.guild
	if not guild then
		WARNING_LOG(string.format("Player %d fail to FillEvent, player not has guild", self.pid))
		return false
	end

	for i = 1, MAX_EVENT_COUNT - self.events[map_id][team_id].event_count, 1 do
		self:AddEvent(map_id, team_id, guild.level)
	end
end

function GuildExploreEvent:GetDisplayMapEvent()
	local t = {}
	for map_id, v in pairs(self.events) do
		for team_id, v2 in pairs(v) do
			for _, v3 in ipairs(v2.events) do
				local event_id = v3.event_id 
				local cfg = GetGuildExploreEventMap(event_id)
				if cfg and cfg.event_type == EVENT_TYPE_MAP and loop.now() >= v3.begin_time then
					table.insert(t, {pid = self.pid, map_id = map_id, team_id = team_id, uuid = v3.uuid, begin_time = v3.begin_time, end_time = v3.end_time})
				end
			end
		end
	end

	return t 
end

function GuildExploreEvent:FinishEvent(map_id, team_id, uuid)
	DEBUG_LOG(string.format("Player %d begin to finish event for map %d, team %d, uuid %d ", self.pid, map_id, team_id, uuid))

	self:CheckAndDeleteEvent(map_id, team_id)

	local player = PlayerManager.Get(self.pid)
	if not player then
		WARNING_LOG(string.format("Player %d fail to FinishEvent, player not exist", self.pid))
		return false
	end

	if not player.guild then
		WARNING_LOG(string.format("Player %d fail to FinishEvent, player not has guild", self.pid))
		return false
	end

	local guild = player.guild
	if not guild then
		WARNING_LOG(string.format("Player %d fail to FinishEvent, player not has guild", self.pid))
		return false
	end
	
	if not self.events[map_id] or not self.events[map_id][team_id] then
		WARNING_LOG(string.format("Player %d fail to FinishEvent, event not exist", self.pid))
		return false
	end

	local idx = EventIndex(self.events[map_id][team_id].events, uuid) 
	if not idx then
		WARNING_LOG(string.format("Player %d fail to FinishEvent, event for uuid %d not exist", self.pid, uuid))
		return false
	end	

	local event_id = self.events[map_id][team_id].events[idx].event_id
	local cfg = GetGuildExploreEventMap(event_id)
	if not cfg then
		WARNING_LOG(string.format("Player %d fail to FinishEvent, cfg for event %d is nil", self.pid, event_id))
		return false
	end

	if cfg.event_type == EVENT_TYPE_REWARD then
		print("reward event, send reward for explore event")
		local respond = cell.sendReward(self.pid, cfg.rewards, nil, Command.REASON_GUILD_EXPLORE_EVENT, false, 0);
		if respond == nil or respond.result ~= Command.RET_SUCCESS then
			yqinfo("Fail to send reward for explore event, cell error")
		end

	elseif cfg.event_type == EVENT_TYPE_FIGHT then
		print("fight event")
		--self:AddGuildPlayerFight(self.pid, cfg.event_result)
	elseif cfg.event_type == EVENT_TYPE_MAP then
		print("map event")
		--check if exist same type event
		--local success, err = CheckAndReplaceMapEvent(self.pid, map_id, team_id, uuid)		
		--if success and err == "not deleted" then
			AddNewMap(guild.id, cfg.event_result, loop.now(), loop.now() + cfg.event_duration)
		--end
	end

	self:DeleteEvent(map_id, team_id, uuid)

	for i = 1, MAX_EVENT_COUNT - self.events[map_id][team_id].event_count, 1 do
		self:AddEvent(map_id, team_id, guild.level)
	end
	
	local event_log = GuildEventLog.Get(guild.id)
	if event_log then
		event_log:AddLog(1, {self.pid, map_id, team_id, event_id})
	end

	return true
end

function server_finish_explore_event(conn, channel, request)
	local sn = request.sn or 0
	local pid = request.pid

	if channel ~= 0 then
		log.warning("server_finish_explore_event: channel is not zero.")
		return
	end

	log.debug(string.format("server_finish_explore_event: ai %d finish explore.", pid))

	local player = PlayerManager.Get(pid)
	if not player then
		log.warning(string.format("server_finish_explore_event: player %d is not exist.", pid))
		return
	end	
	
	if not player.guild then
		log.warning(string.format("sendServiceRespond: player %s has not guild.", pid))
		return
	end

	local event_log = GuildEventLog.Get(player.guild.id)
	if event_log then
		local maps = {}
		for _, v in pairs(guild_explore_event_config.map) do
			local map_config = GetExploreMapConfig(v.map_id)
			if map_config and map_config.team_level <= player.guild.level then 
				table.insert(maps, v)
			end
		end
		
		local count = math.random(2, 3)
		count = math.min(count, #maps)
		for i = 1, count do
			local index = math.random(#maps)
			event_log:AddLog(1, { pid, maps[index].map_id, i, maps[index].event_id })
			table.remove(maps, index)
		end
	end
end

return GuildExploreEvent
