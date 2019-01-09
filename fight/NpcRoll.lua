local database = require "database"

local PICK_TYPE_TEAM_BATTLE = 1 --小队副本

local NpcRoll = {}

local players = {}
local function loadPlayerData(pid)
	local success, results = database.query("select pid, `type`, today_count, unix_timestamp(update_time) as update_time from npc_roll where pid = %d", pid)
	if not success then return end
	local tb = {
		pid = pid,
		rolls = {}	
	}
	for _, row in ipairs(results) do
		tb.rolls[row.type] = tb.rolls[row.type] or {}	
		tb.rolls[row.type].type      		= row.type
		tb.rolls[row.type].today_count      = row.today_count
		tb.rolls[row.type].update_time      = row.update_time
		tb.rolls[row.type].db_exists        = true 
	end
	return setmetatable(tb, {__index = NpcRoll})
end

function NpcRoll.Get(pid) 
	if not players[pid] then
		players[pid] = loadPlayerData(pid)
	end
	return players[pid]	
end

--implement
function NpcRoll:RebuildPlayerData(type, time)
	--time = time or loop.now()
	time = loop.now()
	if not self.rolls[type] then
		self.rolls[type] = {
			type = type,
			today_count = 0,
			update_time = 0,
			db_exists = false,
		}
	end
	if StableTime.get_begin_time_of_day(time) > StableTime.get_begin_time_of_day(self.rolls[type].update_time) then
		self.rolls[type].today_count = 0
		self.rolls[type].update_time = time 
	end
end

function NpcRoll:GetRollCount(type, time)
	--time = time or loop.now()
	time = loop.now()
	self:RebuildPlayerData(type, time)
	
	return self.rolls[type].today_count	
end

function NpcRoll:UpdateRollCount(type, count, time)
	--time = time or loop.now()
	time = loop.now()
	self:RebuildPlayerData(type, time)

	self.rolls[type].today_count = count 
	self.rolls[type].update_time = time 

	if not self.rolls[type].db_exists then
		database.update("insert into npc_roll(pid, `type`, today_count, update_time) values(%d, %d, %d, from_unixtime_s(%d))", self.pid, type, count, time)
		self.rolls[type].db_exists = true
	else
		database.update("update npc_roll set today_count = %d, update_time = from_unixtime_s(%d) where pid = %d and `type` = %d", count, time, self.pid, type)
	end
end

function NpcRoll.registerCommand(service)
	service:on(Command.C_TEAM_QUERY_NPC_ROLL_COUNT_REQUEST, function(conn, pid, request)
		log.debug(string.format("Player %d begin to query npc roll count", pid))
		local sn = request[1];
		local type = request[2] or 1

		local npc_roll = NpcRoll.Get(pid)
		if not npc_roll then
			return conn:sendClientRespond(Command.C_TEAM_QUERY_NPC_ROLL_COUNT_RESPOND, pid, {sn, Command.RET_ERROR});
		end
		
		local today_count1 = npc_roll:GetRollCount(1)
		local today_count2 = npc_roll:GetRollCount(2)

		return conn:sendClientRespond(Command.C_TEAM_QUERY_NPC_ROLL_COUNT_RESPOND, pid, {sn, Command.RET_SUCCESS, today_count1, today_count2});
	end);
end

return NpcRoll
