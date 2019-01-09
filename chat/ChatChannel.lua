local Class = require "Class"
local Command = require "Command"
local AMF = require "AMF"
local Scheduler = require "Scheduler"

local log = log;
local setmetatable = setmetatable;
local assert = assert;
local string = string;
local cell = cell;
local pairs = pairs;
local rawset = rawset;
local table = table;
local os = os;
local next = next;
local string = string;
local util  =require "util"

local NetService = require "NetService"
local ChatConfig = require "ChatConfig"
local database = require "database"


module "ChatChannel"

local all = {};

local Channel = {};

local meta_unsetable = {
	__newindex = function(self, k, v)
		assert(false, "can't set member directly")
	end;
}

function Channel:_init_(id, type)
	log.debug(string.format("create new channel %u", id));
	self._id = id;
	self._type = type;
	self.members = {};
	setmetatable(self.members, meta_unsetable);

	-- load history
	self.history ={}
	local ok, rows =database.query("SELECT `uuid`, `from_player_id`, `from_player_name`, `rid`, `message`, unix_timestamp(`t`) as t FROM `chat_history` WHERE `id`=%d ORDER BY `t` DESC LIMIT %d", id, ChatConfig.QUERY_CHAT_MESSAGE_MAX_COUNT);
	if ok and rows then
		for i=1, #rows do
			table.insert(self.history, rows[i])
		end
	end
	all[id] = self;
end

-- property
Channel.id = {
	get = "_id",
}

function Channel:Join(player, conn)
	log.debug(string.format("player %u join channle %u", player.id, self.id));
	if conn then
		player.chat_conn = conn;
	end
	rawset(self.members, player.id, player);
end

function Channel:Leave(player)
	log.debug(string.format("player %u leave channle %u", player.id, self.id));
	rawset(self.members, player.id, nil);
	player.chat_conn = nil;

	if next(self.members) == nil then
		all[self._id] = nil;
		log.debug(string.format("delete channel %u", self._id));
	end
end

function Channel:BinMessage(cmd, msg, flag, fakeTargetID)
	flag = flag or 1;

	local pids = {};
	if not fakeTargetID then
		for id, target in pairs(self.members) do
			table.insert(pids, id);
		end
	else
		table.insert(pids, fakeTargetID);
	end

	if #pids > 0 then
		local service = NetService.Get("Chat");
		if service then
			service:BroadcastToClient(flag, cmd, msg, pids)
		end
	end
end

function Channel:Chat(player, message, fakeTargetID)
	local rid = nil;
	-- local channel_name =''

	if self._id > 1000 then
		rid = Command.CHAT_GUILD; -- 军团
		-- channel_name ='军团'
	else
		rid = self._id;
	end
	
	-- 入库
	self:AddHistory({
		id =self._id,
		from_player_id =player.id,
		from_player_name =player.name,
		rid =rid,
		message =message or '',
		t =os.time()
	});

	local msg = {
		0, --sn
		Command.RET_SUCCESS, --result
		{ -- from
			player.id, --id
			player.name --name
		},
		rid,
		message
	};

	local cmd = Command.C_CHAT_MESSAGE_NOTIFY;
	-- local sender =string.format("[%d]%s", player.id, player.name)
	-- local receiver =string.format("[%d]%s", rid, channel_name)
	self:BinMessage(cmd, AMF.encode(msg), 1, fakeTargetID);
end

function Channel:AddHistory(info)
	if info.rid ~= Command.CHAT_GUILD then
		return
	end
	-- remove timeout
	self:RemoveTimeout()

	-- save to db
	local ok =database.update("INSERT INTO `chat_history`(`id`, `from_player_id`, `from_player_name`, `rid`, `message`, `t`)VALUES(%d, %d, '%s', %d, '%s', now())", info.id, info.from_player_id, util.encode_quated_string(info.from_player_name), info.rid, util.encode_quated_string(info.message));
	if not ok then
		return
	end	

	-- save to mem
	table.insert(self.history, 1, info)
end
function Channel:RemoveTimeout()
	for i=#self.history, 1, -1 do
		local info =self.history[i]
		if (os.time() - info.t) >= ChatConfig.CHAT_MESSAGE_SAVE_TIME then
			table.remove(self.history, i)
		else
			break
		end
	end
end
function Channel:GetHistory()
	self:RemoveTimeout()
	return self.history
end

function Get(id)
	if all[id] == nil then
		all[id] = Class.New(Channel, id);
	end
	return all[id];
end

local g_last_clean_time =0
Scheduler.Register(function(now)
	if now - g_last_clean_time > 3600 then
		database.update("DELETE FROM `chat_history` WHERE `uuid`>1 AND (unix_timestamp(`t`) < (unix_timestamp(now())-%d))", ChatConfig.CHAT_MESSAGE_SAVE_TIME);
		g_last_clean_time =now
	end
end);
