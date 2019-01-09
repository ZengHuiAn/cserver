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
--local YQSTR = require "YQSTR"
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
local SweepstakeRewardConfig = require "SweepstakeRewardConfig"
local bit32 = require "bit32"
local cell = require "cell"
--require "printtb"

local sprinttb = sprinttb
local yqinfo = yqinfo
local yqerror = yqerror

module "SweepstakeRankManager"

local activityid2instance = {}
local SweepstakeRankManager = {}

local online = {};

function SweepstakeRankManager:_init_(activity_id)
	self.activity_id = activity_id
	self.rankList = {}
	self.rankListArray = {}
	local ok, ret = database.query("SELECT activity_id, pid, rank, score, UNIX_TIMESTAMP(score_update_time) as score_update_time, has_draw_final_reward, reward_flag, has_draw_score_reward FROM sweepstakerank WHERE activity_id = %d", activity_id)
	if ok and #ret > 0 then
		for k, row in ipairs(ret) do
			local tb = {
				activity_id = row.activity_id,
				pid = row.pid,
				rank = row.rank,
				score = row.score,
				score_update_time = row.score_update_time,
				has_draw_final_reward = row.has_draw_final_reward,
				reward_flag = row.reward_flag,
				has_draw_score_reward = row.has_draw_score_reward,
			}
			self.rankList[row.pid] = self.rankList[pid] or {}
			self.rankList[row.pid] = tb
			table.insert(self.rankListArray,tb)
		end
	end
end

function SweepstakeRankManager:getRankList()
	return self.rankListArray or {}
end

function SweepstakeRankManager:getPlayerScore(pid)
	return self.rankList[pid] and self.rankList[pid].score or 0
end

function SweepstakeRankManager:updateRankScore(pid, score, score_update_time)
	local activity_id = self.activity_id
	if not self.rankList[pid] then
		local ok = database.update("INSERT INTO sweepstakerank(activity_id, pid, rank, score, score_update_time, has_draw_final_reward, reward_flag, has_draw_score_reward) VALUES(%d, %d, %d, %d, from_unixtime_s(%d), %d, %d, %d)", activity_id, pid, 0, score, score_update_time, 0, 0, 0)
		if not ok then
			log.error("Player `%d` fail to update sweepstakerank score, mysql error", pid)
			return 
		end
		local tb = {
			activity_id = activity_id,
			pid = pid,
			rank = 0,
			score = score,
			score_update_time = score_update_time,
			has_draw_final_reward = 0,
			reward_flag = 0,
			has_draw_score_reward = 0,
		}
		self.rankList[pid] = tb
		table.insert(self.rankListArray, tb)
	else
		local ok = database.update("UPDATE sweepstakerank set score=%d, score_update_time=from_unixtime_s(%d) WHERE activity_id=%d AND pid=%d", self.rankList[pid].score+score, score_update_time, activity_id, pid)
		if not ok then
			log.error("Player `%d` fail to update sweepstakerank score, mysql error", pid)
			return 
		end
		self.rankList[pid].score = self.rankList[pid].score + score
		self.rankList[pid].score_update_time = score_update_time
	end
end

function SweepstakeRankManager:getScore(pid)
	return self.rankList[pid] and self.rankList[pid].score or 0
end

function SweepstakeRankManager:checkAndSendManualReward(pid)
	local activity_id = self.activity_id
	local this = self
	if not activity_id then
		yqerror("Player `%d` fail to checkAndSendManualReward, cannot get activity_id ", pid, activity_id)
	end	
	if self.rankList[pid] then
		yqinfo("Player `%d` begin to checkAndSendManualReward", pid)
		if self.rankList[pid].has_draw_final_reward ~= 1 and online[pid] and self.rankList[pid].rank then
			local send_success = this:sendFinalReward(pid, self.rankList[pid].rank)
			if send_success then
				local ok = database.update("UPDATE sweepstakerank set has_draw_final_reward=%d WHERE activity_id=%d AND pid=%d", 1, activity_id, pid)
				if not ok then
					yqerror("Player `%d` fail to update has_draw_final_reward for activity_id:%d , mysql error", pid, activity_id)
				else	
					self.rankList[pid].has_draw_final_reward = 1
				end
			end
		end			
		if self.rankList[pid].has_draw_score_reward ~= 1 and online[pid] then
			local send_success,ret_flag = this:sendScoreReward(pid, self.rankList[pid].score, self.rankList[pid].reward_flag)
			if send_success then
				local ok = database.update("UPDATE sweepstakerank set has_draw_score_reward=%d WHERE activity_id=%d AND pid=%d", 1, activity_id, pid)
				if not ok then
					yqerror("Player `%d` fail to update has_draw_score_reward for activity_id:%d , mysql error", pid, activity_id)
				else
					self.rankList[pid].has_draw_score_reward = 1
				end
				if ret_flag ~= self.rankList[pid].reward_flag then
					local ok = database.update("UPDATE sweepstakerank set reward_flag=%d WHERE activity_id=%d AND pid=%d", ret_flag, activity_id, pid)
					if not ok then
						yqerror("Player `%d` fail to update reward_flag for activity_id:%d, mysql error", pid, activity_id)
					else
						self.rankList[pid].reward_flag = ret_flag
					end
				end
			end
		end
	end
end

function SweepstakeRankManager:settleReward()
	local success = true 
	local activity_id = self.activity_id
	local this = self
	if not activity_id then
		yqerror("sweepstakerank settleReward fail, cannot get activity_id")
		return false
	end	
	if not self.rankListArray then
		yqerror("sweepstakerank settleReward fail, cannot get rankList for id：%d", activity_id)
		return false
	end
	table.sort(self.rankListArray, function (a, b)
		if a.score ~= b.sore then
			return a.score > b.score
		end
		if a.score_update_time ~=b.score_update_time then
			return a.score_update_time < b.score_update_time
		end
		if a.pid ~= b.pid then
			return a.pid < b.pid
		end
	end)	
	for k, v in ipairs(self.rankListArray or {}) do 
		local ok = database.update("UPDATE sweepstakerank set rank=%d WHERE activity_id=%d AND pid=%d", k, activity_id, v.pid)
		if not ok then
			yqerror("Player `%d` fail to update rank for activity_id:%d, mysql error, rank:%d", v.pid, activity_id, k)
			success = false
		else
			v.rank = k
			if v.has_draw_final_reward ~= 1 and online[v.pid] then
				local send_success = this:sendFinalReward(v.pid, v.rank)
				if send_success then
					local ok = database.update("UPDATE sweepstakerank set has_draw_final_reward=%d WHERE activity_id=%d AND pid=%d", 1, v.activity_id, v.pid)
					if not ok then
						yqerror("Player `%d` fail to update has_draw_final_reward for activity_id:%d mysql error", v.pid, activity_id)
						success = false
					else	
						v.has_draw_final_reward = 1
					end
				end
			else
				yqinfo("Player `%d` has draw final reward", v.pid)
			end	
			if v.has_draw_score_reward ~= 1 and online[v.pid] then
				local send_success, ret_flag = this:sendScoreReward(v.pid, v.score, v.reward_flag)
				if send_success then
					local ok = database.update("UPDATE sweepstakerank set has_draw_score_reward=%d WHERE activity_id=%d AND pid=%d", 1, v.activity_id, v.pid)
					if not ok then
						yqerror("Player `%d` fail to update has_draw_score_reward for activity_id:%d, mysql error ", v.pid, activity_id)
						success = false
					else
						v.has_draw_score_reward = 1
					end
					if ret_flag ~= v.reward_flag then
						local ok = database.update("UPDATE sweepstakerank set reward_flag=%d WHERE activity_id=%d AND pid=%d", ret_flag, v.activity_id, v.pid)
						if not ok then
							yqerror("Player `%d` fail to update reward_flag for activity_id:%d, mysql error", v.pid, activity_id)
							success = false
						else
							v.reward_flag = ret_flag
						end
					end
				end
			else
				yqinfo("Player `%d` has draw final reward", v.pid)
			end	
		end
	end
	return success
end

function SweepstakeRankManager:sendFinalReward(pid, rank)
	local activity_id = self.activity_id
	local cfg_instance = SweepstakeConfig.Get(activity_id)
	if not cfg_instance then
		log.error("fail to sendFinalReward to Player `%d`, cannot get sweepstakeconfig", pid)
		return false
	end
	local reward_cfg_id = cfg_instance:getRewardCfgIDByID(activity_id)
	local reward_cfg_instance = SweepstakeRewardConfig.Get(reward_cfg_id)
	local final_reward = reward_cfg_instance:getFinalRewardByRank(rank)
	if final_reward and #final_reward > 0 then
		if activity_id > 10000 then
			cell.sendReward(pid, final_reward, {}, Command.REASON_SWEEPSTAKE_JIANGLIN_FINAL_REWARD, true, math.floor(os.time()) + 30*24*3600, string.format(YQSTR.SWEEPSTAKE_JIANGLIN_FINAL_REWARD, rank))	
		else
			cell.sendReward(pid, final_reward, {}, Command.REASON_SWEEPSTAKE_FINAL_REWARD, true, math.floor(os.time()) + 30*24*3600, string.format(YQSTR.SWEEPSTAKE_FINAL_REWARD, rank))	
		end
		return true
	else
		log.info("Player `%d` dont has final_reward for rank:%d", rank)
		return true 
	end
end

function SweepstakeRankManager:sendScoreReward(pid, score, reward_flag)
	local activity_id = self.activity_id
	local cfg_instance = SweepstakeConfig.Get(activity_id)
	if not cfg_instance then
		log.error("fail to sendScoreReward to Player `%d`, cannot get sweepstakeconfig", pid)
		return false
	end
	local reward_cfg_id = cfg_instance:getRewardCfgIDByID(activity_id)
	local reward_cfg_instance = SweepstakeRewardConfig.Get(reward_cfg_id)
	local odd_score_reward,ret_flag = reward_cfg_instance:getOddScoreReward(score, reward_flag)
	if odd_score_reward and #odd_score_reward > 0 then
		for k,v in ipairs(odd_score_reward) do
			if activity_id > 10000 then
		    	cell.sendReward(pid, {v}, {}, Command.REASON_SWEEPSTAKE_JIANGLIN_SCORE_REWARD, true, math.floor(os.time()) +30*24*3600, YQSTR.SWEEPSTAKE_JIANGLIN_SCORE_REWARD)	
			else
		    	cell.sendReward(pid, {v}, {}, Command.REASON_SWEEPSTAKE_SCORE_REWARD, true, math.floor(os.time()) +30*24*3600, YQSTR.SWEEPSTAKE_SCORE_REWARD)	
			end
		end
		return true, ret_flag
	else
		log.info("Player `%d` dont has odd_score_reward ", pid)
		return true, reward_flag 
	end
end

function SweepstakeRankManager:getRewardFlag(pid)
	return self.rankList[pid] and self.rankList[pid].reward_flag or 0 
end

function SweepstakeRankManager:isScoreRewardHasDraw(pid, pos)
	local now_flag = self:getRewardFlag(pid)
	local mask = 2^(pos-1)
	if bit32.band(now_flag,mask) == 0 then
		return false 
	else
		return true 
	end
end

function SweepstakeRankManager:updateRewardFlag(pid, pos)
	if not self:isScoreRewardHasDraw(pid, pos) then
		local now_flag = self:getRewardFlag(pid)
		local mask = 2^(pos-1)
		local ret_flag = bit32.bor(now_flag,mask)
		local ok =	database.update("UPDATE sweepstakerank set reward_flag=%d WHERE activity_id=%d AND pid=%d", ret_flag, self.activity_id, pid)
		if not ok then
			yqerror("Player `%d` fail to update reward_flag , mysql error", pid)
			return false
		end
		self.rankList[pid].reward_flag = ret_flag
		return true
	end
	return false
end



function Get(activity_id)
	local instance = activityid2instance[activity_id]
	if not instance then
		instance = Class.New(SweepstakeRankManager, activity_id)
		activityid2instance[activity_id] = instance 
	end
	return instance
end

function Login(id, conn)
	log.debug(string.format('player %u login begin to checkAndSendManualReward', id));
	online[id] = true;
	local cfg_instance = SweepstakeConfig.Get()
	if not cfg_instance then
		yqerror("fail to checkAndSendManualReward, cannot get sweepstakeconfig")
		return
	end	
	local map_cfg = cfg_instance:getMapConfig()		
	for k, v in pairs(map_cfg) do
		local activity_id = k
		local status = cfg_instance:getStatusByID(activity_id)
		if status and status == 1 then
			local rankManager = Get(activity_id)
			rankManager:checkAndSendManualReward(id)
		end
	end
end

function Logout(id)
	log.debug(string.format('player %u logout', id));
	online[id] = nil;
end

function process_query_ranklist(conn, pid, req)
	local activity_id = req[2]
	local req_num = req[3]
	if not activity_id or not req_num then
		log.error("Player `%d` fail to get ranklist ,arg 2nd or 3rd id wrong", pid)
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_RANKLIST_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local rankManager = Get(activity_id)
	if not rankManager then
		log.error("Player `%d` fail to get ranklist, cannot get rankManager for activity_id:%d", pid, activity_id)
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_RANKLIST_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local ranklist = rankManager:getRankList()
	table.sort(ranklist, function (a, b)
		if a.score ~= b.sore then
			return a.score > b.score
		end
		if a.score_update_time ~=b.score_update_time then
			return a.score_update_time < b.score_update_time
		end
		if a.pid ~= b.pid then
			return a.pid < b.pid
		end
	end)
	local ranklist_amf = {}
	for k, v in ipairs(ranklist) do
		if k <= req_num then
			local tb = {
				v.pid,
				v.score
			}
			table.insert(ranklist_amf,tb)
		else
			break
		end
	end
	conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_RANKLIST_RESPOND, pid, {req[1], Command.RET_SUCCESS, ranklist_amf})
end

function process_query_rankscore(conn, pid, req)
	local activity_id = req[2]
	if not activity_id then
		log.error("Player `%d` fail to get rank score, arg 2nd is wrong", pid)
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_SCORE_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local rankManager = Get(activity_id)
	if not rankManager then 
		log.error("Player `%d` fail to get rankscore, cannot get rankManager for activity_id:%d", pid, activity_id)
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_SCORE_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local score = rankManager:getPlayerScore(pid)
	local reward_flag = rankManager:getRewardFlag(pid)
	conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_SCORE_RESPOND, pid, {req[1], Command.RET_SUCCESS, score, reward_flag})
end

function process_achieve_reward(conn, pid, req)
	local activity_id = req[2]
	local pos = req[3]
	log.info("Player `%d` try to achieve scoreReward activity_id:%d pos:%d", pid, activity_id, pos)
	if not activity_id or not pos then
		log.error("Player `%d` fail to achieve scoreReward , arg wrong", pid)
		conn:sendClientRespond(Command.S_ACHIEVE_SWEEPSTAKE_SCORE_REWARD_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local cfg_instance = SweepstakeConfig.Get(activity_id)
	if not cfg_instance then
		log.error("Player `%d` fail to achieve scoreReward , cannot get sweepstakeconfig", pid)
		conn:sendClientRespond(Command.S_ACHIEVE_SWEEPSTAKE_SCORE_REWARD_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local reward_cfg_id = cfg_instance:getRewardCfgIDByID(activity_id)
	local reward_cfg_instance = SweepstakeRewardConfig.Get(reward_cfg_id)
	if not reward_cfg_instance then
		log.error("Player `%d` fail to achieve scoreReward `, cannot get sweepstakerewardconfig", pid)
		conn:sendClientRespond(Command.S_ACHIEVE_SWEEPSTAKE_SCORE_REWARD_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local score_reward = reward_cfg_instance:getScoreRewardByPos(pos)
	local condition_score = reward_cfg_instance:getConditionScoreByPos(pos)

	local rankManager = Get(activity_id)
	if not rankManager then 
		log.error("Player `%d` fail to achieve scoreReward,  cannot get rankManager for activity_id:%d", pid, activity_id)
		conn:sendClientRespond(Command.S_ACHIEVE_SWEEPSTAKE_SCORE_REWARD_RESPOND, pid, {req[1], Command.RET_ERROR})
	end

	local score = rankManager:getScore(pid)
	if score_reward and score >= condition_score then
		if not rankManager:isScoreRewardHasDraw(pid,pos) then
			rankManager:updateRewardFlag(pid,pos)
			cell.sendReward(pid, {{type=score_reward.reward_type, id=score_reward.reward_id, value=score_reward.reward_value}}, {}, Command.REASON_SWEEPSTAKE_SCORE_REWARD)
			conn:sendClientRespond(Command.S_ACHIEVE_SWEEPSTAKE_SCORE_REWARD_RESPOND, pid, {req[1], Command.RET_SUCCESS})	
		else
			log.error("Player `%d` fail to achieve scoreReward, already has draw", pid)
			conn:sendClientRespond(Command.S_ACHIEVE_SWEEPSTAKE_SCORE_REWARD_RESPOND, pid, {req[1], Command.RET_ERROR})	
		end	
	else
		log.error("Player `%d` fail to achieve scoreReward, score not enough", pid)
		conn:sendClientRespond(Command.S_ACHIEVE_SWEEPSTAKE_SCORE_REWARD_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
end
