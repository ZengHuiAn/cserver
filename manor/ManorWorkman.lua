require "printtb"
local database = require "database"
local Command = require "Command"
local cell = require "cell"
require "yqlog_sys"
local yqwarn = yqwarn
local yqinfo = yqinfo
local yqerror = yqerror
local sprinttb = sprinttb
local setmetatable = setmetatable
local ipairs = ipairs
local pairs = pairs
local math = math
local os = os
local loop = loop
local assert = assert
local tostring = tostring
local table = table

module "ManorWorkman"

local debug = false
if not debug then
	yqdebug = function(...)
		return
	end
end

local ManorWorkman = {}

RECOVER_POWER_PER_FIVE_MIN = 0  --酒馆恢复体力速率
COST_POWER_PER_FIVE_MIN = 0 --工作中消耗体力速率
RECOVER_POWER_INLINE_PER_FIVE_MIN = 0 --产线上恢复体力速率

local function isEmptyOrNull(t)
    return t == nil or #t == 0
end

local function Exchange(pid, reward, consume, reason, manual, limit, name)
	assert(reason and reason ~= 0)

	if isEmptyOrNull(reward) and isEmptyOrNull(consume) then
		return true
	end

	local respond = cell.sendReward(pid, reward, consume, reason, manual, limit, name)
	if respond == nil or respond.result ~= 0 then
		return false;
	end
	return true;
end

local power_consume_config = nil
function LoadManorPowerConsumeConfig(id)
	if power_consume_config == nil then
		power_consume_config = {}
		local success, result = database.query("select * from config_manor_energy");
		if success then
			for _, row in ipairs(result) do
				power_consume_config[row.id] =	{
					type = row.type,
					id = row.id,
					value = row.value,
					add_energy = row.add_energy,
					add_storage1 = row.add_storage1,	
					add_storage2 = row.add_storage2,
					add_storage3 = row.add_storage3,	
					add_storage4 = row.add_storage4 or 0,	
					add_storage5 = row.add_storage5 or 0,	
					add_storage6 = row.add_storage6 or 0,	
					add_storage_pool = row.add_storage_pool or 0,
				}
			end
		end
	end	
	return power_consume_config[id]
end

local workman_power_property_config = nil
function LoadWorkmanPowerPropertyConfig(hero_id, type)
	if workman_power_property_config == nil then
		workman_power_property_config = {}
		local success, result = database.query("select * from config_manor_property")
		if success then
			for _, row in ipairs(result) do
				workman_power_property_config[row.id] = workman_power_property_config[row.id] or {}
				workman_power_property_config[row.id][row.type] = workman_power_property_config[row.id][row.type] or {}
				workman_power_property_config[row.id][row.type] = {
					init1 = row.init1,
					lv_value1 = row.lv_value1,
					rank_value1 = row.rank_value1,
					star_value1 = row.star_value1,
				}
			end
		end
	end
	return (workman_power_property_config[hero_id] and workman_power_property_config[hero_id][type]) and workman_power_property_config[hero_id][type] or {init1 = 50, lv_value1 = 2, rank_value1 = 5, star_value1 = 8} 
end

function ManorWorkman.New(pid)
	return setmetatable({
		pid = pid,
		workman_list = {

		},
	},{__index = ManorWorkman})
end

function ManorWorkman:Load()
	local success, result = database.query("select workman_id, now_power, power_upper_limit, is_busy, UNIX_TIMESTAMP(last_power_change_time) as last_power_change_time, busy_time, free_time from manor_workman_power where pid = %d", self.pid)
	if not success then
		return 
	end

	for _, row in ipairs(result) do
		self.workman_list[row.workman_id] = self.workman_list[row.workman_id] or {}
		self.workman_list[row.workman_id].workman_id = row.workman_id
		self.workman_list[row.workman_id].now_power = row.now_power
		self.workman_list[row.workman_id].power_upper_limit = row.power_upper_limit
		self.workman_list[row.workman_id].is_busy = row.is_busy  
		self.workman_list[row.workman_id].last_power_change_time = row.last_power_change_time
		self.workman_list[row.workman_id].busy_time = row.busy_time
		self.workman_list[row.workman_id].free_time = row.free_time
		self.workman_list[row.workman_id].db_exists = true
	end
end

--local uuid_to_gid = {}
function ManorWorkman:GetWorkmanInfo(workman_id)
	local b = os.clock()
	if not workman_id or workman_id == 0 then
		return
	end
	if not self.workman_list[workman_id] then
		yqdebug("load  workman info>>>>")
		local playerHeroInfo = cell.getPlayerHeroInfo(self.pid, 0, workman_id)	
		--uuid_to_gid[workman_id] = nil
		if not playerHeroInfo then
			yqinfo("fail to GetWorkmanInfo, cannnot get hero info for hero:%d", workman_id)	
			return 
		end
		--uuid_to_gid[workman_id] = playerHeroInfo.gid
		local cfg = LoadWorkmanPowerPropertyConfig(playerHeroInfo.gid, 701)
		if not cfg then
			yqinfo("fail to GetWorkmanInfo, cannnot get power property config for hero:%d", workman_id)	
			return
		end
		local power_upper_limit = cfg.init1 + playerHeroInfo.level * cfg.lv_value1 + playerHeroInfo.stage * cfg.rank_value1 + playerHeroInfo.star * cfg.star_value1
		self.workman_list[workman_id] = {
			workman_id = workman_id,
			now_power = power_upper_limit,
			power_upper_limit = power_upper_limit,
			is_busy = 0,
			last_power_change_time = 0,
			busy_time = 0,
			free_time = 0,
			db_exists = true,	
		}
		database.update("insert into manor_workman_power(pid, workman_id, now_power, power_upper_limit, is_busy, last_power_change_time, busy_time, free_time)values(%d, %d, %d, %d, %d, from_unixtime_s(%d), %d, %d)", self.pid, workman_id, power_upper_limit, power_upper_limit, 0, 0, 0, 0)
	end	

	yqdebug("getworkmaninfo   last_time:%f", os.clock() - b)
	return self.workman_list[workman_id]
end

function ManorWorkman:ReloadWorkmanInfo(workman_id)
	if not workman_id or workman_id == 0 then
		return
	end
	self:GetWorkmanInfo(workman_id)
	local playerHeroInfo = cell.getPlayerHeroInfo(self.pid, 0, workman_id)	
	if not playerHeroInfo then
		return 
	end
	local hero_id = playerHeroInfo.gid
	local cfg = LoadWorkmanPowerPropertyConfig(hero_id, 701)
	if not cfg then
		yqinfo("fail to ReloadWorkmanInfo, cannnot get power property config for hero:%d", workman_id)	
		return
	end
	new_power_upper_limit = cfg.init1 + playerHeroInfo.level * cfg.lv_value1 + playerHeroInfo.stage * cfg.rank_value1 + playerHeroInfo.star * cfg.star_value1	
	if new_power_upper_limit > self.workman_list[workman_id].power_upper_limit then
		self.workman_list[workman_id].now_power = self.workman_list[workman_id].now_power + new_power_upper_limit - self.workman_list[workman_id].power_upper_limit
		self.workman_list[workman_id].power_upper_limit = new_power_upper_limit
		database.update("update manor_workman_power set now_power = %d, power_upper_limit = %d where pid = %d and workman_id = %d", self.workman_list[workman_id].now_power, self.workman_list[workman_id].power_upper_limit, self.pid, workman_id)
		return true
	elseif new_power_upper_limit < self.workman_list[workman_id].power_upper_limit then
		self.workman_list[workman_id].now_power = (self.workman_list[workman_id].now_power + new_power_upper_limit - self.workman_list[workman_id].power_upper_limit) >= 0 and (self.workman_list[workman_id].now_power + new_power_upper_limit - self.workman_list[workman_id].power_upper_limit)
		self.workman_list[workman_id].power_upper_limit = new_power_upper_limit
		database.update("update manor_workman_power set now_power = %d, power_upper_limit = %d where pid = %d and workman_id = %d", self.workman_list[workman_id].now_power, self.workman_list[workman_id].power_upper_limit, self.pid, workman_id)
		return true
	end
	return false
end

function ManorWorkman:GetWorkmanPower(workman_id, time)
	if not workman_id or workman_id == 0 then
		return
	end
	local info = self:GetWorkmanInfo(workman_id)
	if not info then
		return 
	end
	local calc_time = time and time or loop.now()
	yqinfo("Player:%d Begin GetWorkmanPower workman:%d  now_power:%d is_busy:%d calc_time:%d,  last_power_change_time:%d, busy_time:%d  free_time:%d", self.pid, workman_id, info.now_power, info.is_busy, calc_time, info.last_power_change_time, info.busy_time, info.free_time)
	assert(calc_time >= info.last_power_change_time)
	if info.is_busy == 1 then
		if info.now_power - math.floor((calc_time + info.busy_time - info.last_power_change_time)/ (1 * 60)) * COST_POWER_PER_FIVE_MIN > 0 then
			return info.now_power - math.floor((calc_time + info.busy_time - info.last_power_change_time)/ (1 * 60)) * COST_POWER_PER_FIVE_MIN, calc_time + info.busy_time - info.last_power_change_time - math.floor((calc_time + info.busy_time - info.last_power_change_time)/ (1 * 60)) * 60
		else
			return 0, 0
		end
	elseif info.is_busy == 0 then
		if info.now_power + math.floor((calc_time + info.free_time - info.last_power_change_time)/ (1 * 60)) * RECOVER_POWER_PER_FIVE_MIN < info.power_upper_limit then 
			return info.now_power + math.floor((calc_time + info.free_time - info.last_power_change_time)/ (1 * 60)) * RECOVER_POWER_PER_FIVE_MIN, calc_time + info.free_time - info.last_power_change_time - math.floor((calc_time + info.free_time - info.last_power_change_time)/ (1 * 60)) * 60
		else
			return info.power_upper_limit, 0
		end
	elseif info.is_busy == 2 then
		if info.now_power + math.floor((calc_time + info.free_time - info.last_power_change_time)/ (1 * 60)) * RECOVER_POWER_INLINE_PER_FIVE_MIN < info.power_upper_limit then 
			return info.now_power + math.floor((calc_time + info.free_time - info.last_power_change_time)/ (1 * 60)) * RECOVER_POWER_INLINE_PER_FIVE_MIN, calc_time + info.free_time - info.last_power_change_time - math.floor((calc_time + info.free_time - info.last_power_change_time)/ (1 * 60)) * 60
		else
			return info.power_upper_limit, 0
		end
	end	
end

function ManorWorkman:GetWorkmanPowerNextChangeTime(workman_id, time)
	if not workman_id or workman_id == 0 then
		return
	end
	local info = self:GetWorkmanInfo(workman_id)
	if not info then
		return 
	end
	local calc_time = time and time or loop.now()
	assert(calc_time >= info.last_power_change_time)
	if info.is_busy == 1 then
		local left_time = (60 - (calc_time + info.busy_time - info.last_power_change_time - math.floor((calc_time + info.busy_time - info.last_power_change_time)/ (1 * 60)) * 60)) 
		return left_time == 0 and calc_time + 60 or calc_time + left_time
	else
		local left_time = (60 - (calc_time + info.free_time - info.last_power_change_time - math.floor((calc_time + info.free_time - info.last_power_change_time)/ (1 * 60)) * 60)) 
		return left_time == 0 and calc_time + 60 or calc_time + left_time
	end
end

function ManorWorkman:GetWorkmanPowerUpperLimit(workman_id)
	if not workman_id or workman_id == 0 then
		return
	end
	local info = self:GetWorkmanInfo(workman_id)
	if not info then
		return	
	end
	return info.power_upper_limit
end

function ManorWorkman:GetWorkmanBusyStatus(workman_id)
	if not workman_id or workman_id == 0 then
		return
	end
	local info = self:GetWorkmanInfo(workman_id)
	if not info then
		return	
	end
	return info.is_busy
end

function ManorWorkman:ChangeWorkmanBusyStatus(workman_id, is_busy, time)
	if not workman_id or workman_id == 0 then
		return
	end
	yqinfo("begin to change busy workman_id:%d  is_busy:%d",  workman_id, is_busy)
	if time then
		yqinfo("ChangeWorkmanBusyStatus    time:%d", time)
	end
	local info = self:GetWorkmanInfo(workman_id)
	if not info then
		return 
	end
	local power, extra_time = self:GetWorkmanPower(workman_id, time)	
	if is_busy ~= info.is_busy then
		--self:UpdateWorkmanPower(workman_id, power, time, busy_time, free_time)
		--local info = self:GetWorkmanInfo(workman_id)	
		info.now_power = power
		info.last_power_change_time = time
		if info.is_busy == 1 then
			info.busy_time = extra_time  
		else
			info.free_time = extra_time
		end
		info.is_busy = is_busy
		if info.db_exists then
			database.update("update manor_workman_power set is_busy = %d, now_power = %d, last_power_change_time = from_unixtime_s(%d), busy_time = %d, free_time = %d where pid = %d and workman_id = %d", info.is_busy, power, time, info.busy_time, info.free_time, self.pid, workman_id)
		else
			database.update("insert into manor_workman_power(pid, workman_id, now_power, power_upper_limit, is_busy, last_power_change_time, busy_time, free_time)values(%d, %d, %d, %d, %d, from_unixtime_s(%d), %d, %d)", self.pid, workman_id, info.now_power, info.power_upper_limit, is_busy, info.last_power_change_time, 0, 0)
			info.db_exists = true
		end
	end
end


function ManorWorkman:IncreaseWorkmanPower(workman_id, consume_type, consume_id, consume_value, count)
	yqinfo("Player %d begin to increase workman power  workman_id:%d", self.pid, workman_id)
	local add_value = 0
	if not workman_id or workman_id == 0 then
		return	
	end
	local info = self:GetWorkmanInfo(workman_id) 
	if not info then
		return
	end
	local power, extra_time = self:GetWorkmanPower(workman_id)	
	local power_upper_limit = self:GetWorkmanPowerUpperLimit(workman_id)
	local consume_cfg = LoadManorPowerConsumeConfig(consume_id)
	local consume = {}
	if not consume_cfg then
		yqinfo("Player %d fail to increase workman power , dont has consume config for id:%d", self.pid, consume_id)
		return 
	end
	if consume_type ~= consume_cfg.type or consume_value ~= consume_cfg.value then
		yqinfo("Player %d fail to increase workman power , client consume config dont fit with server consume config", self.pid)
		return
	end
	table.insert(consume, {type = consume_cfg.type, id = consume_cfg.id, value = consume_cfg.value * count})
	add_value = consume_cfg.add_energy * count
	if not Exchange(self.pid, nil, consume, Command.REASON_MANOR_MANUFACTURE_INCREASE_POWER, false, nil, nil) then
		yqinfo("Player %d fail to increase workman power , consume fail", self.pid)
		return 
	end
	if power == power_upper_limit then
		yqinfo("Player %d fail to increase workman power, power already max", self.pid)
		return 
	end
	if power + add_value > power_upper_limit then
		yqwarn("Player %d  to increase workman power , add_value too big", self.pid)
		add_value = power_upper_limit - power
	end
	info.now_power = power + add_value
	info.last_power_change_time = loop.now()
	if info.is_busy == 1 then
		info.busy_time = extra_time  
	else
		info.free_time = extra_time
	end
	database.update("update manor_workman_power set now_power = %d, last_power_change_time = from_unixtime_s(%d), busy_time = %d, free_time = %d where pid = %d and workman_id = %d", info.now_power, loop.now(), info.busy_time, info.free_time, self.pid, workman_id)
	return true
end

function ManorWorkman:decreaseWorkmanPower(workman_id, count)
	yqinfo("decreaseWorkmanPower: %d decrease workman %d power %d", self.pid, workman_id, count)
	if not workman_id or workman_id == 0 then
		yqinfo("decreaseWorkmanPower: invalid workman_id")
		return
	end	
	local info = self:GetWorkmanInfo(workman_id)
	if not info then
		yqinfo("decreaseWorkmanPower: get workman info failed.")
		return
	end

	local power, extra_time = self:GetWorkmanPower(workman_id)	
	
	if power < count then
		yqinfo("decreaseWorkmanPower: power not enough.")
		return 
	end
	info.now_power = power - count
	info.last_power_change_time = loop.now()
	if info.is_busy == 1 then
		info.busy_time = extra_time  
	else
		info.free_time = extra_time
	end
	database.update("update manor_workman_power set now_power = %d, last_power_change_time = from_unixtime_s(%d), busy_time = %d, free_time = %d where pid = %d and workman_id = %d", info.now_power, loop.now(), info.busy_time, info.free_time, self.pid, workman_id)
	return true
end

function ManorWorkman:AddWorkmanPower(workman_id, add_value)
	if not workman_id or workman_id == 0 then
		return	
	end
	local info = self:GetWorkmanInfo(workman_id) 
	if not info then
		return
	end
	local power, extra_time = self:GetWorkmanPower(workman_id)	
	local power_upper_limit = self:GetWorkmanPowerUpperLimit(workman_id)
	if power == power_upper_limit then
		yqinfo("Player %d fail to increase workman power, power already max", self.pid)
		return 
	end
	if power + add_value > power_upper_limit then
		yqwarn("Player %d  to increase workman power , add_value too big", self.pid)
		add_value = power_upper_limit - power
	end
	info.now_power = power + add_value
	info.last_power_change_time = loop.now()
	if info.is_busy == 1 then
		info.busy_time = extra_time  
	else
		info.free_time = extra_time
	end
	database.update("update manor_workman_power set now_power = %d, last_power_change_time = from_unixtime_s(%d), busy_time = %d, free_time = %d where pid = %d and workman_id = %d", info.now_power, loop.now(), info.busy_time, info.free_time, self.pid, workman_id)
	return true
end

local ManorWorkmanList = {}

function Get(pid)
	if ManorWorkmanList[pid] == nil then
		ManorWorkmanList[pid] = ManorWorkman.New(pid);
		ManorWorkmanList[pid]:Load();
	end
	return ManorWorkmanList[pid];
end

function Unload(pid)
	if ManorWorkmanList[pid] then
		ManorWorkmanList[pid] = nil
	end
end

--[[function GetWorkmanGID(pid, uuid)
	if not uuid or uuid == 0 then
		return 0
	end

	if uuid_to_gid[uuid] then
		return uuid_to_gid[uuid]
	else
		local playerHeroInfo = cell.getPlayerHeroInfo(pid, 0, uuid)	
		if not playerHeroInfo then
			return 0
		end

		uuid_to_gid[uuid] = playerHeroInfo.gid 
		return uuid_to_gid[uuid]
	end	
end--]]
