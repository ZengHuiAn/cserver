local PlayerManager = require "PlayerManager"
local Class = require "Class"
local database = require "database"
local Command = require "Command"
local log = log;
local string = string;
local tonumber = tonumber;
local pairs = pairs;
local ipairs = ipairs;
local setmetatable = setmetatable;
local rawset = rawset;
local assert = assert;
local print = print;
local table = table;
require "printtb"
local sprinttb = sprinttb
local Agent = require "Agent"

module "ContactManager"

local Contact = {};
local all = {};
local CloseFriends = {}

function Contact:_init_(id)
	all[id] = self;
	self._id = id;
	self._mcount = {};
end

local meta_unsetable = {
	__newindex = function(self, k, v)
		assert(false, "can't set member directly")
	end;
}

local function loadContactMember(contact)
	log.debug(string.format("loadContactMember %u", contact.id));
	local success, result = database.query("select cid, `type`, rtype from contact where pid = %u", contact.id);
	if success then
		contact._members = {};
		contact._mcount = {};
		for _, row in ipairs(result) do
			local tid = row.cid;
			local target = PlayerManager.Get(tid);
			local type = row.type;
			local rtype = row.rtype;
			contact._members[target.id] = {player = target, type = type, rtype = rtype};
			if not contact._mcount[type] then
				contact._mcount[type] = 0;
			end
			contact._mcount[type] = contact._mcount[type] + 1;

			if type == 3 then
				CloseFriends[tid] = CloseFriends[tid] or {}
				CloseFriends[tid][contact.id] = true
			end 
		end
		setmetatable(contact._members, meta_unsetable);
	end
	return success;
end

local function Notify(cmd, pid, msg)
    local agent = Agent.Get(pid);
    if agent then
        agent:Notify({cmd, msg})
    end
end

function NotifyOnlineToCloseFriends(pid)
	local contact = Get(pid)
	if contact._members == nil then
		loadContactMember(contact)	
	end
	if CloseFriends[pid] then
		for tid, _ in pairs(CloseFriends[pid] or {}) do
			Notify(Command.NOTIFY_CLOSE_FRIEND_ONLINE, tid, {pid})			
		end
	end
end

Contact.id = {
	get = "_id",
}

Contact.members = {
	get = function(self)
		if self._members == nil then
			loadContactMember(self);
		end
		return self._members;
	end
}

function Contact:IsExist(pid)
	return self.members[pid] ~= nil
end
function Contact:Add(player, type)
	log.debug(self._id, self._mcount and self._mcount[type] or nil, type);
	local sql;
	
	local success, result = database.query("select `type` from contact where pid = %u and cid = %u;",  player.id, self._id);
	local rtype = 0;
	if success and #result >= 1 then
		for _, row in ipairs(result) do
			rtype = row.type;
		end
	end
	if self.members[player.id] then
		sql = "update contact set `type` = %u where pid = %u and cid = %u";
		if not database.update(sql, type, self._id,  player.id) then
			return false;
		end
		if not self._mcount[type] then
			self._mcount[type] = 0;
		end
		self._mcount[self.members[player.id].type] = self._mcount[self.members[player.id].type] - 1;
	else
		sql = "insert into contact(`type`, pid, cid, rtype) values(%u, %u, %u, %u)";
		if not database.update(sql, type, self._id,  player.id, rtype) then
			return false;
		end
		if not self._mcount[type] then
			self._mcount[type] = 0;
		end
	end
	self._mcount[type] = self._mcount[type] + 1;
	
	if rtype ~= 0 then
		sql = "update contact set `rtype` = %u where pid = %u and cid = %u";
		if not database.update(sql, type,  player.id, self._id) then
			return false;
		end
	end
	
	if self.members[player.id] == nil then
		rawset(self._members, player.id, {player = player, type = type, rtype = rtype});
	else
		rawset(self._members, player.id, {player = player, type = type, rtype = rtype});
	end
	
	local contact = Get(player.id);
	if contact then
		if contact.members then
			if contact.members[self._id] then
				contact.members[self._id].rtype = type;
				log.debug(string.format("%u set %u rtype = %u", contact.id, self._id, contact.members[self._id].rtype));
			end
		end
	end

	if type == 3 then
		CloseFriends[player.id] = CloseFriends[player.id] or {}
		CloseFriends[player.id][self._id] = true	
	end
	
	return true;
end

function Contact:Remove(player)
	local type = 99;
	if self.members[player.id] and self.members[player.id].type then
		type = self.members[player.id].type;
	end
	log.debug(self._id, self._mcount and self._mcount[type] or nil, type);
	if not database.update("delete from contact where pid = %u and cid = %u", self._id, player.id) then
		return false;
	end
	
	if not database.update("update contact set `rtype` = 0 where pid = %u and cid = %u", player.id, self._id) then
		return false;
	end
	
	if self.members[player.id] then
		rawset(self._members, player.id, nil);
		if self._mcount[type] then
			self._mcount[type] = self._mcount[type] - 1;
		end
	end
	
	local contact = Get(player.id);
	if contact then
		if contact.members then
			if contact.members[self._id] then
				contact.members[self._id].rtype = 0;
				log.debug(string.format("%u set %u rtype = %u", contact.id, self._id, contact.members[self._id].rtype));
			end
		end
	end

	if CloseFriends[player.id] and CloseFriends[player.id][self._id] then
		CloseFriends[player.id][self._id] = nil	
	end
	
	return true;
end

function Contact:Recommend()
	if self._mcount[1] and self._mcount[1] >= 100 then
		return false, Command.RET_CONTACT_MAX;
	end
	log.debug(string.format("%u Get Recommend People", self._id));
	local g_player = PlayerManager.GetPartPlayer();
	local t_player = {};
	for k, v in pairs(g_player) do
		if self._id ~= v and not self.members[v] then
			table.insert(t_player, v);
		end
	end
	return true, t_player;
end

function Contact:FriendCount()
	local n = 0

	for i, v in pairs(self._mcount or {}) do
		if i ~= 2 and i ~= 4 then
			n = n + v
		end	
	end
	
	return n
end

function Contact:isTruelyFriend(id)
	if self.members[id] and self.members[id].type ~= 2 and self.members[id].type ~= 4 then
		return true
	end

	return false
end

function Get(id)
	if all[id] == nil then
		all[id] = Class.New(Contact, id);
	end
	return all[id];
end
