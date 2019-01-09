local NetService = require "NetService"
local log = require "log"
local cell = require "cell"
local ManorEvent = require "ManorEvent"
local ManorWorkman = require "ManorWorkman"
local ManorLog = require "ManorLog"
local EVENT_TYPE_HERO_BACK_TAVERN = 4

local playerHeros = {}
local function getPlayerHeros(pid)
	if playerHeros[pid] == nil or loop.now() - playerHeros[pid].update_time > 300 then
		playerHeros[pid] = {}
		local _, heros = cell.getPlayerHeroInfo(pid, 0, 0)
		playerHeros[pid].heros =  heros
		playerHeros[pid].update_time = loop.now()
	end
	return playerHeros[pid].heros 
end

local function isEmptyOrNull(t)
	return t == nil or #t == 0
end

local function DOReward(pid, reward, consume, reason, manual, limit, name)
	assert(reason and reason ~= 0)

	if isEmptyOrNull(reward) and isEmptyOrNull(consume) then
		return true
	end

	local respond = cell.sendReward(pid, reward, consume, reason, manual, limit, name)
	if respond == nil or respond.result ~= 0 then
		return false;
	end
	return true;
end


local ManorHeroInPub = {}

local playerHeroInPub = {}
function GetPlayerHeroInPub(pid)
	if not playerHeroInPub[pid] then
		playerHeroInPub[pid] = ManorHeroInPub.New(pid)
	end
	return playerHeroInPub[pid]
end

function UnloadPlayerHeroInPub(pid)
	if playerHeroInPub[pid] then
		playerHeroInPub[pid] = nil
	end
end

function ManorHeroInPub.New(pid)
	local t = {
		pid = pid,
		last_event_time = 0,
		heros = {}
	}

	local success, result = database.query("select uuid, unix_timestamp(leave_time) as leave_time, unix_timestamp(back_time) as back_time, finish, event_id from manor_tavern_hero_status where pid = %d", pid)	
	if success then
		for _, row in ipairs(result) do
			t.heros[row.uuid] = t.heros[row.uuid] or {}
			t.heros[row.uuid].leave_time = row.leave_time
			t.heros[row.uuid].back_time = row.back_time
			t.heros[row.uuid].event_id = row.event_id
			t.heros[row.uuid].finish = row.finish
			t.heros[row.uuid].db_exists = true
			if row.leave_time > t.last_event_time then
				t.last_event_time = row.leave_time
			end
		end
	end

	return setmetatable(t, {__index = ManorHeroInPub})
end

local REFRESH_PERIOD = 3600 

function ManorHeroInPub:PushTimeLine()
	if loop.now() - self.last_event_time > 3600 * 24 then
		self:TriggerEvent(loop.now())	
	end

	while loop.now() - self.last_event_time > REFRESH_PERIOD do
		self:TriggerEvent(self.last_event_time + REFRESH_PERIOD)
	end

	self:FinishTavernEvent(loop.now())
	for uuid, v in pairs(self.heros) do
		if v.data_change then
			if v.db_exists then
				database.update("update manor_tavern_hero_status set leave_time = from_unixtime_s(%d), back_time = from_unixtime_s(%d), finish = %d, event_id = %d where pid = %d and uuid = %d", v.leave_time, v.back_time, v.finish, v.event_id, self.pid, uuid)
			else
				database.update("insert into manor_tavern_hero_status (pid, uuid, leave_time, back_time, finish, event_id) values(%d, %d, from_unixtime_s(%d), from_unixtime_s(%d), %d, %d)", self.pid, uuid, v.leave_time, v.back_time, v.finish, v.event_id)
				v.db_exists = true
			end
			v.data_change = nil
		end
	end
end

function ManorHeroInPub:FinishTavernEvent(time)
	for uuid, v in pairs (self.heros or {}) do
		if v.finish == 0 and time > v.back_time then
			local cfg = LoadRiskPoolConfig(nil, v.event_id)	
			local reward = {}
			local add_value = 0

			for i = 1, 3, 1 do
				if cfg["reward_type"..i] ~= 0 then
					if cfg["reward_type"..i] == 110 then
						local manor_workman = ManorWorkman.Get(self.pid)
						add_value = math.random(cfg["reward_value_min"..i], cfg["reward_value_max"..i])
						manor_workman:AddWorkmanPower(uuid, add_value)
					else
						local item = {type = cfg["reward_type"..i], id = cfg["reward_id"..i], value = math.random(cfg["reward_value_min"..i], cfg["reward_value_max"..i])}
						table.insert(reward, item)
					end
				end
			end

			if #reward > 1 then
				--隐藏道具
				table.insert(reward, {type = 41, id = 100000, value = 1})
				DOReward(self.pid, reward, nil, Command.REASON_MANOR_EVENT, false, loop.now() + 14 * 24 * 3600, nil)
			end
		
			self:UpdateHeroStatus(uuid, v.leave_time, v.back_time, 1, v.event_id)
			
			local amf_reward = {}
			for k, v in ipairs(reward) do
				table.insert(amf_reward, {v.type, v.id, v.value})
			end
			--self:Notify(Command.NOTIFY_MANOR_HERO_BACK_TAVERN, {uuid, v.event_id, v.leave_time, v.back_time, amf_reward, add_value})

			local manor_log = ManorLog.Get(self.pid)
			manor_log:AddLog(EVENT_TYPE_HERO_BACK_TAVERN, {uuid, v.event_id, v.leave_time, v.back_time, amf_reward, add_value})
		end	
	end
end

-- -1 working 0 normal 1 leaving 
function ManorHeroInPub:GetHeroStatus(uuid)
	self:PushTimeLine()
	
	local info = GetManufacture(self.pid)
	local line, pos, linfo = info:GetWorkmanLineAndPos(uuid)

	if line > 0 and pos > 0 and linfo then
		return -1, 0, 0
	end

	if not self.heros[uuid] then
		return 0, 0, 0
	end		
	
	if loop.now() > self.heros[uuid].back_time then
		return 0, 0, 0
	end

	return 1, self.heros[uuid].leave_time, self.heros[uuid].back_time 
end

function ManorHeroInPub:Notify(cmd, msg)
	NetService.NotifyClients(cmd, msg, {self.pid});
end

function ManorHeroInPub:UpdateHeroStatus(uuid, leave_time, back_time, finish, event_id)
	if self.heros[uuid] and self.heros[uuid].leave_time == leave_time and self.heros[uuid].back_time == back_time and self.heros[uuid].finish == finish then
		return
	end

	if not self.heros[uuid] then
		self.heros[uuid] = {}
		self.heros[uuid].db_exists = false 
	end

	self.heros[uuid].leave_time = leave_time
	self.heros[uuid].back_time = back_time
	self.heros[uuid].finish = finish
	self.heros[uuid].event_id = event_id 
	self.heros[uuid].data_change = true

	--[[if self.heros[uuid].db_exists then
		database.update("update manor_tavern_hero_status set leave_time = from_unixtime_s(%d), back_time = from_unixtime_s(%d), finish = %d, event_id = %d where pid = %d and uuid = %d", leave_time, back_time, finish, event_id, self.pid, uuid)
	else
		database.update("insert into manor_tavern_hero_status (pid, uuid, leave_time, back_time, finish, event_id) values(%d, %d, from_unixtime_s(%d), from_unixtime_s(%d), %d, %d)", self.pid, uuid, leave_time, back_time, finish, event_id)
		self.heros[uuid].db_exists = true
	end--]]

end

function ManorHeroInPub:TriggerEvent(time)
	self:FinishTavernEvent(time)

	local t = {}
	local heros = getPlayerHeros(self.pid)
	local info = GetManufacture(self.pid)

	for k, v in ipairs(heros) do
		local line, pos, linfo = info:GetWorkmanLineAndPos(v.uuid)
		local working = line > 0 and pos > 0 and linfo 
		
		if not working and (not self.heros[v.uuid] or time > self.heros[v.uuid].back_time) then
			table.insert(t, {uuid = v.uuid, gid = v.gid})
		end
	end
	
	local manor_event = ManorEvent.Get(self.pid)
	manor_event:TriggerRiskingEvent(t, self, time)
	if time > self.last_event_time then
		self.last_event_time = time
	end
end

local service = select(1, ...);

service:on(Command.C_MANOR_QUERY_HERO_STATUS_REQUEST, function(conn, pid, request)
	local sn = request[1]
	local uuid = request[2]
	local manor_hero = GetPlayerHeroInPub(pid)
	local status , leave_time, back_time = manor_hero:GetHeroStatus(uuid)

	conn:sendClientRespond(Command.C_MANOR_QUERY_HERO_STATUS_RESPOND, pid, {sn, Command.RET_SUCCESS, status, leave_time, back_time});
end)


return ManorHeroInPub
