package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";


require "database"
require "log"
require "Command"
require "Agent"
require "cell"

local TeamProxy = require "TeamProxy"
local TeamFightVM = require "TeamFightVM"
local BattleConfig = require "BattleConfig"
local TeamRewardManger = require "TeamReward"
local SocialManager = require "SocialManager"

local BOUNTY_MIN_TEAM_MEMBER_COUNT = 1
local BOUNTY_NORMAL_COUNT = 100
local BOUNTY_DOUBLE_COUNT = 20
local BOUNTY_ROUND_COUNT = 10

--------------------------------------------------------------------------------
-- config

local BinaryConfig = require "BinaryConfig"

local quest_config = {}
local function load_quest_config()
	local rows = BinaryConfig.Load("config_bounty_quest", "bounty")	

	quest_config.list = {}
	if rows then
		for _, row in ipairs(rows) do
			quest_config.list[row.activity_id] = quest_config.list[row.activity_id] or { weight = 0 }
			quest_config.list[row.activity_id].active = quest_config.list[row.activity_id].active or {}
			local t = {
				id     = row.quest_id,
				weight = row.weight,
				count  = row.times,
				begin_time = row.begin_time,
				end_time = row.end_time,
				theme = row.theme or 0,
			}
			table.insert(quest_config.list[row.activity_id].active, t)
			quest_config.list[row.activity_id].weight = quest_config.list[row.activity_id].weight + row.weight
			quest_config.list[row.activity_id].max_theme_type  = quest_config.list[row.activity_id].max_theme_type or 0
			if row.theme > quest_config.list[row.activity_id].max_theme_type then
				quest_config.list[row.activity_id].max_theme_type = row.theme;
			end
		end
	end
end

local function get_quest_config(activity_id)
	return quest_config.list[activity_id]
end

local function get_active_id_list()
	local ret = {}

	for id, _ in pairs(quest_config.list) do
		table.insert(ret, id)
	end

	return ret
end

------------------------------------------------------------------------------------
local fight_config = {}
local function load_fight_config()
	local rows = BinaryConfig.Load("bounty_fight", "bounty")
	fight_config.list = {}

	for _, row in ipairs(rows or {}) do
		fight_config.list[row.quest_id] = fight_config.list[row.quest_id] or { weight = 0 }
		fight_config.list[row.quest_id].fight = fight_config.list[row.quest_id].fight or {}

		local t = {
			id          = row.fight_id,
			type        = row.fight_type,
			reward_type = row.reward_type,	
			weight = row.weight,
			order = row.order,
		}	
		table.insert(fight_config.list[row.quest_id].fight, t)
		fight_config.list[row.quest_id].weight = fight_config.list[row.quest_id].weight + row.weight		
	end
end

local function get_fight(quest_id)
	return fight_config.list[quest_id]
end

--------------------------------------------------------------------------------------
local reward_config = nil
local function load_reward_config()
	local rows = BinaryConfig.Load("bounty_reward", "bounty")	
	reward_config = {}
	for _, row in ipairs(rows or {}) do
		local type = row.fight_type

		reward_config[type] = reward_config[type] or {}
		table.insert(reward_config[type], {
			level = {min = row.min_lev, max = row.max_lev },
			captain = { double_drop_id = row.double_captain, drop_id = row.normal_captain, round_drop_id = extra_captain},
			members = { double_drop_id = row.double,         drop_id = row.normal,         round_drop_id = extra_normal },
		})
	end
end

local function LoadConfig()
	load_quest_config()
	load_fight_config()
	load_reward_config()
end

LoadConfig()

-- 玩家等级
local PlayerLevelMap = {}
local function IsLevel(pid, limit)
	assert(pid)
	assert(limit)
	PlayerLevelMap[pid] = PlayerLevelMap[pid] or {}
	if PlayerLevelMap[pid].lv == nil or PlayerLevelMap[pid].lv < limit then
		local info = cell.getPlayerInfo(pid)
		PlayerLevelMap[pid].lv = info.level or 0
	end

	if PlayerLevelMap[pid].lv < limit then
		return false
	end	
	return true
end

--------------------------------------------------------------------------------
local START_TIME = 1467302400
local PERIOD_TIME = 3600 * 24

local function ROUND(t)
	return math.floor((t-START_TIME)/PERIOD_TIME);
end

local function update_player_data(player)
	if ROUND(player.update_time) ~= ROUND(loop.now()) then
		player.normal_count = 0;
		player.double_count = 0;
		player.update_time = loop.now();
	end
	return player;
end

local player_data = {}
local function getPlayerData(pid)
	if player_data[pid] == nil then
		local ok, results = database.query("select active, normal_count, double_count, unix_timestamp(update_time) as update_time from bounty_player where pid = %d", pid);
		if ok then	
			player_data[pid] = {}
			for i, v in ipairs(results) do
				local t = {
					pid = pid,
					active = v.active,
					normal_count = v.normal_count,
					double_count = v.double_count,
					update_time  = v.update_time,
				}
								
				local player = update_player_data(t);
				local info = cell.getPlayerInfo(pid);
				player.level = info and info.level or 0
	
				player_data[pid][v.active] = player
			end
		end
	end	

	return player_data[pid];
end

local function getPlayerData2(pid, activity_id)
	local datas = getPlayerData(pid)
	if datas == nil or datas[activity_id] == nil then	
		player_data[pid] = player_data[pid] or {}
		local t = {
			pid = pid,
			active = activity_id,
			normal_count = 0,
			double_count = 0,
			update_time  = loop.now(),
			is_not_db = true,
		}	
		
		local player = update_player_data(t);
		local info = cell.getPlayerInfo(pid);
		player.level = info and info.level or 0
	
		player_data[pid][activity_id] = player	
	end

	return player_data[pid][activity_id]
end

local function update_count(pid, active, normal_count, double_count)
	assert(pid)
	assert(active)
	assert(normal_count)
	assert(double_count)
	local player = getPlayerData2(pid, active)
	if player.is_not_db then
		local ok = database.update("insert into bounty_player (pid, active, normal_count, double_count, update_time) values (%d, %d, %d, %d, from_unixtime_s(%d));", 
				pid, active, normal_count, double_count, loop.now())

		if ok then
			player.is_not_db = false
			player.normal_count = normal_count
			player.double_count = double_count
			player.update_time = loop.now()
		end
	else
			
		local ok = database.update("update bounty_player set normal_count = %d, double_count = %d, update_time = from_unixtime_s(%d) where pid = %d and active = %d;", 
			normal_count, double_count, loop.now(), pid, active)
		if ok then
			player.normal_count = normal_count
			player.double_count = double_count
			player.update_time  = loop.now()
		end
	end
	
	local agent = Agent.Get(player.pid);
	if agent then
		agent:Notify({Command.NOTIFY_BOUNTY_PLAYER_CHANGE, { player.normal_count, player.double_count, player.active } });
	end
end

--------------------------------------------------------
local team_data = {}

local function getTeamData(id)
	if team_data[id] == nil then
		local ok, results = database.query("select active, quest, record from bounty_team where id = %d;", id)	
		if ok then
			team_data[id] = {}
			for i, v in ipairs(results) do
				team_data[id][v.active] = { quest = v.quest, record = v.record, next_fight_time = loop.now(), fight_id = 0, fight_type = 0 }
			end
		end
	end
	return team_data[id]
end

local function getTeamData2(id, activity_id)
	local data = getTeamData(id)
	if not data or not team_data[id][activity_id] then
		team_data[id] = team_data[id] or {}
		team_data[id][activity_id] = { quest = 0, record = 0, next_fight_time = loop.now(), fight_id = 0, fight_type = 0, is_not_db = true }
	end

	return team_data[id][activity_id]	
end

local function getInfoByFightId(team_id, activity_id, fight_id)
	assert(team_id)
	assert(activity_id)
	assert(fight_id)

	local data = getTeamData2(team_id, activity_id)
	if data.fight_id == fight_id then
		return data
	end
	return nil
end

local function add_team_data(id, activity_id, data)
	assert(id)
	assert(activity_id)
	assert(data)

	local ok = database.update("insert into bounty_team(id, active, quest, record) values(%d, %d, %d, %d);",
		id, activity_id, data.quest, 0)
	if ok then
		data.is_not_db = false
	end
end

local function remove_team_data(id, activity_id)
	assert(id)
	assert(activity_id)

	local data = getTeamData2(id, activity_id)
	if not data.is_not_db then
		local ok = database.update("delete from bounty_team where id = %d and active = %d;", id, activity_id)
		if ok then
			team_data[id][activity_id] = nil
		end
	else
		team_data[id][activity_id] = nil
	end
end

local function update_quest_count(id, activity_id, n)	
	assert(id)
	assert(activity_id)
	assert(n)
	
	local data = getTeamData2(id, activity_id)
	if data.is_not_db then
		local ok = database.update("insert into bounty_team(id, active, quest, record) values(%d, %d, %d, %d);",
				id, activity_id, data.quest, n)
		if ok then
			data.is_not_db = false
			data.record = n
		end	
	else
		local ok = database.update("update bounty_team set record = %d where id = %d and active = %d;", n, id, activity_id)
		if ok then
			data.record = n
		end
	end
end

local function delete_team(id)
	if team_data[id] and next(team_data[id]) then
		local ok = database.update('delete from bounty_team where id = %d', id);
		if ok then
			team_data[id] = nil
		end
	end
end

--------------------------------------------------------------------------------
local function calc_total_weight(items)
	local w = 0;
	for _, v in pairs(items) do
		w = w + v.weight;
	end
	return w;
end

local function random_by_weight(items, total_weight)
	total_weight = total_weight or calc_total_weight(items);

	if total_weight == 0 then
		return nil
	end

	local value = math.random(1, total_weight);
	for k, v in pairs(items) do
		if v.weight >= value then
			return v
		end

		value = value - v.weight
	end
end

local WELLRNG512a_ = require "WELLRNG512a"
local function random_range(rng, min, max)
	assert(min <= max)
	local v  = WELLRNG512a_.value(rng);
	return min + (v % (max - min + 1))
end

-- 从活动id上随机一个任务，返回id
local function random_quest(id)
	local list = get_quest_config(id) or {}
	local list2, weight = {}, 0

	local theme = 0;
	if list.max_theme_type > 0 then
		theme = random_range(WELLRNG512a_.new(id + ROUND(loop.now())), 1, list.max_theme_type);
	end

	for _, v in ipairs(list.active or {}) do
		if loop.now() >= v.begin_time and loop.now() <= v.end_time then
			if v.type == 0 or v.theme == theme then
				table.insert(list2, v) 
				weight = weight + v.weight
			end
		end
	end

	if #list2 > 0 then
		local v = random_by_weight(list2, weight)
		return v.id or 0
	else
		log.warning(string.format("random_quest: active id %d config is nil, theme %d.", id, theme))
		return 0
	end

end

-- 从任务id上随机一个战斗，返回战斗id
local function random_fight(id, order)
	assert(id)
	local temp = get_fight(id)
	if temp then
		local fights, wieght = {}
		for _, v in ipairs(temp.fight) do
			if v.order == 0 or v.order == order then
				table.insert(fights, v) 
			end
		end

		local v = random_by_weight(fights, weight);
		return v.id or 0, v.type or 0, v.reward_type
	else
		log.warning(string.format("random_fight: quest %d fight config is nil, order %d.", id, order))
		return 0, 0, 0
	end
end

local function doReward(player, fight_type, captain, heros, reward_level)
	local list = reward_config[fight_type]
	if not list then
		log.warning(string.format('do_reward config of type %d not exist', fight_type));
		return;
	end

	local reward = nil;
	for _, v in ipairs(list) do
		if player.level >= v.level.min and player.level <= v.level.max then
			reward = v;
			break;
		end
	end

	if not reward then
		log.debug(string.format("doReward: reward is nil, pid = %d, level = %d, fight_type = %d", player.pid, player.level, fight_type))
		return;
	end

	reward = captain and reward.captain or reward.members;

	local drops = { }

	local double_count, normal_count = player.double_count, player.normal_count;

	local reward_type = 0;
	if player.double_count < BOUNTY_DOUBLE_COUNT then
		table.insert(drops, {id=reward.double_drop_id, level=reward_level})
		double_count = player.double_count + 1;
		reward_type = 2;
	elseif player.normal_count < BOUNTY_NORMAL_COUNT then
		table.insert(drops, {id=reward.drop_id, level=reward_level})
		normal_count = player.normal_count + 1;
		reward_type = 1;
	end

	if (player.normal_count + player.double_count) % BOUNTY_ROUND_COUNT == 0 then
		table.insert(drops, {id=reward.round_drop_id, level = reward_level});
	end

	local rewards = {}
	if #drops > 0 then
		local respond = cell.sendReward(player.pid, nil,  nil,     reason, false,   0,   '',   drops, heros);
		-- cell.sendReward(playerid, reward, consume, reason, manual, limit, name, drops, heros, first_time, send_reward)
		rewards = respond.rewards;
		update_count(player.pid, player.active, normal_count, double_count)
	end

	if captain and reward_type > 0 then
		reward_type = reward_type + 4;
	end

	return rewards, reward_type;
end

local function StartQuest(pid, activity_id)
	log.info(string.format('BOUNTY: player %d start quest', pid));
	
	-- 等级检测	
	local battle_cfg = BattleConfig.GetBattleConfig(activity_id)
	local limit = battle_cfg.limit_level or 0

	local team = getTeamByPlayer(pid);
	if team == nil then
		log.debug('StartQuest: team is nil');
		return Command.RET_ERROR;
	end

	if team.leader.pid ~= pid then
		log.debug(string.format('StartQuest: player %d is not leader(%d) of team', pid, team.leader.pid))
		return Command.RET_NOT_ENOUGH;
	end

	if #team.members < BOUNTY_MIN_TEAM_MEMBER_COUNT then
		log.debug(string.format(' StartQuest: team member not enough %d/%d', #team.members, BOUNTY_MIN_TEAM_MEMBER_COUNT));
		return Command.RET_NOT_ENOUGH;
	end
	
	for i, v in ipairs(team.members) do	
		if not IsLevel(v.pid, limit) then
			log.debug("StartQuest: level not enough, pid = ", v.pid)
			return Command.RET_PREMISSIONS  
		end
	end
	
	local questInfo = getTeamData2(team.id, activity_id)
	if questInfo.quest ~= 0 then	-- 此活动是否开启
		log.debug(string.format("StartQuest: team %d active %d is exist, queset %d.", team.id, activity_id, questInfo.quest))
		return Command.RET_ERROR
	end		

	local quest_id = random_quest(activity_id)	-- 通过活动id来随机一个任务id
	if quest_id == 0 then
		log.debug('StartQuest: generate random quest id failed');
		return Command.RET_ERROR;
	end

	log.info(string.format('BOUNTY: get quest %d', quest_id));
		
	local next_fight_time = loop.now() -- + 3 + math.random(1, 10);

	-- 给活动增加一个任务
	questInfo.quest = quest_id
	questInfo.next_fight_time = next_fight_time
	
	add_team_data(team.id, activity_id, questInfo)

	team:Notify(Command.NOTIFY_BOUNTY_TEAM_CHANGE, { quest_id, 0, next_fight_time, activity_id })

	local AI_members = team:GetAIMembers()
	for _, id  in ipairs(AI_members or {}) do
		SocialManager.NotifyAIBountyChange(id, quest_id, 0, next_fight_time, activity_id, false, -1)
	end

	return Command.RET_SUCCESS, questInfo;
end


local function CancelQuest(pid, activity_id)
	log.info(string.format('BOUNTY: player %d cancel active %d', pid, activity_id));
	local team = getTeamByPlayer(pid);
	if team == nil then
		log.debug('CancelQuest: team is nil.');
		return Command.RET_ERROR;
	end

	if team.leader.pid ~= pid then
		log.debug('CancelQuest: player %d is not leader(%d) of team', pid, team.leader.pid)
		return Command.RET_NOT_ENOUGH;
	end

	local questInfo = getTeamData2(team.id, activity_id)
	if questInfo.quest == 0 then
		log.debug(string.format('CancelQuest: get team quest info failed, team_id = %d, activity_id = %d', team.id, activity_id));
		return Command.RET_EXIST;
	end

	-- 删除活动任务
	remove_team_data(team.id, activity_id)

	team:Notify(Command.NOTIFY_BOUNTY_TEAM_CHANGE, {0, 0, 0, activity_id});

	local AI_members = team:GetAIMembers()
	for _, id  in ipairs(AI_members or {}) do
		SocialManager.NotifyAIBountyChange(id, 0, 0, 0, activity_id, false, -1)
	end

	return Command.RET_SUCCESS
end

TeamProxy.RegisterObserver({
	OnTeamDissolve = function(_, team_id)
		delete_team(team_id)
	end
})

local BountyRactor = {}
function BountyRactor.New(team, activity_id)
	return setmetatable({team = team:Snap(), activity_id = activity_id}, {__index = BountyRactor})
end

function BountyRactor:OnFightFinished(winner, fight_id, fight_time, members_heros)
	local activity_id = self.activity_id

	if winner == 1 then
		local questInfo = getInfoByFightId(self.team.id, activity_id, fight_id)
		if not questInfo then
			log.warning(string.format("OnFightFinished: quest info is nil, team_id, fight_id is %d, %d", self.team.id, fight_id))
			return
		end

		local player_reward_info = {}

		for k, v in ipairs(self.team.members) do
			local player = getPlayerData2(v.pid, activity_id)
			if player then
				local reward_level = self.monster_level;
				if questInfo.reward_type == 1 then
					reward_level = player.level;
				end

				local rewards, reward_type = doReward(player, questInfo.fight_type, v.pid == self.team.leader.pid, members_heros[v.pid], reward_level)
				--quest
				cell.NotifyQuestEvent(v.pid, {{type = 4, id = 35 + activity_id - 50, count = 1}})

				player_reward_info[v.pid] = { type = reward_type, rewards = {} }
				for _, r in ipairs(rewards) do
					-- print("-- Bounty reward --", v.pid, r.type, r.id, r.value);
					table.insert(player_reward_info[v.pid].rewards, {r.type,r.id,r.value});
				end

				-- 记录获得试炼奖励信息
				TeamRewardManger.AddReward(v.pid, 1, rewards, 1)
				cell.NotifyQuestEvent(v.pid, {{type = 85, id = questInfo.quest, count = 1}})
			end
		end

		local count = questInfo.record + 1;  -- 战斗完成次数
		local quest = questInfo.quest;
		local limit = 0			     -- 完成任务需要的次数
		local config = get_quest_config(activity_id)
		for i, v in ipairs(config.active or {}) do
			if v.id == questInfo.quest then
				limit = v.count 
				break
			end
		end 
		log.debug(string.format("team %d quest count update %d/%d", self.team.id, count, limit));
		
		local time = 0	
		if count >= limit then -- quest finished
			remove_team_data(self.team.id, activity_id)
			count = 0
			quest = 0;
		else
			update_quest_count(self.team.id, activity_id, count)
			time = loop.now() -- + 3 + math.random(1, 10)	
			questInfo.next_fight_time = time
		end

		for k, v in ipairs(self.team.members) do
			local rewards, type = {}, 0 
			if player_reward_info[v.pid] then
				rewards, type = player_reward_info[v.pid].rewards, player_reward_info[v.pid].type;
			end
			self.team:Notify(Command.NOTIFY_BOUNTY_TEAM_CHANGE, { quest, count, time, activity_id, rewards, type}, {v.pid})
		end

		local AI_members = self.team:GetAIMembers()
		local finish = false
		local next_fight_time = questInfo.next_fight_time
		if quest == 0 and count == 0 then
			finish = true
			next_fight_time = 0
		end
		for _, id  in ipairs(AI_members or {}) do
			SocialManager.NotifyAIBountyChange(id, quest, count, next_fight_time, activity_id, finish, winner)
		end
	
		-- 组队活动活动胜利以后，增加成员之间的好感度
		SocialManager.AddMembersFavor(self.team.members, 1, 2)
	end

	if winner ~= 1 then
		local questInfo = getInfoByFightId(self.team.id, activity_id, fight_id)
		if not questInfo then
			return
		end

		--fight fail also change next_fight_time
		questInfo.next_fight_time = loop.now() 
		for k, v in ipairs(self.team.members) do
			self.team:Notify(Command.NOTIFY_BOUNTY_TEAM_CHANGE, {questInfo.quest, questInfo.record, questInfo.next_fight_time, activity_id, {}, 0}, {v.pid})
		end

		local AI_members = self.team:GetAIMembers()
		for _, id  in ipairs(AI_members or {}) do
			SocialManager.NotifyAIBountyChange(id, questInfo.quest, questInfo.record, questInfo.next_fight_time, activity_id, false, 0)
		end
	end
end

function BountyRactor:OnVMFinished()
	self.team:StopVM();
end

local function BountyFight(pid, activity_id)
	log.info(string.format('BOUNTY: player %d start fight', pid));
	
	-- 等级检测	
	local battle_cfg = BattleConfig.GetBattleConfig(activity_id)
	local limit = battle_cfg.limit_level or 0
	local team = getTeamByPlayer(pid);
	if team == nil then
		log.debug('BountyFight: team is nil');
		return Command.RET_ERROR;
	end

	if team.leader.pid ~= pid then
		log.debug('BountyFight: player %d is not leader(%d) of team', pid, team.leader.pid)
		return Command.RET_NOT_ENOUGH;
	end

	if #team.members < BOUNTY_MIN_TEAM_MEMBER_COUNT then
		log.debug('BountyFight: team member not enough %d/%d', #team.members, BOUNTY_MIN_TEAM_MEMBER_COUNT);
		return Command.RET_NOT_ENOUGH;
	end

	for i, v in ipairs(team.members) do	
		if not IsLevel(v.pid, limit) then
			log.debug("BountyFight: level not enough, pid = ", v.pid)
			return Command.RET_PREMISSIONS  
		end
	end

	local questInfo = getTeamData2(team.id, activity_id);
	if questInfo.quest == 0 then
		log.debug("BountyFight: get team quest info failed, quest is 0, active id = ", activity_id)
		return Command.RET_NOT_EXIST;
	end


	if loop.now() < questInfo.next_fight_time then
		log.debug('BountyFight: fight time error');
		return Command.RET_ERROR;
	end

	local fight_id, fight_type, reward_type = random_fight(questInfo.quest, questInfo.record + 1)
	if fight_id == 0 or fight_type == 0 then
		log.debug(string.format('BountyFight: generate fight of quest %d failed', questInfo.quest));
		return Command.RET_ERROR;
	end

	log.info(string.format('  fight %d for order %d', fight_id, questInfo.record + 1));

	local reactor = BountyRactor.New(team, activity_id);

	local level_sum   = 0;

	local pids = {}
	for _, v in ipairs(team.members) do
		if not team:PlayerAFK(v.pid) then
			table.insert(pids, v.pid);
			local player = getPlayerData2(v.pid, activity_id)
			level_sum = level_sum + player.level;
		end
	end

	local level_percent = {50, 60, 70, 85, 100}
	local monster_level = math.floor(level_sum / #team.members * (level_percent[#team.members] or 100) / 100);

	reactor.monster_level = monster_level;

	local vm = TeamFightVM.New(pids, reactor, fight_id, {level = monster_level});

	if not team:StartVM(vm) then
		log.debug('BountyRactor: start fight failed');
		return Command.RET_ERROR;
	end

	questInfo.fight_id = fight_id;
	questInfo.fight_type = fight_type;
	questInfo.reward_type = reward_type;
	--questInfo.next_fight_time = loop.now() -- + 3 + math.random(1, 10);

	return Command.RET_SUCCESS, questInfo.next_fight_time;
end


--------------------------------------------------------------------------------
-- command
local function registerCommand(service)
	service:on(Command.C_BOUNTY_QUERY_REQUEST, function(conn, pid, data)
		log.info(string.format('BOUNTY: player %d query quest', pid));
		local sn = data[1];
		
		local team = getTeamByPlayer(pid)
		if not team then
			log.debug("query quest: team is nil, pid = ", pid)
			return conn:sendClientRespond(Command.C_BOUNTY_QUERY_RESPOND, pid, { sn, Command.RET_ERROR })
		end

		local questInfo = {}
		local datas = getTeamData(team.id)
		for activity_id, v in pairs(datas or {}) do
			table.insert(questInfo, { v.quest, v.record, v.next_fight_time, activity_id })	
		end	

		local activeInfo = {}
		local playerList = getPlayerData(pid)
		for i, v in pairs(playerList or {}) do
			table.insert(activeInfo, { v.normal_count, v.double_count, v.active })
		end

		return conn:sendClientRespond(Command.C_BOUNTY_QUERY_RESPOND, pid, { sn, Command.RET_SUCCESS, 
			questInfo, activeInfo } )
	end)

	service:on(Command.S_BOUNTY_QUERY_REQUEST, "BountyQueryRequest", function(conn, channel, request) 
		local cmd = Command.S_BOUNTY_QUERY_RESPOND;
		local proto = "BountyQueryRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_BOUNTY_QUERY_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local team = getTeamByPlayer(pid)
		if not team then
			log.debug("query quest: team is nil, pid = ", pid)
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR});
		end

		local questInfo = {}
		local datas = getTeamData(team.id)
		for activity_id, v in pairs(datas or {}) do
			table.insert(questInfo, { quest = v.quest, record = v.record, next_fight_time = v.next_fight_time, activity_id = activity_id })	
		end
	
		if datas then
			AI_DEBUG_LOG("Success ai query bounty")
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS, quest_info = questInfo});
		end
		
		return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR})
	end)

	service:on(Command.C_BOUNTY_START_REQUEST, function(conn, pid, data)
		local sn = data[1];
		
		local ret, questInfo = StartQuest(pid, data[2] or 1);

		questInfo = questInfo or {};

		return conn:sendClientRespond(Command.C_BOUNTY_START_RESPOND, pid, { sn, ret, questInfo and questInfo.quest or 0, questInfo and questInfo.record or 0, 
						questInfo and questInfo.next_fight_time or 0 });
	end);

	service:on(Command.S_BOUNTY_START_REQUEST, "BountyStartRequest", function(conn, channel, request) 
		local cmd = Command.S_BOUNTY_START_RESPOND;
		local proto = "BountyStartRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_BOUNTY_START_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local activity_id = request.activity_id

		local ret, questInfo = StartQuest(pid, activity_id);
	
		if ret then
			AI_DEBUG_LOG("Success ai start bounty")
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS, quest = (questInfo and questInfo.quest or 0), record = (questInfo and questInfo.record or 0) , next_fight_time = (questInfo and questInfo.next_fight_time or 0)});
		end
		
		return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR})
	end)

	service:on(Command.C_BOUNTY_CANCEL_REQUEST, function(conn, pid, data)
		local sn = data[1];

		local ret = CancelQuest(pid, data[2] or 1);
		return conn:sendClientRespond(Command.C_BOUNTY_CANCEL_RESPOND, pid, {sn, ret});
	end);

	service:on(Command.C_BOUNTY_FIGHT_REQUEST, function(conn, pid, data)
		local sn = data[1];

		local ret, next_fight_time = BountyFight(pid, data[2] or 1);
		return conn:sendClientRespond(Command.C_BOUNTY_FIGHT_RESPOND, pid, {sn, ret, next_fight_time});
	end);

	service:on(Command.S_BOUNTY_FIGHT_REQUEST, "BountyFightRequest", function(conn, channel, request) 
		local cmd = Command.S_BOUNTY_FIGHT_RESPOND;
		local proto = "BountyFightRespond";

		if channel ~= 0 then
			log.error(request.pid .. "Fail to `S_BOUNTY_FIGHT_REQUEST`, channel ~= 0")
			sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_PREMISSIONS});
			return;
		end

		local pid = request.pid
		local activity_id = request.activity_id

		local ret, next_fight_time = BountyFight(pid, activity_id);
	
		if ret then
			AI_DEBUG_LOG("Success ai bounty fight")
			return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS, next_fight_time});
		end

		return sendServiceRespond(conn, cmd, channel, proto, {sn = request.sn or 0, result = Command.RET_ERROR})
	end)
end

return {
	registerCommand = registerCommand
}
