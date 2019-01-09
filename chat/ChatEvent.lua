
local log = log;

local pairs=pairs;
local cell = require "cell"
local Command = require "Command"
local EventManager = require "EventManager"
local PlayerManager = require "PlayerManager"
local print = print;
local string = string;

module "GuildEvent"

local function sendNotifyToMembers(guild, cmd, msg, title)
	title = title or 0;
	for _, m in pairs(guild.members) do
		if title == 0 or (m.title > 0 and m.title <= title) then
		end
	end
end

local function onSendMail(mail)
	local notify = mail.client_message;

	log.debug(string.format("player %u get new mail", mail.to));

	local player = PlayerManager.Get(mail.to);
	if player then
		-- 在线发送通知
		player:Notify(Command.NOTIFY_MAIL_NEW, notify);
	end
end

local listener = EventManager.CreateListener("mail_event_listener");

--EventManager.RegisterEvent("GUILD_CRETE", function(event, info) end);
listener:RegisterEvent("SEND_MAIL", function (event, info)
		return onSendMail(info);
	end);


listener:RegisterEvent("CONTACT_CHANGE", function(event, info)
	local player = PlayerManager.Get(info.target);
	if player then
		player:Notify(Command.NOTIFY_CONTACT_ADD, {info.pid, type});
	end
end)
