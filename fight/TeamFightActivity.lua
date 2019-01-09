require "Command"
require "Scheduler"
require "protobuf"


local TeamProxy = require "TeamProxy"

local PlayerTeamFight = require "PlayerTeamFight"
local getPlayerTeamFight = PlayerTeamFight.Get

local TeamProgress = require "TeamProgress"
local getTeamProgressManager = TeamProgress.Get
local deleteTeamProgress = TeamProgress.Delete

local TeamPlayerNpcRewardPool = require "TeamPlayerNpcRewardPool"
local getPlayerNpcRewardPool = TeamPlayerNpcRewardPool.Get

local BattleConfig = require "BattleConfig"
local NpcConfig = require "NpcConfig"

local Agent = require "Agent"
local database = require "database"
local cell = require "cell"

local RollGame = require "RollGame"
local TeamFightVM = require "TeamFightVM"
local TeamRewardManger = require "TeamReward" 

local NPC_REWARD_VALID_TIME = 10 * 3600
local SocialManager = require "SocialManager"


local TeamFightActivityTimeControl = require "TeamFightActivityTimeControl" 
local NetService = require "NetService"

local ONE_DAY_SEC = 86400

require "StableTime"
-- players
local players = {}
local function getPlayer(pid)
	if not players[pid] then
		local result = cell.getPlayer(pid)
		local player = result and result.player or nil;

		players[pid] = { 
			pid = pid,
			_name = player and player.name or "unknown",
			_level = player and player.level or 1,
			fresh_time = loop.now(),
			conn = nil
		};

		setmetatable(players[pid], {__index = function(t, k)
			if (loop.now() - t.fresh_time > 60) and coroutine.running() then
				local result = cell.getPlayer(pid)
				local player = result and result.player or nil

				t._name = player and player.name or t._name --"unknown"
				t._level= player and player.level or t._level --1 

				t.fresh_time = loop.now()
			end 			 

			return rawget(t, "_"..k)
		end})
	end
	return players[pid]
end

local function Notify(cmd, pid, msg)
	local agent = Agent.Get(pid);
	if agent then
		agent:Notify({cmd, msg});
	end
end

local function SendDropReward(pid, consume, reason, drops, heros)
	local ret = cell.sendReward(pid, consume, nil, reason, false, nil, "", drops, heros)
	if type(ret)=='table' then
		if ret.result== Command.RET_SUCCESS then
			local content = {}
			for k, v in ipairs(ret.rewards) do
				table.insert(content, {v.type, v.id, v.value})
			end

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

local function GetDropReward(drops, first_time)
	local ret = cell.getDropsReward(drops, first_time)--cell.sendReward(0, nil, nil, 0, false, nil, "", drops, nil, first_time, 0)
	if ret then
		local content = {}
		for k, v in ipairs(ret) do
			table.insert(content, {type = v.type, id = v.id, value = v.value})
		end
		return true, Command.RET_SUCCESS, content
	else
		return false
	end
	--[[if type(ret)=='table' then
		if ret.result== Command.RET_SUCCESS then
			local content = {}
			for k, v in ipairs(ret.rewards) do
				table.insert(content, {type = v.type, id = v.id, value = v.value})
			end
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
	end--]]
end

local function split( str,reps )
    local resultStrList = {}
    string.gsub(str,'[^'..reps..']+',function ( w )
        table.insert(resultStrList,w)
    end)
    return resultStrList
end


local function NotifyQuestEventByStr(pid, event_type, event_id_str)
	if not event_id_str then
		return
	end

	local ids = split(event_id_str, "|")	
	for _, id in ipairs(ids) do
		if tonumber(id) > 0 then	
			cell.NotifyQuestEvent(pid, {{type = event_type, id = tonumber(id), count = 1}})
		end
	end
end

local TeamFightAward = {}

function TeamFightAward.New(team)
	log.debug(string.format("create TeamFightAward for team:%d", team.id))
	local t = {
		team = team:Snap(),
		npc_drop_reward = {},
		npc_extra_roll = {},
	}
	return setmetatable(t, {__index = TeamFightAward})
end

-- callback   OnFightFinish   OnKillMonster
function TeamFightAward:OnFightFinished(winner, fight_id, fight_time, members_heros)
	log.debug("TeamFightAward Fight finish>>>>>>>>>>>>>")

	-- send fight reward
	self:SendFightReward(winner, fight_id, fight_time, members_heros)	
	self:UpdatePlayerTeamFightWinCount(winner, fight_id, fight_time)
	self:UpdateTeamProgress(winner, fight_id, fight_time)

	-- send npc drop rewrad
	if winner == 1 then
		for pid, v in pairs(self.npc_drop_reward or {}) do
			local success, err, rewards = SendDropReward(pid, nil, Command.REASON_TEAM_FIGHT_REWARD, v.drops, v.heros)
				Notify(Command.NOTIFY_FIGHT_REWARD, pid, {Command.FIGHT_REWARD_TYPE_TEAM_FIGHT_MONSTER_DIE, rewards})
			-- 记录获得组队副本奖励信息
			TeamRewardManger.AddReward(pid, 2, rewards, 2)
		end

		-- send npc extra roll
		for pid, v in pairs(self.npc_extra_roll or {}) do
			for _, v2 in ipairs(v) do
				self:AddPlayerNpcReward(pid, v2.fight_id, v2.npc_id, v2.fight_time, v2.drops, v2.heros)
			end
		end
	end

	self.roll_game = self.roll_game or {}
	
	local fight_cfg = BattleConfig.Get(fight_id)
	print("fight %d winner %d", fight_id, winner)
	if winner == 1 and fight_cfg and fight_cfg.public_drop ~= 0 then
		local drops = {{id = fight_cfg.public_drop, level = self:GetTeamAverageLevel()}}
		local success, err, rewards = GetDropReward(drops, 0)
		print("drop reward >>>>> ", fight_cfg.public_drop, tostring(success), sprinttb(rewards))
		if success and #rewards > 0 then
			local final_rewards = self:FilterRewards(rewards, fight_id)
			if #final_rewards > 0 then
				local game, game_id = RollGame.New(self.team, final_rewards, members_heros, fight_id)--, {type = 41, id = 90007, value = 2000}})
			end	
			--self.roll_game[game_id] = game
		end
	else
		log.debug(string.format("fight %d donnt has public drop or lose fight", fight_id))
	end

	--quest
	--[[local battle_cfg = BattleConfig.GetBattleConfig(fight_cfg.battle_id)
	if winner == 1 and battle_cfg then
		for k, v in ipairs(self.team.members) do
			cell.NotifyQuestEvent(v.pid, {{type = 58, id = fight_cfg.battle_id, count = 1}})	
		end
	end--]]
	if winner == 1 then
		for k, v in ipairs(self.team.members) do
			cell.NotifyQuestEvent(v.pid, {{type = 88, id = fight_id, count = 1}})
			if fight_cfg then
				NotifyQuestEventByStr(v.pid, 89, fight_cfg.key_value)
			end
		end
    	end

	-- 组队活动活动胜利以后，增加成员之间的好感度
	SocialManager.AddMembersFavor(self.team.members, 1, 2)

	--不能用team的快照，因为有可能AI在战斗中才加入队伍
	local team = getTeam(self.team.id)
	if team then
		local AI_members = team:GetAIMembers()
		for _, id  in ipairs(AI_members or {}) do
			SocialManager.NotifyAITeamFightFinish(id, winner, fight_id)
		end
	end
		
	-- 副本通关公告.......................
	local battle_cfg = BattleConfig.GetBattleConfig(fight_cfg.gid_id)
	if battle_cfg then
		if loop.now() - StableTime.get_begin_time_of_day(StableTime.get_open_server_time()) > battle_cfg.day * ONE_DAY_SEC then  -- 开始打副本起始时间
			return
		end

		if winner == 1 and fight_id == battle_cfg.final_fight then
			local player_pids = {}
			for k, v in ipairs(self.team.members) do
				table.insert(player_pids,v.pid)
			end
	
			NetService.NotifyClients(Command.NOTIFY_DISPLAY_MESSAGE, { 3,player_pids , fight_cfg.gid_id })
		end
	end
end

function TeamFightAward:GetTeamAverageLevel()
	local sum_level = 0
	for k, v in ipairs(self.team.members) do
		local player = getPlayer(v.pid)
		if player then
			sum_level = sum_level + player.level	
		end
	end

	if #(self.team.members) > 0 then
		return sum_level / #(self.team.members)
	end
	
	return 1
end

function TeamFightAward:FilterRewards(rewards, fight_id)
	local final_rewards = {}

	if not rewards or #rewards == 0 then
		return final_rewards
	end

	assert(#self.team.members > 0)
	local drop_rate = 0 
	local add_drop_rate = math.ceil(100 / #self.team.members)
	for k, v in ipairs(self.team.members) do
		local player_team_fight = PlayerTeamFight.Get(v.pid)
		local roll_count = player_team_fight:GetRollCount(fight_id)

		local player = getPlayer(v.pid)
		if player then
			local fight_cfg = BattleConfig.Get(fight_id)
			if fight_cfg then
				local battle_cfg = BattleConfig.GetBattleConfig(fight_cfg.battle_id)
				if battle_cfg and  battle_cfg.limit_level then
					if roll_count and roll_count < 1 and player.level <= battle_cfg.limit_level + 40 then
						drop_rate = drop_rate + add_drop_rate	
					end
				end
			end
		end
	end

	if drop_rate <= 0 then
		log.debug(string.format("maybe all member has roll in this fight:%d this period, so final rewards is empty", fight_id))
		return final_rewards
	end

	for k, v in ipairs(rewards) do
		local rand = math.random(1, 100)
		if rand <= drop_rate then
			table.insert(final_rewards, {type = v.type, id = v.id, value = v.value})
		end
	end	

	return final_rewards
end

function TeamFightAward:OnKillMonster(pid, fight_id, fight_time, refid, npc_id, heros, npc_level, npc_pos, npc_wave)
	log.debug(string.format("team %d player %d kill npc refid:%d npc_id:%d in fight:%d, begin add npc reward", self.team.id, pid, refid, npc_id, fight_id))

	-- send npc drop reward
	local npc_cfg = NpcConfig.Get(fight_id, npc_wave, npc_pos)
	if not npc_cfg then
		log.debug("fail add npc drop reward, npc config is nil")
	else	
		if npc_cfg.drop1 ~= 0 or npc_cfg.drop2 ~= 0 or npc_cfg.drop3 ~= 0 then
			self.npc_drop_reward[pid] = self.npc_drop_reward[pid] or {drops = {}, heros = {}}
			self.npc_drop_reward[pid].heros = heros

			--local drops = {}
			for i = 1, 3, 1 do
				if npc_cfg["drop"..i] ~= 0 then
					--table.insert(drops, {id = npc_cfg[npc_id]["drop"..i], level = npc_level})	
					table.insert(self.npc_drop_reward[pid].drops, {id = npc_cfg["drop"..i], level = npc_level})
				end
			end

			--local success, err, rewards = SendDropReward(pid, nil, Command.REASON_TEAM_FIGHT_REWARD, drops, heros)
			--Notify(Command.NOTIFY_FIGHT_REWARD, pid, {Command.FIGHT_REWARD_TYPE_TEAM_FIGHT_MONSTER_DIE, rewards})

			-- add npc roll reward
			--self:AddPlayerNpcReward(pid, fight_id, npc_id, fight_time, drops, heros)
		else
			-- log.debug("fail add npc drop reward, npc donnt has drop ")
			--return
		end	
	end

	-- add npc roll reward
	local wave_cfg = NpcConfig.GetWaveConfig(fight_id, npc_wave, npc_pos)
	-- print("@@@@@@@@@@@@@@@@@@@@@@@@@", fight_id, npc_wave, npc_pos)
	-- print(wave_cfg.team_roll_drop1)
	if not wave_cfg then
		log.debug("fail add npc roll reward, wave cfg is nil")
	else
		if wave_cfg.team_roll_drop1 ~= 0 or wave_cfg.team_roll_drop2 ~= 0 or wave_cfg.team_roll_drop3 ~= 0 then
			self.npc_extra_roll[pid] = self.npc_extra_roll[pid] or {}
	
			local drops = {}
			for i = 1, 3, 1 do
				if wave_cfg["team_roll_drop"..i] ~= 0 then
					-- print("############################", wave_cfg["team_roll_drop"..i])
					table.insert(drops, {id = wave_cfg["team_roll_drop"..i], level = npc_level})	
				end
			end
	
			-- log.debug(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>", sprinttb(drops))
			table.insert(self.npc_extra_roll[pid], {fight_id = fight_id, npc_id = npc_id, fight_time = fight_time, drops = drops, heros = heros})
		else
			-- log.debug("fail add npc roll reward, npc donnt has roll reward")
		end
	end
end

-- private function 
function TeamFightAward:SendFightReward(winner, fight_id, fight_time, members_heros)
	log.debug(string.format("team %d begin to send fight reward", self.team.id))

	if winner ~= 1 then
		log.debug("send fight reward fail, team lose")
		return
	end

	local fight_cfg = BattleConfig.Get(fight_id)
	if not fight_cfg then
		log.debug("fail send fight reward, fight config is nil")
		return 
	end	

	local drops = {} 
	for i = 1, 3, 1 do
		if fight_cfg["drop"..i] ~= 0 then
			table.insert(drops, fight_cfg["drop"..i])
		end
	end

	if #drops == 0 then
		log.debug(string.format("fight:%d donot has drop reward", fight_id))
		return
	end

	for k, v in ipairs(self.team.members) do
		if v.pid then
			local player_team_fight = getPlayerTeamFight(v.pid)	
			local pick_count = player_team_fight:GetWinCount(fight_id, fight_time)	
			local pick_limit = fight_cfg.pick_limit 

			if pick_count >= pick_limit then
				log.debug(string.format("fail send fight reward, player:%d pick count already reach max", v.pid))
				return 
			else
				log.debug(string.format("send fight reward to player:%d drop1:%d drop2:%d drop3:%d, heros:%s", v.pid, drops[1] and drops[1] or 0, drops[2] and drops[2] or 0, drops[3] and drops[3] or 0, sprinttb(members_heros[v.pid])))
				local success, err, rewards = SendDropReward(v.pid, nil, Command.REASON_TEAM_FIGHT_REWARD, drops, members_heros[v.pid] and members_heros[v.pid])
				if not success then
					log.debug(string.format("send fight reward to player:%d fail erro:%d", v.pid, err))
					return
				end
				
				if #rewards > 0 then
					Notify(Command.NOTIFY_FIGHT_REWARD, v.pid, {Command.FIGHT_REWARD_TYPE_TEAM_FIGHT_WIN, rewards})
				end
				Notify(Command.NOTIFY_TEAM_FIGHT_REWARD_GET, v.pid, {rewards})

				-- 记录获得组队副本奖励信息
				TeamRewardManger.AddReward(v.pid, 2, rewards, 2)
			end
			--player_team_fight:UpdateWinCount(fight_id, pick_count + 1, fight_time)
		end
	end	

	return
end

function TeamFightAward:UpdatePlayerTeamFightWinCount(winner, fight_id, fight_time)
	log.debug(string.format("team %d begin to update player_team_fight win_count", self.team.id))
	if winner ~= 1 then
		log.debug("update player_team_fight fail, team lose")
		return
	end

	local fight_cfg = BattleConfig.Get(fight_id)
	for k, v in ipairs(self.team.members) do
		if v.pid then
			local player_team_fight = getPlayerTeamFight(v.pid)	
			local win_count = player_team_fight:GetWinCount(fight_id, fight_time)	
			local player_team_fight = getPlayerTeamFight(v.pid)	

			player_team_fight:UpdateWinCount(fight_id, win_count + 1, fight_time)
			local battle_cfg = BattleConfig.GetBattleConfig(fight_cfg.battle_id)
			if battle_cfg and win_count < 1 then
				cell.NotifyQuestEvent(v.pid, {{type = 58, id = fight_cfg.battle_id, count = 1}})	
			end
		end
	end	
end

function TeamFightAward:UpdateTeamProgress(winner, fight_id, fight_time)
	if self.team.id < 0 then return; end

	--update fight progress
	log.debug(string.format("team %d begin to update fight progress for fight:%d",self.team.id, fight_id))
	local team_progress_manager = getTeamProgressManager(self.team.id)
	local star, today_count = team_progress_manager:GetTeamProgress(fight_id, fight_time)

	if star and today_count then
		team_progress_manager:UpdateTeamProgress(fight_id, winner == 1 and 1 or 0, today_count + 1, winner == 1 and 1 or 0, fight_time)
	else
		log.debug(string.format("update team %d progress fail, cannot get progress", self.team.id))
	end	
end

function TeamFightAward:AddPlayerNpcReward(pid, fight_id, npc_id, fight_time, drops, heros)
	local player_npc_reward_pool = getPlayerNpcRewardPool(pid)
	local gid = player_npc_reward_pool:AddReward(fight_id, npc_id, fight_time, loop.now() + NPC_REWARD_VALID_TIME, drops[1] and drops[1] or {id = 0, level = 0}, drops[2] and drops[2] or {id = 0 , level = 0}, drops[3] and drops[3] or {id = 0, level = 0}, heros)
	Notify(Command.NOTIFY_TEAM_NPC_REWARD_DROP, pid, {gid, fight_id, npc_id, loop.now() + NPC_REWARD_VALID_TIME})
end

function TeamFightAward:OnVMFinished()
	self.team:StopVM();
end

local function checkLimit(battle_id, pid)
	local player = getPlayer(pid)
	if not player then
		log.debug(string.format(" checkLimit fail , player:%d not exist", pid))
		return false
	end

	local battle_cfg = BattleConfig.GetBattleConfig(battle_id)
	if not battle_cfg then
		log.debug(string.format(" checkLimit fail , cannt get battle_cfg for battle:%d", battle_id))
		return false
	end	
	
	if not battle_cfg.limit_level then
		log.debug(string.format(" checkLimit fail , level limit for battle:%d not exist", battle_id))
		return true 
	end
	return player.level >= battle_cfg.limit_level 
end

TeamProxy.RegisterObserver({
	OnTeamDissolve = function(_, team_id)
		deleteTeamProgress(team_id);
	end
})

local function HasPlayerInRollGame(members)
	for k, v in ipairs(members) do
		local games = getPlayerGame(v.pid)
		if games and next(games) then
			print(string.format("Player %d in roll game %s >>>>>>>>>>>>>>>>>>", v.pid))
			return true
		end	
	end	
	return false
end

local TeamFightActivity = {}
function TeamFightActivity.StartFight(opt_pid, fight_id, fight_level)
	log.debug(string.format('Player %d start team fight %d, level %d', opt_pid, fight_id, fight_level or 0));
	
	local team = getTeamByPlayer(opt_pid, true)
	if not team then
		log.debug("player not has team")
		return false
	end

	if team.leader.pid ~= opt_pid then
		log.debug('  player not leader', team.leader.pid, opt_pid);
		return false;
	end
	
	if team.vm then
		log.debug(' already in a vm')
		return false
	end
	
	for _, v in ipairs(team.members) do
		v.ready = 0--false;
		team:Notify(Command.NOTIFY_TEAM_INPLACE_READY, {pid, 0});
	end

	local fight_cfg = BattleConfig.Get(fight_id)

	if not fight_cfg then
		log.debug(string.format("start fight fail, cannt get fight config for fight:%d", fight_id))
		return false
	end

	--for k, v in ipairs(team.members) do
	local mems = team:GetMemsNotAFK()
	for _, pid in ipairs(mems) do
		if not checkLimit(fight_cfg.battle_id, pid) then
			log.debug(string.format("player %d level not enough", pid))
			return false
		end
	end

	if not BattleConfig.CheckBattleOnTime(fight_cfg.battle_id, loop.now()) then
		log.debug(string.format("start fight fail, not on time for fight:%d", fight_id))
		return false
	end

	local battle_cfg = BattleConfig.GetBattleConfig(fight_cfg.battle_id)
	if not battle_cfg then
		log.debug(string.format('start fight fail, battle_cfg is nil'))
		return false
	end

	if #team.members < battle_cfg.team_member then
		log.debug(string.format('start fight fail, team member not enough'))
		return false
	end

	local team_progress_manager = nil;
	if team.id > 0 then
		team_progress_manager = getTeamProgressManager(team.id)
		if not team_progress_manager:CheckDependFightFinish(fight_id) then
			log.debug(string.format("start fight fail, depend fight not finish"))
			return false
		end
	end

	if HasPlayerInRollGame(team.members) then
		log.debug(string.format("start fight fail, someone in a roll game"))
		return false
	end

	local time_control = TeamFightActivityTimeControl.Get(team.id)
	if not time_control then
		log.debug(string.format("start fight fail, cannt get battle time control"))
		return false
	end

	local begin_time, end_time = time_control:GetTime(fight_cfg.battle_id)
	if end_time > 0 and loop.now() > end_time then
		log.debug(string.format("start fight fail, battle close"))
		return false	
	end

	--[[local pids = {}
	for _, v in ipairs(team.members) do
		table.insert(pids, v.pid);
	end--]]
	local pids = team:GetMemsNotAFK()
	print("pids >>>>>>>>>>>>>>>", sprinttb(pids))


	if fight_level and fight_level <= 0 then
		fight_level = nil
	end

	local vm = TeamFightVM.New(pids, TeamFightAward.New(team), fight_id, {level = fight_level});

	if team.id > 0 then
		local team_buff = team_progress_manager:GetTeamBuff(fight_id) 
		if team_buff then
			vm:AddBuff(team_buff)
		end
	end

	if not team:StartVM(vm) then
		log.debug("start TeamFightVM fail")
		return false
	end

	team.team_status = 1
	team:Notify(Command.NOTIFY_TEAM_STATUS_CHANGE, {team.team_status});

	local AI_members = team:GetAIMembers()
	for _, id  in ipairs(AI_members or {}) do
		SocialManager.NotifyAITeamFightStart(id)
	end

	return true
end



function TeamFightActivity.FindNpc(opt_pid, ...)
	log.debug(string.format('player %d find npc %d', opt_pid, ...));
	
	local team = getTeamByPlayer(opt_pid)	 
	if not team then
		log.debug("player not has team")
		return false
	end

	if team.leader.pid ~= opt_pid then
		log.debug('  player not leader');
		return false;
	end
	
	if team.vm then
		log.debug(' already in a vm')
		return false
	end
	
	--[[for _, v in ipairs(team.members) do
		v.ready = 0--false;
		team:Notify(Command.NOTIFY_TEAM_INPLACE_READY, {pid, 0});
	end--]]

	local team_progress_manager = getTeamProgressManager(team.id)
	local fight_id = select(1, ...)
	local fight_cfg = BattleConfig.Get(fight_id)

	if not fight_cfg then
		log.debug(string.format("find npc fail, cannt get fight config for fight:%d", fight_id))
		return false
	end

	--for k, v in ipairs(team.members) do
	local mems = team:GetMemsNotAFK()
	for _, pid in ipairs(mems) do
		if not checkLimit(fight_cfg.battle_id, pid) then
			log.debug(string.format("player %d level not enough", v.pid))
			return false
		end
	end

	if not BattleConfig.CheckBattleOnTime(fight_cfg.battle_id, loop.now()) then
		log.debug(string.format("find npc fail, not on time for fight:%d", fight_id))
		return false
	end

	if not team_progress_manager:CheckDependFightFinish(fight_id) then
		log.debug(string.format("find npc fail, depend fight not finish"))
		return false
	end

	if fight_cfg.is_fight_npc ~= 0 then
		log.debug("fight is not a npc")
		return false
	end

	local time_control = TeamFightActivityTimeControl.Get(team.id)
	if not time_control then
		log.debug(string.format("find npc fail, cannt get battle time control"))
		return false
	end

	local begin_time, end_time = time_control:GetTime(fight_cfg.battle_id)
	if end_time > 0 and loop.now() > end_time then
		log.debug(string.format("find npc, battle close"))
		return false	
	end

	--update team progress
	local team_progress_manager = getTeamProgressManager(team.id)
	local star, today_count = team_progress_manager:GetTeamProgress(fight_id, loop.now())

	if star and today_count then
		team_progress_manager:UpdateTeamProgress(fight_id, 1, today_count + 1, 1, loop.now())
	else
		log.debug(string.format("update team %d progress fail, cannot get progress", team.id))
		return false
	end

	for k, v in ipairs(team.members) do
		if v.pid then
			local player_team_fight = getPlayerTeamFight(v.pid)	
			local win_count = player_team_fight:GetWinCount(fight_id, loop.now())	
			local player_team_fight = getPlayerTeamFight(v.pid)	
			player_team_fight:UpdateWinCount(fight_id, win_count + 1, loop.now())
			local battle_cfg = BattleConfig.GetBattleConfig(fight_cfg.battle_id)
			if battle_cfg and win_count < 1 then
				cell.NotifyQuestEvent(v.pid, {{type = 58, id = fight_cfg.battle_id, count = 1}})	
			end
			
			if fight_cfg then
				NotifyQuestEventByStr(v.pid, 89, fight_cfg.key_value)
			end
		end
	end

	team:Notify(Command.NOTIFY_TEAM_FIND_NPC, {fight_id})
	local AI_members = team:GetAIMembers()
	for _, id  in ipairs(AI_members or {}) do
		SocialManager.NotifyAITeamFightFinish(id, 1, fight_id)
	end

	--[[local battle_cfg = BattleConfig.GetBattleConfig(fight_cfg.battle_id)
	if battle_cfg then
		for k, v in ipairs(team.members) do
			cell.NotifyQuestEvent(v.pid, {{type = 58, id = fight_cfg.battle_id, count = 1}})	
		end
	end--]]
	

	--self:UpdatePlayerTeamFightWinCount(1, fight_id, loop.now())
	--self:UpdateTeamProgress(1, fight_id, loop.now())

	return true
end

function TeamFightActivity.registerCommand(service)
	service:on(Command.C_TEAM_START_FIGHT_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local fight_id = request[2]
		
		local ret = TeamFightActivity.StartFight(pid, fight_id)

		return conn:sendClientRespond(Command.C_TEAM_START_FIGHT_RESPOND, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR});
	end);

	service:on(Command.S_TEAM_START_ACTIVITY_FIGHT_REQUEST, "TeamStartActivityFightRequest", function(conn, channel, request) 
		local cmd = Command.S_TEAM_START_ACTIVITY_FIGHT_RESPOND;
		local proto = "aGameRespond";

		if channel ~= 0 then
			log.error(id .. "Fail to `S_TEAM_START_ACTIVITY_FIGHT_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local fight_id = request.fight_id
		local fight_level = request.fight_level;
		
		local ret = TeamFightActivity.StartFight(pid, fight_id, fight_level)

		if ret then
			AI_DEBUG_LOG("Success ai start fight")
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
		else
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

	end)

	service:on(Command.C_TEAM_FIND_NPC_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local fight_id = request[2]
		
		local ret = TeamFightActivity.FindNpc(pid, fight_id)

		return conn:sendClientRespond(Command.C_TEAM_FIND_NPC_RESPOND, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR});
	end);

	service:on(Command.S_TEAM_FIND_NPC_REQUEST, "TeamFindNpcRequest", function(conn, channel, request) 
		local cmd = Command.S_TEAM_FIND_NPC_RESPOND;
		local proto = "aGameRespond";

		if channel ~= 0 then
			log.error(id .. "Fail to `S_TEAM_FIND_NPC_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local fight_id = request.fight_id
		
		local ret = TeamFightActivity.FindNpc(pid, fight_id)

		if ret then
			AI_DEBUG_LOG("Success ai find npc")
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS});
		else
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

	end)

	service:on(Command.C_TEAM_QUERY_TEAM_PROGRESS_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local teamid = request[2]
		local fights = request[3]
	
		if not fights or not teamid then
			log.debug("fail to query team progress, param teamid or fights is nil")
			return conn:sendClientRespond(Command.C_TEAM_QUERY_TEAM_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		if type(fights) ~= "table" then
			log.debug("fail to query team progress, param fights is not table")
			return conn:sendClientRespond(Command.C_TEAM_QUERY_TEAM_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
		end
		
		log.debug(string.format("Player %d begin to query team progress for teamid:%d ", pid, teamid))

		local team = getTeam(teamid)
		if not team then
			log.debug("fail to query team progress , team not exist")
			return conn:sendClientRespond(Command.C_TEAM_QUERY_TEAM_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local team_progress = TeamProgress.Get(teamid)
	
		if not team_progress then
			return conn:sendClientRespond(Command.C_TEAM_QUERY_TEAM_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local amf_ret = {}
		for _, fight_id in ipairs(fights) do
			local progress = team_progress:GetTeamProgress(fight_id)
			if progress then
				table.insert(amf_ret, {fight_id, progress})
			end
		end

		return conn:sendClientRespond(Command.C_TEAM_QUERY_TEAM_PROGRESS_RESPOND, pid, {sn, Command.RET_SUCCESS, amf_ret});
	end);

	service:on(Command.S_TEAM_GET_TEAM_PROGRESS_REQUEST, "TeamGetTeamProgressRequest", function(conn, channel, request) 
		local cmd = Command.S_TEAM_GET_TEAM_PROGRESS_RESPOND;
		local proto = "TeamGetTeamProgressRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_TEAM_GET_TEAM_PROGRESS_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local teamid = request.teamid
		local fights = request.fights

		local team = getTeam(teamid)
		if not team then
			log.debug("fail to ai query team progress , team not exist")
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

		local team_progress = TeamProgress.Get(teamid)
	
		if not team_progress then
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

		local pro = {}
		for _, fight_id in ipairs(fights) do
			local progress = team_progress:GetTeamProgress(fight_id)
			if progress then
				table.insert(pro, {fight_id = fight_id, progress = progress})
			end
		end

		AI_DEBUG_LOG("Success ai get team progress")
		return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS, progress = pro});
	end)

	service:on(Command.C_TEAM_RESET_TEAM_PROGRESS_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local teamid = request[2]
		--local fights = request[3]
		local battle_id = request[3]
	
		if not battle_id or not teamid then
			log.debug("fail to reset team progress, param teamid or battle_id is nil")
			return conn:sendClientRespond(Command.C_TEAM_RESET_TEAM_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		log.debug(string.format("Player %d begin to reset team progress for teamid:%d battle:%d", pid, teamid, battle_id))

		local team = getTeam(teamid)
		if not team then
			log.debug("fail to reset team progress , team not exist")
			return conn:sendClientRespond(Command.C_TEAM_RESET_TEAM_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local team_progress = TeamProgress.Get(teamid)
	
		if not team_progress then
			return conn:sendClientRespond(Command.C_TEAM_RESET_TEAM_PROGRESS_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local fights = BattleConfig.GetBattleFights(battle_id)
		for fight_id, v in pairs(fights) do
			team_progress:ResetTeamProgress(fight_id)
		end

		TeamFightActivityTimeControl.OnResetTeamProgress(team.id, battle_id)

		return conn:sendClientRespond(Command.C_TEAM_RESET_TEAM_PROGRESS_RESPOND, pid, {sn, Command.RET_SUCCESS});
	end);
end

return TeamFightActivity
