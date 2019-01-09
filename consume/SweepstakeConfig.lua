package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";

local loop = loop;
local log  = log;
local Class = require "Class"
local database = require "database"
require "consume_config"
require "Scheduler"
--require "point_reward_config"
require "cell"
require "printtb"
--require "YQSTR"
--require "Bonus"
--require "broadcast"
--require "RewardQueue"
--require "XMLConfig"

local StableTime =require "StableTime"
local get_today_begin_time =StableTime.get_today_begin_time
local get_begin_time_of_day = StableTime.get_begin_time_of_day 

local type = type
local pairs = pairs
local ipairs = ipairs
local string = string
local print = print
local math = math
local next = next
local log = log
local loop = loop;
local coroutine = coroutine
local table = table
local tostring = tostring
local tonumber = tonumber;
local Scheduler = require "Scheduler"
local database = require "database"
local Class = require "Class"
require "Thread"
local Sleep = Sleep
local Command = require "Command"
local os = os
require "printtb"
local sprinttb = sprinttb
local yqinfo = yqinfo

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

local function includePoolType(pool_type_range,pool_type)
	local ret_pool =str_split(pool_type_range, '[| ]')	
	for k,v in ipairs(ret_pool) do
		if tonumber(v) == pool_type then
			return true
		end
	end 
	return false
end

module "SweepstakeConfig"

local SweepstakeConfig = {} 
local g_instance = nil

function SweepstakeConfig:_init_()
	self._listConfig = {}
	self._mapConfig = {}
end

function SweepstakeConfig:reloadConfig()
	self._listConfig = {}
	self._mapConfig = {}
	local validTime = get_today_begin_time()-30*24*3600  --有效时间10天，大于10天的配置不load
	-- activity_type 活动类型 如：限时神将奖池  player_data_id 用户数据ID（免费时间，抽奖次数） reward_config_id 结算奖励配置ID status 活动状态（0结算未结束，1结算结束）
	local ok, result = database.query("SELECT id, pool_type, UNIX_TIMESTAMP(begin_time) as begin_time, UNIX_TIMESTAMP(end_time) as end_time, activity_type, player_data_id, reward_config_id, free_gap, init_time, guarantee_count, init_count, consume_type, consume_id, price, combo_price, combo_count, change_pool_consume_type, change_pool_consume_id, change_pool_consume_value, first_change_pool_free, count_item_type, count_item_id, count_item_value FROM sweepstakeconfig WHERE UNIX_TIMESTAMP(end_time) > %d  ORDER BY activity_type ASC, begin_time ASC",validTime);
    if ok and #result >= 1 then
       	 for i = 1, #result do
           	local row = result[i];
            self._mapConfig[row.id] = {}
            self._mapConfig[row.id].id = row.id;
            self._mapConfig[row.id].pool_type = row.pool_type;
            self._mapConfig[row.id].begin_time = row.begin_time;
            self._mapConfig[row.id].end_time = row.end_time-1;
            self._mapConfig[row.id].activity_type = row.activity_type;
            self._mapConfig[row.id].player_data_id = row.player_data_id;
            self._mapConfig[row.id].reward_config_id = row.reward_config_id;
			self._mapConfig[row.id].free_gap = row.free_gap;
			self._mapConfig[row.id].init_time = row.init_time;
			self._mapConfig[row.id].guarantee_count = row.guarantee_count;
			self._mapConfig[row.id].init_count = row.init_count;
			self._mapConfig[row.id].consume_type = row.consume_type;
			self._mapConfig[row.id].consume_id = row.consume_id;
			self._mapConfig[row.id].price = row.price;
			self._mapConfig[row.id].combo_price = row.combo_price;
			self._mapConfig[row.id].combo_count = row.combo_count;
			self._mapConfig[row.id].change_pool_consume_type = row.change_pool_consume_type;
			self._mapConfig[row.id].change_pool_consume_id = row.change_pool_consume_id;
			self._mapConfig[row.id].change_pool_consume_value = row.change_pool_consume_value;
			self._mapConfig[row.id].change_pool_first_free = row.change_pool_first_free;
			self._mapConfig[row.id].count_item_type = row.count_item_type;
			self._mapConfig[row.id].count_item_id = row.count_item_id;
			self._mapConfig[row.id].count_item_value = row.count_item_value;
            --self._mapConfig[row.id].status = 0;--row.status;
			self._listConfig[i] = self._mapConfig[row.id] 
        end
    end
end

function SweepstakeConfig:getListConfig()
	return self._listConfig;
end

function SweepstakeConfig:getMapConfig()
	return self._mapConfig;
end

function SweepstakeConfig:checkIDAndPoolTypeVaild(id,pool_type)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return false
	end	
	local cfg_pool_type = cfg_item.pool_type
	if not cfg_pool_type then
		return false
	end
	if includePoolType(cfg_pool_type,pool_type) then
		return true
	end	
	return false
end

function SweepstakeConfig:getPlayerDataIDByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	local cfg_playerDataID = cfg_item.player_data_id
	if not cfg_playerDataID then
		return nil
	end
	return cfg_playerDataID
end

function SweepstakeConfig:getActivityTypeByID(id)
    local cfg_item = self._mapConfig[id]
    if not cfg_item then
        return nil
    end
    local activity_type = cfg_item.activity_type
    if not activity_type then
        return nil
    end
    return activity_type
end

function SweepstakeConfig:getFreeTimeGapByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	local cfg_free_gap = cfg_item.free_gap
	if not cfg_free_gap then
		return nil
	end
	return cfg_free_gap
end

function SweepstakeConfig:getConsumeTypeByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	local cfg_consume_type = cfg_item.consume_type
	if not cfg_consume_type then
		return nil
	end
	return cfg_consume_type
end

function SweepstakeConfig:getConsumeIDByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	local cfg_consume_id = cfg_item.consume_id
	if not cfg_consume_id then
		return nil
	end
	return cfg_consume_id
end

function SweepstakeConfig:getPriceByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	local cfg_price = cfg_item.price
	if not cfg_price then
		return nil
	end
	return cfg_price
end

function SweepstakeConfig:getCountItemByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	local count_item_type = cfg_item.count_item_type
	local count_item_id = cfg_item.count_item_id
	local count_item_value = cfg_item.count_item_value
	if not count_item_type or not count_item_id or not count_item_value then
		return nil
	end
	return {type = count_item_type, id = count_item_id, value = count_item_value}, {count_item_type, count_item_id, count_item_value}
end

function SweepstakeConfig:getComboPriceByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	local cfg_combo_price = cfg_item.combo_price
	if not cfg_combo_price then
		return nil
	end
	return cfg_combo_price
end

function SweepstakeConfig:getComboCountByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	local cfg_combo_count = cfg_item.combo_count
	if not cfg_combo_count then
		return nil
	end
	return cfg_combo_count
end

function SweepstakeConfig:getGuaranteeCountByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	local cfg_guarantee_count = cfg_item.guarantee_count
	if not cfg_guarantee_count then
		return nil
	end
	return cfg_guarantee_count
end

function SweepstakeConfig:getInitCountByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	local cfg_init_count = cfg_item.init_count
	if not cfg_init_count then
		return nil
	end
	return cfg_init_count
end

function SweepstakeConfig:getInitTimeByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	local cfg_init_time = cfg_item.init_time
	if not cfg_init_time then
		return nil
	end
	return cfg_init_time
end

function SweepstakeConfig:getCfgByDataID(player_data_id)
	for k, v in ipairs(self._listConfig) do
		if v.player_data_id == player_data_id then
			return self._listConfig[k] 
		end
	end	
end

function SweepstakeConfig:getActivityTimeByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil,nil
	end
	local cfg_begin_time = cfg_item.begin_time
	local cfg_end_time = cfg_item.end_time
	if not cfg_begin_time or not cfg_end_time then
		return nil,nil
	end
	return cfg_begin_time,cfg_end_time
end

function SweepstakeConfig:getRewardCfgIDByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	local cfg_reward_config_id = cfg_item.reward_config_id
	if not cfg_reward_config_id then
		return nil
	end
	return cfg_reward_config_id
end

function SweepstakeConfig:getStatusByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	--local cfg_status = cfg_item.status
	if not cfg_item.status then
		local ok, result = database.query("SELECT settle_status FROM sweepstakesettlestatus where id=%d",id);
	    if ok and #result >= 1 then
			local row = result[i]
			cfg_item.status = row.status
        elseif ok then
			cfg_item.status = 0
		end 
    end
	--if not cfg_status then
	--	return nil
	--end
	return cfg_item.status 
end

function SweepstakeConfig:closeSweepstakeByID(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	local cfg_status = self:getStatusByID(id)--cfg_item.status
	if cfg_status ~= 1 then
		cfg_item.status = 1
		database.update("REPLACE sweepstakesettlestatus(id,settle_status)values(%d,%d)",id,1);
	end
end

function SweepstakeConfig:getChangePoolConsume(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return nil
	end
	if cfg_item.change_pool_consume_type == 0 or cfg_item.change_pool_consume_id == 0 or cfg_item.change_pool_consume_value == 0 then
		return {}
	end  

	return {{type = cfg_item.change_pool_consume_type, id = cfg_item.change_pool_consume_id, value = cfg_item.change_pool_consume_value}}
end

function SweepstakeConfig:changePoolFirstFree(id)
	local cfg_item = self._mapConfig[id]
	if not cfg_item then
		return false 
	end
	
	if cfg_item.change_pool_first_free == 1 then
		return true
	else
		return false
	end
end

local open_server_time = StableTime.get_open_server_time()--= 1484619287 --2017 01-16 10:00
local duration = 15
local day_hour = 24*3600
local begin_hour = 7*3600
local end_hour = 10*3600
local id_begin = 10000
local has_add_specific_period_already = {}
local jianglin_free_gap = 24*3600  
local jianglin_init_time = 24*3600
local jianglin_guarantee_count = 10
local jianglin_init_count = 0
local jianglin_consume_type = 90;
local jianglin_consume_id = 6;
local jianglin_price = 80;
local jianglin_combo_price = 68;
local jianglin_combo_count = 10;

local open_pool = {
	[1] = "301",
	[2] = "306",
	[3] = "311",
	[4] = "316",
	[5] = "321",
	[6] = "326",
	[7] = "302",
	[8] = "307",
	[9] = "312",
	[10]= "317",
	[11]= "322",
	[12]= "327",
	[13]= "303",
	[14]= "308",
	[15]= "313",
	[16]= "318",
	[17]= "323",
	[18]= "328",
	[19]= "304",
	[20]= "309",
	[21]= "314",
	[22]= "319",
	[23]= "324",
	[24]= "329",
	[25]= "305",
	[26]= "310",
	[27]= "315",
	[28]= "320",
	[29]= "325",
	[30]= "330",

}
local pool_reward_config_id = {
	[1] = 301,
	[2] = 306,
	[3] = 311,
	[4] = 316,
	[5] = 321,
	[6] = 326,
	[7] = 302,
	[8] = 307,
	[9] = 312,
	[10]= 317,
	[11]= 322,
	[12]= 327,
	[13]= 303,
	[14]= 308,
	[15]= 313,
	[16]= 318,
	[17]= 323,
	[18]= 328,
	[19]= 304,
	[20]= 309,
	[21]= 314,
	[22]= 319,
	[23]= 324,
	[24]= 329,
	[25]= 305,
	[26]= 310,
	[27]= 315,
	[28]= 320,
	[29]= 325,
	[30]= 330,
}

--[[local function setOpenServerTime()
	if not open_server_time then
		open_server_time = 1484582400 --2017 01-17 00:00
		local ok, result = database.query("SELECT UNIX_TIMESTAMP(begin) as begin FROM activity_time WHERE type=%d",1);
		if ok and #result >= 1 then
			 for i = 1, #result do
				local row = result[i];
				open_server_time = row.begin
			end
		end
	end
end--]]

--setOpenServerTime()

--添加降临神将配置
--[[function SweepstakeConfig:checkAndAddLimitSweepstake()
	-- cal period day id
	local now = loop.now()
	local period = math.ceil((now - get_begin_time_of_day(open_server_time))/(duration*day_hour))
	--local day = math.ceil(now - (period-1)*24*3600*duration)/(24*3600) 
	--local id = id_begin + tonumber(period..day)
	
	if not has_add_specific_period_already[period] then
		for i=1,duration*2,1 do
			--check
			local a,b = math.modf(i-1,2)
			local id = id_begin + (period-1)*duration*2 + i
			local begin_time = get_begin_time_of_day(open_server_time) + (period-1)*duration*day_hour + math.modf((i-1)/2)*day_hour + begin_hour 
			local end_time = get_begin_time_of_day(open_server_time) + (period-1)*duration*day_hour + math.modf((i-1)/2)*day_hour + end_hour
			if not self._mapConfig[id] then
				local a,b = math.modf(i/2)
				local player_data_id = id
				if i-a*2 == 0 then
					player_data_id = id - 1
				end	
				if  database.update("INSERT INTO sweepstakeconfig(id, pool_type, begin_time, end_time, activity_type, player_data_id, reward_config_id, free_gap, init_time, guarantee_count, init_count, consume_type, consume_id, price, combo_price, combo_count) VALUES(%d,%s,from_unixtime_s(%d),from_unixtime_s(%d),%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)", id, open_pool[i], begin_time, end_time, 2, player_data_id, pool_reward_config_id[i], jianglin_free_gap, jianglin_init_time, jianglin_guarantee_count, jianglin_init_count, jianglin_consume_type, jianglin_consume_id, jianglin_price, jianglin_combo_price, jianglin_combo_count) then
					self._mapConfig[id] = {}
            		self._mapConfig[id].id = id;
            		self._mapConfig[id].pool_type = open_pool[i];
            		self._mapConfig[id].begin_time = begin_time;
            		self._mapConfig[id].end_time = end_time;
            		self._mapConfig[id].activity_type = 2;
            		self._mapConfig[id].player_data_id = player_data_id;
            		self._mapConfig[id].reward_config_id = pool_reward_config_id[i];
					self._mapConfig[id].free_gap = jianglin_free_gap;
					self._mapConfig[id].init_time = jianglin_init_time;
					self._mapConfig[id].guarantee_count = jianglin_guarantee_count;
					self._mapConfig[id].init_count = jianglin_init_count;
					self._mapConfig[id].consume_type = jianglin_consume_type;
					self._mapConfig[id].consume_id = jianglin_consume_id;
					self._mapConfig[id].price = jianglin_price;
					self._mapConfig[id].combo_price = jianglin_combo_price;
					self._mapConfig[id].combo_count = jianglin_combo_count;
            		self._mapConfig[id].status = 0;
					table.insert(self._listConfig, self._mapConfig[id])
				end
			end 
		end
		has_add_specific_period_already[period] = true
	end
end--]]

function Get()
	if not g_instance then
		g_instance = Class.New(SweepstakeConfig);
		g_instance:reloadConfig()
	end
	return g_instance;
end

function process_query_sweepstake_config(conn, pid, req)
	local now = math.floor(os.time())
	local activity_type = req[2]
	--check
	if not activity_type then
		yqerror("Player `%d` get sweepstakeconfig fail, 2nd argument nil", pid)
		conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_CONFIG, pid, {req[1], Command.RET_ERROR})
	end
	local config_amf = {} 
	local config_temp = {}
	local instance = Get()

	-- checkAndAddLimitSweepStake
	--instance:checkAndAddLimitSweepstake()

	local list_cfg = instance:getListConfig()
	local wanted_key = 0
	local max_end_time = -1
	for k,v in ipairs(list_cfg) do
		if v.activity_type == activity_type and now > v.end_time and v.end_time > max_end_time then
			wanted_key = k
			max_end_time = v.end_time
		end
		if (v.activity_type == activity_type) and (now < v.end_time) then
			table.insert(config_temp,v)
		end
	end
	if wanted_key > 0 then
		local tb = {
			list_cfg[wanted_key].id,
			list_cfg[wanted_key].pool_type,
			list_cfg[wanted_key].begin_time,
			list_cfg[wanted_key].end_time,
			--list_cfg[wanted_key].player_data_id,
			--list_cfg[wanted_key].reward_config_id,
			list_cfg[wanted_key].free_gap,
			list_cfg[wanted_key].guarantee_count,
			list_cfg[wanted_key].consume_type,
			list_cfg[wanted_key].consume_id,
			list_cfg[wanted_key].price,
			list_cfg[wanted_key].combo_price,
			list_cfg[wanted_key].combo_count,
			list_cfg[wanted_key].change_pool_consume_type,
            list_cfg[wanted_key].change_pool_consume_id,
            list_cfg[wanted_key].change_pool_consume_value,
            list_cfg[wanted_key].count_item_type,
            list_cfg[wanted_key].count_item_id,
            list_cfg[wanted_key].count_item_value,
		}
		table.insert(config_amf,tb)
	end
	for k,v in ipairs(config_temp) do
		local tb = {
			v.id,
			v.pool_type,
			v.begin_time,
			v.end_time,
			--v.player_data_id,
			--v.reward_config_id,
			v.free_gap,
			v.guarantee_count,
			v.consume_type,
			v.consume_id,
			v.price,
			v.combo_price,
			v.combo_count,
			v.change_pool_consume_type,
	        v.change_pool_consume_id,
            v.change_pool_consume_value,
			v.count_item_type,
			v.count_item_id,
			v.count_item_value,
		}
		table.insert(config_amf,tb)
	end
	conn:sendClientRespond(Command.S_QUERY_SWEEPSTAKE_CONFIG_RESPOND, pid, {req[1], Command.RET_SUCCESS, config_amf})
end

