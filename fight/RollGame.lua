require "Scheduler"
local bit32 = require "bit32"
local cell = require "cell"
local PlayerTeamFight = require "PlayerTeamFight"
local BattleConfig = require "BattleConfig"

local ROLL_GAME_LAST_TIME = 60 

local updateList = {}
local function addUpdateList(game)
	updateList[game.game_id] =  game
end

local function cleanUpdateList(game_id)
	if updateList[game_id] then
		updateList[game_id] = nil
	end
end

Scheduler.Register(function(t)
	for game_id, game in pairs(updateList) do
		log.debug("roll game left time", ROLL_GAME_LAST_TIME -(t - game.game_begin_time))
		if t - game.game_begin_time >= ROLL_GAME_LAST_TIME then
			game:SendRemainReward()
			updateList[game_id] = nil;
		end
	end
end);

local function SendReward(pid, consume, reward, reason) 
	local ret = cell.sendReward(pid, reward, consume, reason, false, nil, "", nil, nil)
	if type(ret)=='table' then
		if ret.result== Command.RET_SUCCESS then
			return true, Command.RET_SUCCESS, content 
		else
			if ret.result== Command.RET_NOT_ENOUGH then
				return false, Command.RET_NOT_ENOUGH
			else
				return false, Command.RET_ERROR
			end
		end
	else 
		return false, Command.RET_ERROR
	end
end

-- games
local games = {}
local function addGame(game)
	games[game.game_id] = game
end

local function getGame(game_id)
	return games[game_id]
end

local function cleanGame(game_id)
	if games[game_id] then
		games[game_id] = nil
	end
end

-- player games
local playerGames = {}
local function addPlayerGame(pid, game)
	playerGames[pid] = playerGames[pid] or {}
	playerGames[pid][game.game_id] = game
end

function getPlayerGame(pid, game_id)
	if not game_id then
		return playerGames[pid] and playerGames[pid] or nil
	else
		return playerGames[pid] and playerGames[pid][game_id] or nil
	end
end

local function cleanPlayerGame(pid, game_id)
	if playerGames[pid] and playerGames[pid][game_id] then
		playerGames[pid][game_id] = nil
	end
end

local gameID = 0
local function getNextGameID() 
	gameID = gameID + 1
	return gameID
end

local function roll(mask)
	local score
	while true do
		score = math.random(1, 100)
		if not mask[score] then
			break
		end
	end
	---
	return score
end

local RollGame = {}
local MAX_ROLL_COUNT = 1
function RollGame.New(team, reward, members_heros, fight_id)
	log.debug(string.format("begin a new roll game for team:%d", team.id))
	local t = {
		game_id = getNextGameID(), 
		team = team,
		game_begin_time = loop.now(),
		game_reward = reward,
		reward_flag = 0,
		members_score = {},
		members_heros = members_heros,
		default_winner = team.leader.pid,
		fight_id = fight_id,
		attend_list = {},
		absent_list = {},
	}	
	setmetatable(t, {__index = RollGame})
	addGame(t)
	for k, v in ipairs(team.members or {}) do
		addPlayerGame(v.pid, t)
	end
	addUpdateList(t)

	local reward = {}
	for k, v in ipairs(t.game_reward) do
		table.insert(reward, {v.type, v.id, v.value, k})
	end	

	local score_list = {}
	for index, v in pairs(t.members_score or {}) do
		for pid, v2 in pairs(v or {}) do
			table.insert(score_list, {pid, v2.score, index, v2.want})
		end	
	end

	local attend_list = {}
	local absent_list = {}
	for k, v in ipairs(team.members or {}) do
		local player_team_fight = PlayerTeamFight.Get(v.pid)
		local roll_count = player_team_fight:GetRollCount(t.fight_id)

		local fight_cfg = BattleConfig.Get(fight_id)
		if fight_cfg then
			local battle_cfg = BattleConfig.GetBattleConfig(fight_cfg.battle_id)
			if battle_cfg and  battle_cfg.limit_level then
				local result = cell.getPlayer(v.pid)
				local player = result and result.player or nil

				if roll_count < MAX_ROLL_COUNT and player and player.level <= battle_cfg.limit_level + 40 then
					table.insert(t.attend_list, v)
					table.insert(attend_list, v.pid)				
					player_team_fight:UpdateRollCount(t.fight_id, roll_count + 1)
				else
					table.insert(t.absent_list, v)
					table.insert(absent_list, v.pid)
				end	
			end
		end
	end

	if team.Notify then
		team:Notify(Command.NOTIFY_TEAM_ROLL_GAME_CREATE, {t.game_id, t.game_begin_time + ROLL_GAME_LAST_TIME, reward, t.reward_flag, score_list, attend_list, absent_list})
	end

	local AI_members = team:GetAIMembers()
	for _, id  in ipairs(AI_members or {}) do
		SocialManager.NotifyAIRollGameCreate(id, t.game_id, #reward)
	end

	return t, t.game_id
end

function RollGame:AlreadyRoll(target_reward, pid)
	return self.members_score[target_reward] and self.members_score[target_reward][pid] or nil
end

function RollGame:AllFinishRoll(target_reward)
	for k, v in ipairs(self.attend_list or {}) do
		if not self.members_score[target_reward] or not self.members_score[target_reward][v.pid] then
			return false
		end	
	end
	return true
end

function RollGame:PlayerCanRoll(pid)
	for k ,v in ipairs(self.attend_list) do
		if v.pid == pid then
			return true
		end
	end

	return false 
end

function RollGame:AllRewardFinish()
	for i = 1, #self.game_reward, 1 do
		local mask = 2 ^ (i - 1)
		if bit32.band(self.reward_flag, mask) == 0 then
			return false	
		end
	end
	return true
end

function RollGame:Info()
	local reward = {}
	for k, v in ipairs(self.game_reward) do
		table.insert(reward, {v.type, v.id, v.value, k})
	end	

	local score_list = {}
	for index, v in pairs(self.members_score or {}) do
		for pid, v2 in pairs(v or {}) do
			table.insert(score_list, {pid, v2.score, index, v2.want})
		end	
	end

	local attend_list = {}
	for k, v in ipairs(self.attend_list or {}) do
		table.insert(attend_list, v.pid)	
	end

	local absent_list = {}
	for k, v in ipairs(self.absent_list or {}) do
		table.insert(absent_list, v.pid)
	end

	return {self.game_id, self.game_begin_time + ROLL_GAME_LAST_TIME, reward, self.reward_flag, score_list, attend_list, absent_list}
end

function RollGame:Roll(pid, target_reward, want)
	log.debug(string.format("Player %d begin to roll for reward:%d", pid, target_reward))

	if self:AllRewardFinish() then
		log.debug("fail to roll, all reward has been sended")
		return false
	end

	if not self.game_reward[target_reward] then
		log.debug("fail to roll , donnt has this reward")
		return false
	end

	if self:AlreadyRoll(target_reward, pid) then
		log.debug("fail to roll , already roll")
		return false
	end

	if not self:PlayerCanRoll(pid) then
		log.debug(string.format("fail to roll , player %d cannt roll reward for fight:%d , already roll in this period", pid, self.fight_id))
		return false
	end
	
	if not want then
		self.members_score[target_reward] = self.members_score[target_reward] or {}
		self.members_score[target_reward][pid] = {score = 0, want = 0} 
		self.team:Notify(Command.NOTIFY_TEAM_PLAYER_ROLL, {self.game_id, pid, target_reward, 0, 0})

		if self:AllFinishRoll(target_reward) then
			self:SendReward(target_reward)
		end

		return true
	end

	local mask = {}
	for pid, v in pairs(self.members_score[target_reward] or {}) do
		mask[v.score] = true
	end

	local score = roll(mask)

	log.debug(string.format("roll score: %d", score))
	self.members_score[target_reward] = self.members_score[target_reward] or {}
	if want == true then
		self.members_score[target_reward][pid] = {score = score, want = 1}
	else
		self.members_score[target_reward][pid] = {score = score, want = 2}
	end

	--local player_team_fight = PlayerTeamFight.Get(pid)
	--local roll_count = player_team_fight:GetRollCount(self.fight_id, pid)
	--player_team_fight:UpdateRollCount(self.fight_id, roll_count + 1)

	if self.team.Notify then
		self.team:Notify(Command.NOTIFY_TEAM_PLAYER_ROLL, {self.game_id, pid, target_reward, score, want == true and 1 or 2})
	end
	
	if self:AllFinishRoll(target_reward) then
		self:SendReward(target_reward)
	end
	
	return true
end

function RollGame:RewardAlreadySended(target_reward)
	local mask = 2 ^ (target_reward - 1)
	return bit32.band(self.reward_flag, mask) == 1
end

function RollGame:UpdateRewardFlag(index, flag)
	local mask = 2 ^ (index - 1)
	self.reward_flag = bit32.bor(self.reward_flag, mask)	
end

function RollGame:SendReward(target_reward)
	log.debug(string.format("begin to send reward %d, type:%d, id:%d, value:%d", target_reward, self.game_reward[target_reward].type, self.game_reward[target_reward].id, self.game_reward[target_reward].value))
	if self:RewardAlreadySended(target_reward) then
		return
	end

	local winner = 0 --self.team.leader and self.team.leader.pid or 0
	local max_score = 0
	for pid, v in pairs(self.members_score[target_reward] or {}) do
		local score = v.score
		if v.want == 1 then
			score = v.score + 100
		end
		if score  > max_score then
			max_score = score
			winner = pid
		end
	end
	
	if winner > 0 then	
		--local final_reward = {}
		--for k, v in ipairs(self.game_reward[target_reward] or {}) do
		local reward = self.game_reward[target_reward]
		local final_reward = {{type = reward.type, id = reward.id, value = reward.value, uuids = self.members_heros[winner]}}
		--end

		--log.debug("send roll reward >>>>>>>>>>>>>>>>>", sprinttb(final_reward))
		local success, err = SendReward(winner, nil, final_reward, Command.REASON_TEAM_ROLL_PUBLIC_REWARD)
		log.debug(string.format("send reward to player:%d score:%d", winner, max_score))
	end

	self:UpdateRewardFlag(target_reward, 1)
	
	if self.team.Notify then
		self.team:Notify(Command.NOTIFY_TEAM_PLAYER_GET_PUBLIC_ROLL_REWARD, {self.game_id, winner, target_reward})
	end
	

	if self:AllRewardFinish() then
		cleanGame(self.game_id)
		for k, v in ipairs(self.team.members or {}) do
			cleanPlayerGame(v.pid, self.game_id)
		end

		cleanUpdateList(self.game_id)
		
		local AI_members = self.team:GetAIMembers()
		for _, id  in ipairs(AI_members or {}) do
			SocialManager.NotifyAIRollGameFinish(id, self.game_id)
		end
	end
end

function RollGame:SendRemainReward()
	log.debug("begin to send remain reward")
	for i = 1, #self.game_reward, 1 do
		if not self:RewardAlreadySended(i) then
			--替玩家roll点
			--[[for k ,v in ipairs(self.attend_list) do
				if not self.game_reward[i][v.pid] then
					self:Roll(v.pid, i, true)
				end
			end--]]

			self:SendReward(i)
		end
	end
end

function RollGame.registerCommand(service)
	service:on(Command.C_TEAM_QUERY_ROLL_GAME_INFO_REQUEST, function(conn, pid, request)
		local sn = request[1];

		log.debug(string.format("Player %d begin to query roll game info", pid))
		local games = getPlayerGame(pid)
		--[[if not games then
			log.debug("fail to query roll game info , not in a game")
			return conn:sendClientRespond(Command.C_TEAM_QUERY_ROLL_GAME_INFO_RESPOND, pid, {sn, Command.RET_ERROR});
		end--]]

		local amf = {}
		for _, game in pairs(games or {}) do
			local info = game:Info()
			table.insert(amf, info)	
		end

		return conn:sendClientRespond(Command.C_TEAM_QUERY_ROLL_GAME_INFO_RESPOND, pid, {sn, Command.RET_SUCCESS, amf});
	end);

	service:on(Command.C_TEAM_ROLL_GAME_ROLL_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local game_id = request[2]
		local index = request[3]
		local want = request[4] --and true or false --request[4]

		log.debug(string.format("Player %d begin to roll public reward", pid))
		local game = getPlayerGame(pid, game_id)
		if not game then
			log.debug("fail to roll public reward , not in a game")
			return conn:sendClientRespond(Command.C_TEAM_ROLL_GAME_ROLL_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local success = game:Roll(pid, index, want)
		return conn:sendClientRespond(Command.C_TEAM_ROLL_GAME_ROLL_RESPOND, pid, {sn, success and Command.RET_SUCCESS or Command.RET_ERROR});
	end);

	service:on(Command.S_TEAM_ROLL_REWARD_REQUEST, "TeamRollRewardRequest", function(conn, channel, request)
        local cmd = Command.S_TEAM_ROLL_REWARD_RESPOND;
        local proto = "aGameRespond";

        if channel ~= 0 then
            log.error(request.pid .. "Fail to `S_TEAM_ROLL_REWARD_REQUEST`, channel ~= 0")
            sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
            return;
        end

        local pid = request.pid
		local game_id = request.game_id
		local idx = request.idx
		local want = request.want

		local game = getPlayerGame(pid, game_id)
		if not game then
			log.debug("fail to ai roll public reward , not in a game")
            return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

		local success = game:Roll(pid, idx, want)
        if success then
            log.debug("Success ai roll public reward")
            return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
        else
            return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
        end

    end)

end

return RollGame
