local Class = require "Class"
local cell = require "cell"
local database = require "database"

local table = table;
local math = math;
local string = string;
local ipairs = ipairs;
local pairs = pairs;
local os=os;
local assert=assert
local tostring=tostring;
local fight=fight
local type=type
local log=log;
local rawget=rawget;
local tonumber=tonumber;
local loop = loop;
local print = print;

local Command =require "Command"
local ArenaConfig = require "RankArenaConfig"
local Time = require "Time"
local YQSTR =require "YQSTR"
local bit32 = require "bit32"
require 'MailReward'
local send_mail =send_mail

-- DEBUG ==================
require "Debug"
local ps = ps;
local pe = pe;
local pm = pm;
local pr = pr;
local debugOn = debugOn;
local debugOff = debugOff;
local dumpObj = dumpObj;
local ArenaEnemyConfigManager = require "ArenaEnemyConfigManager"
debugOn(false);
--debugOff();
-- ================== DEBUG

module "RankArenaPlayer"

local function setPlayerTodayTopInfo(player, today_top, reward_status)
	local changed = false;

	if today_top and (player.today_top == 0 or player.today_top > today_top) then
		changed = true;
	end

	if reward_status and reward_status ~= player.reward_status then
		changed = true;
	end

	if changed then
		log.debug("set player today_top", player.id, today_top, reward_status);
		player._today_top               = today_top or player.today_top;
		player._today_top_reward_status = reward_status or player.today_top_reward_status;
		player._today_top_update_time   = loop.now();
		database.update("replace into arena_daily_max_order (pid,max_order, reward_status, update_time) values(%d, %d, %d, from_unixtime_s(%d))", 
						player._id, player._today_top, player._today_top_reward_status, player._today_top_update_time);
	end
end

-- load
local function loadPlayerArenaInfo(player)
	log.debug(string.format("arena load player %u arena info", player._id));


	local success, result = database.query([[select `order`, cwin, unix_timestamp(fight_time) as fight_time, fight_count, addFightCount, unix_timestamp(reward_time) as reward_time, xorder, xorder_date, daily_reward_flag, unix_timestamp(daily_reward_flag_update_time) as daily_reward_flag_update_time, today_win_count, unix_timestamp(today_win_count_update_time) as today_win_count_update_time, unix_timestamp(last_refresh_enemy_list_time) as last_refresh_enemy_list_time, unix_timestamp(addFightCount_time) as addFightCount_time from arena where pid = %u]], player._id);

	if not success or result[1] == nil then
		return false;
	end

	player._order       = tonumber(result[1].order);
	player._cwin        = tonumber(result[1].cwin);
	player._fight_time  = tonumber(result[1].fight_time);
	player._fight_count = tonumber(result[1].fight_count);
	player._addFightCount = tonumber(result[1].addFightCount);
	player._reward_time = tonumber(result[1].reward_time);
	player._xorder      = tonumber(result[1].xorder);
	player._xorder_date = tonumber(result[1].xorder_date);
	player._daily_reward_flag = tonumber(result[1].daily_reward_flag);
	player._daily_reward_flag_update_time = tonumber(result[1].daily_reward_flag_update_time);
	player._today_win_count = tonumber(result[1].today_win_count)
	player._today_win_count_update_time = tonumber(result[1].today_win_count_update_time)
	player._last_refresh_enemy_list_time = tonumber(result[1].last_refresh_enemy_list_time)
	player._addFightCount_time = tonumber(result[1].addFightCount_time)

	if player._xorder_date == 0 then
		player._xorder_date = loop.now();
	end

	local success, result = database.query([[select `max_order`, reward_status, unix_timestamp(update_time) as update_time from arena_daily_max_order where pid = %u]], player._id);

	player._today_top               = player._order;
	player._today_top_reward_status = 0;
	player._today_top_update_time   = loop.now();

	if success and result[1] then
		player._today_top = tonumber(result[1].max_order);
		player._today_top_reward_status = tonumber(result[1].reward_status);
		player._today_top_update_time   = tonumber(result[1].update_time);
	else
		database.update("replace into arena_daily_max_order (pid,max_order, reward_status, update_time) values(%d, %d, %d, from_unixtime_s(%d))", 
						player._id, player._today_top, player._today_top_reward_status, player._today_top_update_time);
	end	

	-- setPlayerTodayTopInfo(player, player._order, nil);

	player._enemy_list = {}
	local success, result = database.query("select * from rank_arena_enemy_list where pid = %d", player._id);
	if success and result[1] then
		for i = 1, #result, 1 do
			local row = result[i]
			table.insert(player._enemy_list, row.enemy_id)
		end
	end

	player._formation_data = {formation = {}, update_time = 0}
	local success, result = database.query("select * from rank_arena_formation where pid = %d", player._id);
	if success and result[1] then
		for i = 1, #result, 1 do
			local row = result[i]
			table.insert(player._formation_data.formation, row.role1)
			table.insert(player._formation_data.formation, row.role2)
			table.insert(player._formation_data.formation, row.role3)
			table.insert(player._formation_data.formation, row.role4)
			table.insert(player._formation_data.formation, row.role5)
		end
	end	

	return true;
end

local function loadPlayerInfo(player)
	log.debug(string.format("arena load player %u info", player.id)); 

--[[
	-- 假人
	if (player._id < 10) then
		player._level  = 5;
		player._update_time = loop.now();
		return;
	end
]]

	local respond = cell.getPlayer(player.id);
	if respond and respond.result == Command.RET_SUCCESS then
		player._level = respond.player.level;
		player._name = respond.player.name;
		player._vip = respond.player.vip;
		player._update_time = loop.now();
	else
		log.debug(string.format("load player %u info failed", player.id));
	end
end

local function getPlayerInfo(self, key)
	local value = rawget(self, key);
	if not value or loop.now() - self._update_time > 60 then
		loadPlayerInfo(self);
		value = rawget(self, key);
	end
	return value;
end

local function getPlayerArenaInfo(self, key)
	local value = rawget(self, key);
	if not value then
		loadPlayerArenaInfo(self);
		value = rawget(self, key);
	end
	return value;
end


function _init_(self, id)
	log.debug(string.format("Player:_init_ %u",  id));
	self._id = id;
	ArenaEnemyConfigManager.AIJoinRankArena(id)
	if not loadPlayerArenaInfo(self) then
		return false;
	end
end

-- * property

id     = { get = "_id"     }

level = { 
	get = function(self)
		return getPlayerInfo(self, "_level");
	end,
}

name = { 
	get = function(self)
		return getPlayerInfo(self, "_name");
	end,
}

vip = {
	get = function(self)
		return getPlayerInfo(self, "_vip");
	end
}

-- 返回 间隔轮数 下次重置时间
local function getRefreshTime(otime, now, at, loop)
	at = at or 0; 			-- 默认0点重置
	loop = loop or Time.DSEC;	-- 默认每天重置

	local oday, osec = Time.ROUND(otime - at, loop);
	local cday, csec = Time.ROUND(now - at, loop);

	if oday < cday then
		return cday - oday, now - csec + loop
	elseif oday > cday then
		return false, otime - osec + loop;
	else
		return false, now - csec + loop;
	end
end

local function checkXOrder(self)
    local round = 3600 * 24; -- 周期
    local refresh_time = ArenaConfig.REWARD_TIME; -- 刷新时间

    local now = loop.now();

    -- 查看昨日排名是否过期
    local refreshed = getRefreshTime(self._xorder_date, now, refresh_time, round);
    if not refreshed then
        return self._xorder, self._xorder_date;
    end

    -- 过期了
    return self._order, now;
end

-- 当前排名
order  = {
	get = "_order",
}

-- 上次排名
xorder = {
	get = function(self)
		if rawget(self, "_xorder_date") == nil then
			loadPlayerArenaInfo(self);
		end

		local x, d = checkXOrder(self);
		return x;
	end
}

-- 连胜
cwin   = {
	get = "_cwin";
}

-- 挑战时间
fight_time = {
	get = "_fight_time",

	set = function(self, t) 
		self._fight_time = t;
	end
}

-- 下次挑战时间
fight_cd = {
	get = function(self)
		local fight_cd = 0;
		local CD = self._fight_cd or ArenaConfig.FIGHT_CD_WHEN_WIN;
		if self.fight_time + CD > loop.now() then
			fight_cd = self.fight_time + CD;
		end
		return fight_cd;
	end
}


-- 挑战次数
fight_count = {
	get = function(self)
		local refresh_time = ArenaConfig.FIGHT_COUNT_REFRESH;

		local refed = getRefreshTime(self.fight_time, loop.now(), refresh_time, 3600 * 24);
		if refed and refed > 0 then
			return 0;
		else
			return self._fight_count;
		end
	end,
}

addFightCount_time = {
	get = "_addFightCount_time",
	
	set = function(self, t)
		self._addFightCount_time = t;
	end
}

-- 购买次数 有隐患
addFightCount = {
	get = function(self)
		local refresh_time = ArenaConfig.FIGHT_COUNT_REFRESH;

		local refed = getRefreshTime(self.addFightCount_time, loop.now(), refresh_time, 3600 * 24);
		if refed and refed > 0 then
			return 0;
		else
			return self._addFightCount;
		end
	end,
}

-- 领奖日期
reward_time = {
	get = function(self)
		return getPlayerArenaInfo(self, "_reward_time");
	end,

	set = function(self, rtime)
		local old = rawget(self, "_reward_time") or 0;
		if old ~= rtime then
			log.debug(string.format("arena set player %u reward_time %u -> %u", self.id, old, rtime));
			if database.update("update arena set reward_time = from_unixtime_s(%u) where pid = %u", rtime, self.id) then
				self._reward_time = rtime;
			end
		end
	end
}

-- 领奖CD
reward_cd = {
	get =function(self)
		local refresh_time = ArenaConfig.REWARD_TIME;
		local round = 3600 * 24;

		local old = self.reward_time or 0;
		local now = loop.now();
		local refreshed, nextTime = getRefreshTime(old, now, refresh_time, round);
		return refreshed and 0 or nextTime;
	end
}

-- 对手类表
enemy_list = {
	get = function(self)
		if rawget(self, "_enemy_list") == nil then
			loadPlayerArenaInfo(self);
		end

		return self._enemy_list;
	end
}

daily_reward_flag_update_time = {
	get = function(self)
		if rawget(self, "_daily_reward_flag_update_time") == nil then
			loadPlayerArenaInfo(self);
		end

		return self._daily_reward_flag_update_time
	end
}

daily_reward_flag = {
	get = function(self)
		if rawget(self, "_daily_reward_flag") == nil then
			loadPlayerArenaInfo(self);
		end
		
		local refed = getRefreshTime(self._daily_reward_flag_update_time, loop.now(), 0, 3600 * 24);
		if refed and refed > 0 then
			return 0;
		end

		return self._daily_reward_flag;	
	end
}

today_win_count_update_time = {
	get = function(self)
		if rawget(self, "today_win_count_update_time") == nil then
			loadPlayerArenaInfo(self);
		end

		return self._today_win_count_update_time
	end
}

today_win_count = {
	get = function(self)
		if rawget(self, "_today_win_count") == nil then
			loadPlayerArenaInfo(self);
		end
		
		local refed = getRefreshTime(self._today_win_count_update_time, loop.now(), 0, 3600 * 24);
		if refed and refed > 0 then
			return 0;
		end

		return self._today_win_count;	
	end
}

last_refresh_enemy_list_time = {
	get = function(self)
		if rawget(self, "_last_refresh_enemy_list") == nil then
			loadPlayerArenaInfo(self);
		end
		
		return self._last_refresh_enemy_list_time;	
	end
}

formation_data = {
	get = function(self)
		if rawget(self, "_formation_data") == nil then
			loadPlayerArenaInfo(self);
		end

		if not self._formation_data.fight_data or loop.now() - self._formation_data.update_time > 2 * 3600 then
			default_formation = true
			for k, v in ipairs(self._formation_data.formation) do
				if v ~= 0 then
					default_formation = false	
				end
			end

			local fight_data, err = cell.QueryPlayerFightInfo(self.id, false, 0, not default_formation and self._formation_data.formation or nil)
			if fight_data then
				self._formation_data.fight_data = fight_data
			end
		end
		
		return self._formation_data;	
	end
}

-- functions
function rankReachReward(self)
	for i=1, #ArenaConfig.RankReachReward do
		local cfg =ArenaConfig.RankReachReward[i]
		if self._order > cfg.Rank then
			break
		end
		-- prepare rank reach reward status
		if not self._rank_reach_reward_status then
			local success, result = database.query([[select `rank` from arena_rank_reach_status where `pid` = %u]], self._id);
			if not success then
				break
			end
			self._rank_reach_reward_status ={}
			for j=1, #result do
				local row =result[j]
				self._rank_reach_reward_status[row.rank] =true
			end
		end
		-- check and reward
		if not self._rank_reach_reward_status[cfg.Rank] then
			if not database.update("replace into arena_rank_reach_status(`pid`, `rank`)values(%d, %d)", self._id, cfg.Rank) then
				break
			end
			self._rank_reach_reward_status[cfg.Rank] =true
			local title =YQSTR.ARENA_RANK_REACH_REWARD_TITLE
			local content =string.format(YQSTR.ARENA_RANK_REACH_REWARD_CONTENT, cfg.Rank)
			send_mail(Command.MAIL_TYPE_USER, 0, self._id, title, content, cfg.Reward)
		end
	end
end
function setArenaInfo(self, count, time, cwin, order, cd, addCount, daily_reward_flag, today_win_count, last_refresh_enemy_list_time, addFightCount_time)
	local oldc  = rawget(self, "_fight_count");
	local oldt  = rawget(self, "_fight_time");
	local oldw  = rawget(self, "_cwin");
	local oldo  = rawget(self, "_order");
	local oldx  = rawget(self, "_xorder");
	local oldxd = rawget(self, "_xorder_date");
	local oldcd = rawget(self, "_fight_cd");
	local oldac = self.addFightCount--rawget(self, "_addFightCount");
	local oldact = self.addFightCount_time
	local olddrf = self.daily_reward_flag 
	local olddrft = self.daily_reward_flag_update_time
	local oldtwc = self.today_win_count
	local oldtwct = self.today_win_count_update_time
	local oldlret = rawget(self, "_last_refresh_enemy_list_time")

	local daily_reward_flag_change = (daily_reward_flag ~= nil)
	local today_win_count_change = (today_win_count ~= nil)
	local last_refresh_enemy_list_time_change = (last_refresh_enemy_list_time ~= nil)

	count = count or oldc;
	time  = time  or oldt;
	cwin  = cwin  or oldw;
	order = order or oldo;
	cd    = cd    or oldcd;
	addCount = addCount or oldac;
	last_refresh_enemy_list_time = last_refresh_enemy_list_time or oldlret
	addFightCount_time = addFightCount_time or oldact

	daily_reward_flag_update_time = daily_reward_flag and loop.now() or olddrft
	daily_reward_flag = daily_reward_flag or olddrf
	today_win_count_update_time = today_win_count and loop.now() or oldtwct
	today_win_count = today_win_count or oldtwc

	if oldc == count and oldt == time and oldw == cwin and oldo == order and oldac == addCount and not daily_reward_flag_change and not today_win_count_change and not last_refresh_enemy_list_time_change then
		log.debug(string.format("%u setArenaInfo no change", self.id));
		self._fight_cd    = cd;
		return;
	end

	local nx, nd = checkXOrder(self);

	log.debug(string.format([[setArenaInfo %u 
			fight_count %u -> %u
			fight_time  %u -> %u
			cwin        %u -> %u
			order       %u -> %u
			xorder      %u -> %u
			xorder_date %u -> %u
			addFightCount %u -> %u
			daily_reward_flag %u -> %u
			daily_reward_flag_update_time %d -> %d
			today_win_count %u -> %u
			today_win_count_update_time %d -> %d
			last_refresh_enemy_list_time %d -> %d
			addFightCount_time %d -> %d]],
		self.id, 
		oldc, count, 
		oldt, time, 
		oldw, cwin, 
		oldo, order,
		oldx, nx,
		oldxd, nd,
		oldac, addCount,
		olddrf, daily_reward_flag,
		olddrft, daily_reward_flag_update_time,
		oldtwc, today_win_count,
		oldtwct, today_win_count_update_time,
		oldlret, last_refresh_enemy_list_time,
		oldact, addFightCount_time));

	if database.update("update arena set fight_count = %u, fight_time = from_unixtime_s(%u), cwin = %u, `order` = %u, xorder = %u, xorder_date = %u, addFightCount = %u, daily_reward_flag = %d, daily_reward_flag_update_time = from_unixtime_s(%d), today_win_count = %u, today_win_count_update_time = from_unixtime_s(%d), last_refresh_enemy_list_time = from_unixtime_s(%d), addFightCount_time = from_unixtime_s(%d) where pid = %u", count, time, cwin, order, nx, nd, addCount, daily_reward_flag, daily_reward_flag_update_time, today_win_count, today_win_count_update_time, last_refresh_enemy_list_time, addFightCount_time, self.id) then

		self._order       = order;
		self._xorder      = nx;
		self._xorder_date = nd;
		self._fight_count = count;
		self._fight_time  = time;
		self._fight_cd    = cd;
		self._cwin        = cwin;
		self._addFightCount = addCount;
		self._daily_reward_flag = daily_reward_flag;
		self._daily_reward_flag_update_time = daily_reward_flag_update_time;
		self._today_win_count = today_win_count
		self._today_win_count_update_time = today_win_count_update_time
		self._last_refresh_enemy_list_time = last_refresh_enemy_list_time
		self._addFightCount_time = addFightCount_time
		
		-- 首次达到名次奖励
		--rankReachReward(self)
	end

	setPlayerTodayTopInfo(self, order);
end

function refreshEnemyList(self, enemy_list)
	if #enemy_list == 0 then
		return
	end

	local old_enemy_list = self.enemy_list
		
	-- clean old data
	if #old_enemy_list > 0 then
		database.update("delete from rank_arena_enemy_list where pid = %d", self.id)
	end

	for k, enemy in ipairs(enemy_list) do
		database.update("insert into rank_arena_enemy_list(pid, enemy_id) values(%d, %d)", self.id, enemy)
	end

	self._enemy_list = enemy_list
end

function reloadFormationData(self, fight_data)
	self._formation_data.fight_data = fight_data
	self._formation_data.update_time = loop.now()
end

function changeFormation(self, formation)
	if #formation < 5  then
		return
	end

	self._formation_data.formation = formation

	local fight_data, err = cell.QueryPlayerFightInfo(self.id, false, 0, formation)
	if fight_data then
		self._formation_data.fight_data = fight_data
		self._formation_data.update_time = loop.now()
	end
	
	database.update("replace into rank_arena_formation(pid, role1, role2, role3, role4, role5) values(%d, %d, %d, %d, %d, %d)", self.id, formation[1], formation[2], formation[3], formation[4], formation[5])	
end

local start_week_unix_time = 1441054800; -- 2015-09-01 05:00:00
local SEC_OF_WEEK = 7 * 24 * 3600;
local function isMaxOrderRewardRoundChange(player)
	local now = loop.now();
	local week1 = math.floor((now - start_week_unix_time) / SEC_OF_WEEK);
	local week2 = math.floor((player._today_top_update_time - start_week_unix_time) / SEC_OF_WEEK);
	return week1 ~= week2;
end

today_top = {
	get = function(self)
		if isMaxOrderRewardRoundChange(self) then
			return self._order;
		end
		return self._today_top;
	end,
};

today_top_reward_status = {
	get = function(self)
		if isMaxOrderRewardRoundChange(self) then
			return 0;
		end
		return self._today_top_reward_status;
	end
}

local orderToBit = {
	[  1] = {bit=0,value=200},
	[ 20] = {bit=1,value=150},
	[ 50] = {bit=2,value=100},
	[200] = {bit=3,value=50},
};

function GetTodayMaxOrderReward(self, order)
	local today_status = self.today_top_reward_status;
	local today_top    = self.today_top;

	if order < today_top then
		log.debug(string.format("order(%d) < today_top(%d)", order, today_top));
		return Command.RET_ERROR;
	end

	if orderToBit[order] == nil then
		log.debug(string.format("order(%d) not exists", order));
		return Command.RET_ERROR;
	end

	local bit = bit32.lshift(1, orderToBit[order].bit);
	if bit32.band(today_status, bit) ~= 0 then
		log.debug(string.format("order(%d) reward already received", order));
		return Command.RET_ERROR;
	end

	local respond = cell.sendReward(self._id, {{type=90, id=24, value=orderToBit[order].value}}, {}, Command.REASON_ARENA_REWARD);
	if respond and  respond.result == "RET_SUCCESS" then
		setPlayerTodayTopInfo(self, nil, bit32.bor(today_status, bit));
		return Command.RET_SUCCESS;
	else
		return Command.RET_ERROR;
	end
end

function New(...)
	return Class.New(_M, ...)
end
