require "Class"
require "yqlog_sys"
require "printtb"
local database = require "database"
local Class = Class
local yqinfo = yqinfo
local sprinttb = sprinttb
local ipairs = ipairs
local pairs = pairs
local math = math
local table = table
local base64 = require "base64"
local protobuf = require "protobuf"
local Property = require "Property"
module "ArenaFightRecord"

local module_name = "ArenaFightRecord"
local pid2instance = {}
local ArenaFightRecord = {}

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

function ArenaFightRecord:_init_(pid)
	self._pid = pid
	self._fight_record = {}
	self._fight_record_map = {}
	local ok, result = database.query("SELECT pid, enemy_id, has_win, fight_count, UNIX_TIMESTAMP(last_fight_time) as last_fight_time, buff_increase_percent, fight_data, reward_id FROM arena_fight_record WHERE pid = %d", pid)
    if ok and #result >= 1 then
       	 for i = 1, #result do
           	local row = result[i];
			
			local code = base64.decode(row.fight_data)	
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

			local temp = {
				_enemy_id = row.enemy_id,
				_has_win = row.has_win,
				_fight_count = row.fight_count,
				_last_fight_time = row.last_fight_time,
				_buff_increase_percent = row.buff_increase_percent,
				_fight_data = code,
				_capacity = capacity,
				_reward_id = row.reward_id
			}
			self._fight_record_map[row.enemy_id] = temp
			table.insert(self._fight_record, temp)
        end
    end
end

function ArenaFightRecord:getAllFightRecord()
	local fightRecord = {}
	for k, v in ipairs(self._fight_record) do
		table.insert(fightRecord, {enemy_id = v._enemy_id, has_win = v._has_win, fight_count = v._fight_count, last_fight_time = v._last_fight_time, buff_increase_percent = v._buff_increase_percent, fight_data = v._fight_data, capacity = v._capacity, reward_id = v._reward_id})
	end
	return fightRecord
end

function ArenaFightRecord:getHasWin(enemyID)
	if not self._fight_record_map[enemyID] then
		yqinfo("[%s] %d fail to getHasWin, enemy %d not in config", module_name, self._pid, enemyID)
		return nil
	end
	return self._fight_record_map[enemyID]._has_win
end

function ArenaFightRecord:getFightCount(enemyID)
	if not self._fight_record_map[enemyID] then
		yqinfo("[%s] %d fail to getFightCount, enemy %d not in config", module_name, self._pid, enemyID)
		return nil 
	end		
	return self._fight_record_map[enemyID]._fight_count 
end

function ArenaFightRecord:getLastFightTime(enemyID)
	if not self._fight_record_map[enemyID] then
		yqinfo("[%s] %d fail to getLastFightTime, enemy %d not in config", module_name, self._pid, enemyID)
		return nil 
	end		
	return self._fight_record_map[enemyID]._last_fight_time 
end

function ArenaFightRecord:getBuffIncreasePercent(enemyID)
	if not self._fight_record_map[enemyID] then
		yqinfo("[%s] %d fail to getBuffIncreasePercent, enemy %d not in config", module_name, self._pid, enemyID)
		return nil
	end
	return self._fight_record_map[enemyID]._buff_increase_percent
end

function ArenaFightRecord:getFightData(enemyID)
	if not self._fight_record_map[enemyID] then
		yqinfo("[%s] %d fail to getFightData, enemy %d not in config", module_name, self._pid, enemyID)
		return nil
	end	
	return self._fight_record_map[enemyID]._fight_data
end

function ArenaFightRecord:getCapacity(enemyID)
	if not self._fight_record_map[enemyID] then
		yqinfo("[%s] %d fail to getCapacity, enemy %d not in config", module_name, self._pid, enemyID)
		return nil
	end	
	return self._fight_record_map[enemyID]._capacity
end

function ArenaFightRecord:getRewardID(enemyID)
	if not self._fight_record_map[enemyID] then
		yqinfo("[%s] %d fail to getRewardID, enemy %d not in config", module_name, self._pid, enemyID)
		return nil
	end	
	return self._fight_record_map[enemyID]._reward_id
end

function ArenaFightRecord:updateHasWin(enemyID, hasWin)
	if not self._fight_record_map[enemyID] then
		yqinfo("[%s] %d fail to updateHasWin, enemy %d not in config", module_name, self._pid, enemyID)
		return 1
	end		
	if self._fight_record_map[enemyID]._has_win == hasWin then
		return 0
	end
	if not database.update("UPDATE arena_fight_record SET has_win = %d WHERE pid = %d AND enemy_id = %d", hasWin, self._pid, enemyID) then
		yqinfo("[%s] %d fail to updateHasWin, mysql error", module_name, self._pid)
		return 1
	end
	self._fight_record_map[enemyID]._has_win = hasWin
	return 0
end

function ArenaFightRecord:updateFightCount(enemyID, fightCount)
	if not self._fight_record_map[enemyID] then
		yqinfo("[%s] %d fail to updateFightCount, enemy %d not in config", module_name, self._pid, enemyID)
		return 1 
	end		
	if self._fight_record_map[enemyID]._fight_count == fightCount then
		return 0
	end
	if not database.update("UPDATE arena_fight_record SET fight_count = %d WHERE pid = %d AND enemy_id = %d", fightCount, self._pid, enemyID) then
		yqinfo("[%s] %d fail to updateHasWin, mysql error", module_name, self._pid)
		return 1
	end
	self._fight_record_map[enemyID]._fight_count = fightCount 
	return 0
end

function ArenaFightRecord:updateLastFightTime(enemyID, lastFightTime)
	if not self._fight_record_map[enemyID] then
		yqinfo("[%s] %d fail to updateLastFightTime, enemy %d not in config", module_name, self._pid, enemyID)
		return 1
	end		
	if self._fight_record_map[enemyID].last_fight_timel == lastFightTime then
		return 0
	end
	if not database.update("UPDATE arena_fight_record SET last_fight_time = from_unixtime_s(%d) WHERE pid = %d AND enemy_id = %d", lastFightTime, self._pid, enemyID) then
		yqinfo("[%s] %d fail to updateHasWin, mysql error", module_name, self._pid)
		return 1
	end
	self._fight_record_map[enemyID]._last_fight_time = lastFightTime 
	return 0
end

function ArenaFightRecord:updateBuffIncreasePercent(enemyID, buffIncreasePercent)
	if not self._fight_record_map[enemyID] then
		yqinfo("[%s] %d fail to updateBuffIncreasePercent, enemy %d not in config", module_name, self._pid, enemyID)
		return 1 
	end		
	if self._fight_record_map[enemyID]._buff_increase_percent == buffIncreasePercent then
		return 0
	end
	if not database.update("UPDATE arena_fight_record SET buff_increase_percent = %d WHERE pid = %d AND enemy_id = %d", buffIncreasePercent, self._pid, enemyID) then
		yqinfo("[%s] %d fail to updateBuffIncreasePercent, mysql error", module_name, self._pid)
		return 1
	end
	self._fight_record_map[enemyID]._buff_increase_percent = buffIncreasePercent 
	return 0
end

function ArenaFightRecord:updateFightRecord(enemyID, hasWin, fightCount, lastFightTime, buffIncreasePercent)
	if not self._fight_record_map[enemyID] then
		yqinfo("[%s] %d fail to updateFightRecord, enemy %d not in config", module_name, self._pid, enemyID)
		return 1 
	end		
	if not database.update("UPDATE arena_fight_record SET has_win=%d,fight_count=%d,last_fight_time=from_unixtime_s(%d),buff_increase_percent=%d WHERE pid = %d AND enemy_id = %d", hasWin, fightCount, lastFightTime, buffIncreasePercent, self._pid, enemyID) then
		yqinfo("[%s] %d fail to updateFightRecord, mysql error", module_name, self._pid)
		return 1
	end
	self._fight_record_map[enemyID]._has_win = hasWin 
	self._fight_record_map[enemyID]._fight_count = fightCount 
	self._fight_record_map[enemyID]._last_fight_time = lastFightTime 
	self._fight_record_map[enemyID]._buff_increase_percent = buffIncreasePercent 
	return 0
end

function ArenaFightRecord:deleteAllFightRecord()
	if #self._fight_record == 0 then
		return 0
	end
	if not database.update("DELETE FROM arena_fight_record WHERE pid = %d", self._pid) then
		yqinfo("[%s] %d fail to deleteAllFightRecord, mysql error", module_name, self._pid)
		return 1
	end
	self._fight_record = {}
	self._fight_record_map = {}
	return 0	
end

function ArenaFightRecord:addNewFightRecord(enemyID, buffIncreasePercent, fightData, reward_id)
	if self._fight_record_map[enemyID] then
		yqinfo("[%s] %d fail to addNewFightRecord, enemy %d already exist", module_name, self._pid, enemyID)
		return 1
	end
	if not database.update("INSERT INTO arena_fight_record(pid, enemy_id, has_win, fight_count, last_fight_time, buff_increase_percent, fight_data, reward_id)VALUES(%d,%d,%d,%d,from_unixtime_s(%d),%d, '%s', %d)", self._pid, enemyID, 0, 0, 0, buffIncreasePercent, fightData, reward_id) then
		yqinfo("[%s] %d fail to addNewFightRecord for enemy %d, mysql error", module_name, self._pid, enemyID)
		return 1
	end

	local code = base64.decode(fightData)	
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

	local temp = {
		_enemy_id = enemyID,
		_has_win = 0,
		_fight_count = 0,	
		_last_fight_time = 0,
		_buff_increase_percent = buffIncreasePercent,
		_fight_data = code,
		_capacity = capacity,
		_reward_id = reward_id
	}
	table.insert(self._fight_record, temp)
	self._fight_record_map[enemyID] = temp
	return 0
end

function ArenaFightRecord:hasWinAllGame()
	local hasWinAllGame = true 
	for k, v in ipairs(self._fight_record or {}) do
		if v._has_win == 0 then
			hasWinAllGame = false
			break
		end
	end
	return hasWinAllGame
end

function ArenaFightRecord:getThisRoundWinCount()
	local sum = 0 
	for k, v in ipairs(self._fight_record or {}) do
		if v._has_win == 1 then
			sum = sum + 1	
		end
	end
	return sum
end

function Get(pid)
	if not pid2instance[pid] then 
		pid2instance[pid] = Class.New(ArenaFightRecord, pid)
	end
	return pid2instance[pid]
end
