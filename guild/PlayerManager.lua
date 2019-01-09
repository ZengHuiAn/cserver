local Class = require "Class"
local cell = require "cell"
local database = require "database"
local loop = loop;
local log = log;
local string = string;
local tonumber = tonumber;
local Time = require "Time"
local SocialManager = require "SocialManager"
local GuildConfig = require "GuildConfig"
--local limit = require "limit"
local Command = require "Command"
require "DonateManager"
local get_donate = DonateManager.get_donate
local StableTime =require "StableTime"
local stable_time =StableTime.stable_time
local get_today_begin_time =StableTime.get_today_begin_time
require "printtb"
local sprinttb = sprinttb

module "PlayerManager"

SocialManager.Connect("Arena");

local All = {};

local Player = {}

function Player:_init_(id)
	self._id = id;
	self._update_time = loop.now();
    self._unload_level_time = 0;
	All[id] = self;
end

local function unloadPlayerInfo(player)
	player._name  = nil;
	player._level = nil;
	player._login = nil;
    player._vip   = nil;
	-- player._country = nil;
	player._arena_order = nil;
    --player._reward_flag = nil;
    --player._reward_flag_dirty_time = nil;
end

local function loadPlayerInfo(player)
	--log.debug(string.format("loadPlayerInfo %u", player.id));
	local respond = cell.getPlayer(player.id);
	if respond and respond.result == Command.RET_SUCCESS then
		player._name  = respond.player.name;
		player._level = respond.player.level;
        player._vip   = respond.player.vip;
		local t = respond.player.login;
		if t < respond.player.logout then
			t = respond.player.logout;
		end
		player._login = t;
		player._update_time = loop.now();

        --[[if not player._reward_flag or not player._reward_flag_dirty_time then
            local ok, result = database.query("select reward_flag, reward_flag_dirty_time from guild_activity_reward_record where pid = %d",player.id);
            if ok and #result >= 1 then
                player._reward_flag = result[1].reward_flag;
                player._reward_flag_dirty_time = result[1].reward_flag_dirty_time;
            else
                database.update("insert into guild_activity_reward_record(pid, reward_flag, reward_flag_dirty_time) values(%d, %d, %d)", player.id, 0,loop.now() );
                player._reward_flag = 0;
                player._reward_flag_dirty_time = loop.now();
            end
        end]]
		return true;
	else
		return false;
	end
end

--- * property
Player.id = {
	get = "_id";
}

local function checkAndLoad(player, key)
	if player[key] == nil or key == '_vip' then
		loadPlayerInfo(player);
	end
	return player[key];
end

Player.name = {
	get = function (self)
		return checkAndLoad(self, "_name");
	end
}

Player.level = {
	get = function(self)
		return checkAndLoad(self, "_level");
	end
}


--[[Player.reward_flag = {
	get = function(self)
		return checkAndLoad(self, "_reward_flag");
	end,

    set = function(self, reward_flag)
        if database.update("update guild_activity_reward_record set reward_flag = %d, reward_flag_dirty_time = %d where pid = %d", reward_flag, loop.now() ,self.id) then
            self._reward_flag = reward_flag;
            self._reward_flag_dirty_time = loop.now();
        end
    end
}--]]

--[[Player.reward_flag_dirty_time = {
	get = function(self)
		return checkAndLoad(self, "_reward_flag_dirty_time");
	end
}--]]

Player.title = {
	get = function(self)
		-- 团长title 1
		if self.guild and self.guild.leader.id == self.id then
			return 1;
		end

		return self._title;
	end,

	set = function(self, title)
		if title == 1 then
			title = 2;
		end
		if self._title == title then return; end

		if database.update("update guildmember set title = %u where pid = %u and gid = %u", title, self.id, self.guild.id) then
			self._title = title;
		end
	end
}

Player.cont = {
	get = function(self)
		if self._today_cont == nil then
			return {total = 0, today = 0};
		end

		local cday = Time.DAY(loop.now());
		local xday = Time.DAY(self._cont_time);
		if (cday ~= xday) then
			return {total = self._total_cont, today = 0};
		end

		return {total = self._total_cont, today = self._today_cont};
	end
};


Player.vip = {
    get = function(self)
        return checkAndLoad(self, "_vip");
    end
}

Player.login = {
	get = function(self)
		return checkAndLoad(self, "_login");
	end
};

Player.reward_flag = {
	get = function(self)
		local cday = Time.DAY(loop.now());
		local xday = Time.DAY(self._last_draw_time);
		if cday ~= xday then
			return 0
		else
			return self._reward_flag
		end	
	end,

	set = function(self, flag)
		if self._reward_flag == flag then return end

		if database.update("update guildmember set reward_flag = %u where pid = %u and gid = %u", flag, self.id, self.guild.id) then
			self._reward_flag = flag
		end
	end
}

Player.last_draw_time = {
	get = function(self)
		return self._last_draw_time
	end,

	set = function(self, time)	
		if self._last_draw_time == time then return end

		if database.update("update guildmember set last_draw_time = from_unixtime_s(%d) where pid = %u and gid = %u", time, self.id, self.guild.id) then
			self._last_draw_time = time
		end
	end
}

Player.today_donate_count = {
	get = function(self)
		local cday = Time.DAY(loop.now());
		local xday = Time.DAY(self._donate_time);
		if cday ~= xday then
			return 0
		else
			return self._today_donate_count
		end
	end,
	
	set = function(self, count)
		--if self._today_donate_count == count then return end

		if database.update("update guildmember set today_donate_count = %d, donate_time = from_unixtime_s(%d) where pid = %u and gid = %d", count, loop.now(), self.id, self.guild.id) then
			self._today_donate_count = count
			self._donate_time = loop.now()
		end
	end
}

--[[
Player.country = {
	get = function(self)
		return checkAndLoad(self, "_country");
	end
};
]]

Player.arena_order = {
	get = function(self)
		--[[
		if self._arena_order == nil then
			self._arena_order = SocialManager.getArenaOrder(self._id);
		end
		--]]
		return self._arena_order or 0;
	end
}


--[[Player.online = {
	get = function (self)
		if self._online == nil then
			loadPlayerInfo(self);
		end
		return self._online;
	end
}--]]


-- * static
--[[
function New(...)
	return Class.New(Player, ...)
end
--]]

local timeout_player_data = 5 * 60;

function Get(id)
	local player = All[id];
	if player == nil then
		player = Class.New(Player, id);
        return player;
	end

    --[[if player._level then--and not limit.check(33, player._level, player._vip) then
		unloadPlayerInfo(player);
	end--]]

	if player and player._update_time + timeout_player_data < loop.now() then
		unloadPlayerInfo(player);
	end
	
	return player;
end


function Login(id, conn)
	local player = Get(id);	
	unloadPlayerInfo(player);
	player.online = true;
	player.conn = conn;
end

function Logout(id)
	local player = Get(id)
	player.online = false;
	player.conn = nil;
end
