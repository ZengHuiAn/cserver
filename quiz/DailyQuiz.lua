local database = require "database"
local cell = require "cell"
require "DailyQuizConfig"
require "printtb"
local StableTime = require "StableTime"
local get_begin_time_of_day = StableTime.get_begin_time_of_day

local QUIZ_BEGIN_TIME = 11 * 3600
local QUIZ_END_TIME = 23 * 3600
local QUIZ_LAST_TIME = 	12 * 3600 
local MAX_QUESTION_NUM = 10
local MAX_HELP_COUNT = 3 

local function str_split(str, pattern)
	local arr ={}
	while true do
		if #str==0 then
			return arr
		end
		local pos,last =string.find(str, pattern)
		if not pos then
			table.insert(arr, str)
			return arr
		end
		if pos>1 then
			table.insert(arr, string.sub(str, 1, pos-1))
		end
		if last<#str then
			str =string.sub(str, last+1, -1)
		else
			return arr
		end
	end
end

local function insertReward(t, str)
	local ret = str_split(str, "|")

    for k,v in ipairs(ret or {}) do
        local kv_pair = str_split(v, ",")
        table.insert(t, {type = tonumber(kv_pair[1]), id = tonumber(kv_pair[2]), value = tonumber(kv_pair[3])})
    end
end

local function getRewardStr(rewards)
	local str = ""

	for k, v in ipairs(rewards) do
		str = str..tostring(v.type)..","..tostring(v.id)..","..tostring(v.value).."|"
	end

	return str
end

local function SendReward(pid, consume, reward, reason)
    local ret =cell.sendReward(pid, reward, consume, reason)
    if type(ret)=='table' then
        if ret.result== Command.RET_SUCCESS then
            return nil
        else
            if ret.result== Command.RET_NOT_ENOUGH then
                return Command.RET_NOT_ENOUGH
            else
                return Command.RET_ERROR
            end
        end
    else
        return Command.RET_ERROR
    end
end


local DailyQuiz = {}

local function getRandomQuestionID(mask)
	local list = {}

	for _, id in ipairs(GetIdList()) do
		if not mask[id] then
			table.insert(list, id)
		end
	end

	if #list == 0 then
		log.warning("getRandomQuestionID failed, not any more quiz, mask is ")
		log.debug(sprinttb(mask))
		return nil
	end

	local index = math.random(1, #list)
	local question_cfg = GetQuestion(index)	

	return question_cfg and question_cfg.id or nil 
end

local function answerCorrect(question_id, select_num)
	log.debug(string.format("begin check answer, question_id:%d  select_num:%d", question_id, select_num))
	local question_cfg = GetQuestion(question_id)	
	
	if not question_cfg then
		log.debug("get question cfg fail")
		return false
	end

	if select_num == question_cfg.right_answer1 or select_num == question_cfg.right_answer2 or select_num == question_cfg.right_answer3 then
		return true
	end

	return false
end

local function roundFinish(question_id, now_round)
	log.debug(string.format("begin check round finish, question_id:%d  now_round:%d", question_id, now_round))
	local question_cfg = GetQuestion(question_id)

	if not question_cfg then
		log.debug("get question cfg fail")
		return false
	end

	if now_round + 1 > question_cfg.type then
		return true
	end
	
	return false
end

local function round(select_num)
	return math.ceil(select_num / 3)
end

local playerDailyQuiz = {}
function GetPlayerDailyQuiz(pid)
	if not playerDailyQuiz[pid] then
		playerDailyQuiz[pid] = DailyQuiz.Get(pid)
	end

	return playerDailyQuiz[pid]
end

function DailyQuiz.Get(pid)
	local t = {
		pid = pid, 
		current_question_id = 0, 
		current_round = 0, 
		correct_count = 0, 
		finish_count = 0, 
		reward = {},
		reward_flag = 0, 
		update_time = 0, 
		end_time = 0,
		sixty_rate_count = 0,
		eighty_rate_count = 0,
		hundred_rate_count = 0,
		db_exist = false,
		data_change = false,
		answer_pool = {},	-- 已经答过的题目id
	}

	local success, result = database.query("select pid, current_question_id, current_round, correct_count, finish_count, reward_depot, reward_flag, help_count, unix_timestamp(update_time) as update_time, unix_timestamp(end_time) as end_time, sixty_rate_count, eighty_rate_count, hundred_rate_count from player_daily_quiz where pid = %d", pid);
	if success then
		for _, row in ipairs(result) do
			t.current_question_id = row.current_question_id
			t.current_round = row.current_round
			t.correct_count = row.correct_count
			t.finish_count = row.finish_count
			t.reward_flag = row.reward_flag
			t.help_count = row.help_count
			t.update_time = row.update_time
			t.sixty_rate_count = row.sixty_rate_count
			t.eighty_rate_count = row.eighty_rate_count
			t.hundred_rate_count = row.hundred_rate_count
			t.end_time = row.end_time
			t.db_exist = true
			insertReward(t.reward, row.reward_depot)
		end
	end

	return setmetatable(t, {__index = DailyQuiz})
end

function DailyQuiz:OnTime()
	local now = loop.now()
	return (now >= get_begin_time_of_day(now) + QUIZ_BEGIN_TIME and now <= get_begin_time_of_day(now) + QUIZ_END_TIME) --and now <= self.end_time
end

function DailyQuiz:FreshQuestion(force)
	local now = loop.now()

	if force and now > self.end_time then
		log.debug("this round quiz end")
		return false
	end

	if not force and (now < get_begin_time_of_day(now) + QUIZ_BEGIN_TIME or now > get_begin_time_of_day(now) + QUIZ_END_TIME) then
		--log.debug("not on time")
		return false
	end
	
	if not force and (get_begin_time_of_day(now) <= get_begin_time_of_day(self.update_time)) then
		--log.debug("not new round and not force")
		return false
	end

	--add questions 
	local new_question = getRandomQuestionID(self.answer_pool)
	if not new_question then
		log.debug("get new question fail")
		return false
	end
	
	self.answer_pool[new_question] = true
	self.current_question_id = new_question	
	self.current_round = 1

	if get_begin_time_of_day(now) > get_begin_time_of_day(self.update_time) then
		self.correct_count = 0 
		self.finish_count = 0 
		self.reward = {}
		self.reward_flag = 0
		self.help_count = 0
		self.end_time = get_begin_time_of_day(now) + QUIZ_END_TIME--now + QUIZ_LAST_TIME
	end

	self.update_time = now
	self.data_change = true
	return true

end

function DailyQuiz:AddReward(question_id)
	log.debug(string.format("begin add reward for question:%d", question_id))

	local question_cfg = GetQuestion(question_id)

	if not question_cfg then
		log.debug("get question cfg fail")
		return false
	end

	local cfg = GetQuizReward(question_cfg.type)

	if not cfg then
		log.debug("reward cfg is nil")
		return false
	end

	if not next(self.reward) then
		for k, v in ipairs(cfg) do
			table.insert(self.reward, {type = v.type, id = v.id, value = v.value})
		end
		self.data_change = true
		return true
	end

	local already_add = {}
	for k, v in ipairs(self.reward) do
		for k2, v2 in ipairs(cfg) do
			if v.type == v2.type and v.id == v2.id and not already_add[k2] then
				v.value = v.value + v2.value
				already_add[k2] = true
			end
		end
	end

	for k, v in ipairs(cfg) do
		if not already_add[k] then
			table.insert(self.reward, {type = v.type, id = v.id, value = v.value})
		end
	end	

	self.update_time = loop.now()
	self.data_change = true
	return true
end

function DailyQuiz:SendReward(question_id)
	log.debug(string.format("Player %d begin send reward", self.pid))

	local question_cfg = GetQuestion(question_id)
	if not question_cfg then
		log.debug("get question cfg fail")
		return 
	end

	local cfg = GetQuizReward(question_cfg.type)
	if not cfg then
		log.debug("reward cfg is nil")
		return 
	end

	local reward = {}
	for k, v in ipairs(cfg) do
		table.insert(reward, {type = v.type, id = v.id, value = v.value})
	end
	
	if #reward > 0 then
		local err = SendReward(self.pid, nil, reward, REASON_DAILY_QUIZ)
		if err then
			log.debug("cell error")
		end
	end
end

function DailyQuiz:UpdateDBData()
	if not self.data_change then
		return false
	end

	if self.db_exist then
		database.update([[update player_daily_quiz set current_question_id = %d, current_round = %d, correct_count = %d, finish_count = %d, reward_depot = '%s', 
			reward_flag = %d, help_count = %d, update_time = from_unixtime_s(%d), end_time = from_unixtime_s(%d), sixty_rate_count = %d, eighty_rate_count = %d, 
			hundred_rate_count = %d where pid = %d]], 
			self.current_question_id, self.current_round, self.correct_count, self.finish_count, getRewardStr(self.reward), self.reward_flag, self.help_count, 
			self.update_time, self.end_time, self.sixty_rate_count, self.eighty_rate_count, self.hundred_rate_count, self.pid)
	else
		database.update([[insert into player_daily_quiz (pid, current_question_id, current_round, correct_count, finish_count, reward_depot, reward_flag, help_count, 
			update_time, end_time, sixty_rate_count, eighty_rate_count, hundred_rate_count) values(%d, %d, %d, %d, %d, '%s', %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), %d, %d, %d)]],
		self.pid, self.current_question_id, self.current_round, self.correct_count, self.finish_count, getRewardStr(self.reward), self.reward_flag, self.help_count, self.update_time, self.end_time,
		self.sixty_rate_count, self.eighty_rate_count, self.hundred_rate_count)
		self.db_exist = true
	end	

	self.data_change = false
end

function DailyQuiz:Info()
	log.debug(string.format("Player %d begin to query info for daily quiz", self.pid))

	if not self:OnTime() then
		log.debug("not on time")
		return false
	end

	self:FreshQuestion()

	local reward = {}
	for k, v in ipairs(self.reward) do
		table.insert(reward, {v.type, v.id, v.value})
	end

	local info = {
		self.current_question_id,
		self.current_round, 
		self.correct_count,
		self.finish_count,
		reward,
		self.reward_flag,
		self.help_count,
		self.end_time
	}

	self:UpdateDBData()

	return true, info
end


function DailyQuiz:DrawReward()
	log.debug(string.format("Player %d begin draw reward", self.pid))
	
	if not self:OnTime() then
		log.debug("not on time")
		return false
	end

	self:FreshQuestion()

	if self.reward_flag == 1 then
		log.debug("already draw")
		return false
	end
	
	if self.finish_count ~= MAX_QUESTION_NUM then
		log.debug("not finish all question")
		return false 
	end

	local err = SendReward(self.pid, nil, self.reward, REASON_DAILY_QUIZ)
	if err then
		log.debug("cell error")
		return false
	end

	self.update_time = loop.now()
	self.reward_flag = 1
	self.data_change = true

	self:UpdateDBData()	
	return true
end

function DailyQuiz:Answer(question_id, select_num)
	log.debug(string.format("Player %d begin to answer question:%d, select:%d", self.pid, question_id, select_num))
	
	if not self:OnTime() then
		log.debug("not on time")
		return false
	end
	
	self:FreshQuestion()
	
	if loop.now() > self.end_time then
		log.debug("this round quiz end")
		return false
	end

	if self.finish_count == MAX_QUESTION_NUM then
		log.debug("already finish all questions")
		return false
	end

	if self.current_question_id ~= question_id then
		log.debug("wrong question")
		return false
	end

	if self.current_round ~= round(select_num) then
		log.debug("wrong round")
		return false
	end
	
	--answer is right
	local correct = answerCorrect(question_id, select_num)
	if correct then
		--round finish
		if roundFinish(question_id, self.current_round) then
			self.current_round = 1
			self.finish_count = self.finish_count + 1
			self.correct_count = self.correct_count + 1
			self.update_time = loop.now()
			self:AddReward(question_id)
			self:SendReward(question_id)
			self:FreshQuestion(true)
		else
			self.current_round = self.current_round + 1
			self.update_time = loop.now()
		end
	else
		self.current_round = 1
		self.finish_count = self.finish_count + 1
		self.update_time = loop.now()
		self:FreshQuestion(true)
	end
	
	--quest
	if self.finish_count == MAX_QUESTION_NUM then
		cell.NotifyQuestEvent(self.pid, {{type = 4, id = 14, count = 1}})
		self.answer_pool = {}
	
		local right_rate = math.floor(self.correct_count / self.finish_count * 100)
		if right_rate < 60 then
			self.sixty_rate_count = 0
			self.eighty_rate_count = 0
			self.hundred_rate_count = 0
			cell.NotifyQuestEvent(self.pid, { { type = 95, id = 1, count = 0 }, { type = 95, id = 2, count = 0 }, { type = 95, id = 3, count = 0 } })
		elseif right_rate >= 60 and right_rate < 80 then
			self.sixty_rate_count = self.sixty_rate_count + 1
			cell.NotifyQuestEvent(self.pid, { { type = 95, id = 1, count = self.sixty_rate_count } })
		elseif right_rate >= 80 and right_rate < 100 then
			self.eighty_rate_count = self.eighty_rate_count + 1	
			cell.NotifyQuestEvent(self.pid, { { type = 95, id = 2, count = self.eighty_rate_count } })
		else
			self.hundred_rate_count = self.hundred_rate_count + 1
			cell.NotifyQuestEvent(self.pid, {{ type = 95, id = 3, count = self.hundred_rate_count } })
		end
	end

	self.data_change = true
	self:UpdateDBData()

	return true, correct 
end

function DailyQuiz:SeekHelp()
	log.debug(string.format("Player %d begin to seek help", self.pid))

	if not self:OnTime() then
		log.debug("not on time")
		return false
	end

	self:FreshQuestion()

	if self.help_count == MAX_HELP_COUNT then
		log.debug("today help count already max")
		return false
	end

	self.help_count = self.help_count + 1	
	self.data_change = true

	self:UpdateDBData()

	return true 
end

function DailyQuiz.RegisterCommand(service)
	service:on(Command.C_QUIZ_DAILY_QUERY_INFO_REQUEST, function(conn, pid, request)
		local sn = request[1];

		local quiz = GetPlayerDailyQuiz(pid)
		local success, ret = quiz:Info()
		return conn:sendClientRespond(Command.C_QUIZ_DAILY_QUERY_INFO_RESPOND, pid, {sn, success and Command.RET_SUCCESS or Command.RET_ERROR, ret});
	end);

	service:on(Command.C_QUIZ_DAILY_ANSWER_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local question_id = request[2]
		local select_num = request[3]

		if not question_id or not select_num then
			log.debug("param error")
			return conn:sendClientRespond(Command.C_QUIZ_DAILY_ANSWER_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		local quiz = GetPlayerDailyQuiz(pid)
		local success, ret = quiz:Answer(question_id, select_num)
		local _, info = quiz:Info()
		if info then
			table.insert(info, ret)
		end
		return conn:sendClientRespond(Command.C_QUIZ_DAILY_ANSWER_RESPOND, pid, {sn, success and Command.RET_SUCCESS or Command.RET_ERROR, info});
	end);

	service:on(Command.C_QUIZ_DAILY_DRAW_REWARD_REQUEST, function(conn, pid, request)
		local sn = request[1];

		local quiz = GetPlayerDailyQuiz(pid)
		local success = quiz:DrawReward()
		return conn:sendClientRespond(Command.C_QUIZ_DAILY_DRAW_REWARD_RESPOND, pid, {sn, success and Command.RET_SUCCESS or Command.RET_ERROR});
	end);

	service:on(Command.C_QUIZ_DAILY_SEEK_HELP_REQUEST, function(conn, pid, request)
		local sn = request[1];

		local quiz = GetPlayerDailyQuiz(pid)
		local success = quiz:SeekHelp()
		return conn:sendClientRespond(Command.C_QUIZ_DAILY_SEEK_HELP_RESPOND, pid, {sn, success and Command.RET_SUCCESS or Command.RET_ERROR});
	end);
end

return DailyQuiz
