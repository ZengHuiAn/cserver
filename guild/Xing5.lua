require "log"
require "database"
require "EventManager"
require "PlayerManager"
require "cell"
--local aiserver =require "aiserver"
require "printtb"
require "SocialManager"
require "GuildManager"
require "Command"
require "Time"

local Class = require "Class"
--------------------------------------------------------------------------------
-- config
local MAX_SLOT = 5;

local Xing5BuyConsume = {{type = 41, id = 90002, value = 10}};

local function Xing5Reward(guildLv)
	return {{ type =Command.REWARD_TYPE_RESOURCE, id = Command.RESOURCES_GERENGONGXIAN, value = 250}}, 250
end
--------------------------------------------------------------------------------
-- logic
local Xing5Class = {};
function Xing5Class:_init_(gid)
	log.debug("Xing5Class:_init_", gid);
	self.id   = gid;
	self.slot = {};
end

function Xing5Class:Have(pid)
	for i = 1, MAX_SLOT do
		if self.slot[i] and self.slot[i].id == pid then
			return true;
		end
	end
	return false;
end

function Xing5Class:IsFull()
	for i = 1, MAX_SLOT do
		if self.slot[i] == nil then
			return false;
		end
	end
	return true;
end

function Xing5Class:Join(pid, name)
	log.debug("Xing5Class:Join", self.id, pid, name);

	if pid > 0 then
		if self:Have(pid) then
			log.debug("", "already join");
			return true;
		end
	end

	for i = 1, MAX_SLOT do
		if self.slot[i] == nil then
			log.debug("", "pos", i);
			self.slot[i] = {
				id   = pid,
				name = name,
			};
			if i == MAX_SLOT then
				self:Reward();
			else
				EventManager.DispatchEvent("GUILD_5XING_CHANGE", self);
			end
			--cell.addActivityPoint(pid, Command.ACTIVITY_GUILD_5XING, 1);
			return true;
		end
	end
	return false;
end

function Xing5Class:Leave(pid)
	for i = 1, MAX_SLOT do
		if self.slot[i] and self.slot[i].id == pid then
			local v = self.slot[i];
			table.remove(self.slot, i);
			log.debug("Xing5Class:Leave", self.id, i, v.id, v.name);
			EventManager.DispatchEvent("GUILD_5XING_CHANGE", self);
			return;
		end
	end
end

function Xing5Class:Reset()
	self.slot = {};
	EventManager.DispatchEvent("GUILD_5XING_CHANGE", self);
end

function Xing5Class:ReducePlayerLeftInfo(player)
	if player.id == 0 then
		return;
	end

	player._xing5_time = loop.now();
	EventManager.DispatchEvent("GUILD_5XING_PLAYER_INFO_CHANGE", self, player);
end

function Xing5Class:Reward()
	log.debug("Xing5Class:Reward", self.id);
	local now = loop.now();
	local cday = Time.DAY(now);
	-- get the reward
	local rewards = {};
	for i = 1, MAX_SLOT do
		if self.slot[i] and self.slot[i].id ~= 0 then
			local player = PlayerManager.Get(self.slot[i].id);
			local guildLevel = player.guild.level;
			local day = Time.DAY(player._xing5_time or 0);
			if day < cday then
				local reward, guild_exp = Xing5Reward(guildLevel);
				player.guild:AddExp(guild_exp, player)
				self:ReducePlayerLeftInfo(player);
				rewards[i] = {id = player.id, name = player.name, reward = reward};

				EventManager.DispatchEvent("GUILD_DONATE", {guild = player.guild, donate= { type =0, pid =player.id, exp_current =player.guild.exp, exp_change =guild_exp }});
			end
		end
	end
	
	-- reset
	EventManager.DispatchEvent("GUILD_5XING_CHANGE", self);
	self:Reset();

	-- send reward
	for _, v in pairs(rewards) do
		cell.sendReward(v.id, v.reward, nil, Command.CHARGE_TYPE_GUILD_XING5);
		for i=1, #v.reward do
			local item =v.reward[i]
			v.reward[i] ={ item.type, item.id, item.value }
		end
	end
	EventManager.DispatchEvent("GUILD_5XING_REWARD", self, rewards);
end

local function New(...)
	return Class.New(Xing5Class, ...);	
end

--------------------------------------------------------------------------------
-- interface

local msgRoute = {};

local function sendClientRespond(conn, cmd, channel, msg)
	assert(conn);
	assert(cmd);
	assert(channel);
	assert(msg and (table.maxn(msg) >= 2), debug.traceback());

	local code = AMF.encode(msg);
	--log.debug(string.format("send %d byte to conn %u", string.len(code), conn.fd));
	log.debug("sendClientRespond", cmd, string.len(code));

	local sid = tonumber(bit32.rshift_long(channel, 32))
	assert(sid > 0, "sid == 0")

	if code then conn:sends(1, cmd, channel, sid, code) end
end

local function getXingByPlayer(pid)
	local player = PlayerManager.Get(pid);

	-- 玩家不存在
	if player == nil or player.name == nil then
		return nil, Command.RET_CHARACTER_NOT_EXIST;
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		return nil, Command.RET_GUILD_NOT_EXIST;
	end

	local guild = player.guild;
	if guild.xing == nil then
		guild.xing = New(guild.id);
	end

	return guild.xing;
end

local function getPlayerLeftTimes(rtime, cday)
	log.debug("getPlayerLeftTimes", rtime, cday);
	local day = Time.DAY(rtime or 0);	
	local cday = cday or Time.DAY(loop.now());
	return (day < cday) and 1 or 0;
end

local function buildXing5SlotInfo(xing)
	local msg = {};
	local cday = Time.DAY(now);
	for _, v in pairs(xing.slot) do
		if v.id == 0 then
			table.insert(msg, {v.id, v.name, 0});
		else
			local player = PlayerManager.Get(v.id);
			if player then
				local left = getPlayerLeftTimes(player._xing5_time, cday);
				table.insert(msg, {v.id, v.name, left});
			end
		end
	end
	return msg;
end

msgRoute[Command.C_GUILD_5XING_QUERY_REQUEST] = function (conn, channel, request)
	local sn = request[1] or 0;
	log.debug(string.format("onGuild5XingQuery sn %u", sn));

	local cmd = Command.C_GUILD_5XING_QUERY_RESPOND;

	local xing, err = getXingByPlayer(channel);
	if err then
		return sendClientRespond(conn, cmd, channel, {sn, err});
	end

	local player = PlayerManager.Get(channel);
	local msg = {
		sn,
		Command.RET_SUCCESS,
		getPlayerLeftTimes(player._xing5_time or 0),
		Xing5BuyConsume[1].value
	};
	sendClientRespond(conn, cmd, channel, msg);
end

msgRoute[Command.C_GUILD_5XING_QUERY_SLOT_REQUEST] = function (conn, channel, request)
	local sn = request[1] or 0;
	log.debug(string.format("onGuild5XingQuery sn %u", sn));

	local cmd = Command.C_GUILD_5XING_QUERY_SLOT_RESPOND;

	local xing, err = getXingByPlayer(channel);
	if err then
		return sendClientRespond(conn, cmd, channel, {sn, err});
	end

	local msg = {
		sn,
		Command.RET_SUCCESS,
		buildXing5SlotInfo(xing)
	};
	sendClientRespond(conn, cmd, channel, msg);
end

msgRoute[Command.C_GUILD_5XING_JOIN_REQUEST] = function (conn, channel, request)
	local sn = request[1] or 0;
	log.debug(string.format("onGuild5XingJoin sn %u", sn));

	local cmd = Command.C_GUILD_5XING_JOIN_RESPOND;

	local xing, err = getXingByPlayer(channel);
	if err then
		return sendClientRespond(conn, cmd, channel, {sn, err});
	end

	local player = PlayerManager.Get(channel);

	local result = Command.RET_SUCCESS;
	if xing:Have(player) then
		result = Command.RET_SUCCESS;
	else
		result = xing:Join(player.id, player.name) and Command.RET_SUCCESS or Command.RET_ERROR;
	end
	assert(result);
	sendClientRespond(conn, cmd, channel, {sn, result});

	-- ai patch
	if result == Command.RET_SUCCESS then
		--aiserver.NotifyAIAction(channel, Command.ACTION_GUILD_JOIN_5XING)
	end
end

msgRoute[Command.C_GUILD_5XING_BUY_REQUEST] = function(conn, channel, request)
	-- return sendClientRespond(conn, cmd, id, {sn, Command.RET_ERROR});
	local sn = request[1] or 0;
	log.debug(string.format("onGuild5XingJoin sn %u", sn));

	local cmd = Command.C_GUILD_5XING_BUY_RESPOND;

	local xing, err = getXingByPlayer(channel);
	if err then
		log.debug("", "get slot failed");
		return sendClientRespond(conn, cmd, channel, {sn, err});
	end

	local player = PlayerManager.Get(channel);

	if not xing:Have(player.id) then
		log.debug("", "player not join");
		return sendClientRespond(conn, cmd, channel, {sn, Command.RET_GUILD_5XING_PLAYER_NOT_JOIN});
	end

	-- TODO: add lock
	local respond = cell.sendReward(channel, nil, Xing5BuyConsume, Command.CONSUME_TYPE_GUILD_XING5);
	print(respond);
	if respond == nil or respond.result ~= Command.RET_SUCCESS then
		log.debug("", "consume failed", respond and respond.result or "<nil>");
		return sendClientRespond(conn, cmd, channel, {sn, Command.RET_RESOURCE_MONEY_NOT_ENOUGH_2});
	end
	log.debug("Buy.1")
	local ret = xing:Join(0, "假人", 1) and Command.RET_SUCCESS or Command.RET_ERROR;
	log.debug("Buy.2")
	sendClientRespond(conn, cmd, channel, {sn, ret});
	log.debug("Buy.3")
end

----server_notify_54首次封魔
----server_notify_53五行阵阵容（人数）变化

local function getMessageRoute()
	return msgRoute;
end

--------------------------------------------------------------------------------
-- event
local function sendNotifyToMembers(guild, cmd, msg)
	local pids = {};
	for _, m in pairs(guild.members) do
		table.insert(pids, m.id);
	end
	NetService.NotifyClients(cmd, msg, pids);
end

local function sendNotifyToPlayers(cmd, msg, pids)
	NetService.NotifyClients(cmd, msg, pids);
end


local function sendNotifyToPlayer(player, cmd, msg)
	if player and player.conn then
		print('sendNotifyToPlayer');
		player.conn:sends(1, Command.C_PLAYER_DATA_CHANGE, player.id,
				AMF.encode({0, Command.RET_SUCCESS,
				{cmd, msg}}));
	end
end

local listener = EventManager.CreateListener("guild_5xing_event_listener");
listener:RegisterEvent("GUILD_5XING_CHANGE", function (event, xing)
	local guild = GuildManager.Get(xing.id);
	if guild == nil then
		return;
	end

	local cmd = Command.NOTIFY_GUILD_5XING_CHANGE;
	local msg = buildXing5SlotInfo(xing)

	sendNotifyToMembers(guild, cmd, { msg });
end);

listener:RegisterEvent("GUILD_5XING_REWARD", function(event, xing, rewards)
	local cmd = Command.NOTIFY_GUILD_5XING_REWARD;
	local msg = {};
	local pids = {};
	for _, v in pairs(rewards) do
		table.insert(msg, {v.id, v.name, v.reward })
		table.insert(pids, v.id);
	end

	log.debug("send reward notify", xing.id, unpack(pids));
	log.debug(sprinttb(msg))
	for k, v in pairs(pids) do
		SocialManager.sendRecordNotify(v, cmd, {msg});
	end
end);

listener:RegisterEvent("GUILD_5XING_PLAYER_INFO_CHANGE", function(event, xing, player)
	local cmd = Command.NOTIFY_GUILD_5XING_PLAYER_TIMES_CHANGE;

	if player and player.id > 0 then
		sendNotifyToPlayer(player, cmd, {getPlayerLeftTimes(player._xing5_time or 0), 10});
	end
end);

-- 用户退出军团，离开五行阵
listener:RegisterEvent("GUILD_LEAVE", function(event, info)
	local guild = info.guild;
	if guild and guild.xing then
		guild.xing:Leave(info.player.id);
	end
end);

module(...)

GetMessageRoute = getMessageRoute;
