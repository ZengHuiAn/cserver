require "stronghold_config"
require "defend_database"
require "Thread"
require "TeamProxy"
local TeamRewardManger = require "TeamReward"
local BinaryConfig = require "BinaryConfig"
local cell = require "cell"
local protobuf = require "protobuf"

local Command = require "Command"
local SocialManager = require "SocialManager"

local ORINGIN_TIME = 1496764800			-- 2017/6/7 0:0:0
local NSECONDS =  3600 * 24

local function deadtime()
	local n = math.floor((loop.now() - ORINGIN_TIME) / NSECONDS) + 1
	return ORINGIN_TIME + n * NSECONDS
end

local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));
		loop.exit();
		return nil;
	end
	return code;
end

local function IsAI(pid)
	if pid < 110000 then
		return true
	end

	return false
end

-- 玩家列表
local PlayerList = {}
-- 队伍列表
local TeamList = {}
-- 地图列表
local MapList = {}
-- 资源列表
local TeamResourceList = {}

-- 等级限制
local LEVEL_LIMIT = 0
local rows1 = BinaryConfig.Load("config_team_battle_config", "team")
if rows1 then
	for i, v in ipairs(rows1) do
		if v.gid_id == 3 then
			LEVEL_LIMIT = v.limit_level
			break
		end
	end
end

------------------------ 玩家类 ---------------------------------------
local Player = {}
function Player.New(pid, team_id, index)
	local old_player = PlayerTable.Select(pid)
	local box_count = 0
	local box_deadtime = deadtime()
	local exp_limit = 0
	if old_player then
		box_count = old_player.box_count
		box_deadtime = old_player.box_deadtime
		exp_limit = old_player.exp_limit
	end

	local obj = { pid = pid, box_count = box_count, box_deadtime = box_deadtime, team_id = team_id, player_index = index, collect_count = 0, 
		pitfall_time = 0, attract_time = 0, exchange_time = 0, move_time = 0, collect_time = 0, reward_id = 0, exp_limit = 0, is_stay = 20, stay_time = 0, last_index = 0 }

	PlayerTable.Insert(obj)

	return setmetatable(obj, {__index = Player})
end

function Player.New2(o)
	o = o or {}
  	return setmetatable(o, {__index = Player})
end

function Player:AddCollectCount(n)
	local ok = PlayerTable.UpdateCollectCount(self.pid, self.collect_count + n)
	if ok then
		self.collect_count = self.collect_count + n
	end
end


function Player:UpdatePosition(p)
	local ok = PlayerTable.UpdatePosition(self.pid, p)
	if ok then
		self.player_index = p
	end
end

function Player:UpdateLastIndex(index)
	local ok = PlayerTable.UpdateLastIndex(self.pid, index)
	if ok then
		self.last_index = index
	end
end

function Player:UpdateMoveTime(time)
	local ok =  PlayerTable.UpdateMoveTime(self.pid, time)
	if ok then
		self.move_time = time
	end
end

function Player:UpdateCollectTime(time)
	local ok = PlayerTable.UpdateCollectTime(self.pid, time)
	if ok then
		self.collect_time = time
	end
end

function Player:UpdatePitfallTime(time)
	local ok = PlayerTable.UpdatePitfallTime(self.pid, time)
	if ok then
		self.pitfall_time = time
	end
end

function Player:UpdateExchangeTime(time)
	local ok = PlayerTable.UpdateExchangeTime(self.pid, time)
	if ok then
		self.exchange_time = time
	end
end

function Player:UpdateAttractTime(time)
	local ok = PlayerTable.UpdateAttractTime(self.pid, time)
	if ok then
		self.attract_time = time
	end
end

function Player:UpdateRewardId(reward_id)
	local ok = PlayerTable.UpdateRewardId(self.pid, reward_id)
	if ok then
		self.reward_id = reward_id
	end
end

function Player:UpdateBoxCount(n)
	local ok = PlayerTable.UpdateBoxCount(self.pid, n)
	if ok then
		self.box_count = n
	end
end

function Player:UpdateDeadTime(time)
	local ok = PlayerTable.UpdateDeadTime(self.pid, time)
	if ok then
		self.box_deadtime = time
	end	
end

function Player:UpdateExperiment(n)
	local ok = PlayerTable.UpdateExperimentLimit(self.pid, n)
	if ok then
		self.exp_limit = n
	end
end

function Player:ResetBoxCountAndDeadTime()
	self:UpdateDeadTime(deadtime())	
	self:UpdateBoxCount(0)
	self:UpdateExperiment(0)
end


function Player:UpdateStayStatus(status)
	local ok = PlayerTable.UpdateStayStatus(self.pid, status, loop.now())		
	if ok then
		self.is_stay = status
		self.stay_time = loop.now()
	end
end

function Player:EncountBoss()
	local team = TeamList.GetTeam(self.team_id)
	local n = BossConfig.GetRandomIncident(team.boss_id)
	log.debug("EncountBoss: n = ", n)
	if n == 11 then
		local resouceList = TeamResourceList.GetResource(team.team_id)
		local id_list = {}
		for id, v in pairs(resouceList) do
			if v > 0 then
				table.insert(id_list, id)
			end
		end
		local n = math.random(5)
		local i = math.random(#id_list)
		if #id_list > 0 then
			local count = n < resouceList[id_list[i]] and n or resouceList[id_list[i]]	
			TeamResourceList.AddResourceCount(team.team_id, id_list[i], 0 - count)	
		else		
			n = 10	
		end
		self:UpdateStayStatus(11)
	elseif n == 12 then
		self:UpdateStayStatus(12)
	elseif n== 13 then
		team:UpdateBossHp(team.boss_hp - team.boss_hp * math.random(3, 5) / 100)						
		self:UpdateStayStatus(13)
	elseif n == 14 then
		self:UpdateStayStatus(14)
	end
	return n
end

------------------------- 队伍类 -------------------------------------
local Team = {}
function Team.New(pid_list, id)
	local pid1 = pid_list[1] or 0
  	local pid2 = pid_list[2] or 0
  	local pid3 = pid_list[3] or 0
  	local pid4 = pid_list[4] or 0
  	local pid5 = pid_list[5] or 0

  	-- 随机产生一个boss
	local boss_id_list = BossConfig.GetBossIdList()
	local num = math.random(#boss_id_list)
	local boss_id = boss_id_list[num]	

  	local boss = BossConfig.GetBoss(boss_id)

  	local t = { team_id = id, player_id1 = pid1, player_id2 = pid2, player_id3 = pid3, player_id4 = pid4, player_id5 = pid5, boss_id = boss_id, boss_mode = boss.mode, 
		boss_type = boss.type, boss_hp = boss.hp, boss_index = MapConfig.GetOrigin(), game_begin = loop.now(), boss_status = 0, begin_time = loop.now(), last_index = 0 }

	local ok = TeamTable.Insert(t)
	if ok then
  		return setmetatable(t, {__index = Team})
	else
		return nil
	end
end

function Team.New2(o)
	o = o or {}
  	return setmetatable(o, {__index = Team})
end

function Team:GetPlayerIdList()
	local ret = {}

	if self.player_id1 ~= 0 then table.insert(ret, self.player_id1) end
	if self.player_id2 ~= 0 then table.insert(ret, self.player_id2) end
	if self.player_id3 ~= 0 then table.insert(ret, self.player_id3) end
	if self.player_id4 ~= 0 then table.insert(ret, self.player_id4) end
	if self.player_id5 ~= 0 then table.insert(ret, self.player_id5) end

	return ret
end

function Team:UpdateBossIndex(index)
	local ok = TeamTable.UpdateBossIndex(self.team_id, index)
	if ok then
		self.boss_index = index
	end
end

function Team:UpdateBossHp(hp)
	local ok = TeamTable.UpdateBossHp(self.team_id, hp)
	if ok then
		self.boss_hp = hp
	end
end

function Team:GetBossInfo()
	return { self.boss_id, self.boss_index, self.game_begin, self.boss_status, self.begin_time, self.boss_hp, self.last_index }
end

function Team:GetPlayerInfo()
	local ret = {}

	local p1 = PlayerList.GetPlayer(self.player_id1)
	if p1 then table.insert(ret, { p1.pid, p1.player_index, p1.move_time, p1.collect_count, p1.is_stay, p1.stay_time, p1.last_index, p1.box_count }) end
  	local p2 = PlayerList.GetPlayer(self.player_id2)
	if p2 then table.insert(ret, { p2.pid, p2.player_index, p2.move_time, p2.collect_count, p2.is_stay, p2.stay_time, p2.last_index, p2.box_count }) end
  	local p3 = PlayerList.GetPlayer(self.player_id3)
	if p3 then table.insert(ret, { p3.pid, p3.player_index, p3.move_time, p3.collect_count, p3.is_stay, p3.stay_time, p3.last_index, p3.box_count }) end
  	local p4 = PlayerList.GetPlayer(self.player_id4)
	if p4 then table.insert(ret, { p4.pid, p4.player_index, p4.move_time, p4.collect_count, p4.is_stay, p4.stay_time, p4.last_index, p4.box_count }) end
  	local p5 = PlayerList.GetPlayer(self.player_id5)
	if p5 then table.insert(ret, { p5.pid, p5.player_index, p5.move_time, p5.collect_count, p5.is_stay, p5.stay_time, p5.last_index, p5.box_count }) end

	return ret
end

function Team:GetResourceInfo()
	local ret = {}

	local resource_id_list = ResourceConfig.GetResourceIdList()
	for i, _ in pairs(resource_id_list) do
		local count = TeamResourceList.GetResourceCount(self.team_id, i) 
		table.insert(ret, { i, count } )
	end

	return ret
end

function Team:GetMapInfo()
	local ret = {}

	local map = MapList.GetMap(self.team_id)
	for i, v in pairs(map) do
		local t  =  { i, v.pitfall_type, v.pitfall_level, v.attract_value, v.box_id, v.resource1_type, v.site_status, v.buff_id }
		table.insert(ret, t)
	end	

	return ret
end

function Team:IsBeyondTime()
	if loop.now() - self.game_begin >= 15 * 60 then
		return true
	end
	return false
end

-- 领取奖励
function Team:ReceiveAward()
	for _, v in pairs(self:GetPlayerIdList()) do
		local player = PlayerList.GetPlayer(v)
		if player and player.reward_id ~= 0 then
			local reward = GameRewardConfig.GetReward(player.reward_id, player.pid)
			local reward_result = cell.sendReward(v, reward, nil, Command.REASON_DEFEND_TASK_DONE, false)
			if reward_result.result == 0 then
				log.debug("ReceiveAward: send reward success")
				log.debug(sprinttb(reward))
			end					
			player:UpdateRewardId(0)

			-- 记录元素暴走获得的奖励
			TeamRewardManger.AddReward(v, 3, reward, 1)
		end
	end
end

function Team:GetRandomPlayerId(site)
	local id_list = {}

	local p1 = PlayerList.GetPlayer(self.player_id1)
	if p1 and p1.player_index == site and p1.box_count < 10 then
		table.insert(id_list, self.player_id1)
	end
	local p2 = PlayerList.GetPlayer(self.player_id2)
	if p2 and p2.player_index == site and p2.box_count < 10 then
		table.insert(id_list, self.player_id2)
	end
	local p3 = PlayerList.GetPlayer(self.player_id3)
	if p3 and p3.player_index == site and p3.box_count < 10 then
		table.insert(id_list, self.player_id3)
	end
	local p4 = PlayerList.GetPlayer(self.player_id4)
	if p4 and p4.player_index == site and p4.box_count < 10 then
		table.insert(id_list, self.player_id4)
	end
	local p5 = PlayerList.GetPlayer(self.player_id5)
	if p5 and p5.player_index == site and p5.box_count < 10 then
		table.insert(id_list, self.player_id5)
	end

	if #id_list > 0 then
		local n = math.random(#id_list)
		return id_list[n]
	else
		return 0
	end
end

function Team:ResetBoxCount()
	if self.player_id1 ~= 0 then
		local p1 = PlayerList.GetPlayer(self.player_id1)
		if p1 and loop.now() > p1.box_deadtime then
			p1:ResetBoxCountAndDeadTime()
		end
	end
	if self.player_id2 ~= 0 then
		local p2 = PlayerList.GetPlayer(self.player_id2)
		if p2 and loop.now() > p2.box_deadtime then	
			p2:ResetBoxCountAndDeadTime()
		end
	end
	if self.player_id3 ~= 0 then
		local p3 = PlayerList.GetPlayer(self.player_id3)
		if p3 and loop.now() > p3.box_deadtime then	
			p3:ResetBoxCountAndDeadTime()
		end
	end
	if self.player_id4 ~= 0 then
		local p4 = PlayerList.GetPlayer(self.player_id4)
		if p4 and loop.now() > p4.box_deadtime then
			p4:ResetBoxCountAndDeadTime()
		end
	end
	if self.player_id5 ~= 0 then
		local p5 = PlayerList.GetPlayer(self.player_id5)
		if p5 and loop.now() > p5.box_deadtime then
			p5:ResetBoxCountAndDeadTime()
		end
	end
end


function Team:GetBoxCount()
	local id_list = self:GetPlayerIdList()

	local ret = {}
	for _, pid in ipairs(id_list) do
		local player = PlayerList.GetPlayer(pid)
		if player then
			table.insert(ret, { pid, player.box_count })
		end
	end

	return ret	
end

function Team:UpdateBossStatus(status)
	local ok = TeamTable.UpdateBossStatus(self.team_id, status, loop.now())

	if ok then
		self.boss_status = status
		self.begin_time = loop.now()
	end
end

function Team:UpdateLastIndex(index)
	local ok = TeamTable.UpdateLastIndex(self.team_id, index)
	if ok then
		self.last_index = index
	end
end

function Team:IsEncounter(index)
	local idList = self:GetPlayerIdList()
	local ret = {}
	for _, pid in ipairs(idList) do
		local player = PlayerList.GetPlayer(pid)
		if player.player_index == index then
			table.insert(ret, pid)
		end
	end

	return ret
end

-----------------------------------------------------------------------
local RoutineList = {}
function RoutineList.Contains(team_id)
	return RoutineList[team_id]
end

function RoutineList.Push(r)
	RoutineList[r.team_id] = r
end

function RoutineList.Remove(team_id)
	if RoutineList[team_id] then
		RoutineList[team_id] = nil
	end
end

------------------------ 玩家列表 -------------------------------------
function PlayerList.GetPlayer(pid)
	if PlayerList[pid] == nil then
    		local t = PlayerTable.Select(pid)
    		if t then
      			PlayerList[pid] = Player.New2(t)
    		end
	end

  	return PlayerList[pid]
end 

-- 根据pid来查看这个队伍是否存在
function PlayerList.Contains(pid)
	local player = PlayerList.GetPlayer(pid)
	if not player or player.team_id == 0 then  
		return false
	else
		return true
	end 
end

function PlayerList.Add(player)
  	PlayerList[player.pid] = player
end

function PlayerList.Remove(pid)
	local ok = PlayerTable.RemoveTeamInfo(pid)

	if ok then
		PlayerList[pid] = nil
	end
end

------------------------ 队伍列表 ---------------------------------------
function TeamList.GetTeam(id)
	if TeamList[id] == nil then
    		local t = TeamTable.Select(id)
    		if t then
      			TeamList[id] = Team.New2(t)
    		end
 	end

	return TeamList[id]
end

function TeamList.Add(team)
	TeamList[team.team_id] = team
end

-- 这些玩家是否可以组队
function TeamList.IsGroup(pid_list)
	if not pid_list or #pid_list == 0 then
		log.debug("player list is empty.")
    		return false
	end

	local flag = true

  	local n = #pid_list
  	local p1 = PlayerList.GetPlayer(pid_list[1])
  	local team_id1 = p1 and p1.team_id or 0
  	for i = 2, n do
    		local p = PlayerList.GetPlayer(pid_list[i])
    		local team_id = p and p.team_id or 0
    		if team_id1 ~= team_id then
      			flag = false
      			break
    		end
  	end

	return flag
end

local Lv_map = {}
function TeamList.IsLevel(pid_list)
	if not pid_list or #pid_list == 0 then
		log.warning("pid_list is empty")
		return false
	end

	for i, v in ipairs(pid_list) do
		Lv_map[v] = Lv_map[v] or {}		
		local player = Lv_map[v]
		if player.lv == nil or player.lv < LEVEL_LIMIT then
			local info = cell.getPlayerInfo(v)
			player.lv = info.level or 0
			log.debug("pid, level: ", v, player.lv)
		end
		if player.lv < LEVEL_LIMIT then
			return false
		end
	end

	return true
end

function TeamList.Remove(team_id)
	local ok = TeamTable.Delete(team_id)
	if ok then
		TeamList[team_id] = nil
	end
end

------------------------------ 地图列表 -----------------------------------------
function MapList.GetMap(team_id)
	if MapList[team_id] == nil then
    		local t = MapTable.Select(team_id)
      		MapList[team_id] = t
  	end

  	return MapList[team_id]
end

function MapList.Add(team_id, map)
  	MapList[team_id] = map
end

function MapList.UpdateLevel(team_id, site_id, level)
	local map = MapList.GetMap(team_id)
	if map == nil then
		log.debug("MapList.UpdateLevel: map not exist, ", team_id)
		return
	end
	local ok = MapTable.UpdateLevel(team_id, site_id, level)
	if ok then
		map[site_id].pitfall_level = level
	end
end

function MapList.UpdateAttactValue(team_id, site_id, value)
	local map = MapList.GetMap(team_id)
	if not map then
		log.debug("MapList.UpdateAttactValue: map not exist, ", team_id)
		return
	end
	local ok =  MapTable.UpdateAttactValue(team_id, site_id, value)
	if ok then
		map[site_id].attract_value = value
	end	
end

function MapList.UpdateBoxId(team_id, site_id, box_id)	
	local map = MapList.GetMap(team_id)
	if not map then
		log.debug("MapList.UpdateBoxId: map not exist, ", team_id)
		return
	end
	local ok = MapTable.UpdateBoxId(team_id, site_id, box_id)
	if ok then
		map[site_id].box_id = box_id
	end
end

function MapList.Remove(team_id)
	local ok = MapTable.Delete(team_id)
	if ok then
		MapList[team_id] = nil
	end
end

function MapList.GetBoxId(team_id)
	local map = MapList.GetMap(team_id)
	if map == nil then
		log.debug("GetBoxId: map is nil, team_id = ", team_id)
		return nil
	end

	local ret = {}
	for i, v in pairs(map) do
		table.insert(ret, { i, v.box_id })
	end

	return ret
end

function MapList.UpdateResourceType(team_id, site_id, type1)
	local map = MapList.GetMap(team_id)
	if not map then
		log.debug("MapList.UpdateResourceType: map not exist, ", team_id)
		return
	end
	local ok = MapTable.UpdateResourceType(team_id, site_id, type1)
	if ok then
		map[site_id].resource1_type = type1
	end
end

function MapList.UpdateLastCollectTime(team_id, site_id, time)
	local map = MapList.GetMap(team_id)
	if not map then
		log.debug("MapList.UpdateLastCollectTime: map not exist, ", team_id)
		return
	end
	local ok = MapTable.UpdateLastCollectTime(team_id, site_id, time)
	if ok then
		map[site_id].last_collect_time = time
	end
end

function MapList.UpdateSiteStatus(team_id, site_id, status) 
	local map = MapList.GetMap(team_id)
	if not map then
		log.debug("MapList.UpdateSiteStatus: map not exist, ", team_id)
		return
	end
	local ok = MapTable.UpdateSiteStatus(team_id, site_id, status)
	if ok then
		map[site_id].site_status = status
	end
end

-------------------------------- 资源列表 ---------------------------------------
function TeamResourceList.GetResource(team_id)
	if TeamResourceList[team_id] == nil then
		local t = TeamResourceTable.Select(team_id)
		TeamResourceList[team_id] = t
	end

	return TeamResourceList[team_id]
end

function TeamResourceList.InitialResource(team_id)
	local resource_id_list = ResourceConfig.GetResourceIdList()		
	for i, v in pairs(resource_id_list) do
		TeamResourceTable.Insert(team_id, { resource_id = i, resource_value = 0 })
	end
end

function TeamResourceList.GetResourceCount(team_id, resource_id)	
	if TeamResourceList[team_id] == nil then
		local t = TeamResourceTable.Select(team_id)
		TeamResourceList[team_id] = t
	end

	return TeamResourceList[team_id][resource_id]
end

function TeamResourceList.AddResourceCount(team_id, resource_id, value)
	if resource_id == 0 then
		return true;
	end

	local resource = TeamResourceList.GetResource(team_id)
	if #resource == 0 then
		log.debug("resource list is empty, team_id = ", team_id)
		return false
	end


	print(resource_id, resource[resource_id], value, debug.traceback());

	local ok = TeamResourceTable.UpdateCount(team_id, resource_id, resource[resource_id] + value)
	if ok then
		resource[resource_id] = resource[resource_id] + value
	end

	return ok
end

function TeamResourceList.Enough(team_id, resource_id, value)
	log.debug("------resource_id = ", resource_id)	

	if resource_id == 0 then
		return true;
	end

	local resource = TeamResourceList.GetResource(team_id)
	if #resource == 0 or resource[resource_id] == nil then
		log.debug("resource list is empty, team_id = ", team_id)
		return false
	end
	
	return resource[resource_id] >= value
end

function TeamResourceList.Remove(team_id)
	local ok = TeamResourceTable.Delete(team_id)
	if ok then
		TeamResourceList[team_id] = nil
	end
end

---------------------------------------------------------------------------------
local function build_team(pid_list, id)
	if not pid_list or #pid_list == 0 then
    		log.debug("build_team: pid list is empty.")
    		return
  	end

  	-- 如果队伍不存在，则新建一个队伍
  	local team_exist = PlayerList.Contains(pid_list[1]) 
  	if not team_exist then
    		-- 创建队伍
    		local team = Team.New(pid_list, id)
    		TeamList.Add(team)
			-- 创建资源
			TeamResourceList.InitialResource(team.team_id)
    		-- 创建角色
    		local n = #pid_list
    		local index_pool = {}
    		local index = 10002		
    		for i = 1, n do
      			table.insert(index_pool, index)
			index = index + 1
    		end
    		for i, v in ipairs(pid_list) do 
      			local num = math.random(#index_pool)
      			local p = Player.New(v, team.team_id, index_pool[num])
      			PlayerList.Add(p)
      			table.remove(index_pool, num)
    		end
    		-- 创建地图
    		local map = MapConfig.GetMap()
			log.debug("create map ---------------------------------------------", #map)		

    		MapTable.InsertMap(team.team_id, map)
    		MapList.Add(team.team_id, map)
  	end
end

--------------------- notify -----------------------------------
local function NotifyResourceChanged(conn, team_id, reason)
	log.debug("NotifyResourceChanged: team_id = ", team_id)
	if team_id == nil or conn == nil then
		log.debug("NotifyResourceChanged: pid or conn is empty.")
		return
	end

	local team = TeamList.GetTeam(team_id)
	if team == nil then
		log.debug("NotifyResourceChanged: team is nil, team id = ", team_id)
		return
	end

	local id_list = team:GetPlayerIdList()
	local resource_info = team:GetResourceInfo()
	local sn = 100

	for i, v in pairs(id_list) do
		if not IsAI(v) then
			conn:sendClientRespond(Command.NOTIFY_RESOURCE_CHANGE, v, { sn, Command.RET_SUCCESS, resource_info, team:GetPlayerInfo(), reason })
		end
	end
end

local function NotifyBossMove(conn, team_id)
	log.debug("NotifyBossMove: team_id  = ", team_id)
	if team_id == nil or conn == nil then
		log.debug("NotifyBossMove: team_id or conn is empty.")
		return
	end

	local team = TeamList.GetTeam(team_id)
	if team == nil then
		log.debug("NotifyBossMove: team is nil, team id = ", team_id)
		return
	end
	
	log.debug("NotifyBossMove: boss_status = ", team.boss_status)
		
	local id_list = team:GetPlayerIdList()
	local sn = 101

	for i, v in pairs(id_list) do
		if not IsAI(v) then
			conn:sendClientRespond(Command.NOTIFY_BOSS_MOVE, v, { sn, Command.RET_SUCCESS, team.boss_index, team.boss_status, loop.now(), team.boss_hp, MapList.GetBoxId(team.team_id), team.last_index })
		end
	end
end

local function NotifyGameOver(conn, team_id)
	log.debug("NotifyGameOver ...")
	if team_id == nil or conn == nil then
		log.debug("NotifyGameOver: team_id or conn is empty.")
		return
	end

	local team = TeamList.GetTeam(team_id)
	if team == nil then
		log.debug("NotifyGameOver: team is nil, team id = ", team_id)
		return
	end

	local id_list = team:GetPlayerIdList()
	local sn = 102

	local original_hp = BossConfig.GetBoss(team.boss_id).hp	or 1000
	local hp = team.boss_hp < 0 and 0 or team.boss_hp
	local condition = math.ceil(hp / original_hp * 10) * 1000
	local reward_id = BossConditionConfig.GetRewardId(condition)
	
	local victory = 0
	if team.boss_hp <= 0 then
		victory = 1
		local team = getTeam(team.team_id)
		if team then
			-- 组队活动活动胜利以后，增加成员之间的好感度
			SocialManager.AddMembersFavor(team.members, 1, 2)
		end
	end	

	for i, v in pairs(id_list) do
		local player = PlayerList.GetPlayer(v)
		log.debug('--- notify to player', v, player,  IsAI(v));
		if player then
			if not IsAI(v) then
				player:UpdateRewardId(reward_id)
				local reward = GameRewardConfig.GetReward(reward_id, player.pid)
				local list = {}
				for _, v in ipairs(reward) do
					table.insert(list, { v.type, v.id, v.value })
				end
				
				conn:sendClientRespond(Command.NOTIFY_GAME_OVER, v, { sn, Command.RET_SUCCESS, victory, list })
			else
				AICoManager.map[pid] = nil
			end
		end		
	end
end

local function NotifyPlayerMove(conn, player_id)
	local player = PlayerList.GetPlayer(player_id)
	if not player then
		log.debug("NotifyPlayerMove: player not exist.")
		return
	end
	log.debug("NotifyPlayerMove: is_stay = ", player.is_stay)
	local team = TeamList.GetTeam(player.team_id)
	if team == nil then
		log.debug("NotifyPlayerMove: team not exist, team_id = ", player.team_id)
		return
	end
	local sn = 103
	local id_list = team:GetPlayerIdList()
	for _, v in pairs(id_list) do
		if not IsAI(v) then
			conn:sendClientRespond(Command.NOTIFY_PLAYER_MOVE, v, { sn, Command.RET_SUCCESS, player.pid, player.player_index, player.is_stay, loop.now(), player.last_index, player.box_count })
		end
	end
end

local function NotifySiteChange(conn, team_id, site_id, pid)
	local team = TeamList.GetTeam(team_id)
	if not team then	
		log.debug("NotifySiteChange: team not exist, team_id = ", team_id)
		return
	end

	local id_list = team:GetPlayerIdList()
	local map = MapList.GetMap(team_id)
	if not map then
		log.debug("NotifySiteChange: map is empty, game maybe over, team_id = ", team_id)
		return
	end
	local site =  map[site_id]	
	local sn = 104
	for _, v in pairs(id_list) do
		if not IsAI(v) then
			local respond = {}
			respond[1] = sn
			respond[2] = Command.RET_SUCCESS
			respond[3] = site_id
			respond[4] = pid
			respond[5] = loop.now()
			respond[6] = site.resource1_type
			respond[7] = site.pitfall_level
			respond[8] = site.attract_value	
			respond[9] = site.site_status
			respond[10] = site.box_id

			conn:sendClientRespond(Command.NOTIFY_SITE_CHANGE, v, respond )	
		end
	end
end

local function NotifyComeIn(conn, pid_list)
	local cmd = Command.NOTIFY_COME_IN 
	log.debug("NotifyComeIn ....")

	for _, pid in ipairs(pid_list or {}) do
		local agent = Agent.Get(pid)
		if agent then
			agent:Notify({cmd})
		end
	end
end

-- 游戏结束，移除所有团队数据
local function remove_all_data(team_id)
	if team_id == nil then
		log.debug("remove_all_data: team_id is nil.")
		return
	end
	local team = TeamList.GetTeam(team_id)
	if team == nil then
		log.debug("remove_all_data: team is nil, team id = ", team_id)
	end
	-- 1.删除用户
	local id_list = team:GetPlayerIdList()
	for i, v in pairs(id_list) do
		PlayerList.Remove(v)
	end
	-- 2.删除队伍信息
	TeamList.Remove(team.team_id)
	-- 3.删除队伍地图信息
	MapList.Remove(team.team_id)
	-- 4.删除队伍资源
	TeamResourceList.Remove(team.team_id)
end

local function boss_move(team_id, conn)	
	local team = TeamList.GetTeam(team_id)
	if not team then
		log.warning(string.format("boss_move: team %d is not exist.", team_id))	
		return		
	end
	
	local map = MapList.GetMap(team_id)
	if not map then
		log.warning(string.format("boss_move: team %d map is not exist.", team_id))
		return		
	end

	-- 如果boss在起点，则是游戏开始，boss停留2分钟	
	if team.boss_index == MapConfig.GetOrigin() then
		log.debug("boss_move: sleep two minutes.")
		team:UpdateBossStatus(0)
		Sleep(2 * 60)
	end
	
	local route =  MapConfig.GetRouteRelation()
	-- 如果还没到达终点，则一直前进	
	while route[team.boss_index] and (route[team.boss_index].next1 or route[team.boss_index].next2 or route[team.boss_index].next3) do
		-- 选择一个诱敌值高的路径
		local path1 = route[team.boss_index].next1	
		local path2 = route[team.boss_index].next2
		local path3 = route[team.boss_index].next3

		local next_site = nil;

		local paths = {
			{path1, path1 and map[path1].attract_value or 9999999},
			{path2, path2 and map[path2].attract_value or 9999999},
			{path3, path3 and map[path3].attract_value or 9999999},
		}

		local attract_value = 9999999;
		for _, v in ipairs(paths) do
			if v[1] and v[2] < attract_value then
				attract_value = v[2];
				next_site = v[1];
			end
		end
		
--[[
		if path1 and path2 and path3 then
			local num1 = map[path1].attract_value
			local num2 = map[path2].attract_value
			local num3 = map[path3].attract_value
			if num1 == 0 and num2 == 0 and num3 == 0 then
				num1 = 1
				num2 = 1
				num3 = 1
			end
			local rand = math.random(num1 + num2 + num3)			
			if rand <= num1 then
				next_site = path1
			elseif rand > num1 and rand <= num1 + num2 then
				next_site = path2
			else
				next_site = path3
			end	
		elseif path1 and path2 then
			local num1 = map[path1].attract_value
			local num2 = map[path2].attract_value
			if num1 == 0 and num2 == 0 then
				num1 = 1
				num2 = 1
			end
			local rand = math.random(num1 + num2)
			if rand <= num1 then
				next_site = path1
			else
				next_site = path2
			end
		elseif path1 then
			next_site = path1	
		end
--]]

		team:UpdateLastIndex(team.boss_index)
		team:UpdateBossIndex(next_site)
		team:UpdateBossStatus(4)
		-- boss到达终点
		if team.boss_index == MapConfig.GetEnd() then
			NotifyBossMove(conn, team.team_id)	
			log.debug("arrival end ......")
			break
		end

		local site = map[team.boss_index]
		local original_hp = BossConfig.GetBoss(team.boss_id).hp	
		
		-- 计算boss掉血
		local hp_func = function(boss_type)
			local hp = 0
			local pitfall = PitfallConfig.GetDamage(site.pitfall_type, site.pitfall_level)
			
			if boss_type == 1 then
				hp = original_hp * (pitfall.air_damage / 10000)	
			elseif boss_type == 2 then
				hp = original_hp * (pitfall.dirt_damage / 10000)	
			elseif boss_type == 3 then
				hp = original_hp * (pitfall.water_damage / 10000)	
			elseif boss_type == 4 then
				hp = original_hp * (pitfall.fire_damage / 10000)	
			elseif boss_type == 5 then
				hp = original_hp * (pitfall.light_damage / 10000)	
			elseif boss_type == 6 then
				hp = original_hp * (pitfall.dark_damage / 10000)	
			end
		
			return hp		
		end

		-- 计算buff加持需要的时间和损失的血量	
		local move_time = TimeConfig.GetBossMoveTime(team.boss_id)
		local buff_func = function()
			local time = 0
			local hp = 0	
			local pitfall = PitfallConfig.GetDamage(site.pitfall_type, site.pitfall_level)
			if pitfall.is_buff ~= 0 then
				local buff_id = site.buff_id 
				local buff = BuffConfig.GetBuff(buff_id)
				if buff and buff.Effect == 1 then		-- 掉血
					hp = original_hp * (buff.Value / 10000) * (buff.Time / 1000) 
				elseif buff and buff.Effect == 2 then		-- 减速
								
				elseif buff and buff.Effect == 3 then		-- 眩晕
					time = buff.Time / 1000
				end	
			end

			return time, hp
		end	
		
		-- 根据掉血量掉落宝箱
		local drop_func = function(team)
			if team.boss_hp <= 0 then
				return;
			end
			local hp = team.boss_hp < 0 and 0 or team.boss_hp
			local condition = math.ceil(hp / original_hp * 10) * 1000
			local type_list = BossConditionConfig.GetTypeList(condition)
			local box_id_list = {}
			-- type_list 不为nil，则需要掉落宝箱
			if type_list then
				for _, v in ipairs(type_list) do
					local package_list = PackageConfig.GetPackageIdList(v)
					local n = math.random(#package_list)
					table.insert(box_id_list, package_list[n])				
				end
			end
	
			local site_list = MapConfig.GetRefreshSite()		
			for i, v in ipairs(box_id_list) do
				local n = math.random(#site_list)
				MapList.UpdateBoxId(team.team_id, site_list[n], v)
				table.remove(site_list, n)
			end
		end

		local accident = TimeConfig.GetRandomIncident(team.boss_id)
		local accident_time = 0
		local time = 0				-- 可能出现的眩晕时间
		local hp1 = 0				-- 固定掉血
		local hp2 = 0				-- 可能出现的buff掉血
		if #accident > 0 then
			accident_time = accident[2] / 1000
			hp1 = hp_func(team.boss_type)					
			time, hp2 = buff_func()	
			if hp1 >= team.boss_hp then
				accident_time = 0
				time = 0
			elseif hp1 + hp2 >= team.boss_hp then
				accident_time = 0
			end
	
			if accident[1] == 1 then
				-- 破坏据点
				local func = function(sec1, sec2, sec3)
					local index = team.boss_index
					log.debug("boss moving ...")
					Sleep(sec1)	
					-- 是否遭遇
					local list = team:IsEncounter(index)
					if #list > 0 then
						for _, pid in ipairs(list) do
							local index = team.boss_index
							log.debug("encouter boss: ", pid)
							local player = PlayerList.GetPlayer(pid)
							local n = player:EncountBoss(index)	
							if n == 11 then
								NotifyResourceChanged(conn, team.team_id, 5)
							elseif n == 12 then

							elseif n == 13 then
								NotifyBossMove(conn, team.team_id)
							elseif n == 14 then

							end
							NotifyPlayerMove(conn, player.pid)	
						end
					end
					
					team:UpdateBossHp(team.boss_hp - hp1)		
					NotifyBossMove(conn, team.team_id)		
					if sec2 > 0 then
						Sleep(sec2)	
					end
					if hp2 > 0 then
						team:UpdateBossHp(team.boss_hp - hp2)		
						NotifyBossMove(conn, team.team_id)		
					end					
					drop_func(team)	
					NotifySiteChange(conn, team.team_id, index, team.boss_id)
			
					if sec3 > 0 then				
						log.debug("boss begin to destroy site.")
						team:UpdateBossStatus(1)
						NotifyBossMove(conn, team.team_id)
						Sleep(sec3)	
						log.debug("boss destroy site end.")	
						-- MapList.UpdateSiteStatus(team.team_id, index, 1)
						-- NotifySiteChange(conn, team.team_id, index, team.boss_id)
					end
				end
				RunThread(func, move_time, time, accident_time)
			elseif accident[1] == 2 then
				-- 发呆
				local func = function(sec1, sec2)
					local index = team.boss_index
					log.debug("boss moving ...")
					Sleep(sec1)
					
					-- 是否遭遇
					local list = team:IsEncounter(index)
					if #list > 0 then
						for _, pid in ipairs(list) do
							log.debug("encouter boss: ", pid)
							local player = PlayerList.GetPlayer(pid)
							local n = player:EncountBoss()	
							if n == 11 then
								NotifyResourceChanged(conn, team.team_id, 5)
							elseif n == 12 then

							elseif n == 13 then
								NotifyBossMove(conn, team.team_id)
							elseif n == 14 then

							end
							NotifyPlayerMove(conn, player.pid)	
						end
					end					
				
					team:UpdateBossHp(team.boss_hp - hp1)
					NotifyBossMove(conn, team.team_id)			
							
					if sec2 > 0 then
						Sleep(sec2)
					end
					if hp2 > 0 then
						team:UpdateBossHp(team.boss_hp - hp2)
						NotifyBossMove(conn, team.team_id)		
					end

					drop_func(team)	
					NotifySiteChange(conn, team.team_id, index, 0) -- team.boss_id)
					log.debug("boss dazing ... ")
					team:UpdateBossStatus(2)	
					NotifyBossMove(conn, team.team_id)
				end
				RunThread(func, move_time, time)
			elseif accident[1] == 3 then
				-- 回血
				local func = function(sec1, sec2, sec3)
					local index = team.boss_index
					log.debug("boss moving ...")
					Sleep(sec1)	
					-- 是否遭遇
					local list = team:IsEncounter(index)
					if #list > 0 then
						for _, pid in ipairs(list) do
							log.debug("encouter boss: ", pid)
							local player = PlayerList.GetPlayer(pid)
							local n = player:EncountBoss()	
							if n == 11 then
								NotifyResourceChanged(conn, team.team_id, 5)
							elseif n == 12 then

							elseif n == 13 then
								NotifyBossMove(conn, team.team_id)
							elseif n == 14 then

							end
							NotifyPlayerMove(conn, player.pid)
						end
					end					

					team:UpdateBossHp(team.boss_hp - hp1)
					NotifyBossMove(conn, team.team_id)			
						
					if sec2 > 0 then
						Sleep(sec2)
					end
					if hp2 > 0 then
						team:UpdateBossHp(team.boss_hp - hp2)
						NotifyBossMove(conn, team.team_id)		
					end
		
					drop_func(team)
					NotifySiteChange(conn, team.team_id, index, 0) -- team.boss_id)	
	
					if sec3 > 0 then
						log.debug("boss recovering ...")
						team:UpdateBossStatus(3)	
						NotifyBossMove(conn, team.team_id)	
						team:UpdateBossHp(team.boss_hp + original_hp * 0.1)								
						Sleep(sec3)
						NotifyBossMove(conn, team.team_id)	
					end
				end
				RunThread(func, move_time, time, accident_time)
			end
		end

		log.debug("send boss move respond.....", team.boss_index)
		-- boss位置变化的通知
		NotifyBossMove(conn, team.team_id)
		Sleep(move_time + accident_time + time)

		-- boss血量为0, 游戏提前结束
		if team.boss_hp <= 0 then
			--quest
			local pidLst = team:GetPlayerIdList()
			for _, id in ipairs(pidLst) do
				log.debug("defend_stronghold   quest>>>>>>>>", id)
				cell.NotifyQuestEvent(id, {{type = 4, id = 8, count = 1}})
			end
			log.debug("boss hp is zero.")
			break
		end
	end	
	log.debug("------------------------------------ game over")
	-- 发送游戏结束通知(留点时间去移动)
	local move_time = TimeConfig.GetBossMoveTime(team.boss_id)
	if team.boss_index == MapConfig.GetEnd() then
		log.debug("boss move to end, wait to notify")
		Sleep(move_time)
	end
	NotifyGameOver(conn, team.team_id)
	-- 5秒之后自动领取奖励
	Sleep(5)
	team:ReceiveAward()
	-- 移除协程
	RoutineList.Remove(team.team_id)
	-- 移除所有数据
	remove_all_data(team.team_id)
end

local BossMoveRoutine = {}
function BossMoveRoutine.New(team_id)
  	return setmetatable({ team_id = team_id }, {__index = BossMoveRoutine})
end

function BossMoveRoutine:run(conn)
	co = coroutine.create(boss_move)
	coroutine.resume(co, self.team_id, conn)
end

local AICoManager = { map = {} }
function AICoManager.GetCo(pid)
	return AICoManager.map[pid]
end

local function ai_thread(pid, conn)
	local player = PlayerList.GetPlayer(pid)
	if not player then
		log.warning(string.format("ai_thread: player %d is not exist.", pid))
		return
	end

	local team = TeamList.GetTeam(player.team_id)
	if not team then
		log.warning(string.format("ai_thread: team %d is not exist.", player.team_id))
		return
	end

	local map = MapList.GetMap(team.team_id)
	if not map then
		log.warning(string.format("ai_thread: team %d map is not exist.", team.team_id))
		return		
	end

	local move_time = TimeConfig.GetPlayerMoveTime()

	while AICoManager.map[pid] do
		local route = MapConfig.GetRouteRelation()
		local point = nil
		local other = nil
		if route[team.boss_index] and route[team.boss_index].next1 == player.player_index  then
			point = route[team.boss_index].next1
			other = route[team.boss_index].next2
		elseif route[team.boss_index] and route[team.boss_index].next2 == player.player_index then
			point = route[team.boss_index].next2
			other = route[team.boss_index].next1
		end

		local site1 = map[point]
		local site2 = map[other]
		local flag = false		-- 是否处于目标陷阱点
		if site1 and site2 then
			local demage1 = 0
			local demage2 = 0
			local type1 = site1.pitfall_type
			local type2 = site2.pitfall_type
			local lv_1 = site1.pitfall_level
			local lv_2 = site2.pitfall_level
			local pit1 = PitfallConfig.GetDamage(type1, lv_1)
			local pit2 = PitfallConfig.GetDamage(type2, lv_2)

			if team.boss_type == 1 then
				demage1 = pit1.air_damage
				demage2 = pit2.air_damage
			elseif team.boss_type == 2 then
				demage1 = pit1.dirt_damage
				demage2 = pit2.dirt_damage
			elseif team.boss_type == 3 then
				demage1 = pit1.water_damage
				demage2 = pit2.water_damage
			elseif team.boss_type == 4 then
				demage1 = pit1.fire_damage
				demage2 = pit2.fire_damage
			elseif team.boss_type == 5 then
				demage1 = pit1.light_damage
				demage2 = pit2.light_damage
			elseif team.boss_type == 6 then
				demage1 = pit1.dark_damage
				demage2 = pit2.dark_damage
			end
			if demage1 >= demage2 then
				flag = true
			end
		elseif site1 then
			flag = true
		end

		if flag then
			-- 诱敌
			local curr_time = loop.now()	
			if curr_time > player.attract_time + AttractConfig.GetCD() / 1000 then
				local attract_config = AttractConfig.GetAttractConfig()
				local attract_type = 0
				if attract_config.Diversion_consume == 0 then
					attract_type = team.boss_type
				else 
					attract_type = attract_config.Diversion_consume
				end

				if TeamResourceList.Enough(team.team_id, attract_type, attract_config.Consume_value) then
					player:UpdateAttractTime(curr_time)
					-- 消耗资源
					TeamResourceList.AddResourceCount(team.team_id, attract_type, 0 - attract_config.Consume_value)	
					-- 提升诱敌率
					MapList.UpdateAttactValue(player.team_id, player.player_index, site1.attract_value + attract_config.Diversion_probability)
					NotifySiteChange(conn, team.team_id, player.player_index, pid)
				end
			end
			Sleep(3)
			-- 升级该陷阱
			local pitfall_type = site1.pitfall_type
			local pitfall_level = site1.pitfall_level
			local pitfall = PitfallConfig.GetDamage(pitfall_type, pitfall_level)	
			if curr_time > player.pitfall_time + PitfallConfig.GetCD(pitfall_type, pitfall_level) / 1000 then
				if pitfall_level < 5 then
					-- 检测资源是否足够
					if TeamResourceList.Enough(team.team_id, pitfall.consume_type1, pitfall.consume_value1) and 
						TeamResourceList.Enough(team.team_id, pitfall.consume_type2, pitfall.consume_value2) then
						player:UpdatePitfallTime(curr_time)
						-- 消耗资源
						TeamResourceList.AddResourceCount(team.team_id, pitfall.consume_type1, 0 - pitfall.consume_value1)	
						TeamResourceList.AddResourceCount(team.team_id, pitfall.consume_type2, 0 - pitfall.consume_value2)	
						-- 提升陷阱等级
						MapList.UpdateLevel(player.team_id, player.player_index, pitfall_level + 1) 
						NotifySiteChange(conn, team.team_id, player.player_index, pid)
					end
				end
			end
		else
			-- 收集资源
			local curr_time = loop.now()
			local site = map[player.player_index]
			if curr_time > site.last_collect_time + TimeConfig.GetResourceProduceTime() then
				-- 收集资源1
				local random_count = math.random(site.resource1_value)
				local ok = TeamResourceList.AddResourceCount(team.team_id, site.resource1_type, random_count)
				if ok then
					player:AddCollectCount(random_count)	
					table.insert(resource, {site.resource1_type, random_count})
					local temp = site.resource1_type
					local n = math.random(6)
					if n >= temp then
						n = n + 1
					end		
					MapList.UpdateResourceType(team.team_id, player.player_index, n)
					MapList.UpdateLastCollectTime(team.team_id, player.player_index, loop.now())
				end
				-- 收集资源2
				local num2 = math.random(1, 10000) 
				local resource_type = site.resource2_type
				if site.resource2_type == 99 then
					resource_type = math.random(7)	
				end	
				if num2 <= site.resource2_probability then
					local random_count2 = math.random(site.resource2_value)
					local ok = TeamResourceList.AddResourceCount(team.team_id, resource_type, random_count2)
					if ok then
						player:AddCollectCount(random_count2)	
						table.insert(resource, { resource_type, random_count2 })		
					end
				end
				player:UpdateCollectTime(curr_time)
				-- 通知所有成员，资源数量发生变化
				NotifyResourceChanged(conn, team.team_id, 1)
				NotifySiteChange(conn, team.team_id, player.player_index, pid)
			end

			-- 移动到与boss类型相当的资源收集点
			if player.is_stay == 12 and player.stay_time + TimeConfig.GetPlayerDebarTime() < loop.now() then
				player:UpdateStayStatus(10)	
			end
			if player.is_stay == 14 and player.stay_time + TimeConfig.GetPlayerForbiddenTime() < loop.now() then
				player:UpdateStayStatus(10)	
			end

			local nearby = MapConfig.GetNearSites(player.player_index)
			if player.is_stay ~= 12 and player.is_stay ~= 14 and #nearby > 0 then
				local dest = nearby[1]
				for _, v in ipairs(nearby) do
					if map[v].resource1_type == team.boss_type then
						dest = v
					end
				end

				local func = function(sec)
					Sleep(sec)
					player:UpdateStayStatus(20)		
					NotifyPlayerMove(conn, pid)
	
					-- 如果有玩家被禁锢了，则解救
					local pidLst = team:GetPlayerIdList()
					for _, id in ipairs(pidLst) do
						if player.pid ~= id then
							local p = PlayerList.GetPlayer(id)
							if p.is_stay == 12 then
								log.debug(string.format("rescue target %d", p.pid))
								p:UpdateStayStatus(20)
								NotifyPlayerMove(conn, p.pid)
							end
						end 
					end

					if team.boss_index == player.player_index and team.boss_status ~= 4 then	-- boss遭遇
						local n = player:EncountBoss()
						log.debug("player move to destination, encounter boss: n = ", n)	
						if n == 11 then
							NotifyResourceChanged(conn, player.team_id, 5)	
						elseif n == 12 then

						elseif n == 13 then
							NotifyBossMove(conn, team.team_id)
						elseif n == 14 then

						end
						NotifyPlayerMove(conn, player.pid)	
					end		
				end
				RunThread(func, TimeConfig.GetPlayerMoveTime())
				player:UpdateMoveTime(curr_time)
			end
		end
		Sleep(move_time)
	end
end

local function get_team_respond(pid, request, conn)
	-- 参数检测
  	if type(request) ~= "table" or #request < 1 then
    		local sn = request[1] or 1
    		return { sn, Command.RET_PARAM_ERROR }
  	end

	local sn = request[1]

	local teamInfo = getTeamByPlayer(pid)
	if not teamInfo then
		log.warning("get_team_respond: teamInfo is not exist.")
		return { sn, Command.RET_NOT_EXIST }
	end
	
	local pid_list = {}
	for _, v in ipairs(teamInfo.members or {}) do
		table.insert(pid_list, v.pid)
	end

  	-- 是否可以组队
  	if not TeamList.IsGroup(pid_list) then
    		log.debug("can not make a team.")
    		return { sn, Command.RET_DEPEND }
  	end

	-- 是否满足等级开放
	if not TeamList.IsLevel(pid_list) then
		log.warning("level is not enough.")	
    		return { sn, Command.RET_DEPEND }
	end

  	-- 建立团队
  	build_team(pid_list, teamInfo.id)

 	-- 获取player
  	local player = PlayerList.GetPlayer(pid)
	if not player then
		log.warning("get_team_respond: player not exist, pid = ", pid)
		return { sn, Command.RET_NOT_EXIST }	
	end	

  	-- 获取team
  	local team = TeamList.GetTeam(player.team_id)
	if not team then
		log.debug("team is empty, maybe game over, pid = ", pid1)
		return { sn, Command.RET_ERROR }
  	end

	team:ResetBoxCount()

  	local respond = {}
  	respond[1] = request[1]
  	respond[2] = Command.RET_SUCCESS
  	-- boss信息
  	respond[3] = team:GetBossInfo()
  	-- 玩家信息
  	respond[4] = team:GetPlayerInfo()
	-- 队伍资源信息
	respond[5] = team:GetResourceInfo()
	-- 地图信息
	respond[6] = team:GetMapInfo()

	-- 启动boss移动的协程
	if not RoutineList.Contains(team.team_id) then
		local r = BossMoveRoutine.New(team.team_id)
		r:run(conn)
		RoutineList.Push(r)
	end
	
	-- 启动ai协程
	for _, v in ipairs(team:GetPlayerIdList()) do
		if IsAI(v) and not AICoManager.GetCo(v) then
			AICoManager.map[v] = RunThread(ai_thread, v, conn)
		end
	end

	return respond
end

local function get_resource_respond(pid, request, conn)
	-- 参数判断
	if type(request) ~= "table" or #request == 0 then
    	local sn = request[1] or 1
    	return { sn, Command.RET_PARAM_ERROR }
	end	
	
	local sn = request[1]
	
  	local player = PlayerList.GetPlayer(pid)
	if not player then
		log.debug("player not exist, game maybe over, pid = ", pid)
		return { sn, Command.RET_ERROR } 
	end
	 
  	local team = TeamList.GetTeam(player.team_id)
	if not team then
		log.debug("team is empty, game maybe over, pid = ", pid)	
		return { sn, Command.RET_ERROR } 
	end

	local map = MapList.GetMap(player.team_id)
	if not map then
		log.debug("map is empty, game maybe over, pid = ", pid)
		return { sn, Command.RET_ERROR } 
	end


	local player_index = request[2] or player.player_index;

	local site =  map[player_index];

	if site.site_status == 1 then
		log.debug("site has destroyed, pid = ", pid)
		return { sn, Command.RET_ERROR }
	end

	-- 获取经验
	if player.exp_limit < ResourceConfig.GetExpLimit(site.resource1_type) then
		local exp = ResourceConfig.GetExperiment(site.resource1_type)

		player:UpdateExperiment(player.exp_limit + exp)
	end

	-- 检测cd
	local curr_time = loop.now()
	if curr_time < site.last_collect_time + TimeConfig.GetResourceProduceTime() then
		log.debug("collect time not enough, pid = ", pid)
		return { sn, Command.RET_ERROR }
	end

	player:UpdateCollectTime(curr_time)

	local respond = {}
	respond[1] = sn
	respond[2] = Command.RET_SUCCESS

	local num1 = math.random(1, 10000)
	-- 爆发战斗，结束收集
	if num1 <= site.fight_probability then						
		log.debug("start fight .... ")
		local attacker, err = cell.QueryPlayerFightInfo(pid, false, 0)
		if err then
			log.debug("get attacker error.")
		end
		local defender, err2 = cell.QueryPlayerFightInfo(site.fight_id, true, 100)
		if err2 then
			log.debug("get defender error.")
		end
		local fight_data = {
			attacker = attacker,
			defender = defender,
			scene = "",
		}
		local code = encode("FightData", fight_data)
		respond[3] = code
		player:UpdateStayStatus(21)		
		return respond
	else
		respond[3] = 0
	end

	local resource = {}
	-- 收集资源1
	local random_count = math.random(site.resource1_value)

	local ok = TeamResourceList.AddResourceCount(team.team_id, site.resource1_type, random_count)
	if ok then
		player:AddCollectCount(random_count)	
		table.insert(resource, { player_index ,site.resource1_type, random_count })
		local temp = site.resource1_type
		local n = math.random(3)
		if n >= temp then n = n + 1 end		
		MapList.UpdateResourceType(team.team_id, player_index, n)
		MapList.UpdateLastCollectTime(team.team_id, player_index, loop.now())
	end
	-- 收集资源2
	local num2 = math.random(1, 10000) 
	local resource_type = site.resource2_type
	if site.resource2_type == 99 then
		resource_type = math.random(1,4)
	end	
	if num2 <= site.resource2_probability then
		local random_count2 = math.random(site.resource2_value)
		local ok = TeamResourceList.AddResourceCount(team.team_id, resource_type, random_count2)
		if ok then
			player:AddCollectCount(random_count2)	
			table.insert(resource, { player_index, resource_type, random_count2 })		
		end
	end
	respond[4] = resource
	respond[5] = player.collect_time	

	-- 通知所有成员，资源数量发生变化
	NotifyResourceChanged(conn, team.team_id, 1)
	
	NotifySiteChange(conn, team.team_id, player_index, pid)

	-- 启动boss移动的协程
	if not RoutineList.Contains(team.team_id) then
		local r =  BossMoveRoutine.New(team.team_id)
		r:run(conn)
		RoutineList.Push(r)
	end

	return respond
end

local function get_pitfall_respond(pid, request, conn)
	-- 参数判断
	if type(request) ~= "table" or #request == 0 then
    	local sn = request[1] or 1
    	return { sn, Command.RET_PARAM_ERROR }
	end

	local sn = request[1]
	 	
  	local player = PlayerList.GetPlayer(pid)
	if not player then
		log.debug("player not exist, game maybe over, pid = ", pid)
		return { sn, Command.RET_ERROR } 
	end

  	local team = TeamList.GetTeam(player.team_id)
	if not team then
		log.debug("team is empty, game maybe over, pid = ", pid)	
		return { sn, Command.RET_ERROR } 
	end

	local map = MapList.GetMap(player.team_id)
	if not map then
		log.debug("map is empty, game maybe over, pid = ", pid)
		return { sn, Command.RET_ERROR } 
	end

	-- 获取陷阱信息
	local player_index = request[2] or player.player_index;
	
	local site =  map[player_index]	
	local pitfall_type = site.pitfall_type
	local pitfall_level = site.pitfall_level
	local pitfall = PitfallConfig.GetDamage(pitfall_type, pitfall_level)	
	if not pitfall then
		log.debug("fitfall config not exist, ", pitfall_type, pitfall_level, pid )
		return { sn, Command.RET_ERROR } 
	end

	-- 检测cd
	local curr_time = loop.now()
	if curr_time < player.pitfall_time + PitfallConfig.GetCD(pitfall_type, pitfall_level) / 1000 then
		log.debug("time cd not enough, pid = ", pid)
		return { sn, Command.RET_ERROR }
	end
	player:UpdatePitfallTime(curr_time)

	-- 检测等级是否已经到达最高
	if pitfall_level >= 5 then
		log.debug("fitfall level at monst level.")
		return { sn, Command.RET_MAX_LEVEL }
	end
	
	-- 检测资源是否足够
	if not TeamResourceList.Enough(team.team_id, pitfall.consume_type1, pitfall.consume_value1) or not TeamResourceList.Enough(team.team_id, pitfall.consume_type2, pitfall.consume_value2) then
		log.debug("resource not enough, pid = ", pid)
		return { sn, Command.RET_RESOURCES }
	end

	local respond = {}
	respond[1] = sn
	respond[2] = Command.RET_SUCCESS

	-- 消耗资源
	TeamResourceList.AddResourceCount(team.team_id, pitfall.consume_type1, 0 - pitfall.consume_value1)	
	TeamResourceList.AddResourceCount(team.team_id, pitfall.consume_type2, 0 - pitfall.consume_value2)	
	-- 提升陷阱等级
	MapList.UpdateLevel(player.team_id, player_index, pitfall_level + 1) 	
		
	respond[3] = {}
	table.insert(respond[3], { pitfall.consume_type1, pitfall.consume_value1 })
	table.insert(respond[3], { pitfall.consume_type2, pitfall.consume_value2 })
	
	respond[4] = site.pitfall_level
	respond[5] = player.pitfall_time
	respond[6] = player_index	
	
	NotifyResourceChanged(conn, team.team_id, 2)

	NotifySiteChange(conn, team.team_id, player_index, pid)

	-- 启动boss移动的协程
	if not RoutineList.Contains(team.team_id) then
		local r =  BossMoveRoutine.New(team.team_id)
		r:run(conn)
		RoutineList.Push(r)
	end

	return respond	
end

local function get_exchange_respond(pid, request, conn)
	-- 参数检测
	if type(request) ~= "table" or #request < 3 or type(request[2]) ~= "table" or #request[2] < 2 then
		local sn = request[1] or 1
    	return { sn, Command.RET_PARAM_ERROR }
	end
	
	local sn = request[1]

  	local player = PlayerList.GetPlayer(pid)
	if not player then
		log.debug("player not exist, game maybe over, pid = ", pid)
		return { sn, Command.RET_ERROR } 
	end

  	local team = TeamList.GetTeam(player.team_id)
	if not team then
		log.debug("team is empty, game maybe over, pid = ", pid)	
		return { sn, Command.RET_ERROR } 
	end

	local map = MapList.GetMap(player.team_id)
	if not map then
		log.debug("map is empty, game maybe over, pid = ", pid)
		return { sn, Command.RET_ERROR } 
	end

	-- 检测cd
	local curr_time = loop.now()	
	if curr_time < player.exchange_time + ExchangeConfig.GetCD() / 1000 then
		log.debug("time cd not enough, pid = ", pid)
		return { sn, Command.RET_ERROR }
	end
	player:UpdateExchangeTime(curr_time)

	local input = request[2]	-- 放入的资源
	local out = request[3]		-- 兑换的资源
	-- 检测是否满足兑换要求

	-- 检测资源是否足够	
	if not TeamResourceList.Enough(team.team_id, input[1], 1) or not TeamResourceList.Enough(team.team_id, input[2], 1) then	
		log.debug("resource not enough, pid = ", pid)
		return { sn, Command.RET_RESOURCES }
	end

	-- 更换资源
	TeamResourceList.AddResourceCount(team.team_id, input[1], -1)
	TeamResourceList.AddResourceCount(team.team_id, input[2], -1)
	TeamResourceList.AddResourceCount(team.team_id, out, 1)	

	local respond = {}
	respond[1] = sn
	respond[2] = Command.RET_SUCCESS
	respond[3] = player.exchange_time
	respond[4] = player.player_index
	respond[5] = player.pid
	
	-- 通知资源数量发生变化			
	NotifyResourceChanged(conn, team.team_id, 3)	

	-- 启动boss移动的协程
	if not RoutineList.Contains(team.team_id) then
		local r =  BossMoveRoutine.New(team.team_id)
		r:run(conn)
		RoutineList.Push(r)
	end

	return respond
end

local function get_attract_respond(pid, request, conn)
	-- 参数检测
	if type(request) ~= "table" or #request == 0 then
		local sn = request[1] or 1
    		return { sn, Command.RET_PARAM_ERROR }
	end
	
	local sn = request[1]

  	local player = PlayerList.GetPlayer(pid)
	if not player then
		log.debug("player not exist, game maybe over ", pid)
		return { sn, Command.RET_ERROR } 
	end

  	local team = TeamList.GetTeam(player.team_id)
	if not team then
		log.debug("team is empty, game maybe over, pid = ", pid)	
		return { sn, Command.RET_ERROR } 
	end
	
	local map = MapList.GetMap(player.team_id)
	if not map then
		log.debug("map is empty, game maybe over, pid = ", pid)
		return { sn, Command.RET_ERROR } 
	end
	
	local curr_time = loop.now()	
	if curr_time < player.attract_time + AttractConfig.GetCD() / 1000 then
		log.debug("time cd not enough, pid = ", pid)
		return { sn, Command.RET_ERROR }
	end
	player:UpdateAttractTime(curr_time)

	-- 获取诱敌配置信息
	local attract_config = AttractConfig.GetAttractConfig()
	local attract_type = 0
	if attract_config.Diversion_consume == 0 then
		attract_type = team.boss_type
	else 
		attract_type = attract_config.Diversion_consume
	end
	
	-- 检测是否资源是否足够
	if not TeamResourceList.Enough(team.team_id, attract_type, attract_config.Consume_value) then
		log.debug("resource not enough, pid = ", pid)
		return { sn, Command.RET_RESOURCES }	
	end
	
	-- 消耗资源
	TeamResourceList.AddResourceCount(team.team_id, attract_type, 0 - attract_config.Consume_value)	
	-- 提升诱敌率
	

	local player_index = request[2] or player.player_index;

	local site =  map[player_index]
	MapList.UpdateAttactValue(player.team_id, player_index, site.attract_value + attract_config.Diversion_probability)

	local respond = {}
	respond[1] = sn
	respond[2] = Command.RET_SUCCESS
	respond[3] = player.attract_time
	respond[4] = site.attract_value	
	respond[5] = player_index

	NotifyResourceChanged(conn, team.team_id, 4)

	NotifySiteChange(conn, team.team_id, player_index, pid)

	-- 启动boss移动的协程
	if not RoutineList.Contains(team.team_id) then
		local r =  BossMoveRoutine.New(team.team_id)
		r:run(conn)
		RoutineList.Push(r)
	end
	
	return respond
end

local function get_move_respond(pid, request, conn)
	-- 参数检测
	if type(request) ~= "table" or #request < 2 then
		local sn = request[1] or 1
    		return { sn, Command.RET_PARAM_ERROR }
	end
	
	local sn = request[1]

  	local player = PlayerList.GetPlayer(pid)
	if not player then
		log.debug("player not exist, game maybe over", pid)
		return { sn, Command.RET_ERROR } 
	end
	
	local team = TeamList.GetTeam(player.team_id)
	if not team then
		log.debug("team is empty, game maybe over, pid = ", pid)	
		return { sn, Command.RET_ERROR } 
	end

	-- 检测cd
	local curr_time = loop.now()
	if curr_time < player.move_time + TimeConfig.GetMoveCD() then
		log.debug("time cd not enough, pid = ", pid)
		return { sn, Command.RET_ERROR }
	end

	-- 检测目的地是否为起点或终点
	local dst = request[2]			-- 移动目的地
	if dst == MapConfig.GetOrigin() or dst == MapConfig.GetEnd() then
		log.debug("can not be destination")
		return { sn, Command.RET_ERROR }
	end

	local src = player.player_index		-- 玩家位置
	local route =  MapConfig.GetRouteRelation()
	local site = route[src]
	if dst < src then
		if site.previous1 == dst or site.previous2 == dst then				
			player:UpdateLastIndex(player.player_index)	
			player:UpdatePosition(dst)
		else		
			log.debug("destination not exist: src, dst = ", src, dst)
			return { sn, Command.RET_TARGET_NOT_EXIST }	
		end
	elseif dst > src then
		if site.next1 == dst or site.next2  == dst then
			player:UpdateLastIndex(player.player_index)	
			player:UpdatePosition(dst)
		else
			log.debug("destination not exist: src, dst = ", src, dst)
			return { sn, Command.RET_TARGET_NOT_EXIST }	
		end
	end

	-- 当前玩家是否可以移动
	if player.is_stay == 12 and player.stay_time + TimeConfig.GetPlayerDebarTime() > loop.now() then
		log.debug("player was debared, pid = ", pid)
		return { sn, Command.RET_ERROR }	
	end
	if player.is_stay == 14 and player.stay_time + TimeConfig.GetPlayerForbiddenTime() > loop.now() then
		log.debug("player can not move, pid = ", pid)
		return { sn, Command.RET_ERROR }
	end

	player:UpdateMoveTime(curr_time)
	player:UpdateStayStatus(10)	

	-- 启动boss移动的协程
	if not RoutineList.Contains(team.team_id) then
		local r =  BossMoveRoutine.New(team.team_id)
		r:run(conn)
		RoutineList.Push(r)
	end

	local func = function(sec)
		Sleep(sec)
		player:UpdateStayStatus(20)		
		NotifyPlayerMove(conn, pid)
	
		-- 如果有玩家被禁锢了，则解救
		local pidLst = team:GetPlayerIdList()
		for _, id in ipairs(pidLst) do
			if player.pid ~= id then
				local p = PlayerList.GetPlayer(id)
				if p.is_stay == 12 then
					log.debug(string.format("rescue target %d", p.pid))
					p:UpdateStayStatus(20)
					NotifyPlayerMove(conn, p.pid)
				end
			end 
		end

--[[
		if team.boss_index == player.player_index and team.boss_status ~= 4 then	-- boss遭遇
			local n = player:EncountBoss()
			log.debug("player move to destination, encounter boss: n = ", n)	
			if n == 11 then
				NotifyResourceChanged(conn, player.team_id, 5)	
			elseif n == 12 then

			elseif n == 13 then
				NotifyBossMove(conn, team.team_id)
			elseif n == 14 then

			end
			NotifyPlayerMove(conn, player.pid)	
		end		
--]]
	end	

	RunThread(func, TimeConfig.GetPlayerMoveTime())

	NotifyPlayerMove(conn, player.pid)

	return { sn, Command.RET_SUCCESS }		
end

local service = select(1, ...)

service:on(Command.C_DEFEND_STRONGHOLD_REQUEST, function(conn, pid, request)
	local respond = get_team_respond(pid, request, conn)
	conn:sendClientRespond(Command.C_DEFEND_STRONGHOLD_RESPOND, pid, respond)
end)

service:on(Command.C_DEFEND_RESOURCE_REQUEST, function(conn, pid, request)
	local respond = get_resource_respond(pid, request, conn)	
	conn:sendClientRespond(Command.C_DEFEND_RESOURCE_RESPOND, pid, respond)
end)

service:on(Command.C_DEFEND_STRENGTHEN_REQUEST, function(conn, pid, request)
	local respond = get_pitfall_respond(pid, request, conn)
	conn:sendClientRespond(Command.C_DEFEND_STRENGTHEN_RESPOND, pid, respond)
end)

service:on(Command.C_DEFEND_EXCHANGE_REQUEST, function(conn, pid, request)
	local respond = get_exchange_respond(pid, request, conn)
	conn:sendClientRespond(Command.C_DEFEND_EXCHANGE_RESPOND, pid, respond)
end)

service:on(Command.C_DEFEND_ATTRACT_REQUEST, function(conn, pid, request)
	local respond = get_attract_respond(pid, request, conn)
	conn:sendClientRespond(Command.C_DEFEND_ATTRACT_RESPOND, pid, respond)
end)

service:on(Command.C_DEFEND_MOVE_REQUEST, function(conn, pid, request)
	local respond = get_move_respond(pid, request, conn)
	conn:sendClientRespond(Command.C_DEFEND_MOVE_RESPOND, pid, respond)
end)

service:on(Command.C_DEFEND_REWARD_REQUEST, function(conn, pid, request)
	local player = PlayerList.GetPlayer(pid)
	local sn = request[1] or 1
	if not player then
		log.debug("player not exist: ", pid)
		conn:sendClientRespond(Command.C_DEFEND_REWARD_RESPOND, pid, { sn, Command.RET_ERROR })
		return
	end

	local reward_id = player.reward_id
	if reward_id == 0 then
		log.debug("reward_id is 0, pid = ", pid)
		conn:sendClientRespond(Command.C_DEFEND_REWARD_RESPOND, pid, { sn, Command.RET_ERROR })
		return
	end

	local reward = GameRewardConfig.GetReward(reward_id, pid)
	local reward_result =  cell.sendReward(pid, reward, nil, Command.REASON_DEFEND_TASK_DONE, false)	
	if reward_result.result == 0 then
		log.debug("Game over, send reward success")
		log.debug(sprinttb(reward))
	end					
	player:UpdateRewardId(0)

	-- 记录元素暴走获得的奖励
	TeamRewardManger.AddReward(pid, 3, reward, 1)

	conn:sendClientRespond(Command.C_DEFEND_REWARD_RESPOND, pid, { sn, Command.RET_SUCCESS })
end)

service:on(Command.C_DEFEND_BOX_REQUEST, function(conn, pid, request)
	local respond = {}
	if type(request) ~= "table" or #request == 0 then	
		local sn = request[1] or 1
    		local respond = { sn, Command.RET_PARAM_ERROR }
		conn:sendClientRespond(Command.C_DEFEND_BOX_RESPOND, pid, respond)
		return
	end
	
	local sn = request[1]
	local player = PlayerList.GetPlayer(pid)
	if not player then
		log.debug("player not exist: ", pid)
		local respond = { sn, Command.RET_ERROR } 
		conn:sendClientRespond(Command.C_DEFEND_BOX_RESPOND, pid, respond)
		return
	end	

	local player_index = request[2] or player.player_index;

	local map = MapList.GetMap(player.team_id)
	if map then
		local point = map[player_index]
		if point.box_id ~= 0 and player.box_count < 10 then
			local reward = PackageConfig.GetReward(point.box_id)
			local reward_result = cell.sendReward(player.pid, reward, nil, Command.REASON_DEFEND_AWARD, false)
			if reward_result.result == 0 then
				log.debug("send reward success")
			end						
			MapList.UpdateBoxId(player.team_id, player_index, 0)
			player:UpdateBoxCount(player.box_count + 1)

			-- 记录元素暴走获得的奖励
			TeamRewardManger.AddReward(pid, 3, reward, 1)
			respond = { sn, Command.RET_SUCCESS }
		else
			respond = { sn, Command.RET_DEPEND }
		end
	else
		respond = { sn, Command.RET_NOT_EXIST }	
	end		
	
	NotifySiteChange(conn, player.team_id, player_index, pid)

	conn:sendClientRespond(Command.C_DEFEND_BOX_RESPOND, pid, respond)
end)

service:on(Command.C_DEFEND_FIX_SITE_REQUEST, function(conn, pid, request)
	local respond = {} 
	if type(request) ~= "table" or #request == 0 then	
		local sn = request[1] or 1
    		local respond = { sn, Command.RET_PARAM_ERROR }
		conn:sendClientRespond(Command.C_DEFEND_FIX_SITE_RESPOND, pid, respond)
		return
	end

	local sn = request[1]
	local player = PlayerList.GetPlayer(pid)
	if not player then
		log.debug("player not exist: ", pid)
		local respond = { sn, Command.RET_ERROR } 
		conn:sendClientRespond(Command.C_DEFEND_FIX_SITE_RESPOND, pid, respond)
		return
	end	

	local player_index = request[2] or player.player_index;
	local index = player_index
	local map = MapList.GetMap(player.team_id)
	if map then
		local point = map[index]
		if point and point.site_status ~= 0 then
			MapList.UpdateSiteStatus(player.team_id, index, 0)					
			respond = { sn, Command.RET_SUCCESS }
		else
			log.debug("this site not exist: index", index)	
			respond = { sn, Command.RET_NOT_EXIST }
		end	
	else	
		log.debug("this map not exist: pid, index: ", pid, index)
		respond = { sn, Command.RET_NOT_EXIST }
	end
	
	conn:sendClientRespond(Command.C_DEFEND_FIX_SITE_RESPOND, pid, respond)
	if respond[2] == Command.RET_SUCCESS then
		NotifySiteChange(conn, player.team_id, index, pid)
	end
end)

service:on(Command.C_DEFEND_FIGHT_END_REQUEST, function(conn, pid, request)
	if type(request) ~= "table" or request == 0 then
		local sn = request[1] or 1
    		local respond = { sn, Command.RET_PARAM_ERROR }
		conn:sendClientRespond(Command.C_DEFEND_FIGHT_END_RESPOND, pid, respond) 
		return
	end
	local player = PlayerList.GetPlayer(pid)
	if not player then
		log.debug("player not exist: ", pid)
		local respond = { sn, Command.RET_ERROR } 
		conn:sendClientRespond(Command.C_DEFEND_FIGHT_END_RESPOND, pid, respond)
		return	
	end
	
	if player.is_stay ~= 21 then
		log.debug("player status is not fighting: ", pid)
		local respond = { sn, Command.RET_ERROR } 
		conn:sendClientRespond(Command.C_DEFEND_FIGHT_END_RESPOND, pid, respond)
		return	
	end
	
  	local team = TeamList.GetTeam(player.team_id)
	if not team then
		log.debug("team is empty, game maybe over, pid = ", pid)	
		local respond = { sn, Command.RET_ERROR } 
		conn:sendClientRespond(Command.C_DEFEND_FIGHT_END_RESPOND, pid, respond)
		return	
	end

	local map = MapList.GetMap(player.team_id)
	if not map then
		log.debug("map is empty, game maybe over, pid = ", pid)
		local respond = { sn, Command.RET_ERROR } 
		conn:sendClientRespond(Command.C_DEFEND_FIGHT_END_RESPOND, pid, respond)
		return	
	end

	local player_index = request[2] or player.player_index;

	local site =  map[player_index]		
	player:UpdateStayStatus(20)		

	-- 收集资源1
	local respond = {}
	respond[1] = request[1]
	respond[2] = Command.RET_SUCCESS	
	respond[3] = {}
	-- 收集资源1
	local random_count = math.random(site.resource1_value)
	local ok = TeamResourceList.AddResourceCount(team.team_id, site.resource1_type, random_count * 2)
	if ok then
		player:AddCollectCount(random_count * 2)	
		table.insert(respond[3], { site.resource1_type, random_count * 2 })
	end
	-- 收集资源2
	local num2 = math.random(1, 10000) 
	local resource_type = site.resource2_type
	if site.resource2_type == 99 then
		resource_type = math.random(7)	
	end	
	if num2 <= site.resource2_probability then
		local random_count2 = math.random(site.resource2_value)
		local ok = TeamResourceList.AddResourceCount(team.team_id, resource_type, random_count2 * 2)
		if ok then
			player:AddCollectCount(random_count2 * 2)	
			table.insert(respond[3], { resource_type, random_count2 * 2 })		
		end
	end
		
	NotifyResourceChanged(conn, team.team_id, 6)
	NotifyPlayerMove(conn, pid)

	conn:sendClientRespond(Command.C_DEFEND_FIGHT_END_RESPOND, pid, respond)
end)

service:on(Command.C_DEFEND_BEGIN_REQUEST, function(conn, pid, request)
	local cmd = Command.C_DEFEND_BEGIN_RESPOND 
	log.debug(string.format("cmd: %d, %d come in.", cmd, pid))

	if type(request) ~= "table" or #request < 1 then
		log.warning(string.format("cmd: %d, param error.", cmd))	
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]

	local teamInfo = getTeamByPlayer(pid)
	if not teamInfo then
		log.warning(string.format("cmd: %d, team is not exist, leader pid is %d.", cmd, pid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
	end
	
	local pid_list = {}
	for _, v in ipairs(teamInfo.members or {}) do
		table.insert(pid_list, v.pid)
	end

	NotifyComeIn(conn, pid_list)

	return conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })	
end)

service:on(Command.C_DEFEND_QUERY_REQUEST, function(conn, pid, request)
	local cmd = Command.C_DEFEND_QUERY_RESPOND
	log.debug(string.format("cmd: %d, query defend infomation.", cmd))

	if type(request) ~= "table" or #request < 1 then
		log.warning(string.format("cmd: %d, param error.", cmd))	
		return conn:sendClientRespond(cmd, pid, { 0, Command.RET_PARAM_ERROR })
	end
	local sn = request[1]	
	
	-- 获取player
  	local player = PlayerList.GetPlayer(pid)
	if not player then
		log.info(string.format("cmd: %d, player %d not exist.", cmd, pid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
	end	

  	-- 获取team
  	local team = TeamList.GetTeam(player.team_id)
	if not team then
		log.warning(string.format("cmd: %d, team %d is not exist, pid is %d.", cmd, player.team_id, pid))
		return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
  	end

  	local respond = {}
  	respond[1] = sn
  	respond[2] = Command.RET_SUCCESS

 
	return conn:sendClientRespond(cmd, pid, respond)
end)

