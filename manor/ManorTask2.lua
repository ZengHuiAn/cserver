local Command = require "Command"
local protobuf = require "protobuf"
local cell = require "cell"
local SocialManager = require "SocialManager"  
local openlv = require "OpenlevConfig"
local ManorWorkman = require "ManorWorkman"
local StableTime = require "StableTime"
require "MailReward"
local get_begin_time_of_day = StableTime.get_begin_time_of_day
local ORIGIN_TIME = 1495382400  	-- 2017/5/22 00:00:00
local NSECONDS_PER_DAY = 3600 * 24	-- 一天的秒数
local INTERVAL = 3600			-- 补满3条任务的时间间隔
local INTERVAL2 = 3600 * 4		-- 补齐2条额外任务的时间间隔
local REFRESH_LIMIT = 100  		-- 每日刷新任务次数上限
local FREE_COUNT = 3			-- 免费刷新任务的次数
local TASK_COUNT = 5			-- 普通任务次数
local SPECIAL_COUNT = 2			-- 额外任务次数
local RISK_COUNT = 6			-- 冒险团任务个数

local ORDINARY_TASK1 = 1		-- 普通任务
local SPECIAL_TASK   = 2		-- 特殊任务
local RISK_TASK = 11			-- 冒险团任务

local TASK_STATUS_0 = 0			-- 任务完成
local TASK_STATUS_1 = 1			-- 任务还未被派遣
local TASK_STATUS_2 = 2			-- 任务已经被派遣

local FORTUNE_ID = 801			-- 幸运的property_id
local INTELLIGENCE_ID = 802		-- 智慧的property_id
local POWER_ID = 803			-- 力量的property_id   			 
local TREASURE_ID = 804			-- 寻宝的property_id

math.randomseed(os.time())

local TaskConfig = {}
local PlayerInfo = {}
local PlayerTask = {}
local RewardConfig = {}
local StarRewardConfig = {}

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

-- 获得整点时间
local function whole_time()
	return ORIGIN_TIME + math.floor((loop.now() - ORIGIN_TIME) / INTERVAL) * INTERVAL	
end

-- 额外任务的整点时间
local function whole_time2()
	return ORIGIN_TIME + math.floor((loop.now() - ORIGIN_TIME) / INTERVAL2) * INTERVAL2	
end

local function whole_time3()
	return ORIGIN_TIME + math.floor((loop.now() - ORIGIN_TIME / 28800)) * 28800
end

-- 今天的截止时间
local function dead_time()
	assert(loop.now() > ORIGIN_TIME, "current time should greater than ORIGIN_TIME")
	local n = math.floor( (loop.now() - ORIGIN_TIME) / NSECONDS_PER_DAY ) + 1
	return ORIGIN_TIME + n * NSECONDS_PER_DAY
end

-- 根据类型随机生成一个任务, 返回这个任务在列表中的位置
local function random_task(task_list)
	if task_list == nil or #task_list == 0 then
		return 0
	end
	local totalWeight = 0
	for _, v in ipairs(task_list) do
		totalWeight = totalWeight + v.weight
	end
	local num = math.random(totalWeight)
	for i, v in ipairs(task_list) do
		if num <= v.weight then
			return i
		else
			num = num - v.weight
		end
	end

	return 0
end

-- 从任务列表中随机生成n条不同的任务
local function random_multi_Task(n, task_list)
	local ret = {}
	if task_list == nil or #task_list == 0 then
		return nil
	end
	for i = 1, n do
		local index = random_task(task_list)
		if index ~= 0 then
			table.insert(ret, task_list[index])
			table.remove(task_list, index)
		end
	end
	return ret
end

---------------------------------- 任务配置 --------------------------------------
function TaskConfig.Load()
	local cfg = readFile("../etc/config/manor/config_manor_task.pb", "config_manor_task")
	if cfg then
		log.debug("load config_manor_task success.")
		for i, v in ipairs(cfg.rows) do
			TaskConfig[v.task_type] = TaskConfig[v.task_type] or {}
			local t = { gid = v.gid, time_begin = v.time_begin,  condition1 = v.condition1, weight = v.weight, lv_min = v.lv_min, 
				lv_max = v.lv_max, hold_time = v.hold_time, valid_time = v.valid_time, deadline = v.deadline, fresh_limit = v.fresh_limit, guild_level = v.guild_level }
			table.insert(TaskConfig[v.task_type], t)
		end
	end
end

function TaskConfig.IsEmpty()
	if TaskConfig == nil or #TaskConfig == 0 then
		return true
	end
	return false
end

function TaskConfig.GetTaskList(type)
	local ret = {}
	if TaskConfig.IsEmpty() then
		TaskConfig.Load()
	end
	if TaskConfig[type] == nil then
		return nil
	end
	for _, v in ipairs(TaskConfig[type]) do
		table.insert(ret, v)
	end
	return ret
end

-- 获得任务的有效时间
function TaskConfig.GetValidTime(type, gid)
	if TaskConfig[type] == nil or #TaskConfig[type] == 0  then
		return 0
	end
	for _, v in ipairs(TaskConfig[type]) do
		if v.gid == gid then
			return v.valid_time
		end
	end
	return 0
end

function TaskConfig.GetHoldTime(type, gid)
	if TaskConfig[type] == nil or #TaskConfig[type] == 0  then
		log.debug("GetHoldTime, can not find task", type, gid)
		return 0
	end
	for _, v in ipairs(TaskConfig[type]) do
		if v.gid == gid then
			return v.hold_time
		end
	end

	return 0
end

---------------------------------- 奖励配置 --------------------------------------
function StarRewardConfig.Load()
	local cfg = readFile("../etc/config/manor/config_manor_task_starbox.pb", "config_manor_task_starbox")
        if cfg then
                for _, v in ipairs(cfg.rows) do
                        table.insert(StarRewardConfig, v)
                end
        end
end

function StarRewardConfig.IsEmpty()
        if StarRewardConfig == nil or #StarRewardConfig == 0 then
                return true
        end
        return false
end

function StarRewardConfig.GetReward(gid)
        if StarRewardConfig.IsEmpty() then
                StarRewardConfig.Load()
        end
        for i, v in ipairs(StarRewardConfig) do
                if gid == v.gid then
                        return v
                end
        end
        return nil
end

function RewardConfig.Load()
	local cfg = readFile("../etc/config/manor/config_manor_task_item.pb", "config_manor_task_item")
	if cfg then
		for _, v in ipairs(cfg.rows) do
			table.insert(RewardConfig, v)
		end
	end
end

function RewardConfig.IsEmpty()
	if RewardConfig == nil or #RewardConfig == 0 then
		return true
	end
	return false
end

function RewardConfig.GetReward(gid)
	if RewardConfig.IsEmpty() then
		RewardConfig.Load()
	end
	for i, v in ipairs(RewardConfig) do
		if gid == v.gid then
			return v
		end
	end
	return nil
end

function RewardConfig.GetTaskType(gid)
	if RewardConfig.IsEmpty() then
		RewardConfig.Load()
	end
	for i, v in ipairs(RewardConfig) do
		if gid == v.gid then
			return v.task_type
		end
	end
	return 0
end

function RewardConfig.GetRewardBySuccessRate(gid, rate, uuids)
	local v = RewardConfig.GetReward(gid)
	if v == nil or rate == nil then 
		log.warning("GetRewardBySuccessRate: gid, rate = ", gid, rate)
		return {}
	end
	local ret = {}
	if rate >= v.success_rate1 and rate < v.success_rate2 then
		local value = math.random(v.reward_num_min1, v.reward_num_max1)
		if v.reward_type1 > 0 then
			table.insert(ret, { type = v.reward_type1, id = v.reward_id1, value = value, uuids = v.reward_type1 == 90 and uuids or nil })
		end
	elseif rate >= v.success_rate2 and rate < v.success_rate3 then
		local value = math.random(v.reward_num_min1, v.reward_num_max1)
		local value2 = math.random(v.reward_num_min2, v.reward_num_max2)
		if v.reward_type1 > 0 then
			table.insert(ret, { type = v.reward_type1, id = v.reward_id1, value = value, uuids = v.reward_type1 == 90 and uuids or nil })
		end
		if v.reward_type2 > 0 then
			table.insert(ret, { type = v.reward_type2, id = v.reward_id2, value = value2, uuids = v.reward_type2 == 90 and uuids or nil })
		end
	elseif rate >= v.success_rate3 then
		local value = math.random(v.reward_num_min1, v.reward_num_max1)
		local value2 = math.random(v.reward_num_min2, v.reward_num_max2)
		local value3 = math.random(v.reward_num_min3, v.reward_num_max3)
		if v.reward_type1 > 0 then		
			table.insert(ret, { type = v.reward_type1, id = v.reward_id1, value = value, uuids = v.reward_type1 == 90 and uuids or nil })
		end
		if v.reward_type2 > 0 then
			table.insert(ret, { type = v.reward_type2, id = v.reward_id2, value = value2, uuids = v.reward_type2 == 90 and uuids or nil })
		end
		if v.reward_type3 > 0 then
			table.insert(ret, { type = v.reward_type3, id = v.reward_id3, value = value3, uuids = v.reward_type3 == 90 and uuids or nil })
		end
	end
	return ret
end

function RewardConfig.GetRequire(gid)
	if RewardConfig.IsEmpty() then
		RewardConfig.Load()
	end
	for i, v in ipairs(RewardConfig) do
		if gid == v.gid then
			return { require1 = v.require1, require2 = v.require2, require3 = v.require3, require4 = v.require4, require5 = v.require5 }
		end
	end
	return nil	
end

function RewardConfig.GetRoleCount(gid)
	if RewardConfig.IsEmpty() then
		RewardConfig.Load()
	end
	for i, v in ipairs(RewardConfig) do
		if gid == v.gid then
			return { role_min = v.role_min, role_max = v.role_max }
		end
	end
	return nil	
end

function RewardConfig.GetBigSuccessRate(gid)
	if RewardConfig.IsEmpty() then
		RewardConfig.Load()
	end
	for i, v in ipairs(RewardConfig) do
		if gid == v.gid then
			return v.big_success_rate 
		end
	end
	return 0	
end

function RewardConfig.GetRareRewardRate(gid)
	if RewardConfig.IsEmpty() then
		RewardConfig.Load()
	end
	for i, v in ipairs(RewardConfig) do
		if gid == v.gid then
			return v.special_reward_rate
		end
	end	
	return 0
end

function RewardConfig.GetRareReward(gid)
	if RewardConfig.IsEmpty() then
		RewardConfig.Load()
	end
	for i, v in ipairs(RewardConfig) do
		if gid == v.gid then
			return { type = v.special_reward_type, id = v.special_reward_id, value = math.random(v.special_reward_num_min, v.special_reward_num_max) }
		end
	end
	return {}
end

function RewardConfig.GetEnergy(gid)	
	if RewardConfig.IsEmpty() then
		RewardConfig.Load()
	end
	for i, v in ipairs(RewardConfig) do
		if gid == v.gid then
			return v.require_energy
		end
	end
	return 0
end

function RewardConfig.GetMark(gid)	
	if RewardConfig.IsEmpty() then
		RewardConfig.Load()
	end
	for i, v in ipairs(RewardConfig) do
		if gid == v.gid then
			return v.task_mark
		end
	end
	return 0
end

function RewardConfig.GetStar(gid)
	if RewardConfig.IsEmpty() then
                RewardConfig.Load()
        end
        for i, v in ipairs(RewardConfig) do
                if gid == v.gid then
                        return v.task_star
                end
        end
        return 0
end

---------------------------------------------------------------
local SuccessRateConfig = { map = {} }
function SuccessRateConfig.Load()	
	local cfg = readFile("../etc/config/manor/config_manor_task_equation.pb", "config_manor_task_equation")
	if cfg then
		for _, v in ipairs(cfg.rows) do
			SuccessRateConfig.map[v.task_type] = v
		end
	end
end
SuccessRateConfig.Load()

--------------------------------- 玩家的任务记录数据库操作 --------------------------------------------
function PlayerTask.Load(pid)
	local ok, result = database.query([[select `gid`, `task_type`, unix_timestamp(`last_refresh_time`) as `last_refresh_time`, `hold_task`, 
		`workman1_id`, `workman2_id`, `workman3_id`, `workman4_id`, `workman5_id`, unix_timestamp(`begin_time`) as `begin_time` from `manor_player_task` where `pid` = %d;]], pid)
	if ok and #result > 0 then
		log.debug("select `manor_player_task` success.")
		return result
	else
		return {}
	end
end

function PlayerTask.InsertTask(pid, v)
	if v == nil then
		return false
	end
	local ok = database.update([[replace into `manor_player_task`(`pid`, `gid`, `task_type`, `last_refresh_time`, `hold_task`, `workman1_id`, 
		`workman2_id`, `workman3_id`, `workman4_id`, `workman5_id`, `begin_time`) values(%d, %d, %d, from_unixtime_s(%d), %d, %d, %d, %d, %d, %d, from_unixtime_s(%d));]], 
		pid, v.gid, v.task_type, v.last_refresh_time, v.hold_task, v.workman1_id, v.workman2_id, v.workman3_id, v.workman4_id, v.workman5_id, v.begin_time)
	if ok then
		log.debug("replace into manor_player_task success.")
	end
	return ok
end

function PlayerTask.ResetTaskInfo(pid, gid)
	local ok = database.update([[update `manor_player_task` set `hold_task` = %d, `workman1_id` = %d, `workman2_id` = %d, `workman3_id` = %d, `workman4_id` = %d, `workman5_id` = %d, begin_time = %d 
		where `pid` = %d and `gid` = %d;]],
		TASK_STATUS_0, 0, 0, 0, 0, 0, 0, pid, gid)
	if ok then
		log.debug("update manor_player_task set hold_task = 0 success.")
	end
	return ok
end

function PlayerTask.UpdateDispatch(pid, gid, workman_list, time)
	print('--------------------------------------------------------')
	if type(workman_list) ~= "table" then
		return false
	end
	local workman1 = workman_list[1] or 0
	local workman2 = workman_list[2] or 0
	local workman3 = workman_list[3] or 0
	local workman4 = workman_list[4] or 0	
	local workman5 = workman_list[5] or 0

	local ok = database.update([[update `manor_player_task` set `hold_task` = %d, `workman1_id` = %d, `workman2_id` = %d, `workman3_id` = %d, `workman4_id` = %d, `workman5_id` = %d, 
		`begin_time` = from_unixtime_s(%d) where `pid` = %d and `gid` = %d;]], TASK_STATUS_2, workman1, workman2, workman3, workman4, workman5, time, pid, gid)
	if ok then
		log.debug("update manor_player_task set workman_id and begin_time success.")
	end
	return ok
end

--PlayerTask.UpdateDispatch(463856568092,41,{536    , 2819   , 2826,0,0},1527555082)

function PlayerTask.TermTask(pid, gid)
	local ok = database.update([[update `manor_player_task` set `hold_task` = %d, `workman1_id` = %d, `workman2_id` = %d, `workman3_id` = %d, `workman4_id` = %d, `workman5_id` = %d, `begin_time` = from_unixtime_s(%d)
	where `pid` = %d and `gid` = %d;]], TASK_STATUS_1, 0, 0, 0, 0, 0, 0, pid, gid)
	if ok then
		log.debug("PlayerTask.TermTask: term the task success: ", pid, gid)
	end
	return ok
end

------------------------------------ 玩家信息的数据库操作 ------------------------------------------
function PlayerInfo.LoadPlayerID()
	local ok,result = database.query([[select pid from manor_task_playerInfo]])
	if ok and #result then
		return result
	else
		return nil
	end
end

function PlayerInfo.Load(pid)
	local ok, result = database.query([[select `refresh_count`, unix_timestamp(`last_whole_time`) as `last_whole_time`, unix_timestamp(`last_whole_time2`) as `last_whole_time2`, 
		`complete_count`, unix_timestamp(`today_deadtime`) as `today_deadtime` ,`star_count`,`reward_flag` ,`star_count`,`reward_flag` from `manor_task_playerInfo` where `pid` = %d;]], pid)
	if ok and #result then
		return result[1]
	else
		return nil
	end
end

-- 插入一个新的玩家
function PlayerInfo.InsertPlayerInfo(info)
	local ok = database.update([[insert into `manor_task_playerInfo`(`pid`, `refresh_count`, `last_whole_time`, `last_whole_time2`, `complete_count`, `today_deadtime`) 
		values(%d, %d, from_unixtime_s(%d), from_unixtime_s(%d), %d, from_unixtime_s(%d));]], 
		info.pid, info.refresh_count, info.last_whole_time, info.last_whole_time2, info.complete_count, info.today_deadtime)
	return ok
end

function PlayerInfo.UpdateRefreshCount(pid, count)
	local ok = database.update("update `manor_task_playerInfo` set `refresh_count` = %d where `pid` = %d;", count, pid)
	if ok then
		log.debug("update manor_task_playerInfo: add refresh_count success.")
	end
	return ok
end

function PlayerInfo.UpdateWholeTime(pid)
	local time = whole_time()
	local ok = database.update("update `manor_task_playerInfo` set `last_whole_time` = from_unixtime_s(%d) where `pid` = %d;", time, pid)
	if ok then
		log.debug("update manor_task_playerInfo: set last_whole_time success.")
	end
	return ok
end

function PlayerInfo.UpdateWholeTime2(pid)
	local time = whole_time2()
	local ok = database.update("update `manor_task_playerInfo` set `last_whole_time2` = from_unixtime_s(%d) where `pid` = %d;", time, pid)
	if ok then
		log.debug("update manor_task_playerInfo: set last_whole_time2 success.")
	end
	return ok
end

function PlayerInfo.UpdateCompleteCount(pid, n)
	local ok = database.update("update `manor_task_playerInfo` set `complete_count` = %d where `pid` = %d;", n, pid)
	if ok then
		log.debug("update manor_task_playerInfo: set complete_count is ", n)
	end
	return ok
end

function PlayerInfo.ResetCompleteCountAndTime(pid)
	local time = dead_time()
	local ok = database.update("update `manor_task_playerInfo` set `complete_count` = %d, `today_deadtime` = from_unixtime_s(%d) where `pid` = %d;", 0, time, pid)
	if ok then
		log.debug("update manor_task_playerInfo: set complete_count is 0")
	end
	return ok
end

function PlayerInfo.UpdateStarCount(pid,n)
	print('--------------- pid n =',pid,n)
	local ok = database.update("update `manor_task_playerInfo` set `star_count` = %d where `pid` = %d;", n, pid)
	if ok then
                log.debug("update manor_task_playerInfo: set star_count is",n)
        end
        return ok
end

function PlayerInfo.UpdateRewardFlag(pid,flag)
        local ok = database.update("update `manor_task_playerInfo` set `reward_flag` = %d where `pid` = %d;", flag, pid)
        if ok then
                log.debug("update manor_task_playerInfo: set reward_flag is",flag)
        end
        return ok
end

------------------------------------------ 星星宝箱奖励领取记录 ----------------------------------
local StarboxReward = {}
function StarboxReward.Select(pid,gid)
	local ok,res = database.update("select pid,gid,flag from manor_task_starboxreward where pid = %d and gid = %d",pid,gid)
        if ok and #res > 0 then
		print('0000000000000000000000000000000000000000')
		StarboxReward[pid] = StarboxReward[pid] or {}
		StarboxReward[pid][gid] = res[1].flag
		return StarboxReward[pid][gid]
	else
		print('--------------------nil')
		return nil
        end
end

function StarboxReward.Update(pid,gid,flag,boo)	
	if not boo then
		local ok = database.update("insert into manor_task_starboxreward(pid,gid,flag) values(%d,%d,%d)",pid,gid,flag)
		if not ok then
			log.debug("insert manor_task_starboxreward err...")
			return false
		end
	else
		local ok = database.update("update manor_task_starboxreward set flag = %d where pid = %d and gid = %d;", flag,pid,gid)
		if not ok then
			log.debug("update manor_task_starboxreward err...")
			return false
		end
	end
	
	return true
end

local function getStarboxReward(pid,gid)
	StarboxReward[pid] = StarboxReward[pid] or {}
	local db_in = true
	print('------------------------')
	if not StarboxReward[pid][gid] then
		local box_reward = StarboxReward.Select(pid,gid)
		if box_reward then	
			print('--------------------------------  flag1 = '..box_reward)
			StarboxReward[pid][gid] = box_reward
			db_in = true	
		else
			print('--------------------------------  flag0')
			StarboxReward[pid][gid] = nil
			db_in = false
		end
	end
	return StarboxReward[pid][gid],db_in
end

------------------------------------------- 玩家 --------------------------------------------------
local Player = {}
function Player:New(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

-- 是否可以刷新特殊任务
function Player:IsSpecial()
	return true
end

-- 是否可以刷新这个任务
function Player:IsCanRefresh(task)
	local last_refresh_time = 0
	for _, v in ipairs(self.task_list or {}) do
		if v.gid == task.gid then
			last_refresh_time = v.last_refresh_time
			break
		end
	end

	if last_refresh_time + task.fresh_limit <= loop.now() then
		return true
	else
		return false
	end
end

function Player:IsExist(gid)
	if self.task_list == nil or #self.task_list == 0 then
		return false
	end
	local flag = false
	for i, v in ipairs(self.task_list) do
		if v.gid == gid and v.hold_task ~= TASK_STATUS_0 then
			flag = true
			break
		end
	end	

	return flag
end

-- 获得玩家等级
function Player:GetLevel()
	local info = cell.getPlayerInfo(self.pid)

	if info and info.level then
		return info.level
	else
		log.debug("search player level failed.")
		return 0
	end
end

function Player:GetGuildLevel()
	local info = SocialManager.getGuild(self.pid) 
	if info and info.result == 0 and info.guild.level then
		return info.guild.level
	else
		log.debug("search guild level failed.")
		return 0
	end
end

-- 获得可供刷新的任务列表
function Player:GetRefreshList(type)
	local list = TaskConfig.GetTaskList(type)
	local filterList = {}

	if list == nil then
		print('-----------list = nil')
		return {}
	end
	local guild_level = self:GetGuildLevel() or 0
	local level = self:GetLevel() or 0
	log.debug("GetRefreshList: guild_level, level = ", guild_level, level)
	local _, heros = cell.getPlayerHeroInfo(self.pid)

	for i, v in ipairs(list) do
		local level_ok = level >= v.lv_min and level <= v.lv_max      -- 玩家等级达到
		local time_ok = self:IsCanRefresh(v)       -- 满足刷新时间限制
		local is_exist = self:IsExist(v.gid)
		local is_intime = loop.now() >= v.time_begin and loop.now() <= v.deadline	-- 处于时间范围内
		local has_role = true						-- 是否拥有某个角色
		if v.condition1 ~= 0 then
			has_role = false
			for _, hero in ipairs(heros or {}) do
				if hero.gid == v.condition1 then
					has_role = true
					break
				end
			end
		end
		--[[
		if level_ok then print('1111') end
		if time_ok then print('2222') end
		if v.weight > 0 then print('3333') end
		if not is_exist then print('4444') end
		if is_intime then print('5555') end
		if guild_level >= v.guild_level then print('6666') end
		if has_role then print('7777') end--]]
		if level_ok and v.weight > 0 and not is_exist and is_intime and guild_level >= v.guild_level and has_role then  --TODO   刷新时间限制暂时去除 便于测试
			table.insert(filterList, v)
		end
	end

	return filterList
end

function Player:addTask(task_list, type)
	if task_list == nil then return end
	local time = loop.now()
	for _, v in ipairs(task_list) do
		print('----------------------')
		local exist, index = self:isTaskExist(v.gid)
		local t = { gid = v.gid, task_type = type, last_refresh_time = time, hold_task = TASK_STATUS_1, 
			workman1_id = 0, workman2_id = 0, workman3_id = 0, workman4_id = 0, workman5_id = 0, begin_time = 0 }
		local ok = PlayerTask.InsertTask(self.pid, t)
		if not ok then
			log.warning("insert task failed, task is ", sprinttb(task_list))
		end
		if exist then	
			self.task_list[index] = t
		else	
			table.insert(self.task_list, t)
		end
	end
end

function Player:isTaskExist(gid)
	for i, v in ipairs(self.task_list) do
		if gid == v.gid then
			return true, i
		end
	end
	return false
end

local function ClearTask(task)
	task.hold_task = TASK_STATUS_0
	task.workman1_id = 0
	task.workman2_id = 0
	task.workman3_id = 0
	task.workman4_id = 0
	task.workman5_id = 0
	task.begin_time = 0
end

function Player:addNewTask()
	local n = 0
	for _, v in ipairs(self.task_list or {}) do
		if v.last_refresh_time < whole_time3() and v.hold_task == TASK_STATUS_1 then
			if PlayerTask.ResetTaskInfo(self.pid, v.gid) then
				ClearTask(v)
			end
		end
		if v.hold_task ~= TASK_STATUS_0 then
			n = n + 1
		end
	end
	
	local list = self:GetRefreshList(RISK_TASK)
	-- 插入冒险团任务	
	local tasks = random_multi_Task(RISK_COUNT - n, list)
	if tasks and #tasks > 0 then
		player:addTask(list, RISK_TASK)
	end
end

function Player:RemoveInValidTask()
	local now = loop.now()
	for i, v in ipairs(self.task_list or {}) do
		local validTime = TaskConfig.GetValidTime(v.task_type, v.gid)
		if validTime > 0 and now > validTime + v.last_refresh_time and v.hold_task == TASK_STATUS_1 or now >= get_begin_time_of_day(v.last_refresh_time) + NSECONDS_PER_DAY then
			if PlayerTask.ResetTaskInfo(self.pid, v.gid) then
				ClearTask(v)
			end
		end
	end
end

function Player:OrdinaryTaskCount()
	if self.task_list == nil or #self.task_list == 0 then
		return 0
	end
	local n = 0
	for _, v in ipairs(self.task_list) do
		if v.task_type == ORDINARY_TASK1 and v.hold_task ~= TASK_STATUS_0 then
			n = n + 1
		end 
	end

	return n
end

function Player:SpecialTaskCount()
	if self.task_list == nil or #self.task_list == 0 then
		return 0
	end
	local n = 0
	for _, v in ipairs(self.task_list) do
		if v.task_type == SPECIAL_TASK and v.hold_task ~= TASK_STATUS_0 then
			n = n + 1
		end 
	end

	return n
end

function Player:FillUpTask()
	local n1 = TASK_COUNT - self:OrdinaryTaskCount()
	local n2 = 0
	if self:IsSpecial() then
		n2 = SPECIAL_TASK - self:SpecialTaskCount()
	end
	print('---------------------------------------------- n1 n2 = ',n1,n2)
	local list1 = self:GetRefreshList(ORDINARY_TASK1)
	local list2 = self:GetRefreshList(SPECIAL_TASK)
	local fill_list1 = random_multi_Task(n1, list1)
	local fill_list2 = random_multi_Task(n2, list2)

	print('----------------- #list1 #list2',#list1,#list2)
	if fill_list1 and #fill_list1 > 0 then	-- and self.last_whole_time < whole_time() then
		print('sssssssssssssssssssssssssssssssssssssssssss')
		self:addTask(fill_list1, ORDINARY_TASK1)
		local ok = PlayerInfo.UpdateWholeTime(self.pid)
		if ok then
			self.last_whole_time = whole_time()
		end
	end
	if fill_list2 and #fill_list2 > 0 and self.last_whole_time2 < whole_time2() then
		self:addTask(fill_list2, SPECIAL_TASK)
		local ok = PlayerInfo.UpdateWholeTime2(self.pid)
		if ok then
			self.last_whole_time2 = whole_time2()
		end
	end
end

function Player:IsWorkmanIdValid(workman_id)
	local hero = cell.getPlayerHeroInfo(self.pid, 0, workman_id)
	if hero then
		return true
	else
		return false
	end
end


function Player:IsWorkmanIdListValid(list)
	local ret = true
	for _, v in ipairs(list) do
		ret = self:IsWorkmanIdValid(v)
		if not ret then return false end
	end
	return ret
end

function Player:IsDispatch(workman_list)
	for _, v in ipairs(workman_list) do
		if v == 0 or self:IsDispatch2(v) then
			return true
		end
	end
	return false
end


function Player:IsDispatch2(workman_id)
	for _, v in ipairs(self.task_list) do
		if v.hold_task == TASK_STATUS_2 then
			if v.workman1_id == workman_id or v.workman2_id == workman_id or v.workman3_id == workman_id or v.workman4_id == workman_id or v.workman5_id == workman_id then
				return true
			end	
		end
	end
	return false
end

function Player:IsLevel(gid, workman_list)
	if workman_list == nil or #workman_list == 0 then
		return false
	end

	local flag = true

	local req = RewardConfig.GetRequire(gid)
	local level_limit = req and req.require1 or 1000
	for _, v in ipairs(workman_list) do	
		local hero = cell.getPlayerHeroInfo(self.pid, 0, v)
		if not hero or hero.level < level_limit then
			return false
		end 
	end
	return true
end

function Player:IsId(gid, workman_list)
	if workman_list == nil or #workman_list == 0 then
		return false
	end

	local flag = false

	local req = RewardConfig.GetRequire(gid)
	local require5 = req.require5
	if require5 == 0 then
		return true
	end

	for _, uuid in ipairs(workman_list) do 
		local hero = cell.getPlayerHeroInfo(self.pid, 0, uuid)
		log.debug("card id = ", hero.gid)
		if hero and hero.gid == require5 then
			flag = true
			break
		end	
	end
	return flag	
end

function Player:isPowerOK(gid, workman_list)
	local man = ManorWorkman.Get(self.pid) 
	if not man then
		log.warning("isPowerOK: workman is nil, pid = ", self.pid)
		return false
	end

	local n = RewardConfig.GetEnergy(gid)
	for _, id in ipairs(workman_list or {}) do	
		local power = man:GetWorkmanPower(id) or 0
		if power < n then
			log.debug("isPowerOK: power not enough, ", info.now_power, n)
			return false
		end
	end
	return true
end

-- 派遣n个人去执行任务
function Player:DispatchTask(gid, workman_list)
	print('---------------------------------------------- workman_list = ',workman_list[1],workman_list[2],workman_list[3],workman_list[4],workman_list[5])
	if self.task_list == nil or #self.task_list == 0 then
		return false
	end
	
	-- 检测派遣的人数是否足够
	local role_limit = RewardConfig.GetRoleCount(gid)
	local min = role_limit and role_limit.role_min or 100
	local max = role_limit and role_limit.role_max or 0
	if #workman_list < min or #workman_list > max then
		log.debug("workman count is not enough")
		return false
	end

	-- 检测workman_id是否合法
	local valid = self:IsWorkmanIdListValid(workman_list)
	if not valid then
		log.debug("workman id not exist.") 
		return false
	end	

	-- 检测workman是否已经被派遣
	local dispatch = self:IsDispatch(workman_list)
	if dispatch then
		log.debug("workman has been dispatch.")
		return false
	end

	-- 检测活力是否满足
	if not self:isPowerOK(gid, workman_list) then
		log.debug("power not enough")
		return false
	end

	-- 检测就角色等级是否满足要求
	local is_level = self:IsLevel(gid, workman_list)
	if not is_level then
		log.debug("workman level is too low.")
		return false
	end
	
	-- 检测元素是否满足要求
	
	-- 检测属性分数限制
	
	-- 检测角色性别是否满足要求
	
	-- 检测妖精id
	local is_id = self:IsId(gid, workman_list)
	if not is_id then
		log.debug("card is not exist.")
		return false
	end
	
	for i, v in ipairs(self.task_list) do 
		if v.gid ==  gid and v.hold_task == TASK_STATUS_1 then
			local currTime = loop.now()
			-- 指派n个人去完成任务
			local ok = PlayerTask.UpdateDispatch(self.pid, gid, workman_list, currTime)
			if ok then
				v.hold_task = TASK_STATUS_2
				v.begin_time = currTime
				v.workman1_id = workman_list[1] or 0
				v.workman2_id = workman_list[2] or 0
				v.workman3_id = workman_list[3] or 0
				v.workman4_id = workman_list[4] or 0
				v.workman5_id = workman_list[5]	or 0
			end
			return true
		end
	end

	return false
end


function Player:GetTask(gid)
	if self.task_list == nil or #self.task_list == 0 then
		return nil
	end

	for i, v in ipairs(self.task_list) do
		if v.gid == gid and v.hold_task == TASK_STATUS_1 then
			return i, v
		end
	end

	return nil
end

function Player:GetUUids(gid)
	local _, task = self:GetTask(gid)
	if not task then
		return {}
	end

	local ret = {}
	if task.workman1_id ~= 0 then
		table.insert(ret, task.workman1_id)
	end
	if task.workman2_id ~= 0 then
		table.insert(ret, task.workman2_id)
	end
	if task.workman3_id ~= 0 then
		table.insert(ret, task.workman3_id)
	end
	if task.workman4_id ~= 0 then
		table.insert(ret, task.workman4_id)
	end
	if task.workman5_id ~= 0 then
		table.insert(ret, task.workman5_id)
	end
	
	return ret
end

function Player:RefreshTask(gid)
	if self.task_list == nil or #self.task_list == 0 then
		return Command.RET_ERROR
	end

	local i, v = self:GetTask(gid)
	if i == nil then
		return Command.RET_ERROR
	end

	-- 刷新次数到达上限
	if self.refresh_count == REFRESH_LIMIT then
		return Command.RET_NOT_ENOUGH 
	end

	if ORDINARY_TASK1 == v.task_type then
		local ok = PlayerTask.ResetTaskInfo(self.pid, gid)
		if ok then 
			ClearTask(self.task_list[i])
		end
		local list1 = self:GetRefreshList(ORDINARY_TASK1)
		local fill_list1 = random_multi_Task(1, list1)
		if fill_list1 and #fill_list1 > 0 then
			self:addTask(fill_list1, ORDINARY_TASK1)
		end
		return Command.RET_SUCCESS
	elseif SPECIAL_TASK == v.task_type then
		local ok = PlayerTask.ResetTaskInfo(self.pid, gid)
		if ok then 
			ClearTask(self.task_list[i])
		end
		local list2 = self:GetRefreshList(SPECIAL_TASK)
		local fill_list2 = random_multi_Task(1, list2)
		if fill_list2 and #fill_list2 > 0 then
			self:addTask(fill_list2, SPECIAL_TASK)
		end
		return Command.RET_SUCCESS
	end

	return Command.RET_NOT_EXIST
end

function Player:TermTask(gid)	
	if self.task_list == nil or #self.task_list == 0 then
		log.debug("TermTask: task list is empty.")
		return false
	end
	
	for i, v in ipairs(self.task_list) do
		if v.gid == gid and v.hold_task == TASK_STATUS_2 then
			local ok = PlayerTask.TermTask(self.pid, gid)
			if ok then
				v.hold_task = TASK_STATUS_1
				v.begin_time = 0
				v.workman1_id = 0
				v.workman2_id = 0
				v.workman3_id = 0
				v.workman4_id = 0
				v.workman5_id = 0	
			end
			return true
		end
	end
	return false
end

function Player:EndTask(gid)	
	if self.task_list == nil or #self.task_list == 0 then
		log.debug("EndTask: task list is empty.")
		return false
	end
	print('----------------------------------提前结束0')
	for i, v in ipairs(self.task_list) do
		if v.gid == gid and v.hold_task == TASK_STATUS_2 then
			local holdtime = TaskConfig.GetHoldTime(v.task_type, v.gid)
			local end_time = v.begin_time + holdtime
			print('-----------------------  end_time  v.begin_time ',end_time,v.begin_time)

			end_time = end_time > loop.now() and loop.now()	or end_time					

			--[[
			local n = math.floor((end_time - v.begin_time) / 60)		-- 钻石数量
			if n == 0 then
				n = 1
			end--]]
			
			local success_rate = self:SuccessRate1(v)
			print('-----------------------  end_time  v.begin_time ',end_time,v.begin_time)
			local n = math.ceil(holdtime/120)
			print('----------------------------------提前结束1',n)	
			local ok = PlayerTask.ResetTaskInfo(self.pid, gid)
			if ok then
				ClearTask(self.task_list[i])
				local res = cell.sendReward(self.pid, nil, { {type = 41, id = 90006, value = n} }, Command.REASON_MANOR_TASK_STONE, false)
				if not res then
					return false
				end 
			end
			return true, success_rate
		end
	end
	
	return false
end

function Player:SingleScore(taskType, workman_id)
	if workman_id == 0 then
		return 0
	end

	local workman = GetManufactureQualifiedWorkmen(self.pid)
	if not workman then
		log.warning("SingleScore: get workman failed.")
		return 0
	end

	local cfg = SuccessRateConfig.map[taskType]
	if not cfg then
		log.warning("SingleScore: SuccessRateConfig is nil ", taskType)
		return 0
	end

	local data = 0
	for i = 1, 4 do
		if cfg["property_type" .. i] > 0 then
			data = data + workman:GetProperty(workman_id, cfg["property_type" .. i]) * cfg["property_ratio" .. i]
		end
	end

	--[[if taskType == 1 then
		local intelligence = workman:GetProperty(workman_id, INTELLIGENCE_ID)
		local power = workman:GetProperty(workman_id, POWER_ID)
		return intelligence * 0.8 + power * 0.2
	elseif taskType == 2 then
		local power = workman:GetProperty(workman_id, POWER_ID)
		local fortune = workman:GetProperty(workman_id, FORTUNE_ID)
		return power * 0.75 + fortune * 0.25
	elseif taskType == 4 then
		local treasure = workman:GetProperty(workman_id, TREASURE_ID)
		return treasure * 0.95
	elseif taskType == 3 then
		local fortune = workman:GetProperty(workman_id, FORTUNE_ID)
		return fortune * 0.85
	end--]]

	return data
end


function Player:SuccessRate(task)
	if not task then
		return 0
	end
	
	local taskType = RewardConfig.GetTaskType(task.gid)
	local score1 = self:SingleScore(taskType, task.workman1_id)
	local score2 = self:SingleScore(taskType, task.workman2_id)
	local score3 = self:SingleScore(taskType, task.workman3_id)
	local score4 = self:SingleScore(taskType, task.workman4_id)
	local score5 = self:SingleScore(taskType, task.workman5_id)

	local mark = RewardConfig.GetMark(task.gid)
	if mark == 0 then
		log.warning(string.format("SuccessRate: mark is 0"))
		return 0
	else
		return math.floor((score1 + score2 + score3 + score4 + score5) / mark * 100)
	end
end

function Player:SingleScore1(property_type, workman_id)
	if workman_id == 0 then
                print('---------------------------- workman_id == 0')
                return 0
        end

        local workman = GetManufactureQualifiedWorkmen(self.pid)
        if not workman then
                log.warning("SingleScore: get workman failed.")
                return 0
        end

        return workman:GetProperty(workman_id, property_type)
end

function Player:SuccessRate1(task)
        if not task then
                return 0
        end

        local temp = RewardConfig.GetReward(task.gid)
        local  property_type = temp.task_work_type
        print('-------------------------- property_type = ',property_type,task.workman1_id,task.workman2_id,task.workman3_id,task.workman4_id,task.workman5_id,'------------gid  = '..task.gid)

        local score1 = self:SingleScore1(property_type, task.workman1_id)
       	local score2 = self:SingleScore1(property_type, task.workman2_id)
        local score3 = self:SingleScore1(property_type, task.workman3_id)
       	local score4 = self:SingleScore1(property_type, task.workman4_id)
        local score5 = self:SingleScore1(property_type, task.workman5_id)

        local mark = RewardConfig.GetMark(task.gid)
        if mark == 0 then
                log.warning(string.format("SuccessRate: mark is 0"))
                return 0
        else
                print('--------------------------------- score1 score2 score3 score4 score5:',score1, score2, score3, score4, score5,mark)
                return math.floor((score1 + score2 + score3 + score4 + score5) / mark * 100)
        end
end


function Player:GetWorkmanCount(task)
	if task == nil or task.hold_task ~= TASK_STATUS_2 then
		return 0
	end
	local n = 0
	if task.workman1_id ~= 0 then n = n + 1 end
	if task.workman2_id ~= 0 then n = n + 1 end
	if task.workman3_id ~= 0 then n = n + 1 end
	if task.workman4_id ~= 0 then n = n + 1 end
	if task.workman5_id ~= 0 then n = n + 1 end
	return n
end

function Player:TaskDone(gid, type)
	if self.task_list == nil or #self.task_list == 0 then
		log.debug("TaskDone: task_list is Empty.")
		return false
	end

	for i, v in ipairs(self.task_list) do
		if v.gid == gid and v.hold_task == TASK_STATUS_2 then
			local success_rate = 0
			if type == 1 then
				success_rate = self:SuccessRate1(v)
			else
				success_rate = 100
			end
			if loop.now() < v.begin_time + TaskConfig.GetHoldTime(v.task_type, gid) then   -- 判断任务完成时间是否足够
				log.debug("TaskDone: complete time not enough, begin time is ", v.begin_time)
				return false
			end
			if type == 1 then
				local ok = PlayerTask.ResetTaskInfo(self.pid, gid)
				if ok then 
					ClearTask(self.task_list[i])
				end
			else
				local ok = PlayerTask.TermTask(self.pid, gid)
				if ok then
					v.hold_task = TASK_STATUS_1
				end
			end
			return true, success_rate
		end
	end
	log.debug("TaskDone: gid not found, gid = ", gid)
	return false
end

-- 获得主动刷新一次需要消耗的钻石数量
function Player:DiamondCount()
	local n = self.refresh_count
	if n <= FREE_COUNT then 
		return 0
	elseif n <= FREE_COUNT + 10 then
		return 2
	else
		return math.floor((n - FREE_COUNT - 1) / 10) * 10 + 2
	end
end

function Player:GetRefreshCount()
	return self.refresh_count
end

function Player:UpdateRefreshCount()
	local count = self.refresh_count + 1
	local ok = PlayerInfo.UpdateRefreshCount(self.pid, count)
	if ok then
		self.refresh_count = count
	end
end

function Player:GetTaskList()
	if self.task_list == nil or #self.task_list == 0 then
		print('-----------------GetTaskList = nil ')
		return {}
	end 

	local ret = {}
	for _, v in ipairs(self.task_list) do
		if v.hold_task ~= TASK_STATUS_0 then
			local t = { v.gid, v.hold_task }
			local workmanid_list = {}
			if v.hold_task == TASK_STATUS_2 and v.workman1_id ~= 0 then table.insert(workmanid_list, v.workman1_id) end
			if v.hold_task == TASK_STATUS_2 and v.workman2_id ~= 0 then table.insert(workmanid_list, v.workman2_id) end
			if v.hold_task == TASK_STATUS_2 and v.workman3_id ~= 0 then table.insert(workmanid_list, v.workman3_id) end
			if v.hold_task == TASK_STATUS_2 and v.workman4_id ~= 0 then table.insert(workmanid_list, v.workman4_id) end
			if v.hold_task == TASK_STATUS_2 and v.workman5_id ~= 0 then table.insert(workmanid_list, v.workman5_id) end
			
			local holdTime = TaskConfig.GetHoldTime(v.task_type, v.gid)
			local begin_time = v.begin_time or 0
			table.insert(t, begin_time)
			table.insert(t, begin_time + holdTime) 
			table.insert(t, self:SuccessRate(v))		
			table.insert(t, workmanid_list)
			table.insert(ret, t)
		end
	end
	return ret
end

function Player:RefreshCompleteCount()
	local time = dead_time()
	if time > self.today_deadtime then
		local ok = PlayerInfo.ResetCompleteCountAndTime(self.pid)
		if ok then
			self.complete_count = 0
			self.today_deadtime = time
		end
	end
end

-- 获取今天完成的任务次数
function Player:GetCompleteCount()
	return self.complete_count
end

function Player:SetCompleteCount(n)
	local ok = PlayerInfo.UpdateCompleteCount(self.pid, n)
	if ok then
		self.complete_count = n
	end
end

function Player:GetStarCount()
	return self.star_count
end

function Player:SetStarCount(n)
	local count = self.star_count + n
	local ok = PlayerInfo.UpdateStarCount(self.pid,count)
	if ok then
		self.star_count = count
	end
end

function Player:GetRewardFlag()
	return self.reward_flag
end

function Player:SetRewardFlag(flag)
	local ok = PlayerInfo.UpdateRewardFlag(self.pid,flag)
	if ok then
		self.reward_flag = flag
	end
end

--如果工人正在线上工作那么需要更新生产线
function Player:CheckWorkmanWorking(workman_id)
	local lineInfo = GetManufacture(self.pid)	
	if lineInfo then
		lineInfo:GetWorkmanLineAndPos(workman_id)
	end
end

-- 扣除精力
function Player:TakeEnergy(gid)
	local task = nil
	for i, v in ipairs(self.task_list or {}) do
		if v.gid == gid then
			task = v		
		end
	end
	
	if task == nil then
		log.warning(string.format("TakeEnergy: task is nil, gid = %d", gid))
		return
	end

	local n = RewardConfig.GetEnergy(gid)

	local man = ManorWorkman.Get(self.pid)
	if not man then
		log.warning("TakeEnergy: get workman failed, pid = ", self.pid)
		return 
	end

	if task.workman1_id ~= 0 then
		self:CheckWorkmanWorking(task.workman1_id)
		man:decreaseWorkmanPower(task.workman1_id, n)
	end
	if task.workman2_id ~= 0 then
		self:CheckWorkmanWorking(task.workman2_id)
		man:decreaseWorkmanPower(task.workman2_id, n)	
	end
	if task.workman3_id ~= 0 then
		self:CheckWorkmanWorking(task.workman3_id)
		man:decreaseWorkmanPower(task.workman3_id, n)
	end
	if task.workman4_id ~= 0 then
		self:CheckWorkmanWorking(task.workman4_id)
		man:decreaseWorkmanPower(task.workman4_id, n)
	end
	if task.workman5_id ~= 0 then
		self:CheckWorkmanWorking(task.workman5_id)
		man:decreaseWorkmanPower(task.workman5_id, n)
	end
end

------------------------------------------ 玩家列表 ----------------------------------------------
local PlayerList = {}
function PlayerList.Load(pid, type)
	local task = PlayerTask.Load(pid)
	local info = PlayerInfo.Load(pid)
	if not info then				-- 玩家不存在
		log.debug("there is no player, need to insert a new one.")
		local time = whole_time()
		local time2 = whole_time2()
		local t = { pid = pid, refresh_count = 0, last_whole_time = time, last_whole_time2 = time2, complete_count = 0, today_deadtime = dead_time(),star_count = 0,reward_flag = 0}
		local ok = PlayerInfo.InsertPlayerInfo(t)
		if ok then log.debug("insert into manor_task_playerInfo success.") end
		t.task_list = {}
		PlayerList[pid] = Player:New(t)
		if type == 1 then
			-- 插入三个普通任务
			local list = PlayerList[pid]:GetRefreshList(ORDINARY_TASK1)
			local random_task = random_multi_Task(TASK_COUNT, list)
			PlayerList[pid]:addTask(random_task, ORDINARY_TASK1)
			-- 判断是否可以刷新特殊任务
			if PlayerList[pid]:IsSpecial() then
				local list = PlayerList[pid]:GetRefreshList(SPECIAL_TASK)
				local random_task = random_multi_Task(SPECIAL_COUNT, list)
				PlayerList[pid]:addTask(random_task, SPECIAL_TASK)
			end
		else
			-- 插入冒险团任务	
			local list = PlayerList[pid]:GetRefreshList(RISK_TASK)
			local tasks = random_multi_Task(list, RISK_COUNT)
			if tasks and #tasks > 0 then
				PlayerList[pid]:addTask(tasks, RISK_TASK)
			end
		end
	else 	
		PlayerList[pid] = Player:New(info)
		PlayerList[pid].task_list = task
		PlayerList[pid].pid = pid
	end
end

function PlayerList.GetPlayer(pid, type)
	if PlayerList[pid] == nil then
		PlayerList.Load(pid, type)
	end
	return PlayerList[pid]
end

----------------------------------------------------------------------------------------
local function StarRewardContent(star_reward)
	local reward1 = { type = star_reward.reward_type1,id = star_reward.reward_id1,value = star_reward.reward_value1}
        local reward2 = { type = star_reward.reward_type2,id = star_reward.reward_id2,value = star_reward.reward_value2}
        local reward3 = { type = star_reward.reward_type3,id = star_reward.reward_id3,value = star_reward.reward_value3}

        if star_reward.reward_type1 == 0 or  star_reward.reward_id1 == 0 then
                reward1 = nil
        end
        if star_reward.reward_type2 == 0 or  star_reward.reward_id2 == 0 then
                reward2 = nil
        end
        if star_reward.reward_type3 == 0 or  star_reward.reward_id3 == 0 then
                reward3 = nil
        end
        
	return { reward1,reward2,reward3 }
end

local function Exchange(pid,reward,consume,reason)
        local ret = cell.sendReward(pid,reward,consume,reason)
        if ret and ret.result == Command.RET_SUCCESS then
                return true
        else
                log.warning("Exchange fail, cell error")
                return false
        end
end


local THIS_YEAR_FIRSTDAY_5 = 1514754000
local function begin_time(now)
        local n = math.floor((now - THIS_YEAR_FIRSTDAY_5) / NSECONDS_PER_DAY)
        return THIS_YEAR_FIRSTDAY_5 + n * NSECONDS_PER_DAY
end

----[[
Scheduler.Register(function(now)
	local beginTime = begin_time(now) 
	if now == beginTime  then
		-- 加载任务列表配置
		if TaskConfig.IsEmpty() then
			TaskConfig.Load()
		end
		
		local res = PlayerInfo.LoadPlayerID()
		for _,v in ipairs(res or {}) do
			-- 刷新任务
			local player = PlayerList.GetPlayer(v.pid, 1)
			player:RefreshCompleteCount()

			for _, w in ipairs(player.task_list or {}) do
           	     		if PlayerTask.ResetTaskInfo(v.pid, w.gid) then
                        		ClearTask(w)
                		end
        		end
			player:FillUpTask()

			-- 发放奖励邮件
			local star_count = player:GetStarCount()
		        for i = 1,4,1 do
                		local flag = getStarboxReward(v.pid,i)
				if not flag or flag == 0 then
					print('-------------------------------- 领宝箱：')
	                                local star_reward = StarRewardConfig.GetReward(i)
					if star_count >= star_reward.star_value then
						local rewards = StarRewardContent(star_reward)
						print('=======================',rewards[1].type)
						local co = coroutine.create(function()
							send_reward_by_mail(v.pid,string.format("酒馆任务%d星宝箱未领取奖励",star_reward.star_value),nil,rewards)
						end)
						coroutine.resume(co)
						print('--------------------------uuuuu')
					end
				else
					StarboxReward.Update(v.pid,i,0,true)
					flag = 0	
				end
			end

			-- 重置星星数
			PlayerInfo.UpdateStarCount(v.pid,0)
                	player.star_count = 0
		end
	end
end)--]]

-----------------------------------------------------------------------------------------
local function get_task_respond(pid, request) 
	print('---------------------------------------------------------------------------------------- get_task_respond')
	if type(request) ~= "table" or #request < 2 then
		return { 0, Command.RET_PARAM_ERROR }
	end

	-- 加载任务列表配置
	if TaskConfig.IsEmpty() then
		TaskConfig.Load()
	end

	-- 获取玩家信息
	local player = PlayerList.GetPlayer(pid, request[2])

	-- 刷新今天的完成次数
	player:RefreshCompleteCount()

	-- 移除已经失效的任务
	player:RemoveInValidTask()
	
	--[[
	-- 增加功能开启判断
	local ok = openlv.isLvOK(pid, 2002)
	if request[2] == 1 and not ok then	
		print('-------------------------------22')
		return { request[1], Command.RET_ERROR }
	end--]]
	if request[2] == 1 then
		if player:OrdinaryTaskCount() == 0 then
			-- 补齐任务
			player:FillUpTask()
		end
	else
		-- 如果是新的一轮，将旧的任务替换成新的任务
		player:addNewTask()
	end

	local ret = player:GetTaskList()	
	print('-------------------------------返回数据：',request[1], Command.RET_SUCCESS, ret, player:GetRefreshCount(), player:GetCompleteCount())
	return { request[1], Command.RET_SUCCESS, ret, player:GetRefreshCount(), player:GetCompleteCount() }
end

local function get_task_todo(pid, request)
	print('-------------------------------------------------------------------- get_task_todo:',request[1],request[2],request[3],request[4])
	-- 参数判断
	if type(request) ~= "table" or #request < 4 then
		return { 0, Command.RET_PARAM_ERROR }
	end
	local gid = request[2]
	if type(gid) ~= "number" then
		request[1] = request[1] or 1	
		return { request[1], Command.RET_PARAM_ERROR }
	end
	if type(request[3]) ~= "table" then
		request[1] = request[1] or 1	
		return { request[1], Command.RET_PARAM_ERROR }
	end  

	-- 加载任务列表配置
	if TaskConfig.IsEmpty() then
		TaskConfig.Load()
	end

	-- 获取玩家信息
	local player = PlayerList.GetPlayer(pid, request[4])

	-- 刷新今天的完成次数
	player:RefreshCompleteCount()

	-- 移除已经失效的任务
	player:RemoveInValidTask()

	if request[4] == 1 then
		-- 补齐任务
	--	player:FillUpTask()
	else
		player:addNewTask()
	end

	-- 派遣任务
	local ok = player:DispatchTask(gid, request[3])
	if ok then
		log.debug("dispatch task success.")
		-- 扣除精力
		player:TakeEnergy(gid)
		local ret = player:GetTaskList()
		if not ret then
			print('---------  there is no tasklist...')
		end
		return { request[1], Command.RET_SUCCESS, ret, player:GetRefreshCount(), player:GetCompleteCount() }
	else
		log.debug("dispatch task failed.")
		return { request[1], Command.RET_ERROR }
	end
end

local function get_task_refresh(pid, request)
	print('------------------------------------------------------------------------- get_task_refresh:')
	-- 参数判断
	if type(request) ~= "table" or #request < 3 then
		return { 0, Command.RET_PARAM_ERROR }
	end
	local gid = request[2]
	if type(gid) ~= "number" then
		request[1] = request[1] or 1	
		return { request[1], Command.RET_PARAM_ERROR }
	end

	-- 加载任务列表配置
	if TaskConfig.IsEmpty() then
		TaskConfig.Load()
	end

	-- 获取玩家信息
	local player = PlayerList.GetPlayer(pid, request[3])

	-- 移除已经失效的任务
	player:RemoveInValidTask()

	-- 刷新今天的完成次数
	player:RefreshCompleteCount()

	if request[3] == 1 then
		-- 补齐任务
		player:FillUpTask()
	else	
		player:addNewTask()
	end

	-- 刷新任务
	local ret_code = player:RefreshTask(gid)

	if ret_code == Command.RET_SUCCESS then
		log.debug("refresh task success.")
		-- 更新刷新次数
		player:UpdateRefreshCount()
		-- 消耗钻石
		local n = player:DiamondCount()		
		if n ~= 0 then
			cell.sendReward(pid, nil, { {type = 41, id = 90006, value = n} }, Command.REASON_MANOR_TASK_STONE, false)
		end	

		local ret = player:GetTaskList()
		return { request[1], ret_code, ret, player:GetRefreshCount(), player:GetCompleteCount()}
	else
		log.debug("refresh task failed.")
		return { request[1], ret_code }
	end
end

local function get_task_done(pid, request)
	print('---------------------------------------------------------------- get_task_done:')
	-- 参数判断
	if type(request) ~= "table" or #request < 3 then
		return { 0, Command.RET_PARAM_ERROR }
	end
	local gid = request[2]
	if type(gid) ~= "number" then
		request[1] = request[1] or 1	
		return { request[1], Command.RET_PARAM_ERROR }
	end 

	-- 加载任务列表配置
	if TaskConfig.IsEmpty() then
		TaskConfig.Load()
	end

	-- 加载任务奖励配置
	if RewardConfig.IsEmpty() then
		RewardConfig.Load()
	end

	-- 获取玩家信息
	local player = PlayerList.GetPlayer(pid, request[3])

	-- 刷新今天的完成次数
	player:RefreshCompleteCount()

	-- 移除已经失效的任务
	player:RemoveInValidTask()

	if request[3] == 1 then
		-- 补齐任务
	--	player:FillUpTask()
	else
		player:addNewTask()
	end

	local count = player:GetCompleteCount()	
	if count >= 100 then
		log.warning("you have complete max count ...")
		return { request[1], Command.RET_ERROR }

	end
	-- 完成任务
	local ok, success_rate = player:TaskDone(gid, request[3])

	if ok then
		log.debug("complete task success.")

		-- 获得星星数
		local star_count = RewardConfig.GetStar(gid)
		player:SetStarCount(star_count)		

		-- 增加今天完成次数
		if request[3] == 1 then	
			local completeCount = player:GetCompleteCount()
			player:SetCompleteCount(completeCount + 1)
		end
		
		-- 根据成功率来获取奖励
		local uuids = player:GetUUids(gid)	
		local reward = RewardConfig.GetRewardBySuccessRate(gid, success_rate, uuids)

		-- 是否有几率升级为大成功
		local big_success = 0
		if math.random(10000) <= RewardConfig.GetBigSuccessRate(gid) then
			for i, v in ipairs(reward) do
				v.value = 2 * v.value
			end
			big_success = 1
		end
	
		-- 分发奖励
		if reward and #reward > 0 then
			cell.sendReward(pid, reward, nil, Command.REASON_MANOR_TASK_DONE, false)
		end
		 
		-- 如果今天完成次数为10次，则有一个额外奖励	(type = 41, id = 94011, value = 1)
		local completeCount2 = player:GetCompleteCount()
		if 10 == completeCount2 and request[3] == 1 then 	
			cell.sendReward(pid, { {type = 41, id = 94011, value = 1} }, nil, Command.REASON_MANOR_TASK_DONE, false)
			table.insert(reward, { type = 41, id = 94011, value = 1 })
		end

		-- 是否可获得稀有奖励
		local rare = {}
		if math.random(10000) <= RewardConfig.GetRareRewardRate(gid) then
 			rare = RewardConfig.GetRareReward(gid)
			cell.sendReward(pid, { rare, }, nil, Command.REASON_MANOR_TASK_DONE, false)	
		end

		if success_rate == 100 then
			rare = RewardConfig.GetRareReward(gid)
                        cell.sendReward(pid, { rare, }, nil, Command.REASON_MANOR_TASK_DONE, false)	
		end

		local ret = player:GetTaskList()
		local reward_ret = {}
		for _, v in ipairs(reward) do
			table.insert(reward_ret, { v.type, v.id, v.value })
		end

		--quest
		cell.NotifyQuestEvent(pid, {{type = 54, id = 1, count = 1}})
		if request[3] == 1 then
			return { request[1], Command.RET_SUCCESS, ret, player:GetRefreshCount(), player:GetCompleteCount() }
		else
			return { request[1], Command.RET_SUCCESS, ret, player:GetRefreshCount(), player:GetCompleteCount(), reward_ret, { rare.type, rare.id, rare.value }, big_success }
		end
	else
		log.debug("complete task failed.")
		local ret = player:GetTaskList()
		if request[3] == 1 then
			return { request[1], Command.RET_ERROR , ret, player:GetRefreshCount(), player:GetCompleteCount() }
		else
			return { request[1], Command.RET_ERROR , ret, player:GetRefreshCount(), player:GetCompleteCount(), {}, {}}
		end
	end
end
	
function get_task_term(pid, request)
	print('--------------------------------------------------------------------- get_task_term:')	
	-- 参数判断
	if type(request) ~= "table" or #request < 3 then
		return { 0, Command.RET_PARAM_ERROR }
	end
	local gid = request[2]

	-- 加载任务列表配置
	if TaskConfig.IsEmpty() then
		TaskConfig.Load()
	end

	-- 加载任务奖励配置
	if RewardConfig.IsEmpty() then
		RewardConfig.Load()
	end

	-- 获取玩家信息
	local player = PlayerList.GetPlayer(pid, request[3])
	
	-- 移除已经失效的任务
	player:RemoveInValidTask()

	-- 刷新今天的完成次数
	player:RefreshCompleteCount()

	if request[3] == 1 then
		-- 补齐任务
	--	player:FillUpTask()
	else
		player:addNewTask()
	end

	local ok = player:TermTask(gid)	
	local ret = player:GetTaskList()
	if ok then
		log.debug("Terminate the task success: ", pid, gid)	
		return { request[1], Command.RET_SUCCESS, ret, player:GetRefreshCount(), player:GetCompleteCount() }
	else
		log.debug("Terminate the task failed: ", pid, gid)	
		return { request[1], Command.RET_ERROR, ret, player:GetRefreshCount(), player:GetCompleteCount() }
	end
end

function get_task_early_done(pid, request)
	print('-------------------------------------------------------------- get_task_early_done:')
	-- 参数判断
	if type(request) ~= "table" or #request < 3 then
		return { 0, Command.RET_PARAM_ERROR }
	end
	local gid = request[2]

	-- 加载任务列表配置
	if TaskConfig.IsEmpty() then
		TaskConfig.Load()
	end

	-- 加载任务奖励配置
	if RewardConfig.IsEmpty() then
		RewardConfig.Load()
	end

	-- 获取玩家信息
	local player = PlayerList.GetPlayer(pid, request[3])
	
	-- 移除已经失效的任务
	player:RemoveInValidTask()

	-- 刷新今天的完成次数
	player:RefreshCompleteCount()

	if request[3] == 1 then
		-- 补齐任务
	--	player:FillUpTask()
	else
		log.debug("get_task_early_done, not a sgk task: ", pid, gid)
		return { request[1], Command.RET_ERROR }
	end

	local count = player:GetCompleteCount()
        if count >= 100 then
                log.warning("you have complete max count ...")
                return { request[1], Command.RET_ERROR }

        end

	local ok, success_rate = player:EndTask(gid)
	print('---------------------- success_rate = ',success_rate)
	if ok then
		log.debug("get_task_early_done, complete task success.")

		-- 获得星星数
		local star_count = RewardConfig.GetStar(gid)
		player:SetStarCount(star_count)

		-- 增加今天完成次数
		if request[3] == 1 then	
			local completeCount = player:GetCompleteCount()
			player:SetCompleteCount(completeCount + 1)
		end

		-- 根据成功率来获取奖励
		local uuids = player:GetUUids(gid)
		local reward = RewardConfig.GetRewardBySuccessRate(gid, success_rate, uuids)

		-- 是否有几率升级为大成功
		local big_success = 0
		if math.random(10000) <= RewardConfig.GetBigSuccessRate(gid) then
			for i, v in ipairs(reward) do
				v.value = 2 * v.value
			end
			big_success = 1
		end
	
		-- 分发奖励
		if reward and #reward > 0 then
			cell.sendReward(pid, reward, nil, Command.REASON_MANOR_TASK_DONE, false)
		end
		 
		-- 如果今天完成次数为10次，则有一个额外奖励	(type = 41, id = 94011, value = 1)
		local completeCount2 = player:GetCompleteCount()
		if 10 == completeCount2 and request[3] == 1 then 	
			cell.sendReward(pid, { {type = 41, id = 94011, value = 1} }, nil, Command.REASON_MANOR_TASK_DONE, false)
			table.insert(reward, { type = 41, id = 94011, value = 1 })
		end

		-- 是否可获得稀有奖励
		local rare = {}
		if math.random(10000) <= RewardConfig.GetRareRewardRate(gid) then
 			rare = RewardConfig.GetRareReward(gid)
			cell.sendReward(pid, { rare, }, nil, Command.REASON_MANOR_TASK_DONE, false)	
		end

		if success_rate >= 100 then
			print('----------------------恭喜你，获得了额外奖励...')
                        rare = RewardConfig.GetRareReward(gid)
                        cell.sendReward(pid, { rare, }, nil, Command.REASON_MANOR_TASK_DONE, false)
                end

		local ret = player:GetTaskList()
		local reward_ret = {}
		for _, v in ipairs(reward) do
			table.insert(reward_ret, { v.type, v.id, v.value })
		end
		
		--quest
		cell.NotifyQuestEvent(pid, {{type = 54, id = 1, count = 1}})
		if request[3] == 1 then
			return { request[1], Command.RET_SUCCESS, ret, player:GetRefreshCount(), player:GetCompleteCount()}
		else
			return { request[1], Command.RET_SUCCESS, ret, player:GetRefreshCount(), player:GetCompleteCount(), reward_ret, { rare.type, rare.id, rare.value }, big_success }
		end
	else
		log.debug("get_task_early_done, complete task failed.")
		local ret = player:GetTaskList()
		if request[3] == 1 then
			return { request[1], Command.RET_SUCCESS, ret, player:GetRefreshCount(), player:GetCompleteCount() }
		else
			return { request[1], Command.RET_ERROR , ret, player:GetRefreshCount(), player:GetCompleteCount(), {}, {}}
		end
	end
end

function get_task_star_reward_info(pid, request)
	local sn = request[1]
        local _type = request[2]
	
	print('------------------------------------------------------------------------------- get_task_star_reward_info:',_type)
	if type(_type) ~= "number" then
                log.warning('param is erro...')
                return { sn, Command.RET_PARAM_ERROR }
        end

        local player = PlayerList.GetPlayer(pid, _type)
	local flags = {}
	for i = 1,4,1 do
		print('------------------ i = '..i)
		local flag = getStarboxReward(pid,i) or 0
		print('*****************************',flag)
		table.insert(flags,flag)
	end	
	print('-----------player:GetStarCount() = '..player:GetStarCount())	
	return { request[1], Command.RET_SUCCESS,player:GetStarCount(),flags}

end

function get_task_star_reward(pid, request)
	local sn = request[1]	
	local gid = request[2]
	local _type = request[3]

	print('-------------------------------------------------------------------------------- get_task_star_reward:',gid,_type)
	if type(_type) ~= "number" and type(gid) ~= "number" then
		log.warning('param is erro...')
                return { sn, Command.RET_PARAM_ERROR }
        end

        local player = PlayerList.GetPlayer(pid, _type)
	
	local flag,db_in = getStarboxReward(pid,gid)
	if flag == 1 then
		log.warning("you have acquire reward...")
                return { sn,Command.RET_ERROR }
	end

	local star_reward = StarRewardConfig.GetReward(gid)
	local rewards = StarRewardContent(star_reward)

	if Exchange(pid,rewards,nil,Command.REASON_MANOR_STARBOX_REWARD) and StarboxReward.Update(pid,gid,1,db_in) then
		StarboxReward[pid][gid]	= 1
	
		local flags = {}
        	for i = 1,4,1 do
                	local flag = getStarboxReward(pid,i) or 0
                	print('*****************************',flag)
                	table.insert(flags,flag)
        	end
		return { sn,Command.RET_SUCCESS,player:GetStarCount(),flags}
	else
		log.warning('you have an error for rewarding ...')
		return { sn,Command.RET_ERROR }
	end	
end

function get_task_refresh_all_tasks(pid,request)
	local sn = request[1]
        local _type = request[2]

	print('--------------------------------------------------------------------------------- get_task_refresh_all_tasks:')

	if type(_type) ~= "number" then
                log.warning('param is erro...')
                return { sn, Command.RET_PARAM_ERROR }
        end
	
	-- 消耗刷新卡
	if not Exchange(pid,nil,{{type = 41, id = 90020,value = 1}},Command.REASON_MANOR_TASK_STONE) then
		print('---------消耗失败...')
		return { sn,Command.RET_ERROR }
	end

	local player = PlayerList.GetPlayer(pid, _type)
	--player:RemoveInValidTask()
        player:RefreshCompleteCount()

	for _, v in ipairs(player.task_list or {}) do
        	if PlayerTask.ResetTaskInfo(pid, v.gid) then
			ClearTask(v)
                end
        end

	player:FillUpTask()
	player:UpdateRefreshCount()
	
	local ret = player:GetTaskList()
	local ret = player:GetTaskList()
	
	local ret = player:GetTaskList()
	for _,v in ipairs(ret) do

		print('--- v = ',v[1],v[2],v[3])
	end
        return { sn, Command.RET_SUCCESS, ret, player:GetRefreshCount(), player:GetCompleteCount() }
end

return {
	get_task_respond = get_task_respond,
	get_task_todo = get_task_todo,
	get_task_refresh = get_task_refresh,
	get_task_done = get_task_done,
	get_task_early_done = get_task_early_done,
	get_task_term = get_task_term,

	get_task_star_reward_info = get_task_star_reward_info,
	get_task_star_reward = get_task_star_reward,
	get_task_refresh_all_tasks = get_task_refresh_all_tasks,
}
