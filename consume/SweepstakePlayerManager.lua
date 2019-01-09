local loop = loop;
local log  = log;
local Class = require "Class"

local database = require("database")
require "printtb"
--require "point_reward"
--require "aiserver"
require "SocialManager"
--local lottoConfig =require "lottoConfig"
--local lotto = require "lotto"
--local lottoRecord = require "lottoRecord"

local StableTime =require "StableTime"
local get_today_begin_time =StableTime.get_today_begin_time
--local broadcast =require "broadcast"
--require "YQSTR"
--require "util"

local tostring = tostring
local tonumber = tonumber
local math = math
local os = os
local ipairs = ipairs
local pairs = pairs

local type = type
local string = string
local print = print
local next = next
local log = log
local loop = loop;
local coroutine = coroutine
local table = table
local Scheduler = require "Scheduler"
local database = require "database"
local Class = require "Class"
require "Thread"
local Sleep = Sleep
local Command = require "Command"
local SweepstakeConfig = require "SweepstakeConfig"

local SweepstakePoolConfig = require "SweepstakePoolConfig"

module "SweepstakePlayerManager"

local SweepstakePlayerManager = {}
local pid2instance = {}

function SweepstakePlayerManager:_init_(pid,dataid)
	if not pid or not dataid then
		log.error("SweepstakePlayerManager init fail, pid or dataid not found")
		return
	end
	local ok, ret = database.query("select pid, dataid, UNIX_TIMESTAMP(last_free_time) as last_free_time, total_count, has_used_gold, UNIX_TIMESTAMP(last_draw_time) as last_draw_time, today_draw_count, random_count, randnum, flag, current_pool, current_pool_draw_count, UNIX_TIMESTAMP(current_pool_end_time) as current_pool_end_time from sweepstakeplayerdata where pid = %d and dataid = %d", pid, dataid)
	self.playerdata = {}
	if ok then
		if #ret >= 1 then
			for k,row in ipairs(ret) do
				self.playerdata = {}
				self.playerdata.pid = row.pid
				self.playerdata.dataid = row.dataid
				self.playerdata.last_free_time = row.last_free_time
				self.playerdata.total_count = row.total_count
				self.playerdata.has_used_gold = row.has_used_gold
				self.playerdata.last_draw_time = row.last_draw_time
				self.playerdata.today_draw_count = row.today_draw_count
				self.playerdata.random_count = row.random_count
				self.playerdata.randnum = row.randnum
				self.playerdata.flag = row.flag
				self.playerdata.current_pool = row.current_pool
				self.playerdata.current_pool_draw_count = row.current_pool_draw_count
				self.playerdata.current_pool_end_time = row.current_pool_end_time
			end
		else
			
			local cfg_instance = SweepstakeConfig.Get()
			if not cfg_instance then
				log.error("SweepstakePlayerManager init fail, cannot get cfg")
				return 
			end
			local cfg = cfg_instance:getCfgByDataID(dataid)
			if not cfg then
				log.error("SweepstakePlayerManager init fail, cannot get cfg")
				return
			end
			self.playerdata = {}
			self.playerdata.pid = pid
			self.playerdata.dataid = dataid
			self.playerdata.last_free_time = math.floor(os.time()) - cfg.init_time  
			self.playerdata.total_count = cfg.init_count 
			self.playerdata.has_used_gold = 0
			self.playerdata.last_draw_time = 0
			self.playerdata.today_draw_count = 0
			self.playerdata.random_count = 0
			self.playerdata.randnum = 0
			self.playerdata.flag = 0
			self.playerdata.current_pool = 0 
			self.playerdata.current_pool_draw_count = 0 
			self.playerdata.current_pool_end_time = 0 
			database.update("INSERT INTO sweepstakeplayerdata(pid, dataid, last_free_time, total_count, has_used_gold, last_draw_time, today_draw_count, random_count, randnum, flag, current_pool, current_pool_draw_count, current_pool_end_time)VALUES(%d,%d,from_unixtime_s(%d),%d,%d,from_unixtime_s(%d),%d,%d,%d,%d,%d,%d,from_unixtime_s(%d))", pid, dataid, self.playerdata.last_free_time, self.playerdata.total_count, 0, 0, 0, 0, 0, 0, 0, 0, 0)
		end
	end
end

function SweepstakePlayerManager:getSweepstakePlayerData()
    if self.playerdata.last_draw_time < get_today_begin_time() then
		self.playerdata.today_draw_count = 0
	end

	return self.playerdata;
end

function SweepstakePlayerManager:updateSweepstakePlayerData(last_free_time, total_count, has_used_gold, last_draw_time, today_draw_count, random_count, randnum, flag, current_pool, current_pool_draw_count, current_pool_end_time)
	local ret = database.update("REPLACE INTO sweepstakeplayerdata(pid,dataid,last_free_time,total_count, has_used_gold, last_draw_time, today_draw_count, random_count, randnum, flag, current_pool, current_pool_draw_count, current_pool_end_time)VALUES(%d,%d,from_unixtime_s(%d),%d,%d,from_unixtime_s(%d),%d,%d,%d,%d,%d,%d,from_unixtime_s(%d))", self.playerdata.pid, self.playerdata.dataid, last_free_time, total_count, has_used_gold, last_draw_time, today_draw_count, random_count, randnum, flag, current_pool, current_pool_draw_count, current_pool_end_time) 
	self.playerdata.last_free_time = last_free_time
	self.playerdata.total_count = total_count
	self.playerdata.has_used_gold = has_used_gold
	self.playerdata.last_draw_time = last_draw_time
	self.playerdata.today_draw_count = today_draw_count
	self.playerdata.random_count = random_count
	self.playerdata.randum = randum
	self.playerdata.flag = flag
	self.playerdata.current_pool = current_pool 
	self.playerdata.current_pool_draw_count = current_pool_draw_count 
	self.playerdata.current_pool_end_time = current_pool_end_time 
	return ret
end

function Get(pid, dataid)
	local instance = pid2instance[pid] and pid2instance[pid][dataid] or nil--pid2instance[tostring(pid)..tostring(dataid)]
	if not instance then
		instance = Class.New(SweepstakePlayerManager,pid,dataid)
		pid2instance[pid] = pid2instance[pid] or {}
		pid2instance[pid][dataid] = instance
	end
	return instance;
end

function CheckAndRefreshPool(pid, id)
	local cfg_instance = SweepstakeConfig.Get()
	if not cfg_instance then
		return
	end

	local dataid = cfg_instance:getPlayerDataIDByID(id)
	if not dataid then
		return 
	end

	local instance = Get(pid, dataid)
	if not instance then
		return
	end	

	local playerdata = instance:getSweepstakePlayerData()
	if not playerdata then
		return
	end

	if loop.now() > playerdata.current_pool_end_time then
		local pool_cfg = SweepstakePoolConfig.Get(id)
		local idx = 0
		for k, v in pairs(pool_cfg or {}) do
			idx = k	
		end
		local rand_pool = {}
		if pool_cfg and pool_cfg[idx].begin_time > 0 then
			for pool_type, v in pairs(pool_cfg) do
				table.insert(rand_pool, pool_type)	
			end
			local index = math.random(1, #rand_pool)
			local select_pool = rand_pool[index]

			local current_pool_end_time = pool_cfg[idx].begin_time + math.ceil((loop.now() - pool_cfg[idx].begin_time) / pool_cfg[idx].duration) * pool_cfg[idx].duration
			local success = instance:updateSweepstakePlayerData(playerdata.last_free_time, playerdata.total_count, playerdata.has_used_gold, playerdata.last_draw_time, playerdata.today_draw_count, playerdata.random_count, playerdata.randnum, playerdata.flag, select_pool, 0, current_pool_end_time)
		end
	end
end

function process_query_sweepstake_player_info(conn, pid, req)
	--check
	local id = req[2]
	local t_now = math.floor(os.time())
	if not id then
		log.error("Player `%d` fail to query sweepstake player info, arg 2nd is invaild", pid)		
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_PLAYER_INFO_RESPOND, pid, {req[1], Command.RET_ERROR})
	end	
	log.info(string.format("Player `%d` try query sweepstake player info for id:%d",pid, id))
	local cfg_instance = SweepstakeConfig.Get()
	if not cfg_instance then
		log.error(string.format("Player `%d` fail to query sweepstake player info, cannot get cfg", pid))		
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_PLAYER_INFO_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local begin_time,end_time = cfg_instance:getActivityTimeByID(id)
	if not begin_time or not end_time then
		log.error(string.format("Player `%d` fail to query sweepstake player info, cannot get begin_time or end_time", pid))		
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_PLAYER_INFO_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	if  t_now < begin_time or t_now > end_time then
		log.error(string.format("Player `%d` fail to query sweepstake player info, activity not on time", pid))		
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_PLAYER_INFO_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local dataid = cfg_instance:getPlayerDataIDByID(id)
	if not dataid then
		log.error(string.format("Player `%d` fail to query sweepstake player info, cannot get dataid", pid))
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_PLAYER_INFO_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local free_gap = cfg_instance:getFreeTimeGapByID(id) 
	if not free_gap then
		log.error(string.format("Player `%d` fail to query sweepstake player info, cannot get freegap", pid))		
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_PLAYER_INFO_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local instance = Get(pid, dataid)
	if not instance then
		log.error(string.format("Player `%d` fail to query sweepstake player info, cannot get playermanager",pid))
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_PLAYER_INFO_RESPOND, pid, {req[1], Command.RET_ERROR})
	end	
	local playerdata = instance:getSweepstakePlayerData()
	if not playerdata then
		log.error(string.format("Player `%d` fail to query sweepstake player info, cannot get player data",pid))
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_PLAYER_INFO_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local cd = math.floor(os.time()) - playerdata.last_free_time		
	if free_gap > 0 and cd >= free_gap then
		cd = 0
	end

	CheckAndRefreshPool(pid, id)

	local pool_cfg = SweepstakePoolConfig.Get(id)
	local max_draw_count = 0
	if pool_cfg and pool_cfg[playerdata.current_pool] then
		max_draw_count = pool_cfg[playerdata.current_pool].max_draw_count
	end

	local player_info_amf = {
		playerdata.last_free_time,
		playerdata.total_count,
		playerdata.has_used_gold,
		playerdata.last_draw_time,
		playerdata.today_draw_count,
		playerdata.current_pool,
		playerdata.current_pool_draw_count,
		playerdata.current_pool_end_time,
		max_draw_count,
	}
	conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_PLAYER_INFO_RESPOND, pid, {req[1], Command.RET_SUCCESS, player_info_amf})
end
