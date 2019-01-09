#!../bin/server

package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

require "log"
require "report"
require "XMLConfig"
local _base_log_path   = XMLConfig.FileDir and XMLConfig.FileDir or "../log/";
local chat_report_path = _base_log_path .. "/chat_report"
if log.open then
	local l = log.open(
		XMLConfig.FileDir and XMLConfig.FileDir .. "/chat_%T.log" or
		"../log/chat_%T.log");
	log.debug    = function(...) l:debug   (...) end;
	log.info     = function(...) l:info   (...)  end;
	log.warning  = function(...) l:warning(...)  end;
	log.error    = function(...) l:error  (...)  end;
end
local math =math
require "cell"
require "bit32"
require "base64"
require "AMF"
require "protobuf"
require "MailReward"
require "Agent"

require "PlayerManager"
require "MailManager"
require "ContactManager"
require "ChatChannel"

require "EventManager"
require "ChatEvent"

require "ChatConfig"

require "NetService"
require "SocialManager"
require "ServiceManager"
require "protobuf"
require "util"
local cell = require "cell"
local make_player_rich_text =util.make_player_rich_text;
require "Scheduler"
require "TimingNotifyManager"
local FavorManager = require "favor"

-- DEBUG ==================
require "Debug"
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


function sendClientRespond(conn, cmd, channel, msg)
	assert(conn);
	assert(cmd);
	assert(channel);
	assert(msg and (table.maxn(msg) >= 2));

	local sid = tonumber(bit32.rshift_long(channel, 32))
	assert(sid > 0)

	local code = AMF.encode(msg);
	--log.debug(string.format("send %d byte to conn %u", string.len(code), conn.fd));
	log.debug("sendClientRespond", cmd, string.len(code));

	if code then conn:sends(1, cmd, channel, sid, code) end
end

local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));		
		loop.exit();
		return nil;
	end
	return code;
end

local function loadProtocol(file)
	local f = io.open(file, "rb")
	local protocol= f:read "*a"
	f:close()
	protobuf.register(protocol)
end

loadProtocol("../protocol/config.pb");

local function readFile(fileName, protocol)
	local f = io.open(fileName, "rb")
	local content = f:read("*a")
	f:close()

	return protobuf.decode("com.agame.config." .. protocol, content);
end

local function sendServiceRespond(conn, cmd, channel, protocol, msg)
	local code = encode(protocol, msg);
	if code then
		return conn:sends(2, cmd, channel, 0, code);
	else
		return false;
	end
end

local function get_energy_config()
	local cfg = FavorConfig[1][0]
	local energy_config = {}
	if cfg then
		energy_config.reward = { { type = cfg.item_type, id = cfg.item_id, value = cfg.item_value }, }
		energy_config.get_limit = cfg.get_limit
		energy_config.give_limit = cfg.give_limit
		energy_config.friends_limit = cfg.friends_limit
	end

	return energy_config
end

local function onAILogin(conn, channel, request)
	local pid = request.pid
	if pid then
		local player = PlayerManager.Login(pid, {})
	end
end

local function onLogin(conn, playerid, request)
	local player = PlayerManager.Login(playerid, conn);

	if request then
		-- player:AddNotifyMessage(Command.C_PLAYER_DATA_CHANGE, AMF.encode({0, Command.RET_SUCCESS,
		--			       {Command.NOTIFY_DISPLAY_MESSAGE, {1, "欢迎光临"}}}));
		--
		-- 上线礼包
		-- local reward = {
		-- 	{type="REWARD_RESOURCES_VALUE",key=6,value=10},
		-- 	{type="REWARD_RESOURCES_VALUE",key=10,value=5},
		-- };
		-- cell.sendReward(playerid, reward, nil, 10000, true);
	end

	-- 系统
	local channel = ChatChannel.Get(0);
	channel:Join(player, conn);

	-- 世界
	channel = ChatChannel.Get(1);
	channel:Join(player, conn);

	-- 通知
	channel = ChatChannel.Get(2);
	channel:Join(player, conn);

	-- 组队
	channel = ChatChannel.Get(10);
	channel:Join(player, conn);

	if player.name == nil then
		-- player not exist
		return;
	end

--[[
	-- 国家
	if player.country then
		channel = ChatChannel.Get(player.country + 10);
		if channel  then
			channel:Join(player, conn);
		end
	end
--]]	

	--print(player.guild);
	if player.guild and player.guild.id ~= 0 then
		channel = ChatChannel.Get(player.guild.id + 1000);
		channel:Join(player, conn);
	end

	--通知亲密好友玩家上线
    --ContactManager.NotifyOnlineToCloseFriends(playerid)
end

local function onAILogout(conn, channel, request)
	local pid = request.pid 
	if pid then
		local player = PlayerManager.Get(pid);
		PlayerManager.Logout(pid);
	end
end

local function onLogout(conn, playerid, request)
	local player = PlayerManager.Get(playerid);
	player.conn = nil;

	-- 系统
	local channel = ChatChannel.Get(0);
	channel:Leave(player);

	-- 世界
	channel = ChatChannel.Get(1);
	channel:Leave(player);

	-- 通知
	channel = ChatChannel.Get(2);
	channel:Leave(player);

	-- 组队
	channel = ChatChannel.Get(10);
	channel:Leave(player);
--[[
	-- 国家
	if player.country then
		channel = ChatChannel.Get(player.country + 10);
		if channel then 
			channel:Leave(player);
		end
	end
--]]

	if player.guild and player.guild.id ~= 0 then
		channel = ChatChannel.Get(player.guild.id + 1000);
		channel:Leave(player);
	end

	for k, _ in pairs(player.chat_channels or {}) do
		channel = ChatChannel.Get(k);
		channel:Leave(player);
	end
	player.chat_channels = {};

	PlayerManager.Logout(playerid);
end

local function onChannelJoin(conn, playerid, request)
	local sn = request[1] or 0;
	local cid = request[2];
	local cmd = Command.C_JOIN_CHANNEL_RESPOND;

	if cid == nil then
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_PARAM_ERROR, "param error"});
	end

	local player = PlayerManager.Get(playerid);
	if not player then
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_PARAM_ERROR, "param error"});
	end

	for i = 2, #request do
		local cid = request[i];

		log.debug(string.format("player %u join channel %u", playerid, cid));


		local channel = ChatChannel.Get(cid);
		if cid >= 10 and cid <= 1000 then
			channel:Join(player, conn);
			player.chat_channels = player.chat_channels or {}
			player.chat_channels[cid] = true;
		end
	end

	conn:sendClientRespond(cmd, playerid, {sn, Command.RET_SUCCESS});
end

local function onChannelLeave(conn, playerid, request)
	local sn = request[1] or 0;
	local cid = request[2];
	local cmd = Command.C_LEAVE_CHANNEL_RESPOND;

	if cid == nil then
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_PARAM_ERROR, "param error"});
	end

	local player = PlayerManager.Get(playerid);

	log.debug(string.format("player %u leave channel %u", playerid, cid));

	local channel = ChatChannel.Get(cid);

	channel:Leave(player);

	if player.chat_channels then
		player.chat_channels[cid] = nil;
	end

	conn:sendClientRespond(cmd, playerid, {sn, Command.RET_SUCCESS});
end

local function onChannelChat(conn, playerid, request)
	-- onLogin(conn, playerid, nil);

	local cmd = Command.C_CHAT_MESSAGE_RESPOND;

	local sn      = request[1] or 0;
	--local type    = request[2];
	local rid     = request[2];
	local message = request[3];

	local from = PlayerManager.Get(playerid);

	local cid = CHAT_WORLD;
	if rid == Command.CHAT_WORLD then
		cid = 1;
	elseif rid == Command.CHAT_COUNTRY then
		-- cid =  from.country + 10;
		log.error("fail to C_CHAT_MESSAGE_REQUEST:character not in channel")
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_CHANNEL_INVALID, "character not in channel"});
	elseif rid == Command.CHAT_GUILD then
		if from.guild.id == 0 then
			log.error("fail to C_CHAT_MESSAGE_REQUEST:character not in channel")
			return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_CHANNEL_INVALID, "character not in channel"});
		else 
			cid = from.guild.id + 1000;
		end
	elseif rid <= 1000 or rid >= 10 then
		cid = rid;
	else
		log.error("fail to C_CHAT_MESSAGE_REQUEST:character not in channel")
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_CHANNEL_INVALID, "character not in channel"});
	end


	if from then
		local now = loop.now();
		if from.last_chat_time and now - from.last_chat_time < 1 then
			log.error("fail to C_CHAT_MESSAGE_REQUEST:mute")
			return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_CHARACTER_STATUS_MUTE, "mute"});
		end
		from.last_chat_time = now;
	end

	local channel = ChatChannel.Get(cid);

	if playerid > 100000 and channel.members[playerid] == nil then
		log.error("fail to C_CHAT_MESSAGE_REQUEST:character not in channel")
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_CHANNEL_INVALID, "character not in channel"});
	end

	if bit32.band(from.status, 0x02) ~= 0 then
		-- 禁言则只发给自己
		channel:Chat(from, message, playerid);
	else
		channel:Chat(from, message);
		report.write(chat_report_path, playerid, 0, cid, loop.now(), message);
		log.debug(string.format("player %u chat at channel %u: %s", playerid, cid, message));
	end
	cell.NotifyQuestEvent(playerid, {{type = 44, id = rid, count = 1}})
	conn:sendClientRespond(cmd, playerid, {sn, Command.RET_SUCCESS});
	log.info("C_CHAT_MESSAGE_REQUEST success")

--[[
	if message == 'show me the money' then
		cell.sendReward(playerid, {{type=41,id=90010,value=100},{type=41,id=90007,value=5}}, nil, math.random(110, 119), true, 0, 'REWARD FROM GOLD');
	elseif message == 'server notify' then
		TimingNotifyManager.Add(loop.now(), 60 * 10, 60, 1, 'server notify message body');
	end
--]]
end

local function onQueryChannelChat(conn, playerid, request)
	local cmd = Command.C_QUERY_CHAT_MESSAGE_RESPOND;

	local sn      = request[1] or 0;
	local rid     = request[2];

	-- calc channel id
	local from = PlayerManager.Get(playerid);
	local cid = CHAT_WORLD;
	if rid == Command.CHAT_WORLD then
		cid = 1;
	elseif rid == Command.CHAT_COUNTRY then
		cid =  from.country + 10;
	elseif rid == Command.CHAT_GUILD then
		if from.guild.id == 0 then
			log.error("fail to C_QUERY_CHAT_MESSAGE_REQUEST:character not in channel")
			return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_CHANNEL_INVALID, "character not in channel"});
		else 
			cid = from.guild.id + 1000;
		end
	else
		log.error("fail to C_QUERY_CHAT_MESSAGE_REQUEST:character not in channel")
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_CHANNEL_INVALID, "character not in channel"});
	end

	-- get channel
	local channel = ChatChannel.Get(cid);
	log.debug(string.format("player %u chat at channel %u", playerid, cid));

	-- check
	if channel.members[playerid] == nil then
		log.error("fail to C_QUERY_CHAT_MESSAGE_REQUEST:character not in channel")
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_CHANNEL_INVALID, "character not in channel"});
	end
	local history =channel:GetHistory()
	local list ={}
	for i=1, math.min(ChatConfig.QUERY_CHAT_MESSAGE_MAX_COUNT, #history) do
		local it =history[i]
		table.insert(list, { it.from_player_id, it.from_player_name, it.rid, it.message, it.t })
	end
	conn:sendClientRespond(cmd, playerid, {sn, Command.RET_SUCCESS, list});
	log.info("C_QUERY_CHAT_MESSAGE_REQUEST success")
end

local function onMailQuery(conn, playerid, request)
	local sn = request[1] or 0;
	local ftype = request[2] or 0xffffffff;
	local fstatus = request[3] or 0xffffffff;

	log.info(string.format("player %u query mail list ftype %08x, fstatus %08x", playerid, ftype, fstatus));

	local cmd = Command.C_MAIL_QUERY_RESPOND;
	local mails = MailManager.GetByPlayerID(playerid) or {};

	local respond = {
		sn,
		Command.RET_SUCCESS,
		{}
	};


	for _, m in pairs(mails) do
		if bit32.band(m.flag,fstatus) ~= 0 and bit32.band(m.type, ftype) ~= 0 then
			table.insert(respond[3], m.client_message)
		end
	end
	return conn:sendClientRespond(cmd, playerid, respond);
end

local function onMailGet(conn, playerid, request)
	local cmd = Command.C_MAIL_GET_RESPOND;
	local sn = request[1] or 0;
	local mail_list = request[2] or {};
	if type(mail_list) ~= "table" then
		log.debug(string.format("%u fail to C_MAIL_GET_REQUEST, param error", playerid));
		return conn:sendClientRespond(cmd, playerid, { sn, Command.RET_ERROR });
	end

	local respond = {
		sn, 
		Command.RET_SUCCESS,
		{}
	};

	local mails= MailManager.GetByPlayerID(playerid) or {};

	for idx = 1, #mail_list do
		local id = mail_list[idx];
		log.debug(string.format("player %u get mail %u content", playerid, id));
	
		if mails[id] and mails[id].appendix then
			local appendix_list ={}
			for k =1, #mails[id].appendix do
				local item =mails[id].appendix[k]
				table.insert(appendix_list, { item.type, item.id, item.value })
			end
			local mail = {id, mails[id].content, appendix_list, mails[id].appendix_opened and 1 or 0};
			table.insert(respond[3], mail)
		end
	end
	log.debug(string.format("%u C_MAIL_GET_RESPOND mail count =%d", playerid, #mails));
	return conn:sendClientRespond(cmd, playerid, respond);
end

local function onMailOpenAppendix(conn, playerid, request)
	log.debug(string.format("onMailOpenAppendix %u", playerid));
	local sn = request[1] or 0;
	local mail_id = request[2] or 0;
	local respond = {
		sn, 
		Command.RET_SUCCESS,
	};

	local cmd = Command.C_MAIL_OPEN_APPENDIX_RESPOND;
	local mails = MailManager.GetByPlayerID(playerid) or {};
	local mail =mails[mail_id]
	if not mail then
		log.error(string.format("`%d` fail to open mail `%d` appendix, mail not exist", playerid, mail_id))
		return conn:sendClientRespond(cmd, playerid, { sn, Command.RET_NOT_EXIST });
	end
	if not mail.appendix or #mail.appendix==0 then
		log.error(string.format("`%d` fail to open mail `%d` appendix, not exist appendix", playerid, mail_id))
		return conn:sendClientRespond(cmd, playerid, { sn, Command.RET_ERROR });
	end
	if mail.appendix_opened then
		log.error(string.format("`%d` fail to open mail `%d` appendix, already opened", playerid, mail_id))
		return conn:sendClientRespond(cmd, playerid, { sn, Command.RET_ERROR });
	end
	if not MailManager.OpenAppendix(playerid, mail) then
		log.error(string.format("`%d` fail to open mail `%d` appendix", playerid, mail_id))
		return conn:sendClientRespond(cmd, playerid, { sn, Command.RET_ERROR });
	end
	log.info(string.format("`%d` success to open mail `%d` appendix", playerid, mail_id))
	return conn:sendClientRespond(cmd, playerid, respond);
end

local function onMailMark(conn, playerid, request)
	log.debug(string.format("onMailMark %u", playerid));
	local sn = request[1] or 0;
	local mail_list = request[2] or {};
	local respond = {
		sn, 
		Command.RET_SUCCESS,
		{}
	};

	local cmd = Command.C_MAIL_MARK_RESPOND;
	local mails = MailManager.GetByPlayerID(playerid) or {};

	for idx = 1, #mail_list do
		if type(mail_list[idx]) ~= "table" then
			return conn:sendClientRespond(cmd, playerid, { sn, Command.RET_PARAM_ERROR, {} });
		end
		local id = mail_list[idx][1];
		local status = mail_list[idx][2];

		log.debug(string.format("player %u set mail %u status %u", playerid, id, status));

		if mails[id] then
			mails[id].flag = status;
			local info = {id, status};
			table.insert(respond[3], info)
		end
	end
	return conn:sendClientRespond(cmd, playerid, respond);
end

local function onMailDel(conn, playerid, request)
	log.debug(string.format("onMailDel %u", playerid));

	local sn = request[1] or 0;
	local mail_list =request[2] or {}
	local cmd = Command.C_MAIL_DEL_RESPOND;

	local respond = {
		sn, 
		Command.RET_SUCCESS,
		{}
	};
	local mails = MailManager.GetByPlayerID(playerid) or {};

	for idx = 1, #mail_list do
		local id = mail_list[idx];
		log.debug(string.format("player %u del mail %u", playerid, id));
		if mails[id] then
			MailManager.Delete(id);
			table.insert(respond[3], id)
		end
	end
	return conn:sendClientRespond(cmd, playerid, respond);
end

local function onMailSend(conn, playerid, request)
	log.debug(string.format("onMailSend %u", playerid));

	local sn = request[1] or 0; 
	local to = request[2];
	local type = request[3];
	local title = request[4] or " ";
	local content = request[5] or " ";

	local from;
	if type == Command.MAIL_TYPE_SYSTEM and playerid == 0 then
		from = {id = playerid, name = "System"};
	else
		from = PlayerManager.Get(playerid);
	end	

	local cmd = Command.C_MAIL_SEND_RESPOND;

	--检查玩家是否存在
	if to ~= 100000 then
		local target = PlayerManager.Get(to);
		if target == nil or target.name == nil then
			return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_CHARACTER_NOT_EXIST, "角色不存在"});
		end
	end

	log.debug(string.format("player %u send mail to %u, type %u title [%s] content [%s]", from.id, to, type, title, content));
	report.write(chat_report_path,from.id, to, type, loop.now(),content);

	local mail = MailManager.New(type, from.id, to, title, content, {
		-- {type=41, id= 41001, value =1},
		-- {type=41, id =41002, value =2}
	});
	if mail == nil then
		log.debug(string.format("%u fail to C_MAIL_SEND_REQUEST", playerid));
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR, "database error"});
	end

	log.debug(string.format("    mid = %u", mail.id));
	log.debug(string.format("%u C_MAIL_SEND_REQUEST", playerid));
	conn:sendClientRespond(cmd, playerid, {sn, Command.RET_SUCCESS});

	if type == Command.MAIL_TYPE_CHAT then
		cell.NotifyQuestEvent(playerid, {{type = 44, id = 100, count = 1}})
	end
end

local function onMailContactGet(conn, playerid, request)
	log.debug(string.format("onMailContactGet %u", playerid));

	local sn = request[1] or 0;
	local cmd = Command.C_MAIL_CONTACT_GET_RESPOND;

	local respond = {
		sn, 
		Command.RET_SUCCESS,
		{}
	};

	log.debug(string.format("player %u get contact", playerid));

	local contact = ContactManager.Get(playerid);
	for id, info in pairs(contact.members) do
		local value = FavorManager.TotalFavor(playerid, info.player.id)	-- 好感度
		table.insert(respond[3], {
			info.player.id,
			info.type,
			info.player.name,
			info.player.conn and 1 or 0,
			info.player.level,
			info.rtype,
			info.player.sex,
			value,
		});
	end
	conn:sendClientRespond(cmd, playerid, respond);
end

local function onMailContactGetByType(conn, playerid, request)
	log.debug(string.format("onMailContactGetByType %u", playerid));

	local sn = request[1] or 0;
	local type = request[2] or 3

	local cmd = Command.C_MAIL_CONTACT_GET_BY_TYPE_RESPOND;

	local respond = {
		sn, 
		Command.RET_SUCCESS,
		{}
	};

	log.debug(string.format("player %u get contact, type %d", playerid, type));

	local contact = ContactManager.Get(playerid);
	for id, info in pairs(contact.members) do
		if info.type == type then
			local value = FavorManager.TotalFavor(playerid, info.player.id)	-- 好感度
			table.insert(respond[3], {
				info.player.id,
				info.type,
				info.player.name,
				info.player.conn and 1 or 0,
				info.player.level,
				info.rtype,
				info.player.sex,
				value,
			});
		end
	end
	conn:sendClientRespond(cmd, playerid, respond);
end

local function onMailContactAdd(conn, playerid, request)
	local sn   = request[1] or 0;
	local type = request[2];
	local id   = request[3];
	local name = request[4];

	local cmd = Command.C_MAIL_CONTACT_ADD_RESPOND;

	log.debug(string.format("player %u add %u to contact %u", playerid, id, type));

	local target = nil;
	if id and id > 0 then
		target = PlayerManager.Get(id);
	else
		target = PlayerManager.GetByName(name);
	end

	local player = PlayerManager.Get(playerid);

	if target == nil or target.name == nil then
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_CHARACTER_NOT_EXIST, "角色不存在"});
	end

	if target.id == playerid then
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_CONTACT_SELF, "不能添加自己"});
	end

	local config = get_energy_config()
	if not config then
		return conn:sendClientRespond(cmd, playerid, { sn, Command.RET_ERROR, "配置不存在" })
	end

	local contact = ContactManager.Get(playerid);
	local is_exist = contact:IsExist(target.id)	

	if (type == 1 or type == 3) and not is_exist and contact:FriendCount() >= config.friends_limit then
		log.debug("friend count is full.")
		return conn:sendClientRespond(cmd, playerid, { sn, Command.RET_FULL, "好友已满" })
	end

	local rt1, rt2 = contact:Add(target, type);
	if rt1 then
		local info = contact.members[target.id];
		assert(info);

		conn:sendClientRespond(cmd, playerid, {sn,
				Command.RET_SUCCESS,
				target.id,
				type,
				target.name,
				target.conn and true or false,
				target.level,
				info.rtype,
				target.sex,
				is_exist and 0 or 1 -- is new
			});

		EventManager.DispatchEvent("CONTACT_CHANGE", {pid=playerid, target=id, type=type});
		if type == 1 then
			local mail = MailManager.New(Command.MAIL_TYPE_FRIEND, playerid, target.id, player.name, "", {})
			if not mail then
				log.error(string.format("fail to add mail from %d to %d", playerid, target.id))
			end
		end
		
		-- 陌生人和黑名单，好感度清零
		if type == 2 or type == 4 then
			-- clear favor
			FavorManager.ClearFavor(playerid, id)
		end

		return;
	elseif rt2 then
		return conn:sendClientRespond(cmd, playerid, {sn, rt2});
	else
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR, "database error"});
	end
end

local function onAddFriend(conn, channel, request)
	local pid = request.pid
	local friends = request.friends

	if channel ~= 0 then
		log.error("onAddFriend: channel ~= 0")
		return
	end

	local config = get_energy_config()
	if not config then
		log.warning("onAddFriend: config is not exist.")
		return
	end

	local player = PlayerManager.Get(pid)
	local contact = ContactManager.Get(pid)

	for _, id in ipairs(friends) do
		local is_exist = contact:IsExist(id)
		if contact:FriendCount() >= config.friends_limit then
			log.debug("onAddFriend: friend count is full.")
			break
		end
		if not is_exist then
			local target = PlayerManager.Get(id)
			if contact:Add(target, 1) then	
				local mail = MailManager.New(Command.MAIL_TYPE_FRIEND, pid, target.id, player.name, "", {})
				if not mail then
					log.error(string.format("fail to add mail from %d to %d", playerid, target.id))
				end
			end
		end
	end	
end

local function onMailContactDel(conn, playerid, request)
	local sn = request[1] or 0;
	local id = request[2];

	local cmd = Command.C_MAIL_CONTACT_DEL_RESPOND;

	log.debug(string.format("player %u remove %u from contact", playerid, id));

	local contact = ContactManager.Get(playerid);
	local target = PlayerManager.Get(id);

	if contact:Remove(target) then
		-- favor
		FavorManager.ClearFavor(playerid, id)

		EventManager.DispatchEvent("CONTACT_CHANGE", {pid=playerid, target=id, type=0});
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_SUCCESS, target.id});
	else 
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR, "database error"});
	end
end

local function onMailContactRecommend(conn, playerid, request)
	local sn   = request[1] or 0;
	local cmd = Command.C_MAIL_CONTACT_RECOMMEND_RESPOND;

	log.debug(string.format("player %u get recommend list", playerid));
	local contact = ContactManager.Get(playerid);
	local ok, result= contact:Recommend();
	local n = 0
	if ok then
		local ret = {}
		for _, v in ipairs(result) do
			if n < 10 then
				player = PlayerManager.Get(v);
				local name = "<SGK>" .. player.id .. "</SGK>"	
				if player.name ~= name then
					table.insert(ret,{
						player.id,
						player.name,
						player.conn and 1 or 0,
						player.level,
						player.sex,
            				});
					n = n + 1
				end
			else
				break
			end
        	end
        	conn:sendClientRespond(cmd, playerid, {sn, Command.RET_SUCCESS, ret});
        	log.debug(string.format("player %u get recommend list success", playerid));
	else
        	conn:sendClientRespond(cmd, playerid, {sn, result});
        	log.debug(string.format("player %u get recommend list failed", playerid));
	end
end


local function onMailGetNotifyMessage(conn, playerid, request)
	-- service:on(Command.C_MAIL_GET_NOTIRY_MESSAGE_REQUEST, onMailGetNotifyMessage);
	local sn = request[1] or 0;
	local cmd = Command.C_MAIL_GET_NOTIRY_MESSAGE_RESPOND;

	log.debug(string.format("player %u query notify message", playerid));

	local player = PlayerManager.Get(playerid);

	if player.messages == nil then
		return conn:sendClientRespond(cmd, playerid, {sn, Command.RET_ERROR, "database error"});
	end

	conn:sendClientRespond(cmd, playerid, {sn, Command.RET_SUCCESS});

	-- send notify and remove
	for k, v in pairs(player.messages) do 
		if player:NotifyCode(v.type, v.data) then
			player:RemoveNotifyMessage(v);
		end
	end
	
	-- 读取系统公告
	TimingNotifyManager.LoadNotify(playerid);
end

local function onRecordNotifyMessageRequest(conn, channel, request)
	local cmd = Command.S_RECORD_NOTIRY_MESSAGE_RESPOND;
	local proto = "aGameRespond";

	if channel ~= 0 then
		sendServiceRespond(conn, cmd, 0, proto,
				{sn = request.sn or 0, result = Command.RET_PREMISSIONS})
		return;
	end

	local player = PlayerManager.Get(request.to);
	if nil ~= player and player.id ~= 0 then
		if player:AddNotifyMessage(request.cmd, request.data) == false then
			sendServiceRespond(conn, cmd, 0, proto, {sn = request.sn or 0, result = Command.RET_ERROR})
			return;
		end
		sendServiceRespond(conn, cmd, 0, proto, {sn = request.sn or 0, result = Command.RET_SUCCESS})
	else
		sendServiceRespond(conn, cmd, 0, proto,
				{sn = request.sn or 0, result = Command.RET_ERROR})
	end
end

local function onServiceMailContactGet(conn, channel, request)
	local cmd = Command.S_MAIL_CONTACT_GET_RESPOND;
	local proto = "MailContactGetRespond";
	if channel ~= 0 then
		sendServiceRespond(conn, cmd, 0, proto, {sn = request.sn, result = Command.RET_PREMISSIONS})
		return;
	end

	local respond = {
		sn = request.sn or 0,
		result = Command.RET_SUCCESS,
		contacts = {};
	};

	local contact = ContactManager.Get(request.id);
	for id, info in pairs(contact.members) do
		table.insert(respond.contacts, {
			id = info.player.id,
			type = info.type;
			name = info.player.name,
			online = info.player.conn and true or false,
			level = info.player.level,
			rtype = info.rtype});
	end
	sendServiceRespond(conn, cmd, 0, proto, respond);
end

local function onTimingNotifyAdd(conn, channel, request)
	local cmd = Command.S_TIMING_NOTIFY_ADD_RESPOND;
	local proto = "TimingNotifyAddRespond";

	if channel ~= 0 then
		sendServiceRespond(conn, cmd, 0, proto,
				{sn = request.sn or 0, result = Command.RET_PREMISSIONS})
		return;
	end
	
	local id = TimingNotifyManager.Add(
		request.start, request.duration, request.interval, request.type, request.message, request.gm_id);

	pm("onTimingNotifyAdd", channel, "",
		{request.start, request.duration, request.interval, request.type, request.message, result, id});
	
	sendServiceRespond(conn, cmd, 0, proto, {
			sn = request.sn or 0,
			result = (id ~= nil) and Command.RET_SUCCESS or Command.RET_NOT_EXIST,
			id = id
		});
end

local function onTimingNotifyQuery(conn, channel, request)
	local cmd = Command.S_TIMING_NOTIFY_QUERY_RESPOND;
	local proto = "TimingNotifyQueryRespond";

	if channel ~= 0 then
		sendServiceRespond(conn, cmd, 0, proto,
				{sn = request.sn or 0, result = Command.RET_PREMISSIONS})
		return;
	end
	
	local respond = {
		sn = request.sn or 0,
		result = TimingNotifyManager.loadSuccess and Command.RET_SUCCESS or Command.RET_NOT_EXIST,
		allTimingNotify = {};
	};
	local allTimingNotify = TimingNotifyManager.Query();
	for id, notify in pairs(allTimingNotify) do
		table.insert(respond.allTimingNotify, {
				id = id,
				start = notify.start,
				lastTime = notify.lastTime,
				duration = notify.duration,
				interval = notify.interval,
				type = notify.type,
				message = notify.msg,
			});
	end
	
	pm("onTimingNotifyQuery", channel, "", respond);

	sendServiceRespond(conn, cmd, 0, proto, respond);
end

local function onTimingNotifyDel(conn, channel, request)
	local cmd = Command.S_TIMING_NOTIFY_DEL_RESPOND;
	local proto = "aGameRespond";

	if channel ~= 0 then
		sendServiceRespond(conn, cmd, 0, proto,
				{sn = request.sn or 0, result = Command.RET_PREMISSIONS})
		return;
	end
	
	local id = TimingNotifyManager.Delete(request.id, request.gm_id);
	
	pm("onTimingNotifyDel", channel, "", {request.id, id});
	
	sendServiceRespond(conn, cmd, 0, proto, {sn = request.sn or 0,
			result = (id ~= nil) and Command.RET_SUCCESS or Command.RET_NOT_EXIST});
end

--[[local function onServiceRegister(conn, playerid, request) 
	local sn   = request.sn;
	local type = request.type;
	local id   = request.id;

	conn.type = type;

	if request.type == "GATEWAY" then

	end

	sendServiceRespond(conn, Command.S_SERVICE_REGISTER_RESPOND,
						0, "ServiceRegisterRespond",
						{sn = sn, result = Command.RET_SUCCESS})
end--]]

local function onAdminChatMessage(conn, channel, request)
	if channel ~= 0 then
		sendServiceRespond(conn, Command.S_CHAT_MESSAGE_RESPOND, 0, "ChatMessageRespond",
				{sn = request.sn, result = Command.RET_PREMISSIONS})
		return;
	end

	print(request.from, request.channel, request.message);
	log.debug(string.format("chat from %u -> channel %u : %s", request.from, request.channel, request.message));

	local sn = request.sn;
	local from = PlayerManager.Get(request.from);
	local channel =  ChatChannel.Get(request.channel);

	channel:Chat(from, request.message);

	sendServiceRespond(conn, Command.S_CHAT_MESSAGE_RESPOND, 0, "ChatMessageRespond",
			{sn = request.sn, result = Command.RET_SUCCESS})
end

local function onAdminChannelMessage(conn, channel, request)
	if channel ~= 0 then
		sendServiceRespond(conn, Command.S_CHANNEL_MESSAGE_RESPOND, 0, "aGameRespond",
				{sn = request.sn, result = Command.RET_PREMISSIONS})
		return;
	end

	log.debug(string.format("admin add channel %u message", request.channel));

	local sn = request.sn or 0;
	local channel =  ChatChannel.Get(request.channel);
	if channel then
		channel:BinMessage(request.cmd, request.message, request.flag);
	end

	sendServiceRespond(conn, Command.S_CHANNEL_MESSAGE_RESPOND, 0, "aGameRespond",
			{sn = request.sn, result = Command.RET_SUCCESS})
end

local function onAdminChangeChatChannel(conn, channel, request)
	local cmd = Command.S_CHANGE_CHAT_CHANNEL_RESPOND;

	if channel ~= 0 then
		sendServiceRespond(conn, cmd, 0, "aGameRespond", {sn = request.sn, result = Command.RET_PREMISSIONS});
	end

	local pid = request.pid or 0;
	log.debug(string.format("admin change %u chat channel", pid));
	if pid == 0 then
		sendServiceRespond(conn, cmd, 0, "aGameRespond", {sn = request.sn, result = Command.RET_PARAM_ERROR});
	end

	local player = PlayerManager.Get(pid);

	-- HACK: maybe player guild change, reset player guild info
	player._guild = nil;

	for _, cid in ipairs(request.leave) do
		log.debug(string.format("    leave channel %u", cid));
		local channel = ChatChannel.Get(cid);
		channel:Leave(player);
	end

	for _, cid in ipairs(request.join) do
		log.debug(string.format("    join channel %u", cid));
		local channel = ChatChannel.Get(cid);
		channel:Join(player);
	end
	sendServiceRespond(conn, cmd, 0, "aGameRespond", {sn = request.sn, result = Command.RET_SUCCESS});
end

local function onAdminAddMail(conn, channel, request)
	if channel ~= 0 then
		sendServiceRespond(conn, Command.S_ADMIN_ADD_MAIL_RESPOND, 0, "aGameRespond",
				{sn = request.sn, result = Command.RET_PREMISSIONS})
		return;
	end

	local sn      = request.sn;
	local from    = PlayerManager.Get(request.from);
	local to      = PlayerManager.Get(request.to);
	local type    = request.type or 1;
	local title   = request.title;
	local content = request.content;
	local appendix = request.appendix;

	log.debug(string.format("admin player %u send mail to %u, type %u title [%s] content [%s], appendix count %d", from.id, to.id, type, title, content, #appendix));

	local mail = MailManager.New(type, from.id, to.id, title, content, appendix);
	if mail == nil then
		log.warning("database error")
		return sendServiceRespond(conn, Command.S_ADMIN_ADD_MAIL_RESPOND, 0, "aGameRespond", { sn = sn, result = Command.RET_ERROR })
	end

	log.debug(string.format("    mid = %u", mail.id));

	sendServiceRespond(conn, Command.S_ADMIN_ADD_MAIL_RESPOND, 0, "aGameRespond",
			{sn = request.sn, result = Command.RET_SUCCESS})
end

local function onAddMails(conn, channel, request)
	local cmd = Command.S_ADMIN_ADD_MULTI_MAIL_RESPOND 
	local protoc = "aGameRespond"
	local sn = request.sn or 0
	local from = PlayerManager.Get(request.from);
	local type = request.type or 1;
	local title = request.title;
	local content = request.content;
	local appendix = request.appendix;

	if channel ~= 0 then
		return sendServiceRespond(conn, cmd, 0, protoc, { sn = sn, result = Command.RET_PREMISSIONS })
	end

	for _, pid in ipairs(request.pids) do
		local to = PlayerManager.Get(pid)
		log.debug(string.format("admin player %u send mail to %u, type %u title [%s] content [%s], appendix count %d", from.id, to.id, type, title, content, #appendix))		
		local mail = MailManager.New(type, from.id, to.id, title, content, appendix);
		if mail == nil then
			log.warning("database error")
			return sendServiceRespond(conn, cmd, 0, "aGameRespond", { sn = sn, result = Command.RET_ERROR })
		end
	end

	sendServiceRespond(conn, Command.S_ADMIN_ADD_MAIL_RESPOND, 0, "aGameRespond", {sn = request.sn, result = Command.RET_SUCCESS})
end

local function onAdminQueryMail(conn, channel, request)
	if channel ~= 0 then
		sendServiceRespond(conn, Command.S_ADMIN_QUERY_MAIL_RESPOND, 0, "AdminQueryMailRespond", 
				{sn = request.sn, result = Command.RET_PREMISSIONS})
		return;
	end

	local sn = request.sn;
	local pid = request.pid;

	log.debug(string.format("admin query mail of player %u", pid));

	local mails = MailManager.GetByPlayerID(pid) or {};

	local respond = {
		sn = sn,
		result = Command.RET_SUCCESS,
		mails = {}
	};

	for _, m in pairs(mails) do
		if bit32.band(m.type, 1) ~= 0 then
			local mail = {
				id      = m.id,
				from    = {id = m.from, name = PlayerManager.Get(m.from).name},
				to      = {id = m.to,   name = PlayerManager.Get(m.to).name},
				type    = m.type,
				title   = m.title,
				content = m.content,
				appendix = m.appendix,
				time    = m.at,
				status  = m.flag,
			};
			table.insert(respond.mails, mail);
		end
	end

	sendServiceRespond(conn, Command.S_ADMIN_QUERY_MAIL_RESPOND, 0, "AdminQueryMailRespond", respond);
end

local function onAdminDelMail(conn, channel, request)
	if channel ~= 0 then
		sendServiceRespond(conn, Command.S_ADMIN_DEL_MAIL_RESPOND, 0, "aGameRespond",
				{sn = request.sn, result = Command.RET_PREMISSIONS})
		return;
	end

	local sn = request.sn;
	local id = request.id;

	log.debug(string.format("admin delete mail %u", id));

	local mail = MailManager.Get(id);
	if mail == nil then
		sendServiceRespond(conn, Command.S_ADMIN_DEL_MAIL_RESPOND, 0, "aGameRespond",
				{sn = request.sn, result = Command.RET_NOT_EXIST})
		return;
	end

	MailManager.Delete(id)
	
	sendServiceRespond(conn, Command.S_ADMIN_DEL_MAIL_RESPOND, 0, "aGameRespond",
			{sn = request.sn, result = Command.RET_SUCCESS})
	return;
end

local OriginTime = 1499270400  -- 2017/7/6 0:0:0
local Seconds = 24 * 3600
local function deadTime(time)
	assert(time >= OriginTime)
	local n = math.floor((time - OriginTime) / Seconds) + 1
	return OriginTime + n * Seconds
end

-- 判断time是否与当前时间处于同一天
local function same_day(time)
	local dead_time = deadTime(loop.now())	
	local morning = dead_time - Seconds;

	if time >= morning and time < dead_time then
		return true
	end

	return false
end

-- 两个时间相差的天数
local function day_interval(time1, time2)
	local dead_time1 = deadTime(time1)
	local dead_time2 = deadTime(time2)
		
	return (dead_time2 - dead_time1) / Seconds
end

local RecordList = { map = {}, map2 = {}, ref_map = {} }
-- 查询赠送记录
function RecordList.GetRecord(pid)
	assert(pid)
	if RecordList.map[pid] == nil then	
		local ok, result = database.query([[select `pid`, `target_id`, th, status, unix_timestamp(`present_time`) as `present_time`, `overdue`, unix_timestamp(`get_time`) as `get_time`,
			unix_timestamp(`remove_time`) as `remove_time` from `present` where `pid` = %d;]], pid)
		if ok and #result > 0 then
			for i, v in ipairs(result) do
				if not RecordList.ref_map[v.pid] or not RecordList.ref_map[v.pid][v.target_id] or not RecordList.ref_map[v.pid][v.target_id][v.th] then 				
					local t = { pid = v.pid, target_id = v.target_id, th = v.th, status = v.status, present_time = v.present_time, 
						overdue = v.overdue, get_time = v.get_time, remove_time = v.remove_time }

					RecordList.map[v.pid] = RecordList.map[v.pid] or {}
					RecordList.map[v.pid][v.target_id] = RecordList.map[v.pid][v.target_id] or {}
					RecordList.map[v.pid][v.target_id][v.th] = t

					RecordList.ref_map[v.pid] = RecordList.ref_map[v.pid] or {} 
					RecordList.ref_map[v.pid][v.target_id] = RecordList.ref_map[v.pid][v.target_id] or {}
					RecordList.ref_map[v.pid][v.target_id][v.th] = t
				end
			end
		end
	end
	
	RecordList.map[pid] = RecordList.map[pid] or {}

	return RecordList.map[pid]
end

-- 查询获赠记录
function RecordList.GetPresent(target_id)
	assert(target_id)
	if RecordList.map2[target_id] == nil then	
		local ok, result = database.query([[select `pid`, `target_id`, th, status, unix_timestamp(`present_time`) as `present_time`, overdue, unix_timestamp(`get_time`) as `get_time`, 
			unix_timestamp(`remove_time`) as `remove_time` from `present` where `target_id` = %d;]], target_id)
		if ok and #result > 0 then
			for i, v in ipairs(result) do
				if not RecordList.ref_map[v.pid] or not RecordList.ref_map[v.pid][v.target_id] or not RecordList.ref_map[v.pid][v.target_id][v.th] then 	
					local t = { pid = v.pid, target_id = v.target_id, th = v.th, status = v.status, present_time = v.present_time, 
						overdue = v.overdue, get_time = v.get_time, remove_time = v.remove_time }

					RecordList.map2[v.target_id] = RecordList.map2[v.target_id] or {}
					RecordList.map2[v.target_id][v.pid] = RecordList.map2[v.target_id][v.pid] or {}
					RecordList.map2[v.target_id][v.pid][v.th] = t
					
					RecordList.ref_map[v.pid] = RecordList.ref_map[v.pid] or {} 
					RecordList.ref_map[v.pid][v.target_id] = RecordList.ref_map[v.pid][v.target_id] or {}
					RecordList.ref_map[v.pid][v.target_id][v.th] = t	
				end
			end
		end
	end
	
	RecordList.map2[target_id] = RecordList.map2[target_id] or {}

	return RecordList.map2[target_id]
end

-- 当天给所有好友的赠送总次数
function RecordList.GiveTotalCount(pid)
	local map = RecordList.GetRecord(pid)
	if not map then
		return 0
	end

	local n = 0
	for _, v in pairs(map) do
		for _, v2 in pairs(v) do
			if same_day(v2.present_time) then
				n = n + 1
			end
		end
	end	

	return n
end

-- 当天给pid2这个好友的赠送次数
function RecordList.GiveCount(pid, pid2)
	local map = RecordList.GetRecord(pid)
	if not map or not map[pid2] then
		return 0
	end

	local n = 0
	for _, v in pairs(map[pid2]) do
		if same_day(v.present_time) then
			n = n + 1
		end
	end

	return n
end

-- 当天的获赠总次数
function RecordList.PresentTotalCount(target_id)
	local map = RecordList.GetPresent(target_id)
	if not map then
		return 0
	end

	local n = 0
	for _, v in pairs(map) do
		for _, v2 in pairs(v) do
			if same_day(v2.present_time) then
				n = n + 1
			end
		end
	end	

	return n	
end

-- 判断是否可以还可以领取
function RecordList.isCanDraw(target_id, limit)
	local map = RecordList.GetPresent(target_id)	
	if not map then
		return true
	end

	local n = 0
	for _, v in pairs(map) do
		for _, v2 in pairs(v) do
			if n < limit then
				if v2.status == 1 and same_day(v2.get_time) then
					n = n + 1
				end
			else
				return false
			end
		end	
	end

	if n < limit then
		return true
	end
	
	return false
end

-- 获取当天的领取奖励次数
function RecordList.GetDrawCount(target_id)
	local map = RecordList.GetPresent(target_id)

	local n = 0 
	for _, v in pairs(map) do
		for _, v2 in pairs(v) do
			if v2.status == 1 and same_day(v2.get_time) then
				n = n + 1
			end
		end
	end

	return n
end

function RecordList.Insert(info)
	if type(info) ~= "table" then
		log.warning("RecordList insert data: info is not a table.")
		return false
	end

	local record = RecordList.GetRecord(info.pid)
	if record and record[info.target_id] then
		info.th = table.maxn(record[info.target_id]) + 1
	else
		info.th = 1
	end
	local ok = database.update([[insert into present(pid, target_id, th, present_time, status, overdue, get_time, remove_time) 
			values(%d, %d, %d, from_unixtime_s(%d), %d, %d, from_unixtime_s(%d), from_unixtime_s(%d));]],
			info.pid, info.target_id, info.th, info.present_time, info.status, info.overdue, info.get_time, info.remove_time)		

	if ok then
		RecordList.ref_map[info.pid] = RecordList.ref_map[info.pid] or {}
		RecordList.ref_map[info.pid][info.target_id] = RecordList.ref_map[info.pid][info.target_id] or {}
		RecordList.ref_map[info.pid][info.target_id][info.th] = info

		RecordList.map[info.pid] = RecordList.map[info.pid] or {}
		RecordList.map[info.pid][info.target_id] = RecordList.map[info.pid][info.target_id] or {}
		RecordList.map[info.pid][info.target_id][info.th] = info

		RecordList.map2[info.target_id] = RecordList.map2[info.target_id] or {}
		RecordList.map2[info.target_id][info.pid] = RecordList.map2[info.target_id][info.pid] or {}
		RecordList.map2[info.target_id][info.pid][info.th] = info
	end

	return ok
end

function RecordList.UpdateOverDue(info, due)
	return database.update("update present set overdue = %d, remove_time = from_unixtime_s(%d) where pid = %d and target_id = %d and th = %d.", due, loop.now(), info.pid, info.target_id, info.th)
end

function RecordList.UpdateStatus(info, status)
	return database.update("update present set status = %d, get_time = from_unixtime_s(%d) where pid = %d and target_id = %d and th = %d.", status, loop.now(), info.pid, info.target_id, info.th)
end

function RecordList.Delete(info)
	return database.update("delete from present where pid = %d and target_id = %d and th = %d.", info.pid, info.target_id, info.th)
end

function RecordList.DeleteOverdueData()
	for pid, v in pairs(RecordList.ref_map) do
		for target_id, v2 in pairs(v) do
			for th, v3 in pairs(v2) do
				if v3.overdue == 1 and loop.now() - v3.remove_time >= 3 * 24 * 3600 then
					if RecordList.Delete(v3) then
						RecordList.ref_map[pid][target_id][th] = nil
						if RecordList.map[pid] and RecordList.map[pid][target_id] and RecordList.map[pid][target_id][th] then	
							RecordList.map[pid][target_id][th] = nil 
						end
						if RecordList.map2[target_id] and RecordList.map2[target_id][pid] and RecordList.map2[target_id][pid][th] then 
							RecordList.map2[target_id][pid][th] = nil
						end
					end	
				end
			end 
		end
	end	
end

local PRESENT_REASON_1 = 1	-- 在同一天内，不能对同一个人赠送超过限制
local PRESENT_REASON_2 = 2	-- 在同一天内，给好友的总总数次数不能超过限制
local PRESENT_REASON_3 = 3	-- 在同一天内，获得的总赠送次数不能超过限制
-- 给好友赠送
local function onEnergePresent(conn, pid, request) 
	local cmd = Command.C_MAIL_ENERGE_PRESENT_RESPOND 
	if type(request) ~= "table" or #request	~= 2 or type(request[2]) ~= "table" then
		log.warning(string.format("cmd: %d, param error", cmd))
		return conn:sendClientRespond(cmd, pid, { request[1] or 0, Command.RET_PARAM_ERROR })	
	end
	local sn = request[1]
	local pidLst = request[2]	
	
	local config = get_energy_config()
	if config == nil then
		log.warning(string.format("cmd: %d, energy config is nil.", cmd))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end

	local total = RecordList.GiveTotalCount(pid) -- 当天给好友的赠送总次数
	log.debug(string.format("cmd: %d, total give count = %d", cmd, total))

	for _, id in ipairs(pidLst) do	
		local count = RecordList.GiveCount(pid, id)		-- 当天，pid给id赠送的次数
		log.debug(string.format("cmd: %d, %d give %d count is %d", cmd, pid, id, count))

		if count < 1 and total < config.give_limit then	
			-- 插入一条赠送记录
			local info = { pid = pid, target_id = id, present_time = loop.now(), status = 0, overdue = 0, get_time = 0, remove_time = 0 }
			if info.target_id < 100000 then
				info.overdue = 1
				info.status = 1
				info.remove_time = loop.now()
			end
			if RecordList.Insert(info) then
				total = total + 1			
				--quest
				cell.NotifyQuestEvent(pid, {{type = 45, id = 1, count = 1 }})

				-- 通知玩家
				local cmd = Command.NOTIFY_PRESENT
				local agent = Agent.Get(id)
				if agent then
					agent:Notify({ cmd, { info.pid, 1, info.present_time, info.th, info.status } })
				end

				-- 是否互为好友
				local contact1 = ContactManager.Get(pid)
				local contact2 = ContactManager.Get(id)
				if contact1 and contact2 and contact1:isTruelyFriend(id) and contact2:isTruelyFriend(pid) then
					-- favor
					FavorManager.AddFavor(pid, id, 1)
				end
			end
		end
	end
	
	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
end

local function onAiPresent(conn, channel, request)
	local cmd = Command.S_MAIL_ENERGE_PRESENT_RESPOND
	local sn = request.sn or 0
	local pid = request.pid		

	log.debug(string.format("onAiPresent: ai %d present.", pid))

	if channel ~= 0 then
		log.error("onAiPresent: channel ~= 0")
		return
	end
	
	local config = get_energy_config()
	if config == nil then
		log.warning(string.format("onAiPresent: nergy config is nil."))
		return
	end

	local contact = ContactManager.Get(pid)
	for id, _ in pairs(contact.members or {}) do	
		local total = RecordList.PresentTotalCount(id)	-- 当天获赠总次数	
		if total < config.get_limit then
			-- 插入一条赠送记录
			local info = { pid = pid, target_id = id, present_time = loop.now(), status = 0, overdue = 0, get_time = 0, remove_time = 0 }
			if RecordList.Insert(info) then
				--[[local code = cell.sendReward(id, config.reward, nil, Command.REASON_ENERGY_PRESENT)
				if not code or code.result ~= Command.RET_SUCCESS then
					log.warning(string.format("onAiPresent: ai %d send %d reward failed.", pid, id))
				end--]]

				-- 是否互为好友
				local contact1 = ContactManager.Get(pid)
				local contact2 = ContactManager.Get(id)
				if contact1 and contact2 and contact1:isTruelyFriend(id) and contact2:isTruelyFriend(pid) then
					-- favor
					FavorManager.AddFavor(pid, id, 1)
				end
			end
		end
	end
end

-- 查询玩家给好友的赠送记录
local function onEnergyQuery(conn, pid, request)
	local cmd = Command.C_MAIL_ENERGE_QUERY_RESPOND
	if type(request) ~= "table" or #request < 1 then
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { request[1] or 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1] 
	local record = RecordList.GetRecord(pid)

	local ret = {}
	for _, v in pairs(record or {}) do
		for _, v2 in pairs(v) do
			if same_day(v2.present_time) then
				table.insert(ret, { v2.target_id, 1, v2.present_time, v.th, v.status })
			end
		end
	end

	-- 删除已经失效的赠送记录
	RecordList.DeleteOverdueData()

	local total = RecordList.GiveTotalCount(pid)

	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, ret, total })
end 

-- 查询玩家的获赠记录
local function onPresentQuery(conn, pid, request)
	local cmd = Command.C_MAIL_PRESENT_QUERY_RESPOND
	if type(request) ~= "table" or #request < 1 then
		log.debug(string.format("cmd: %d, param error.", cmd))	
		return conn:sendClientRespond(cmd, pid, { request[1] or 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]

	local ret = {}
	local present = RecordList.GetPresent(pid)
	for _, v in pairs(present or {}) do
		for _, v2 in pairs(v) do
			if v2.overdue == 0 then
				table.insert(ret, { v2.pid, 1, v2.present_time, v2.th, v2.status })
			end
		end
	end
	
	-- 删除已经失效的赠送记录
	RecordList.DeleteOverdueData()

	local total = RecordList.GetDrawCount(pid)

	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, ret, total })
end

local function onServerPresentQuery(conn, channel, request)
	if channel ~= 0 then
		log.error("onServerPresentQuery: channel ~= 0")
		return sendServiceRespond(conn, Command.S_QUERY_RESENT_RECORD_RESPOND, 0, "QueryResentRecordRespond",
				{ sn = request.sn, result = Command.RET_PREMISSIONS, donors = {} })
	end
	local pid = request.pid
	local donors = {}
	local present = RecordList.GetPresent(pid)
	for _, v in pairs(present or {}) do
		for _, v2 in pairs(v) do
			table.insert(donors, v.pid)
		end
	end
		
	sendServiceRespond(conn, Command.S_QUERY_RESENT_RECORD_RESPOND, 0, "QueryResentRecordRespond",
			{ sn = request.sn, result = Command.RET_SUCCESS, donors = donors })	
end

local function onReceiveReward(conn, pid, request)
	local cmd = Command.C_MAIL_RECEIVE_PRESENT_RESPOND		
	if type(request) ~= "table" or #request < 3 then
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { request[1] or 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]
	local pid1 = request[2]
	local th = request[3]

	local map = RecordList.GetPresent(pid)
	if map == nil or map[pid1] == nil or map[pid1][th] == nil then
		log.warning(string.format("cmd: %d, there is no present, pid1 = %d, th = %d.", cmd, pid1, th))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end

	local p = map[pid1][th]
	if p.status ~= 0 then
		log.warning(string.format("cmd: %d, have draw the present, pid1 = %d, th = %d.", cmd, pid1, th))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end
	
	local config = get_energy_config()
	if config == nil then
		log.warning(string.format("cmd: %d, energy config is nil.", cmd))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end
	
	-- 判断当天是否还可以进行领取
	if not RecordList.isCanDraw(pid, config.get_limit) then
		log.warning(string.format("cmd: %d, draw reward beyond limit.", cmd))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end
	
	if RecordList.UpdateStatus(p, 1) then	
		local reward = {}
		if FavorManager.IsDoublePresent(pid, pid1) then
			for _, v in ipairs(config.reward) do
				table.insert(reward, { type = v.type, id = v.id, value = v.value * 2 })
			end
		else	
			for _, v in ipairs(config.reward) do
				table.insert(reward, { type = v.type, id = v.id, value = v.value })
			end
		end
		local code = cell.sendReward(pid, reward, nil, Command.REASON_ENERGY_PRESENT)
		if not code or code.result ~= Command.RET_SUCCESS then
			log.warning(string.format("cmd: %d, send reward failed.", cmd))
		end
		p.status = 1
		p.get_time = loop.now()	
	end
	
	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
end

local function onDeletePresentRecord(conn, pid, request)
	local cmd = Command.C_MAIL_DELETE_RECORD_RESPOND
	if type(request) ~= "table" or #request < 2 or type(request[2]) ~= "table" then
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { request[1] or 0, Command.RET_PARAM_ERROR })
	end
	
	local sn = request[1]
	local list = request[2]

	local map = RecordList.GetPresent(pid)	
	for _, v in ipairs(list or {}) do
		if map and map[v[1]] and map[v[1]][v[2]] then
			local p = map[v[1]][v[2]] 
			if p.overdue == 0 and RecordList.UpdateOverDue(p, 1) then
				p.overdue = 1
				p.remove_time = loop.now()
			end
		end
	end	

	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
end

function onLoad()
	TimingNotifyManager.onLoad();
end

function onUnload()
	TimingNotifyManager.onUnload();
end

local function onServiceRegister(conn, channel, request)
	if request.type == "GATEWAY" then
		for k, v in pairs(request.players) do
			-- print(k, v);
			onLogin(conn, v, nil)
		end
	end
end

local function queryPlayerOnlineStat(conn, channel, request)
	local cmd = Command.C_MAIL_QUERY_PLAYER_ONLINE_STAT_RESPOND
	local sn = request[1] 
	local list = request[2]
	if type(list) ~= "table" or #list < 1 then
		log.debug("queryPlayerOnlineStat: param error")	
		conn:sendClientRespond(cmd, channel, { sn, Command.RET_PARAM_ERROR })
	end
	local ret = {}
	for _, pid in ipairs(list) do
		local player = PlayerManager.Get(pid)
		if not player or not player.conn then
			table.insert(ret, false)
		else
			table.insert(ret, true)
		end	
	end
	
	conn:sendClientRespond(cmd, channel, { sn, Command.RET_SUCCESS, ret})
end

for _, cfg in ipairs(ChatConfig.listen) do
	service = NetService.New(cfg.port, cfg.host, cfg.name or "chat");
	assert(service, "listen on " .. cfg.host .. ":" .. cfg.port .. " failed");
	
	service:on("accept", function (client)
		client.sendClientRespond = sendClientRespond;
		log.debug(string.format("Service: client %d connected", client.fd));
	end);

	service:on("close", function(client)
		log.debug(string.format("Service: client %d closed", client.fd));
	end);


	if cfg.name == "Chat" then
		service:on(Command.C_LOGIN_REQUEST, 		onLogin);
		service:on(Command.C_LOGOUT_REQUEST, 		onLogout);
		service:on(Command.S_SERVICE_REGISTER_REQUEST,	onServiceRegister);
	end

	service:on(Command.C_JOIN_CHANNEL_REQUEST, 	onChannelJoin);
	service:on(Command.C_LEAVE_CHANNEL_REQUEST, 	onChannelLeave);
	service:on(Command.C_CHAT_MESSAGE_REQUEST, 	onChannelChat);
	service:on(Command.C_QUERY_CHAT_MESSAGE_REQUEST, 	onQueryChannelChat);

	service:on(Command.C_MAIL_QUERY_REQUEST, 	onMailQuery);
	service:on(Command.C_MAIL_GET_REQUEST, 		onMailGet);
	service:on(Command.C_MAIL_OPEN_APPENDIX_REQUEST, 		onMailOpenAppendix);
	service:on(Command.C_MAIL_MARK_REQUEST, 	onMailMark);
	service:on(Command.C_MAIL_DEL_REQUEST, 		onMailDel);
	service:on(Command.C_MAIL_SEND_REQUEST, 	onMailSend);
	service:on(Command.C_MAIL_CONTACT_GET_REQUEST, 	onMailContactGet);
	service:on(Command.C_MAIL_CONTACT_GET_BY_TYPE_REQUEST, 	onMailContactGetByType);
	service:on(Command.C_MAIL_CONTACT_ADD_REQUEST, 	onMailContactAdd);
	service:on(Command.C_MAIL_CONTACT_DEL_REQUEST, 	onMailContactDel);
	service:on(Command.C_MAIL_CONTACT_RECOMMEND_REQUEST, 	onMailContactRecommend);

	service:on(Command.C_MAIL_GET_NOTIRY_MESSAGE_REQUEST, onMailGetNotifyMessage);

 	service:on(Command.C_MAIL_ENERGE_PRESENT_REQUEST, onEnergePresent)
	service:on(Command.C_MAIL_ENERGE_QUERY_REQUEST, onEnergyQuery)
	service:on(Command.C_MAIL_PRESENT_QUERY_REQUEST, onPresentQuery)
	service:on(Command.C_MAIL_RECEIVE_PRESENT_REQUEST, onReceiveReward)
	service:on(Command.C_MAIL_DELETE_RECORD_REQUEST, onDeletePresentRecord)

	service:on(Command.C_MAIL_QUERY_PLAYER_ONLINE_STAT_REQUEST, queryPlayerOnlineStat)

	service:on(Command.S_MAIL_ENERGE_PRESENT_NOTIFY, "PresentEnergyNotify", onAiPresent)
	service:on(Command.S_MAIL_ADD_FRIEND_NOTIFY, "AddFriendNotify", onAddFriend)

	service:on(Command.S_QUERY_RESENT_RECORD_REQUEST, "QueryResentRecordRequest", onServerPresentQuery)
	
	service:on(Command.S_CHAT_MESSAGE_REQUEST,          "ChatMessageRequest",         onAdminChatMessage);
	service:on(Command.S_CHANNEL_MESSAGE_REQUEST,       "ChannelMessageRequest",      onAdminChannelMessage);
	service:on(Command.S_CHANGE_CHAT_CHANNEL_REQUEST,   "ChangeChatChannelRequest",   onAdminChangeChatChannel);
	service:on(Command.S_RECORD_NOTIRY_MESSAGE_REQUEST, "RecordNotifyMessageRequest", onRecordNotifyMessageRequest);

	service:on(Command.S_MAIL_CONTACT_GET_REQUEST, "MailContactGetRequest", onServiceMailContactGet);

	service:on(Command.S_ADMIN_ADD_MAIL_REQUEST,   "AdminAddMailRequest",   onAdminAddMail);
	
	service:on(Command.S_ADMIN_ADD_MULTI_MAIL_REQUEST, "AdminAddMultiMailRequest", onAddMails)

	service:on(Command.S_ADMIN_QUERY_MAIL_REQUEST, "AdminQueryMailRequest", onAdminQueryMail);
	service:on(Command.S_ADMIN_DEL_MAIL_REQUEST,   "AdminDelMailRequest",   onAdminDelMail);
	
	service:on(Command.S_TIMING_NOTIFY_ADD_REQUEST, "TimingNotifyAddRequest", onTimingNotifyAdd);
	service:on(Command.S_TIMING_NOTIFY_QUERY_REQUEST, "TimingNotifyQueryRequest", onTimingNotifyQuery);
	service:on(Command.S_TIMING_NOTIFY_DEL_REQUEST, "TimingNotifyDelRequest", onTimingNotifyDel);

	service:on(Command.S_NOTIFY_AI_LOGIN_CHAT, "AILoginNotify", onAILogin);
	service:on(Command.S_NOTIFY_AI_LOGOUT_CHAT, "AILogoutNotify", onAILogout);

	FavorManager.RegisterCommands(service)
end

