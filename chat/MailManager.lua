local ipairs = ipairs;
local string = string;
local print = print;
local table = table
local tonumber = tonumber
local log = log;
local os = os;
local loop = loop;
local pairs = pairs;
local next = next;

local function is_string(str)
	return type(str) == 'string'
end
local database = require "database"
local cell = require "cell"
local Command = require "Command"
local Class = require "Class"
local PlayerManager = require "PlayerManager"
local util  =require "util"
local assert =assert

local EventManager = require "EventManager"

module "MailManager"
local MAIL_TIMEOUT = 86400*2

function string_split(str, pattern)
	assert(is_string(str))
	local ret ={}
	local len_str =#str
	if len_str == 0 then
		return ret
	end
	local pos_find_start =1
	local pos_match_start, pos_match_end =string.find(str, pattern, pos_find_start)	
	while pos_match_start do
		if pos_match_start > pos_find_start then
			local sub_str =string.sub(str, pos_find_start, pos_match_start-1)	
			table.insert(ret, sub_str)
		end
		pos_find_start =pos_match_end + 1
		if pos_match_end>len_str then
			break
		end
		pos_match_start, pos_match_end =string.find(str, pattern, pos_find_start)	
	end
	if pos_find_start <= len_str then
		local sub_str =string.sub(str, pos_find_start, len_str)	
		table.insert(ret, sub_str)
	end
	return ret
end

local function parseAppendixFromString(str)
	local ret ={}
	local appendix_str_list =string_split(str, ';') or {}
	for i=1, #appendix_str_list do
		local value_str_list = string_split(appendix_str_list[i], ',') or {}
		if #value_str_list ~= 3 then
			yqerror('parseAppendixFromString:syntax error')
			break
		else
			local t    =tonumber(value_str_list[1])
			local id   =tonumber(value_str_list[2])
			local value=tonumber(value_str_list[3])
			if value ~= 0 then
				table.insert(ret, {type =t, id =id, value =value})			
			end
		end
	end
	return ret
end

local function buildAppendixAsString(appendix)
	if not appendix or #appendix==0 then
		return ''
	end
	local str_ret =''
	for i=1, #appendix do
		local item =appendix[i]
		str_ret =str_ret .. string.format("%d,%d,%d;", item.type, item.id, item.value)
	end
	return str_ret
end

local players = {};
local mails   = {};

local Mail = {};
local function loadMail(mail)
	local id = mail._id;
	local success, result = database.update("select type, `from`, `to`, title, content, appendix_opened, appendix, flag, unix_timestamp(at) as at from mail where mid = %u", id);
	if not success or result[1] == nil then
		return false;
	end

	self._type    = result[1].type;
	self._from    = result[1].from;
	self._to      = result[1].to;
	self._title   = result[1].title;
	self._content = result[1].content;
	self._appendix_opened = result[1].appendix_opened ~= 0;
	self._appendix = parseAppendixFromString(result[1].appendix);
	self._flag    = result[1].flag;
	self._at      = result[1].at;

	return true;
end

local function loadMailByPlayer(player)
	local id = player.id;
	local success, result = database.update("select mid, type, `from`, title, content, appendix_opened, appendix, flag, unix_timestamp(at) as at from mail where `to` = %u", id);
	if not success then
		return false;
	end

	for _, row in ipairs(result) do
		local mail = Class.New(Mail, row.mid, row.type, row.from, player.id, row.title, row.content, row.appendix_opened~=0, parseAppendixFromString(row.appendix), row.flag, row.at);
		player.mails[mail.id] = mail;
		mails[mail.id] = mail;
	end
end

function Mail:_init_(id, type, from, to, title, content, appendix_opened, appendix, flag, at)
	self._id = id;

	if type == nil then
		return loadMail(self);
	else
		self._type = type;
		self._from = from;
		self._to = to;
		self._title = title;
		self._content = content;
		self._appendix_opened = appendix_opened or false
		self._appendix = appendix or {};
		self._flag = flag or 0;
		self._at = at;
		return true;
	end
end

Mail.id = {
	get = "_id",
};

Mail.type = {
	get = "_type",
};

Mail.from = {
	get = "_from",
};

Mail.to = {
	get = "_to",
};

Mail.title = {
	get = "_title",
};

Mail.content = {
	get = "_content",
};

Mail.appendix = {
	get = "_appendix",
};

Mail.appendix_opened = {
	get = "_appendix_opened",
};

Mail.at = {
	get = "_at",
};

Mail.flag = {
	get = "_flag",
	set = function(self, flag)
		if self._flag == flag then
			return;
		end

		if database.update("update mail set flag = %u where mid = %u", flag, self._id) then
			self._flag = flag;
		end
	end
};


Mail.client_message = {
	get = function(m)
		local appendix = m.appendix or {}
		return {
			m.id, m.type, m.title, m.flag, m.from, 
			PlayerManager.Get(m.from).name, m.at,
			#appendix,
			(#appendix == 0 or m.appendix_opened) and 1 or 0,
		};
	end
};

local function getPlayer(id)
	if players[id] == nil then
		players[id] = PlayerManager.Get(id);
	end

	local player = players[id];
	if player.mails == nil then
		player.mails = {};
		loadMailByPlayer(player);
	end
	return players[id];
end

function New(type, from, to, title, content, appendix)
	if type == Command.MAIL_TYPE_FRIEND or type == Command.MAIL_TYPE_ARENA then
		content = os.date("%Y-%m-%d %H:%M:%S") .. content
	end
	appendix =appendix or { }
	if not database.update("insert into mail(type, `from`, `to`, title, content, appendix_opened, appendix, flag, at) values(%u, %u, %u, '%s', '%s', 0, '%s', 1, from_unixtime_s(%u))",
		type, from, to, util.encode_quated_string(title), util.encode_quated_string(content), buildAppendixAsString(appendix), loop.now()) then
		log.debug("database.update failed");
		return nil;
	end

	local id = database.last_id();

	local mail = Class.New(Mail, id, type, from, to, title, content, false, appendix, 1, loop.now());

	local player = getPlayer(to);

	mails[mail.id] = mail;
	player.mails[mail.id] = mail;

	EventManager.DispatchEvent("SEND_MAIL", mail);

	return mail;
end

function Get(id)
	if mails[id] == nil then
		mails[id] = Class.New(Mail, id);
	end
	return mails[id];
end


function Delete(mid)
	if not database.update("delete from mail where mid = %u", mid) then
		return false;
	end

	if mails[mid] then
		local mail = mails[mid];
		if players[mail.to] then
			players[mail.to].mails[mail.id] = nil;
		end
	end
	return true;
end

function GetByPlayerID(pid)
    local user_mail = getPlayer(pid).mails or {};
    local now = loop.now()
    local delete_mail_id = {}
    for k, v in pairs(user_mail) do
        if (#v.appendix==0 or v.appendix_opened) and (now - v.at > MAIL_TIMEOUT) then  --没有附件或者已经打开附件 => 并且邮件超过两天
            table.insert(delete_mail_id, v.id)
            user_mail[k] = nil
        end
    end
    if next(delete_mail_id) then
        database.update("DELETE FROM mail WHERE mid IN (%s)", table.concat(delete_mail_id, ",")) 
    end
	return getPlayer(pid).mails;
end
function OpenAppendix(playerid, mail)
	if mail.appendix_opened then
		return false
	end
	local ret =cell.sendReward(playerid, mail.appendix, nil, Command.REASON_OPEN_MAIL_APPENDIX, false);
	if ret and ret.result == Command.RET_SUCCESS then
		if not database.update("update mail set appendix_opened=1 where mid = %d", mail.id) then
			cell.sendReward(playerid, nil, mail.appendix, Command.REASON_OPEN_MAIL_APPENDIX, false);
			return false
		end
		mail._appendix_opened =true
		return true
	end
	return false
end
