local database = require "database"
local cell = require "cell"
local Command = require "Command"
local protobuf = require "protobuf"
local Agent = require "Agent"
require "Thread"

local ORIGIN_TIME = 1497801600 		-- 2017/6/19 0:0:0
local WEEK_INTERVAL = 3600 * 24 * 7
local function deadTime()
	local n = math.floor((loop.now() - ORIGIN_TIME) / WEEK_INTERVAL) + 1
	return ORIGIN_TIME + WEEK_INTERVAL * n
end


local PlayerList = {}
local TeamList = {}
local RoutineList = {}

math.randomseed(os.time())

------------ database table --------------------
local PlayerTable = {}
function PlayerTable.Select(pid)
	local ok, result = database.query([[select `pid`, `team_id`, `is_AI`, `credits`, unix_timestamp(`deadtime`) as `deadtime`, `week_count`, 
		`answer_correct`, `is_answer`, unix_timestamp(`answer_time`) as `answer_time`, `correct_count`, `next_type` from `answer_info` where `pid` = %d;]], pid)
	if ok and #result > 0 then
		log.debug("select answer_info success: pid = ", pid)
		return result[1]
	else
		return nil
	end		
end

function PlayerTable.Insert(info)
	local ok = database.update([[replace into `answer_info`(`pid`, `team_id`, `is_AI`, `credits`, `deadtime`, `week_count`, `answer_correct`, `is_answer`,`answer_time`, `correct_count`, 
		`next_type`) values(%d, %d, %d, %d, from_unixtime_s(%d), %d, %d, %d, from_unixtime_s(%d), %d, %d);]],
		info.pid, info.team_id, info.is_AI, info.credits, info.deadtime, info.week_count, info.answer_correct, info.is_answer, info.answer_time, info.correct_count, info.next_type)
	if not ok then
		log.debug("replace into answer_info failed: pid = ", info.pid)
	end

	return ok
end

function PlayerTable.UpdateTeamId(pid, tid)
	local ok = database.update([[update `answer_info` set `team_id` = %d where `pid` = %d;]], tid, pid)
	if not ok then
		log.debug("update answer_info set team_id failed: ", pid, tid)
	end

	return ok
end

function PlayerTable.UpdateWeekQuizCount(pid, n)
	local ok = database.update([[update `answer_info` set `week_count` = %d where `pid` = %d;]], n, pid)
	if not ok then
		log.debug("update answer_info set week_count failed: ", pid, n)
	end

	return ok
end

function PlayerTable.UpdateDeadTime(pid, time)
	local ok = database.update([[update `answer_info` set `deadtime` = from_unixtime_s(%d) where `pid` = %d;]], time, pid)
	if not ok then
		log.debug("update answer_info set deadtime failed: ", pid, time)
	end

	return ok
end

function PlayerTable.UpdateCorrectStatus(pid, status)
	local ok = database.update([[update `answer_info` set `answer_correct` = %d where `pid` = %d;]], status, pid)
	if not ok then
		log.debug("update answer_info set answer_correct failed: ", pid, status)
	end

	return ok
end

function PlayerTable.UpdateIsAnswer(pid, flag)
	local ok = database.update([[update `answer_info` set `is_answer` = %d where `pid` = %d;]], flag, pid)
	if not ok then
		log.debug("update answer_info set is_answer failed: ", pid, flag)
	end

	return ok
end

function PlayerTable.UpdateCorrectCount(pid, n)
	local ok = database.update([[update `answer_info` set `correct_count` = %d where `pid` = %d;]], n, pid)
	if not ok then
		log.debug("update answer_info set correct_count failed: ", pid, n)
	end

	return ok
end

function PlayerTable.UpdateNextType(pid, type)
	local ok = database.update([[update `answer_info` set `next_type` = %d where `pid` = %d;]], type, pid)
	if not ok then
		log.debug("update answer_info set next_type failed: ", pid, type)
	end

	return ok
end

function PlayerTable.UpdateAnswerTime(pid, time)
	local ok = database.update([[update `answer_info` set `answer_time` = from_unixtime_s(%d) where `pid` = %d;]], time, pid)
	if not ok then
		log.debug("update answer_info set answer_time failed: ", pid, time)
	end

	return ok
end

function PlayerTable.UpdateCredits(pid, n)
	local ok = database.update([[update `answer_info` set `credits` = %d where `pid` = %d;]], n, pid)
	if not ok then
		log.debug("update answer_info set credits failed: ", pid, n)
	end

	return ok
end

function PlayerTable.ResetStatus(pid)
	local ok = database.update([[update `answer_info` set `answer_correct` = %d, `is_answer` = %d, `answer_time` = from_unixtime_s(%d) where `pid` = %d;]],
		0, 0, 0, pid)
	if not ok then
		log.debug("reset answer_info failed: pid = ", pid)
	end

	return ok
end

function PlayerTable.Clear(pid)
	local ok = database.update([[update `answer_info` set `team_id` = %d, `is_AI` = %d, `credits` = %d, `answer_correct` = %d,
		`is_answer` = %d, `answer_time` = %d, `correct_count` = %d, `next_type` = %d where `pid` = %d;]], 0, 0, 0, 0, 0, 0, 0, 0, pid)
	if not ok then
		log.debug("clear answer_info failed: ", pid)
	end

	return ok
end

function PlayerTable.Delete(pid)
	local ok = database.update([[delete from `answer_info` where `pid` = %d;]], pid)
	if not ok then
		log.debug("delete from answer_info failed: ", pid)
	end	

	return ok
end

function PlayerTable.UpdateAIStatus(pid, status)
	local ok = database.update([[update `answer_info` set `is_AI` = %d where `pid` = %d;]], status, pid)
	if not ok then
		log.debug("update answer_info set is_AI failed: ", pid, status)
	end
	
	return ok
end

------------------------------------------------------------------
local TeamTable = {}
function TeamTable.Select(tid)
	local ok, result = database.query([[select `team_id`, `round`, `pindex`, `qid`, unix_timestamp(`publish_time`) as `publish_time`, `pid1`, `pid2`, `pid3`, `pid4`, pid5
		from `answer_team_info` where team_id = %d;]], tid)
	if ok and #result then
		log.debug("select answer_team_info success: team_id = ", tid)
		return result[1]
	else
		return nil
	end
end

function TeamTable.Insert(info)
	local ok = database.update([[insert into `answer_team_info`(`round`, `pindex`, `qid`, `publish_time`, `pid1`, `pid2`, `pid3`, `pid4`, `pid5`) 
		values(%d, %d, %d, from_unixtime_s(%d), %d, %d, %d, %d, %d);]], 
		info.round, info.qid, info.pindex, info.publish_time, info.pid1, info.pid2, info.pid3, info.pid4, info.pid5 )
	if not ok then
		log.debug("insert into answer_team_info failed: team_id = ", info.team_id)
	end

	return ok
end

function TeamTable.SelectTid(list)
	local ok, result = database.query([[select `team_id` from `answer_team_info` where `pid1` = %d and `pid2` = %d and `pid3` = %d and `pid4` = %d and `pid5` = %d;]],
		list[1], list[2], list[3], list[4], list[5])
	if ok and #result > 0 then
		log.debug("select team_id success: ", result[1].team_id)
		return result[1].team_id
	end

	return 0
end

function TeamTable.UpdateRound(tid, n)
	local ok = database.update([[update `answer_team_info` set `round` = %d where `team_id` = %d;]], n, tid)

	if not ok then
		log.debug("update answer_team_info set round failed: ", tid, n)
	end

	return ok
end

function TeamTable.UpdatePublishTime(tid, time)
	local ok = database.update([[update `answer_team_info` set `publish_time` = from_unixtime_s(%d) where `team_id` = %d;]], time, tid)

	if not ok then
		log.debug("update answer_team_info set publish_time failed: ", tid, time)
	end

	return ok
end

function TeamTable.UpdateQid(tid, qid)
	local ok = database.update([[update `answer_team_info` set `qid` = %d where `team_id` = %d;]], qid, tid)
	if not ok then
		log.debug("update answer_team_info set qid failed: ", tid, qid)
	end
	
	return ok
end

function TeamTable.UpdatePindex(tid, index)
	local ok = database.update([[update `answer_team_info` set `pindex` = %d where `team_id` = %d;]], index, tid)
	if not ok then
		log.debug("update answer_team_info set pindex failed: ", tid, index)
	end
	
	return ok
end

function TeamTable.Delete(tid)
	local ok = database.update([[delete from `answer_team_info` where `team_id` = %d;]], tid)
	if not ok then
		log.debug("delete from answer_team_info failed: ", tid)
	end

	return ok
end

---------------------- config --------------------------
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

local QuestionBank = {}
function QuestionBank.Load()
	local cfg = readFile("../etc/config/quiz/config_datijingsai.pb", "config_datijingsai")
	if cfg then
		log.debug("read config_datijingsai success.")
		QuestionBank.content = {}
		QuestionBank.content2 = {}
		for i, v in ipairs(cfg.rows) do
			if v.type == 1 then
				QuestionBank.content[v.zhonglei] = QuestionBank.content[v.zhonglei] or {}
				QuestionBank.content[v.zhonglei][v.id] = { answer1 = v.right_answer1, answer2 = right_answer2, answer3 = right_answer3 }
				QuestionBank.content2[v.id] = { type = v.zhonglei, answer1 = v.right_answer1, answer2 = right_answer2, answer3 = right_answer3 }
			end
		end
	end
end

function QuestionBank.IsEmpty()
	if QuestionBank.content == nil then
		return true
	end

	return false
end

function QuestionBank.IsCorrect(qid, answer)
	if QuestionBank.IsEmpty() then
		QuestionBank.Load()
	end	

	local temp = QuestionBank.content2[qid]
	if temp == nil or answer == 0 then
		log.debug("answer = ", answer)
		return false
	end
	if answer == temp.answer1 or answer == temp.answer2 or answer == temp.answer3 then
		return true
	else
		return false
	end
end

function QuestionBank.hasType(type)
	if QuestionBank.IsEmpty() then
		QuestionBank.Load()
	end	

	for i, _ in pairs(QuestionBank.content) do
		if i == type then
			return true
		end
	end 

	return false
end

function QuestionBank.GetTypeList()
	if QuestionBank.IsEmpty() then
		QuestionBank.Load()
	end	

	local ret = {}
	for t, _ in pairs(QuestionBank.content) do
		table.insert(ret, t)
	end

	return ret
end

function QuestionBank.GetIdListByType(type, mask)
	if QuestionBank.IsEmpty() then
		QuestionBank.Load()
	end

	local ret = {}
	for qid, _ in pairs(QuestionBank.content[type]) do
		if not mask[qid] then
			table.insert(ret, qid)
		end
	end

	return ret
end

------------------------------------------------------
local AI = {}
function AI.Load()	
	local cfg = readFile("../etc/config/quiz/ainame_zhoudati.pb", "ainame_zhoudati")
	if cfg then
		log.debug("load ainame_zhoudati success.")
		AI.content = {}
		AI.content2 = {}
		AI.index = 1
		for i, v in ipairs(cfg.rows) do
			AI.content[v.id] = { id = v.id, name = v.name, icon = v.icon }
			table.insert(AI.content2, v.id)
		end	
	end
end

AI.Load()

function AI.GetId()
	if AI.content == nil then
		AI.Load()		
	end

	if #AI.content2 == 0 then
		return 0
	end

	local n = math.random(#AI.content2)
	local id = AI.content2[n]
	table.remove(AI.content2, n)

	return id
end

function AI.PutId(id)
	if type(id) == "number" then
		table.insert(AI.content2, id)
	end	
end

-------------------------------------------------------
local RewardBank = {}
function RewardBank.Load()
	local cfg = readFile("../etc/config/quiz/config_reward_zhoudati.pb", "config_reward_zhoudati")
	if cfg then
		RewardBank.content = {}
		for i, v in ipairs(cfg.rows) do
			RewardBank.content[v.id] = {}
			if v.reward_type1 > 0 then
				table.insert(RewardBank.content[v.id], { type = v.reward_type1, id = v.reward_id1, value = v.reward_value1 })
			end
			if v.reward_type2 > 0 then
				table.insert(RewardBank.content[v.id], { type = v.reward_type2, id = v.reward_id2, value = v.reward_value2 })
			end
			if v.reward_type3 > 0 then
				table.insert(RewardBank.content[v.id], { type = v.reward_type3, id = v.reward_id3, value = v.reward_value3 })
			end
		end
	end
end

function RewardBank.IsEmpty()
	if RewardBank.content == nil then
		return true
	end

	return false
end

function RewardBank.GetIdList()
	if RewardBank.IsEmpty() then
		RewardBank.Load()
	end

	local ret = {}
	for id, _ in pairs(RewardBank.content) do
		table.insert(ret, id)
	end

	return ret
end

function RewardBank.GetReward(id)
	if RewardBank.IsEmpty() then
		RewardBank.Load()
	end

	return RewardBank.content[id]
end

---------------------- class ---------------------------
local Player = {}
function Player.New(pid, tid, isAI, qtype)
	local time = 0
	if is_AI == 2 then
		time = math.random(loop.now() + 5, loop.now() + 35)
	end

	local o = { pid = pid, team_id = tid, is_AI = isAI, credits = 0, deadtime = deadTime(), week_count = 0, 
			answer_correct = 0, is_answer = 0, answer_time = time, correct_count = 0, next_type = qtype }
	PlayerTable.Insert(o)
	return setmetatable(o, {__index = Player})
end

function Player.New2(o)
	return setmetatable(o, {__index = Player})
end

-- 是否可以答题
function Player:IsQuiz()
	if self.deadtime < loop.now() then
		self:UpdateWeekQuizCount(0)
		self:UpdateDeadTime(deadTime())
	end
	if self.week_count > 0 then
		return false
	end
	return true
end

function Player:IsInTeam()
	if self.team_id ~= 0 then
		return true
	end

	return false
end

function Player:UpdateWeekQuizCount(n)
	local ok = PlayerTable.UpdateWeekQuizCount(self.pid, n)
	if ok then
		self.week_count = n
	end
end

function Player:UpdateDeadTime(time)
	local ok = PlayerTable.UpdateDeadTime(self.pid, time)
	if ok then
		self.deadtime = time
	end
end

function Player:UpdateCorrectStatus(status)
	local ok = PlayerTable.UpdateCorrectStatus(self.pid, status)

	if ok then
		self.answer_correct = status
	end
end

function Player:UpdateIsAnswer(flag)
	local ok = PlayerTable.UpdateIsAnswer(self.pid, flag)

	if ok then
		self.is_answer = flag
	end
end

function Player:UpdateCorrectCount(n)
	local ok = PlayerTable.UpdateCorrectCount(self.pid, n)
	
	if ok then
		self.correct_count = n
	end
end

function Player:UpdateNextType(type)
	local ok = PlayerTable.UpdateNextType(self.pid, type)

	if ok then
		self.next_type = type
	end
end

function Player:UpdateTeamId(team_id)
	local ok = PlayerTable.UpdateTeamId(self.pid, team_id)

	if ok then
		self.team_id = team_id
	end
end

function Player:UpdateAnswerTime(time)
	local ok = PlayerTable.UpdateAnswerTime(self.pid, time)

	if ok then
		self.answer_time = time
	end
end

function Player:UpdateCredits(n)
	local ok = PlayerTable.UpdateCredits(self.pid, n)

	if ok then
		self.credits = n
	end
end

function Player:ResetStatus()
	local ok = PlayerTable.ResetStatus(self.pid)

	if ok then
		self.answer_correct = 0
		self.is_answer = 0
		self.answer_time = 0
	end
end

function Player:Clear()
	local ok = PlayerTable.Clear(self.pid)
	if ok then
		PlayerList.Remove(self.pid)
	end
end

function Player:Delete()
	local ok = PlayerTable.Delete(self.pid)
	if ok then
		PlayerList.Remove(self.pid)
	end
end


function Player:UpdateAIStatus(status)
	local ok = PlayerTable.UpdateAIStatus(self.pid, status)
	if ok then
		self.is_AI = status
	end
end


-----------------------------------------------------------
local Team = {}
function Team.New(list)
	if list == nil then
		log.debug("Team new failed.")
		return nil
	end
	
	-- map 里面存储的是已经答过的题目
	local o = { round = 1, pindex = 1, qid = 0, publish_time = loop.now(), pid1 = list[1], pid2 = list[2], pid3 = list[3], pid4 = list[4], pid5 = list[5], map = {} }

	local ok = TeamTable.Insert(o)
	if ok then
		local id = TeamTable.SelectTid(list)
		o.team_id = id
	end

	return setmetatable(o, {__index = Team})
end

function Team.New2(o)
	return setmetatable(o, {__index = Team})
end

-- 获取非AI的玩家id列表
function Team:GetNonAIPidList()
	local ret = {}

	local p1 = PlayerList.GetPlayer(self.pid1)
	if p1 and p1.is_AI == 0 then
		table.insert(ret, self.pid1)
	end

	local p2 = PlayerList.GetPlayer(self.pid2)
	if p2 and p2.is_AI == 0 then
		table.insert(ret, self.pid2)
	end

	local p3 = PlayerList.GetPlayer(self.pid3)
	if p3 and p3.is_AI == 0 then
		table.insert(ret, self.pid3)
	end

	local p4 = PlayerList.GetPlayer(self.pid4)
	if p4 and p4.is_AI == 0 then
		table.insert(ret, self.pid4)
	end

	local p5 = PlayerList.GetPlayer(self.pid5)
	if p5 and p5.is_AI == 0 then
		table.insert(ret, self.pid5)
	end

	return ret
end

-- 获取所有玩家的id列表(包括AI)
function Team:GetPidList()
	local ret = {}
	table.insert(ret, self.pid1)
	table.insert(ret, self.pid2)
	table.insert(ret, self.pid3)
	table.insert(ret, self.pid4)
	table.insert(ret, self.pid5)

	return ret	
end

-- 获取AI玩家的id列表
function Team:GetAIPidList()
	local ret = {}

	local p1 = PlayerList.GetPlayer(self.pid1)
	if p1 and p1.is_AI ~= 0 then
		table.insert(ret, self.pid1)
	end

	local p2 = PlayerList.GetPlayer(self.pid2)
	if p2 and p2.is_AI ~= 0 then
		table.insert(ret, self.pid2)
	end

	local p3 = PlayerList.GetPlayer(self.pid3)
	if p3 and p3.is_AI ~= 0 then
		table.insert(ret, self.pid3)
	end

	local p4 = PlayerList.GetPlayer(self.pid4)
	if p4 and p4.is_AI ~= 0 then
		table.insert(ret, self.pid4)
	end

	local p5 = PlayerList.GetPlayer(self.pid5)
	if p5 and p5.is_AI ~= 0 then
		table.insert(ret, self.pid5)
	end

	return ret
end

-- 根据当前时间判断AI是否到了答题的时间
function Team:AIAnswerTheQuestion()
	local aiList = self:GetAIPidList()	
	if #aiList == 0 then
		return {} 
	end
	
	local ret = {}
	for _, pid in ipairs(aiList) do
		local player = PlayerList.GetPlayer(pid)
		if player and player.is_answer == 0 and player.answer_time <= loop.now() then
			player:UpdateIsAnswer(1)
			local num = math.random(10)
			if num <= 3 then
				player:UpdateCorrectStatus(1)
				player:UpdateCorrectCount(player.correct_count + 1)
			else
				local typeList = QuestionBank.GetTypeList()
				local num = math.random(#typeList)
				player:UpdateNextType(typeList[num])
			end
			table.insert(ret, pid)
		end
	end
	return ret
end

-- 为所有的非AI还没回答的人随机选择一个答案
function Team:RandomSelect()
	local list = self:GetPidList()
	local ret = {}
	for _, pid in ipairs(list) do
		local player = PlayerList.GetPlayer(pid)
		if player and player.is_answer == 0 then
--[[
			local num = math.random(10)
			if num <= 3 then
				player:UpdateCorrectStatus(1)
				player:UpdateCorrectCount(player.correct_count + 1)
				player:UpdateAnswerTime(self.publish_time + 35)
			end
--]]
			player:UpdateIsAnswer(1)
			table.insert(ret, pid)	
		end
	end
	return ret
end

-- 是否全体成员都回答了问题
function Team:AllMemberAnswer()
	for _, pid in ipairs(self:GetPidList()) do
		local player = PlayerList.GetPlayer(pid)
		if player.is_answer ~= 1 then
			return false
		end
	end

	return true
end

-- 是否全部的玩家都是AI
function Team:IsAllAI()
	local p1 = PlayerList.GetPlayer(self.pid1)
	if p1 and p1.is_AI == 0 then
		return false
	end

	local p2 = PlayerList.GetPlayer(self.pid2)
	if p2 and p2.is_AI == 0 then
		return false
	end

	local p3 = PlayerList.GetPlayer(self.pid3)
	if p3 and p3.is_AI == 0 then
		return false
	end

	local p4 = PlayerList.GetPlayer(self.pid4)
	if p4 and p4.is_AI == 0 then
		return false
	end

	local p5 = PlayerList.GetPlayer(self.pid5)
	if p5 and p5.is_AI == 0 then
		return false
	end

	return true
end

function Team:UpdateRound(n)
	local ok = TeamTable.UpdateRound(self.team_id, n)

	if ok then
		self.round = n
	end
end

function Team:UpdateQid(q)
	local ok = TeamTable.UpdateQid(self.team_id, q)

	if ok then
		self.qid = q
	end
end

function Team:UpdatePindex()
	local pindex = 0
	if self.pindex < 5 then
		pindex = self.pindex + 1
	else
		pindex = 1
	end
	local ok = TeamTable.UpdatePindex(self.team_id, pindex)

	if ok then
		self.pindex = pindex
	end
end

function Team:GetQtype()
	local pidList = self:GetPidList()
	local player = PlayerList.GetPlayer(pidList[self.pindex])
	return player.next_type
end

function Team:GetSelectId() 
	local pidList = self:GetPidList()
	local player = PlayerList.GetPlayer(pidList[self.pindex])
	return player.pid
end

-- 获得回答正确的玩家
function Team:GetAnswerRight()
	local pidList = self:GetPidList()
	local ret = {}

	for _, pid in ipairs(pidList) do
		local player = PlayerList.GetPlayer(pid)
		if player and player.answer_correct == 1 then
			table.insert(ret, { pid = pid, answer_time = player.answer_time })
		end
	end

	return ret	
end

-- 增加积分
function Team:AddCredits()
	if not self:AllMemberAnswer() then
		return
	end

	local rightLst = self:GetAnswerRight()
	table.sort(rightLst, function (i, j)
		return i.answer_time < j.answer_time
	end)
	local n = 5
	for _, v in ipairs(rightLst) do
		local player = PlayerList.GetPlayer(v.pid)
		player:UpdateCredits(player.credits + n)
		n = n - 1
	end
end

-- 计算得到的奖励的比例
function Team:CalculateRatio()
	local list = self:GetPidList()
	table.sort(list, function (i, j)
		local player1 = PlayerList.GetPlayer(i)
		local player2 = PlayerList.GetPlayer(j)	
		return player1.credits > player2.credits
	end)

	local ratio_pool = { 30, 25, 20, 15, 10 }

	local ret = {}

	for i = 1, #list do
		local player = PlayerList.GetPlayer(list[i])
		if ret[player.credits] == nil then
			ret[player.credits] = {}
			table.insert(ret[player.credits], ratio_pool[i])
			table.insert(ret[player.credits], list[i])
		else
			ret[player.credits][1] = ret[player.credits][1] + ratio_pool[i]
			table.insert(ret[player.credits], list[i])
		end
	end

	for _, v in pairs(ret) do
		local num = v[1] / (#v - 1)
		for i = 2, #v do
			local player = PlayerList.GetPlayer(v[i])
			player.award_ratio = num
		end		
	end	
end

-- 得到玩家的积分信息
function Team:GetCreditsInfo()
	local list = self:GetPidList()

	local ret = {}
	for _, pid in ipairs(list) do
		local player = PlayerList.GetPlayer(pid)
		table.insert(ret, { pid, player.credits })
	end

	return ret
end

-- 重置为答题之前的状态
function Team:ResetStatus()
	local list = self:GetPidList()
	for _, pid in ipairs(list) do
		local player = PlayerList.GetPlayer(pid)
		player:ResetStatus()
	end 
end


function Team:RandomQType()
	local list = self:GetPidList()
	for _, pid in ipairs(list) do
		local player = PlayerList.GetPlayer(pid)
		if player and player.is_AI ~= 0 then
			local typeList = QuestionBank.GetTypeList()
			local index =  math.random(#typeList)
			player:UpdateNextType(typeList[index])
		end
	end
end


function Team:RecordQuestionId()
	self.map[self.qid] = true
end

-- 生成新的question id
function Team:GenerateNewId()
	local list = self:GetPidList()
	local player = PlayerList.GetPlayer(list[self.pindex])
	local qidLst = QuestionBank.GetIdListByType(player.next_type, self.map)
	local i = math.random(#qidLst)
	self:UpdateQid(qidLst[i])
end

function Team:GeneratePublishTimeAndAnwerTime(sec)
	local ok = TeamTable.UpdatePublishTime(self.team_id, loop.now() + sec)
	if ok then
		self.publish_time = loop.now()
	end
	local aiLst = self:GetAIPidList()
	for _, pid in ipairs(aiLst) do
		log.debug("GeneratePublishTimeAndAnwerTime: publish_time = ", self.publish_time)
		local time = math.random(self.publish_time + 8, self.publish_time + 35)
		local player = PlayerList.GetPlayer(pid)
		player:UpdateAnswerTime(time)
		log.debug("GeneratePublishTimeAndAnwerTime: pid, time ", pid, player.answer_time)
	end
end

function Team:ClearAllInfo()
	local list = self:GetPidList()
	for _, pid in ipairs(list) do
		local player = PlayerList.GetPlayer(pid)
		if player and player.is_AI == 2 then   				-- 纯正AI玩家
			player:Delete()
		else
			player:Clear()
		end 
	end
	local ok = TeamTable.Delete(self.team_id)
	if ok then
		TeamList.Remove(self.team_id)
	end
end

function Team:AddCompleteCount()
	local list = self:GetPidList()
	for _, pid in ipairs(list) do
		local player = PlayerList.GetPlayer(pid)
		if player and player.is_AI ~= 2 then
			player:UpdateWeekQuizCount(player.week_count + 1)		
		end
	end
end

function Team:GiveBack()	
	local list = self:GetPidList()

	for _, pid in ipairs(list) do
		local player = PlayerList.GetPlayer(pid)
		if player and player.is_AI == 2 then
			AI.PutId(pid)
		end	
	end
end

function Team:GetCredits()
	local ret = {}
	local list = self:GetPidList()
	for _, pid in ipairs(list) do
		local player = PlayerList.GetPlayer(pid)
		if player and player.is_AI ~= 2 then
			table.insert(ret, { player.pid, player.credits })	
		elseif player and player.is_AI == 2 then		
			table.insert(ret, { player.pid, player.credits, AI.content[player.pid].name, AI.content[player.pid].icon })
		end
	end

	return ret
end

---------------------- information list ---------------------
function PlayerList.GetPlayer(pid)
	if PlayerList[pid] == nil then
		local t = PlayerTable.Select(pid)
		if t then
			PlayerList[pid] = Player.New2(t)
		end
	end

	return PlayerList[pid]
end

function PlayerList.Add(player)
	if player == nil then
		log.debug("PlayerList add failed, player is nil.")
		return
	end

	PlayerList[player.pid] = player
end

function PlayerList.Remove(pid)
	PlayerList[pid] = nil
end

-------------------------------------------------------------
function TeamList.GetTeam(tid)
	if TeamList[tid] == nil then
		local t = TeamTable.Select(tid)
		if t then
			t.map = {}
			TeamList[tid] = Team.New2(t)
		end
	end

	return TeamList[tid]
end

function TeamList.Add(team)
	if team == nil then
		log.debug("TeamList add failed, team is nil.")
		return
	end

	TeamList[team.team_id] = team
end

function TeamList.Remove(tid)
	TeamList[tid] = nil
end

----------------------- notify -------------------------
local function Notify(cmd, pid, msg)
	local agent = Agent.Get(pid);
	if agent then
		agent:Notify({cmd, msg});
	end
end

-- 匹配成功
local function NotifyMatch(team_id)
	log.debug("Notify match ... ")
	local team = TeamList.GetTeam(team_id)
	if not team then
		log.debug("NotifyMatch: team is nil, team_id = ", team_id)
		return
	end
	local pidList = team:GetNonAIPidList()

	for _, pid in ipairs(pidList) do
		local player = PlayerList.GetPlayer(pid)
		local respond = {}
		respond[1] = 100
		respond[2] = Command.RET_SUCCESS
		respond[3] = team.qid
		respond[4] = team.round
		respond[5] = team.publish_time + 5
		respond[6] = team:GetQtype()
		respond[7] = team:GetSelectId()
		Notify(Command.NOTIFY_QUIZ_MATCH, pid, respond)
	end
end

-- 分发问题
local function NotifyDispatchQuestion(team_id)
	log.debug("NotifyDispatchQuestion ... ")
	local team = TeamList.GetTeam(team_id)
	if not team then
		log.debug("NotifyDispatchQuestion: team is nil, team_id = ", team_id)
		return
	end
	log.debug(sprinttb(team:GetCredits()))
	local pidList = team:GetNonAIPidList()
	for _, pid in ipairs(pidList) do
		local respond = {}
		respond[1] = 101
		respond[2] = Command.RET_SUCCESS
		respond[3] = team.qid
		respond[4] = team.round
		respond[5] = team:GetCredits()
		respond[6] = team.publish_time + 5
		respond[7] = team:GetQtype()
		respond[8] = team:GetSelectId()
		local player = PlayerList.GetPlayer(respond[8])
		if player.is_AI == 2 then
			respond[9] = AI.content[player.pid].name
		end
		Notify(Command.NOTIFY_QUIZ_DISPATCH, pid, respond)
	end
end

-- 游戏结束的通知
local function NotifyGameOver(team_id)
	log.debug("NotifyGameOver ... ")
	local team = TeamList.GetTeam(team_id)
	if not team then
		log.debug("NotifyGameOver: team is nil, team_id = ", team_id)
		return
	end
	-- 计算每位玩家获得奖励的比例
	team:CalculateRatio()	
	local ridLst =  RewardBank.GetIdList()
	local i = math.random(#ridLst)	
	local reward = RewardBank.GetReward(ridLst[i])
	-- 分发奖励
	local pidLst = team:GetPidList()
	local reward_respond = {}
	for _, pid in ipairs(pidLst) do
		local player = PlayerList.GetPlayer(pid)
		local reward_list = {}
		for i, v in ipairs(reward) do
			table.insert(reward_list, { type = v.type, id = v.id, value = math.floor(v.value * player.award_ratio / 100) })
		end
		if player.is_AI ~= 2 then
			local retResult = cell.sendReward(pid, reward_list, nil, Command.REASON_WEEK_QUIZ, false)	
		end
		local ret_list = {}
		for _, v in ipairs(reward_list) do
			table.insert(ret_list, { v.type, v.id, v.value })
		end
		if player.is_AI ~= 2 then
			table.insert(reward_respond, { pid, ret_list })
		else
			table.insert(reward_respond, { pid, ret_list, AI.content[pid].name, AI.content[pid].icon })
		end
	end

	local pidList = team:GetNonAIPidList()
	local respond = {}
	respond[1] = 102
	respond[2] = Command.RET_SUCCESS
	respond[3] = team:GetCredits()
	respond[4] = reward_respond
	log.debug("NotifyGameOver ....")
	log.debug(sprinttb(respond[3]))
	
	for _, pid in ipairs(pidList) do
		Notify(Command.NOTIFY_QUIZ_END, pid, respond)
	end
end

local function NotifyAnswer(pid)
	log.debug("NotifyAnswer ...")
	local player = PlayerList.GetPlayer(pid)
	if not player then
		log.debug("NotifyAnswer: player is nil, pid = ", pid)
		return
	end
	local team = TeamList.GetTeam(player.team_id)
	if not team then
		log.debug("NotifyAnswer: team is nil, team_id = ", player.team_id)
		return
	end

	local pidList = team:GetNonAIPidList()
	for _, v in ipairs(pidList) do
		local respond = {}
		respond[1] = 103
		respond[2] = Command.RET_SUCCESS
		respond[3] = pid
		respond[4] = player.answer_correct
		Notify(Command.NOTIFY_QUIZ_ANSWER, v, respond)
	end 
end 

--[[
	匹配池
	p1中所有的用户都是等待时间小于20秒的用户
	p2中所有的用户都是等待时间超过20秒的用户
--]]
local MatchPool = { p1 = {}, p2 = {} }
function MatchPool.IsEmpty()
	if MatchPool.Count() == 0 then
		return true
	end
	return false
end

function MatchPool.Count()
	local n = 0
	for _, _ in pairs(MatchPool.p1) do
		n = n + 1
	end
	for _, _ in pairs(MatchPool.p2) do
		n = n + 1
	end

	return n
end

function MatchPool.Add(pid, qtype)
	if MatchPool.p1[pid] == nil then
		MatchPool.p1[pid] = { loop.now(), qtype }
	end
end

function MatchPool.Remove(pid)
	if MatchPool.p1[pid] ~= nil then
		MatchPool.p1[pid] = nil
	end
	if MatchPool.p2[pid] ~= nil then
		MatchPool.p2[pid] = nil
	end 
end

-- 从匹配池中选取n个玩家
function MatchPool.SelectNPlayer(n)
	if MatchPool.Count() < n then
		return {}
	end

	-- 计算p2中的玩家数量
	local n1 = 0
	for i, v in pairs(MatchPool.p2) do
		n1 = n1 + 1
	end
	local n2 = n - n1
	local ret = {}
	for pid, v in pairs(MatchPool.p2) do
		if n1 > 0 then
			table.insert(ret, { pid = pid, qtype = v[2], isAI = 0 })
			MatchPool.p2[pid] = nil
			n1 = n1 - 1
		end
	end
	if n2 > 0 then
		for pid, v in pairs(MatchPool.p1) do
			if n2 > 0 then
				table.insert(ret, { pid = pid, qtype = v[2], isAI = 0 })
				MatchPool.p1[pid] = nil
				n2 = n2 - 1
			end
		end
	end
	
	return ret
end

function MatchPool.WaitOverTimePlayer()
	if MatchPool.Count() == 0 then
		return {}
	end

	local ret = {}
	for pid, v in pairs(MatchPool.p2) do
		if loop.now() - v[1] >= 40 then
			table.insert(ret, { pid = pid, qtype = v[2], isAI = 0 })
			MatchPool.p2[pid] = nil
		end
	end

	return ret
end

-- 组队
local function make_team(plist)
	if plist == nil or #plist == 0 then
		return nil
	end
	
	-- 加上这段代码是为了防止一个玩家在多个队伍中
	local is_exist = false
	for _, v in ipairs(plist) do
		local p = PlayerList.GetPlayer(v.pid)	
		if p and p.team_id ~= 0 then
			log.warning(string.format("In_make_team: %d was in team %d.", p.pid, p.team_id))
			MatchPool.Remove(v.pid)
			is_exist = true
		end
	end
	if is_exist then
		log.warning("In_make_team: make team failed.")
		return nil
	end

	-- 不足5人的，剩下的人由AI替代
	local n = 5 - #plist

	-- ai数量不够
	if #AI.content2 <= n then	
		log.warning("In_make_team: ai count not enough, need ai count is ", n)
		return nil
	end

	for i = 1, n do
		local typeList = QuestionBank.GetTypeList()
		local index =  math.random(#typeList)
		local id = AI.GetId()	
		table.insert(plist, { pid = id, qtype = typeList[index], isAI = 2 } )
	end

	local pidList = {}
	for _, v in ipairs(plist) do
		table.insert(pidList, v.pid) 
	end
	-- 组建team
	local team = Team.New(pidList)
	TeamList.Add(team)
	-- 创建玩家
	for _, v in ipairs(plist) do
		local player = PlayerList.GetPlayer(v.pid)

		if player then
			player:UpdateTeamId(team.team_id)
			player:UpdateNextType(v.qtype)
		else
			local player = Player.New(v.pid, team.team_id, v.isAI, v.qtype)
			PlayerList.Add(player)
		end
	end	
	team:GeneratePublishTimeAndAnwerTime(0)
	team:GenerateNewId()

	return team.team_id
end

---------------- routine ------------------------------
-- 答题系统
local function quiz_thread(tid)
	local team = TeamList.GetTeam(tid)
	if not team then
		log.debug("quiz_thread excute failed: team_id = ", tid)
		return
	end
	while true do
		-- 如果当前所有的玩家全部为AI，则将当前协程挂起
		--[[if team:IsAllAI() then
			coroutine.yield()
		end--]]
		-- AI 回答问题
		local plist = team:AIAnswerTheQuestion()
		for _, pid in ipairs(plist) do
			NotifyAnswer(pid)	
		end
	
		-- 从上一次分发题目到当前时间，经过了n轮(当所有的玩家全部掉线，答题系统停止运作)
		local n = math.floor((loop.now() - team.publish_time) / 35)
		local all_answer = team:AllMemberAnswer()
		if n > 0 or all_answer then
			local wait_sec = 0		-- 所有人答题结束以后需要延迟发题的时间
			if n == 0 then
				n = 1
				wait_sec = 2
			end
			if team.round + n >= 16 then
				n = 16 - team.round
			end
			for i = 1, n do
				-- 为还没选择答案的玩家随机选择一个答案
				local plist = team:RandomSelect()
				for _, pid in ipairs(plist) do
					NotifyAnswer(pid)	
				end
				-- 计算积分
				team:AddCredits()
				-- 重置状态
				team:ResetStatus()
				-- 更新round值
				team:UpdateRound(team.round + 1)
				-- 生成分发题目的时间和AI的回答问题时间
				team:GeneratePublishTimeAndAnwerTime(wait_sec)	
				-- 随机为AI生成题目类型
				team:RandomQType()
				-- 更新下一题选题人
				team:UpdatePindex()
				-- 记录此题已答
				team:RecordQuestionId()
				-- 生成新的题目id
				team:GenerateNewId()
			end
			if team.round > 15 then
				break
			end
			Sleep(wait_sec)
			-- 分发题目
			NotifyDispatchQuestion(team.team_id)
		end
		Sleep(1)	
	end
	-- 通知游戏结束
	NotifyGameOver(team.team_id)
	-- todo
	local pids = team:GetNonAIPidList()
	for _, pid in ipairs(pids) do
		cell.NotifyQuestEvent(pid, {{type = 67, id = 1, count = 1}})
	end

	-- 归还ai
	team:GiveBack()
	-- clear
	RoutineList.Remove(team.team_id)
	-- 增加一次完成次数
	team:AddCompleteCount()
	team:ClearAllInfo()
end

-- 答题系统的协程列表
function RoutineList.Contains(tid)
	if RoutineList[tid] == nil then
		return false
	end

	return true
end

function RoutineList.Add(tid, co)
	if not RoutineList.Contains(tid) then
		RoutineList[tid] = co
	end
end

function RoutineList.Remove(tid)
	RoutineList[tid] = nil
end

-- 匹配系统
local match_handler = { match_co = nil, flag  = false }	 		-- flag为true代表主动放弃执行，不是因为sleep的缘故
local function match_thread()
	while true do
		-- 先将等待时间超过20秒的用户移到p2中
		for pid, v in pairs(MatchPool.p1) do
			if loop.now() - v[1] >= 20 then
				MatchPool.p1[pid] = nil
				MatchPool.p2[pid] = v
			end
		end

		local n = MatchPool.Count() 	
		if n == 0 then								-- 匹配池是空的，则什么也不做
			log.debug("MatchPool is Empty, yield the match_thread.")
			match_handler.flag = true
			coroutine.yield()
		elseif n >= 4 then						-- 匹配池中的用户数量超过4个，则可以进行匹配		
			local plist = MatchPool.SelectNPlayer(4)
			local tid = make_team(plist)
			if tid then
				local co = RunThread(quiz_thread, tid)
				RoutineList.Add(tid, co)
				NotifyMatch(tid)
			else
				for _, v in ipairs(plist) do
					MatchPool.p2[v.pid] = { loop.now() - 40, v.qtype }
				end
			end
		else													-- p2中存在匹配时间超过40秒的用户，则匹配相应数量的AI
			local plist = MatchPool.WaitOverTimePlayer()
			local tid = make_team(plist)
			if tid then
				local co = RunThread(quiz_thread, tid)
				RoutineList.Add(tid, co)
				NotifyMatch(tid)
			else						
				for _, v in ipairs(plist) do
					MatchPool.p2[v.pid] = { loop.now() - 40, v.qtype }
				end
			end
		end
		Sleep(1)	
	end
end

----------------------- respond ------------------------
local function get_match_respond(pid, request)
	if type(request) ~= "table" or #request ~= 2 then
		local sn = request[1] or 1
		return { sn, Command.RET_PARAM_ERROR }
	end
	local sn = request[1]

	local player = PlayerList.GetPlayer(pid)

	-- 检测匹配人物是否满足匹配条件
	--[[if player and not player:IsQuiz() then
		log.debug("has already quiz: pid = ", pid)
		return { sn, Command.RET_NOT_ENOUGH }
	end--]]
	if player and player:IsInTeam() then
		log.debug("has in a team: pid = ", pid)
		return { sn, Command.RET_EXIST }
	end

	-- 将人物加入到匹配池中
	MatchPool.Add(pid, request[2])

	-- 开启匹配系统
	if match_handler.match_co == nil then
		log.debug("start match thread ...")
		match_handler.match_co = RunThread(match_thread)
	end
	if coroutine.status(match_handler.match_co) == "suspended" and match_handler.flag then
		log.debug("resume match thread ... ")
		match_handler.flag = false
		coroutine.resume(match_handler.match_co)
	end

	return { sn, Command.RET_SUCCESS }
end

local function get_cancel_match_respond(pid, request)
	if type(request) ~= "table" or #request == 0 then
		local sn = request[1] or 1
		return { sn, Command.RET_PARAM_ERROR }
	end
	local sn = request[1]

	MatchPool.Remove(pid)

	return { sn, Command.RET_SUCCESS } 
end

local function get_quiz_info_respond(pid, request)
	if type(request) ~= "table" or #request == 0 then
		local sn = request[1] or 1
		return { sn, Command.RET_PARAM_ERROR }
	end
	local sn = request[1]

	-- 查看目标是否存在
	local player = PlayerList.GetPlayer(pid)
	if not player or player.team_id == 0 then
		log.debug("player not exist: pid = ", pid)
		return { sn, Command.RET_NOT_EXIST } 
	end

	local team = TeamList.GetTeam(player.team_id)
	if not team then
		log.debug("team not exist: pid = ", pid)
		return { sn, Command.RET_NOT_EXIST }
	end

	local respond = {}
	respond[1] = sn
	respond[2] = Command.RET_SUCCESS
	respond[3] = team:GetCredits()
	respond[4] = team.qid
	respond[5] = team.round
	respond[6] = team.publish_time + 5
	respond[7] = team:GetQtype()
	respond[8] = team:GetSelectId()
	request[9] = AI.content[respond[8]] and AI.content[respond[8]].name or nil

	return respond
end

local function get_question_type_respond(pid, request)
	if type(request) ~= "table" or #request < 2 then
		local sn = request[1] or 1
		return { sn, Command.RET_PARAM_ERROR }
	end
	local sn = request[1]

	-- 查看类型是否存在
	if not QuestionBank.hasType(request[2]) then
		log.debug("question type not exist: pid, type = ", pid, request[2])
		return { sn, Command.RET_NOT_EXIST }
	end	

	-- 查看目标是否存在
	local player = PlayerList.GetPlayer(pid)
	if not player or player.team_id == 0 then
		log.debug("player not exist: pid = ", pid)
		return { sn, Command.RET_NOT_EXIST } 
	end

	player:UpdateNextType(request[2])

	return { sn, Command.RET_SUCCESS }
end

local function get_answer_respond(pid, request)
	if type(request) ~= "table" or #request < 2 then
		local sn = request[1] or 1
		return { sn, Command.RET_PARAM_ERROR }
	end
	local sn = request[1]

	-- 查看目标是否存在
	local player = PlayerList.GetPlayer(pid)
	if not player or player.team_id == 0 then
		log.debug("player not exist: pid = ", pid)
		return { sn, Command.RET_NOT_EXIST } 
	end
	local team = TeamList.GetTeam(player.team_id)
	if not team then
		log.debug("team not exist: tid = ", player.team_id)
		return { sn, Command.RET_NOT_EXIST }
	end

	-- 是否处于答题时间
	if team.publish_time + 5 > loop.now() then
		log.debug("reading time.")
		return { sn, Command.RET_DEPEND }
	end

	local qid = team.qid
	local is_right = QuestionBank.IsCorrect(qid, request[2])
	if is_right then 
		player:UpdateCorrectStatus(1)
		player:UpdateCorrectCount(player.correct_count + 1)
	end
	player:UpdateIsAnswer(1)
	player:UpdateAnswerTime(loop.now())

	return { sn, Command.RET_SUCCESS, is_right }
end


------------------------ register ----------------------
local WeekQuiz = {}
function WeekQuiz.RegisterCommand(service)
	service:on(Command.C_QUIZ_WEEKLY_MATCH_REQUEST, function (conn, pid, request)
		local respond = get_match_respond(pid, request)
		conn:sendClientRespond(Command.C_QUIZ_WEEKLY_MATCH_RESPOND, pid, respond)
	end)

	service:on(Command.C_QUIZ_WEEKLY_CANCEL_MATCH_REQUEST, function (conn, pid, request)
		local respond = get_cancel_match_respond(pid, request)
		conn:sendClientRespond(Command.C_QUIZ_WEEKLY_CANCEL_MATCH_RESPOND, pid, respond)
	end)

	service:on(Command.C_QUIZ_WEEKLY_QUERY_REQUEST, function (conn, pid, request)
		local respond = get_quiz_info_respond(pid, request)
		conn:sendClientRespond(Command.C_QUIZ_WEEKLY_QUERY_RESPOND, pid, respond)
	end)

	service:on(Command.C_QUIZ_WEEKLY_GET_TYPE_REQUEST, function (conn, pid, request)
		local respond = get_question_type_respond(pid, request)
		conn:sendClientRespond(Command.C_QUIZ_WEEKLY_GET_TYPE_RESPOND, pid, respond)
	end)

	service:on(Command.C_QUIZ_WEEKLY_ANSWER_REQUEST, function (conn, pid, request)
		local respond = get_answer_respond(pid, request)
		conn:sendClientRespond(Command.C_QUIZ_WEEKLY_ANSWER_RESPOND, pid, respond)
		if respond[2] == Command.RET_SUCCESS then
			NotifyAnswer(pid)
		end
	end)

	service:on(Command.C_LOGIN_REQUEST, function(conn, pid, request)
		local player = PlayerList.GetPlayer(pid)
		if player and player.team_id ~= 0 then
			log.debug("someone login: ", pid)
			player:UpdateAIStatus(0)
		end
		--[[if not player then
			return
		end
		co = RoutineList[player.team_id]
		if co == nil then
			co = RunThread(quiz_thread, player.team_id)
			RoutineList.Add(player.team_id, co)
		else
			if coroutine.status(co) == "suspended" then
				log.debug("resume coroutine")
				coroutine.resume(co)
			end
		end--]]
	end)

	service:on(Command.C_LOGOUT_REQUEST, function(conn, pid, request)
		local player = PlayerList[pid]
		if player and player.team_id ~= 0 then
			log.debug("someone login out: ", pid)
			player:UpdateAIStatus(1)
		end		
	end)

	service:on(Command.C_QUIZ_WEEKLY_TOTAL_COUNT_REQUEST, function(conn, pid, request)
		if type(request) ~= "table" or #request < 1 then
			conn:sendClientRespond(Command.C_QUIZ_WEEKLY_TOTAL_COUNT_RESPOND, pid, { 1, Command.RET_PARAM_ERROR })
		end
		local sn = request[1]
		local player = PlayerList.GetPlayer(pid)
		local n = 0
			
		if player and player.deadtime < loop.now() then
			player:UpdateWeekQuizCount(0)
			player:UpdateDeadTime(deadTime())
		end
	
		n = player and player.week_count or 0
		conn:sendClientRespond(Command.C_QUIZ_WEEKLY_TOTAL_COUNT_RESPOND, pid, { sn, Command.RET_SUCCESS, n })
	end)
end

return WeekQuiz
