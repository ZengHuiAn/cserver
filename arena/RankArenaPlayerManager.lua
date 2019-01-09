local ipairs = ipairs;
local table = table;
local pcall = pcall;

local log = log;

local Class = require "Class"
local Player = require "RankArenaPlayer"
local database = require "database"
local loop = loop;
local Scheduler = require "Scheduler"
local ArenaConfig = require "RankArenaConfig"
local Command = require "Command"
local Scheduler = require "Scheduler"
local Time = require "Time"
local cell = require "cell"
local pairs = pairs;
--local broadcast =require "broadcast"
local YQSTR = require "YQSTR";
local string = string;
local coroutine = coroutine
--local AIConfig = require "AIConfig"
local type = type;
local print = print
local next = next
local ArenaEnemyConfigManager = require "ArenaEnemyConfigManager"
local SGK_Game = SGK_Game

--local add_player_to_arena_queue =add_player_to_arena_queue
module "RankArenaPlayerManager"

all = {};
count = 0;
--ai_max_pid =0
--[[local function prepare_ai_max_pid()
	if ai_max_pid == 0 then
		local ok, result =database.query("SELECT max(`pid`) as `max_pid` FROM `property`")
		if ok and result and #result>=1 then
			ai_max_pid =result[1].max_pid
			if ai_max_pid < AIConfig.AI_ID_MIN then
				ai_max_pid =AIConfig.AI_ID_MIN
			end
			log.debug(string.format("max ai pid is %d", ai_max_pid))
		end
	end
end--]]
--[[local function is_property_name_exist(name)
	local ok, result =database.query("SELECT `pid` FROM `property` WHERE `name`='%s'", name)
	return ok and result and #result>=1
end--]]
--[[local function add_ai()
	-- check enable
	if not AIConfig.ENABLE then
		return
	end

	-- prepare ai pid
	prepare_ai_max_pid()
	if ai_max_pid == 0 then
		return
	end

	-- gen
	for i=1, AIConfig.AI_GEN_COUNT do
		-- try gen ai_name
		local ai_name =AIConfig.GenName()
		if is_property_name_exist(ai_name) then
			break
		end
		-- make pid and order
		local ai_pid =ai_max_pid + 1
		local ai_order =count + 1

		-- property
		local cfg =AIConfig.GenProperty()
		if not cfg then
			break
		end
		local ok =database.update("INSERT INTO `property`(`pid`, `name`, `exp`, `head`)VALUES(%d, \"%s\", %d, %d);\n"
			, ai_pid, ai_name, cfg.exp, cfg.head);
		if not ok then
			break
		end

		-- armament
		local cfg_list =AIConfig.GenArmament()
		for j=1, #cfg_list do
			local cfg =cfg_list[j]
			database.update("INSERT INTO `armament`(`pid`, `gid`, `level`, `stage`, `placeholder`)VALUES(%d, %d, %d, %d, %d);\n"
				, ai_pid, cfg.gid, cfg.level, cfg.stage, cfg.placeholder)
		end

		-- king avatar
		local cfg =AIConfig.GenKingAvatar()
		database.update(string.format("REPLACE INTO `kingavatar`(`pid`, `banner_id`, `scale`, `hero_skin_id`,`hero_body_type`,`weapon_skin_id`,`weapon_body_type`,`mount_skin_id`,`mount_body_type`,`flag_skin_id`)VALUES(%d,%d,%d,%d,'%s',%d,'%s',%d,'%s',%d);\n",
					ai_pid, cfg.banner_id, cfg.scale, 
					cfg.hero_skin_id, cfg.hero_body_type, 
					cfg.weapon_skin_id, cfg.weapon_body_type, 
					cfg.mount_skin_id, cfg.mount_body_type, 
					cfg.flag_skin_id
		));

		-- arena
		database.update("INSERT INTO `arena`(`pid`, `order`)VALUES(%d, %d);\n", ai_pid, ai_order)

		-- add to all
		all[ai_pid] =Player.New(ai_pid);

		-- add ai to queue
		add_player_to_arena_queue(ai_order, all[ai_pid]);

		-- incr counter
		ai_max_pid =ai_max_pid + 1
		count =count + 1
	end
end--]]

function Create(id)
	print("Arena Create player", id)
	if all[id] then
		log.warning("PlayerManager::Create already exist %u", id);
		return nil;
	end

	-- add ai patch
	--[[if id < AIConfig.AI_ID_MIN then
		add_ai()
	end--]]

	local order = count + 1;
	if not database.update("insert into arena(pid, `order`, `reward_time`) values(%u, %u, now())", id, order) then
		return nil;
	end

	local player = Player.New(id);
	if player then
		all[id] = player;
		count = count + 1;
	end

	return player;
end

function Get(id)
	return all[id];
end

function GetAll()
    return all
end

local max_order = -1
function GetMaxOrder()
	return max_order
end

function UpdateMaxOrder(order)
	if order > max_order then
		max_order = order
	end
end

function LoadAll()
	local success, result = database.query("select pid, `order` from arena");
	if not success then
		return false;
	end

	all = {};
	count = 0;
	for _, row in ipairs(result) do
		local player = Player.New(row.pid);
		if player then
			all[row.pid] = player;
			count = count + 1;
		end

		UpdateMaxOrder(row.order)
	end

	--添加机器人
	if not next(all) then
		--local ids = ArenaEnemyConfigManager.genRankArenaAIEnemy()
		local ids = ArenaEnemyConfigManager.genOriginalRankArenaAIEnemy()
		table.sort(ids, function(a, b)
			if a ~= b then
				return a < b
			end
		end)
		if ids then
			for _, id in ipairs(ids) do
				Create(id)
			end
		end
	end
end

LoadAll();

local function checkAndSendManualReward(player, now)
	now = now or loop.now();

	if player.reward_cd > now then
		return;
	end

	if player.xorder == 0 then
		player.reward_time = now;
		return;
	end

	--[[ older
	local coin = 0;
	local prestige = 0;

	local reward = ArenaReward.Reward[player.xorder];
	if not reward then
		-- 100名之后未配置的奖励
		local coin = (160000 - (player.xorder * 100));
		if coin < ArenaReward.REWARD_COIN_MIN then
			coin = ArenaReward.REWARD_COIN_MIN;
		end
		reward = {
			{type = "REWARD_RESOURCES_VALUE", key = RESOURCES_COIN, value = coin},
		};
	end
	]]
	player.reward_time = now;
	local reward =ArenaConfig.GetRankReward(player.xorder)
	if reward then
		print("send reward for player", player.id)
		cell.sendReward(player.id, reward, nil, Command.REASON_RANK_ARENA_REWARD, true, player.reward_cd, string.format(YQSTR.ARENA_RANK_REWARD, player.xorder))
		--cell.sendReward(player.id, reward, nil, Command.REWARD_TYPE_ARENA, 1, player.reward_cd, string.format(YQSTR.ARENA_RANK_REWARD, player.xorder));
	end
end

local online = {};
function Login(id, conn)
	log.debug(string.format('player %u login', id));
	local player = Get(id);
	if player then
		player.conn = conn;
		online[player.id] = player;
		if SGK_Game() then
			checkAndSendManualReward(player);
		end
	end
end

function Logout(id)
	log.debug(string.format('player %u logout', id));
	local player = Get(id);
	if player then
		player.conn = nil;
		online[player.id] = nil;
	end
end

-- 返回 间隔轮数 下次重置时间
local function getRefreshTime(now, at, loop)
	at = at or 0; 			-- 默认0点重置
	loop = loop or Time.DSEC;	-- 默认每天重置

	return Time.ROUND(now - at, loop);
end

local rewardTime = 0;
local fightTime = 0;


local function NotifyPlayer(player)
	if player and player.conn then
		local cmd = Command.C_ARENA_QUERY_RESPOND;
		local respond = {
			0,		-- sn
			Command.RET_SUCCESS,	-- result
			{ 		-- self
				player.order, 
				player.id,
				player.cwin,		-- 连胜
				ArenaConfig.getFightCountPerDay() - player.fight_count,	-- 挑战次数
				player.fight_cd,	-- 挑战cd
				player.xorder,		-- 昨天排名
				player.reward_cd,	-- 领奖cd
				ArenaConfig.getFightCountPerDay(), -- 竞技场每天总挑战次数
				ArenaConfig.ADD_FC_CONSUME_BASE,
			},
		}
		player.conn:sendClientRespond(cmd, player.id, respond);
	end
end

if SGK_Game() then
	Scheduler.Register(function(now)
		local rday, rsec = getRefreshTime(rewardTime, ArenaConfig.REWARD_TIME); 
		local cday, csec = getRefreshTime(now, ArenaConfig.REWARD_TIME);

		if rday < cday and csec > 5 then
			rewardTime = now;

			--[[local broadCo = coroutine.create(function(all)
				for _, player in pairs(all) do
					if player.xorder == 1 then
						broadcast.SystemBroadcastEasy(Command.SYS_BROADCAST_TYPE_FULL_SCREEN, string.format(YQSTR.ARENA_WIN_AS_CHAMPION, player.name)); 
					end
				end
			end)
			local ok, status = coroutine.resume(broadCo, all);
			if not ok then 
				log.info("broadCo send broadcast fail", status)
			end--]]
			for _, player in pairs(online) do
				checkAndSendManualReward(player);
				--NotifyPlayer(player);
			end
		end

		rday, rsec = getRefreshTime(fightTime, ArenaConfig.FIGHT_COUNT_REFRESH);
		cday, csec = getRefreshTime(now, ArenaConfig.FIGHT_COUNT_REFRESH);

		if rday < cday and csec > 5 then
			fightTime = now;

			--[[for _, player in pairs(online) do
				NotifyPlayer(player);
			end--]]
		end
	end);
end

local g_card_info = {}; --玩家翻牌信息
local g_KT = {flag = 1, pool_type = {16, 17, 18}};
local g_RM = {flag = 2, pool_type = {19, 20, 21}};
local g_free_pool_type = 16;

function GetFreePoolType()
	return g_free_pool_type;
end

function AddLuckyDrawCountToPlayer(pid, flag)
	if pid and type(pid) == "number" then
		local data = {};
		if flag == g_KT.flag then
			for key, value in pairs(g_KT.pool_type) do
				table.insert(data, {pool_type = value, count = 1});
			end
		elseif flag == g_RM.flag then
			for key, value in g_RM.pool_type do
				table.insert(data, {pool_type = value, count = 1});
			end
		end

		g_card_info[pid] = data;
	end
end

function DeductPlayerLuckyDrawCount(pid, pool_type, count)
	if pid and type(pid) == "number" and pool_type and type(pool_type) == "number" then
		local data = g_card_info[pid];
		if data then
			for key, value in pairs(data) do
				if value.pool_type == pool_type and value.count > 0 then
					value.count = value.count - 1;
					return true;
				end
			end
		end
	end
	return false;
end

function CheckSurplusLuckyDrawCount(pid, pool_type)
	if pid and type(pid) == "number" and pool_type and type(pool_type) == "number" then
		local count = 0;
		local data = g_card_info[pid];
		if data then
			for key, value in pairs(data) do
				if value.pool_type == pool_type then
					return value.count;
				end
			end
		end
	end
	return 0;
end
