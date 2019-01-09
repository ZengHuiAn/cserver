local database = require "database"
local cell = require "cell"
local Command = require "Command"
local protobuf = require "protobuf"
local Agent = require "Agent"
local BinaryConfig = require "BinaryConfig"
local bit32 = require "bit32"
local OpenlevConfig = require "OpenlevConfig"
require "Thread"
require "MailReward"

math.randomseed(os.time())

local PlayerManager = { player_map = {} }
local Player = {}				-- 玩家类
local QuizInfo = {
	co = nil,				-- 答题协程 
	round = 0,				-- 第几轮答题
	question_id = 0,			-- 题目id	
	qid_list = {}, 				-- 从这个列表中随机题目
	last_answer_right_count = 0,		-- 上一轮答题正确玩家数量
}

function QuizInfo.Reset()
	QuizInfo.co = nil
	QuizInfo.round = 0
	QuizInfo.question_id = 0
	QuizInfo.qid_list = {}
end

------------------- config -----------------------------
local QuestionConfig = {}
local rows1 = BinaryConfig.Load("config_dailyanswer", "quiz")
if rows1 then
	for i, v in ipairs(rows1) do
		QuestionConfig[v.group] = QuestionConfig[v.group] or {}
		QuestionConfig[v.group][v.id] = { answer = v.right_answer1 }
	end
end

local RewardConfig = {}
local rows2 = BinaryConfig.Load("config_dailyanswer_reward", "quiz")
if rows2 then
	for i, v in ipairs(rows2) do
		RewardConfig[v.correct_number] ={ 
			{ type = v.reward_type1, id = v.reward_id1, value = v.reward_value1 }, 
			{ type = v.reward_type2, id = v.reward_id2, value = v.reward_value2 } 
		}
	end
end

local ActivityConfig = {}
local rows3 = BinaryConfig.Load("config_guild_activity", "guild")
if rows3 then
	for i, v in ipairs(rows3) do
		if v.id == 1 then
			ActivityConfig.ref_time = v.begin_time
			ActivityConfig.open_level = v.openLevel
			ActivityConfig.period = v.period
			ActivityConfig.loop_duration = v.loop_duration
		end
	end
end

local ANSWER_TIME = 10				-- 固定答题时间
local COUNT_DOWN = 5				-- 倒计时
local QUESTION_COUNT = math.floor(ActivityConfig.loop_duration / (ANSWER_TIME + COUNT_DOWN))	-- 题目数量
local RANGE = QUESTION_COUNT * (ANSWER_TIME + COUNT_DOWN)

----------------------------- auxiliary function ---------------------------------
-- 获取答题开启时间
local function begin_time()
	local interval = ActivityConfig.period
	local n = math.floor((loop.now() - ActivityConfig.ref_time) / interval)
	return ActivityConfig.ref_time + n * interval
end

-- 是否处于答题开启时间段
local function is_range()
	local beginTime = begin_time()
	log.debug("is_range: begin time = ", beginTime)
	local endTime = beginTime + RANGE
	local now = loop.now()
	if now >= beginTime and now < endTime then
		return true
	end
	return false
end

local function notify(cmd, pid, msg)
	local agent = Agent.Get(pid);
	if agent then
		agent:Notify({cmd, msg});
	end
end

-- 获取当前第几轮答题，三个返回值
-- return value 1: 第几轮答题
-- return value 2: 距离答题结束时间
-- return value 3: 距离倒计时结束时间
local function get_round_info(beginTime, now)
	local total = ANSWER_TIME + COUNT_DOWN
	local n = math.floor((now - beginTime) / total)
	local point1 = beginTime + n * total + ANSWER_TIME 			-- 这一轮答题结束时的时间点
	local point2 = point1 + COUNT_DOWN					-- 这一轮答题倒计时结束时的时间点
	local ret = { 0, 0, 0 }
	ret[1] = n + 1
	if point1 > now then
		ret[2] = point1 - now
	end 
	if point2 > now then
		ret[3] = math.min(point2 - now, COUNT_DOWN)
	end

	return ret
end

local function rand_id(list)
	list = list or {}
	if #list == 0 then
		log.warning("In_rand_id: list is empty.")
		return 0
	end	
	local i = math.random(#list)
	local ret = list[i]
	table.remove(list, i)

	return ret
end

-- 是否处于15答题时间范围
local function is_answer_time()
	local total = ANSWER_TIME + COUNT_DOWN
	local now = loop.now()	
	local beginTime = begin_time()
	local n = math.floor((now - beginTime) / total)
	local point = beginTime + n * total + ANSWER_TIME 			-- 这一轮答题结束时的时间点

	if now < point then
		return true
	else		
		return false
	end
end

------------------------------------- Database Operation -----------------------------------------
local PlayerDB = {}
function PlayerDB.Select(pid)
	if type(pid) ~= "number" then
		log.warning("In_PlayerDB_Select: param error, pid is not number.")
		return nil
	end

	local ok, result = database.query([[select pid, answer_count, correct_count, is_quiz from world_quiz where pid = %d;]], pid)
	if ok and #result > 0 then
		return result[1]
	else
		log.info(string.format("In_PlayerDB_Select: select world_quiz failed, %d not exist.", pid))
		return nil
	end
end

function PlayerDB.SyncData(info)
	if type(info) ~= "table" then
		log.warning("In_PlayerDB_SyncData: param error, info is not table.")
		return
	end
	
	if info.is_db then
		local ok = database.update([[update world_quiz set answer_count = %d, correct_count = %d, is_quiz = %d where pid = %d;]],
			info.answer_count, info.correct_count, info.is_quiz, info.pid)
		if not ok then
			log.warning("In_PlayerDB_SyncData: update world_quiz failed, info is: ")
			log.debug(sprinttb(info))
		end
	else
		if PlayerDB.Insert(info) then
			info.is_db = true
		end
	end
end

function PlayerDB.Insert(info)
	if type(info) ~= "table" then
		log.warning("In_PlayerDB_Insert: param error, info is not table.")
		return false
	end

	local ok = database.update([[insert into world_quiz(pid, answer_count, correct_count, is_quiz) values(%d, %d, %d, %d);]],
		info.pid, info.answer_count, info.correct_count, info.is_quiz)
	if not ok then
		log.warning("In_PlayerDB_Insert: insert into world_quiz failed, info is: ")
		log.debug(sprinttb(info))
	end

	return ok
end

------------------------------------------------------
function PlayerManager.GetPlayer(pid)
	if PlayerManager.player_map[pid] == nil then
		local player = PlayerDB.Select(pid)
		if not player then
			player = { pid = pid, answer_count = 0, correct_count = 0, is_quiz = 0, is_db = false }
			PlayerManager.player_map[pid] = Player.New(player)
		else	
			player.is_db = true
			PlayerManager.player_map[pid] = Player.New(player)
		end
	end

	return PlayerManager.player_map[pid]
end

function PlayerManager.ClearPlayerInfo()
	for pid, player in pairs(PlayerManager.player_map) do
		if player.is_quiz > 0 then
			player:ClearData()
			PlayerDB.SyncData(player)
		end
	end	
end

-- 获取参与答题的人数
function PlayerManager.GetQuizCount()
	local n = 0
	for _, player in pairs(PlayerManager.player_map) do
		if player.is_quiz > 0 then 
			n = n + 1
		end
	end
	
	return n
end

-- 获取玩家答题正确次数和总答题次数
function PlayerManager.GetAnswerInfo()
	local ret = {}

	for pid, player in pairs(PlayerManager.player_map) do
		if player.is_quiz > 0 then
			table.insert(ret, { pid, player:GetTotalRightCount(), player:GetTotalAnswerCount() })
		end
	end	

	return ret
end

function PlayerManager.BroadcastAnswer(pid, answer, is_right)
	for id, player in pairs(PlayerManager.player_map) do
		if id ~= pid and player.is_quiz then			
			local msg = {}
			msg[1] = 1
			msg[2] = Command.RET_SUCCESS 
			msg[3] = answer
			msg[4] = is_right 
			notify(Command.WORLD_QUIZ_ANSWER_NOTIFY, id, msg)
		end 
	end
end

---------------------------------------------------------------

function Player.New(o)
	o = o or {}
	return setmetatable(o, {__index = Player})
end

function Player:UpdateAnswerCount(round)	
	self.answer_count = self.answer_count + 1 
end

function Player:UpdateCorrectCount()
	self.correct_count = self.correct_count + 1
	QuizInfo.last_answer_right_count = QuizInfo.last_answer_right_count + 1
end

function Player:UpdateQuizStatus(status)
	self.is_quiz = status
end

function Player:ClearData()
	self.answer_count = 0
	self.correct_count = 0
	self.is_quiz = 0
end

-- 获取玩家答对的总题数
function Player:GetTotalRightCount()	
	return self.correct_count
end

-- 获取答题次数
function Player:GetTotalAnswerCount()
	return self.answer_count
end

----------------------- notify -------------------------
-- 发题通知
local function notify_dispatch(n)
	log.debug("In_notify_dispatch: dispatch ......")
	local cmd = Command.WORLD_QUIZ_DISPATCH_NOTIFY
	local msg = {}
	msg[1] = 1
	msg[2] = Command.RET_SUCCESS
	msg[3] = QuizInfo.round
	msg[4] = QuizInfo.question_id
	msg[5] = QuizInfo.last_answer_right_count					-- 这一轮答题正确玩家人数
 	msg[6] = PlayerManager.GetQuizCount()						-- 参与答题的玩家总人数

	for pid, player in pairs(PlayerManager.player_map) do
		if player.is_quiz > 0 then
			notify(cmd, pid, msg)
		end
	end
	QuizInfo.last_answer_right_count = 0
end

-- 答题结束通知 
local function notify_gameover()
	log.debug("In_notify_gameover: game over ......")
	local cmd = Command.WORLD_QUIZ_GAME_OVER_NOTIFY
	local msg = {}
	msg[1] = 2
	msg[2] = Command.RET_SUCCESS
	msg[3] = PlayerManager.GetAnswerInfo()

	for pid, player in pairs(PlayerManager.player_map) do
		if player.is_quiz > 0 then
			notify(cmd, pid, msg)
		end
	end
end

-- 发放奖励（以邮件的方式）
local function send_reward()
	for pid, player in pairs(PlayerManager.player_map) do
	 	local reward = RewardConfig[player:GetTotalRightCount()]			
		if reward then
			local respond = send_reward_by_mail(pid, "公会答题奖励", string.format("恭喜您获得公会答题奖励，回答正确次数 %d", player:GetTotalRightCount()), reward)
			if not respond then
				log.warning("In_send_reward: send reward failed.")
			end
		else
			log.warning("In_send_reward: reward is nil.")
		end
	end
end

-- 答题协程
local function answer_thread()
	local beginTime = begin_time()
	while true do
		local roundInfo = get_round_info(beginTime, loop.now())
		log.debug("In_answer_thread: ")
		log.debug(sprinttb(roundInfo))
		log.debug("current round = ", QuizInfo.round)
		-- 如果当前正好处于发题时间
		if roundInfo[2] == ANSWER_TIME and roundInfo[3] == COUNT_DOWN then 			
			-- 更新答题轮数等信息
			if QuizInfo.round ~= roundInfo[1] then
				QuizInfo.round = roundInfo[1]	
				QuizInfo.question_id = rand_id(QuizInfo.qid_list)

				if QuizInfo.question_id == 0 then
					for id, _ in pairs(QuestionConfig[1] or {}) do
						table.insert(QuizInfo.qid_list, id)
					end
					QuizInfo.question_id = rand_id(QuizInfo.qid_list)
				end
			end
			-- 发题
			notify_dispatch()
			if QuizInfo.round >= QUESTION_COUNT then
				Sleep(roundInfo[2])
				break
			else
				Sleep(roundInfo[2] + roundInfo[3])	
			end
		else	
			if QuizInfo.round >= QUESTION_COUNT then					
				Sleep(roundInfo[2])
				break
			end
			Sleep(roundInfo[2] + roundInfo[3])
			-- 更新答题轮数等信息
			QuizInfo.round = roundInfo[1] + 1	
			QuizInfo.question_id = rand_id(QuizInfo.qid_list)
			-- 发题
			notify_dispatch()
			Sleep(ANSWER_TIME + COUNT_DOWN)	
		end
	end
	notify_gameover()
	-- 发放奖励
	send_reward()
	-- 清除全局的答题信息
	QuizInfo.Reset()
	-- 清除玩家的答题信息
	PlayerManager.ClearPlayerInfo()
end

------------------- register ----------------------------
local WorldQuiz = {}
function WorldQuiz.RegisterCommand(service)
	-- 获取答题信息
	service:on(Command.C_QUIZ_WORLD_QUERY_INFO_REQUEST, function(conn, pid, request)
		local cmd = Command.C_QUIZ_WORLD_QUERY_INFO_RESPOND
		log.debug(string.format("cmd: %d, player %d get answer infomation.", cmd, pid))	

		-- 参数检测
		if type(request) ~= "table" or #request < 1 then
			log.info(string.format("cmd: %d, param error.", cmd))	
			return conn:sendClientRespond(cmd, pid, { 0, Command.RET_ERROR })
		end	
		local sn = request[1] or 0
		
		-- 判断玩家等级能否开启军团答题
		if OpenlevConfig.get_level(pid) < ActivityConfig.open_level then
			log.warning(string.format("cmd: %d, player %d level is not enough.", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_DEPEND })
		end

		-- 查看玩家存在
		local player = PlayerManager.GetPlayer(pid)
		if not player then
			log.warning(string.format("cmd: %d, get player info error, pid = %d", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end

		-- 检查是否处于答题时间范围
		if not is_range() then
			log.info(string.format("cmd: %d, not in quiz time range, now is %d", cmd, loop.now()))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
		
		-- 如果答题协程还没启动，则启动协程
		local info = get_round_info(begin_time(), loop.now())	
		if QuizInfo.co == nil then
			QuizInfo.round = info[1]
			for id, _ in pairs(QuestionConfig[1] or {}) do
				table.insert(QuizInfo.qid_list, id)
			end
			QuizInfo.question_id = rand_id(QuizInfo.qid_list)
			QuizInfo.co = RunThread(answer_thread) 
		end
	
		if player.is_quiz ~= 1 then
			player:UpdateQuizStatus(1)		-- 1 代表玩家参与世界答题活动
			PlayerDB.SyncData(player)
		end

		local respond = {}
		respond[1] = sn
		respond[2] = Command.RET_SUCCESS
		respond[3] = QuizInfo.round			-- round
		respond[4] = QuizInfo.question_id		-- 题目id
		respond[5] = info[2]				-- 答题时间
		respond[6] = info[3]				-- 倒计时时间
		respond[7] = player.correct_count

		conn:sendClientRespond(cmd, pid, respond)
	end)	

	-- 答题
	service:on(Command.C_QUIZ_WORLD_ANSWER_REQUEST, function(conn, pid, request)
		local cmd = Command.C_QUIZ_WORLD_ANSWER_RESPOND
		log.debug(string.format("cmd: %d, player %d answer the question.", cmd, pid))
		
		-- 参数检测
		if type(request) ~= "table" or #request < 2 then
			log.info(string.format("cmd: %d, param error.", cmd))	
			return conn:sendClientRespond(cmd, pid, { 0, Command.RET_ERROR })
		end	
		local sn = request[1] or 0
		local answer = request[2] or 0
			
		-- 查看玩家存在
		local player = PlayerManager.GetPlayer(pid)
		if not player then
			log.warning(string.format("cmd: %d, get player info error, pid = %d", cmd, pid))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
				
		-- 检查是否处于世界答题活动时间范围
		if not is_range() then
			log.info(string.format("cmd: %d, not in quiz time range, now is %d.", cmd, loop.now()))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end

		-- 检查是否处于15秒答题时间范围
		if not is_answer_time() then
			log.info(string.format("cmd: %d, not in answer time, now is %d.", cmd, loop.now()))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end

		-- 答案是否正确
		local is_right = 0
		if QuestionConfig[1][QuizInfo.question_id].answer == answer then
			player:UpdateCorrectCount()
			is_right = 1
		end
		player:UpdateAnswerCount()
		PlayerDB.SyncData(player)

		local respond = {}
		respond[1] = sn
		respond[2] = Command.RET_SUCCESS
		respond[3] = is_right 	

		-- 玩家答题时通知其他玩家
		PlayerManager.BroadcastAnswer(pid, answer, is_right)

		conn:sendClientRespond(cmd, pid, respond)
	end)
end

return WorldQuiz
