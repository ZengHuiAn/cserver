local Command = require "Command"
local cell = require "cell"
local BinaryConfig = require "BinaryConfig"
local OpenlevConfig = require "OpenlevConfig"
local database = require "database"
require "printtb"

math.randomseed(os.time())

local QUEST_POOL = 501	-- 庄园随机任务池子
local QUEST_TYPE = 103	-- 庄园随机任务类型

local NPC_QUEST_TYPE = 14	-- npc随机任务类型

local OriginTime = 1499270400  -- 2017/7/6 0:0:0
local Seconds = 24 * 3600
local Period = 2 * 3600
local function deadTime(time)
	assert(time >= OriginTime)
	local n = math.floor((time - OriginTime) / Seconds) + 1
	return OriginTime + n * Seconds
end

-- 判断time是否与当前时间处于同一天
local function same_day(time)
	local dead_time = deadTime(loop.now())	
	local morning = dead_time - Seconds;

	if time >= morning and time < dead_time then
		return true
	end

	return false
end

-- npc整点刷新时间
local function NPC_TIME()
	local now = loop.now()
	return OriginTime + math.floor((now - OriginTime) / Period) * Period
end

-- 判断今天是否已经开启过庄园任务
local function is_start(quests)
	if quests == nil or #quests == 0 then
		return false, nil
	end

	for _, v in ipairs(quests) do
		log.debug("id, accept_time, status, records = ", v.id, v.accept_time, v.status, v.records[1])
		if same_day(v.accept_time) then
			return true, v
		end
	end

	return false, nil
end

local function split(str, deli)
	local start_index = 1	
	local n = 1
	local ret = {}

	if str == "" then
		return ret
	end

	while true do
		local end_index = string.find(str, deli, start_index)
		if not end_index then
			ret[n] = string.sub(str, start_index, string.len(str))
			break
		end
		ret[n] = string.sub(str, start_index, end_index - 1)
		n = n + 1
		start_index = end_index + string.len(deli)
	end	

	return ret
end

local RandomEventConfig = {}
function LoadRandomEventConfig()
	local rows = BinaryConfig.Load("random_event", "manor")
	for _, v in ipairs(rows) do
		RandomEventConfig[v.id] = RandomEventConfig[v.id] or { totalWeight = 0, list = {} }
		RandomEventConfig[v.id].totalWeight = RandomEventConfig[v.id].totalWeight + v.weight
		table.insert(RandomEventConfig[v.id].list, v)
	end
end
LoadRandomEventConfig()

function Random(pid, t, count)
	local list = {}
	for _, v in ipairs(t.list or {}) do
		table.insert(list, v)
	end
	local totalWeight = t.totalWeight
	local level = OpenlevConfig.get_level(pid)
	if #list == 0 then
		log.warning("random list is empty, ", sprinttb(t))
	end

	local ret = {}
	for i = 1, count do
		local n = math.random(totalWeight)
		for i, v in ipairs(list) do
			if n <= v.weight and level >= v.lv_min and level <= v.lv_max then
				totalWeight = totalWeight - v.weight
				table.insert(ret, v)
				table.remove(list, i)
				break
			else
				n = n - v.weight
			end
		end
	end
	
	if #ret == 0 then
		log.warning("random ret is empty, ", sprinttb(t))
	end

	return ret
end

local QuestPoolConfig = {}
function LoadQuestPoolConfig()
	local rows = BinaryConfig.Load("quest_pool", "quest")
	for _, v in ipairs(rows) do
		QuestPoolConfig[v.id] = QuestPoolConfig[v.id] or { totalWeight = 0, list = {} }
		QuestPoolConfig[v.id].totalWeight = QuestPoolConfig[v.id].totalWeight + v.weight
		table.insert(QuestPoolConfig[v.id].list, v)
	end
end
LoadQuestPoolConfig()

local NpcManager = { map = {} }
function NpcManager.GetNpc(pid)
	if NpcManager.map[pid] == nil then
		local ok, result = database.query("select pid, unix_timestamp(refresh_time) as refresh_time, quest_ids from random_npc where pid = %d;", pid)		
		if ok and #result > 0 then
			NpcManager.map[pid] = { pid = pid, refresh_time = result[1].refresh_time, quest_ids = {} }
			local ids_str = split(result[1].quest_ids, '|')
			for _, v in ipairs(ids_str) do
				table.insert(NpcManager.map[pid].quest_ids, tonumber(v))
			end
			NpcManager.map[pid].is_db = true
		else	
			NpcManager.map[pid] = { pid = pid, refresh_time = 0, quest_ids = {} }
			NpcManager.map[pid].is_db = false
		end
	end

	return NpcManager.map[pid]
end

function NpcManager.Update(info)
	local ok = false
	local str = info.quest_ids[1] and tostring(info.quest_ids[1]) or ""
	for i = 2, #info.quest_ids do
		str = str .. "|" .. info.quest_ids[i]
	end
	if info.is_db then
		ok = database.update("update random_npc set refresh_time = from_unixtime_s(%d), quest_ids = '%s' where pid = %d;", info.refresh_time, str, info.pid)
	else
		ok = database.update("insert into random_npc(pid, refresh_time, quest_ids) values(%d, from_unixtime_s(%d), '%s');", info.pid, info.refresh_time, str)
		if ok then
			info.is_db = true
		end
	end

	return ok
end

local function do_npc(pid)
	local npc = NpcManager.GetNpc(pid)		

	if npc.refresh_time ~= NPC_TIME() then
		-- 将所有过期的任务设置为取消的状态
		local quests = cell.QueryPlayerQuestList(pid, { NPC_QUEST_TYPE })	
		for _, quest in ipairs(quests) do
			if quest.status == 0 then
				local info = { uuid = 0, id = quest.id, status = 2 }
				cell.SetPlayerQuestInfo(pid, info)
			end
		end
		npc.quest_ids = {}
		
		local ids = Random(pid, RandomEventConfig[1], 3)
		for _, v in ipairs(ids) do
			local pool_id = v.mode_id 
			local quests = Random(pid, QuestPoolConfig[pool_id], 1)
			for _, v in ipairs(quests) do
				table.insert(npc.quest_ids, v.quest) 
			end
		end
		
		npc.refresh_time = NPC_TIME()
		NpcManager.Update(npc)
	else	
		-- 查询所有有关任务，移除已完成任务
		local quests = cell.QueryPlayerQuestList(pid, { NPC_QUEST_TYPE }, true)
		for _, quest in ipairs(quests) do
			log.debug("id, accept_time, status: ", quest.id, quest.accept_time, quest.status)
			if quest.accept_time > npc.refresh_time and quest.status == 1 then	-- 已经完成的任务
				for i, v in ipairs(npc.quest_ids) do
					if v == quest.id then
						table.remove(npc.quest_ids, i)
						break
					end
				end
			end
		end
		NpcManager.Update(npc)
	end

	return npc
end

local DayQuest = {}
function DayQuest.RegisterCommands(service)
	-- 庄园随机任务
	service:on(Command.C_MANOR_QUERY_TODAY_TASK_REQUEST, function (conn, pid, request)
		local cmd = Command.C_MANOR_QUERY_TODAY_TASK_RESPOND
		log.debug(string.format("cmd: %d, player %d query today task.", cmd, pid))

		if type(request) ~= "table" or #request < 1 then
			log.warning(string.format("cmd: %d, param error.", cmd))
			return conn:sendClientRespond(cmd, pid, { request[1] or 1, Command.RET_PARAM_ERROR })
		end
		local sn = request[1]

		local quests = cell.QueryPlayerQuestList(pid, { QUEST_TYPE }, true)
		local start, quest = is_start(quests)	
		if start then
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, quest.id, quest.records[1] })
		else
			local info = {
				uuid = 0,
				id = 0,
				status = 0,
				pool = QUEST_POOL,
			}
			local id = cell.SetPlayerQuestInfo(pid, info)
			if id then
				return conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, id, 0 })
			else
				log.warning(string.format("cmd: %d, player %d accept quest failed.", cmd, pid))
				return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
			end
		end
	end)

	-------------------------- 这两个协议是另一个功能  -------------------------
	service:on(Command.C_MANOR_RANDOM_NPC_REQUEST, function (conn, pid, request)
		local cmd = Command.C_MANOR_RANDOM_NPC_RESPOND
		log.debug(string.format("cmd: %d, player %d random npc.", cmd, pid))
		
		if type(request) ~= "table" or #request < 1 then
			log.warning(string.format("cmd: %d, param error.", cmd))
			return conn:sendClientRespond(cmd, pid, { request[1] or 1, Command.RET_PARAM_ERROR })
		end
		local sn = request[1]
	
		local npc = do_npc(pid)

		conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, npc.quest_ids })
	end)

	service:on(Command.C_MANOR_RANDOM_QUEST_REQUEST, function (conn, pid, request)
		local cmd = Command.C_MANOR_RANDOM_QUEST_RESPOND
		log.debug(string.format("cmd: %d, player %d random quest.", cmd, pid))

		if type(request) ~= "table" or #request < 2 then
			log.warning(string.format("cmd: %d, param error.", cmd))
			return conn:sendClientRespond(cmd, pid, { request[1] or 1, Command.RET_PARAM_ERROR })
		end
		local sn = request[1]
		local id = request[2]
	
		local npc = do_npc(pid)
		local could = false
		for _, v in ipairs(npc.quest_ids) do
			if v == id then
				could = true
				break
			end
		end
		if not could then
			log.warning(string.format("cmd: %d, quest %s is not exist, current quest id is: ", cmd, id, sprinttb(npc.quest_ids)))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
		end
	
		local info = {
			uuid = 0,
			id = id,
			status = 0,
			pool = 0,
		}
		local quest_id = cell.SetPlayerQuestInfo(pid, info)
		if quest_id then		
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, quest_id })
		else
			log.warning(string.format("cmd: %d, player %d accept quest failed.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
	end)
end

return DayQuest
