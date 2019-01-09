local loop = loop;
local log = log;
local string = string;
local tonumber = tonumber;
local pairs = pairs;
local assert = assert;
local table = table;

local Class = require "Class"
local cell = require "cell"
local database = require "database"
local AMF = require "AMF";
local NotifyMessage = require "NotifyMessage"
local SocialManager = require "SocialManager"
local Command = require "Command"

local bit32 = require "bit32"

module "PlayerManager"

SocialManager.Connect("Guild");

local All = {};

local Player = {}

local gPlayer = {};

function GetPartPlayer()
    return gPlayer;
end

function Player:_init_(id)
	--log.debug("Player:_init_");
	self._id = id;
	self._update_time = loop.now();
	All[id] = self;
end

local function unloadPlayerInfo(player)
	player._name = nil;
	player._level = nil;
	player._country = nil;
	player._status = nil;
	player._sex = nil;
	player._guild = nil;
end

local function loadPlayerInfo(player)
	log.debug(string.format("loadPlayerInfo %u", player.id));
	local respond = cell.getPlayer(player.id);
	if respond and respond.result == Command.RET_SUCCESS then
		player._name = respond.player.name;
		player._level = respond.player.level;
		player._sex = respond.player.sex;
		player._country = respond.player.country;
		player._update_time = loop.now();
		player._status = respond.player.status;
		return true;
	else
		return false;
	end
end

local function loadPlayerGuildInfo(player)
	local success, reply = database.command("HMGET guild:player:%u title ", player.id);
	if success then
		player._title = tonumber(reply[1] or 0);
	end
end

--- * property
Player.id = {
	get = "_id";
}

Player.name = {
	get = function (self)
		if self._name == nil then
			loadPlayerInfo(self);
		end
		return self._name;
	end
}

Player.level = {
	get = function(self)
		if self._level == nil then
			loadPlayerInfo(self)
		end
		return self._level;
	end
}

Player.sex = {
	get = function(self)
		if self._sex == nil then
			loadPlayerInfo(self)
		end
		return self._sex;
	end
};


Player.country = {
	get = function(self)
		-- 未选择国家的30秒更新一次
		if self._country == 0 and self._update_time < loop.now() - 30 then
			unloadPlayerInfo(self);
		end

		if self._country == nil then
			loadPlayerInfo(self)
		end
		return self._country;
	end
}

Player.guild = {
	get = function(self)
		if self._guild == nil then
			local respond = SocialManager.getGuild(self.id);
			if respond then
				self._guild = {
					id = respond.guild.id,
					name = respond.guild.name,
				}
			else
				log.debug("getPlayerGuildID failed");
				self._guild =  { id = 0; }
			end
		end
		return self._guild;
	end
}

Player.status = {
	get = function(self)
		-- 封号状态60s一次更新
		if (self._country == nil) or ((self._update_time + 60) < loop.now()) then
			loadPlayerInfo(self)
		end
		return self._status;
	end
}

-- * static
--[[
function New(...)
	return Class.New(Player, ...)
end
--]]

local timeout_player_data = 5 * 60;

local PlayerSystem = {
	id      = 0;
	name    = "system";
	level   = 100;
	country = 4;
	status  = 0;
};


function Get(id)
	if id == 0 then
		return 	PlayerSystem;
	end
	
	local player = All[id];
	if player == nil then
		player = Class.New(Player, id);
		--[[
		if not loadPlayerInfo(player) then
			player = nil;
			All[id] = nil;
		end
		--]]
	end

	if player and player._update_time + timeout_player_data < loop.now() then
		unloadPlayerInfo(player);
	end
	return player;
end


function GetByName(name)
	log.debug(string.format("loadPlayerInfoByName %s", name));
	local respond = cell.getPlayer(nil, name);
	if respond and respond.result == Command.RET_SUCCESS then
		return Get(respond.player.id);
	else
		return nil;
	end
end

function Login(pid, conn)
	local player = Get(pid);
	player.conn = conn;

    	local flag = false;
    	for _, v in pairs(gPlayer) do
		if v == pid then
           		flag = true;
			break
		end
	end
	if not flag then
        	if #gPlayer + 1 > 100 then
            		table.remove(gPlayer, 1);
        	end
        	table.insert(gPlayer, pid);
    	end

	return player;
end

function Logout(pid)
	local player = All[pid];
	if player then
		if player.messages then
			for _, msg in pairs(player.messages) do
				msg:Save();
			end
		end
		unloadPlayerInfo(player);
		player.conn = nil;
	end
end

--[[
local function sendClientRespond(conn, cmd, channel, msg)
	assert(conn);
	assert(cmd);
	assert(channel);
	assert(msg and (table.maxn(msg) >= 2));

	local code = AMF.encode(msg);
	log.debug("sendClientRespond", cmd, string.len(code));

	if code then conn:sends(1, cmd, channel, code) end

	return true;
end
--]]

-- 发送二进制消息
function Player:NotifyCode(cmd, code, flag)
	flag = flag or 1;
        if self.conn == nil then return nil; end

		local sid = tonumber(bit32.rshift_long(self.id, 32))
        self.conn:sends(flag, cmd, self.id, sid, code);
        return true;
end

-- 发送数组消息
function Player:Notify(cmd, msg)
        if self.conn == nil then return nil; end

	log.debug(string.format("send notify message to player %u", self.id));

	-- player:AddNotifyMessage(Command.C_PLAYER_DATA_CHANGE, AMF.encode({0, Command.RET_SUCCESS,
	--				       {Command.NOTIFY_DISPLAY_MESSAGE, {1, "欢迎光临"}}}));

	local sid = tonumber(bit32.rshift_long(self.id, 32))
	assert(sid > 0)
        self.conn:sends(1, Command.C_PLAYER_DATA_CHANGE, self.id, sid, AMF.encode({0, Command.RET_SUCCESS,
						{cmd, msg}}));
        return true;
end

local function loadNotifyMessageByPID(pid)
	local msgs = NotifyMessage.LoadByPlayerID(pid);
	if msgs == nil then
		return nil;
	end

	local t = {};
	for _, msg in pairs(msgs) do
		msg.tid = #t + 1;
		t[msg.tid] = msg;
	end
	return t;
end

Player.messages = {
	get = function(self)
		if self._messages == nil then
			self._messages = loadNotifyMessageByPID(self.id);
		end
		return self._messages;
	end,
};

function Player:AddNotifyMessage(type, data)
	local message = NotifyMessage.New(self.id, type, data);
	if message == nil then
		return false;
	end

	-- try to send 
	if self:NotifyCode(type, data) then
		return true;
	end

	-- send failed, save it
	message.tid = #(self.messages) + 1;
	self.messages[message.tid] = message;
	message:Save();
	return true;
end

function Player:RemoveNotifyMessage(message)
	-- remove from player list
	self.messages[message.tid] = nil;

	-- delete from database
	message:Delete();
end
