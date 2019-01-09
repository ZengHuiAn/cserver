local TeamProxy = require "TeamProxy"
local BattleConfig = require "BattleConfig"

local All = {}
local TeamFightActivityTimeControl = {}

function TeamFightActivityTimeControl.New(teamid)
	if not teamid then
		return 	
	end
	
	local success, results = database.query("select battle_id, unix_timestamp(battle_begin_time) as battle_begin_time, unix_timestamp(battle_close_time) as battle_close_time from team_battle_time where teamid = %d", teamid)
	if not success then return end

	local t = {
		teamid = teamid,
		battle_time = {},
	}

	for _, row in ipairs(results) do
		t.battle_time[row.battle_id] = t.battle_time[row.battle_id] or {}
		t.battle_time[row.battle_id].begin_time = row.battle_begin_time
		t.battle_time[row.battle_id].end_time = row.battle_close_time
	end

	return setmetatable(t, {__index = TeamFightActivityTimeControl})
end

function TeamFightActivityTimeControl:GetTime(battle_id)
	if not self.battle_time[battle_id] then
		return 0, 0
	end

	return self.battle_time[battle_id].begin_time, self.battle_time[battle_id].end_time	
end

function TeamFightActivityTimeControl:NotifyAIBattleTimeChange(battle_id, begin_time, end_time)
	print("notify battle time change >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
	local team = getTeam(self.teamid);
	if team then
		print("notify battle time change >>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 222222")
		local AI_members = team:GetAIMembers()
		for _, id in ipairs(AI_members) do
			print("notify battle time change >>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 33333", id, battle_id, begin_time, end_time)
			SocialManager.NotifyAIBattleTimeChange(id, battle_id, begin_time, end_time)
		end
	end
end

function TeamFightActivityTimeControl:UpdateTime(battle_id, begin_time, end_time)
	if not self.battle_time[battle_id] then
		self.battle_time[battle_id] = {
			begin_time = begin_time,
			end_time = end_time
		}

		database.update("insert into team_battle_time(teamid, battle_id, battle_begin_time, battle_close_time) values(%d, %d, from_unixtime_s(%d), from_unixtime_s(%d))", self.teamid, battle_id, begin_time, end_time)
		self:NotifyAIBattleTimeChange(battle_id, begin_time, end_time)
		return true, begin_time, end_time
	end	

	self.battle_time[battle_id].begin_time = begin_time
	self.battle_time[battle_id].end_time = end_time
	database.update("update team_battle_time set battle_begin_time = from_unixtime_s(%d), battle_close_time = from_unixtime_s(%d) where teamid = %d and battle_id = %d", begin_time, end_time, self.teamid, battle_id)
	self:NotifyAIBattleTimeChange(battle_id, begin_time, end_time)
	return true, begin_time, end_time
end

function TeamFightActivityTimeControl:DeleteSelf()
	All[self.teamid] = nil
	database.update("delete from team_battle_time where teamid = %d", self.teamid)
	self = nil
end

function TeamFightActivityTimeControl.Get(teamid)
	if not All[teamid] then
		All[teamid] = TeamFightActivityTimeControl.New(teamid)
	end	

	return All[teamid]
end

function TeamFightActivityTimeControl.OnResetTeamProgress(teamid, battle_id)
	local time_control = TeamFightActivityTimeControl.Get(teamid)
	if not time_control then
		return
	end

	local begin_time, end_time = time_control:GetTime(battle_id)
	if end_time > 0 then
		time_control:UpdateTime(battle_id, 0, 0)
	end
end

TeamProxy.RegisterObserver({
	OnTeamDissolve = function(_, teamid)
		if All[teamid] then
			local time_control = TeamFightActivityTimeControl.Get(teamid)
			if time_control then
				time_control:DeleteSelf()
			end
		end
	end
})

function TeamFightActivityTimeControl.RegisterCommand(service)
	service:on(Command.C_TEAM_QUERY_BATTLE_TIME_REQUEST, function(conn, pid, request)
        local sn = request[1]
		local battle_id = request[2]

        log.debug(string.format("Player %d begin to query team battle time for battle:%d", pid, battle_id))

        local team = getTeamByPlayer(pid)
        if not team then
            log.debug("fail to query team battle time , player not in a team")
            return conn:sendClientRespond(Command.C_TEAM_QUERY_BATTLE_TIME_RESPOND, pid, {sn, Command.RET_ERROR});
        end

        local time_control = TeamFightActivityTimeControl.Get(team.id)

        if not time_control then
            return conn:sendClientRespond(Command.C_TEAM_QUERY_BATTLE_TIME_RESPOND, pid, {sn, Command.RET_ERROR});
        end

		local begin_time, end_time = time_control:GetTime(battle_id)

        return conn:sendClientRespond(Command.C_TEAM_QUERY_BATTLE_TIME_RESPOND, pid, {sn, Command.RET_SUCCESS, begin_time, end_time});
    end); 

	service:on(Command.C_TEAM_ENTER_BATTLE_REQUEST, function(conn, pid, request)
        local sn = request[1]
		local battle_id = request[2]

        log.debug(string.format("Player %d begin to enter battle time for battle:%d", pid, battle_id))

        local team = getTeamByPlayer(pid)
        if not team then
            log.debug("fail to enter battle , player not in a team")
            return conn:sendClientRespond(Command.C_TEAM_ENTER_BATTLE_RESPOND, pid, {sn, Command.RET_ERROR});
        end

		if pid ~= team.leader.pid then
            log.debug("fail to enter battle , player is not leader")
            return conn:sendClientRespond(Command.C_TEAM_ENTER_BATTLE_RESPOND, pid, {sn, Command.RET_ERROR});
		end

        local time_control = TeamFightActivityTimeControl.Get(team.id)

        if not time_control then
            return conn:sendClientRespond(Command.C_TEAM_ENTER_BATTLE_RESPOND, pid, {sn, Command.RET_ERROR});
        end

		local begin_time, end_time = time_control:GetTime(battle_id)
		local success = true
		if begin_time == 0 and end_time == 0 then
			local cfg = BattleConfig.GetBattleConfig(battle_id)
			local cd = cfg and cfg.limit_time or 30*60
			success, begin_time, end_time = time_control:UpdateTime(battle_id, loop.now(), loop.now() + cd)
		end	

        return conn:sendClientRespond(Command.C_TEAM_ENTER_BATTLE_RESPOND, pid, {sn, Command.RET_SUCCESS, begin_time, end_time});
    end); 

	service:on(Command.S_TEAM_QUERY_BATTLE_TIME_REQUEST, "QueryTeamBattleTimeRequest", function(conn, channel, request)
		local cmd = Command.S_TEAM_QUERY_BATTLE_TIME_RESPOND;
        local proto = "QueryTeamBattleTimeRespond";

        if channel ~= 0 then
            log.error(id .. "Fail to `S_TEAM_AI_QUERY_BATTLE_TIME_REQUEST`, channel ~= 0")
            sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
            return;
        end

        local pid = request.pid
        local battle_id = request.battle_id

        log.debug(string.format("Player %d begin to query team battle time for battle:%d", pid, battle_id))

		local team = getTeamByPlayer(pid)
        if not team then
            AI_DEBUG_LOG("fail to query ai team battle time , ai not in a team")
            return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
        end

		local time_control = TeamFightActivityTimeControl.Get(team.id)
        if not time_control then
            return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
        end

		local begin_time, end_time = time_control:GetTime(battle_id)
        return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS, battle_begin_time = begin_time, battle_end_time = end_time});
    end); 

	service:on(Command.S_TEAM_ENTER_BATTLE_REQUEST, "TeamEnterBattleRequest", function(conn, channel, request)
		local cmd = Command.S_TEAM_ENTER_BATTLE_RESPOND;
		local proto = "aGameRespond"

		if channel ~= 0 then
            log.error(id .. "Fail to `S_TEAM_ENTER_BATTLE_REQUEST`, channel ~= 0")
            sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
            return;
        end

        local pid = request.pid
        local battle_id = request.battle_id
        log.debug(string.format("AI %d begin to enter battle time for battle:%d", pid, battle_id))

        local team = getTeamByPlayer(pid)
        if not team then
            log.debug("ai fail to enter battle , ai not in a team")
            return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
        end

		if pid ~= team.leader.pid then
            log.debug("ai fail to enter battle , ai is not leader")
            return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

        local time_control = TeamFightActivityTimeControl.Get(team.id)
        if not time_control then
            return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
        end

		local begin_time, end_time = time_control:GetTime(battle_id)
		local success = true
		if begin_time == 0 and end_time == 0 then
			local cfg = BattleConfig.GetBattleConfig(battle_id)
			local cd = cfg and cfg.limit_time or 30*60
			success, begin_time, end_time = time_control:UpdateTime(battle_id, loop.now(), loop.now() + cd)
		end

        return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = success and Command.RET_SUCCESS or Command.RET_ERROR});
    end); 
end

return TeamFightActivityTimeControl
