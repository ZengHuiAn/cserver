local network=network;
local ipairs=ipairs;
local pairs=pairs;
local log=log;
local string=string;
local table=table;
local protobuf=protobuf;
local coroutine=coroutine;
local os=os;
local io=io;
local assert=assert;
local print=print;
local error=error;
local unpack=unpack;

local Command = require "Command"

local ServiceManager = require "ServiceManager"
local XMLConfig = require "XMLConfig"
local EventManager = require "EventManager"

local AMF=require "AMF"
local protobuf=require "protobuf"

--------------------------------------------------------
local ServiceName = {"Chat"};
local listen = {};
for idx, name in ipairs(ServiceName) do
    listen[idx] = {};
    listen[idx].host = XMLConfig.Social[name].host;
    listen[idx].port = XMLConfig.Social[name].port;
    listen[idx].name = name;
end

local service = ServiceManager.New("WorldSendReward", unpack(listen));
if service == nil then
	log.error("connect to mail service failed");
	loop.exit();
	return;
end

service:RegisterCommands({
	{Command.S_ADMIN_ADD_MAIL_REQUEST,"AdminAddMailRequest"},
	{Command.S_ADMIN_ADD_MAIL_RESPOND,"aGameRespond"},
	{Command.S_TIMING_NOTIFY_ADD_REQUEST, "TimingNotifyAddRequest"},
	{Command.S_TIMING_NOTIFY_ADD_RESPOND, "TimingNotifyAddRespond"},
	{Command.S_TIMING_NOTIFY_DEL_REQUEST, "TimingNotifyDelRequest"},
	{Command.S_TIMING_NOTIFY_DEL_RESPOND, "aGameRespond"},
	{Command.S_ADMIN_QUERY_MAIL_REQUEST, "AdminQueryMailRequest"},
	{Command.S_ADMIN_QUERY_MAIL_RESPOND, "AdminQueryMailRespond"},
	{Command.S_ADMIN_ADD_MULTI_MAIL_REQUEST, "AdminAddMultiMailRequest"},
	{Command.S_ADMIN_ADD_MULTI_MAIL_RESPOND, "aGameRespond"},
});

function _send_mail_internal(mail_type, from, to, title, content, appendix)
    if service:isConnected(to) then
        local request = {
            type     = mail_type,
            from     = from,
            to       = to,
            title    = title,
            content  = content,
            appendix = appendix
        }
        local respond =service:Request(Command.S_ADMIN_ADD_MAIL_REQUEST, 0 , request);
        if not respond then
            log.error(string.format("reward.adminSendReward error, respond is nil"))
            return nil
        elseif respond.result ~= 0 then
            log.error(string.format("reward.adminSendReward error no %s", respond.result))
            return nil
        else
            return respond
        end
    else
        log.warning(string.format("`%d` fail to call adminSendRewaed, disconnected", to or -1))
        return nil;
    end
end
function send_system_mail(to, title, content, appendix)
	return _send_mail_internal(Command.MAIL_TYPE_SYSTEM, 0, to, title, content, appendix);
end
function send_reward_by_mail(to, title, content, appendix)
	return _send_mail_internal(Command.MAIL_TYPE_SYSTEM, 0, to, title, content, appendix);
end
function send_arena_mail(to, title, content, appendix)
	return _send_mail_internal(Command.MAIL_TYPE_ARENA, 0, to, title, content, appendix);
end
function send_mail(mail_type, from, to, title, content, appendix)
	return _send_mail_internal(mail_type, from, to, title, content, appendix);
end

-- 群发邮件
function send_multi_mail(mail_type, from, to, title, content, appendix)
	if service:isConnected(to) then
		local request = {
			type = mail_type, 
			from = from,
			to = to,
			title = title,
			content = content,
			appendix = appendix,
		}
		local respond = service:Request(Command.S_ADMIN_ADD_MULTI_MAIL_REQUEST, 0, request)
		if not respond then
			log.error("send_multi_mail, respond is nil.")
		end
		return respond
	else
		log.warning("send_multi_mail: failed to send mails.")
		return nil
	end	
end

-- 增加一个公告
function add_notify(start, duration, interval, type, message)
	local respond = service:Request(Command.S_TIMING_NOTIFY_ADD_REQUEST, 0, 
		{ start = start, duration = duration, interval = interval, type = type, message = message })
	if not respond then
		log.error("TimingNotifyAddRequest error, respond is nil.")
		return nil
	end
	if respond.result ~= 0 then
		log.debug("TimingNotifyAddRequest failed, result is ", respond.result)	
		return nil
	else
		return respond.id
	end
end

-- 删除一个公告
function del_notify(id)
	local respond = service:Request(Command.S_TIMING_NOTIFY_DEL_REQUEST, 0, { id = id })
	if not respond then
		log.error("TimingNotifyDelRequest error, respond is nil.")
		return false
	end
	if respond.result ~= 0 then
		log.debug("TimingNotifyDelRequest failed, result is ", respond.result)
		return false
	else
		return true
	end
end

-- 查询邮件
function getMail(pid)
	assert(pid)
	local respond = service:Request(Command.S_ADMIN_QUERY_MAIL_REQUEST, 0, { pid = pid })
	if not respond then
		log.error("AdminQueryMailRequest error, respond is nil.")
		return nil
	end
	if respond.result == 0 then
		return respond.mails
	else
		log.debug("AdminQueryMailRequest failed, result is ", respond.result)
		return nil
	end
end
