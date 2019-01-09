local Command = require "Command"
local cell = require "cell"
local Scheduler = require "Scheduler"
local Agent = require "Agent"
local bit32 = require "bit32"

require "MailReward"
require "FishDB"
require "FishConfig"
require "TeamProxy"

math.randomseed(os.time())

local MAX_PLAYER_COUNT = 5	-- 组队玩家的最大人数

local FishStatus = {		-- 垂钓状态
	Nothing = 0,		-- 什么也没做	
	Status = 1,		-- 甩杆
	Status2 = 2,		-- 收杆
}

local PlayerStatus = {		
	Normal = 0,		-- 正常钓鱼
	Hanging = 1, 		-- 挂机
	Quit = 2,		-- 离开
}

-- 队伍信息
local TeamManager = { map = {} }
local Team = {}
-- 玩家信息
local PlayerManager = { map = {} }
local Player = {}
-- 玩家钓鱼记录
local FishRecordManager = { map = {} }

-------------------------- auxiliary function ---------------------------
local ORIGIN_TIME = 1506873600	 		-- 2017-10-01 0:0:0

-- 当天的截止时间
local function dead_time()
	local INTEVAL = 24 * 3600
	local n = math.floor((loop.now() - ORIGIN_TIME) / INTEVAL)
	return ORIGIN_TIME + (n + 1) * INTEVAL 
end

-- 当前时间是否是周一0点
local function is_zero_time(now)
	local INTEVAL = 24 * 3600 * 7
	if (now - ORIGIN_TIME) % INTEVAL == 0 then
		return true
	end
	return false
end

Scheduler.Register(function (now)
	if is_zero_time(now) then
		log.info("now is zero time.")
		local pid_list = PlayerManager.GetRankList()
		-- 发放钓鱼奖励（以邮件的方式发放）
		for i, pid in ipairs(pid_list) do
			local reward = get_rank_reward(i)
			if reward then
				local player = PlayerManager.GetPlayer(pid)
				local n = player and player:GetPoints() or 0
				send_reward_by_mail(pid_list[i], "钓鱼排名奖励", string.format("钓鱼排名%d，请查收奖励~", i), reward)
			else
				log.warning("send reward by mail: reward not exist, rank is ", i)
			end
		end
		-- 清除钓鱼积分
		PlayerManager.ClearPoints()
	end
end)

------------------------------------------- team ----------------------------------------
function Team.New(o)
	o = o or {}
	return setmetatable(o, {__index = Team})
end

-- 将玩家pid踢出 
function Team:Kick(pid)
	for i = 1, MAX_PLAYER_COUNT do
		if self["pid" .. i] == pid then
			self["pid" .. i] = 0
			return
		end
	end
end

function Team:GetPlayerCount()
	local n = 0

	for i = 1, MAX_PLAYER_COUNT do
		if self["pid" .. i] ~= 0 then
			n = n + 1
		end
	end

	return n
end

-- 获得玩家在bit中的位置
function Team:GetIndex(pid)
	assert(pid)
	for i = 1, MAX_PLAYER_COUNT do
		if self["pid" .. i] == pid and pid ~= 0 then
			return i
		end
	end

	return 0
end

-- 除了accept以外，每人可获得一份奖励
function Team:SendReward(reward, accept)
	assert(reward)
	assert(accept)

	for i = 1, MAX_PLAYER_COUNT do
		if self["pid" .. i] ~= accept and self["pid" .. i] ~= 0 then
			local respond = cell.sendReward(self["pid" .. i], reward, nil, Command.REASON_FISH_HELP_REWARD)
			if not respond or respond.result ~= Command.RET_SUCCESS then
				log.warning("In_Team_SendReward: send reward failed, pid is ", self["pid" .. i])
			end
		end
	end
end

function Team:AddPlayer(pid)
	for i = 1, MAX_PLAYER_COUNT do
		if self["pid" .. i] == 0 then
			self["pid" .. i] = pid
			return
		end
	end
end

function Team:RemovePlayer(pid)
	for i = 1, MAX_PLAYER_COUNT do
		if self["pid" .. i] == pid then
			self["pid" .. i] = 0
			return
		end 
	end
end

function Team:GetPidList()	
	local ret = {}
	for i = 1, MAX_PLAYER_COUNT do
		if self["pid" .. i] ~= 0 then
			table.insert(ret, self["pid" .. i])
		end
	end

	return ret
end

------------------------------------------- team manager -------------------------------
-- 是否有队伍已经在队伍中
function TeamManager.HasTeam(t)
	if t == nil or #t == 0 then
		log.warning("In_TeamManager_HasTeam: t is nil or empty.")
		return true
	end
	for _, pid in ipairs(t) do
		local player = PlayerManager.GetPlayer(pid)
		if player.tid > 0 then
			return true
		end
	end

	return false
end

function TeamManager.IsExist(tid)
	if TeamManager.GetTeam(tid) then
		return true
	end

	return false
end

-- 创建队伍
function TeamManager.CreateTeam(tid, t)
	if t == nil or #t == 0 then
		log.warning("In_TeamManager_CreateTeam: t is nil or empty.")
		return false
	end	

	local team = {}
	for _, v in ipairs(t) do
		local player = PlayerManager.GetPlayer(v.pid)
		player:SetTid(tid)
		FishPlayerDB.SyncData(player)
	end
	team.tid = tid
	team.pid1 = t[1] and t[1].pid or 0
	team.pid2 = t[2] and t[2].pid or 0
	team.pid3 = t[3] and t[3].pid or 0
	team.pid4 = t[4] and t[4].pid or 0
	team.pid5 = t[5] and t[5].pid or 0
	team.fight_id = 0 
	team.is_db = false

	if FishTeamDB.SyncData(team) then
		TeamManager.map[tid] = Team.New(team)
		return true
	end

	return false
end

function TeamManager.GetTeam(tid)
	if TeamManager.map[tid] == nil then
		local team = FishTeamDB.Select(tid)
		if team then	
			TeamManager.map[tid] = Team.New(team)
		end
	end
	return TeamManager.map[tid]
end

function TeamManager.GetTeamInfo(tid)
	local team = TeamManager.GetTeam(tid)
	if team == nil then
		log.warning("In_TeamManager_GetTeamInfo: team is nil, tid = ", tid)
		return nil
	end
	local ret = {}
	for i = 1, MAX_PLAYER_COUNT do
		local pid = team["pid" .. i]
		if pid > 0 then
			local player = PlayerManager.GetPlayer(pid)
			table.insert(ret, { player.pid, player.status, player:GetFishStatus(), FishRecordManager.GetRecordInfo(pid, tid) })
		end
	end

	return ret
end

function TeamManager.Remove(tid)
	TeamManager.map[tid] = nil
end

function TeamManager.GetAllTeam()
	local ret = {}

	for tid, v in pairs(TeamManager.map) do
		local member = {}
		if v.pid1 ~= 0 then table.insert(member, v.pid1) end
		if v.pid2 ~= 0 then table.insert(member, v.pid2) end
		if v.pid3 ~= 0 then table.insert(member, v.pid3) end
		if v.pid4 ~= 0 then table.insert(member, v.pid4) end
		if v.pid5 ~= 0 then table.insert(member, v.pid5) end

		local team = getTeam(tid)
		table.insert(ret, { tid, team and team.leader.pid or 0, member })
	end
	
	return ret
end

------------------------------------------- player --------------------------------------
function Player.New(o)
	return setmetatable(o, {__index = Player})	
end

function Player:SetTid(tid)
	if type(tid) ~= "number" then
		log.warning("In_Player_SetTid: tid is not a number.")
		return
	end

	self.tid = tid
end

function Player:GetFishStatus()
	return self.fish_status
end

function Player:UpdateFishStatus(status)
	if type(status) ~= "number" then
		log.warning("In_Player_UpdateFishStatus: status is not a number.")
		return
	end
	self.fish_status = status
end

function Player:GetFishTime()
	return self.fish_time
end

function Player:UpdateFishTime(time)
	if type(time) ~= "number" then
		log.warning("In_Player_UpdateFishTime: time is not a number.")
		return
	end
	self.fish_time = time
end

function Player:GetPoints()
	return self.points
end

function Player:UpdatePoints(n)
	if type(n) ~= "number" then
		log.warning("In_Player_UpdatePoints: n is not a number.")
		return
	end
	self.points = n
end

function Player:SetAssistBit(i)
	if i <= 0 then 
		log.warning("In_Player_SetAssistBit: i is 0.")
		return 
	end	

	local n = bit32.lshift(1, i - 1)
	self.assist_bit = bit32.bor(self.assist_bit, n)
end

function Player:GetAssistBit(i)
	if i <= 0 then return 0 end

	local n = bit32.lshift(1, i - 1)
	if bit32.band(self.assist_bit, n) > 0 then
		return 1
	else
		return 0
	end
end

function Player:GetAssistCount()
	local n = 0
	for i = 1, 5 do 
		if self:GetAssistBit(i) > 0 then
			n = n + 1
		end	
	end
	return n
end

------------------------------------------- player manager ------------------------------
function PlayerManager.GetPlayer(pid)
	if not PlayerManager.map[pid] then
		local player = FishPlayerDB.Select(pid)
		if not player then
			player = { pid = pid, tid = 0, fish_status = 0, fish_time = 0, fish_back_time = 0, points = 0, assist_bit = 0, status = 0, power = 0, th = 0, nsec = 0, is_db = false }
		end
		PlayerManager.map[pid] = Player.New(player)
	end

	return PlayerManager.map[pid]
end

function PlayerManager.ClearPoints()
	for pid, player in pairs(PlayerManager.map) do
		player:UpdatePoints(0)
		FishPlayerDB.SyncData(player)
	end
end

-- 根据钓鱼积分进行排序
function PlayerManager.GetRankList()
	local pid_list = {}
	for pid, _ in pairs(PlayerManager.map) do
		table.insert(pid_list, pid)
	end

	-- 排序
	table.sort(pid_list, function (i, j)
        	local player1 = PlayerManager.GetPlayer(i)
        	local player2 = PlayerManager.GetPlayer(j)
        	return player1.points > player2.points
        end)
	return pid_list
end

----------------------- fish record manager -------------
function FishRecordManager.GetRecord(pid)
	assert(pid)
	if FishRecordManager.map[pid] == nil then
		FishRecordManager.map[pid] = FishRecordDB.Select(pid) or {}
	end

	return FishRecordManager.map[pid]
end

function FishRecordManager.GetRecordInfo(pid, tid)
	assert(pid)
	local list = FishRecordManager.GetRecord(pid)
	local ret = {}
	for i, v in ipairs(list) do
		if v.tid == tid then
			table.insert(ret, { v.type, v.id, v.value, v.order })
		end
	end
	return ret
end

function FishRecordManager.AddFishRecord(pid, fish, tid)
	local list = FishRecordManager.GetRecord(pid)

	local info = { pid = pid, order = #list + 1, type = fish.type, id = fish.id, value = fish.value, tid = tid, time = loop.now(), is_db = false }
	if FishRecordDB.SyncData(info) then
		table.insert(list, info)
	end
end

function FishRecordManager.Remove(pid)
	if FishRecordDB.Delete(pid) then
		FishRecordManager.map[pid] = {}
	end
end

----------------------- notify -------------------------
local function Notify(cmd, pid, msg)
	local agent = Agent.Get(pid);
	if agent then
		agent:Notify({cmd, msg});
	end
end

-- 踢人或者转让队长头衔（pid是目标，1代表踢人，2代表转让队长头衔）
local function NotifyKick(tid, pid, type)
	log.debug("In_NotifyKick: tid, pid, type = ", tid, pid, type)
	local team = TeamManager.GetTeam(tid)
	local cmd = Command.NOTIFY_KICK
	if not team then
		log.warning(string.format("In_NotifyKick: team %d is nil.", tid))
		return
	end

	for i = 1, MAX_PLAYER_COUNT do
		if team["pid" .. i]  ~= 0 then
			Notify(cmd, team["pid" .. i], { type, pid })
		end
	end
end

-- 通知玩家已经被邀请加入某个小队(pid1是邀请人，pid2是被邀请人, type是1代表强制邀请，2代表非强制邀请)
local function NotifyInvite(pid1, pid2, tid, type)
	log.debug("In_NotifyInvite: pid1, pid2, tid, type = ", pid1, pid2, tid, type)
	local cmd = Command.NOTIFY_INVITE
	Notify(cmd, pid2, { tid, pid1, type })
end

-- 通知小队玩家，有一个新玩家加入
local function NotifyMember(tid, obj_id)
	log.debug("In_NotifyMember: tid = ", tid)
	local cmd = Command.NOTIFY_JOIN
	local team = TeamManager.GetTeam(tid)
	if not team then
		log.warning(string.format("In_NotifyMember: team %d is nil.", tid))
		return
	end
	for i = 1, MAX_PLAYER_COUNT do
		local pid = team["pid" .. i]
		if pid ~= 0 then
			Notify(cmd, pid, { obj_id })
		end
	end
end

-- 通知其他玩家，自己钓到什么鱼
local function NotifyFish(tid, pid, fish, is_help)
	log.debug("In_NotifyFish: tid, pid, fish id, is_help = ", tid, pid, fish.id, is_help)
	local cmd = Command.NOTIFY_FISH
	local team = TeamManager.GetTeam(tid)
	if not team then
		log.warning(string.format("In_NotifyFish: team %d is nil.", tid))
		return
	end
	for i = 1, MAX_PLAYER_COUNT do
		if team["pid" .. i] ~= 0 then
			Notify(cmd, team["pid" .. i], { pid, fish.type, fish.id, fish.value, is_help })
		end
	end
end

-- 通知玩家协助(pid1是协助者，pid2是被协助者)
local function NotifyAssist(tid, pid1, pid2, n)
	log.debug("In_NotifyAssist: tid, pid1, pid2, n = ", tid, pid1, pid2, n)
	local cmd = Command.NOTIFY_ASSIST
	local team = TeamManager.GetTeam(tid)
	if not team then
		log.warning(string.format("In_NotifyFish: team %d is nil.", tid))
		return
	end
	for i = 1, MAX_PLAYER_COUNT do
		if team["pid" .. i] ~= 0 then
			Notify(cmd, team["pid" .. i], { pid1, pid2, n })
		end
	end
end

-- 通知玩家状态（正常钓鱼，挂机，停止钓鱼）
local function NotifyPlayerStatusChanged(tid, pid, status)
	log.debug("In_NotifyPlayerStatusChanged: tid, pid, status = ", tid, pid, status)
	local team = TeamManager.GetTeam(tid)
	local cmd = Command.NOTIFY_PLAYER_STATUS 
	if not team then
		log.warning(string.format("In_NotifyPlayerStatusChanged: team %d in nil.", tid))
		return
	end
	for i = 1, MAX_PLAYER_COUNT do
		if team["pid" .. i] ~= 0 then
			Notify(cmd, team["pid" .. i], { pid, status })
		end
	end
end

-- 通知玩家触发战斗
local function NotifyFight(tid, pid, fight_id)
	log.debug("In_NotifyFight: tid, pid, fight_id = ", tid, pid, fight_id)
	local team = TeamManager.GetTeam(tid)
	local cmd = Command.NOTIFY_FIGHT
	if not team then
		log.warning(string.format("In_NotifyFight: team %d is nil.", tid))
		return
	end
	for i = 1, MAX_PLAYER_COUNT do
		if team["pid" .. i] ~= 0 then
			Notify(cmd, team["pid" .. i], { fight_id })
		end
	end
end

-- 通知玩家退出
local function NotifyQuit(tid, pid)
	log.debug("In_NotifyQuit: tid, pid = ", tid, pid)
	local team = TeamManager.GetTeam(tid)
	local cmd = Command.NOTIFY_PLAYER_QUIT
	if not team then
		log.warning(string.format("In_NotifyQuit: team %d is nil.", tid))
		return
	end
	for i = 1, MAX_PLAYER_COUNT do
		if team["pid" .. i] ~= 0 then
			Notify(cmd, team["pid" .. i], { pid })
		end
	end
end

-- 通知某人需要协助
local function NotifyHelp(tid, pid, fish)
	log.debug("In_NotifyHelp: tid, pid, fish id is  = ", tid, pid, fish.id)	
	local team = TeamManager.GetTeam(tid)
	local cmd = Command.NOTIFY_NEED_HELP 
	if not team then
		log.warning(string.format("In_NotifyHelp: team %d is nil.", tid))
		return
	end
	for i = 1, MAX_PLAYER_COUNT do
		if team["pid" .. i] ~= 0 then
			Notify(cmd, team["pid" .. i], { pid, fish.type, fish.id, fish.value })
		end
	end
end

-- 通知组队成功
local function NotifyMakeTeam(tid, leader)
	log.debug("In_NotifyMakeTeam: tid = ", tid)
	local cmd = Command.NOTIFY_MAKE_TEAM 
	local team = TeamManager.GetTeam(tid)
	if not team then
		log.warning(string.format("In_NotifyMakeTeam: team %d is nil.", tid))
		return
	end
	local list = team:GetPidList()
	for i = 1, MAX_PLAYER_COUNT do
		Notify(cmd, team["pid" .. i], { leader, list })
	end
end

-- 16231 16232
----------------------------------- request handler  ------------------------------------
local function make_team(conn, pid, request)
	local cmd = Command.C_FISH_MAKE_TEAM_RESPOND

	log.debug(string.format("cmd: %d, pid is %d.", cmd, pid))	

	-- 参数检测
	if type(request) ~= "table" or #request < 1 then
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1] or 0
	
	-- team 是否存在
	local team = getTeamByPlayer(pid, true)
	if not team or team.id == 0 then
		log.warning(string.format("cmd: %d, team not exist, pid is %d.", cmd, pid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })		
	end

	-- 检测是否存在这样的钓鱼房间	
	if TeamManager.IsExist(team.id) then
		log.warning(string.format("cmd: %d, there is a team %d exist.", cmd, team.id))
		log.debug(sprinttb(team_list))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_EXIST })
	end

	-- 创建队伍
	if not TeamManager.CreateTeam(team.id, team.members) then
		log.warning(string.format("cmd: %d, create team failed, list is ", cmd))
		log.debug(sprinttb(team_list))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end

	local player = PlayerManager.GetPlayer(pid)
	NotifyMakeTeam(player.tid, team.leader.pid)

	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
end 

-- 16233 16234
local function get_team_info(conn, pid, request)
	local cmd = Command.C_FISH_TEAM_INFO_RESPOND
	log.debug(string.format("cmd: %d, pid is %d.", cmd, pid))	

	-- 参数检测
	if type(request) ~= "table" or #request < 1 then
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]

	local player = PlayerManager.GetPlayer(pid)	
	local tid = request[2] or player.tid
	
	-- 队伍是否存在	
	local team = TeamManager.GetTeam(tid)
	if team == nil then
		log.info(string.format("cmd: %d, team is nil, tid = %d", cmd, tid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
	end

	-- leader id
	local teamInfo = getTeam(tid)
	local leader_id = teamInfo and teamInfo.leader.pid or 0

	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, leader_id, TeamManager.GetTeamInfo(tid) })
end

-- 16235 16236
local function team_change(conn, pid, request)
	local cmd = Command.C_FISH_TEAM_LEADER_RESPOND
	log.debug(string.format("cmd: %d, pid is %d.", cmd, pid))	
	
	-- 参数检测
	if type(request) ~= "table" or #request < 3 then
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]
	local purpose = request[2]
	local obj_id = request[3]
	
	-- 判断目标是否与队长属于同队
	local player = PlayerManager.GetPlayer(pid)
	local player2 = PlayerManager.GetPlayer(obj_id)
	if player.tid ~= player2.tid then
		log.warning(string.format("cmd: %d, %d and %d is not in same team.", cmd, pid, obj_id))	
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_TARGET_NOT_EXIST })	
	end

	-- 房间是否存在
	local team = TeamManager.GetTeam(player.tid)
	if not team then
		log.warning(string.format("cmd: %d, team not exist, tid is %d. ", cmd, player.tid))			
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })		
	end

	if purpose == 1 then			-- 踢人				
		player2:SetTid(0)
		player2.status = PlayerStatus.Normal
		FishPlayerDB.SyncData(player2)
		team:Kick(obj_id)			
		FishTeamDB.SyncData(team)	
	end

	NotifyKick(team.tid, obj_id, purpose)	
	
	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS }) 
end

-- 16237 16238
local function invite(conn, pid, request)
	local cmd = Command.C_INVITE_PLAYER_RESPOND
	log.debug(string.format("cmd: %d, pid is %d.", cmd, pid))	

	-- 参数检测
	if type(request) ~= "table" or #request < 3 then
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]
	local obj_id = request[2]
	local force = request[3]

	-- 邀请人是否在小队中
	local player = PlayerManager.GetPlayer(pid)
	if player.tid == 0 then
		log.warning(string.format("cmd: %d, player %d is not in a team, can not invite player %d.", cmd, pid, obj_id))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end

	-- 被邀请人是否已经在小队中
	local player2 = PlayerManager.GetPlayer(obj_id)
	if player2.tid ~= 0 then
		log.warning(string.format("cmd: %d, player %d has been in a team.", cmd, obj_id))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end

	-- 小队人数是否已满
	local team = TeamManager.GetTeam(player.tid)
	if not team or team:GetPlayerCount() >= MAX_PLAYER_COUNT then
		log.warning(string.format("cmd: %d, team member is full.", cmd))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_DEPEND })
	end

	if force == 1 then 		-- 强制邀请玩家
		NotifyMember(player.tid, obj_id)
		player2:SetTid(player.tid)
		FishPlayerDB.SyncData(player2)
		team:AddPlayer(player2.pid)
		FishTeamDB.SyncData(team)	
	end	
	NotifyInvite(pid, obj_id, team.tid, force)

	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
end

local function answer_invite(conn, pid, request)
	local cmd = Command.C_INVITATION_ANSWER_RESPOND
	log.debug(string.format("cmd: %d, pid is %d.", cmd, pid))	

	-- 参数检测
	if type(request) ~= "table" or #request < 3 then
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]
	local tid = request[2]		-- 加入的队伍id
	local accept = request[3]

	-- 如果不接受
	if accept ~= 1 then
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, 2 } )
	end

	-- 玩家是否已经在小队中了
	local player = PlayerManager.GetPlayer(pid)
	if player.tid ~= 0 then
		log.warning(string.format("cmd: %d, player %d has been in a team.", cmd, pid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR, 2 })
	end

	-- 小队中的成员是否已满
	local team = TeamManager.GetTeam(tid)
	if not team then
		log.warning(string.format("cmd: %d, team %d is not exist.", cmd, tid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST, 2 })
	end

	-- 房间是否已满
	if team:GetPlayerCount() >= MAX_PLAYER_COUNT then
		log.warning(string.format("cmd: %d, team %d is full.", cmd, tid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_FULL, 2 })
	end

	-- 加入房间
	player:SetTid(tid)
	FishPlayerDB.SyncData(player)
	team:AddPlayer(pid)
	FishTeamDB.SyncData(team)

	-- 通知其他玩家
	NotifyMember(tid, pid)

	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, 1 })
end

local function begin_fish(conn, pid, request)
	local cmd = Command.C_FISH_BEGIN_RESPOND
	log.debug(string.format("cmd: %d, pid is %d.", cmd, pid))	
	
	-- 参数检测
	if type(request) ~= "table" or #request < 2 then
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]
	local power = request[2]
	local which = request[3]
 
	-- 是否玩家处于队伍中
	local player = PlayerManager.GetPlayer(pid)
	if player.tid == 0 then
		log.warning(string.format("cmd: %d, the player %d is not in a team.", cmd, pid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
	end

	-- 消耗某件道具
	local consume = {}
	if which == 1 then
		table.insert(consume, FishConsume.consume)
	elseif which == 2 then
		table.insert(consume, FishConsume.consume2)
	end
	
	local code = cell.sendReward(pid, nil, consume, Command.REASON_FISH_BAIT_CONSUME)
	if not code or code.result ~= Command.RET_SUCCESS then
		log.warning(string.format("cmd: %d, the begin fish failed, consume failed.", cmd, pid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
	end

	-- 更新钓鱼状态为甩杆
	player:UpdateFishStatus(FishStatus.Status)
	-- 记录甩杆时间
	player:UpdateFishTime(loop.now())
	-- 记录甩杆力度
	player.power = power
	player.assist_bit = 0
	player.th = 0
	-- 记录收杆需要的秒数
	player.nsec = math.random(FishConsume.gofish_time_min, FishConsume.gofish_time_max)

	FishPlayerDB.SyncData(player)	

	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, player.nsec })
end

-- 16245 16246
local function end_fish(conn, pid, request)
	local cmd = Command.C_FISH_END_RESPOND
	log.debug(string.format("cmd: %d, pid is %d.", cmd, pid))	
	
	-- 参数检测
	if type(request) ~= "table" or #request < 1 then
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]
 
	-- 是否玩家处于队伍中
	local player = PlayerManager.GetPlayer(pid)
	if player.tid == 0 then
		log.warning(string.format("cmd: %d, the player %d is not in a team.", pid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
	end

	-- 当前状态是否处于甩杆
	if player:GetFishStatus() ~= FishStatus.Status then
		log.warning(string.format("cmd: %d, the player %d fish status is not %d, current status is %d.", cmd, pid, FishStatus.Status, player:GetFishStatus()))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_DEPEND })
	end

	-- 是否可以收杆
	if loop.now() < player:GetFishTime() + player.nsec then
		log.info(string.format("cmd: %d, the player %d fish back time not enough, need wait %d seconds.", cmd, pid, player:GetFishTime() + player.nsec - loop.now()))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_COOLDOWN })	
	end
	
	-- 是否处于有效的收杆时间
	if loop.now() > player:GetFishTime() + player.nsec + FishConsume.effective_time then
		log.info(string.format("cmd: %d, the fish is gone, now is %d, begin_fish is %d, nsec is %d, effective_time is %d", 
			cmd, loop.now(), player:GetFishTime(), player.nsec, FishConsume.effective_time))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
	end  
 
	-- 从钓鱼池中随机一条鱼
	local fish, th = FishConfig.RandomFish(player.power)
	if not fish then
		log.warning(string.format("cmd: %d, fish is nil, power is %d.", cmd, player.power))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end
			
 	player:UpdateFishStatus(FishStatus.Status2)
	player.fish_back_time = loop.now()
	player.begin_fish = 0
	player.nsec = 0

	if fish.is_help == 0 then				
		player:UpdatePoints(player:GetPoints() + 1)
		FishRecordManager.AddFishRecord(pid, fish.reward, player.tid)
		player:UpdateFishStatus(FishStatus.Nothing)
		NotifyFish(player.tid, pid, fish.reward, fish.is_help)
		player.power = 0
		player.fish_back_time = 0
		local code = cell.sendReward(pid, { fish.reward }, nil, Command.REASON_FISH_REWARD)
		if not code or code.result ~= 0 then
			log.warning(string.format("cmd: %d, send reward failed.", cmd))	
		end
	elseif fish.is_help == 1 then
		player.th = th	
	else	
		player.th = th	
		NotifyHelp(player.tid, player.pid, fish.reward)
	end
	
	FishPlayerDB.SyncData(player)

	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, fish.is_help, { fish.reward.type, fish.reward.id, fish.reward.value } })
end

-- 16257 16258
local function qte_check(conn, pid, request)
	local cmd = Command.C_QTE_CHECK_RESPOND
	log.debug(string.format("cmd: %d, pid is %d.", cmd, pid))	

	-- 参数检测
	if type(request) ~= "table" or #request < 2 then
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]
	local right = request[2]

	-- 玩家是否处于队伍中
	local player = PlayerManager.GetPlayer(pid)
	if player.tid == 0 then
		log.warning(string.format("cmd: %d, player %d is not in a team.", cmd, pid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end

	-- 玩家是否是收杆状态
	if player:GetFishStatus() ~= FishStatus.Status2 then
		log.warning(string.format("cmd: %d, player %d status is not %d.", cmd, pid, FishStatus.Status2))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end

	-- config
	local config = FishConfig[player.power][player.th]
	if not config then
		log.warning(string.format("cmd: %d, config is not exist, power = %d, th = %d.", cmd, player.power, player.th))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end

	-- 是否是qte操作
	if config.is_help ~= 1 then
		log.warning(string.format("cmd: %d, there is not a qte, pid is %d.", cmd, pid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end

	-- qte操作是否处于时间范围
	if loop.now() > player.fish_back_time + FishConsume.qtefish_time then
		log.warning(string.format("cmd: %d, qte out of range, fish_back_time is %d, now is %d.", cmd, player.fish_back_time, loop.now()))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_DEPEND })
	end

	if right == 1 then
		player:UpdatePoints(player:GetPoints() + 1)
		FishRecordManager.AddFishRecord(pid, config.reward, player.tid)
		NotifyFish(player.tid, pid, config.reward, config.is_help)
		local code = cell.sendReward(pid, { config.reward } , nil, Command.REASON_FISH_REWARD)
		if not code or code.result ~= 0 then
			log.warning(string.format("cmd: %d, send reward failed.", cmd))	
		end
	end
	player.fish_back_time = 0
	player.power = 0
	player:UpdateFishStatus(FishStatus.Nothing)
	player.assist_bit = 0
	player.th = 0

	FishPlayerDB.SyncData(player)

	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, right })
end

local function assist(conn, pid, request)
	local cmd = Command.C_FISH_ASSIST_RESPOND
	log.debug(string.format("cmd: %d, pid is %d.", cmd, pid))	

	-- 参数检测
	if type(request) ~= "table" or #request < 2 then	
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]
	local assist_pid = request[2]

	-- 检测两者是否是同一队
	local player = PlayerManager.GetPlayer(pid)
	local player2 = PlayerManager.GetPlayer(assist_pid)	
	if player.tid == 0 or player2.tid == 0 then
		log.warning(string.format("cmd: %d, team not exist, pid1 = %d, tid1 = %d, pid2 = %d, tid2 = %d", cmd, player.pid, player.tid, player2.pid, player2.tid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
	end
	if player.tid ~= player2.tid then
		log.warning(string.format("cmd: %d, %d and %d not in a team.", cmd, player.pid, player2.pid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_DEPEND })	
	end	
		
	-- 获取队伍信息
	local team = TeamManager.GetTeam(player.tid)
	if not team then
		log.warning(string.format("cmd: %d, team not exist.", player.tid))	
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })	
	end
	
	-- config
	local config = FishConfig[player2.power][player2.th]
	if not config then
		log.warning(string.format("cmd: %d, config is not exist, power = %d, th = %d.", cmd, player2.power, player2.th))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end

	-- 判断是否应该是协助操作
	if config.is_help ~= 2 then
		log.warning(string.format("cmd: %d, there is not a qte, pid is %d.", cmd, pid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end

	if pid == assist_pid then		-- 遛鱼
		-- 遛鱼时间是否已经过了
		if loop.now() > player2.fish_back_time + FishConsume.walkfish_time then
			log.warning(string.format("cmd: %d, walk fish time out of range,", cmd))
			player2:UpdateFishStatus(FishStatus.Nothing)
			player2.fish_back_time = 0
			player2.power = 0
			player2.assist_bit = 0
			player2.th = 0
			FishPlayerDB.SyncData(player2)
			return conn:sendClientRespond(cmd, player2.pid, { sn, Command.RET_ERROR })
		end	
		local n = math.random(10000)
		if n <= config.probability then
			-- 触发战斗
			team.fight_id = config.fight_id
			FishTeamDB.SyncData(team)
			return conn:sendClientRespond(cmd, player2.pid, { sn, Command.RET_SUCCESS, team.fight_id })
		else
			local code = cell.sendReward(pid, { config.reward } , nil, Command.REASON_FISH_REWARD)
			if not code or code.result ~= 0 then
				log.warning(string.format("cmd: %d, send reward failed.", cmd))	
			end

			FishRecordManager.AddFishRecord(pid, config.reward, player.tid)
			-- 通知其他玩家钓到的鱼是什么
			NotifyFish(player2.tid, player2.pid, config.reward, config.is_help)
			player2:UpdateFishStatus(FishStatus.Nothing)
			player2.fish_back_time = 0
			player2.power = 0
			player2:UpdatePoints(player2:GetPoints() + 1)
			player2.assist_bit = 0
			player2.th = 0
			FishPlayerDB.SyncData(player2)
		end
	else							-- 协助	
		-- 协助时间是否已过
		if loop.now() > player2.fish_back_time + FishConsume.helpfish_time then
			log.warning(string.format("cmd: %d, help time out of range.", cmd))
			-- 协助失败	
			player2:UpdateFishStatus(FishStatus.Nothing)
			player2.fish_back_time = 0
			player2.assist_bit = 0
			player2.power = 0
			player2.th = 0
			FishPlayerDB.SyncData(player2)
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
		end
		local index = team:GetIndex(pid)
		player2:SetAssistBit(index)
		-- 通知玩家已经协助
		NotifyAssist(player2.tid, pid, player2.pid, player2:GetAssistCount())

		if player2:GetAssistCount() == team:GetPlayerCount() - 1 then	-- 所有小队成员都已经协助
			local n = math.random(10000)
			if n <= config.probability then 		-- 概率触发战斗
				-- 记录当前队伍进入战斗的战斗id
				team.fight_id = config.fight_id
				FishTeamDB.SyncData(team)
				-- 通知玩家触发战斗
				NotifyFight(player.tid, pid, team.fight_id)
				return conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, team.fight_id })
			else 									-- 获得奖励 
				-- 协助者奖励
				team:SendReward(config.reward2, assist_pid)
				-- 玩家得到鱼的奖励
				local code = cell.sendReward(player2.pid, { config.reward }, nil, Command.REASON_FISH_REWARD)
				if not code or code.result ~= 0 then
					log.warning(string.format("cmd: %d, send reward failed.", cmd))	
				end
		
				FishRecordManager.AddFishRecord(player2.pid, config.reward, player2.tid)
				NotifyFish(player2.tid, player2.pid, config.reward, config.is_help)
				player2:UpdateFishStatus(FishStatus.Nothing)
				player2.assist_bit = 0
				player2.power = 0
				player2.th = 0
				player2:UpdatePoints(player2:GetPoints() + 1)
				player2.fish_back_time = 0
				FishPlayerDB.SyncData(player2)
			end
		end 	
	end
	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
end

local function fight_check(conn, pid, request)
	local cmd = Command.C_FISH_FIGHT_CHECK_RESPOND 
	log.debug(string.format("cmd: %d, pid is %d.", cmd, pid))	
		
	-- 参数检测
	if type(request) ~= "table" or #request < 3 then	
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]
	local pid2 = request[2]
	local victory = request[3]
	
	-- 检测两者是否是同一队
	local player = PlayerManager.GetPlayer(pid)
	local player2 = PlayerManager.GetPlayer(pid2)
	if player.tid == 0 or player2.tid == 0 then
		log.warning(string.format("cmd: %d, team not exist, pid1 = %d, tid1 = %d, pid2 = %d, tid2 = %d.", cmd, player.pid, player.tid, player2.pid, player2.tid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
	end
	if player.tid ~= player2.tid then
		log.warning(string.format("cmd: %d, player %d and player %d not in same team.", cmd, player.pid, player2.pid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end

	-- 获取队伍信息
	local team = TeamManager.GetTeam(player.tid)
	if not team then
		log.warning(string.format("cmd: %d, team not exist.", player.tid))	
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })	
	end

	if team.fight_id == 0 then
		log.info(string.format("cmd: %d, team %d have end the fight.", cmd, team.tid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
	end
	
	-- config
	local config = FishConfig[player2.power][player2.th]
	if not config then
		log.warning(string.format("cmd: %d, config is not exist, power = %d, th = %d.", cmd, player2.power, player2.th))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end
	
	if victory == 1 then				-- 战斗胜利
		-- 玩家收获此鱼
		player2:UpdatePoints(player2:GetPoints() + 1)	
		local code = cell.sendReward(player2.pid, { config.reward }, nil, Command.REASON_FISH_REWARD)
		if not code or code.result ~= 0 then
			log.warning(string.format("cmd: %d, send reward failed.", cmd))	
		end

		FishRecordManager.AddFishRecord(player2.pid, config.reward, player2.tid)
		NotifyFish(player2.tid, player2.pid, config.reward, config.is_help)
		-- 协助玩家收获协助奖励 
		team:SendReward(config.reward2, pid2)		
	end		
	player2:UpdateFishStatus(FishStatus.Nothing)
	player2.assist_bit = 0
	player2.power = 0
	player2.fish_back_time = 0
	player2.th = 0
	FishPlayerDB.SyncData(player2)

	team.fight_id = 0
	FishTeamDB.Update(team)	

	return conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
end

local function get_rank(conn, pid, request)
	local cmd =  Command.C_FISH_RANK_LIST_RESPOND 	
	log.debug(string.format("cmd: %d, pid is %d.", cmd, pid))	

	-- 参数检测	
	if type(request) ~= "table" or #request < 1 then	
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]

	local rank_list = {}
 	local pid_list = PlayerManager.GetRankList()
	for i = 1, 50 do
		if pid_list[i] then
			local player = PlayerManager.GetPlayer(pid_list[i])
			table.insert(rank_list, { player.pid, player:GetPoints() })
		end
	end
	
	local player = PlayerManager.GetPlayer(pid)

	-- 获得玩家的排名
	local rank = 0
	for i, v in ipairs(pid_list) do
		if v == pid  then
			rank = i
			break
		end
	end
	
	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, rank_list, { rank, player:GetPoints() } })
end

-- 16251 16252
local function auto_fish(conn, pid, request)
	local cmd = Command.C_FISH_STATUS_RESPOND
	log.debug(string.format("cmd: %d, pid is %d.", cmd, pid))	
	
	-- 参数检测 
	if type(request) ~= "table" or #request < 2 then	
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]
	local status = request[2]

	local player = PlayerManager.GetPlayer(pid)
	if status == PlayerStatus.Normal or status == PlayerStatus.Hanging or status == PlayerStatus.Quit then
		player.status = status
		FishPlayerDB.SyncData(player)
		NotifyPlayerStatusChanged(player.tid, pid, player.status)
		conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
	else
		log.warning(string.format("cmd: %d, status is error, status is %d.", cmd, status))	
		conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end	
end

local function do_quit(pid)
	local player = PlayerManager.GetPlayer(pid)
	if player.tid == 0 then
		return 
	end
	local team = TeamManager.GetTeam(player.tid)
	if not team then
		log.warning(string.format("logout: team %d is not exist.", player.tid))
		return
	end
			
	log.debug(string.format("player %d quit team %d", pid, team.tid))

	-- 减去一个人
	player:SetTid(0)
	player:UpdateFishStatus(FishStatus.Nothing)
	player.assist_bit = 0
	player.status = PlayerStatus.Normal
	player.power = 0
	player.fish_time = 0
	player.fish_back_time = 0
	player.th = 0
	player.nsec = 0
	player.points = 0
	FishPlayerDB.SyncData(player)
	team:RemovePlayer(pid)
	FishTeamDB.SyncData(team)
	
	FishRecordManager.Remove(pid)

	NotifyQuit(team.tid, pid)

	if team:GetPlayerCount() == 0 then -- 所有人都退出了
		if FishTeamDB.Delete(team.tid) then
			TeamManager.Remove(team.tid)
		end	
	end
end

-- 16255 16256
local function quit(conn, pid, request)
	local cmd = Command.C_QUIT_RESPOND
	log.debug(string.format("cmd: %d, pid is %d.", cmd, pid))	

	-- 检测参数
	if type(request) ~= "table" or #request < 1 then	
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]

	-- 检测玩家是否在队伍中
	local player = PlayerManager.GetPlayer(pid)
	if player.tid == 0 then
		log.warning(string.format("cmd: %d, player %d not in a team.", cmd, pid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })
	end

	-- team是否存在
	local team = TeamManager.GetTeam(player.tid)
	if not team then
		log.warning(string.format("cmd: %d, team %d is nil.", cmd, player.tid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_ERROR })		
	end

	do_quit(pid)

	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
end

local function query_room(conn, pid, request)
	local cmd = Command.C_QUERY_ROOM_RESPOND
	log.debug(string.format("cmd: %d, pid is %d.", cmd, pid))
	
	-- 检测参数
	if type(request) ~= "table" or #request < 1 then	
		log.warning(string.format("cmd: %d, param error.", cmd))
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]
	
	conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, TeamManager.GetAllTeam() })	
end

---------------------------------------------- register ----------------------------------------------
local Fish = {}
function Fish.RegisterCommand(service)
	-- 组队参加钓鱼活动
	service:on(Command.C_FISH_MAKE_TEAM_REQUEST, make_team)		
	-- 获取整个团队玩家信息
	service:on(Command.C_FISH_TEAM_INFO_REQUEST, get_team_info)
	-- 队长操作
	service:on(Command.C_FISH_TEAM_LEADER_REQUEST, team_change)
	-- 邀请某人加入队伍
	service:on(Command.C_INVITE_PLAYER_REQUEST, invite)
	-- 回复邀请
	service:on(Command.C_INVITATION_ANSWER_REQUEST, answer_invite)
	-- 甩杆
	service:on(Command.C_FISH_BEGIN_REQUEST, begin_fish)
	-- 收杆
	service:on(Command.C_FISH_END_REQUEST, end_fish)
	-- 遛鱼/协助
	service:on(Command.C_FISH_ASSIST_REQUEST, assist)
	-- 战斗结束确认
	service:on(Command.C_FISH_FIGHT_CHECK_REQUEST, fight_check)
	-- 自动钓鱼或者取消自动钓鱼
	service:on(Command.C_FISH_STATUS_REQUEST, auto_fish)
	-- 获取排行榜
	service:on(Command.C_FISH_RANK_LIST_REQUEST, get_rank)
	-- 离开队伍
	service:on(Command.C_QUIT_REQUEST, quit)
	-- QTE操作确认
	service:on(Command.C_QTE_CHECK_REQUEST, qte_check)
	-- 查询所有的房间
	service:on(Command.C_QUERY_ROOM_REQUEST, query_room)
	
	service:on(Command.C_LOGOUT_REQUEST, function(conn, pid, request)
		local player = PlayerManager.map[pid]
		if not player then
			return		
		end
		if player.tid ~= 0 then
			player.status = PlayerStatus.Quit
			FishPlayerDB.SyncData(player)
			NotifyPlayerStatusChanged(player.tid, pid, player.status)
		end
	end)
end

return Fish
