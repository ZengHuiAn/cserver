local database = require "database"
local BattleConfig = require "BattleConfig"

local PlayerTeamFight = {}

local players = {}
local function loadPlayerData(pid)
	local success, results = database.query("select pid, fight_id, count, unix_timestamp(update_time) as update_time, roll_count, unix_timestamp(last_roll_time) as last_roll_time from player_team_fight where pid = %d", pid)
	if not success then return end
	local tb = {
		pid = pid,
		fights = {}	
	}
	for _, row in ipairs(results) do
		tb.fights[row.fight_id] = tb.fights[row.fight_id] or {}	
		tb.fights[row.fight_id].fight_id    	= row.fight_id
		tb.fights[row.fight_id].count      	= row.count
		tb.fights[row.fight_id].update_time  = row.update_time
		tb.fights[row.fight_id].roll_count  = row.roll_count
		tb.fights[row.fight_id].last_roll_time  = row.last_roll_time
		tb.fights[row.fight_id].db_exists    = true 
	end
	return setmetatable(tb, {__index = PlayerTeamFight})
end

function PlayerTeamFight.Get(pid) 
	if not players[pid] then
		players[pid] = loadPlayerData(pid)
	end
	return players[pid]	
end

function PlayerTeamFight:RebuildPlayerData(fight_id, time)
	--time = time or loop.now()
	time = loop.now()
	local cfg = BattleConfig.Get(fight_id) 
	if not cfg then
		log.debug(string.format("fail rebuild playerdata config for fight:%d not exist", fight_id))
		return
	end

	if not self.fights[fight_id] then
		self.fights[fight_id] = {
			fight_id = fight_id,
			count = 0,
			update_time = 0,
			roll_count = 0,
			last_roll_time = 0,
			db_exists = false,
		}
	end

	local battle_id = cfg.battle_id 

	if BattleConfig.CheckNewPeriod(battle_id, self.fights[fight_id].update_time, time) then
		self.fights[fight_id].count = 0
		self.fights[fight_id].update_time = time 
	end

	if BattleConfig.CheckNewPeriod(battle_id, self.fights[fight_id].last_roll_time, time) then
		self.fights[fight_id].roll_count = 0
		self.fights[fight_id].last_roll_time = time 
	end
end

function PlayerTeamFight:GetWinCount(fight_id, time)
	--time = time or loop.now()
	time = loop.now()
	self:RebuildPlayerData(fight_id, time)
	
	return self.fights[fight_id] and self.fights[fight_id].count or nil
end

function PlayerTeamFight:UpdateWinCount(fight_id, count, time)
	--time = time or loop.now()
	time = loop.now()
	self:RebuildPlayerData(fight_id, time)

	if not self.fights[fight_id] then
		return 
	end

	self.fights[fight_id].count = count 
	self.fights[fight_id].update_time = time 

	if not self.fights[fight_id].db_exists then
		database.update("insert into player_team_fight(pid, fight_id, count, update_time, roll_count, last_roll_time) values(%d, %d, %d, from_unixtime_s(%d), %d, from_unixtime_s(%d))", self.pid, fight_id, count, time, self.fights[fight_id].roll_count, self.fights[fight_id].last_roll_time)
		self.fights[fight_id].db_exists = true
	else
		database.update("update player_team_fight set count = %d, update_time = from_unixtime_s(%d) where pid = %d and fight_id = %d", count, time, self.pid, fight_id)
	end
end

function PlayerTeamFight:GetRollCount(fight_id, time)
	time = loop.now()
	self:RebuildPlayerData(fight_id, time)
	
	return self.fights[fight_id] and self.fights[fight_id].roll_count or nil
end

function PlayerTeamFight:UpdateRollCount(fight_id, roll_count, time)
	--time = time or loop.now()
	time = loop.now()
	self:RebuildPlayerData(fight_id, time)

	if not self.fights[fight_id] then
		return 
	end

	self.fights[fight_id].roll_count = roll_count 
	self.fights[fight_id].last_roll_time = time 

	if not self.fights[fight_id].db_exists then
		database.update("insert into player_team_fight(pid, fight_id, count, update_time, roll_count, last_roll_time) values(%d, %d, %d, from_unixtime_s(%d), %d, from_unixtime_s(%d))", self.pid, fight_id, self.fights[fight_id].count, self.fights[fight_id].time, roll_count, time)
		self.fights[fight_id].db_exists = true
	else
		database.update("update player_team_fight set roll_count = %d, last_roll_time = from_unixtime_s(%d) where pid = %d and fight_id = %d", roll_count, time, self.pid, fight_id)
	end
end

function PlayerTeamFight.registerCommand(service)
	service:on(Command.C_TEAM_QUERY_PLAYER_FIGHT_WIN_COUNT_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local fights = request[2];
		if not fights then
			log.debug("query player team_fight win_count fail , param fights is nil")	
			return conn:sendClientRespond(Command.C_TEAM_QUERY_PLAYER_FIGHT_WIN_COUNT_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		if type(fights) ~= 'table' then
			log.debug("query player team_fight win_count fail param fights is not table")
			return conn:sendClientRespond(Command.C_TEAM_QUERY_PLAYER_FIGHT_WIN_COUNT_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		-- log.debug(string.format("Player %d begin to query player team_fight win_count for fights:%s", pid, sprinttb(fights)))

		local player_team_fight = PlayerTeamFight.Get(pid)
		if not player_team_fight then
			return conn:sendClientRespond(Command.C_TEAM_QUERY_PLAYER_FIGHT_WIN_COUNT_RESPOND, pid, {sn, Command.RET_ERROR});
		end
		
		local amf = {}
		for _ , fight_id in ipairs(fights) do
			local win_count = player_team_fight:GetWinCount(fight_id)
			local roll_count = player_team_fight:GetRollCount(fight_id)
			if win_count then
				table.insert(amf, {fight_id, win_count, roll_count})
			end
		end

		return conn:sendClientRespond(Command.C_TEAM_QUERY_PLAYER_FIGHT_WIN_COUNT_RESPOND, pid, {sn, Command.RET_SUCCESS, amf});
	end);
end

return PlayerTeamFight
