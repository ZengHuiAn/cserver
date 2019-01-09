local loop = loop;
local string = string;
local pairs = pairs;
local ipairs = ipairs;
local os = os;
local log = log;
local assert = assert;
local tonumber = tonumber;
local setmetatable = setmetatable;
local rawset = rawset;
local next = next;
local table = table;
local print = print;
local coroutine = coroutine;
local math = math;
local type = type;

local Class = require "Class"
local database = require "database"
local base64 = require "base64"

local PlayerManager = require "PlayerManager"
local RankManager = require "RankManager"
local DonateManager = require "DonateManager"

local SocialManager = require "SocialManager"
local Scheduler = require "Scheduler"
local GuildConfig =require "GuildConfig"
local Time = require "Time";
local FixLengthQueue = require "FixLengthQueue";
local GuildEvent =require "GuildEvent"
local EventManager =require "EventManager"
local GuildEventLog = require "GuildEventLog"
local bit32 = require "bit32"
local cell = require "cell"
local Command = require "Command"
local tostring = tostring

require "GuildSummaryConfig"
local GuildNumberConfig = GuildNumberConfig
local GetBoxReward = GetBoxReward
require "yqlog_sys"
local sprinttb = sprinttb

-- DEBUG ==================
require "Debug"
--require "GuildActivity"
--local delActJoinQueue = delActJoinQueue;
local ps = ps;
local pe = pe;
local pm = pm;
local pr = pr;
local debugOn = debugOn;
local debugOff = debugOff;
local dumpObj = dumpObj;
debugOn(false);
--debugOff();
-- ================== DEBUG

module "GuildManager"

SocialManager.Connect("Boss");

local All = {};
local AllName = {};
local AllAutoConfirm = {}; --开启自动审核的军团列表
local AutoJoinPlayers = {};  --开启自动申请的玩家列表

local Guild = {};
local _now = os.time();
local rank = RankManager.New();
local rank_highest_wealth = RankManager.New()

local JOIN_GUILD  = 101
local LEVEL_GUILD = 102
local ADD_WEALTH  = 103
local function AddDynamicLog(type, tb, guildid )
	local event_log = GuildEventLog.Get(guildid)
        
	if event_log then
		event_log:AddLog(type,tb)
	end
end

local meta_unsetable = {
	__newindex = function(self, k, v)
		assert(false, "can't set member directly")
	end;
}
local function get_today_begin_time()
	local now =os.date("*t", loop.now())
	now.hour=0
	now.min=0
	now.sec=0
	local t =os.time(now)
	return t
end
-- 卸载不活跃数据
local function unloadGuild(guild)
	guild._name = nil;
	guild._founder = nil;
	guild._leader = nil;
	guild._create_time = nil;
	guild._members = nil;
	guild._requests = nil;
	guild._notice = nil;
	guild._desc = nil;
	guild._mcount = nil;
    guild._member_buy_count = nil;
end

local function loadGuildInfo(guild, result)
	if not result then
		log.debug(string.format("loadGuildInfo %u", guild._id));
		local success, rows = database.query("select name,camp, exp, today_add_exp, add_exp_time, founder, leader, \
						unix_timestamp(createat) as createat, member_buy_count, \
						unix_timestamp(boss) as boss, notice, \
						`desc`, dissolve, auto_confirm, wealth, today_add_wealth, add_wealth_time, highest_wealth from guild where gid = %u",
						guild._id);

		if (not success) or rows[1] == nil then
			return false;
		end
		result = rows
	end

	guild._exp       = result[1].exp;
	guild._today_add_exp = result[1].today_add_exp;
	guild._add_exp_time  = result[1].add_exp_time;
	guild._name        = result[1].name;
	guild._camp 	   = result[1].camp;
	guild._founder     = PlayerManager.Get(result[1].founder);
	guild._leader      = PlayerManager.Get(result[1].leader);
	guild._create_time = tonumber(result[1].createat);
	guild._notice      = result[1].notice;
	guild._desc        = result[1].desc;
	guild._dissolve    = result[1].dissolve;
	guild._boss        = tonumber(result[1].boss);
    guild._member_buy_count = result[1].member_buy_count;
	guild._auto_confirm = result[1].auto_confirm
	guild._wealth   = result[1].wealth
	guild._today_add_wealth = result[1].today_add_wealth
	guild._add_wealth_time = result[1].add_wealth_time
	guild._highest_wealth = result[1].highest_wealth

	if guild._dissolve ~= 0 then
		return false;
	end

	rank:setValue(guild._id, guild._exp);
	AllName[guild._name] = guild;
	return true;
end

local function loadGuildMember(guild, result)
	if not result then
		log.debug(string.format("loadGuildMember %u", guild._id));
		local success, rows = database.query("select pid, title, total_cont, today_cont, unix_timestamp(cont_time) as cont_time, reward_flag, unix_timestamp(last_draw_time) as last_draw_time, today_donate_count, unix_timestamp(donate_time) as donate_time from guildmember where gid = %u", guild._id);

		if not success then
			return false;
		end
		result = rows;
	end

	guild._members = {};
	guild._mcount = 0;
	for _, row in ipairs(result) do
		local id = row.pid;
		local player = PlayerManager.Get(id);

		player.guild       = guild;
		player._title      = row.title;
		guild._members[id] = player;

		player._total_cont = row.total_cont;
		player._today_cont = row.today_cont;
		player._cont_time  = tonumber(row.cont_time);
		player._reward_flag = row.reward_flag
		player._last_draw_time = row.last_draw_time
		player._today_donate_count = row.today_donate_count
		player._donate_time = tonumber(row.donate_time)

		guild._mcount = guild._mcount + 1;
	end
	setmetatable(guild._members, meta_unsetable);
	return true;
end

local function loadGuildRequest(guild, result)
	if not result then
		log.debug(string.format("loadGuildRequest %u", guild._id));

		local success, rows = database.query("select rid, unix_timestamp(`at`) as time from guildrequest where gid = %u", guild._id);
		if not success then
			return false;
		end

		result = rows;
	end

	guild._requests = {};
	for _, row in ipairs(result) do
		local rid = row.rid;
		guild._requests[rid] = {time = tonumber(row.time)};
	end
	setmetatable(guild._requests, meta_unsetable);
	return true;
end

local function loadGuildExpLog(guild, result)
	if not result then
		log.debug(string.format("loadGuildExpLog %u", guild._id));

		local success, rows = database.query("select id, unix_timestamp(time) as time, pid, exp, reason from guild_exp_log where gid = %u",
				guild._id);

		if not success then
			return false;
		end
		result = rows;
	end

	local newLog = nil;
	for _, row in ipairs(result) do
		local log = {
			id = row.id;
			time = tonumber(row.time);
			pid = row.pid;
			exp = row.exp;
			reason = row.reason;
		};

		if log.id <= guild.log.length then
			if newLog == nil or newLog.time < log.time then
				newLog = log;
			end
			guild.log[log.id] = log;
		end
	end

	if newLog then
		guild.log[newLog.id] = newLog;
	end
end

local function onAddGuildExpLog(queue, log, index, old, guild)
	print('onAddGuildExpLog', log.id, index, guild.id);	
	if log.id then
		return;
	end

	log.id = index;

	local gid = guild._id;

	if old then
		-- replace old log
		database.update("update guild_exp_log set time = from_unixtime_s(%u), pid = %u, exp = %u, reason = %u where id = %u and gid = %u",
			log.time, log.pid, log.exp, log.reason, index, gid);
	else
		-- insert new log
		database.update("insert into guild_exp_log (id, gid, time, pid, exp, reason) values(%u, %u, from_unixtime_s(%u), %u, %u, %u)",
			index, gid, log.time, log.pid, log.exp, log.reason);
	end
end

function Guild:_init_(id, db_result)
	db_result = db_result or {}

	self._id = id;
	self.log = FixLengthQueue.New(20, onAddGuildExpLog, self);
	
	loadGuildExpLog(self, db_result.explog);

	return loadGuildInfo(self, db_result.info) and loadGuildMember(self, db_result.member) and loadGuildRequest(self, db_result.request);
end

-- property
Guild.id = {
	get = "_id",
}


local levelConfig = {
	0,
	20000,
	70000,
	170000,
	370000,
	870000,
	1870000,
	3870000,
	8870000,
	18870000
};

local function getLevel(exp)
	--local l = math.floor(math.sqrt(exp / 10000)) + 1
	-- return l
	for k, v in ipairs(GuildNumberConfig) do
		if k ~= #GuildNumberConfig then
			if exp >= v.MaxExp and exp < GuildNumberConfig[k+1].MaxExp then
				return k
			end	
		else
			return #GuildNumberConfig
		end
	end
end 

Guild.exp = {
	get = "_exp",
	set = function(self, exp)
		if self._exp == exp then return; end

		rank:setValue(self._id, self._exp);

		log.debug(string.format("[GUILD] guild %u set exp %u -> %u", self.id, self._exp, exp));
		if database.update("update guild set exp = %u where gid = %u", exp, self.id) then
			self._exp = exp;
			self._level = getLevel(self._exp);
		end
	end
}
Guild.add_exp_time ={
	get =function(self)
		return self._add_exp_time or 0
	end,
	set =function(self, val)
		self._add_exp_time =val
	end
}
Guild.today_add_exp = {
	get = function(self)
		local today_begin =get_today_begin_time()
		if self.add_exp_time >= today_begin then
			return self._today_add_exp or 0
		else
			return 0
		end
	end,
	set = function(self, today_add_exp)
		--self.today_add_exp =self._today_add_exp or 0
		if self.today_add_exp == today_add_exp then return; end

		log.debug(string.format("[GUILD] guild %u set today_add_exp %u -> %u", self.id, self._today_add_exp, today_add_exp));
		local now =loop.now()
		if database.update("update guild set today_add_exp = %u, add_exp_time =%d where gid = %u", today_add_exp, now, self.id) then
			self._today_add_exp = today_add_exp;
			self.add_exp_time = now;
		end
	end
}

Guild.wealth = {
	get = "_wealth",
	set = function(self, wealth)
		if self._wealth == wealth then return end
		
		log.debug(string.format("[GUILD] guild %u set wealth %u -> %u", self.id, self._wealth, wealth))
		if database.update("update guild set wealth = %u where gid = %u", wealth, self.id) then
			self._wealth = wealth
		end
	end
}
Guild.add_wealth_time = {
	get = "_add_wealth_time",
	set = function(self, val)
		self._add_wealth_time = val
	end
}
Guild.today_add_wealth = {
	get = function(self)
		local today_begin = get_today_begin_time()
		if self.add_wealth_time >= today_begin then
			return self._today_add_wealth or 0
		else
			return 0
		end
	end,
	set = function(self, today_add_wealth)
		self._today_add_wealth = self._today_add_wealth or 0

		log.debug(string.format("[GUILD] guild %u set today_add_wealth %u -> %u", self.id, self._today_add_wealth, today_add_wealth))
		local now = loop.now()
		if database.update("update guild set today_add_wealth = %u, add_wealth_time = %d where gid = %u", today_add_wealth, now, self.id) then
			self._today_add_wealth = today_add_wealth
			self.add_wealth_time = now
		end
	end
}
Guild.highest_wealth = {
	get = "_highest_wealth",
	set = function(self, value)
		if self._highest_wealth >= value then return end
		
		log.debug(string.format("[GUILD] guild %u set highest_wealth %u -> %u", self.id, self._highest_wealth, value))
		if database.update("update guild set highest_wealth = %u where gid = %u", value, self.id) then
			self._highest_wealth = value 
		end
	end
}

function Guild:AddExp(exp, player, no_log, donate_type)
	local add_exp =exp
	local today_add_exp_old =self.today_add_exp
	local numConfig = GuildNumberConfig[self.level]
	if (today_add_exp_old + add_exp) > numConfig.daily_max_exp then
		add_exp = numConfig.daily_max_exp - today_add_exp_old
	end
	self.today_add_exp =today_add_exp_old + add_exp
	self.exp = self._exp + add_exp;
	rank:setValue(self._id, self._exp);

	if player then
		local cont = player.cont;

		cont.total = cont.total + exp;
		cont.today = cont.today + exp;

		database.update("update guildmember set total_cont = %u, today_cont = %u, cont_time = from_unixtime_s(%u) where gid = %u and pid = %u",
				cont.total, cont.today, loop.now(), self._id, player.id);
		player._cont_time = loop.now();
		player._total_cont = cont.total;
		player._today_cont = cont.today;
	end

    if not no_log and tonumber(add_exp) > 0 then
        -- add exp log
        self.log:push({time = loop.now(), pid = player and player.id or 0, exp = exp, reason = donate_type or 0});
    end

	-- notify event
end

function Guild:AddExpOnly(player, exp, no_log, reason)
	local add_exp =exp
	local today_add_exp_old =self.today_add_exp
	--[[if (today_add_exp_old + add_exp) > GuildConfig.GUILD_MAX_ADD_EXP_PER_DAY then
		add_exp =GuildConfig.GUILD_MAX_ADD_EXP_PER_DAY - today_add_exp_old
	end--]]
	self.today_add_exp =today_add_exp_old + add_exp
	self.exp = self._exp + add_exp;
	rank:setValue(self._id, self._exp);

	 if not no_log and (tonumber(add_exp) > 0) then
         -- add exp log
         self.log:push({time = loop.now(), pid = player and player.id or 0, exp = exp, reason = reason or 0});
     end
end

function Guild:AddWealth(wealth, player)
	local add_wealth = wealth
	self.today_add_wealth = self.today_add_wealth + add_wealth
	self.wealth = self._wealth + add_wealth
	self.highest_wealth = self.wealth
	
	local tb = { player.id, add_wealth }
	log.info(string.format('Added wealth by player %d',player.id))
	AddDynamicLog(ADD_WEALTH,tb,self.id)
end

function Guild:CostWealth(player, val)
	if self.wealth < val then
		log.debug("not enough wealth to cost")
		return false
	else
		self.wealth = self._wealth - val
		return true
	end
end

Guild.level = {
	get = function(self)
		if self._level == nil then
			self._level = getLevel(self._exp);
		end
		return self._level;
	end
};

Guild.rank = {
	get = function(self)
		return rank:getRank(self.id);
	end
}

Guild.name = {
	get = "_name",
}

Guild.founder = {
	get = "_founder",
}

Guild.create_time = {
	get = "_create_time";
}

Guild.mcount = {
	get = "_mcount";
}

Guild.max_mcount = {
    get = function(self)
        local guild_member_level = self.level--(self.level < GuildConfig.GUILD_MAX_MEMBER_LEVEL) and self.level or GuildConfig.GUILD_MAX_MEMBER_LEVEL;
        local max_member_count   = GuildNumberConfig[guild_member_level].MaxNumber--GuildConfig.GuildMemberInitConfig[guild_member_level] + self.member_buy_count;
        return max_member_count
    end
}

Guild.member_buy_count = {
    get = "_member_buy_count";
}

Guild.leader = {
	get = "_leader",

	set = function(self, player)
		if self._leader.id == player.id then return; end

		log.debug(string.format("[GUILD] guild %u set leader %u", self.id, player.id));
		
		if database.update("update guild set leader = %u where gid = %u", player.id, self.id) then
			self._leader = PlayerManager.Get(player.id);
		end
	end
}

Guild.dissolve = {
	get = "_dissolve",
}

Guild.notice = {
	get = "_notice",

	set = function(self, notice)
		--if notice == "" then notice = " " end; -- 最少一个空格
		if self._notice == notice then return; end
		log.debug(string.format("[GUILD] guild %u set notice %s", self.id, notice));

		escaped_notice =string.gsub(notice, "'", "\\'")
		if database.update("update guild set notice = '%s' where gid = %u", escaped_notice, self.id) then
			self._notice = notice;
		end
	end
}

Guild.desc = {
	get = "_desc",
	set = function(self, desc)
		if self._desc == desc then return; end
		log.debug(string.format("[GUILD] guild %u set desc %s", self.id, desc));

		escaped_desc =string.gsub(desc, "'", "\\'")
		if database.update("update guild set `desc` = '%s' where gid = %u", escaped_desc, self.id) then
			self._desc = desc;
		end
	end
}

Guild.boss = {
	get = function(self)
		return self._boss;
	end;

	set = function(self, time)
		local _, ssec = Time.DAY(time);
		local cday, csec = Time.DAY(self._boss);
	
		time = time + (csec - ssec);

		if self._boss == time then return; end

		log.debug(string.format("[GUILD] guild %u set boss %u", self.id, time));
		if database.update("update guild set boss = from_unixtime_s(%u) where gid = %u", time, self.id) then
			self._boss = time;

		end
	end
};

Guild.members = {
	get = "_members",
}

Guild.requests = {
	get = "_requests",
}

Guild.auto_confirm = {
	get = "_auto_confirm", 
	
	set = function(self, auto_confirm)
		if self._auto_confirm == auto_confirm then return end
		
		log.debug(string.format("[GUILD] guild %u set auto_confirm %d", self.id, auto_confirm))
		if database.update("update guild set auto_confirm = %d where gid = %u", auto_confirm, self.id) then
			self._auto_confirm = auto_confirm
		end
	end
}

function Guild:SetAutoConfirm(auto_confirm)
	self.auto_confirm = auto_confirm
	local joinPlayers = {}
	if auto_confirm == 1 then
		AllAutoConfirm[self.id] = self

		for pid, player in pairs(AutoJoinPlayers or {}) do
			if self:Join(player) then
				--AutoJoinPlayers[pid] = nil
				player.auto_join = nil
				table.insert(joinPlayers, player)
			end
		end

	else
		if AllAutoConfirm[self.id] then
			AllAutoConfirm[self.id] = nil
		end
	end	
	return true, joinPlayers
end

-- function
function Guild:Join(player, title)
	assert((player.guild == nil) or not (player.guild.id == self.id))

	title = (title or 0); -- 玩家职位 默认为0
	if (self._mcount >= self.max_mcount) then
		return false;
	end

	local ms = self.members;  --must load member first

	log.debug(string.format("[GUILD] player %u join guild %u", player.id, self.id));
	
	local success, result = database.query("select gid, today_donate_count, reward_flag, unix_timestamp(last_draw_time) as last_draw_time from guildmember where pid = %u", player.id);
	if success then
		if result[1] then
			success = database.update("update guildmember set gid = %u, title = %u, today_cont = 0, cont_time = now(), total_cont = 0  where gid = %u and pid = %u",
				self.id, title, result[1].gid, player.id);
			player._today_donate_count = result[1].today_donate_count 
			player._reward_flag = result[1].reward_flag 
			player._last_draw_time = result[1].last_draw_time 
		else
			success = database.update("insert into guildmember(gid, pid, title, today_cont, cont_time, total_cont, reward_flag, last_draw_time, today_donate_count, donate_time) values(%u, %u, %u, 0, now(), 0, 0, 0,0, 0)",
				self.id, player.id, title);
			player._today_donate_count = 0
			player._reward_flag = 0
			player._last_draw_time = 0
		end
	end
	if success then
		player.guild = self;
		player.title = title;

		rawset(self.members, player.id, player);
		self._mcount = self._mcount + 1;

		self._today_cont = 0;
		self._total_cont = 0;
		self._cont_time  = loop.now();

		if AutoJoinPlayers[player.id] then
			AutoJoinPlayers[player.id] = nil
		end
		local tb = { player.id }
		log.info(string.format('Player %d join in guild %d',player.id,self.id))
		AddDynamicLog(JOIN_GUILD, tb, self.id)
		cell.NotifyQuestEvent(player.id, { { type = 80, id = 1, count = 1 }, })	

		-- 记录一下加入军团的时间
		player.join_time = loop.now()

		return true;
	else
		return false;
	end
end

function Guild:Leave(player)
	assert(player.guild.id == self.id)

	local ms = self.members; --must load members first

	log.debug(string.format("[GUILD] player %u leave guild %u", player.id, self.id));

    --if not delActJoinQueue(player.id, player.guild.id) then
    --    log.debug("fail to player leave , delActJoinQueue failed")
    --    return false;
    --end

	if database.update("update guildmember set gid = 0 where gid = %u and pid = %u", self.id, player.id) then
		player._title = 0;
		player.guild = nil;
		rawset(self.members, player.id, nil);
		self._mcount = self._mcount - 1;

		player._today_cont = nil;
		player._total_cont = nil;
		player._cont_time  = nil;

		if (self.mcount == 0)  then
			self:Dissolve();
		end
		local tb = { player.id }
		log.info(string.format('Player %d leave guild %d',player.id,self.id))
		AddDynamicLog(LEVEL_GUILD, tb,self.id)
		return true;
	else
		return false;
	end
end

--[[local reward_cfg = {
	{
		condition = 100, 
		reward = {
			{type = 41, id = 900003, value = 100},
		}
	},	
	{
		condition = 200, 
		reward = {
			{type = 41, id = 900003, value = 200},
		}
	},	
	{
		condition = 200, 
		reward = {
			{type = 41, id = 900003, value = 300},
		}
	}	
}--]]

function Guild:DrawDonateReward(player, index)
	log.debug(string.format("[GUILD] player %u draw donate reward, index %d", player.id, index))

	local reward_cfg = GetBoxReward(1, self.level, index)
	if not reward_cfg then
		log.debug("reward config is nil")
		return false
	end

	local mask = 2^(index-1)
	log.debug(string.format("today exp %d", self.today_add_exp))
	log.debug(string.format("reward flag %d", player.reward_flag))
	if self.today_add_exp >= reward_cfg.condition and bit32.band(player.reward_flag, mask) == 0 then
		cell.sendReward(player.id, reward_cfg.reward, nil, Command.REASON_GUILD_DONATE_REWARD, false, 0);

		player.reward_flag = bit32.bor(player.reward_flag, mask) 
		player.last_draw_time = loop.now()
		return true
	end

	log.debug("today exp is not enough or already has draw reward")
	return false
end

function Guild:JoinRequest(player)
	log.debug(string.format("[GUILD] player %u request join guild %u", player.id, self.id));

	if database.update("insert into guildrequest(gid, rid) values(%u, %u)", self.id, player.id) then
		rawset(self.requests, player.id, {time = loop.now()});
		return true;
	else
		return false;
	end
end

function AutoJoinRequest(player)
	for gid, v in pairs(AllAutoConfirm or {}) do
		local guild = Get(gid)	
		if guild and guild:Join(player) then
			return true, guild
		end
	end	

	AutoJoinPlayers[player.id] = player		
	player.auto_join = 1

	return true, nil 
end

function CancelAutoJoin(player)
   if AutoJoinPlayers[player.id] then
	   AutoJoinPlayers[player.id] = nil
	   player.auto_join = nil
   end
end

function Guild:RemoveRequest(id)
	log.debug(string.format("[GUILD] guild %u remove request of player %u", self.id, id));

	local player = PlayerManager.Get(id);

	if database.update("delete from guildrequest where gid = %u and rid = %u", self.id, player.id) then
		rawset(self.requests, player.id, nil);
		return true;
	else
		return false;
	end
	return success;
end

function Guild:RemoveAllRequest()
	log.debug(string.format("[GUILD] guild %u remove all requests", self.id));

	if database.update("delete from guildrequest where gid = %u", self.id) then
		self._requests = {};
		return true;
	else
		return false;
	end
end

function Guild:GetRequestsCount()
	local n = 0

	for _, _ in pairs(self._requests or {}) do
		n = n + 1
	end

	return n
end

function Guild:Donate(player, donate_type, guild_add_exp, self_add_exp, guild_add_wealth)
	player.today_donate_count = player.today_donate_count + 1
	self:AddExp(guild_add_exp, player, false, donate_type)
	self:AddWealth(guild_add_wealth,player)
	DonateManager.Donate(player, donate_type, self_add_exp)
	--quest
	cell.NotifyQuestEvent(player.id, {{type = 4, id = 18, count = 1}, {type = 87, id = 1, count = 1}})
end
function Guild:QueryDonate(player, max_count)
	return DonateManager.QueryDonate(player, max_count)	
end
function Guild:HasDonatedToday(player)
	return DonateManager.HasDonatedToday(player)	
end

local dissolved_guild = {};

function Guild:Dissolve()
	log.debug(string.format("[GUILD] guild %u dissolved", self.id));

	if database.update("update guild set dissolve = 1 where gid = %u", self.id) then
		All[self.id] = nil;
		AllName[self.name] = dissolved_guild;
		AllAutoConfirm[self.id] = nil;
		for _, player in pairs(self.members) do
			player.guild = nil;
			player._title = 0;
		end

		rank:remove(self.id);

		--unloadGuild(self);
		return true;
	else
		return false;
	end
end

-- * static
function Create(player, name, camp)
	local now = loop.now();
	-- local cday, csec = Time.DAY(now);
	local yestoday = now - 3600 * 24;
	
	escaped_name =string.gsub(name, "'", "\\'")
	if not database.update("insert into guild(camp, name, leader, founder, boss) values(%u, '%s', %u, %u, from_unixtime_s(%u))",
		camp,escaped_name, player.id, player.id, yestoday) then
		return nil;
	end

	local id = database.last_id();

	local guild = Class.New(Guild, id);
	if guild then
		guild:Join(player, 2);
		All[id] = guild;
		AllName[name] = guild;
	end
	return guild;
end

function Get(id)
	return All[id];
end

-- 获取可以加入的军团id
function GetJoinGuild()	
	local guild_list = {}

	for _, guild in pairs(All) do
		if guild.mcount + guild:GetRequestsCount() < guild.max_mcount * 0.3 then
			table.insert(guild_list, guild)
		end
	end

	table.sort(guild_list, function (g1, g2)
		local i = is_online(g1.leader) and 1 or 0
		local j = is_online(g2.leader) and 1 or 0
		local n1 = g1:GetRequestsCount()
		local n2 = g2:GetRequestsCount()

		if g1.mcount ~= g2.mcount then
			return g1.mcount < g2.mcount
		elseif n1 ~= n2 then
			return n1 < n2
		else
			return i > j
		end
	end)
	
	return guild_list	
end

function GetByName(name)
--[[
    log.info("guild name is ".. name);
    for k, v in pairs(AllName) do
        log.info(string.format("guild gid is %s, name is %s",v.id,v.name))
    end
--]]

	local guild = AllName[name];
	if guild == dissolved_guild then
		return nil;
	end

	return guild;
end

function IsExist(name)
	return AllName[name];
end

function SearchByName(name)
    if not name or name == "" then
        return {};
    end
    local t = {}
    for k, v in pairs(AllName) do
		if v ~= dissolved_guild then
			ok, _ = string.find(v.name, name)
			if ok and v ~= dissolved_guild then
				table.insert(t, v.id)
			end
		end
    end
    return t
end

function SearchByID(id)
	local guild = All[id]	
	local t = {}
	if guild and guild.dissolve ~= 1 then
		table.insert(t, guild.id)
	end
	return t
end

function NextID(key)
	return next(All, key);
end


local function loadFromDBByGID(...)
	local success, result = database.query(...);
	if not success then
		log.error(result);
		return nil
	end

	local list = {}
	for _, v in ipairs(result) do
		local k = v.gid;

		list[k] = list[k] or {}
		table.insert(list[k], v);
	end
	return list
end

function LoadAll()
	All = {};
	AllName = {};

	local explog   = loadFromDBByGID("select gid, id, unix_timestamp(time) as time, pid, exp, reason from guild_exp_log");
	assert(explog);

	local requests = loadFromDBByGID("select gid, rid, unix_timestamp(`at`) as time from guildrequest");
	assert(requests);

	local members  = loadFromDBByGID("select gid, pid, title, total_cont, today_cont, unix_timestamp(cont_time) as cont_time, reward_flag, unix_timestamp(last_draw_time) as last_draw_time, today_donate_count, unix_timestamp(donate_time) as donate_time from guildmember");
	assert(members);

	local infos    = loadFromDBByGID("select gid, name, exp, today_add_exp, add_exp_time, founder, leader, unix_timestamp(createat) as createat, member_buy_count, unix_timestamp(boss) as boss, notice, `desc`, dissolve, auto_confirm, wealth, today_add_wealth, add_wealth_time, highest_wealth from guild");
	assert(infos);

	-- local success, result = database.query("select gid, name, dissolve, auto_confirm from guild");
	-- assert(success);
	
	for _, row in pairs(infos) do
		local info = row[1];
		if info.dissolve ~= 0 then
			AllName[info.name] = dissolved_guild;
		else
			local gid = info.gid;
			local guild = Class.New(Guild, gid, {
				explog = explog[gid] or {},
				info   = row,
				member = members[gid] or {},
				request = requests[gid] or {},
			});

			if guild then
				All[guild.id] = guild;
				AllName[guild.name] = guild;
			end

			if guild and info.auto_confirm == 1 then
				AllAutoConfirm[guild.id] = guild
			end
		end
	end
end

function Guild:AddMemberBuyCount(player)
	if (self.member_buy_count + 1 > GuildConfig.GUILD_MAX_MEMBER_BUY_COUNT) then
        log.error("[Guild:AddMemberCount], buy count > 10 now");
		return false;
	end
    local old_member_count = self._member_buy_count;
    local target_member_count = self._member_buy_count + 1;
	local success, result = database.query("update guild set member_buy_count = %d where gid = %d", target_member_count, self.id);
	if success then
        self._member_buy_count = target_member_count; 
        log.info(string.format("[Guild:AddMemberCount] %d buy member count for %d,  %d -> %d", player.id or -1, self.id or -1 , old_member_count or -1, target_member_count or -1));
        return true;
    else
        log.error(string.format("[Guild:AddMemberCount], update database fail gid = %d, pid = %d",self.id or -1,  player.id or -1));
		return false;
	end
end

function Guild:IsFull()
    return self.mcount >= self.max_mcount
end

local function go(proc, ...)
	local co = coroutine.create(proc);
	local success, info = coroutine.resume(co, ...);
	if not success then
		log.error(info);
	end
	return success;
end

--[[
local function CreateGuildBoss(now)
	local cday, csec = Time.DAY(now);

	local createList = {};
	local count = 0;
	for _, guild in pairs(All) do
		local gday, _ = Time.DAY(guild._boss);
		if (gday < cday) and (not guild._creating_boss) then
			createList[guild.id] = guild;
			guild._creating_boss = true;
			-- 一次只创建一个军团
			break;
		end
	end

	local time = now - csec + 17 * 3600; -- start at 17:00
	for _, guild in pairs(createList) do
		local respond = SocialManager.createBoss("BOSS_TYPE_GUILD", guild.id, 0, time);
		if respond and respond.result == Command.RET_SUCCESS then
			log.debug(string.format('guild %d create boss %u success', guild.id, time));
			-- 更新下时间
			guild.boss = now;
		else
			log.warning(string.format("guild %d create boss %u failed", guild.id, time));
		end
		guild._creating_boss = nil;
	end
end
--]]

function GetTopKGuild()
    return rank:GetTopK()
end

function is_leader(player)
	return player.title ~= 0 and player.title <= 10
end
function is_online(player)
	return player.online
end
function is_offline(player)
	return not player.online
end
local g_last_check_time =0
Scheduler.Register(function(now)
	local H24 =24 * 3600;
	local H48 =48 * 3600;
	local H72 =72 * 3600;
	_now = now;
	local elapse =now - g_last_check_time
	local tm =os.date("*t", now)
	if elapse >= H24 and (tm.hour>0 and tm.hour<=1) then
		tm.hour =0
		tm.min =0
		tm.sec =0
		g_last_check_time =os.time(tm)
		pm("成员变动", nil, "开始检查军团长在线");
		local co = coroutine.create(function()
			for _, guild in pairs(All) do
				log.debug(string.format("军团 %d 尝试人员变动", guild.id))
				if guild.leader.login and guild.leader.login ~= 0 then
					if  ((_now - guild.leader.login) > H48) and is_offline(guild.leader) then
						log.debug(string.format("军团 %d 尝试提拔副军团长", guild.id))
						-- 准备候选人
						local need_promote_second_leader =true
						for _, member in pairs(guild.members) do
							if is_leader(member) and (member.id ~= guild.leader.id) and (((_now-member.login) < H24) or is_online(member)) then
								need_promote_second_leader =false
								log.debug(string.format("军团 %d 人事变动取消, 副军团长%s %d在线或者24小时内登陆过", guild.id, member.name, member.id))
								break
							end
						end
						local candidate_list ={}
						if need_promote_second_leader then
							for _, member in pairs(guild.members) do
								if (not is_leader(member)) and (((_now-member.login) < H24) or is_online(member)) then
									table.insert(candidate_list, { id =member.id, donate =(member._total_cont or 0) })
								end
							end
						end
						table.sort(candidate_list, function(a, b) return a.donate>b.donate; end)
						log.debug(string.format("军团 %d, 副团长候选人数%d", guild.id, #candidate_list))
						for i=1, #candidate_list do
							log.debug(string.format("军团 %d, 副团长候选人%d", guild.id, candidate_list[i].id))
						end
						-- 提升副军团长
						local candidate_cnt =math.min(2, #candidate_list)
						if candidate_cnt > 0 then
							for i=1, candidate_cnt do
								local candidate_id =candidate_list[i].id
								local member =guild.members[candidate_id]
								member.title =2
								EventManager.DispatchEvent("GUILD_SET_TITLE", {guild = guild, player = member, by_system =true});
								log.debug(string.format("军团 %d 人事变动, %s %d 成为副军团长", guild.id, member.name, member.id))
							end
						end
					else
						log.debug(string.format("军团 %d 人事变动取消, 军团长%s %d在线或者48小时内登陆过", guild.id, guild.leader.name, guild.leader.id))
					end
					if ((_now-guild.leader.login) > H72) and is_offline(guild.leader) then
						log.debug(string.format("军团 %d 尝试更换军团长", guild.id))
						-- 准备候选人
						local best_candidate =nil
						for _, member in pairs(guild.members) do
							if (member.id ~= guild.leader.id) and is_leader(member) and (((_now-member.login) < H24) or is_online(member)) then
								local candidate ={ id =member.id, donate =(member._total_cont or 0) }
								if not best_candidate then
									best_candidate =candidate
								elseif candidate.donate > best_candidate.donate then
									best_candidate =candidate
								end
								break
							end
						end
						log.debug(string.format("军团 %d, 军团长候选人%d", guild.id, (best_candidate and best_candidate.id or 0)))
						-- 提升军团长
						if best_candidate then
							log.debug(string.format("军团 %d 人事变动, %s %d 被降职成为副军团长", guild.id, guild.leader.name, guild.leader.id))
							local candidate_id =best_candidate.id
							local member =guild.members[candidate_id]
							local old_leader =guild.leader
							guild.leader = member;
							old_leader.title =2
							EventManager.DispatchEvent("GUILD_SET_TITLE", {guild = guild, player = old_leader, by_system =true});
							EventManager.DispatchEvent("GUILD_SET_TITLE", {guild = guild, player = guild.leader, by_system =true});
							EventManager.DispatchEvent("GUILD_SET_LEADER", {guild = guild, by_system =true});
							log.debug(string.format("军团 %d 人事变动, %s %d 成为军团长", guild.id, guild.leader.name, guild.leader.id))
						end
					else
						log.debug(string.format("军团 %d 人事变动取消, 军团长%s %d在线或者72小时内登陆过", guild.id, guild.leader.name, guild.leader.id))
					end
				end
			end
		end);
		local status, info = coroutine.resume(co);
		if not status then
			print(info);
		end
	end
end);

LoadAll();
