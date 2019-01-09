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
local bit32 = require "bit32"
local yqerror = yqerror
local yqinfo = yqinfo

module "SweepstakeRewardConfig"

local id2instance = {}
local SweepstakeRewardConfig = {}

function SweepstakeRewardConfig:_init_(id)
	self.id = id
	self.finalRewardConfig = {}
	self.scoreRewardConfig = {}
	local ok, ret = database.query("SELECT rank_begin, rank_end, reward_type, reward_id, reward_value FROM sweepstakefinalrewardconfig WHERE id = %d ORDER BY rank_begin", id)
	if ok and #ret > 0 then
		for k, row in ipairs(ret) do
			table.insert(self.finalRewardConfig,{
				rank_begin = row.rank_begin,
				rank_end = row.rank_end,
				reward_type = row.reward_type,
				reward_id = row.reward_id,
				reward_value = row.reward_value,
			})
		end
	end
	local ok, ret = database.query("SELECT pos, score, reward_type, reward_id, reward_value FROM sweepstakescorerewardconfig WHERE id = %d ORDER BY pos", id)
	if ok and #ret > 0 then
		for k, row in ipairs(ret) do
			self.scoreRewardConfig[row.pos] = {
				pos = row.pos,
				score = row.score,
				reward_type = row.reward_type,
				reward_id = row.reward_id,
				reward_value = row.reward_value,
			}
		end
	end
end

function SweepstakeRewardConfig:getFinalRewardByRank(rank)
	for k,v in ipairs(self.finalRewardConfig) do
		if rank >= v.rank_begin and rank <= v.rank_end then
			return {{type = v.reward_type, id = v.reward_id, value = v.reward_value}}
		end
	end
end

function SweepstakeRewardConfig:getFinalReward()
	return self.finalRewardConfig
end

function SweepstakeRewardConfig:getScoreRewardByPos(pos)
	return self.scoreRewardConfig[pos]
end

function SweepstakeRewardConfig:getScoreReward()
	return self.scoreRewardConfig
end

function SweepstakeRewardConfig:getOddScoreReward(score, reward_flag)
	local odd_reward_tb = {}
	local ret_flag = reward_flag
	for k, v in pairs(self.scoreRewardConfig) do
		local pos = v.pos
		local mask = 2^(pos-1)
		local flag = bit32.band(reward_flag, mask)
		if flag == 0 and score >= v.score then
			table.insert(odd_reward_tb,{type = self.scoreRewardConfig[pos].reward_type, id = self.scoreRewardConfig[pos].reward_id, value = self.scoreRewardConfig[pos].reward_value})
			ret_flag = bit32.bor(ret_flag, mask)
		end
	end
	
	return odd_reward_tb,ret_flag
end

function SweepstakeRewardConfig:getConditionScoreByPos(pos)
	return self.scoreRewardConfig[pos].score
end

function Get(id)
	local instance = id2instance[id]
	if not instance then
		instance = Class.New(SweepstakeRewardConfig, id)
		id2instance[id] = instance 
	end
	return instance
end

function process_query_final_reward_config(conn, pid, req)
	local activity_id = req[2]
	if not activity_id then
		log.error("Player `%d` fail to get sweepstake_final_reward ,arg is wrong", pid)
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_FINAL_REWARD_CONFIG_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local cfg_instance = SweepstakeConfig.Get(activity_id)
	if not cfg_instance then
		log.error("Player `%d` fail to get sweepstake_final_reward ,cannot get sweepstakeconfig for id:%d", pid, activity_id)
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_FINAL_REWARD_CONFIG_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local reward_cfg_id = cfg_instance:getRewardCfgIDByID(activity_id)
	if not reward_cfg_id then
		log.error("Player `%d` fail to get sweepstake_final_reward ,cannot get reward_cfg_id", pid)
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_FINAL_REWARD_CONFIG_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local configManager = Get(reward_cfg_id)
	if not configManager then
		log.error("Player `%d` fail to get sweepstake_final_reward ,cannot get configManager for id:%d", pid, reward_cfg_id)
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_FINAL_REWARD_CONFIG_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local final_reward_cfg = configManager:getFinalReward()
	local final_reward_cfg_amf = {}
	for k,v in ipairs(final_reward_cfg) do
		local tb = {
			v.rank_begin,
			v.rank_end,
			v.reward_type,
			v.reward_id,
			v.reward_value,
		}
		table.insert(final_reward_cfg_amf, tb)
	end
	conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_FINAL_REWARD_CONFIG_RESPOND, pid, {req[1], Command.RET_SUCCESS, final_reward_cfg_amf})
end

function process_query_score_reward_config(conn, pid, req)
	local activity_id = req[2]
	if not activity_id then
		log.error("Player `%d` fail to get sweepstake_score_reward ,arg is wrong", pid)
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_SCORE_REWARD_CONFIG_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local cfg_instance = SweepstakeConfig.Get(activity_id)
	if not cfg_instance then
		log.error("Player `%d` fail to get sweepstake_score_reward ,cannot get sweepstakeconfig for id:%d", pid, activity_id)
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_SCORE_REWARD_CONFIG_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local reward_cfg_id = cfg_instance:getRewardCfgIDByID(activity_id)
	if not reward_cfg_id then
		log.error("Player `%d` fail to get sweepstake_score_reward ,cannot get reward_cfg_id", pid)
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_SCORE_REWARD_CONFIG_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local configManager = Get(reward_cfg_id)
	if not configManager then
		log.error("Player `%d` fail to get sweepstake_score_reward ,cannot get sweepstakescorerewardconfig for id:%d", pid, reward_cfg_id)
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_SCORE_REWARD_CONFIG_RESPOND, pid, {req[1], Command.RET_ERROR})
	end
	local score_reward_cfg = configManager:getScoreReward()
	local score_reward_cfg_amf = {}
	for k,v in ipairs(score_reward_cfg) do
		local tb = {
			v.pos,
			v.score,
			v.reward_type,
			v.reward_id,
			v.reward_value,
		}
		table.insert(score_reward_cfg_amf, tb)
	end
	conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_SCORE_REWARD_CONFIG_RESPOND, pid, {req[1], Command.RET_SUCCESS, score_reward_cfg_amf})
end



