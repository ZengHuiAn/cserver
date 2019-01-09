require "cell"
local database = require "database"
local Class = require "Class"
require "yqlog_sys"
local table = table
local yqdebug = yqdebug
local yqinfo = yqinfo
local yqwarn = yqwarn
local yqerror = yqerror
local yqassert = yqassert
local math = math
local string = string
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local cell = require "cell"
require "printtb"
--require "ArenaPlayerFightData"
--local getPlayerFightData = getPlayerFightData
--local addPlayerFightData = addPlayerFightData
local sprinttb = sprinttb
local base64 = require "base64"
local protobuf = require "protobuf"
local Property = require "Property"
local log = require "log"

module "ArenaPlayerPool"

local STRIDE = 1000 

local module_name = "ArenaPlayerPool"
local single_instance 
local ArenaPlayerPool = {}

local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));		
		loop.exit();
		return nil;
	end
	return code;
end

local function decode(code, protocol)
	return protobuf.decode("com.agame.protocol." .. protocol, code);
end

local buff_tb = {[1002] = true, [1102] = true, [1302] = true, [1402] = true, [1502] = true}
local playerFightData = {}
local function getPlayerFightData(pid, force, increase_percent)
	increase_percent = increase_percent or 0
    if force or playerFightData[pid] == nil then
        playerFightData[pid] = {}
		local fight_data, err = cell.QueryPlayerFightInfo(pid, false, 100)
        if err then
            log.debug(string.format('get fight data of player %d error %s', pid, err))
            return ""
        end

        local capacity = 0;
        for k, v in ipairs(fight_data.roles) do
            capacity = capacity + v.Property.capacity
			for _, property in ipairs(v.propertys) do
				if buff_tb[property.type] then
					property.value = math.floor(property.value * (100 + increase_percent) / 100)
				end
			end
        end

        local code = encode('FightPlayer', fight_data);
        playerFightData[pid].code = code
		playerFightData[pid].capacity = capacity
		playerFightData[pid].name = fight_data.name or ""
		
		local player_pool = Get()
		player_pool:updateFightData(pid, base64.encode(code), capacity)
    end

    return playerFightData[pid].code, playerFightData[pid].capacity, playerFightData[pid].name
end



local AIFightData = {}
local function getAIFightData(ai_id, force, increase_percent)
	increase_percent = increase_percent or 0
	if force or AIFightData[ai_id] == nil then
		AIFightData[ai_id] = {}
		local fight_data, err = cell.QueryPlayerFightInfo(ai_id, true, 100)
		if err then
			log.debug(string.format("get ai fight data of %d error %d", ai_id, err))
			return ""
		end

		local capacity = 0;
        	for k, v in ipairs(fight_data.roles) do
			capacity = capacity + v.Property.capacity
			for _, property in ipairs(v.propertys) do
				if buff_tb[property.type] then
					property.value = math.floor(property.value * (100 + increase_percent) / 100)
				end
			end
        	end

        	local code = encode('FightPlayer', fight_data);
        	AIFightData[ai_id].code = code
		AIFightData[ai_id].capacity = capacity
	end
	
	return AIFightData[ai_id].code 
end

local function addPlayerFightData(pid, data)
	if data == "" then
		return 
	end
	playerFightData[pid] = {}
	local code = base64.decode(data)	
	local fight_data = decode(code, 'FightPlayer') 	

	for k, role in pairs(fight_data.roles) do
		local property = {}
		for _, v in ipairs(role.propertys) do
			property[v.type] = (property[v.type] or 0) + v.value
		end
		role.Property = Property(property);
	end


	local capacity = 0;
	for k, v in ipairs(fight_data.roles) do
		capacity = capacity + v.Property.capacity
	end

	playerFightData[pid].code = code
	playerFightData[pid].capacity = capacity
	playerFightData[pid].name = fight_data.name 
end

function ArenaPlayerPool:_init_()
	self._playerPool = {}
	self._playerPoolFast = {}
	self._playerPoolMap = {}
	local ok, result = database.query("SELECT pid, enemy_power_history, win_count, UNIX_TIMESTAMP(last_win_time) as last_win_time, fight_total_count, UNIX_TIMESTAMP(last_fight_time) as last_fight_time, UNIX_TIMESTAMP(last_reset_time) as last_reset_time, reward_flag, buff, inspire_count, fight_data, const_win_count FROM arena_player_pool")--ASC BY average_power")
    if ok and #result >= 1 then
       	 for i = 1, #result do
           	local row = result[i];
			local temp = {
				_pid = row.pid,
				--_average_power = row.average_power,
				_enemy_power_history = row.enemy_power_history,
				_win_count = row.win_count,
				_last_win_time = row.last_win_time,
				_fight_total_count = row.fight_total_count,
				_last_fight_time = row.last_fight_time,
				_last_reset_time = row.last_reset_time,
				_reward_flag = row.reward_flag,
				_buff = row.buff,
				_inspire_count = row.inspire_count,
				_const_win_count = row.const_win_count,
			}
			table.insert(self._playerPool, temp)
			self._playerPoolMap[row.pid] = temp 
			addPlayerFightData(row.pid, row.fight_data)
		
			local index = math.ceil(playerFightData[row.pid].capacity / STRIDE)
			self._playerPoolFast[index] = self._playerPoolFast[index] or {}
			table.insert(self._playerPoolFast[index], temp)
			temp._idx = index
			temp._idx2 = #self._playerPoolFast[index]
        end
    end
end

function ArenaPlayerPool:playerInPool(pid, funcName)
	if not self._playerPoolMap[pid] then
		if funcName then
			yqinfo("[%s] %d fail to %s, player not in player_pool", module_name, pid, funcName)
		end
		return false
	end
	return true
end

function ArenaPlayerPool:updateData(pid, key, value, value_type)
	local success 
	if value_type and value_type == "INT" then
		success = database.update("UPDATE arena_player_pool SET %s = %d WHERE pid = %d", key, value, pid)
	elseif value_type and value_type == "VARCHAR" then
		success = database.update("UPDATE arena_player_pool SET %s = '%s' WHERE pid = %d", key, value, pid)
	elseif value_type and value_type == "DATETIME" then
		success = database.update("UPDATE arena_player_pool SET %s = from_unixtime_s(%d) WHERE pid = %d", key, value, pid)
	end
	if not success then
		yqinfo("[%s] %d fail to update %s, mysql error", module_name, pid, key)
		return 1 
	end
	self._playerPoolMap[pid]["_"..key] = value
	return 0
end

function ArenaPlayerPool:updateFightData(pid, fight_data, capacity)
	database.update("UPDATE arena_player_pool SET fight_data = '%s' WHERE pid = %d", fight_data, pid)
	local new_idx = math.ceil(capacity / STRIDE)
	local p = self._playerPoolMap[pid] 
	if p and p._idx ~= new_idx then
		if p._idx2 < #self._playerPoolFast[p._idx] then
			for i = #self._playerPoolFast[p._idx], p.idx2 + 1 , -1 do
				self._playerPoolFast[p._idx][i]._idx2 = self._playerPoolFast[p._idx][i]._idx2 - 1
			end
		end

		table.remove(self._playerPoolFast[p._idx], p._idx2)	
		table.insert(self._playerPoolFast[new_idx], p)
		p._idx = new_idx
		p._idx2 = #self._playerPoolFast[new_idx]
	end
end

--function ArenaPlayerPool:getAveragePower(pid)
--	return self:playerInPool(pid, "getAveragePower") and self._playerPoolMap[pid]._average_power or nil
--end

function ArenaPlayerPool:getEnemyPowerHistory(pid)
	return self:playerInPool(pid, "getEnemyPowerHistory") and self._playerPoolMap[pid]._enemy_power_history or nil
end

function ArenaPlayerPool:getWinCount(pid)
	return self:playerInPool(pid, "getWinCount") and self._playerPoolMap[pid]._win_count or nil
end

function ArenaPlayerPool:getLastWinTime(pid)
	return self:playerInPool(pid, "getLastWinTime") and self._playerPoolMap[pid]._last_win_time or nil
end

function ArenaPlayerPool:getFightTotalCount(pid)
	return self:playerInPool(pid, "getFightTotalCount") and self._playerPoolMap[pid]._fight_total_count or nil
end

function ArenaPlayerPool:getLastFightTime(pid)
	return self:playerInPool(pid, "getLastFightTime") and self._playerPoolMap[pid]._last_fight_time or nil
end

function ArenaPlayerPool:getLastResetTime(pid)
	return self:playerInPool(pid, "getLastResetTime") and self._playerPoolMap[pid]._last_reset_time or nil
end

function ArenaPlayerPool:getRewardFlag(pid)
	return self:playerInPool(pid, "getRewardFlag") and self._playerPoolMap[pid]._reward_flag or nil
end

function ArenaPlayerPool:getBuff(pid)
	return self:playerInPool(pid, "getBuff") and self._playerPoolMap[pid]._buff or nil
end

function ArenaPlayerPool:getInspireCount(pid)
	return self:playerInPool(pid, "getInspireCount") and self._playerPoolMap[pid]._inspire_count or nil
end

function ArenaPlayerPool:getConstWinCount(pid)
	return self:playerInPool(pid, "getConstWinCount") and self._playerPoolMap[pid]._const_win_count or nil
end

--function ArenaPlayerPool:updateAveragePower(pid, value)
--	if self:playerInPool(pid, "setAveragePower") then
--		return self:updateData(pid, "average_power", value, "INT")	
--	end
--end

function ArenaPlayerPool:updateEnemyPowerHistory(pid, value)
	if self:playerInPool(pid, "updateEnemyPowerHistory") then
		return updateData(pid, "enemy_power_history", value, "VARCHAR")
	end
end

function ArenaPlayerPool:updateWinCount(pid, value)
	if self:playerInPool(pid, "updateWinCount") then
		return self:updateData(pid, "win_count", value, "INT")
	end
end

function ArenaPlayerPool:updateLastWinTime(pid, value)
	if self:playerInPool(pid, "updateLastWinTime") then
		return self:updateData(pid, "last_win_time", value, "DATETIME")
	end
end

function ArenaPlayerPool:updateFightTotalCount(pid, value)
	if self:playerInPool(pid, "updateFightTotalCount") then
		return self:updateData(pid, "fight_total_count", value, "INT")
	end
end

function ArenaPlayerPool:updateLastFightTime(pid, value)
	if self:playerInPool(pid, "updateLastFightTime") then
		return self:updateData(pid, "last_fight_time", value, "DATETIME")
	end
end

function ArenaPlayerPool:updateLastResetTime(pid, value)
	if self:playerInPool(pid, "updateLastResetTime") then
		return self:updateData(pid, "last_reset_time", value, "DATETIME")
	end
end

function ArenaPlayerPool:updateRewardFlag(pid, value)
	if self:playerInPool(pid, "updateRewardFlag") then
		return self:updateData(pid, "reward_flag", value, "INT")
	end
end

function ArenaPlayerPool:updateBuff(pid, value)
	if self:playerInPool(pid, "updateBuff") then
		return self:updateData(pid, "buff", value, "VARCHAR")
	end
end

function ArenaPlayerPool:updateInspireCount(pid, value)
	if self:playerInPool(pid, "updateInspireCount") then
		return self:updateData(pid, "inspire_count", value, "INT")
	end
end

function ArenaPlayerPool:updatePlayerPoolData(pid,enemyPowerHistory, winCount, lastWinTime, fightTotalCount, lastFightTime, lastResetTime, rewardFlag, buff, inspireCount, const_win_count)
	if self:playerInPool(pid, "updatePlayerPoolData") then
		if not database.update("UPDATE arena_player_pool SET enemy_power_history='%s',win_count=%d,last_win_time=from_unixtime_s(%d),fight_total_count=%d,last_fight_time=from_unixtime_s(%d),last_reset_time=from_unixtime_s(%d), reward_flag=%d, buff='%s',inspire_count=%d, const_win_count = %d WHERE pid = %d", enemyPowerHistory, winCount, lastWinTime, fightTotalCount, lastFightTime, lastResetTime, rewardFlag, buff, inspireCount, const_win_count, pid) then
			yqinfo("[%s] %d fail to updatePlayerPoolData, mysql error", module_name, pid)
			return 1
		else
			self._playerPoolMap[pid]._enemy_power_history = enemyPowerHistory
			self._playerPoolMap[pid]._win_count = winCount
			self._playerPoolMap[pid]._last_win_time = lastWinTime
			self._playerPoolMap[pid]._fight_total_count = fightTotalCount
			self._playerPoolMap[pid]._last_fight_time = lastFightTime
			self._playerPoolMap[pid]._last_reset_time = lastResetTime
			self._playerPoolMap[pid]._reward_flag = rewardFlag 
			self._playerPoolMap[pid]._buff = buff 
			self._playerPoolMap[pid]._inspire_count = inspireCount 
			self._playerPoolMap[pid]._const_win_count = const_win_count
			return 0
		end	
	end	
end

function ArenaPlayerPool:insertNewPlayer(pid)
	if not self:playerInPool(pid ) then
		if not database.update("INSERT INTO arena_player_pool(pid, enemy_power_history, win_count, last_win_time, fight_total_count, last_fight_time, last_reset_time, reward_flag, buff, inspire_count, fight_data, const_win_count)VALUES(%d, '%s', %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), from_unixtime_s(%d), %d, '%s', %d, '%s', %d)", pid, "", 0, 0, 0, 0, 0, 0, "", 0, "", 0) then
			yqinfo("[%s] %d fail to insertNewPlayer, mysql error", module_name, pid)
			return 1
		else	
			local temp = {
				_pid = pid,
				_enemy_power_history = "",
				_win_count = 0,
				_last_win_time = 0,
				_fight_total_count = 0,
				_last_fight_time = 0,	
				_last_reset_time = 0,
				_reward_flag = 0,
				_buff = "",
				_inspire_count = inspireCount,
				_const_win_count = 0,
			}
			table.insert(self._playerPool,temp)
			self._playerPoolMap[pid] = temp

			getPlayerFightData(pid, true)
			local index = math.ceil(playerFightData[pid].capacity / STRIDE)
			self._playerPoolFast[index] = self._playerPoolFast[index] or {}
			table.insert(self._playerPoolFast[index], temp)
			temp._idx = index
			temp._idx2 = #self._playerPoolFast[index]
			return 0
		end
	else
		yqinfo("[%s] %d fail to %s, player already in  player_pool", module_name, pid)
		return 0
	end	
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

function ArenaPlayerPool:calEnemyAveragePower(pid, powerString)
	local ret =str_split(powerString, '[| ]')	
	if #ret == 0 then
		--local cell_res = cell.getPlayer(pid)
		--local player = cell_res.player or nil
		--if player then
		--	return player.level*10	
		--else
			return 0
		--end
	end
	local sum = 0
	for k,v in ipairs(ret) do
		sum = sum + tonumber(v)
	end 
	return math.floor(sum/#ret)
end

function ArenaPlayerPool:getEnemyAveragePower(pid)
	if self:playerInPool(pid, "getEnemyAveragePower") then
		local enemy_power_history = self._playerPoolMap[pid]._enemy_power_history
		return self:calEnemyAveragePower(pid, enemy_power_history) 	
	end
end

function ArenaPlayerPool:getWinRate(pid)
	if self:playerInPool(pid, "getWinRate") then
		local win_count = self._playerPoolMap[pid]._win_count
		local fight_total_count = self._playerPoolMap[pid]._fight_total_count
		return fight_total_count == 0 and 101 or math.floor(win_count/fight_total_count*100) 
	end
end

function ArenaPlayerPool:getPlayerList()
	return self._playerPool
end

function ArenaPlayerPool:getPlayerFastList()
	return self._playerPoolFast
end
--[[function Load(force)
	if not single_instance or force then
		single_instance = Class.New(ArenaPlayerPool)
	end
end--]]

function Get()
	if not single_instance then 
		single_instance = Class.New(ArenaPlayerPool)
	end
	return single_instance
end

GetPlayerFightData = getPlayerFightData
GetAIFightData = getAIFightData
AddPlayerFightData = addPlayerFightData
Stride = STRIDE
