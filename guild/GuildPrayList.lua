require "yqmath"
require "yqlog_sys"
require "printtb"
require "yqmath"
local database = require "database"
local yqinfo = yqinfo
local ipairs = ipairs
local pairs = pairs
local table = table
local math = math
local sprinttb = sprinttb
local GuildPrayConfig = require "GuildPrayConfig" 
local GuildPrayPlayer = require "GuildPrayPlayer" 
local BASE_TIME = GuildPrayPlayer.BASE_TIME  
local Class = require "Class"

module "GuildPrayList"

local instance = {} 
local GuildPrayList = {}

function GuildPrayList:_init_(gid)
	self._gid = gid 
	self._pray_list = {}
	local ok, result = database.query("SELECT pid, id, `index` FROM pray_list where gid = %d ", gid)
    if ok and #result >= 1 then
       	 for i = 1, #result do
           	local row = result[i];
			self._pray_list[row.pid] = self._pray_list[row.pid] or {}
			local temp = {
				_id = row.id,
				_index = row.index	
			}
			table.insert(self._pray_list[row.pid], temp)
        end
	end 
end

function GuildPrayList:getPrayList()
	return self._pray_list
end

function GuildPrayList:insertNewList(pid, id , index)
	if not database.update("INSERT INTO pray_list(gid, pid, id, `index`) VALUES(%d, %d, %d, %d)",self._gid, pid, id, index) then
		yqinfo("[GuildPrayList] Player %d fail to insertNewList , mysql error", pid)
		return 1
	end
	self._pray_list[pid] = self._pray_list[pid] or {}
	table.insert(self._pray_list[pid], {
		_id = id,
		_index = index,
	})
	return 0
end

function GuildPrayList:deletePlayerPrayList(pid, id, index)
	if not self._pray_list[pid] then
		yqinfo("[GuildPrayList] Player %d donot has praylist for id:%d index:%d", pid, id, index)	
		return 1 
	end
	local find = false 
	local find_key
	for k,v in pairs(self._pray_list[pid] or {}) do
		if v._id == id and v._index == index then
			find = true
			find_key = k
			break
		end	
	end	
	if not find then
		yqinfo("[GuildPrayList] Player %d fail to delete pray list , donnt has praylist for id:%d index:%d", pid, id, index)	
		return 1 
	end
	if not database.query("DELETE FROM pray_list WHERE gid=%d and pid=%d and id=%d and `index`=%d", self._gid, pid, id, index) then
		yqinfo("[GuildPrayList] Player %d fail to delete pray list , mysql error", pid)
		return 1
	end
	self._pray_list[pid][find_key] = nil
	return 0
end

function GuildPrayList:deletePlayerAllPrayList(pid)
	if not self._pray_list[pid] then
		yqinfo("[GuildPrayList] Player %d donot has pray list",pid)
		return 0
	end
	if not database.query("DELETE FROM pray_list WHERE gid=%d and pid=%d", self._gid, pid) then
		yqinfo("[GuildPrayList] Player %d fail to deletePlayerAllPrayList , mysql error", pid)
		return 1
	end
	local deleteTb = {}
	for k, v in pairs(self._pray_list or {}) do
		table.insert(deleteTb, {id = v._id, index = v._index})	
	end
	self._pray_list[pid] = nil	
	return 0, deleteTb 
end

function Get(gid)
	if not instance[gid] then
		instance[gid] = Class.New(GuildPrayList, gid)
	end
	return instance[gid]
end
