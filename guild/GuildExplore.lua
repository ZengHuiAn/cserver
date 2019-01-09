local database = require "database"
local Command = require "Command"
local cell = require "cell"
local PlayerManager = require "PlayerManager"

local GuildExploreEvent = require "GuildExploreEvent"
local GuildEventLog = require "GuildEventLog"
local SocialManager = require "SocialManager"

require "GuildSummaryConfig"
require "printtb"


local mapPoolConfig --= {1,2,3}
local alreadyInsert = {}
local MAX_PROGRESS = 10000
local NORMAL_MAP = 1

local exploreProductConfig = {} 
local mapMaxExploreCount = {} 

local function LoadAllExploreProductConfig()
	if not mapPoolConfig then
		mapPoolConfig = {}
		local ok , result = database.query("SELECT mapid, map_type, map_property, explore_count, product_type, product_id, product_value, prob, worth, time_min, time_max, worth_add FROM GuildExploreConfig")
		if ok and #result > 0 then
			for i = 1, #result , 1 do
				local row = result[i]
				if row.map_type == NORMAL_MAP and not alreadyInsert[row.mapid] then
					table.insert(mapPoolConfig, row.mapid)
					alreadyInsert[row.mapid] = true
				end	
			end
		end	
	end
end

local function GetMapPoolConfig()
	LoadAllExploreProductConfig()

	return mapPoolConfig
end

local function LoadExploreProductConfig(mapid)
	if exploreProductConfig[mapid] then 
		return exploreProductConfig[mapid] ~= -1 and exploreProductConfig[mapid] or nil
	end
	local ok , result = database.query("SELECT map_property, explore_count, product_type, product_id, product_value, prob, worth, time_min, time_max, worth_add FROM GuildExploreConfig WHERE mapid = %d", mapid)
	if ok and #result > 0 then
		exploreProductConfig[mapid] = {
			map_property = result[1].map_property,
		}
		for i = 1, #result , 1 do
			local row = result[i]
			mapMaxExploreCount[mapid] = mapMaxExploreCount[mapid] or 0
			if row.explore_count > mapMaxExploreCount[mapid] then
				mapMaxExploreCount[mapid] = row.explore_count	
			end
			exploreProductConfig[mapid][row.explore_count] = exploreProductConfig[mapid][row.explore_count] or {} 
			exploreProductConfig[mapid][row.explore_count].time_min = exploreProductConfig[mapid][row.explore_count].time_min or row.time_min
			exploreProductConfig[mapid][row.explore_count].time_max = exploreProductConfig[mapid][row.explore_count].time_max or row.time_max
			exploreProductConfig[mapid][row.explore_count].product_list = exploreProductConfig[mapid][row.explore_count].product_list or {}
			local product = {
				product_type = row.product_type,
				product_id = row.product_id,
				product_value = row.product_value,
				prob = row.prob,
				worth = row.worth,
				worth_add = row.worth_add,
				--worth_add2 = row.worth_add2,
				--worth_reduce = row.worth_reduce	
			}	
			table.insert(exploreProductConfig[mapid][row.explore_count].product_list, product)
		end
	else
		exploreProductConfig[mapid] = -1 
	end	
	return exploreProductConfig[mapid] ~= -1 and exploreProductConfig[mapid] or nil
end

local function GetMapMaxExploreCount(mapid)
	return mapMaxExploreCount[mapid] or 0
end

local playerHeroInfo = {}
local function GetPlayerHeroInfo(pid, uuid)
	if not playerHeroInfo[pid] then
		playerHeroInfo[pid] = {} 
	end
	
	if not playerHeroInfo[pid][uuid] or loop.now() - playerHeroInfo[pid][uuid].refresh_time > 5 * 60 then
		if not playerHeroInfo[pid][uuid] then
			playerHeroInfo[pid][uuid] = {}
		end
		playerHeroInfo[pid][uuid].refresh_time = loop.now() 

		local heroInfo = cell.getPlayerHeroInfo(pid, 0, uuid)	
		if not heroInfo then
			yqinfo("fail to GetPlayerHeroInfo, cannnot get hero info for hero:%d", uuid)	
			playerHeroInfo[pid][uuid] = nil
			return 
		end

		playerHeroInfo[pid][uuid].data = heroInfo
	end

	return playerHeroInfo[pid][uuid].data
end

local MAX_PROPERTY_COUNT = 6 
local function SamePropertyCount(hero_property, map_property)
	if not hero_property or not map_property then
		return 0
	end 
	local count = 0 
	for i = 1, MAX_PROPERTY_COUNT, 1 do
		local mask = 2 ^ (i - 1)
		if (bit32.band(hero_property, mask) ~= 0) and (bit32.band(map_property, mask) ~= 0) then
			count = count + 1
		end
	end

	return count
end

--[[local function BetterProperty(hero_property, map_property)
	for i = 1, MAX_PROPERTY_COUNT, 1 do
		local mask = 2 ^ (i - 1)
		if bit32.band(hero_property, mask) == 1 then
			if i ~= MAX_PROPERTY_COUNT then
				if bit32.band(map_property, 2 ^ i) == 1 then
					return true	
				end		
			else
				if bit32.band(map_property, 1) == 1 then
					return true	
				end
			end
		end
	end

	return false
end

local function SameProperty(hero_property, map_property)
	return hero_property == map_property
end

local function WorseProperty(hero_property, map_property)
	for i = 1, MAX_PROPERTY_COUNT, 1 do
		local mask = 2 ^ (i - 1)
		if bit32.band(hero_property, mask) == 1 then
			if i ~= 1 then
				if bit32.band(map_property, 2 ^ (MAX_PROPERTY_COUNT - 1)) == 1 then
					return true	
				end		
			else
				if bit32.band(map_property, 2 ^ (i - 2)) == 1 then
					return true	
				end
			end
		end
	end

	return false
end--]]

local function GetWorth(worth, team, pid, worth_add, map_property)
	if not worth then
		return 0
	end

	if not pid then
		return worth
	end

	if not team then
		return worth
	end

	local total_worth = 0
	for i = 1, 5, 1 do
		if team["formation_role"..i] ~= 0 then
			local hero_info = GetPlayerHeroInfo(pid, team["formation_role"..i])
			local gid = hero_info.gid	
				
			if gid then
				local hero_property = GetHeroProperty(gid) 
				local add_value = worth + worth_add * SamePropertyCount(hero_property, map_property)
	
				total_worth = total_worth + add_value 
			end

		end
	end

	return total_worth
end

local function GetReward(exploreCount, mapid, speed, time, team, pid)
	local progressIncrease = 0
	local rewardList = {}
	local nextRewardTime = 0	
	local config = LoadExploreProductConfig(mapid)
	if not config or not config[exploreCount] then
		yqinfo("fail to GetReward cannot get config for map:%d",mapid)
		return nil
	end
	for k, v in ipairs(config[exploreCount].product_list or {}) do
		if math.random(1, 10000) <= v.prob then
			table.insert(rewardList, {type = v.product_type, id = v.product_id, value = v.product_value,})
			local add_value = GetWorth(v.worth, team, pid, v.worth_add, config.map_property)
			progressIncrease = progressIncrease + add_value--v.worth
		end
	end
	nextRewardTime = time + math.floor(math.random(config[exploreCount].time_min, config[exploreCount].time_max)/speed*60)
	return progressIncrease, rewardList, nextRewardTime
end

local allMap = {}
local GetGuildExploreMap
local DeleteGuildExploreMap

local function CheckAndGetAllMap(gid, update)
	if not allMap[gid] then
		allMap[gid] = {}
		local ok, result = database.query("SELECT mapid, progress, reward_flag, unix_timestamp(begin_time) as begin_time, unix_timestamp(end_time) as end_time FROM GuildExploreMap WHERE gid = %d AND (NOW() <= end_time or unix_timestamp(end_time) = 0)", gid)
		if ok and #result > 0 then
			for i = 1, #result ,1 do
				local row = result[i]
				allMap[gid][row.mapid] =  {progress = row.progress, reward_flag = row.reward_flag, begin_time = row.begin_time, end_time = row.end_time}	
			end
		else
			local map_pool_config = GetMapPoolConfig()
			--for i = 1, 3, 1 do
			for _, mapid in ipairs(map_pool_config) do
				database.update("INSERT INTO GuildExploreMap(gid, mapid, progress, reward_flag, begin_time, end_time) VALUES(%d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d))", gid, mapid, 0, 0, 0, 0)	
				allMap[gid][mapid] = {progress = 0, reward_flag = 0, begin_time = 0, end_time = 0}
			end
		end	
	end
	
	--check and update map progress
	local now = loop.now()
	for mapid, map in pairs(allMap[gid]) do
		local guildExploreMap = GetGuildExploreMap(gid, mapid)
		if update then
			guildExploreMap:CheckAndUpdateProgress()
			
			-- delete invalid map
			if ((now > map.end_time or map.progress >= MAX_PROGRESS) and map.end_time > 0) then
				DeleteMap(gid, mapid)

				--TODO  delete event on invalid map
				
				for pid, v in pairs(guildExploreMap.teamList) do
					for order, _ in pairs(v) do
						guildExploreMap:DeleteTeam(pid, order)
					end
					
					local player_event = GuildExploreEvent.Get(pid)
        			player_event:DeleteEvent(self.mapid)	
				end
			end

		end
	end

	return allMap[gid]
end

function HasLimitTimeMap(gid)
	CheckAndGetAllMap(gid, true)

	for  mapid, _ in pairs(allMap[gid]) do
		if mapid > 3 then
			return true 
		end	
	end

	return false
end

function AddNewMap(gid, new_mapid, begin_time, end_time)
	local guildMapList = CheckAndGetAllMap(gid, true)	

	for  mapid, _ in pairs(allMap[gid]) do
		if mapid == new_mapid then
			log.debug(string.format("add new map fail , map %d already exist", new_mapid))
			return false
		end	
	end

	allMap[gid][new_mapid] = {progress = 0, reward_flag = 0, begin_time = begin_time, end_time = end_time}

	local _, reward , _ = GetReward(0, new_mapid, 1, 0)
	local reward_amf = {}
	if reward then
		for k, v in ipairs(reward) do
			table.insert(reward_amf, {v.type, v.id, v.value})
		end
	end	

	local msg = {
		new_mapid,          --mapid
		0,                  --property 
		0,               	--progerss
		0,                  --explore_team_count
		reward_amf,         -- final reward
		begin_time,
		end_time,
	}	

	local config = LoadExploreProductConfig(new_mapid)
	if config then
		msg[2] = config.map_property	
	end

	local guild = GuildManager.Get(gid);
	EventManager.DispatchEvent("GUILD_EXPLORE_MAP_CHANGE", {guild = guild, change = 1, message = msg});
	database.update("INSERT INTO GuildExploreMap(gid, mapid, progress, reward_flag, begin_time, end_time) VALUES(%d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d))", gid, new_mapid, 0, 0, begin_time, end_time)	
end

local function GetMapProgress(gid, mapid)
	local guildMapList = CheckAndGetAllMap(gid)	
	local map = guildMapList[mapid]
	return map and map.progress or nil
end

local function GetMapRewardFlag(gid, mapid)
	local guildMapList = CheckAndGetAllMap(gid)	
	local map = guildMapList[mapid]
	return map and map.reward_flag or nil
end

local function GetMapTime(gid, mapid)
	local guildMapList = CheckAndGetAllMap(gid)	
	local map = guildMapList[mapid]
	return map and map.begin_time or nil, map and map.end_time or nil
end

local function UpdateMapProgress(gid, mapid, updateValue)
	local guildMapList = CheckAndGetAllMap(gid)	
	local map = guildMapList[mapid]
	if map then
		if map.progress == updateValue then return end
		if database.update("UPDATE GuildExploreMap SET progress = %d WHERE gid = %d and mapid = %d", updateValue, gid, mapid) then
			map.progress = updateValue 
		end
	end
end

local function UpdateMapRewardFlag(gid, mapid, flag)
	local guildMapList = CheckAndGetAllMap(gid)	
	local map = guildMapList[mapid]
	if map then
		if map.reward_flag == flag then return end
		if database.update("UPDATE GuildExploreMap SET reward_flag = %d WHERE gid = %d and mapid = %d", flag, gid, mapid) then
			map.reward_flag = flag 
		end
	end
end

function DeleteMap(gid, mapid)
	local guildMapList = CheckAndGetAllMap(gid)	
	local map = guildMapList[mapid]
	if map then
		guildMapList[mapid] = nil
		DeleteGuildExploreMap(gid, mapid)
		
		local msg = {
			mapid,
		}
		EventManager.DispatchEvent("GUILD_EXPLORE_MAP_CHANGE", {guild = guild, change = 0, message = msg});
		return database.update("DELETE FROM GuildExploreMap WHERE gid = %d and mapid = %d", gid, mapid) 
	end
end

local function InsertRandomMap(gid)
	local guildMapList = CheckAndGetAllMap(gid)	
	local mapPool = {}
	
	local map_pool_config = GetMapPoolConfig()
	for _,mapid in pairs(map_pool_config) do
		if not guildMapList[mapid] then
			table.insert(mapPool, mapid)
		end	
	end
	local randomRet = get_rand_unique_num(mapPool, 1)	
	local mapid = randomRet[1]
	guildMapList[mapid] = {progress = 0, reward_flag = 0}	
	return database.update("INSERT INTO GuildExploreMap(gid, mapid, progress, reward_flag) VALUES(%d, %d, 0, 0)", gid, mapid)
end

local function ResetMap(gid , mapid)
	local progress = GetMapProgress(gid, mapid) 
	if progress < MAX_PROGRESS then
		yqinfo("Fail to reset map progress < MAX_PROGRESS")
		return nil
	end

	local guildExploreMap = GetGuildExploreMap(gid, mapid)
	if not guildExploreMap then
		yqinfo("fail to reset explore map ,get guildExploreMap fail")
		return nil 
	end
	for pid, v in pairs(guildExploreMap.teamList) do
		for order, _ in pairs(v) do
			guildExploreMap:DeleteTeam(pid, order)
		end
	end
	if not DeleteMap(gid, mapid) then
		yqinfo("fail to reset map,   deletemap fail")
		return nil
	end
	if not InsertRandomMap(gid) then
		yqinfo("fail to reset map,   insert random map fail")
		return nil
	end
	return 0
end

local playerTeam = {}
local GuildExploreMap = {}

function GetPlayerTeam(pid, mapid, team_id)
	if not mapid and not team_id then
		return playerTeam[pid] and playerTeam[pid] or nil
	elseif mapid and team_id then
		if not playerTeam[pid] then
			return nil
		else
			for k, v in ipairs(playerTeam[pid]) do
				if v.mapid == mapid and team_id == v.order then
					return playerTeam[pid][k]
				end	
			end

			return nil
		end
	end
end

function GetPlayerTeamMemberCount(pid, mapid, team_id)
	local team = GetPlayerTeam(pid, mapid, team_id)
	if not team then
		return nil 
	end

	local count = 0
	for i = 1, 5, 1 do
		if team["formation_role"..i] > 0 then
			count = count + 1
		end
	end		

	return count
end

function GuildExploreMap.New(gid, mapid)
	return setmetatable({
			gid = gid,
			mapid = mapid,
			maxOrder = 0,
			teamNum = 0,
			teamList = {},
	}, {__index = GuildExploreMap});
end

function GuildExploreMap:LoadExploreTeam()
	local ok, result = database.query("SELECT pid, `order`, explore_count, speed, UNIX_TIMESTAMP(start_time) as start_time, UNIX_TIMESTAMP(next_reward_time) as next_reward_time, reward_depot, formation_role1, formation_role2, formation_role3, formation_role4, formation_role5, `index` FROM GuildExploreTeam WHERE gid = %d AND mapid = %d", self.gid, self.mapid)
	if ok and #result > 0 then
		for i = 1, #result do
			local row = result[i]
			if row.order > self.maxOrder then
				self.maxOrder = row.order
			end
			self.teamNum = self.teamNum + 1
			local team = {
				pid = row.pid,
				order = row.order,
				mapid = self.mapid,
				explore_count = row.explore_count,
				speed = row.speed,
				start_time = row.start_time,
				next_reward_time = row.next_reward_time,
				reward_depot = row.reward_depot or '',
				formation_role1 = row.formation_role1,
				formation_role2 = row.formation_role2,
				formation_role3 = row.formation_role3,
				formation_role4 = row.formation_role4,
				formation_role5 = row.formation_role5,
				index = row.index,
				data_change = false,
			}		
			--table.insert(self.teamList, team)
			self.teamList[row.pid] = self.teamList[row.pid] or {}
			self.teamList[row.pid][row.order] = team
			
			playerTeam[row.pid] = playerTeam[row.pid] or {}
			table.insert(playerTeam[row.pid], team)

		end
	end
end

function GuildExploreMap:CalcAndGetSpeed()
	return 1
end

function GuildExploreMap:InsertNewTeam(pid, formationRole1, formationRole2, formationRole3, formationRole4, formationRole5, index)
	if (not GetPlayerHeroInfo(pid, formationRole1) and formationRole1 ~= 0) or (not GetPlayerHeroInfo(pid, formationRole2) and formationRole2 ~= 0) or (not GetPlayerHeroInfo(pid, formationRole3) and formationRole3 ~= 0) or (not GetPlayerHeroInfo(pid, formationRole4) and formationRole4 ~= 0) or (not GetPlayerHeroInfo(pid, formationRole5) and formationRole5 ~= 0) then
		log.debug("not has this hero")
		return false
	end

	local now = loop.now()
	local speed = self:CalcAndGetSpeed()
	local _, _ , nextRewardTime = GetReward(1, self.mapid, speed, now)
	if not nextRewardTime then
		return nil 
	end
	local team = {
			pid = pid,
			order = self.maxOrder+1,
			mapid = self.mapid,
			explore_count = 0,
			speed = speed,
			start_time = now,
			next_reward_time = nextRewardTime,
			reward_depot = '',
			formation_role1 = formationRole1,
			formation_role2 = formationRole2,
			formation_role3 = formationRole3,
			formation_role4 = formationRole4,
			formation_role5 = formationRole5,
			index = index,
			data_change = false,
	}	
	--table.insert(self.teamList, team)
	self.teamList[pid] = self.teamList[pid] or {}
	self.teamList[pid][self.maxOrder + 1] = team

	playerTeam[pid] = playerTeam[pid] or {}
	table.insert(playerTeam[pid], team)
	self.maxOrder = self.maxOrder + 1
	self.teamNum = self.teamNum + 1

	-- add event
	local player_event = GuildExploreEvent.Get(team.pid)
	if player_event then
		player_event:FillEvent(team.mapid, team.order)
	end

	return database.update("INSERT INTO GuildExploreTeam(gid, mapid, pid, `order`, speed, start_time, next_reward_time, reward_depot, explore_count, formation_role1, formation_role2, formation_role3, formation_role4, formation_role5, `index`) VALUES (%d, %d, %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), '', 0, %d, %d, %d, %d, %d, %d)", self.gid, self.mapid, pid, self.maxOrder, speed, now, nextRewardTime, formationRole1, formationRole2, formationRole3, formationRole4, formationRole5, index), team
end

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

local function getRewardFromStr(str)
    local ret = str_split(str, "|")
    local ret_tb = {}
    for k,v in ipairs(ret or {}) do
        local kv_pair = str_split(v, ",")
		table.insert(ret_tb, {type = tonumber(kv_pair[1]), id = tonumber(kv_pair[2]), value = tonumber(kv_pair[3])})
    end
    return ret_tb
end

function GuildExploreMap:SendReward(pid, order)
	if not self.teamList[pid] or not self.teamList[pid][order] then
		yqinfo("fail to sendReward, cannt get teamList for map:%d, player:%d, order:%d", self.mapid, pid, order)
		return nil 
	end	
	local reward = getRewardFromStr(self.teamList[pid][order].reward_depot) 	
	if #reward > 0 then
		local respond = cell.sendReward(pid, reward, nil, Command.REASON_GUILD_EXPLORE, false, 0, nil)--"军团探索奖励");
		if respond == nil or respond.result ~= Command.RET_SUCCESS then
			yqinfo("Fail to sendReward for explore, cell error")
			return nil
		end
		self.teamList[pid][order].reward_depot = ""
		database.update("UPDATE GuildExploreTeam SET reward_depot = '' WHERE gid = %d AND mapid = %d AND pid = %d AND `order` = %d", self.gid, self.mapid, pid, order)
		return 0
	else
		yqinfo("Fail to sendReward for explore, no reward")
		return nil
	end	
end

function GuildExploreMap:SendFinalReward()
	local _, reward , _= GetReward(0, self.mapid, 1, 0)
	if reward then
		local guild = GuildManager.Get(self.gid);
		if not guild then
			yqinfo("Fail to SendFinalReward for explore, cannot player guild")
			return nil
		end
		for _, m in pairs(guild.members) do
			local respond = cell.sendReward(m.id, reward, nil, Command.REASON_GUILD_EXPLORE, false, 0);
			if respond == nil or respond.result ~= Command.RET_SUCCESS then
				yqinfo("Fail to SendFinalReward for explore, cell error")
				return nil
			end

			--quest
			cell.NotifyQuestEvent(m.id, {{type = 36, id = 1, count = 1}})
        end
	
		UpdateMapRewardFlag(self.gid, self.mapid, 1)
	
		for pid, v in pairs(self.teamList) do
			for order, _ in pairs(v) do
				self:SendReward(pid, order)
			end
		end

		return 0
	else
		yqinfo("Fail to sendFinalReward for explore, no reward")
		UpdateMapRewardFlag(self.gid, self.mapid, 1)

		for pid, v in pairs(self.teamList) do
			for order, _ in pairs(v) do
				self:SendReward(pid, order)
			end
		end

		return nil
	end

end

function GuildExploreMap:DeleteTeam(pid, order)
	yqinfo("Delete Team>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>   pid:%d  order:%d   mapid:%d", pid, order, self.mapid)
	if not self.teamList[pid] then
		yqinfo("fail to delete team for map:%d pid:%d order:%d, team not in list", self.mapid, pid, order)
		return nil 
	end
	local find = false
	for k, v in pairs(self.teamList[pid] or {}) do
		if v.pid == pid and v.order == order then
			find = true
			self.teamList[pid][k] = nil
			self.teamNum = self.teamNum - 1
		end
	end

	local delete_key
	for k, v in ipairs(playerTeam[pid] or {}) do
		if v.pid == pid and v.order == order and self.mapid == v.mapid then
			--find = true
			delete_key = k
			--playerTeam[pid][k] = nil
		end
	end
	if delete_key then
		table.remove(playerTeam[pid], delete_key)
	end

	if find then
		if order == self.maxOrder then
			self.maxOrder = self.maxOrder - 1
		end
		--sendReward(pid, order)
		-- delete event 
		local player_event = GuildExploreEvent.Get(pid)
        player_event:DeleteEvent(self.mapid, order)	

		return database.update("DELETE FROM GuildExploreTeam WHERE mapid = %d AND pid = %d AND `order` = %d", self.mapid, pid, order)
	end

	yqinfo("fail to delete team for map:%d pid:%d order:%d, team not in list", self.mapid, pid, order)
	return nil 
end

local function buildNewRewardDepot(reward_depot, type, id, value)
	local ret = str_split(reward_depot, "|")
	local ret_tb = {}
	local has_reward_before = false
	for k,v in ipairs(ret or {}) do
		local kv_pair = str_split(v, ",")
		if tonumber(kv_pair[1]) == type and tonumber(kv_pair[2]) == id then
			has_reward_before = true
			table.insert(ret_tb, {type = tonumber(kv_pair[1]), id = tonumber(kv_pair[2]), value = tonumber(kv_pair[3]+value)})
		else
			table.insert(ret_tb, {type = tonumber(kv_pair[1]), id = tonumber(kv_pair[2]), value = tonumber(kv_pair[3])})
		end
	end
	if #ret == 0 or not has_reward_before then
			table.insert(ret_tb, {type = type, id = id, value = value})
	end
	local retStr = ""
	for _,reward in ipairs(ret_tb or {}) do
		retStr = retStr..tostring(reward.type)..","..tostring(reward.id)..","..tostring(reward.value).."|"
	end
	return retStr
end

function GuildExploreMap:changeData(pid, order, rewardList, nextRewardTime, exploreCount)
	--yqinfo("GuildExploreMap    changeData  pid:%d order:%d nextRewardTime:%d exploreCount:%d rewardList:%s", pid, order, nextRewardTime, exploreCount, sprinttb(rewardList))
	for k, v in pairs(self.teamList[pid] or {}) do
		if v.order == order then

			for _, reward in ipairs (rewardList) do
				v.reward_depot = buildNewRewardDepot(v.reward_depot, reward.type, reward.id, reward.value)--v.reward_depot..tostring(reward.type)..","..tostring(reward.id)..","..tostring(reward.value).."|"
			end
			v.next_reward_time = nextRewardTime
			v.explore_count = exploreCount
			v.dataChange = true
			break
		end
	end
end

function GuildExploreMap:refreshDatabaseData()
	for pid, team_list in pairs (self.teamList or {}) do
		for _, v in pairs(team_list or {}) do
			if v.dataChange then
				database.update("UPDATE GuildExploreTeam SET explore_count = %d, next_reward_time = from_unixtime_s(%d), reward_depot = '%s' WHERE gid = %d AND mapid = %d AND pid = %d AND `order` = %d", v.explore_count, v.next_reward_time, v.reward_depot, self.gid, self.mapid, v.pid, v.order)	
				v.dataChange = false
			end
		end
	end	
end

function GuildExploreMap:CheckAndUpdateProgress()
	local progress = GetMapProgress(self.gid, self.mapid) 
	
	local rewardFlag = GetMapRewardFlag(self.gid, self.mapid)
	local begin_time, end_time = GetMapTime(self.gid, self.mapid)
	if (progress and rewardFlag) and progress >= MAX_PROGRESS and rewardFlag ~= 1 then
		self:SendFinalReward()

		-- delete all team
		if begin_time > 0 and end_time > 0 then
			local guildExploreMap = GetGuildExploreMap(self.gid, self.mapid)
			if not guildExploreMap then
				return  
			end
			for pid, v in pairs(guildExploreMap.teamList) do
				for order, _ in pairs(v) do
					guildExploreMap:DeleteTeam(pid, order)
				end
			end
		end
	end

	--if progress >= MAX_PROGRESS then return end

	if not begin_time or not end_time then
		log.warning("fail to update map progress, map %d of guild %d donnt has begin_time, end_time", self.mapid, self.gid)
		return
	end

	local now = loop.now()

	--calculate settle info 
	local settleList = {}
	for _, team_list in pairs(self.teamList or {}) do
		for k, team in pairs(team_list or {}) do 
			local calcTime = team.next_reward_time
			local exploreCount = team.explore_count
			while(begin_time == 0 and end_time == 0 and calcTime < now and calcTime ~= 0) or (begin_time > 0 and end_time > 0 and calcTime < now and calcTime ~= 0 and calcTime <= end_time) do
				local progressIncrease, rewardList , nextRewardTime = GetReward(exploreCount + 1, self.mapid, team.speed, calcTime, team, team.pid)
				local team_member_num = 0 
				for i = 1, 5, 1 do
					if team["formation_role"..i] ~= 0 then
						team_member_num = team_member_num + 1 
					end
				end
				if not progressIncrease then
					--yqerror("fail to CheckAndUpdateProgress  , cannot getReward for explorecount:%d, mapid:%d", exploreCount + 1, self.mapid)
					break 	
				end
				exploreCount = exploreCount + 1
				if (nextRewardTime <= end_time and end_time > 0 and begin_time > 0) or (end_time == 0 and begin_time == 0) then
					table.insert(settleList, {pid = team.pid, order = team.order, progress_increase = progressIncrease * team_member_num, rewardList = rewardList, get_reward_time = calcTime, next_reward_time = nextRewardTime, explore_count = exploreCount})
				end
				calcTime = nextRewardTime
			end	
		end
	end
	
	table.sort(settleList, function (a, b)
		if a.get_reward_time ~= b.get_reward_time then
			return a.get_reward_time < b.get_reward_time
		end
		return a.order < b.order
	end)

	--begin settle
	for _, v in ipairs(settleList) do
		--if progress >= MAX_PROGRESS then return end
		progress = progress + v.progress_increase			
		self:changeData(v.pid, v.order, v.rewardList, v.next_reward_time, v.explore_count)
	end	
	
	UpdateMapProgress(self.gid, self.mapid, progress >= MAX_PROGRESS and MAX_PROGRESS or progress)	
	self:refreshDatabaseData()
end

local guildExploreMap = {} 
GetGuildExploreMap = function(gid, mapid)
	if not guildExploreMap[gid] then
		guildExploreMap[gid] = {}
	end
	if not guildExploreMap[gid][mapid] then
		guildExploreMap[gid][mapid]	= GuildExploreMap.New(gid, mapid)
		guildExploreMap[gid][mapid]:LoadExploreTeam()
	end
	return guildExploreMap[gid][mapid]
end

DeleteGuildExploreMap = function(gid, mapid) 
	if not guildExploreMap[gid] or not guildExploreMap[gid][mapid]then
		return 
	else
		guildExploreMap[gid][mapid] = nil
	end	
end

function process_guild_explore_query_map_info(conn, pid, req)
	local cmd = Command.C_GUILD_EXPLORE_QUERY_MAP_INFO_RESPOND
	local sn = req[1] 
	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
	end

	local map =	CheckAndGetAllMap(player.guild.id, true)
	local amf = {}

	
	for k, v in pairs(map) do
		local _, reward , _ = GetReward(0, k, 1, 0)
		local reward_amf = {}
		if reward then
			for k, v in ipairs(reward) do
				table.insert(reward_amf, {v.type, v.id, v.value})
			end
		end	

		local temp = {
			k,          --mapid
			0,         --property 
			v.progress,	--progerss
			0,	        --explore_team_count
			reward_amf, -- final reward
			v.begin_time,
			v.end_time,
		}	
		local config = LoadExploreProductConfig(k)
		if config then
			temp[2] = config.map_property	
		end
		local mapInfo = GetGuildExploreMap(player.guild.id, k)
		if mapInfo then
			temp[4] = mapInfo.teamNum
		end
		table.insert(amf, temp)
	end
	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, amf});
end

function process_guild_explore_query_player_team_info(conn, pid, req)
	local cmd = Command.C_GUILD_EXPLORE_QUERY_PLAYER_TEAM_INFO_RESPOND	
	local sn = req[1]

	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
	end

	CheckAndGetAllMap(player.guild.id, true)

	local playerTeam = GetPlayerTeam(pid)	
	if not playerTeam then 
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, {}})
	end
	
	local amf = {}
	for k, v in pairs(playerTeam or {}) do
		local temp = {
			v.mapid,
			v.order,
			v.start_time,
			v.next_reward_time,
			v.reward_depot,			
			v.formation_role1,
			v.formation_role2,
			v.formation_role3,
			v.formation_role4,
			v.formation_role5,
			v.index,
			v.explore_count,
			GetMapMaxExploreCount(v.mapid),
		}
		table.insert(amf, temp)	
	end 
	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, amf})
end

local MAX_TEAM_NUM = 1 
function process_guild_explore_attend(conn, pid, req) 
	local cmd = Command.C_GUILD_EXPLORE_ATTEND_RESPOND	
	local sn = req[1]
	local mapid = req[2]
	local formation_role1 = req[3]
	local formation_role2 = req[4]
	local formation_role3 = req[5]
	local formation_role4 = req[6]
	local formation_role5 = req[7]
	local index = req[8]

	if not mapid or not formation_role1 or not formation_role2 or not formation_role3 or not formation_role4 or not formation_role5 or not index then
		yqinfo("Fail to attend explore, param erro")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	local team_member_num = 0
	for i = 1, 5, 1 do
		if req[i] ~= 0 then
			team_member_num = team_member_num + 1
		end	
	end

	if team_member_num == 0 then
		yqinfo("Fail to attend explore, member count too small")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	yqinfo("Player `%d` Begin to attend explore, mapid:%d formation:%d %d %d %d %d", pid, req[2], req[3], req[4], req[5], req[6], req[7])
	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
	end

	local map = CheckAndGetAllMap(player.guild.id, true)
	
	--check
	if not map[mapid] then
		yqinfo("Fail to attend explore, map:%d not correct", mapid)
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local progress = GetMapProgress(player.guild.id, mapid)
	if progress >= MAX_PROGRESS then
		yqinfo("Fail to attend explore, map:%d explore already finish", mapid)
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_EXPLORE_FINISH})
	end

	local playerTeam = GetPlayerTeam(pid)	
	local size = 0 
	for _,team in pairs(playerTeam or {}) do
		if team.mapid == mapid then
			size = size + 1
		end
	end
	if playerTeam and size >= MAX_TEAM_NUM then 
		yqinfo("Fail to attend explore ,team num already max")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	if size > 0 then
		for i=1, 5, 1 do
			for k, v in pairs(playerTeam) do
				for index = 1, 5 do
					if req[i+2] ~= 0 and req[i+2] == v["formation_role"..index] then
						yqinfo("Fail to attend explore ,role `%d` already in team", req[i+2])
						return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
					end
				end
			end
		end	
	end
	
	local guildExploreMap = GetGuildExploreMap(player.guild.id, mapid)
	if not guildExploreMap then
		yqinfo("Fail to attend explore, cannot get guildExploreMap")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local success , team = guildExploreMap:InsertNewTeam(pid, formation_role1, formation_role2, formation_role3, formation_role4, formation_role5, index)	
	local amf = {}
	if team then
		amf = {
			mapid,
			team.order,
			team.start_time,
			team.next_reward_time,
			team.reward_depot,			
			team.formation_role1,
			team.formation_role2,
			team.formation_role3,
			team.formation_role4,
			team.formation_role5,
			team.index,
		}
	end

	if success then
		cell.NotifyQuestEvent(pid, { { type = 78, id = 1, count = 1 }, }) 
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, amf})
	else
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end
end

function process_guild_explore_stop(conn, pid, req) 
	local cmd = Command.C_GUILD_EXPLORE_STOP_RESPOND	
	local sn = req[1]
	local mapid = req[2]
	local teamOrder = req[3]

	if not mapid or not teamOrder then
		yqinfo("Fail to stop explore, param erro")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	yqinfo("Player `%d` Begin to stop explore, mapid:%d teamOrder:%d", pid, mapid, teamOrder)
	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
	end

	local map = CheckAndGetAllMap(player.guild.id, true)
	
	--check
	if not map[mapid] then
		yqinfo("Fail to stop explore, map:%d not correct", mapid)
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local guildExploreMap = GetGuildExploreMap(player.guild.id, mapid)
	if not guildExploreMap then
		yqinfo("Fail to stop explore, cannot get guildExploreMap")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local success = guildExploreMap:DeleteTeam(pid, teamOrder)	
	if success then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS})
	else
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end
end

function process_guild_explore_reset(conn, pid, req) 
	local cmd = Command.C_GUILD_EXPLORE_RESET_RESPOND	
	local sn = req[1]
	local mapid = req[2]

	--yqinfo(">>>>>     %s",sprinttb(req))
	if not mapid then
		yqinfo("Fail to reset explore, param erro")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	yqinfo("Player `%d` Begin to reset explore for  map:%d", pid, mapid)
	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
	end

	local map = CheckAndGetAllMap(player.guild.id, true)
	
	--check
	if not map[mapid] then
		yqinfo("Fail to reset explore, map:%d not correct", mapid)
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local guildExploreMap = GetGuildExploreMap(player.guild.id, mapid)
	if not guildExploreMap then
		yqinfo("Fail to reset explore, cannot get guildExploreMap")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local success = ResetMap(player.guild.id, mapid)	
	if success then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS})
	else
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end
end

function process_guild_explore_draw_reward(conn, pid, req)
	local cmd = Command.C_GUILD_EXPLORE_DRAW_REWARD_RESPOND	
	local sn = req[1]
	local mapid = req[2]
	local order = req[3]

	if not mapid then
		yqinfo("Fail to draw explore reward, param erro")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	yqinfo("Player `%d` Begin to draw explore reward for map:%d order:%d", pid, mapid, order)
	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
	end

	local map = CheckAndGetAllMap(player.guild.id, true)
	
	--check
	if not map[mapid] then
		yqinfo("Fail to draw explore reward, map:%d not correct", mapid)
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local guildExploreMap = GetGuildExploreMap(player.guild.id, mapid)
	if not guildExploreMap then
		yqinfo("Fail to draw explore reward, cannot get guildExploreMap")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local success = guildExploreMap:SendReward(pid, order)	
	if success then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS})
	else
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end
end

function process_guild_query_explore_event(conn, pid, req)
	local cmd = Command.C_GUILD_EXPLORE_QUERY_EVENT_RESPOND	
	local sn = req[1]
	local mapid = req[2]
	local teamid = req[3]

	if not mapid then
		yqinfo("Fail to query explore events, param erro")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	yqinfo("Player `%d` Begin to query explore events for map:%d team:%d", pid, mapid, teamid)
	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
	end

	local map = CheckAndGetAllMap(player.guild.id, true)
	
	--check
	local player_event = GuildExploreEvent.Get(pid)

	if not player_event then
		yqinfo("Fail to query explore evnets, cannt get player event")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local ret = player_event:GetEvents(mapid, teamid)	
	--print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^", sprinttb(ret))
	if ret then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, ret})
	else
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end
end

function process_guild_finish_explore_event(conn, pid, req)
	local cmd = Command.C_GUILD_EXPLORE_FINISH_EVENT_RESPOND	
	local sn = req[1]
	local mapid = req[2]
	local teamid = req[3]
	local uuid = req[4]

	if not mapid or not teamid or not uuid then
		yqinfo("Fail to finish explore events, param erro")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	yqinfo("Player `%d` Begin to finish explore events for map:%d team:%d uuid:%d", pid, mapid, teamid, uuid)
	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
	end

	local map = CheckAndGetAllMap(player.guild.id, true)
	
	--check
	local player_event = GuildExploreEvent.Get(pid)

	if not player_event then
		yqinfo("Fail to finish explore evnets, cannt get player event")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local ret = player_event:FinishEvent(mapid, teamid, uuid)	
	if ret then	
		cell.NotifyQuestEvent(pid, { { type = 79, id = 1, count = 1 }, }) 
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS})
	else
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end
end

function process_guild_query_explore_event_log(conn, pid, req)
	local cmd = Command.C_GUILD_EXPLORE_QUERY_EVENT_LOG_RESPOND	
	local sn = req[1]

	yqinfo("Player `%d` Begin to query explore event log", pid)
	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

	-- 玩家没有军团
	if player.guild == nil then --or player.level < 10 then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
	end

	local map = CheckAndGetAllMap(player.guild.id, true)
	
	--check
	local event_log = GuildEventLog.Get(player.guild.id)

	if not event_log then
		yqinfo("Fail to finish explore evnets, cannt get event log")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local ret = event_log:GetLog()	
	if ret then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, ret})
	else
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end
end

local EventToFight = {}
function process_guild_explore_fight_prepare(conn, pid, req)
	local cmd = Command.C_GUILD_EXPLORE_FIGHT_PREPARE_RESPOND 
	local sn = req[1]
	local mapid = req[2]
	local teamid = req[3]
	local uuid = req[4]

	if not mapid or not teamid or not uuid then
		yqinfo("Fail to query explore fight data , param erro")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	yqinfo("Player `%d` Begin to query explore fight data for  map:%d team:%d evnet_uuid:%d", pid, mapid, teamid, uuid)
	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

	-- 玩家没有军团
	if player.guild == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
	end

	local map = CheckAndGetAllMap(player.guild.id, true)
	
	--check
	local player_event = GuildExploreEvent.Get(pid)

	if not player_event then
		yqinfo("Fail to query explore fight data, cannt get player event")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local events = player_event:GetEvents(mapid, teamid)
	local target_fight = 0
	for k, v in ipairs(events) do
		local event_uuid = v[5]
		if uuid == event_uuid then
			local event_id = v[3]
			local cfg = GetGuildExploreEventMap(event_id)
			if cfg and cfg.event_type == 2 then
				target_fight = cfg.event_result
			end
			break
		end	
	end

	if target_fight == 0 then
		yqinfo("Fail to query explore fight data, cannt get target fight")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local sn = req[1]
	local attacker = pid	
	local target = target_fight	
	local npc = 1	
	local heros = nil
	local assists = nil

	local playerTeam = GetPlayerTeam(pid)	
	if not playerTeam then 
		yqinfo("Fail to query explore fight data, cannt get team")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end
	
	for k, v in pairs(playerTeam or {}) do
		if v.mapid == mapid and v.order == teamid then
			heros = {}
			table.insert(heros, v.formation_role1)
			table.insert(heros, v.formation_role2)
			table.insert(heros, v.formation_role3)
			table.insert(heros, v.formation_role4)
			table.insert(heros, v.formation_role5)
			break;
		end
	end

	local fightid, fight_data = SocialManager.PVEFightPrepare(attacker, target, npc, heros, assists)
	if not fight_data then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	EventToFight[uuid] = fightid
	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, fightid, fight_data})
end

function process_guild_explore_fight_check(conn, pid, req)
	local cmd = Command.C_GUILD_EXPLORE_FIGHT_CHECK_RESPOND 
	local sn = req[1]
	local mapid = req[2]
	local teamid = req[3]
	local uuid = req[4]
	local starValue = req[5]
	local code = req[6]

	if not mapid or not teamid or not uuid or not starValue or not code then
		yqinfo("Fail to check explore fight, param erro")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	starValue = nil

	yqinfo("Player `%d` Begin to check explore fight for map:%d team:%d evnet_uuid:%d", pid, mapid, teamid, uuid)
	local player = PlayerManager.Get(pid);
	-- 玩家不存在
	if player.name == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_CHARACTER_NOT_EXIST})
	end

	-- 玩家没有军团
	if player.guild == nil then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_GUILD_NOT_EXIST})
	end

	local map = CheckAndGetAllMap(player.guild.id, true)
	
	--check
	local player_event = GuildExploreEvent.Get(pid)

	if not player_event then
		yqinfo("Fail to chec explore fight, cannt get player event")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local events = player_event:GetEvents(mapid, teamid)
	local fightid = 0
	if EventToFight[uuid] then
		fightid = EventToFight[uuid]
	end

	if fightid == 0 then
		yqinfo("Fail to check explore fight, cannt get fightid")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end
	
	local winner , rewards = SocialManager.PVEFightCheck(pid, fightid, starValue, code)
	if not winner then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local ar = {}
	for k, v in ipairs(rewards) do
		table.insert(ar, {v.type, v.id, v.value, v.uuid})
	end
	
	if winner == 1 then
		player_event:FinishEvent(mapid, teamid, uuid)
	end

	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, winner, ar})
end

function CleanPlayerExploreMapInfo(gid, pid)
	local map = CheckAndGetAllMap(gid, true)
	local playerTeam = GetPlayerTeam(pid)
	while playerTeam and #playerTeam > 0 do 
		local team = playerTeam[1]
		local guildExploreMap = GetGuildExploreMap(gid, team.mapid)
		if guildExploreMap then
			guildExploreMap:DeleteTeam(pid, team.order)	
		end
	end
end

