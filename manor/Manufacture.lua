require "printtb"
local ManorWorkman = require "ManorWorkman"
local database = require "database"
local Command = require "Command"
local cell = require "cell"
local ManorCopy = require "ManorCopy"
local ManorTask2 = require "ManorTask2"

local ManorEvent = require "ManorEvent"
local getOrderDiscount = ManorEvent.GetOrderDiscount

local getChangeTime = ManorWorkman.getChangeTime
local RECOVER_POWER_PER_FIVE_MIN = ManorWorkman.RECOVER_POWER_PER_FIVE_MIN 
local COST_POWER_PER_FIVE_MIN = ManorWorkman.COST_POWER_PER_FIVE_MIN 
local RECOVER_POWER_INLINE_PER_FIVE_MIN = ManorWorkman.RECOVER_POWER_INLINE_PER_FIVE_MIN 
local LoadManorPowerConsumeConfig = ManorWorkman.LoadManorPowerConsumeConfig	
local LoadWorkmanPowerPropertyConfig = ManorWorkman.LoadWorkmanPowerPropertyConfig

local Serialize = require "Serialize"

require "ManorConfig"

local PRODUCT_LINE_LIMIT = 40;
local WORKMAN_LIMIT = 5;
local WORK_STATE_BUSY = 1  --工作中
local WORK_STATE_FREE = 0  --在酒馆休息中
local WORK_STATE_INLINE_FREE = 2  --在产线上休息中

local SMITHY = 1  --铁匠铺
local MINE   = 2  --矿洞  
local SELLER   = 3  --贩卖  

--local EVENT_TYPE_START_PRODUCE = 5
local EVENT_TYPE_GATHER = 5 
local EVENT_TYPE_EMPLOY = 6 
local EVENT_PRODUCE_RATE_DOWN = 8
local EVENT_RESET_PRODUCE_RATE = 11
local EVENT_STEAL = 12
local EVENT_CLEAR_THIEF = 13
local EVENT_LAZE = 20 
local ManorLog = require "ManorLog"

local debug = true 
if not debug then
	log.debug = function(...)
		return 
	end
	yqdebug = function()
		return
	end
	sprinttb = function()
		return ""
	end
end

local WORKMAN_CONFIG = {
--[[	[SMITHY] = {
		need_workman = true,
		workman_min = 1,
		workman_max = 5,
	},
	[MINE] = {
		need_workman = true,
		workman_min = 1,
		workman_max = 5,
	},
	[SELLER] = {
		need_workman = true,
		workman_min = 1,
		workman_max = 5, 
	}--]]
}

local function GetWorkmanConfig(line)
	return WORKMAN_CONFIG[line]
	--[[if line >=1 and line < 11 then
		return WORKMAN_CONFIG[SMITHY]
	elseif line >=11 and line < 21 then
		return WORKMAN_CONFIG[MINE]	
	else 
		return WORKMAN_CONFIG[SELLER]
	end
	return nil--]]
end

local function insertItem(list, type, id, value)
	if (type and id) and  type ~= 0 and id ~= 0 then
		table.insert(list, {type=type, id=id, value= value});
	end
end

local LEVELUP_CONSUME_CONFIG = nil --[[{
	[11] = {
		[1] = {{type = 41, id = 90006, value = 0}},
		[2] = {{type = 41, id = 90006, value = 0}},
		[3] = {{type = 41, id = 90006, value = 0}},
		[4] = {{type = 41, id = 90006, value = 0}},
		[5] = {{type = 41, id = 90006, value = 0}},
	}
}--]]

local function LoadLevelUpConsumeConfig()
	if LEVELUP_CONSUME_CONFIG == nil then
		LEVELUP_CONSUME_CONFIG = {}
		local success, result = database.query("select * from config_manor_level_up");
		if success then
			for _, row in ipairs(result) do
				LEVELUP_CONSUME_CONFIG[row.line] = LEVELUP_CONSUME_CONFIG[row.line] or {}
				LEVELUP_CONSUME_CONFIG[row.line][row.line_level] = {}
				insertItem(LEVELUP_CONSUME_CONFIG[row.line][row.line_level], row.consume_item1_type, row.consume_item1_id, row.consume_item1_value)
			end
		end
	end
end

local function GetConsumeByLevel(line, level)
	LoadLevelUpConsumeConfig()
	return (LEVELUP_CONSUME_CONFIG[line] and LEVELUP_CONSUME_CONFIG[line][level]) and LEVELUP_CONSUME_CONFIG[line][level] or nil	
end

local power_change_cfg = {
	[1] = {low = 1, upper = 101, eff = 100}, 
--	[2] = {low = 51, upper = 81 , eff = 90 }, 
--	[3] = {low = 21, upper = 51 , eff = 80 }, 
--	[4] = {low = 6 , upper = 21 , eff = 60 }, 
--	[5] = {low = 1 , upper = 6  , eff = 40 }, 
	[2] = {low = 0 , upper = 1  , eff = 20 }, 
}

local function GetProperKey(power, max_power)
	for k, v in ipairs(power_change_cfg) do
		if power >= math.ceil(max_power * v.low / 100) and power < math.ceil(max_power * v.upper / 100) then
			return k, v	
		end
	end	
	return #power_change_cfg, power_change_cfg[#power_change_cfg]
end


local function addItemToList(list, item, n, need_mark)
	for _, v in ipairs(list) do
		if v.type == item.type and v.id == item.id then
			v.value = v.value + item.value * n
			if need_mark then
				v.change = true
			end
			return
		end
	end

	if need_mark then
		table.insert(list, {type = item.type, id = item.id, value = item.value * n, change = true});
	else
		table.insert(list, {type = item.type, id = item.id, value = item.value * n});
	end

	return list
end

local function mergeItem(list1, list2, n, need_mark)
	n = n or 1

	for _, v in ipairs(list2) do
		addItemToList(list1, v, n, need_mark);
	end	
	return list1
end

local function discountItem(list, discount)
	local t = {}
	for _, v in ipairs(list) do
		v.value = math.floor(v.value * discount)
		if v.value > 0 then
			table.insert(t, v)
		end
	end

	return t
end

local function makeItemTrup(itemList)
	local list = {}
	for _, v in ipairs(itemList) do
		table.insert(list, {v.type, v.id, v.value});
	end
	return list;
end

local function isEmptyOrNull(t)
	return t == nil or #t == 0
end

local function DOReward(pid, reward, consume, reason, manual, limit, name)
	assert(reason and reason ~= 0)

	if isEmptyOrNull(reward) and isEmptyOrNull(consume) then
		return true
	end

	local respond = cell.sendReward(pid, reward, consume, reason, manual, limit, name)
	if respond == nil or respond.result ~= 0 then
		return false;
	end

	for _, v in ipairs(reward or {}) do
                 if v.type == 41 then
                          cell.NotifyQuestEvent(pid, { { type = 109, id = v.id, count = v.value } })      -- 陵币、铜锭、铁锭、银锭
                  end
	end

	return true;
end

local playerInfo = {}
local function checkLevelLimit(pid, limit)
	if playerInfo[pid] and playerInfo[pid].level < limit then
		playerInfo[pid] = nil
	end	

	if not playerInfo[pid] then
		local info = cell.getPlayerInfo(pid)	
		if info then
			playerInfo[pid] = info
		else
			log.debug("checkLevelLimit fail")
			playerInfo[pid] = nil
			return false
		end	
	end	

	return playerInfo[pid].level >= limit 
end

local lineOpenConfig = nil
local linePosOpenConfig = nil
local function LoadLineOpenConfig(line)
	if not lineOpenConfig then
		lineOpenConfig = {}
		linePosOpenConfig = {}
		local success, result = database.query("select * from config_manor_line_open")
		if success then
			for _, row in ipairs(result) do
				if row.line_pos == 0 then
					lineOpenConfig[row.line] = {
						level_limit = row.open_level,
						open_consume = {}
					}
					insertItem(lineOpenConfig[row.line].open_consume, row.consume_type1, row.consume_id1, row.consume_value1)
					insertItem(lineOpenConfig[row.line].open_consume, row.consume_type2, row.consume_id2, row.consume_value2)
					insertItem(lineOpenConfig[row.line].open_consume, row.consume_type3, row.consume_id3, row.consume_value3)
				else
					linePosOpenConfig[row.line] = linePosOpenConfig[row.line] or {}
					linePosOpenConfig[row.line][row.line_pos] = {
						level_limit = row.open_level
					}
				end	
			end
		end	
	end
	
	return lineOpenConfig[line] and lineOpenConfig[line] or nil
end

local function GetLinePosOpenConfig(line, pos)
	if not linePosOpenConfig[line] then
		return 
	end

	return linePosOpenConfig[line][pos]
end

local playerLineOpen = {} 
local function LoadPlayerLineOpen(pid)
	if not playerLineOpen[pid] then
		playerLineOpen[pid] = {}
		local success, result = database.query("select pid, line, open, unix_timestamp(open_time) as open_time from manor_manufacture_player_line_open_status where pid = %d", pid)
		if success then
			for _, row in ipairs(result) do
				playerLineOpen[row.pid] = playerLineOpen[row.pid] or {}
				playerLineOpen[row.pid][row.line] = {
					open = row.open,
					open_time = row.open_time
				}
			end
		end	
	end	
end

local function UnlockPlayerLine(pid, line)
	LoadPlayerLineOpen(pid)

	if playerLineOpen[pid][line] and playerLineOpen[pid][line].open == 1 then
		log.debug("line %d already open")
		return false
	end

	local cfg = LoadLineOpenConfig(line)
	if not cfg then
		log.debug(string.format("line %d dont has open config", line))
		return false 
	end

	if not checkLevelLimit(pid, cfg.level_limit) then
		log.debug("level not enough")
		return false
	end

	-- reward
	if not DOReward(pid, nil, cfg.open_consume, Command.REASON_MANOR_MANUFACTURE_UNLOCK_LINE, false, loop.now() + 14 * 24 * 3600, nil) then
		log.debug("consume fail")
		return false
	end

	if not playerLineOpen[pid][line] then
		playerLineOpen[pid][line] = {
			open = 1,
			open_time = loop.now()
		}
		database.update("insert into manor_manufacture_player_line_open_status (pid, line, open, open_time) values(%d, %d, %d, from_unixtime_s(%d))", pid, line, 1, loop.now())
	else
		playerLineOpen[pid][line].open = 1
		playerLineOpen[pid][line].open_time = loop.now() 
		database.update("update manor_manufacture_player_line_open_status set open = %d, open_time = from_unixtime_s(%d) where pid = %d and line = %d", 1, loop.now(), pid, line)
	end

	return true
end

local function alreadyOpen(pid, line)
    LoadPlayerLineOpen(pid)

	local cfg = LoadLineOpenConfig(line)
	if not cfg or #cfg.open_consume == 0 then
		return true
	end

    return playerLineOpen[pid][line] and (playerLineOpen[pid][line].open == 1 and true or false) or false
end

local function checkLineOpen(pid, line)
	local cfg = LoadLineOpenConfig(line)
	if not cfg then
		log.debug(string.format("line %d dont has open config", line))
		return true
	end

	if (cfg.level_limit == 1) and (#cfg.open_consume == 0) then
		return true
	end

	--print("line open config >>>>>>>>>>", cfg.level_limit, sprinttb(cfg.open_consume))
	return checkLevelLimit(pid, cfg.level_limit) and alreadyOpen(pid, line)
end

local function getRandItems(pool_id)
	local w_num = {}
	local random_item = {}
	local items = GetManufacturePoolConfig(pool_id)
	local sub_num = 0
	for type,item in pairs(items) do
		for id,v in pairs(item) do
			sub_num = sub_num + v.weight	
		end
	end
	--print('-------------sub_num = '..sub_num)	
	math.randomseed(os.time())  
	local random_number = math.random(0,sub_num)
	local n_base = 0
	local stop_loop = false
	for type,item in pairs(items) do
		for id,v in pairs(item) do
			if random_number > n_base and random_number <=  n_base + v.weight then
				--print('------------------random_number = '..random_number,n_base,n_base + v.weight)
				random_item = {{type = type,id = id,value = v.item_value }}	
				stop_loop = true
				break
			end	
			n_base = n_base + v.weight
		end
		if stop_loop then
			break
		end
	end 
	
	return random_item
end

--local x = getRandItems(5001)

--print('llllllllllll',x.type,x.id,x.value)


local product_list = nil
local valid_line = {}
local function LoadProductConfig(gid)
	if product_list == nil then
		product_list = {}
		local success, result = database.query("select * from manor_manufacture_product");
		if success then
			for _, row in ipairs(result) do
				product_list[row.gid] =	{
					gid = row.gid,
					line = row.line,
					time = {min = row.time_min, max = row.time_max},
					count = {min = row.one_time_count_min, max = row.one_time_count_max},
					type = row.type,
					depend_item = row.depend_item,
					level_limit = row.level_limit or 0,
					consume = {},
					reward = {},
					material_type = row.material_type or 0,
					show_type = row.show_type or 0,
					product_pool1 = row.product_pool1,
					product_pool2 = row.product_pool2,
				}

				insertItem(product_list[row.gid].consume, 41, row.depend_item, 0);
				insertItem(product_list[row.gid].consume, row.consume_item1_type, row.consume_item1_id, row.consume_item1_value);
				insertItem(product_list[row.gid].consume, row.consume_item2_type, row.consume_item2_id, row.consume_item2_value);
				insertItem(product_list[row.gid].consume, row.consume_item3_type, row.consume_item3_id, row.consume_item3_value);
				insertItem(product_list[row.gid].consume, row.consume_item4_type, row.consume_item4_id, row.consume_item4_value);
				
				--local product_item = getRandItems(row.product_pool1)
				--insertItem(product_list[row.gid].reward, product_item.type, product_item.id, product_item.value);
				
				insertItem(product_list[row.gid].reward, row.product_item1_type, row.product_item1_id, row.product_item1_value);
				insertItem(product_list[row.gid].reward, row.product_item2_type, row.product_item2_id, row.product_item2_value);
				insertItem(product_list[row.gid].reward, row.product_item3_type, row.product_item3_id, row.product_item3_value);
				insertItem(product_list[row.gid].reward, row.product_item4_type, row.product_item4_id, row.product_item4_value);
				insertItem(product_list[row.gid].reward, row.product_item5_type, row.product_item5_id, row.product_item5_value);
				insertItem(product_list[row.gid].reward, row.product_item6_type, row.product_item6_id, row.product_item6_value);
				
				valid_line[row.line] = true
			end
		end
	end

	return gid and product_list[gid] or product_list;
end

local line_config = nil
local EFFECT_SPEEDUP = 1
local EFFECT_PRODUCEUP = 2
local EFFECT_NONE = 0 
local effect_config = GetEffectConfig()--[[{
	[301] = EFFECT_SPEEDUP,
	[302] = EFFECT_SPEEDUP,
	[303] = EFFECT_SPEEDUP,
	[304] = EFFECT_SPEEDUP,
	[401] = EFFECT_PRODUCEUP,
	[402] = EFFECT_PRODUCEUP,
	[403] = EFFECT_PRODUCEUP,
	[501] = EFFECT_SPEEDUP,
	[502] = EFFECT_PRODUCEUP,
	[601] = EFFECT_SPEEDUP,
	[801] = EFFECT_NONE,
	[802] = EFFECT_NONE,
	[803] = EFFECT_NONE,
	[804] = EFFECT_NONE,
}--]]

local MAX_NUM = 9999999

local function LoadLineConfig(line)
	if line_config == nil then
		line_config = {}	
		local success, result = database.query("select * from config_manor_line_cfg")
		if success then
			for _, row in ipairs(result) do
				line_config[row.line] = line_config[row.line] or {
					line = row.line,
					material_type = row.material_type,	
					factor = row.factor,
					storage1 = row.storage1,
					storage1_up = row.storage_up1,
					storage2 = row.storage2,
					storage2_up = row.storage_up2,
					storage3 = row.storage3,
					storage3_up = row.storage_up3,
					storage4 = row.storage4 or MAX_NUM,
					storage4_up = row.storage_up4 or MAX_NUM,
					storage5 = row.storage5 or MAX_NUM,
					storage5_up = row.storage_up5 or MAX_NUM,
					storage6 = row.storage6 or MAX_NUM,
					storage6_up = row.storage_up6 or MAX_NUM,
					storage_pool = row.storage_pool or MAX_NUM,
					storage_pool_up = row.storage_pool_up or MAX_NUM,
					init_order_limit = row.limit_down,
					max_order_limit = row.limit_up,
					order_limit_consume = {
						{type = row.limit_type, id = row.limit_id, value = row.limit_num},
					},
					limit_effect = row.limit_effect,
					every_steal_percent = math.floor(row.every_steal / 100),
					steal_guarantee = math.floor(row.steal_guarantee / 100),
					steal_count_item = {},--{{type = 41, id = row.steal_item, value = 1}}
				}
				if row.steal_item > 0 then
					table.insert(line_config[row.line].steal_count_item, {type = 41, id = row.steal_item, value = 1})
				end

				local t = {
					property_id1 = row.property_id1,
					property_percent1 = row.property_percent1,
							
					property_id2 = row.property_id2,
					property_percent2 = row.property_percent2,

					property_id3 = row.property_id3,
					property_percent3 = row.property_percent3,

					property_id4 = row.property_id4,
					property_percent4 = row.property_percent4,

					property_id5 = row.property_id5,
					property_percent5 = row.property_percent5
				}
				line_config[row.line].property_list = line_config[row.line].property_list or {}
				table.insert(line_config[row.line].property_list, t)	

				local num = 0
				for i = 1, 5, 1 do
					if row["property_id"..i] ~= 0 then
						num = num + 1
					end
				end
				WORKMAN_CONFIG[row.line] = {
					need_workman = row.property_id1 ~= 0,
					workman_min = (row.property_id1 == 0) and 0 or 1,	
					workman_max = num,
				}		

			end
		end
	end
	if line then 
		return line_config[line]
	else
		return line_config
	end	

	return not line and line_config or line_config[line]
end

LoadLineConfig()

local ManufactureQualifiedWorkmen = {}

function ManufactureQualifiedWorkmen.New(pid)
	return setmetatable({
			pid = pid,
			qualified_workmen_list = {},
		}, {__index = ManufactureQualifiedWorkmen});
end

function ManufactureQualifiedWorkmen:Load()
	--[[local success, result = database.query("select workman_id, property_id, property_value from manor_manufacture_player_qualified_workman where pid = %d", self.pid)
	if not success then
		return 
	end

	for _, row in ipairs(result) do
		self.qualified_workmen_list[row.workman_id] = self.qualified_workmen_list[row.workman_id] or {}
		self.qualified_workmen_list[row.workman_id][row.property_id] = row.property_value
	end--]]
end

local function getTitleAddValue(property_id, fight_data)
	if not fight_data then
		return 0
	end

	for _, property in ipairs(fight_data.roles[1].propertys) do
		if property.type == property_id then
			return property.value
		end
	end

	return 0
end

function ManufactureQualifiedWorkmen:BuildProperty(workman_id, reload)
	if not self.qualified_workmen_list[workman_id] or reload then
		self.qualified_workmen_list[workman_id] = {} 

		local playerHeroInfo = cell.getPlayerHeroInfo(self.pid, 0, workman_id)	
		if not playerHeroInfo then
			yqinfo("fail to BuildProperty, cannnot get hero info for hero:%d", workman_id)	
			return 
		end

		local fight_data, err = cell.QueryPlayerFightInfo(self.pid, false, 0, {workman_id})
		if err then
			log.debug(string.format('fail to BuildProperty, get fight data of hero %d error %s', workman_id, err))
			return 
		end

		local property_map = {}
		if fight_data.roles and fight_data.roles[1] then
			for _, property in ipairs(fight_data.roles[1].propertys or {}) do
				property_map[property.type] = property.value
			end
		end

		local hero_id = playerHeroInfo.gid
		for property_id, _ in pairs(effect_config) do
			local cfg = LoadWorkmanPowerPropertyConfig(hero_id, property_id)
			self.qualified_workmen_list[workman_id][property_id] = cfg.init1 + playerHeroInfo.level * cfg.lv_value1 + playerHeroInfo.stage * cfg.rank_value1 + playerHeroInfo.star * cfg.star_value1

			local title_add_value = property_map[property_id] and property_map[property_id] or 0

			--percent add value
			local percent_add_value = 0
			local target_property_id = GetPropertyConfig(property_id)
			if target_property_id then
				percent_add_value = property_map[target_property_id] or 0
			end
			self.qualified_workmen_list[workman_id][property_id] = math.floor(self.qualified_workmen_list[workman_id][property_id] * (1 + percent_add_value / 10000)) + title_add_value
		end
	end
end

function ManufactureQualifiedWorkmen:GetProperty(workman_id, property_id, reload)
	if not workman_id or workman_id == 0 then return 0 end

	self:BuildProperty(workman_id, reload)

	if not property_id then
		local property_tb = {}
		for i, _ in pairs(self.qualified_workmen_list[workman_id]) do		
			local other = ManorCopy.get_global_property_value(self.pid, workman_id, i)
			property_tb[i] = self.qualified_workmen_list[workman_id][i] + other
		end
		return self.qualified_workmen_list[workman_id] and property_tb or nil
	end
	
	return  (self.qualified_workmen_list[workman_id] and self.qualified_workmen_list[workman_id][property_id]) and self.qualified_workmen_list[workman_id][property_id] + ManorCopy.get_global_property_value(self.pid, workman_id, property_id) or 0 
end

function ManufactureQualifiedWorkmen:Evaluate(workman_id, property_id, property_value, reload)
	local playerHeroInfo = cell.getPlayerHeroInfo(self.pid, 0, workman_id)	
	if not playerHeroInfo then
		log.warning("fail to evaluate workman:%d player donnt has this hero", workman_id)
		return 
	end

	self:BuildProperty(workman_id, reload)

	if not workman_id or not workman_id or not property_value then return nil end
	self.qualified_workmen_list[workman_id] = self.qualified_workmen_list[workman_id] or {}
	if self.qualified_workmen_list[workman_id][property_id] and self.qualified_workmen_list[workman_id][property_id] == property_value then
		return 0
	end
	self.qualified_workmen_list[workman_id][property_id] = property_value
 	database.update("REPLACE INTO manor_manufacture_player_qualified_workman(pid, workman_id, property_id, property_value)VALUES(%d, %d, %d, %d)", self.pid, workman_id, property_id, property_value)
	return 0
end

local ManufactureQualifiedWorkmenList = {} 

function GetManufactureQualifiedWorkmen(pid)
	if ManufactureQualifiedWorkmenList[pid] == nil then
		ManufactureQualifiedWorkmenList[pid] = ManufactureQualifiedWorkmen.New(pid);
		ManufactureQualifiedWorkmenList[pid]:Load();
	end
	return ManufactureQualifiedWorkmenList[pid];
end

local function LoadLineProduceRate(pid, t)
	local success, result = database.query("select pid, line, line_produce_rate, unix_timestamp(line_produce_rate_begin_time) as line_produce_rate_begin_time, unix_timestamp(line_produce_rate_end_time) as line_produce_rate_end_time, line_produce_rate_reason, line_produce_rate_depend_fight, line_produce_rate_extra_data from manor_manufacture_player_line_produce_rate where pid = %d", pid)
	if success then
		for _, row in ipairs(result) do
			t.product_line[row.line].line_produce_rate = row.line_produce_rate
			t.product_line[row.line].line_produce_rate_begin_time = row.line_produce_rate_begin_time
			t.product_line[row.line].line_produce_rate_end_time = row.line_produce_rate_end_time
			t.product_line[row.line].line_produce_rate_reason = row.line_produce_rate_reason
			t.product_line[row.line].line_produce_rate_depend_fight = row.line_produce_rate_depend_fight
			t.product_line[row.line].line_produce_rate_extra_data = row.line_produce_rate_extra_data
		end
	end	
end

local function LoadLinePoolStorage(pid, t)
	local success, result = database.query("select pid, line, gid, type, id, value, stolen_value from manor_manufacture_player_line_pool_storage where pid = %d", pid)
	if success then
		for _, row in ipairs(result) do
			if t.product_line[row.line].orders[row.gid] then
				if row.type and row.id and row.type ~= 0 and row.id ~= 0 then
					table.insert(t.product_line[row.line].orders[row.gid].gather_product_pool, {type = row.type, id = row.id, value = row.value, stolen_value = row.stolen_value})
				end
			end
		end
	end	
end

local function LoadLineThieves(pid, t)
	local success, result = database.query("select pid, line, thief, unix_timestamp(begin_time) as begin_time, unix_timestamp(end_time) as end_time, depend_fight_id, stolen_goods from  manor_manufacture_line_thieves where pid = %d", pid)
	if success then
		for _, row in ipairs(result) do
			t.product_line[row.line].thieves[row.thief] = t.product_line[row.line].thieves[row.thief] or {
				begin_time = row.begin_time,
				end_time = row.end_time,
				depend_fight_id = row.depend_fight_id,
				stolen_goods = Serialize.TransformStr2Tb(row.stolen_goods),
			}	

		end
	end
end

local function LoadLineEventCD(pid, t)
	local success, result = database.query("select pid,line,event_type, unix_timestamp(time_cd) as time_cd from manor_manufacture_line_event_cd where pid = %d",pid)
	if success then
		for _,row in ipairs(result) do
			t.product_line[row.line].event_cd[row.event_type] = row.time_cd
		end
	end
end


local Manufacture = {}

function Manufacture.New(pid)
	return setmetatable({
			pid = pid,
			product_line_limit = PRODUCT_LINE_LIMIT,
			product_line =  {}
	}, {__index = Manufacture});
end

function Manufacture:Load()
	local success, result = database.query("select line, speed, unix_timestamp(next_gather_time) as next_gather_time, unix_timestamp(event_happen_time) as event_happen_time, next_gather_gid, workman1_speed, workman2_speed, workman3_speed, workman4_speed, workman5_speed,  workman1_produce_rate, workman2_produce_rate, workman3_produce_rate, workman4_produce_rate, workman5_produce_rate, unix_timestamp(current_order_begin_time) as current_order_begin_time, current_order_last_time, current_order_produce_rate, storage1, storage2, storage3, storage4, storage5, storage6, storage_pool, order_limit from manor_manufacture_player_line where pid = %d", self.pid);

	if not success then
		return;
	end

	self.product_line = {}
	for i = 1, self.product_line_limit do
		local line_cfg = LoadLineConfig(i)
		self.product_line[i] = {
			idx = i,
			speed = 0,
			next_gather_time = 0,
			next_gather_gid  = 0,
			event_happen_time = 0,
			current_order_begin_time = 0,
			current_order_end_time = 0,
			current_order_produce_rate = 0,
			level = 1,
			workman1_speed = 0,
			workman2_speed = 0,
			workman3_speed = 0,
			workman4_speed = 0,
			workman5_speed = 0,
			workman1_produce_rate = 0,
			workman2_produce_rate = 0,
			workman3_produce_rate = 0,
			workman4_produce_rate = 0,
			workman5_produce_rate = 0,
			current_order_begin_time = 0,
			current_order_last_time = 0,
			orders = {},
			workmen = {},
			storage1 = line_cfg and line_cfg.storage1 or 0,
			storage2 = line_cfg and line_cfg.storage2 or 0,
			storage3 = line_cfg and line_cfg.storage3 or 0,
			storage4 = line_cfg and line_cfg.storage4 or 0,
			storage5 = line_cfg and line_cfg.storage5 or 0,
			storage6 = line_cfg and line_cfg.storage6 or 0,
			storage_pool = line_cfg and line_cfg.storage_pool or 0,
			order_limit = line_cfg and line_cfg.init_order_limit or 0,
			line_produce_rate = 0,                   
			line_produce_rate_begin_time = 0,
			line_produce_rate_end_time = 0,
			line_produce_rate_reason = 0,
			line_produce_rate_depend_fight = 0,
			line_produce_rate_extra_data = 0,
			event_cd = {},--get_player_line_event_cd_cache(self.pid, i),
			thieves = {},
			db_exists = false,
		};	
	end

	for _, row in ipairs(result) do
		if self.product_line[row.line] then
			local line_cfg = LoadLineConfig(row.line)
			self.product_line[row.line].speed = row.speed
			self.product_line[row.line].next_gather_time = row.next_gather_time
			self.product_line[row.line].next_gather_gid  = row.next_gather_gid
			self.product_line[row.line].event_happen_time = row.event_happen_time
			self.product_line[row.line].workman1_speed  = row.workman1_speed
			self.product_line[row.line].workman2_speed  = row.workman2_speed
			self.product_line[row.line].workman3_speed  = row.workman3_speed
			self.product_line[row.line].workman4_speed  = row.workman4_speed
			self.product_line[row.line].workman5_speed  = row.workman5_speed
			self.product_line[row.line].workman1_produce_rate  = row.workman1_produce_rate
			self.product_line[row.line].workman2_produce_rate  = row.workman2_produce_rate
			self.product_line[row.line].workman3_produce_rate  = row.workman3_produce_rate
			self.product_line[row.line].workman4_produce_rate  = row.workman4_produce_rate
			self.product_line[row.line].workman5_produce_rate  = row.workman5_produce_rate
			self.product_line[row.line].current_order_begin_time  = row.current_order_begin_time
			self.product_line[row.line].current_order_last_time  = row.current_order_last_time
			self.product_line[row.line].current_order_produce_rate = row.current_order_produce_rate
			self.product_line[row.line].storage1 = row.storage1
			self.product_line[row.line].storage2 = row.storage2
			self.product_line[row.line].storage3 = row.storage3
			self.product_line[row.line].storage4 = row.storage4
			self.product_line[row.line].storage5 = row.storage5
			self.product_line[row.line].storage6 = row.storage6
			self.product_line[row.line].storage_pool = row.storage_pool
			self.product_line[row.line].order_limit = row.order_limit == 0 and (line_cfg and line_cfg.init_order_limit or 0) or row.order_limit
			self.product_line[row.line].db_exists = true
		end
	end

	local success, result = database.query("select pid, line, gid, left_count, gather_count, gather_product_item1_value, gather_product_item2_value, gather_product_item3_value, gather_product_item4_value, gather_product_item5_value, gather_product_item6_value, stolen_value1, stolen_value2, stolen_value3, stolen_value4, stolen_value5, stolen_value6 from manor_manufacture_player_order where pid = %d", self.pid);
	if not success then
		return;
	end

	for _, row in ipairs(result) do
		if self.product_line[row.line] then
			self.product_line[row.line].orders[row.gid] = {
				gid              = row.gid,
				left_count       = row.left_count,
				gather_count     = row.gather_count,
				gather_product_item1_value = row.gather_product_item1_value,
				gather_product_item2_value = row.gather_product_item2_value,
				gather_product_item3_value = row.gather_product_item3_value,
				gather_product_item4_value = row.gather_product_item4_value,
				gather_product_item5_value = row.gather_product_item5_value,
				gather_product_item6_value = row.gather_product_item6_value,
				stolen_value1 = row.stolen_value1;
				stolen_value2 = row.stolen_value2;
				stolen_value3 = row.stolen_value3;
				stolen_value4 = row.stolen_value4;
				stolen_value5 = row.stolen_value5;
				stolen_value6 = row.stolen_value6;
				gather_product_pool = {}
			}
		end
	end

	local success, result = database.query("select pid, line, workman1, workman2, workman3, workman4, workman5,workman1_gid,workman2_gid,workman3_gid,workman4_gid,workman5_gid from manor_manufacture_player_workman where pid = %d", self.pid)
    if not success then
        return;
    end

    for _, row in ipairs(result) do
        if self.product_line[row.line] then
            self.product_line[row.line].workmen = {
                workman1 = row.workman1,
                workman2 = row.workman2,
                workman3 = row.workman3,
                workman4 = row.workman4,
                workman5 = row.workman5,
				workman1_gid = row.workman1_gid,
				workman2_gid = row.workman2_gid,
				workman3_gid = row.workman3_gid,
				workman4_gid = row.workman4_gid,
				workman5_gid = row.workman5_gid,
            }
			local workman1_speed, workman1_produce_rate = self:GetWorkmanSpeedAndProduceRate2(row.line, self.product_line[row.line], 1)
			local workman2_speed, workman2_produce_rate = self:GetWorkmanSpeedAndProduceRate2(row.line, self.product_line[row.line], 2)
			local workman3_speed, workman3_produce_rate = self:GetWorkmanSpeedAndProduceRate2(row.line, self.product_line[row.line], 3)
			local workman4_speed, workman4_produce_rate = self:GetWorkmanSpeedAndProduceRate2(row.line, self.product_line[row.line], 4)
			local workman5_speed, workman5_produce_rate = self:GetWorkmanSpeedAndProduceRate2(row.line, self.product_line[row.line], 5)
			self.product_line[row.line].workman1_speed = workman1_speed 
			self.product_line[row.line].workman2_speed = workman2_speed 
			self.product_line[row.line].workman3_speed = workman3_speed 
			self.product_line[row.line].workman4_speed = workman4_speed 
			self.product_line[row.line].workman5_speed = workman5_speed 
			self.product_line[row.line].workman1_produce_rate = workman1_produce_rate 
			self.product_line[row.line].workman2_produce_rate = workman2_produce_rate 
			self.product_line[row.line].workman3_produce_rate = workman3_produce_rate 
			self.product_line[row.line].workman4_produce_rate = workman4_produce_rate 
			self.product_line[row.line].workman5_produce_rate = workman5_produce_rate 
        end
    end

	local success, result = database.query("select pid, line, level from manor_manufacture_player_line_level where pid = %d", self.pid)
	if not success then
		return;
	end
	
	for _, row in ipairs(result) do
		if self.product_line[row.line] then
			self.product_line[row.line].level = row.level
		end
	end

	LoadLineProduceRate(self.pid, self)
	LoadLinePoolStorage(self.pid, self)
	LoadLineThieves(self.pid, self)
	LoadLineEventCD(self.pid, self)

end

function Manufacture:GetLineInfo(line)
	return self:CalcGatherInfo(self.product_line[line]);
end

local function random(min, max)
	return (min == max) and min or math.random(min, max)
end

function Manufacture:GetLineProduceRate(info, time)
	assert(time)
	if time < info.line_produce_rate_begin_time or time > info.line_produce_rate_end_time then
		return 0
	end	

	return info.line_produce_rate	
end

local EVENT_MAX_IN_ONE_LOOP = 10 --一次循环最多触发的事件数

local function CalcProductValue(reward, order_count, current_order_produce_rate, line_produce_rate, discount, can_speedup)
	local reward_value = reward and reward.value or 0
	if can_speedup then
		return math.floor(reward_value * order_count * ((100 + current_order_produce_rate) / 100) * ((100 + line_produce_rate) / 100) * discount)	
	else
		return math.floor(reward_value * order_count * discount)	
	end	
end

local function addItemToList2(list, item, n, need_mark)
	for _, v in ipairs(list) do
		if v.type == item.type and v.id == item.id then
			v.value = v.value + item.value * n
			v.change = true
			return
		end
	end

	table.insert(list, {type = item.type, id = item.id, value = item.value * n, stolen_value = 0, change = true});

	return list
end

local function mergeItemOfGatherPool(list1, list2)
	n = n or 1

	for _, v in ipairs(list2) do
		addItemToList2(list1, v, 1);
	end	
	return list1
end

local function gatherPoolReward(order, pool_ids, storage_limit, order_count, current_order_product_rate, line_produce_rate, discount, change_order, speed_up)
	local current_storage = 0
	for _, v in ipairs(order.gather_product_pool) do
		current_storage = current_storage + v.value
	end

	--print("current_storage >>>>>>>>", current_storage,   storage_limit)
	if current_storage >= storage_limit then
		return false
	end

	local items = {}
	for _, pool_id in ipairs(pool_ids) do
		if pool_id > 0 then
			--print("pool_id >>>>>>>>>", pool_id)
			local item = getRandItems(pool_id)
			if #item > 0 then
				mergeItem(items, item)
			end
			--print("random item >>>>>>>>>", sprinttb(item))
		end
	end	

	--print("items >>>>>>>", sprinttb(items), order_count, discount)
	local final_items = {}
	for _, item in ipairs(items) do
		local value = speed_up and math.floor(item.value * order_count * ((100  + current_order_product_rate) / 100) * ((100 + line_produce_rate) / 100) * discount) or math.floor(item.value * order_count * discount)
		--print("value >>>>>>>>>>> ",value, current_order_product_rate, line_produce_rate)
		if storage_limit - current_storage >= value then
			item.value = value
		else
			item.value = storage_limit - current_storage
		end	
		
		if item.value > 0 then
			table.insert(final_items, {type = item.type, id = item.id, value = item.value})
			change_order[order.gid] =  order
		end

		current_storage = current_storage + item.value
		if current_storage >= storage_limit then
			break
		end
	end

	--print("final_items >>>>>>>>", sprinttb(final_items))
	if #final_items > 0 then
		mergeItemOfGatherPool(order.gather_product_pool, final_items)
		return true
	end

	return false
end

function Manufacture:CalcGatherInfo(info, speed_up_time)
	--print("calc gather info >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
	local this = self
	if not info then return end

	local changed_order = {};

	local gather_product_pool_change_order = {}
	-- gather order
	local function gatherOrder(order, product, produce_rate, calc_time, info)
		if order == nil or order.left_count <= 0 then
			return true;
		end

		product = product or LoadProductConfig(order.gid)

		print('product', order.gid, product, product.count);

		local count = random(product.count.min, product.count.max);
		if count > order.left_count then
			count = order.left_count
		end

		order.gather_count = order.gather_count + count;
		order.left_count   = order.left_count - count;

		local discount = getOrderDiscount(self.pid, order.gid, calc_time) / 100
		local line_produce_rate = self:GetLineProduceRate(info, calc_time)
		if this:CanSpeedUpByWorkman(info.idx, order.gid) then
			order.gather_product_item1_value = order.gather_product_item1_value + CalcProductValue(product.reward[1], count, produce_rate, line_produce_rate, discount, true);
			order.gather_product_item2_value = order.gather_product_item2_value + CalcProductValue(product.reward[2], count, produce_rate, line_produce_rate, discount, true);
			order.gather_product_item3_value = order.gather_product_item3_value + CalcProductValue(product.reward[3], count, produce_rate, line_produce_rate, discount, true);
			order.gather_product_item4_value = order.gather_product_item4_value + CalcProductValue(product.reward[4], count, produce_rate, line_produce_rate, discount, true);
			order.gather_product_item5_value = order.gather_product_item5_value + CalcProductValue(product.reward[5], count, produce_rate, line_produce_rate, discount, true);
			order.gather_product_item6_value = order.gather_product_item6_value + CalcProductValue(product.reward[6], count, produce_rate, line_produce_rate, discount, true);
			gatherPoolReward(order, {product.product_pool1, product.product_pool2}, info.storage_pool, count, produce_rate, line_produce_rate, discount, gather_product_pool_change_order, true) 
		else
			order.gather_product_item1_value = order.gather_product_item1_value + CalcProductValue(product.reward[1], count, produce_rate, line_produce_rate, discount, false);
			order.gather_product_item2_value = order.gather_product_item2_value + CalcProductValue(product.reward[2], count, produce_rate, line_produce_rate, discount, false);
			order.gather_product_item3_value = order.gather_product_item3_value + CalcProductValue(product.reward[3], count, produce_rate, line_produce_rate, discount, false);
			order.gather_product_item4_value = order.gather_product_item4_value + CalcProductValue(product.reward[4], count, produce_rate, line_produce_rate, discount, false);
			order.gather_product_item5_value = order.gather_product_item5_value + CalcProductValue(product.reward[5], count, produce_rate, line_produce_rate, discount, false);
			order.gather_product_item6_value = order.gather_product_item6_value + CalcProductValue(product.reward[6], count, produce_rate, line_produce_rate, discount, false);
			gatherPoolReward(order, {product.product_pool1, product.product_pool2}, info.storage_pool, count, produce_rate, line_produce_rate, discount, gather_product_pool_change_order, false) 
		end

		changed_order[order.gid] = order;

		return order.left_count <= 0;
	end


	-- get order for next product
	local choose_idx = 0;
	local waiting_orders = {}
	for gid, order in pairs(info.orders) do
		if order.left_count > 0 then
			table.insert(waiting_orders, order);
			if order.gid == info.next_gather_gid then
				choose_idx = #waiting_orders;
			end
		end
	end

	local now = loop.now();
	local info_changed = false;
	local line_produce_rate_change = false

	if speed_up_time and info.next_gather_time > 0 then
		if info.next_gather_time - speed_up_time <= now then
			info.next_gather_time = now
			speed_up_time = speed_up_time - (info.next_gather_time - now)
		else
			info.next_gather_time = info.next_gather_time - speed_up_time
			speed_up_time = 0
		end
		
		if info.event_happen_time > 0 and info.next_gather_time <= info.event_happen_time then
			info.event_happen_time = 0
		end

		info_changed = true
	end

	local calc_time = (info.next_gather_time > 0) and info.next_gather_time or now;
	local event_happen_time = info.event_happen_time 

	local begin_time = calc_time
	local b = os.clock()
	local n = 0
	--print(string.format("pid%d line %d event_happen_time%d info.event_happen_time%d calc_time%d  now%d #waiting_orders%d", self.pid, info.idx, event_happen_time, info.event_happen_time, calc_time, now, #waiting_orders))
	--print("event happen count down >>>>>>>>>>>>>>", info.idx, event_happen_time - loop.now())
	local event_happen_count_in_one_loop = 0;
	while (event_happen_time <= now and event_happen_time > 0) or (calc_time <= now and #waiting_orders > 0) do
		print("in loop >>>>>>>>>>", event_happen_time, calc_time, #waiting_orders, now)
		--trigger event
		if (event_happen_time <= now and event_happen_time > 0) then
			local event, v1, v2, v3, v4, v5 = self:triggerEvent(info, event_happen_time)	
			if event == EVENT_LAZE then
				--print("event laze happen >>>>>>>>>>>>>>")
				info.next_gather_time = (v1 <= event_happen_time and event_happen_time or v1)
				calc_time = info.next_gather_time	
				info_changed = true
			elseif event == EVENT_PRODUCE_RATE_DOWN then
				info.line_produce_rate = v1
				info.line_produce_rate_begin_time = v2
				info.line_produce_rate_end_time = v3
				info.line_produce_rate_reason = EVENT_PRODUCE_RATE_DOWN
				info.line_produce_rate_depend_fight = v4
				info.line_produce_rate_extra_data = v5
				line_produce_rate_change = true
			end	
			
			info.event_happen_time = 0
			event_happen_time = info.event_happen_time
			event_happen_count_in_one_loop = event_happen_count_in_one_loop + 1
		end

		--gather order
		if (calc_time <= now and #waiting_orders) then
			if gatherOrder(info.orders[info.next_gather_gid], nil, info.current_order_produce_rate, calc_time, info) then
				-- order is empty
				table.remove(waiting_orders, choose_idx);

				if #waiting_orders == 0 then
					-- no waiting orders
					break;	
				end
			end

			-- choose an order
			choose_idx = random(1, #waiting_orders);
			local choose = waiting_orders[choose_idx];

			-- set next gather time
			local product = LoadProductConfig(choose.gid);
			local time = math.random(product.time.min, product.time.max);

			local workmanInfo = ManorWorkman.Get(self.pid)
			for i = 1, WORKMAN_LIMIT do
				if info.workmen["workman"..i] and info.workmen["workman"..i] ~= 0  then
					workmanInfo:ChangeWorkmanBusyStatus(info.workmen["workman"..i], WORK_STATE_BUSY, calc_time)
				end
			end 

			if speed_up_time and speed_up_time > 0 then
				if time <= speed_up_time then
					speed_up_time = speed_up_time - time
					info.next_gather_time = self:GetNextGatherTime(calc_time, 0, info, choose.gid)
				else
					speed_up_time = 0 
					info.next_gather_time = self:GetNextGatherTime(calc_time, 0, info, choose.gid)
				end
			else
				info.next_gather_time = self:GetNextGatherTime(calc_time, time, info, choose.gid)
			end	

			info.current_order_begin_time = calc_time
			info.current_order_last_time = time
			info.next_gather_gid  = choose.gid
			info.current_order_produce_rate = info.workman1_produce_rate + info.workman2_produce_rate + info.workman3_produce_rate + info.workman4_produce_rate + info.workman5_produce_rate
			if info.next_gather_time - info.current_order_begin_time > 20 and event_happen_count_in_one_loop <= EVENT_MAX_IN_ONE_LOOP then
				info.event_happen_time = math.random(info.current_order_begin_time + 1, info.next_gather_time - 10)
			else
				info.event_happen_time = 0
			end	
			info_changed = true;
			
			calc_time = info.next_gather_time;
			event_happen_time = info.event_happen_time
			changed_order[choose.gid] = choose;
		end
		n = n + 1
	end
	local end_time = calc_time
	local e = os.clock()

	-- log.info(string.format("line %d finish calc loop begin:%d end:%d count:%d last_time:%f",info.idx, begin_time, end_time, n, e-b))
	
	if #waiting_orders == 0 and (info.next_gather_time ~= 0 or info.next_gather_gid ~= 0) then
		--change workman busy status
		local workmanInfo = ManorWorkman.Get(self.pid)
		for i = 1, WORKMAN_LIMIT do
			if info.workmen["workman"..i] and info.workmen["workman"..i] ~= 0  then
				workmanInfo:ChangeWorkmanBusyStatus(info.workmen["workman"..i], WORK_STATE_INLINE_FREE, info.next_gather_time)
			end
		end 
		-- nothing to product
		info.next_gather_time = 0;
		info.next_gather_gid = 0;
		info.current_order_begin_time = 0;
		info.current_order_last_time = 0;
		info.current_order_produce_rate = 0;
		info.event_happen_time = 0;
		info_changed = true;
	end

	if info_changed then
		if info.db_exists then
			database.update("update manor_manufacture_player_line set next_gather_time = from_unixtime_s(%d), next_gather_gid = %d,event_happen_time = from_unixtime_s(%d),current_order_begin_time = from_unixtime_s(%d), current_order_last_time = %d, current_order_produce_rate = %d where pid = %d and line = %d",
					info.next_gather_time, info.next_gather_gid,info.event_happen_time,info.current_order_begin_time, info.current_order_last_time, info.current_order_produce_rate, self.pid, info.idx);
		else
			database.update("insert into manor_manufacture_player_line (pid, line, speed, next_gather_time, next_gather_gid, event_happen_time,current_order_begin_time, current_order_last_time, workman1_speed, workman1_produce_rate, workman2_speed, workman2_produce_rate, workman3_speed, workman3_produce_rate, workman4_speed, workman4_produce_rate, workman5_speed, workman5_produce_rate, current_order_produce_rate, storage1, storage2, storage3, storage4, storage5, storage6, storage_pool, order_limit) values(%d,%d,%d,from_unixtime_s(%d),%d, from_unixtime_s(%d),from_unixtime_s(%d), %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d)",
					self.pid, info.idx, info.speed, info.next_gather_time, info.next_gather_gid, info.event_happen_time,info.current_order_begin_time, info.current_order_last_time, info.workman1_speed, info.workman1_produce_rate, info.workman2_speed, info.workman2_produce_rate, info.workman3_speed, info.workman3_produce_rate, info.workman4_speed, info.workman4_produce_rate, info.workman5_speed, info.workman5_produce_rate,info.current_order_produce_rate, info.storage1, info.storage2, info.storage3, info.storage4, info.storage5, info.storage6, info.storage_pool, info.order_limit);
			info.db_exists = true;
		end
	end

	if line_produce_rate_change then
		database.update("replace into manor_manufacture_player_line_produce_rate(pid, line, line_produce_rate, line_produce_rate_begin_time, line_produce_rate_end_time, line_produce_rate_reason, line_produce_rate_depend_fight, line_produce_rate_extra_data) values(%d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), %d, %d, %d)", self.pid, info.idx, info.line_produce_rate, info.line_produce_rate_begin_time, info.line_produce_rate_end_time, info.line_produce_rate_reason, info.line_produce_rate_depend_fight, info.line_produce_rate_extra_data)
	end

	-- update database
	local workmen_uuids = {}
	for i = 1, 5 , 1 do
		if info.workmen["workman"..i] and info.workmen["workman"..i] ~= 0 then
			table.insert(workmen_uuids, info.workmen["workman"..i])
		end
	end

	for gid, order in pairs(changed_order) do
		local hero_item = {}
		local product = LoadProductConfig(order.gid)
		for i = 1, 6, 1 do
			if product.reward[i] and product.reward[i].type == 90 then
				local idx = 'gather_product_item'..tostring(i).."_value"
				table.insert(hero_item, {type = 90, id = product.reward[i].id, value = order[idx], uuids = workmen_uuids})
				order[idx] = 0
			end
		end

		if #hero_item > 0 then
			DOReward(self.pid, hero_item, nil, Command.REASON_MANOR_MANUFACTURE_GATHER, false, 0, nil)
		end
	
		database.update("update manor_manufacture_player_order set gather_count = %d, left_count = %d, gather_product_item1_value = %d, gather_product_item2_value = %d, gather_product_item3_value = %d, gather_product_item4_value = %d, gather_product_item5_value = %d, gather_product_item6_value = %d where pid = %d and line = %d and gid = %d", 	
				order.gather_count, order.left_count, order.gather_product_item1_value, order.gather_product_item2_value, order.gather_product_item3_value, order.gather_product_item4_value, order.gather_product_item5_value, order.gather_product_item6_value, self.pid, info.idx, gid);
	end

	--print("#######################", sprinttb(gather_product_pool_change_order))
	for _, order in pairs(gather_product_pool_change_order) do
		for _, item in ipairs(order.gather_product_pool) do
			if item.change then
				database.update("replace into manor_manufacture_player_line_pool_storage(pid, line, gid, type, id, value, stolen_value) values(%d, %d, %d, %d, %d, %d, %d)", self.pid, info.idx, order.gid, item.type, item.id, item.value, item.stolen_value)
				item.change = nil
			end
		end
	end

	local manor_log = ManorLog.Get(self.pid)
	if manor_log then
		manor_log:FlushCache()
	end

	return info;
end

function Manufacture:ResetLineProduceRate(line, opt_id)
	local info = self:GetLineInfo(line)		
	if not info then
		return false, nil 
	end

	if info.line_produce_rate_begin_time == 0 or info.line_produce_rate_end_time == 0 then
		log.debug("fail to reset line produce rate, line produce rate is already 0")
		return false, self:CalcGatherInfo(info)
	end 

	if loop.now() > info.line_produce_rate_end_time then
		log.debug("fail to reset line produce rate, line produce rate is already 0")
		return false, self:CalcGatherInfo(info)
	end

	info.line_produce_rate = 0
	info.line_produce_rate_begin_time = 0
	info.line_produce_rate_end_time = 0
	info.line_produce_rate_reason = 0
	info.line_produce_rate_depend = 0
	info.line_produce_rate_extra_data = 0
	
	database.update("replace into manor_manufacture_player_line_produce_rate(pid, line, line_produce_rate, line_produce_rate_begin_time, line_produce_rate_end_time, line_produce_rate_reason, line_produce_rate_depend_fight, line_produce_rate_extra_data) values(%d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), %d, %d, %d)", self.pid, info.idx, info.line_produce_rate, info.line_produce_rate_begin_time, info.line_produce_rate_end_time, info.line_produce_rate_reason, info.line_produce_rate_depend_fight, info.line_produce_rate_extra_data)

	local manor_log = ManorLog.Get(self.pid)
	manor_log:AddLog(EVENT_RESET_PRODUCE_RATE, {info.idx, loop.now(), opt_id})

	return true, self:CalcGatherInfo(info)
end

function Manufacture:EventCD(info, event_type, time)
	print("aaaaaa", info.idx, event_type, time)
	if not info.event_cd[event_type] then
		print("bbbbbbbbbbbbb")
		info.event_cd[event_type] = 0
		--database.update("insert into manor_manufacture_line_event_cd(pid,line,event_type,time_cd) values(%d,%d,%d,from_unixtime_s(%d))",self.pid,info.idx,event_type,info.event_cd[event_type])
	end

	print("cccccc", sprinttb(info.event_cd))
	if time <= info.event_cd[event_type] then
		return true
	end

	return false
end

function Manufacture:UpdateEventCD(info, event_type, time, interval)
	print("dddddddddddd", info.idx, event_type, time)
	if not info.event_cd[event_type] then
		print("eeeeeeeeeeeee")
		info.event_cd[event_type] = 0
	end

	print("fffffff", sprinttb(info.event_cd))
	info.event_cd[event_type] = time + interval
	database.update("replace into manor_manufacture_line_event_cd(pid,line,event_type,time_cd) values(%d,%d,%d,from_unixtime_s(%d))",self.pid,info.idx,event_type,info.event_cd[event_type])
	
end

function Manufacture:GetRandomEvent(info, time)
	--return EVENT_PRODUCE_RATE_DOWN
	local t = {total_weight = 0, pool = {}}
	local pool_cfg = GetManorEventPool(info.idx)
	for _, v in ipairs(pool_cfg or {}) do
		if not self:EventCD(info, v.event_type, time) then
			t.total_weight = t.total_weight + v.weight
			table.insert(t.pool, v)
		end
	end

	if t.total_weight > 0 then
		local rand = math.random(0, t.total_weight)
		for _, v in ipairs(t.pool) do
			if rand <= v.weight then
				self:UpdateEventCD(info, v.event_type, time, v.cd)
				return v.event_type
			end

			rand = rand - v.weight
		end
	end

	return 0 
end

function Manufacture:triggerEvent(info, event_happen_time)
	local event = self:GetRandomEvent(info, event_happen_time)
	local manor_log = ManorLog.Get(self.pid)
	if event == EVENT_LAZE then
		local total_add_time = 0
		local total_reduce_time = 0
		local laze_heros = {}
		local hardworking_heros = {}
		local duration = info.next_gather_time - info.current_order_begin_time
		for i = 1, WORKMAN_LIMIT do
			if info.workmen["workman"..i.."_gid"] and info.workmen["workman"..i.."_gid"] ~= 0 then
				--local gid = ManorWorkman.GetWorkmanGID(self.pid, info.workmen.workman1)
				local gid = info.workmen["workman"..i.."_gid"]
				
				print("gid>>>>>>>>>>>>>>>>>", gid)
				if gid > 0 then
					local cfg = GetManorLazeEventConfig(gid, info.idx)
					if cfg then
						local rand = math.random(0, cfg.total_weight)
						--print("rand>>>>>>>>>>>>>", rand, cfg.total_weight)
						for k, v in ipairs(cfg.events) do
							if rand <= v.weight then
								local time = math.ceil(duration * (v.effect_time / 10000))
								print("laze event >>>>>>>>>>>>>>>>>>", gid, time, v.effect_time, v.max_time)
								if time > 0 then
									if v.event_type == 1 then
										total_add_time = total_add_time + time > v.max_time and v.max_time or time 
										table.insert(laze_heros, {gid, time > v.max_time and v.max_time or time})
									elseif v.event_type == 2 then
										total_reduce_time = total_reduce_time + time > v.max_time and v.max_time or time
										table.insert(hardworking_heros, {gid, time > v.max_time and v.max_time or time})
									end	
								end
								break;
							else
								rand = rand - v.weight
							end	
						end
					end
				end
			end
		end

		--print("laze heros >>>>", sprinttb(laze_heros))
		--print("hardworking heros >>>>", sprinttb(hardworking_heros))
		--print("total_add_time, total_reduce_time", total_add_time, total_reduce_time, duration)
		if #laze_heros > 0 or #hardworking_heros > 0 then
			manor_log:AddLog(EVENT_LAZE, {info.idx, event_happen_time, total_add_time, total_reduce_time, laze_heros, hardworking_heros}, true)
		end
		return EVENT_LAZE, (info.next_gather_time + total_add_time - total_reduce_time) > event_happen_time and (info.next_gather_time + total_add_time - total_reduce_time) or event_happen_time	
	end

	if event == EVENT_PRODUCE_RATE_DOWN then
		local cfg = GetManorRandomEventParam(event)
		manor_log:AddLog(EVENT_PRODUCE_RATE_DOWN, {info.idx, event_happen_time, cfg.effect_percent, cfg.id}, true)
		return EVENT_PRODUCE_RATE_DOWN, cfg.effect_percent, event_happen_time, event_happen_time + cfg.duration, cfg.fight_id, cfg.id
	end

	return 0
end

function Manufacture:CancelOrder(line, gid, count)
	log.debug("Player %d cancel order %d for line %d count %d", self.pid, gid, line, count)
	local this = self
	local info = self:GetLineInfo(line);
	if not info then
		return
	end

	local changed_order = {};

	--cancel order
	local order = info.orders[gid]
	if order == nil or order.left_count <= 0 then
		print("order not exist")
		return false
	end
	count = order.left_count < count and order.left_count or count

	local choose_idx = 0;
	local waiting_orders = {}
	for gid, order in pairs(info.orders) do
		if order.left_count > 0 then
			table.insert(waiting_orders, order);
			if order.gid == gid then
				choose_idx = #waiting_orders;
			end
		end
	end

	--payback material
	local p = LoadProductConfig(gid);
	if not p then
		log.debug("cannt get cfg for order %d", gid)
		return false
	end	
	
	if p then
		local consume = mergeItem({}, p.consume, count);
		consume = discountItem(consume, 0.8)
		if #consume > 0 then
			if not DOReward(self.pid, consume, nil, Command.REASON_MANOR_MANUFACTURE_GATHER, false, 0, nil) then
				log.warning("pay back consume fail");
				return false 
			end
		end
	end

	order.left_count = order.left_count - count   
	changed_order[order.gid] = order;
	if order.left_count == 0 then
		table.remove(waiting_orders, choose_idx);
	end
		
	local info_changed = false;
	if gid == info.next_gather_gid and order.left_count == 0 and #waiting_orders > 0 then
		-- choose an order
		choose_idx = random(1, #waiting_orders);
		local choose = waiting_orders[choose_idx];

		-- set next gather time
		local product = LoadProductConfig(choose.gid);
		local time = math.random(product.time.min, product.time.max);

		local workmanInfo = ManorWorkman.Get(self.pid)
		for i = 1, WORKMAN_LIMIT do
			if info.workmen["workman"..i] and info.workmen["workman"..i] ~= 0  then
				workmanInfo:ChangeWorkmanBusyStatus(info.workmen["workman"..i], WORK_STATE_BUSY, loop.now())
			end
		end 

		info.current_order_begin_time = loop.now() 
		info.current_order_last_time = time
		info.next_gather_gid  = choose.gid
		info.current_order_produce_rate = info.workman1_produce_rate + info.workman2_produce_rate + info.workman3_produce_rate + info.workman4_produce_rate + info.workman5_produce_rate
		info.event_happen_time = 0
		info_changed = true;
	end

	if #waiting_orders == 0 and (info.next_gather_time ~= 0 or info.next_gather_gid ~= 0) then
		--change workman busy status
		local workmanInfo = ManorWorkman.Get(self.pid)
		for i = 1, WORKMAN_LIMIT do
			if info.workmen["workman"..i] and info.workmen["workman"..i] ~= 0  then
				workmanInfo:ChangeWorkmanBusyStatus(info.workmen["workman"..i], WORK_STATE_INLINE_FREE, loop.now())
			end
		end 
		-- nothing to product
		info.next_gather_time = 0;
		info.next_gather_gid = 0;
		info.current_order_begin_time = 0;
		info.current_order_last_time = 0;
		info.current_order_produce_rate = 0;
		info_changed = true;
	end

	if info_changed then
		if info.db_exists then
			database.update("update manor_manufacture_player_line set next_gather_time = from_unixtime_s(%d), next_gather_gid = %d, current_order_begin_time = from_unixtime_s(%d), current_order_last_time = %d, current_order_produce_rate = %d where pid = %d and line = %d",
					info.next_gather_time, info.next_gather_gid, info.current_order_begin_time, info.current_order_last_time, info.current_order_produce_rate, self.pid, info.idx);
		else
			database.update("insert into manor_manufacture_player_line (pid, line, speed, next_gather_time, next_gather_gid, current_order_begin_time, current_order_last_time, workman1_speed, workman1_produce_rate, workman2_speed, workman2_produce_rate, workman3_speed, workman3_produce_rate, workman4_speed, workman4_produce_rate, workman5_speed, workman5_produce_rate, current_order_produce_rate, storage1, storage2, storage3, storage4, storage5, storage6, storage_pool, order_limit) values(%d,%d,%d,from_unixtime_s(%d),%d, from_unixtime_s(%d), %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d)",
					self.pid, info.idx, info.speed, info.next_gather_time, info.next_gather_gid, info.current_order_begin_time, info.current_order_last_time, info.workman1_speed, info.workman1_produce_rate, info.workman2_speed, info.workman2_produce_rate, info.workman3_speed, info.workman3_produce_rate, info.workman4_speed, info.workman4_produce_rate, info.workman5_speed, info.workman5_produce_rate,info.current_order_produce_rate, info.storage1, info.storage2, info.storage3, info.storage4, info.storage5, info.storage6, info.storage_pool, info.order_limit);
			info.db_exists = true;
		end
	end

	for gid, order in pairs(changed_order) do
		database.update("update manor_manufacture_player_order set gather_count = %d, left_count = %d, gather_product_item1_value = %d, gather_product_item2_value = %d, gather_product_item3_value = %d, gather_product_item4_value = %d, gather_product_item5_value = %d, gather_product_item6_value = %d where pid = %d and line = %d and gid = %d", 	
				order.gather_count, order.left_count, order.gather_product_item1_value, order.gather_product_item2_value, order.gather_product_item3_value, order.gather_product_item4_value, order.gather_product_item5_value, order.gather_product_item6_value, self.pid, info.idx, gid);
	end

	return self:MakeLineRespond(info)
end

function Manufacture:ReloadWorkmanPropertyAndPower(line, info)
	--[[local info = self:GetLineInfo(line);
	if not info then
		return;
	end--]]
	
	--reload workman property and power 
	local org_left_time = self:GetOriginLeftTime(info)
	local workmanInfo = ManorWorkman.Get(self.pid)
	local qualifiedWorkmanInfo = GetManufactureQualifiedWorkmen(self.pid)
	local powerReload
	for i = 1, WORKMAN_LIMIT do
		if info.workmen["workman"..i] and info.workmen["workman"..i] ~= 0  then
			powerReload = workmanInfo:ReloadWorkmanInfo(info.workmen["workman"..i], true)
			qualifiedWorkmanInfo:GetProperty(info.workmen["workman"..i], nil, true)		
		end
	end 
	--change speed
	local new_workman1_speed, new_workman1_produce_rate = self:GetWorkmanSpeedAndProduceRate2(line, info, 1)
	local new_workman2_speed, new_workman2_produce_rate = self:GetWorkmanSpeedAndProduceRate2(line, info, 2)
	local new_workman3_speed, new_workman3_produce_rate = self:GetWorkmanSpeedAndProduceRate2(line, info, 3)
	local new_workman4_speed, new_workman4_produce_rate = self:GetWorkmanSpeedAndProduceRate2(line, info, 4)
	local new_workman5_speed, new_workman5_produce_rate = self:GetWorkmanSpeedAndProduceRate2(line, info, 5)
	local speed_changed, produce_rate_changed = self:ChangeWorkmanSpeedAndProduceRate(line, info, new_workman1_speed, new_workman1_produce_rate, new_workman2_speed, new_workman2_produce_rate, new_workman3_speed, new_workman3_produce_rate, new_workman4_speed, new_workman4_produce_rate, new_workman5_speed, new_workman5_produce_rate)
	if powerReload or speed_changed then
		local new_next_gather_time = self:GetNextGatherTime(loop.now(), org_left_time, info, info.next_gather_gid)
		info.next_gather_time = new_next_gather_time;
		database.update("update manor_manufacture_player_line set next_gather_time = from_unixtime_s(%d) where pid = %d and line = %d", info.next_gather_time, self.pid, line);
	end
end

function Manufacture:GetNextGatherTime(calc_time, time, info, gid)
	local workman_speed = info.workman1_speed + info.workman2_speed + info.workman3_speed + info.workman4_speed + info.workman5_speed
	log.debug(string.format("GetNextGatherTime begin:%d org_next_gather_time:%d  max_next_gather_time:%d  workman1_speed:%d workman2_speed:%d workman3_speed:%d workman4_speed:%d workman5_speed:%d line:%d", calc_time, math.ceil(calc_time + time * (100 / (100 + info.speed)) * (100 / (100 + workman_speed))), math.ceil(calc_time + time * (100 / (100 + info.speed))), info.workman1_speed, info.workman2_speed, info.workman3_speed, info.workman4_speed, info.workman5_speed, info.idx))
	if not self:CanSpeedUpByWorkman(info.idx, gid) then
		return math.ceil(calc_time + time * (100 / (100 + info.speed)))
	end

	return math.ceil(calc_time + time * (100 / (100 + info.speed)) * (100 / (100 + workman_speed)))
end

function Manufacture:GetOriginLeftTime(info)
	if info.next_gather_time == 0 then
		return 0, 0, 0
	end

	if not self:CanSpeedUpByWorkman(info.idx, info.next_gather_gid) then
        log.debug(string.format("Finish GetOriginLeftTime,  cannot speed up,  org_left_time:%d next_speed_change_time:%d", info.next_gather_time - loop.now(), 0))
        return info.next_gather_time - loop.now() , info.next_gather_time - loop.now(), 0 
    end

	local origin_left_time = (info.next_gather_time - loop.now()) * (((100 + info.workman1_speed + info.workman2_speed + info.workman3_speed + info.workman4_speed + info.workman5_speed) / 100) * ((100 + info.speed) / 100)) 	
	log.debug(string.format("Finish GetOriginLeftTime line:%d origin_left_time %d", info.idx, origin_left_time))

	return origin_left_time, 0, 0 	
end

function Manufacture:ClearThief(line, opt_id, thief)
	local info = self:GetLineInfo(line)
	
	if not info then
		return false, nil
	end

	if not info.thieves[thief] or loop.now() < info.thieves[thief].begin_time or loop.now() > info.thieves[thief].end_time then
		log.debug(string.format("not has thief %d", thief))
		return false, self:CalcGatherInfo(info)
	end

	if not DOReward(self.pid, info.thieves[thief].stolen_goods, nil, Command.REASON_MANOR_MANUFACTURE_PAY_BACK_STOLEN_GOODS, false, 0, nil) then
		log.debug("pay back stolen reward fail")
		return false, self:CalcGatherInfo(info) 
	end

	info.thieves[thief] = nil 
	database.update("delete from manor_manufacture_line_thieves where pid = %d and thief = %d and line = %d", self.pid, thief, line)
	
	local manor_log = ManorLog.Get(self.pid)
	manor_log:AddLog(EVENT_CLEAR_THIEF, {info.idx, loop.now(), thief, opt_id})

	return true, self:MakeLineRespond(info)
end

local STEAL_PERCENT = 20
local STEAL_GUARANTEE = 60
local THIEF_DURATION = 15 * 60
function Manufacture:Steal(line, thief)
	local info = self:GetLineInfo(line);

	if not info then
		return false
	end

	local line_cfg = LoadLineConfig(line)
	if not line_cfg then
		log.debug("steal fail, cannt get line cfg")
		return false
	end

	for thief_id, v in pairs(info.thieves) do
		if loop.now() >= v.begin_time and loop.now() <= v.end_time then
			log.debug("already exist a thief %d", thief_id)
			return false
		end
	end

	if self.pid == thief then
		log.debug("thief cannt be self")
		return false	
	end

	local stolen_reward = {}
	local amf_stolen_reward = {}
	local change_order = {}
	local change_pool_order = {}
	for gid, order in pairs(info.orders) do
		if order.gather_count > 0 then
			local product = LoadProductConfig(gid);
			if product then
				for k, v in ipairs(product.reward) do
					if v.type ~= 90 then
						local reward_value = order["gather_product_item"..k.."_value"]
						local stolen_value = math.floor(reward_value * line_cfg.every_steal_percent / 100)
						log.debug("stolen value >>>>>>>>>", k, order["stolen_value"..k], order["gather_product_item"..k.."_value"], line_cfg.steal_guarantee)
						local can_be_stolen = order["stolen_value"..k] / (order["gather_product_item"..k.."_value"] + order["stolen_value"..k]) * 100 < (100 - line_cfg.steal_guarantee)
						if stolen_value > 0 and can_be_stolen then
							change_order[gid] = change_order[gid] or {}
							table.insert(change_order[gid], {final_value = reward_value - stolen_value, index = k, stolen_value = order.stolen_value + stolen_value})
							table.insert(stolen_reward, {type = v.type, id = v.id, value = stolen_value})
							table.insert(amf_stolen_reward, {v.type, v.id, stolen_value})
						end
					end
				end
			end

			if #order.gather_product_pool > 0 then
				for _, item in ipairs(order.gather_product_pool) do
					local stolen_value = math.floor(item.value * line_cfg.every_steal_percent / 100)
					local can_be_stolen = item.stolen_value / (item.value + item.stolen_value) * 100 < (100 -line_cfg.steal_guarantee) 
					if stolen_value > 0 and can_be_stolen then
						change_pool_order[gid] = change_pool_order[gid] or {}
						table.insert(change_pool_order[gid], {type = item.type, id = item.id, value = item.value - stolen_value, stolen_value = item.stolen_value + stolen_value})
						table.insert(stolen_reward, {type = item.type, id = item.id, value = stolen_value})
						table.insert(amf_stolen_reward, {item.type, item.id, stolen_value})
					end
				end
			end
		end
	end

	if #stolen_reward  == 0 then
		log.debug("nothing to steal")
		return false
	end

	--print("stolen reward >>>>>>>>>>", sprinttb(stolen_reward), Serialize.TransformTb2Str(stolen_reward))
	--send reward
	if not DOReward(thief, stolen_reward, line_cfg.steal_count_item, Command.REASON_MANOR_MANUFACTURE_STEAL_OTHERS, false, 0, nil) then
		log.debug("steal send reward fail or cost count item fail")
		return false
	end

	info.thieves[thief] = {line = line, thief = thief, begin_time = loop.now(), end_time = loop.now() + THIEF_DURATION, stolen_goods = stolen_reward, depend_fight_id = 13110106}
	database.update("replace into manor_manufacture_line_thieves(pid, line, thief, begin_time, end_time, depend_fight_id, stolen_goods) values (%d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), %d, '%s')", self.pid, line, thief, loop.now(), loop.now() + THIEF_DURATION, 13110106, Serialize.TransformTb2Str(stolen_reward))

	local manor_log = ManorLog.Get(self.pid)
	manor_log:AddLog(EVENT_STEAL, {line, loop.now(), thief, amf_stolen_reward})

	for gid, v in pairs(change_order) do
		local sql = "update manor_manufacture_player_order set %s"..string.format(" where line = %d and pid = %d and gid = %d", line, self.pid, gid)
		local sql2 = ""
		for k, v2 in ipairs(v) do
			if k ~= #v then
				sql2 = sql2..string.format("gather_product_item%d_value = %d, stolen_value%d = %d, ", v2.index, v2.final_value, v2.index, v2.stolen_value)
			else
				sql2 = sql2..string.format("gather_product_item%d_value = %d, stolen_value%d = %d", v2.index, v2.final_value, v2.index, v2.stolen_value)
			end	

			if info.orders[gid] then
				info.orders[gid][string.format("gather_product_item%d_value", v2.index)] = v2.final_value
				info.orders[gid][string.format("stolen_value%d", v2.index)] = v2.stolen_value
			end
		end

		database.update(string.format(sql, sql2))
	end	

	for gid, v in pairs(change_pool_order) do 
		for k, v2 in ipairs(v) do
			database.update("replace into manor_manufacture_player_line_pool_storage (pid, line, gid, type, id, value, stolen_value)values(%d, %d, %d, %d, %d, %d, %d)", self.pid, line, gid, v2.type, v2.id, v2.value, v2.stolen_value)
		end

		if info.orders[gid] then
			info.orders[gid].gather_product_pool= v
		end
	end

	return true, self:MakeLineRespond(info)
end

function Manufacture:Gather(line)
	local info = self:GetLineInfo(line);

	if not info then
		return
	end

	if not checkLineOpen(self.pid, line) then
		log.debug(string.format('line %d of player %d not open', line, self.pid)); 
		return 
	end

	local reward = {}
	local gathed_order = {}
	local reward_amf = {}
	local gids = {}
	local gather_product_pool_change_order = {}

	local update_gids = nil;
	local removed_gids = nil;

	-- 收获的订单总数
	local total_order_gather_count = 0

	for gid, order in pairs(info.orders) do
		if order.gather_count > 0 then
			total_order_gather_count = total_order_gather_count + order.gather_count
			local product = LoadProductConfig(gid);
			table.insert(gids, gid)
			if product then
				for k,v in ipairs(product.reward) do
					local reward_value = order["gather_product_item"..k.."_value"]
					if info["storage"..k] ~= 0 and order["gather_product_item"..k.."_value"] > info["storage"..k] then
						reward_value = info["storage"..k]
					end
					if v.type ~= 90 and reward_value > 0 then
						table.insert(reward, {type = v.type, id = v.id, value = reward_value})
						table.insert(reward_amf, {v.type, v.id, reward_value})
					end
				end

				if order.left_count <= 0 then
					removed_gids = (removed_gids and removed_gids .. "," or "") .. gid
				else
					update_gids = (update_gids and "," or "") .. gid
				end

				table.insert(gathed_order, gid);
			end

			if #order.gather_product_pool > 0 then
				for _, item in ipairs(order.gather_product_pool) do
					if item.value > 0 then
						table.insert(reward, {type = item.type, id = item.id, value = item.value})
						table.insert(reward_amf, {item.type, item.id, item.value})
						table.insert(gather_product_pool_change_order, gid)
					end
				end
			end
		end
	end

	print("Manufacture:Gather reward count", #reward);

	-- reward
	--商铺添加隐藏道具
	if line == 31 then
		table.insert(reward, {type = 41, id = 100000, value = 1})		
	end	

	--print("reward >>>>>>>>>>>>>>>>>>>>>>>>>>", sprinttb(reward))
	if not DOReward(self.pid, reward, nil, Command.REASON_MANOR_MANUFACTURE_GATHER, false, loop.now() + 14 * 24 * 3600, nil) then
		return
	end

	-- trigger event
	local manor_event = ManorEvent.Get(self.pid)
	-- lucky event
	manor_event:TriggerLuckyEvent({info.idx, reward[1] and reward[1].value or 0, reward[2] and reward[2].value or 0, reward[3] and reward[3].value or 0, self.pid})
	-- popular event
	manor_event:TriggerPopularEvent(self.pid, line, nil, 1)

	-- update
	if update_gids then
		-- update database
		database.update("update manor_manufacture_player_order set gather_count = 0, gather_product_item1_value = 0, gather_product_item2_value = 0, gather_product_item3_value = 0, gather_product_item4_value = 0, gather_product_item5_value = 0, gather_product_item6_value = 0, stolen_value1 = 0, stolen_value2 = 0, stolen_value3 = 0, stolen_value4 = 0, stolen_value5 = 0, stolen_value6 = 0 where line = %d and pid = %d and gid in (%s)", line, self.pid, update_gids)
	end

	-- remove
	if removed_gids then
		database.update("delete from manor_manufacture_player_order where line = %d and pid = %d and gid in (%s)", line, self.pid, removed_gids)
	end

	if #gather_product_pool_change_order > 0 then
		database.update("delete from manor_manufacture_player_line_pool_storage where line = %d and pid = %d", line, self.pid) 
	end

	for _, gid in ipairs(gather_product_pool_change_order) do
		info.orders[gid].gather_product_pool = {}
	end

	-- set gather count = 0;
	for _, gid in ipairs(gathed_order) do
		if info.orders[gid].left_count > 0 then
			info.orders[gid].gather_count = 0;
			info.orders[gid].gather_product_item1_value = 0;
			info.orders[gid].gather_product_item2_value = 0;
			info.orders[gid].gather_product_item3_value = 0;
			info.orders[gid].gather_product_item4_value = 0;
			info.orders[gid].gather_product_item5_value = 0;
			info.orders[gid].gather_product_item6_value = 0;
			info.orders[gid].stolen_value1 = 0;
			info.orders[gid].stolen_value2 = 0;
			info.orders[gid].stolen_value3 = 0;
			info.orders[gid].stolen_value4 = 0;
			info.orders[gid].stolen_value5 = 0;
			info.orders[gid].stolen_value6 = 0;
		else
			info.orders[gid] = nil;
		end
	end

	--add log
	local manor_log = ManorLog.Get(self.pid)
	manor_log:AddLog(EVENT_TYPE_GATHER, {line, gids, reward_amf, loop.now()})

	--quest
	if line >= 1 and line <= 4 then
		cell.NotifyQuestEvent(self.pid, {{type = 4, id = 17, count = 1}})	
	end

	cell.NotifyQuestEvent(self.pid, {{type = 53, id = line, count = total_order_gather_count}})

	return self:MakeLineRespond(info), makeItemTrup(reward);
end

function Manufacture:GetWorkmanSpeedAndProduceRate2(line, info, pos)
	local speed = 0
	local produce_rate = 0 
	local workmanConfig = GetWorkmanConfig(line) 
	if not workmanConfig then
		log.warning("fail to GetWorkmanSpeed, cannt get config")	
		return speed, produce_rate
	end
	if not workmanConfig.need_workman then
		return speed, produce_rate 
	end
	local speed_score = 0
	local produce_score = 0 

	local line_cfg = LoadLineConfig(line)
	if not line_cfg then
		return speed, produce_rate 
	end

	local property_index = "property_id" .. pos
	for _, v in ipairs(line_cfg.property_list) do
		if effect_config[v[property_index]] == EFFECT_SPEEDUP then 	
			speed_score = speed_score + GetManufactureQualifiedWorkmen(self.pid):GetProperty(info.workmen["workman"..pos] ,v[property_index]) * v["property_percent" .. pos] / 100
		elseif effect_config[v[property_index]] == EFFECT_PRODUCEUP then
			produce_score = produce_score +  GetManufactureQualifiedWorkmen(self.pid):GetProperty(info.workmen["workman"..pos] ,v[property_index]) * v["property_percent"..pos] / 100
		end		
	end	
	
	--if effect_config[line_cfg["property_id"..pos]] == EFFECT_SPEEDUP then	
	--	speed_score = speed_score + GetManufactureQualifiedWorkmen(self.pid):GetProperty(info.workmen["workman"..pos] ,line_cfg["property_id"..pos]) * line_cfg["property_percent"..pos] / 100
	--end

	--if effect_config[line_cfg["property_id"..pos]] == EFFECT_PRODUCEUP then	
	--	produce_score = produce_score +  GetManufactureQualifiedWorkmen(self.pid):GetProperty(info.workmen["workman"..pos] ,line_cfg["property_id"..pos]) * line_cfg["property_percent"..pos] / 100
	--end
	
	local speed_adjust_score = speed_score * line_cfg.factor/10000
	speed = math.ceil(math.min(2, speed_adjust_score) * 100)

	local produce_adjust_score = produce_score * line_cfg.factor/10000
	produce_rate = math.ceil(math.min(2, produce_adjust_score) * 100) 

	return speed, produce_rate
end

function Manufacture:CanSpeedUpByWorkman(line, gid)
	local line_cfg = LoadLineConfig(line)
	local product = LoadProductConfig(gid);
	if not line_cfg or not product then
		return false
	end
	if line_cfg.material_type == 0 then
		return true
	end
	return line_cfg.material_type == product.material_type
end

function Manufacture:CheckWorkman(line, info)
	local workmanConfig = GetWorkmanConfig(line) 
	if not workmanConfig then
		log.warning("fail to CheckWorkman, cannt get config")	
		return nil
	end
	if not workmanConfig.need_workman then

		return 0
	end 
	local workmanCount = 0
	for i= 1 , workmanConfig.workman_max do
		if info.workmen["workman"..i] and info.workmen["workman"..i] ~= 0 then
			workmanCount = workmanCount + 1
		end	
	end  
	if workmanCount < workmanConfig.workman_min then
		log.warning("fail to CheckWorkman, workman not enough")	
		return nil
	end
	return 0
end

function Manufacture:CheckLineLevel(line, levelLimit, info)
	if info.level < levelLimit then 
		return nil
	end
	return 0
end

local function checkClientConsume(consume, client_consume)
	local final_consume = {}
	for k, v in ipairs (consume) do
		if not (v.type == client_consume[k][1] and v.id == client_consume[k][2] and v.value == client_consume[k][3]) then
			return false
		else
			table.insert(final_consume, {type = v.type, id = v.id, value = v.value, uuid = client_consume[k][4] and client_consume[k][4] or nil})
		end	
	end

	return true, final_consume
end

--local MAX_ORDER_COUNT = 3000
function Manufacture:StartProduce(gid, n, client_consume)
	local product = LoadProductConfig(gid);
	if not product then
		log.warning("  product not exists");
		return
	end

	if n < product.count.min then
		log.warning("  product count not enough");
		return;
	end

	local info = self:GetLineInfo(product.line);
	if not info then
		log.warning("  product line not exists");
		return;
	end

	if not checkLineOpen(self.pid, product.line) then
	        log.debug(string.format('line %d of player %d not open', product.line, self.pid));
        	return 
	end

	if not self:CheckWorkman(product.line, info) then
		log.warning(" work man not enough")
		return;
	end

	if not self:CheckLineLevel(product.line, product.level_limit, info) then
		log.warning(" line level is not enough")
		return;
	end
	
	local order = info.orders[gid];
	
	local order_total_left_count = 0
	for k, v in pairs(info.orders) do
		order_total_left_count = order_total_left_count + v.left_count		
	end
	
	if order_total_left_count >= info.order_limit then
		log.warning(string.format("order left count reach max,  now left count:%d, limit:%d", order_total_left_count, info.order_limit))
		return nil
	end

	local consume = mergeItem({}, product.consume, n);
	
	if client_consume then
		local success, final_consume = checkClientConsume(consume, client_consume)
		if success then
			consume = final_consume 
		else
			log.debug("check consume form client fail")
		end	
	end

	if not DOReward(self.pid, nil, consume, Command.REASON_MANOR_MANUFACTURE_GATHER, false, 0, nil) then
		log.warning("  consume failed")--, sprinttb(consume));
		return nil
	end

	if not order then
		order = {gid = gid, left_count = n, gather_count = 0}
		info.orders[gid] = order;
		database.update("insert into manor_manufacture_player_order(pid, line, gid, left_count, gather_count, gather_product_item1_value, gather_product_item2_value, gather_product_item3_value, gather_product_item4_value, gather_product_item5_value, gather_product_item6_value, stolen_value1, stolen_value2, stolen_value3, stolen_value4, stolen_value5, stolen_value6) value(%d,%d,%d,%d,%d, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)", 
				self.pid, info.idx, order.gid, order.left_count, order.gather_count);
		info.orders[gid].gather_product_item1_value = 0
		info.orders[gid].gather_product_item2_value = 0
		info.orders[gid].gather_product_item3_value = 0
		info.orders[gid].gather_product_item4_value = 0
		info.orders[gid].gather_product_item5_value = 0
		info.orders[gid].gather_product_item6_value = 0
		info.orders[gid].stolen_value1 = 0
		info.orders[gid].stolen_value2 = 0
		info.orders[gid].stolen_value3 = 0
		info.orders[gid].stolen_value4 = 0
		info.orders[gid].stolen_value5 = 0
		info.orders[gid].stolen_value6 = 0
		info.orders[gid].gather_product_pool = {}
	else
		order.left_count = order.left_count + n--MAX_ORDER_COUNT);
		database.update("update manor_manufacture_player_order set left_count = %d where pid = %d and line = %d and gid = %d", order.left_count, self.pid, info.idx, gid);
	end

	--[[local workmanInfo = ManorWorkman.Get(self.pid)
	for i = 1, WORKMAN_LIMIT do
		if info.workmen["workman"..i] and info.workmen["workman"..i] ~= 0  then
			workmanInfo:ChangeWorkmanBusyStatus(info.workmen["workman"..i], WORK_STATE_BUSY, loop.now())
		end
	end]] 

	self:CalcGatherInfo(info);

	--add log
	--local manor_log = ManorLog.Get(self.pid)
	--manor_log:AddLog(EVENT_TYPE_START_PRODUCE, {product.line, gid, n})

	-- TODO: make respond
	return self:MakeLineRespond(info);
end

function Manufacture:Speedup(line, speed, forever)
	local info = self:GetLineInfo(line);
	if not info then
		return;
	end

	local now = loop.now();
	if info.next_gather_time > 0 then
		assert(info.next_gather_time > now);

		local left_time = info.next_gather_time - now;

		local org_left_time = math.ceil(left_time / (100 / (100 + info.speed)));
		-- cacl new left time
		local new_left_time = math.ceil(org_left_time * (100 / (100 + speed))) 

		local diff = left_time - new_left_time;
		if diff > 0 then
		-- TODO: consume
		
		end

		-- update
		info.next_gather_time = new_next_gather_time;

		-- TODO: update database
		database.update("update manor_manufacture_player_line set next_gather_time = from_unixtime_s(%d) where pid = %d and line = %d", info.next_gather_time, self.pid, line);
	end

	if forever then
		info.speed = speed;
	end

	self:CalcGatherInfo(info);

	return self:MakeLineRespond(info);
end

function Manufacture:SpeedUpByWorkman(line, workman)
	log.debug("begin to speed up by workman")
	local info = self:GetLineInfo(line);
	if not info then
		return;
	end

	if info.next_gather_time == 0 or info.next_gather_time <= loop.now() then
		log.debug("speed up by workman fail, order already finish")
		return
	end

	local online, pos = self:WorkmanOnLine(workman, line)
	if not online then
		log.debug(string.format("speed up by workman fail, workman %d not on line %d", workman, line))
		return 
	end

	local workmanInfo = ManorWorkman.Get(self.pid)
	if not workmanInfo then
		return
	end

	local power = workmanInfo:GetWorkmanPower(workman)
	if power < 50 then
		log.debug("fail to speed up by workman, power not enough")
		return 
	end

	--[[if not workmanInfo:decreaseWorkmanPower(workman, 50) then
		log.debug("fail to speed up by workman, consume power fail")
		return 
	end--]]

	--consume workman power
	local speed_up_time = 10 * 60 
	local line_cfg = LoadLineConfig(line)
    if not line_cfg then
        return 
    end

	local cap = 0
    for _, v in ipairs(line_cfg.property_list) do
        cap = cap + GetManufactureQualifiedWorkmen(self.pid):GetProperty(info.workmen["workman"..pos] ,v["property_id"..pos])
    end

	if cap > 500 then
		speed_up_time = 10 * 60 + math.floor((cap - 500) / 100)
	end

	local now = loop.now()
	if info.next_gather_time > 0 then 
		assert(info.next_gather_time > now);
		self:CalcGatherInfo(info, speed_up_time);
	end

	if not workmanInfo:decreaseWorkmanPower(workman, 50) then
		log.debug("fail to speed up by workman, consume power fail")
		return 
	end

	return self:MakeLineRespond(info);
end

function Manufacture:FinishOrderImmediately(line, opt_pid)
	local info = self:GetLineInfo(line);
	if not info then
		return;
	end

	if not checkLineOpen(self.pid, line) then
        log.debug(string.format('line %d of player %d not open', line, self.pid));
        return
    end

	local now = loop.now();
	if info.next_gather_time > 0 then
		assert(info.next_gather_time > now);

		local diff = info.next_gather_time - now;
		local cfg = GetSpeedUpConsumeConfig()	
		if diff > 0 then
		-- TODO: consume
			if not opt_pid or opt_pid == self.pid then
				local consume = {{type = cfg.type or 41, id = cfg.id or 90006, value = math.ceil(diff / 60) * 1}} 
				if not DOReward(self.pid, nil, consume, Command.REASON_MANOR_MANUFACTURE_FINISH_IMMEDIATELY, false, 0, nil) then
					return
				end
			end
		end
		-- update
		info.next_gather_time = now;
	end

	self:CalcGatherInfo(info);

	local amf_info = self:MakeLineRespond(info);
	
	if opt_pid and opt_pid ~= pid then
		self:Notify(Command.NOTIFY_MANOR_OTHER_HELP_SPEEDUP, {opt_pid, amf_info})	
	end

	return self:MakeLineRespond(info);
end

function Manufacture:Notify(cmd, msg)
	NetService.NotifyClients(cmd, msg, {self.pid});
end

function Manufacture:MakeLineRespond(info)
	local orders = {}
	for gid, v in pairs(info.orders) do
		local product_pool = {}
		for _, item in ipairs(v.gather_product_pool) do
			table.insert(product_pool, {item.type, item.id, item.value, item.stolen_value})
		end		
		table.insert(orders, {gid, v.left_count, v.gather_count, v.gather_product_item1_value, v.gather_product_item2_value, v.gather_product_item3_value, v.gather_product_item4_value, v.gather_product_item5_value, v.gather_product_item6_value, product_pool, v.stolen_value1, v.stolen_value2, v.stolen_value3, v.stolen_value4, v.stolen_value5, v.stolen_value6});
	end

	local amf_thieves = {}
	for thief, v in pairs(info.thieves) do
		local ar = {}
		for _, v2 in ipairs(v.stolen_goods) do
			table.insert(ar, {v2.type, v2.id, v2.value})
		end
		if loop.now() >= v.begin_time and loop.now() <= v.end_time then
			table.insert(amf_thieves, {thief, v.begin_time, v.end_time, v.depend_fight_id, ar})
		end
	end

	local _, current_speed_left_time, next_speed_change_time = self:GetOriginLeftTime(info)

	local t = {
		info.idx, 
		info.speed, 
		info.next_gather_gid,
		info.next_gather_time,
		orders,
		{info.workmen.workman1 or 0, info.workmen.workman2 or 0, info.workmen.workman3 or 0, info.workmen.workman4 or 0, info.workmen.workman5 or 0, info.workmen.workman1_gid or 0, info.workmen.workman2_gid or 0, info.workmen.workman3_gid or 0, info.workmen.workman4_gid or 0, info.workmen.workman5_gid or 0},
		0, --(info.next_gather_time > 0) and (loop.now() + current_speed_left_time) or 0,
		(info.next_gather_time > 0) and next_speed_change_time or 0,
		info.storage1,
		info.storage2,
		info.storage3,
		info.current_order_begin_time,
		info.order_limit,
		info.level,
		info.storage4,
		info.storage5,
		info.storage6,
		info.current_order_produce_rate,
		{
			info.workman1_speed,
			info.workman2_speed,
			info.workman3_speed,
			info.workman4_speed,
			info.workman5_speed,
		},
		{
			info.workman1_produce_rate,
			info.workman2_produce_rate,
			info.workman3_produce_rate,
			info.workman4_produce_rate,
			info.workman5_produce_rate,
		},
		info.storage_pool,
		{info.line_produce_rate, info.line_produce_rate_begin_time, info.line_produce_rate_end_time, info.line_produce_rate_reason, info.line_produce_rate_depend_fight, info.line_produce_rate_extra_data},
		info.event_happen_time,
		amf_thieves,
	}

	return t;
end


function Manufacture:QueryProduct(pid)
	local productList = LoadProductConfig();
	local list = {}
	for _, v in pairs(productList) do
		local discount, begin_time, end_time = getOrderDiscount(pid, v.gid)
		table.insert(list, {
			v.gid,

			v.line,

			v.time.min,
			v.time.max,
			v.count.min,
			v.count.max,

			v.depend_item,

			makeItemTrup(v.consume),
			makeItemTrup(v.reward),	

			v.type,
			v.material_type,
			v.show_type,

			discount,
			begin_time,
			end_time,
	
			v.level_limit,
			v.product_pool1,
			v.product_pool2,
		});	
		print("pool2 >>>>>>>>>", v.line, v.product_pool2)
	end
	return list;
end

local function ValidLine(line)
	LoadProductConfig(1)
	return valid_line[line]  
end

function Manufacture:QueryProductLine()
	local list = {}
	for i = 1, PRODUCT_LINE_LIMIT do
		if ValidLine(i) then
			local info = self:GetLineInfo(i);
			table.insert(list, self:MakeLineRespond(info))
		end
	end
	return list
end

function Manufacture:IsBusy(info)
	return info.next_gather_time > 0
end

function Manufacture:GetWorkmanCount(info)
	local count = 0	
	for i = 1, WORKMAN_LIMIT do
		if info.workmen["workman"..i] and info.workmen["workman"..i] ~= 0 then
			count = count + 1
		end
	end 
	return count
end

function Manufacture:Employ(line, workman, pos)
	if not checkLineOpen(self.pid, line) then
        log.debug(string.format('line %d of player %d not open', line, self.pid));
        return 
    end

	LoadLineOpenConfig(line)
	local pos_cfg = GetLinePosOpenConfig(line, pos)
	if not pos_cfg then
		log.debug("cannt get line pos config")
		return 
	end

	if not checkLevelLimit(self.pid, pos_cfg.level_limit) then
		log.debug(string.format('Player %d line %d pos %d not open', self.pid, line, pos))
		return 
	end

	local playerHeroInfo = cell.getPlayerHeroInfo(self.pid, 0, workman)	
	if not playerHeroInfo then
		log.warning(string.format("fail to employ workman:%d player donnt has this hero", workman))
		return 
	end

	local workmanConfig = GetWorkmanConfig(line)
	if not workmanConfig then
		log.warning("fail to employ, cannt get workmanconfg")
		return 
	end

	if workmanConfig.need_workman and pos > workmanConfig.workman_max then
		log.warning("fail to employ, pos is too big")
		return 
	end

	local manor_hero = GetPlayerHeroInPub(self.pid)
	if manor_hero:GetHeroStatus(workman) == 1 then
		log.warning("fail to employ, workman leaving")
		return 
	end
	
	local lineInfo 
	local conflict_line
	local conflict_pos
	local conflict_lineInfo
	local conflict_workman
	local primary_workman

	for i = 1, PRODUCT_LINE_LIMIT do
		if ValidLine(i) then
			local info = self:GetLineInfo(i);
			if info then
				if i == line then
					lineInfo = info
					lineInfo.workmen["workman"..pos.."_gid"] = playerHeroInfo.gid
				end
				for j = 1, WORKMAN_LIMIT do
					if info.workmen["workman"..j] and info.workmen["workman"..j] ~= 0 and workman == info.workmen["workman"..j] then
						conflict_line = i 
						conflict_pos = j
						conflict_lineInfo = info
						conflict_lineInfo.workmen["workman"..pos.."_gid"] = playerHeroInfo.gid
						log.info(string.format("workman:%d already employed in line:%d pos:%d", workman, i, j))
						--return nil
					end
				end 
			end
		end
	end	

	if not lineInfo then
		return nil
	end
	
	if conflict_line and conflict_pos and conflict_line == line and conflict_pos == pos then
		log.warning("fail to employ, already employed in the same place")
		return nil
	end
	
	primary_workman = lineInfo.workmen["workman"..pos] 
	local workmanInfo = ManorWorkman.Get(self.pid)

	if conflict_line and conflict_pos and conflict_line ~= line and self:IsBusy(conflict_lineInfo) and (self:GetWorkmanCount(conflict_lineInfo) < 2 and (not primary_workman or primary_workman == 0)) then
		log.warning("fail to employ, workman :%d is the only workman  employed in line:%d and is busy", workman, conflict_line)
		return nil
	end

	if workman == 0 and self:GetWorkmanCount(lineInfo) < 2 and self:IsBusy(lineInfo) then
		log.warning("fail to kick out workman , last workman on line")
		return nil
	end

	if workman == 0 and primary_workman and primary_workman == 0 then
		return true
	end

	local function logic1(workman_id, state)
		if primary_workman then
			if conflict_pos then
				conflict_lineInfo.workmen["workman"..conflict_pos] = primary_workman
			end
		else
			if conflict_pos then
				conflict_lineInfo.workmen["workman"..conflict_pos] = 0 
			end
		end	
		if workman and state then
			workmanInfo:ChangeWorkmanBusyStatus(workman_id, state, loop.now())
		end
		return true
	end

	local function logic2(workman_id, state)
		lineInfo.workmen["workman"..pos] = workman
		if workman and state then
			workmanInfo:ChangeWorkmanBusyStatus(workman_id, state, loop.now())
		end
		return true
	end

	local function logic3(workman_id, state)
		logic1()
		logic2()
		if workman and state then
			workmanInfo:ChangeWorkmanBusyStatus(workman_id, state, loop.now())
		end
		return true
	end
	
	if conflict_line and conflict_line == line then
		self:ChangeLineWorkmanSpeedAndProduceRate(lineInfo, true, logic3)
	elseif conflict_line and conflict_line ~= line then
		self:ChangeLineWorkmanSpeedAndProduceRate(conflict_lineInfo, true, logic1, primary_workman, self:IsBusy(conflict_lineInfo) and WORK_STATE_BUSY or WORK_STATE_INLINE_FREE)
		self:ChangeLineWorkmanSpeedAndProduceRate(lineInfo, true, logic2, workman, self:IsBusy(lineInfo) and WORK_STATE_BUSY or WORK_STATE_INLINE_FREE)
	else
		if workman ~= 0 then
			self:ChangeLineWorkmanSpeedAndProduceRate(lineInfo, true, logic2, workman, self:IsBusy(lineInfo) and WORK_STATE_BUSY or WORK_STATE_INLINE_FREE)
		else
			self:ChangeLineWorkmanSpeedAndProduceRate(lineInfo, true, logic2)
		end

		if primary_workman and primary_workman ~= 0 then
			workmanInfo:ChangeWorkmanBusyStatus(primary_workman, WORK_STATE_FREE, loop.now())
		end
	end	

	--if not db_exist then
	database.update("replace into manor_manufacture_player_workman(pid, line, workman1, workman2, workman3, workman4, workman5,workman1_gid, workman2_gid, workman3_gid, workman4_gid, workman5_gid) values(%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)" , self.pid, line, lineInfo.workmen.workman1 or 0, lineInfo.workmen.workman2 or 0, lineInfo.workmen.workman3 or 0, lineInfo.workmen.workman4 or 0, lineInfo.workmen.workman5 or 0,lineInfo.workmen.workman1_gid or 0,lineInfo.workmen.workman2_gid or 0,lineInfo.workmen.workman3_gid or 0,lineInfo.workmen.workman4_gid or 0,lineInfo.workmen.workman5_gid or 0);
	if conflict_line and line ~= conflict_line then
		database.update("replace into manor_manufacture_player_workman(pid, line, workman1, workman2, workman3, workman4, workman5,workman1_gid, workman2_gid, workman3_gid, workman4_gid, workman5_gid) values(%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)" , self.pid, conflict_line, conflict_lineInfo.workmen.workman1 or 0, conflict_lineInfo.workmen.workman2 or 0, conflict_lineInfo.workmen.workman3 or 0, conflict_lineInfo.workmen.workman4 or 0, conflict_lineInfo.workmen.workman5 or 0,lineInfo.workmen.workman1_gid or 0,lineInfo.workmen.workman2_gid or 0,lineInfo.workmen.workman3_gid or 0,lineInfo.workmen.workman4_gid or 0,lineInfo.workmen.workman5_gid or 0);
	end

	--add log
	if (workman ~= 0) or (primary_workman and primary_workman ~= 0) then
		if not (conflict_line and conflict_line == line) then
			local manor_log = ManorLog.Get(self.pid)
			manor_log:AddLog(EVENT_TYPE_EMPLOY, {workman, conflict_line and conflict_line or 0, line, primary_workman and primary_workman or 0, loop.now()})
		end
	end
	
	return true
end

function Manufacture:GetWorkmanLineAndPos(workman)
	for i = 1, PRODUCT_LINE_LIMIT do
		if ValidLine(i) then
			local info = self:GetLineInfo(i);
			if info then
				for j = 1, WORKMAN_LIMIT do
					if info.workmen["workman"..j] and info.workmen["workman"..j] ~= 0 and workman == info.workmen["workman"..j] then
						return i, j, info 
					end
				end 
			end
		end
	end	
	return -1, -1, nil
end

function Manufacture:WorkmanOnLine(workman, line)
	if ValidLine(line) then
		local info = self:GetLineInfo(line);
		if info then
			for j = 1, WORKMAN_LIMIT do
				if info.workmen["workman"..j] and info.workmen["workman"..j] ~= 0 and workman == info.workmen["workman"..j] then
					return true, j 
				end
			end 
		end
	end

	return false, 0
end

function Manufacture:ChangeWorkmanSpeedAndProduceRate(line, lineInfo, new_workman1_speed, new_workman1_produce_rate, new_workman2_speed, new_workman2_produce_rate, new_workman3_speed, new_workman3_produce_rate, new_workman4_speed, new_workman4_produce_rate, new_workman5_speed, new_workman5_produce_rate)
	local speed_changed = false
	local produce_rate_changed = false
	speed_changed = (lineInfo.workman1_speed ~= new_workman1_speed) or (lineInfo.workman2_speed ~= new_workman2_speed) or (lineInfo.workman3_speed ~= new_workman3_speed) or (lineInfo.workman4_speed ~= new_workman4_speed) or (lineInfo.workman5_speed ~= new_workman5_speed)
	produce_rate_changed = (lineInfo.workman1_produce_rate ~= new_workman1_produce_rate) or (lineInfo.workman2_produce_rate ~= new_workman2_produce_rate) or (lineInfo.workman3_produce_rate ~= new_workman3_produce_rate) or (lineInfo.workman4_produce_rate ~= new_workman4_produce_rate) or (lineInfo.workman5_produce_rate ~= new_workman5_produce_rate) 

	if speed_changed or produce_rate_changed then
		lineInfo.workman1_speed = new_workman1_speed
		lineInfo.workman1_produce_rate = new_workman1_produce_rate
		lineInfo.workman2_speed = new_workman2_speed
		lineInfo.workman2_produce_rate = new_workman2_produce_rate
		lineInfo.workman3_speed = new_workman3_speed
		lineInfo.workman3_produce_rate = new_workman3_produce_rate
		lineInfo.workman4_speed = new_workman4_speed
		lineInfo.workman4_produce_rate = new_workman4_produce_rate
		lineInfo.workman5_speed = new_workman5_speed
		lineInfo.workman5_produce_rate = new_workman5_produce_rate
		if lineInfo.db_exists then
			database.update("update manor_manufacture_player_line set workman1_speed = %d, workman1_produce_rate = %d, workman2_speed = %d, workman2_produce_rate = %d, workman3_speed = %d, workman3_produce_rate = %d, workman4_speed = %d, workman4_produce_rate = %d, workman5_speed = %d, workman5_produce_rate = %d where pid = %d and line = %d", new_workman1_speed, new_workman1_produce_rate, new_workman2_speed, new_workman2_produce_rate, new_workman3_speed, new_workman3_produce_rate, new_workman4_speed, new_workman4_produce_rate, new_workman5_speed, new_workman5_produce_rate, self.pid, line)
		end
		return speed_changed, produce_rate_changed
	end
	return speed_changed, produce_rate_changed 
end

function Manufacture:LevelUp(line, level)
	if not checkLineOpen(self.pid, line) then
        log.debug(string.format('line %d of player %d not open', line, self.pid));
        return nil
    end

	local info = self:GetLineInfo(line)		

	if level ~= info.level + 1 then
		log.info("fail to levelup manufacture , level invalid")
		return nil
	end
	if not info then 
		log.info("fail to levelup manufacture , cannt get lineinfo for line:%d", line)	
		return nil
	end	
	
	local consume = GetConsumeByLevel(line, level) 
	if not consume then
		log.info("fail to levelup , cannt get consume cfg for level:%d",level)
		return nil
	end
	if not DOReward(self.pid, nil, consume, Command.REASON_MANOR_MANUFACTURE_LEVEL_UP, false, 0, nil) then
		log.info("fail to levelup manufacture,  consume failed");
		return nil
	end

	database.update("replace into manor_manufacture_player_line_level(pid, line, level) values(%d, %d, %d)", self.pid, line, level)
	info.level = level
	
	self:CalcGatherInfo(info)
	return 0
end

function Manufacture:IncreaseStorage(line, consume_type, consume_id, consume_value, count)
	if not checkLineOpen(self.pid, line) then
        log.debug(string.format('line %d of player %d not open', line, self.pid));
        return
    end

	local info = self:GetLineInfo(line)
	local consume_cfg = LoadManorPowerConsumeConfig(consume_id)
	local consume = {}
	local add_value1 = 0
	local add_value2 = 0
	local add_value3 = 0
	local add_value4 = 0
	local add_value5 = 0
	local add_value6 = 0
	local add_value_pool = 0
	if not consume_cfg then
		yqinfo("Player %d fail to increase line storage , dont has consume config for id:%d", self.pid, consume_id)
		return 
	end
	if consume_type ~= consume_cfg.type or consume_value ~= consume_cfg.value then
		yqinfo("Player %d fail to increase line storage , client consume config dont fit with server consume config", self.pid)
		return
	end
	table.insert(consume, {type = consume_cfg.type, id = consume_cfg.id, value = consume_cfg.value * count})
	add_value1 = consume_cfg.add_storage1 * count
	add_value2 = consume_cfg.add_storage2 * count
	add_value3 = consume_cfg.add_storage3 * count
	add_value4 = consume_cfg.add_storage4 * count
	add_value5 = consume_cfg.add_storage5 * count
	add_value6 = consume_cfg.add_storage6 * count
	add_value_pool = consume_cfg.add_storage_pool * count

	local line_cfg = LoadLineConfig(line)
	if not line_cfg then
		yqinfo("Player %d fail to increase storage for line:%d, line_cfg is nil", self.pid, line)
		return
	end

	if info.storage1 >= line_cfg.storage1_up and info.storage2 >= line_cfg.storage2_up and info.storage3 >= line_cfg.storage3_up and info.storage4 >= line_cfg.storage4_up and info.storage5 >= line_cfg.storage5_up and info.storage6 >= line_cfg.storage6_up and info.storage_pool >= line_cfg.storage_pool_up then
		yqinfo("storage already max")
		return
	end

	if not DOReward(self.pid, nil, consume, Command.REASON_MANOR_MANUFACTURE_INCREASE_STORAGE, false, loop.now() + 14 * 24 * 3600, nil) then
		yqinfo("Player %d fail to increase storage for line:%d, consume fail", self.pid, line)
		return
	end
		
	info.storage1 = math.min(info.storage1 + add_value1, line_cfg.storage1_up)
	info.storage2 = math.min(info.storage2 + add_value2, line_cfg.storage2_up)
	info.storage3 = math.min(info.storage3 + add_value3, line_cfg.storage3_up)
	info.storage4 = math.min(info.storage4 + add_value4, line_cfg.storage4_up)
	info.storage5 = math.min(info.storage5 + add_value5, line_cfg.storage5_up)
	info.storage6 = math.min(info.storage6 + add_value6, line_cfg.storage6_up)
	info.storage_pool = math.min(info.storage_pool + add_value_pool, line_cfg.storage_pool_up)

	if info.db_exists then
		database.update("update manor_manufacture_player_line set storage1 = %d, storage2 = %d, storage3 = %d, storage4 = %d, storage5 = %d, storage6 = %d, storage_pool = %d where pid = %d and line = %d",
					info.storage1, info.storage2, info.storage3, info.storage4, info.storage5, info.storage6, info.storage_pool, self.pid, info.idx);
	else
		database.update("insert into manor_manufacture_player_line (pid, line, speed, next_gather_time, next_gather_gid, current_order_begin_time, current_order_last_time, workman1_speed, workman1_produce_rate, workman2_speed, workman2_produce_rate, workman3_speed, workman3_produce_rate, workman4_speed, workman4_produce_rate, workman5_speed, workman5_produce_rate, current_order_produce_rate, storage1, storage2, storage3, storage4, storage5, storage6, storage_pool, order_limit) values(%d,%d,%d,from_unixtime_s(%d),%d, from_unixtime_s(%d), %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d)",
					self.pid, info.idx, info.speed, info.next_gather_time, info.next_gather_gid, info.current_order_begin_time, info.current_order_last_time, info.workman1_speed, info.workman1_produce_rate, info.workman2_speed, info.workman2_produce_rate, info.workman3_speed, info.workman3_produce_rate, info.workman4_speed, info.workman4_produce_rate, info.workman5_speed, info.workman5_produce_rate,info.current_order_produce_rate, info.storage1, info.storage2, info.storage3, info.storage4, info.storage5, info.storage6, info.storage_pool, info.order_limit);
		info.db_exists = true
	end
	self:CalcGatherInfo(info)
	return true
end

function Manufacture:IncreaseLineOrderLimit(line, consume_type, consume_id, consume_value, count)
	if not checkLineOpen(self.pid, line) then
        log.debug(string.format('line %d of player %d not open', line, self.pid));
        return
    end

	local info = self:GetLineInfo(line)
	local add_value = 0

	local line_cfg = LoadLineConfig(line)
	if not line_cfg then
		yqinfo("Player %d fail to increase line order limit for line:%d , line_cfg is nil ", self.pid, line)
		return
	end

	if line_cfg.order_limit_consume[1].type == 0 then
		yqinfo("Player %d fail to increase line order limit for line:%d , line dont support for increase ", self.pid, line)
		return 
	end

	if consume_type ~= line_cfg.order_limit_consume[1].type or consume_id ~= line_cfg.order_limit_consume[1].id or consume_value ~= line_cfg.order_limit_consume[1].value then
		yqinfo("Player %d fail to increase line storage , client consume config dont fit with server consume config", self.pid)
		return
	end

	add_value = line_cfg.limit_effect * count
	
	if info.order_limit >= line_cfg.max_order_limit then
		yqinfo("Player %d fail to increase line order limit for line:%d, already max", self.pid, line)
		return
	end

	if not DOReward(self.pid, nil, line_cfg.order_limit_consume, Command.REASON_MANOR_MANUFACTURE_INCREASE_ORDER_LIMIT, false, loop.now() + 14 * 24 * 3600, nil) then
		yqinfo("Player %d fail to increase line order limit for line:%d, consume fail", self.pid, line)
		return
	end
	
	info.order_limit = math.min(info.order_limit + add_value, line_cfg.max_order_limit)

	if info.db_exists then
		database.update("update manor_manufacture_player_line set order_limit = %d where pid = %d and line = %d",
					info.order_limit, self.pid, info.idx);
	else
		database.update("insert into manor_manufacture_player_line (pid, line, speed, next_gather_time, next_gather_gid, current_order_begin_time, current_order_last_time, workman1_speed, workman1_produce_rate, workman2_speed, workman2_produce_rate, workman3_speed, workman3_produce_rate, workman4_speed, workman4_produce_rate, workman5_speed, workman5_produce_rate, current_order_produce_rate, storage1, storage2, storage3, storage4, storage5, storage6, storage_pool, order_limit) values(%d,%d,%d,from_unixtime_s(%d),%d, from_unixtime_s(%d), %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d)",
					self.pid, info.idx, info.speed, info.next_gather_time, info.next_gather_gid, info.current_order_begin_time, info.current_order_last_time, info.workman1_speed, info.workman1_produce_rate, info.workman2_speed, info.workman2_produce_rate, info.workman3_speed, info.workman3_produce_rate, info.workman4_speed, info.workman4_produce_rate, info.workman5_speed, info.workman5_produce_rate,info.current_order_produce_rate, info.storage1, info.storage2, info.storage3, info.storage4, info.storage5, info.storage6, info.storage_pool, info.order_limit);
		info.db_exists = true
	end
	self:CalcGatherInfo(info)
	return true
end

function Manufacture:ChangeLineWorkmanSpeedAndProduceRate(info, power_may_change, self_logic, ...)
	local org_left_time = self:GetOriginLeftTime(info)

	local success = self_logic(...)

	if success then
		if info.next_gather_time > 0 then
			local new_workman1_speed, new_workman1_produce_rate = self:GetWorkmanSpeedAndProduceRate2(info.idx, info, 1)
			local new_workman2_speed, new_workman2_produce_rate = self:GetWorkmanSpeedAndProduceRate2(info.idx, info, 2)
			local new_workman3_speed, new_workman3_produce_rate = self:GetWorkmanSpeedAndProduceRate2(info.idx, info, 3)
			local new_workman4_speed, new_workman4_produce_rate = self:GetWorkmanSpeedAndProduceRate2(info.idx, info, 4)
			local new_workman5_speed, new_workman5_produce_rate = self:GetWorkmanSpeedAndProduceRate2(info.idx, info, 5)
			local speed_changed, produce_rate_changed = self:ChangeWorkmanSpeedAndProduceRate(info.idx, info, new_workman1_speed, new_workman1_produce_rate, new_workman2_speed, new_workman2_produce_rate, new_workman3_speed, new_workman3_produce_rate, new_workman4_speed, new_workman4_produce_rate, new_workman5_speed, new_workman5_produce_rate)
			if speed_changed or power_may_change then
				local new_next_gather_time = self:GetNextGatherTime(loop.now(), org_left_time, info, info.next_gather_gid)
				info.next_gather_time = new_next_gather_time;
				if (info.event_happen_time >= info.next_gather_time) then
					info.event_happen_time = 0
				end

				database.update("update manor_manufacture_player_line set next_gather_time = from_unixtime_s(%d), event_happen_time = from_unixtime_s(%d) where pid = %d and line = %d", info.next_gather_time,info.event_happen_time,self.pid, info.idx);
			end
			if produce_rate_changed then
				info.current_order_produce_rate = math.ceil((info.current_order_produce_rate * (info.current_order_last_time - org_left_time) + (new_workman1_produce_rate + new_workman2_produce_rate + new_workman3_produce_rate + new_workman4_produce_rate + new_workman5_produce_rate) * org_left_time) / info.current_order_last_time)
				database.update("update manor_manufacture_player_line set current_order_produce_rate = %d where pid = %d and line = %d", info.current_order_produce_rate, self.pid, info.idx);
			end
		else
			local new_workman1_speed, new_workman1_produce_rate = self:GetWorkmanSpeedAndProduceRate2(info.idx, info, 1)
			local new_workman2_speed, new_workman2_produce_rate = self:GetWorkmanSpeedAndProduceRate2(info.idx, info, 2)
			local new_workman3_speed, new_workman3_produce_rate = self:GetWorkmanSpeedAndProduceRate2(info.idx, info, 3)
			local new_workman4_speed, new_workman4_produce_rate = self:GetWorkmanSpeedAndProduceRate2(info.idx, info, 4)
			local new_workman5_speed, new_workman5_produce_rate = self:GetWorkmanSpeedAndProduceRate2(info.idx, info, 5)
			self:ChangeWorkmanSpeedAndProduceRate(info.idx, info, new_workman1_speed, new_workman1_produce_rate, new_workman2_speed, new_workman2_produce_rate, new_workman3_speed, new_workman3_produce_rate, new_workman4_speed, new_workman4_produce_rate, new_workman5_speed, new_workman5_produce_rate)
		end
	
		self:CalcGatherInfo(info)
		return success 
	end
	return success
end

local ManufactureList = {}

function GetManufacture(pid)
	if ManufactureList[pid] == nil then
		ManufactureList[pid] = Manufacture.New(pid);
		ManufactureList[pid]:Load();
	end
	return ManufactureList[pid];
end

function UnloadManufacture(pid)
	if ManufactureList[pid] then
		ManufactureList[pid] = nil
	end
end

local service = select(1, ...);

service:on(Command.C_MANOR_MANUFACTURE_QUERY_PRODUCT_REQUEST, function(conn, pid, request)
	local sn = request[1];
	local info = GetManufacture(pid);
	local respond = {sn,  Command.RET_SUCCESS, info:QueryProduct(pid)}

	log.debug(string.format('player %d query manufacture product list>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>', pid), #respond[3]); 
	conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_QUERY_PRODUCT_RESPOND, pid, respond);
end)

service:on(Command.C_MANOR_MANUFACTURE_QUERY_PRODUCT_LINE_REQUEST, function(conn, pid, request)
	local sn = request[1];
	local target = request[2] or pid
	local info = GetManufacture(target);
	local respond = {sn,  Command.RET_SUCCESS, info:QueryProductLine()}
	log.debug(string.format('player %d query manufacture product line of player %d', pid, target)); 
	conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_QUERY_PRODUCT_LINE_RESPOND, pid, respond);
end)

service:on(Command.C_MANOR_MANUFACTURE_GATHER_REQUEST, function(conn, pid, request)
	local sn = request[1];
	local idx = request[2];

	local info = GetManufacture(pid);
	local lineInfo, reward = info:Gather(idx);

	log.debug(string.format('player %d gather manufacture product line %d', pid, idx)); 

	local respond = {sn, lineInfo and Command.RET_SUCCESS or Command.RET_ERROR,  lineInfo, reward}

	conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_GATHER_RESPOND, pid, respond);
end);

service:on(Command.C_MANOR_MANUFACTURE_PRODUCT_REQUEST, function(conn, pid, request)
	local sn = request[1];
	local gid = request[2];
	local count = request[3] or 1;
	local client_consume = request[4];

	local info = GetManufacture(pid);
	local result = info:StartProduce(gid, count, client_consume);

	log.debug(string.format('player %d start manufacture product gid %d, count %d', pid, gid, count)); 

	local respond = {sn, result and Command.RET_SUCCESS or Command.RET_ERROR,  result}

	conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_PRODUCT_RESPOND, pid, respond);
end)

service:on(Command.C_MANOR_MANUFACTURE_SPEEDUP_REQUEST, function(conn, pid, request)
	local sn    = request[1];
	local idx   = request[2];
	local speed = request[3] or 100;
	local forever = false;

	local info = GetManufacture(pid);
	local result = info:FinishOrderImmediately(idx);--info:Speedup(idx, speed, forever);

	log.debug(string.format('player %d speed up manufacture product line %d, speed %d %s', pid, idx, speed, forever and "forever" or ""));

	local respond = {sn, result and Command.RET_SUCCESS or Command.RET_ERROR,  result}

	conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_SPEEDUP_RESPOND, pid, respond);
end)

local HELP_OTHER_COUNT_ITEM_ID = 900006
service:on(Command.C_MANOR_MANUFACTURE_HELP_OTHER_SPEEDUP_REQUEST, function(conn, pid, request)
	local sn    = request[1];
	local idx   = request[2];
	local target = request[3]

	if not target then
		log.debug("fail to help other speed up, target is nil")
		return conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_HELP_OTHER_SPEEDUP_RESPOND, pid, {sn, Command.RET_PARAM_ERROR});
	end

	local info = GetManufacture(target);
	local result = info:FinishOrderImmediately(idx, pid);--info:Speedup(idx, speed, forever);
	

	log.debug(string.format('player %d hlep other player %d speed up manufacture product line %d', pid, target, idx));

	local respond = {sn, result and Command.RET_SUCCESS or Command.RET_ERROR,  result}

	conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_HELP_OTHER_SPEEDUP_RESPOND, pid, respond);
end)

service:on(Command.C_MANOR_MANUFACTURE_EMPLOY_REQUEST, function(conn, pid, request)
	local sn = request[1];
	local line = request[2]
	local workman  = request[3];
	local pos = request[4]; 
	local cmd = Command.C_MANOR_MANUFACTURE_EMPLOY_RESPOND

	if not line or not workman or not pos then
		log.info(string.format("player %d fail to employ ,param 2nd or 3rd or 4th is nil", pid))	
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR});
	end

	log.info(string.format('player %d begin to employ for manufacture product line %d, workman:%d pos:%d', pid, line, workman, pos));

	local info = GetManufacture(pid);
	local success = info:Employ(line, workman, pos);

	if success then
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, info:QueryProductLine()});
	else
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
	end
end)

service:on(Command.C_MANOR_MANUFACTURE_LINE_LEVELUP_REQUEST, function(conn, pid, request)
	local sn = request[1]
	local line = request[2]
	local level = request[3]
	local cmd = Command.C_MANOR_MANUFACTURE_LINE_LEVELUP_RESPOND
	
	if not line then
		log.info(string.format("player %d fail to levelup manufacture ,param 2nd is nil", pid))
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR});
	end
	
	log.info(string.format("player %d begin to levelup manufacture for line %d", pid, line))
	local info = GetManufacture(pid);
	local result = info:LevelUp(line, level)

	conn:sendClientRespond(cmd, pid, {sn, result and Command.RET_SUCCESS or Command.RET_ERROR});
end)

function Manufacture:ReloadData(workman_id)
	local lineInfo = GetManufacture(self.pid)	
	local line, pos, info = lineInfo:GetWorkmanLineAndPos(workman_id)
	local workmanInfo = ManorWorkman.Get(self.pid)
	local qualifiedWorkmanInfo = GetManufactureQualifiedWorkmen(self.pid)

	if line > 0 and pos > 0 and info and info.next_gather_time > 0 then
		local org_left_time = self:GetOriginLeftTime(info)

		-- reload property and power
		local powerReload = workmanInfo:ReloadWorkmanInfo(workman_id, true)
		qualifiedWorkmanInfo:GetProperty(workman_id, nil, true)

		--change speed and produce rate
		local new_workman1_speed, new_workman1_produce_rate = self:GetWorkmanSpeedAndProduceRate2(line, info, 1)
		local new_workman2_speed, new_workman2_produce_rate = self:GetWorkmanSpeedAndProduceRate2(line, info, 2)
		local new_workman3_speed, new_workman3_produce_rate = self:GetWorkmanSpeedAndProduceRate2(line, info, 3)
		local new_workman4_speed, new_workman4_produce_rate = self:GetWorkmanSpeedAndProduceRate2(line, info, 4)
		local new_workman5_speed, new_workman5_produce_rate = self:GetWorkmanSpeedAndProduceRate2(line, info, 5)
		local speed_changed, produce_rate_changed = self:ChangeWorkmanSpeedAndProduceRate(line, info, new_workman1_speed, new_workman1_produce_rate, new_workman2_speed, new_workman2_produce_rate, new_workman3_speed, new_workman3_produce_rate, new_workman4_speed, new_workman4_produce_rate, new_workman5_speed, new_workman5_produce_rate)
		if powerReload or speed_changed then
			local new_next_gather_time = self:GetNextGatherTime(loop.now(), org_left_time, info, info.next_gather_gid)
			info.next_gather_time = new_next_gather_time;
			database.update("update manor_manufacture_player_line set next_gather_time = from_unixtime_s(%d) where pid = %d and line = %d", info.next_gather_time, self.pid, line);
		end
		if produce_rate_changed then
			info.current_order_produce_rate = math.ceil((info.current_order_produce_rate * (info.current_order_last_time - org_left_time) + (new_workman1_produce_rate + new_workman2_produce_rate + new_workman3_produce_rate + new_workman4_produce_rate + new_workman5_produce_rate) * org_left_time) / info.current_order_last_time)
			database.update("update manor_manufacture_player_line set current_order_produce_rate = %d where pid = %d and line = %d", info.current_order_produce_rate, self.pid, info.idx);
		end

	else
		powerReload = workmanInfo:ReloadWorkmanInfo(workman_id, true)
		qualifiedWorkmanInfo:GetProperty(workman_id, nil, true)
	end
	self:CalcGatherInfo(info)
end

service:on(Command.C_MANOR_MANUFACTURE_QUERY_WORKMAN_INFO_REQUEST, function(conn, pid, request)
	local sn = request[1]
	local workman = request[2]
	local reload = request[3]
	local target = request[4] or pid
	local cmd = Command.C_MANOR_MANUFACTURE_QUERY_WORKMAN_INFO_RESPOND

	print("get workman info >>>>>>>>>>>>>>>>>>>>", workman)
	if not workman then
		log.info(string.format("player %d fail to get workman info ,param 2nd is nil", pid))
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	log.info(string.format("player %d begin to get workman info of target %d", pid, target))
	local lineInfo = GetManufacture(target)
	local workmanInfo = ManorWorkman.Get(target)
	local qualifiedInfo = GetManufactureQualifiedWorkmen(target)	

	if not lineInfo or not workmanInfo or not qualifiedInfo then
		log.info(string.format("player %d fail to get workman info of target %d, lineInfo or workmanInfo or qualifiedInfo is nil", pid, target))
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
	end

	-- calc line
	for i = 1, PRODUCT_LINE_LIMIT do
		if ValidLine(i) then
			lineInfo:GetLineInfo(i);
		end
	end


	if reload then
		lineInfo:ReloadData(workman)
	end

	local power = workmanInfo:GetWorkmanPower(workman)
	local power_upper_limit = workmanInfo:GetWorkmanPowerUpperLimit(workman)
	local power_next_change_time = workmanInfo:GetWorkmanPowerNextChangeTime(workman)
	local is_busy = workmanInfo:GetWorkmanBusyStatus(workman)
	local property_tb = qualifiedInfo:GetProperty(workman)
	local line,_,_  = lineInfo:GetWorkmanLineAndPos(workman)
	local amf_property_tb = {}
	for property_id, property_value in pairs(property_tb) do
		table.insert(amf_property_tb, {property_id, property_value})
	end

	local ret = ManorCopy.get_current_fight_count(target)
	local manor_hero = GetPlayerHeroInPub(target)
	local status , leave_time, back_time = manor_hero:GetHeroStatus(workman)
	local power_change_speed = 0
	if is_busy == 1 then
		power_change_speed = -COST_POWER_PER_FIVE_MIN
	elseif is_busy == 0 then
		power_change_speed = RECOVER_POWER_PER_FIVE_MIN
	elseif is_busy == 2 then
		power_change_speed = RECOVER_POWER_INLINE_PER_FIVE_MIN
	end
	
	if power and power_upper_limit and power_next_change_time and is_busy then
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, power, power_upper_limit, power_change_speed, power_next_change_time, amf_property_tb, line, ret, status, leave_time, back_time});
	else
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
	end	
	
end)

service:on(Command.C_MANOR_MANUFACTURE_INCREASE_POWER_REQUEST, function(conn, pid, request)
	local sn = request[1]
	local workman = request[2]
	local consume_type = request[3]
	local consume_id = request[4]
	local consume_value = request[5]
	local count = request[6] or 1
	local cmd = Command.C_MANOR_MANUFACTURE_INCREASE_POWER_RESPOND

	if not workman or not consume_type or not consume_id or not consume_value or not count then
		log.info(string.format("player %d fail to increase workman power, param 2nd or 3rd... is nil", pid))
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	local lineInfo = GetManufacture(pid)
	local workmanInfo = ManorWorkman.Get(pid)
	
	local function logic()
        return workmanInfo:IncreaseWorkmanPower(workman, consume_type, consume_id, consume_value, count)
	end

	local line, pos, linfo = lineInfo:GetWorkmanLineAndPos(workman)
	local success = false
	if line > 0 and pos > 0 and linfo then
		success = lineInfo:ChangeLineWorkmanSpeedAndProduceRate(linfo, true, logic)
	else
		success = workmanInfo:IncreaseWorkmanPower(workman, consume_type, consume_id, consume_value, count)
	end
	conn:sendClientRespond(cmd, pid, {sn, success and Command.RET_SUCCESS or Command.RET_ERROR});
end)

service:on(Command.C_MANOR_MANUFACTURE_INCREASE_LINE_STORAGE_REQUEST, function(conn, pid, request)
	local sn = request[1]
	local line = request[2]
	local consume_type = request[3]
	local consume_id = request[4]
	local consume_value = request[5]
	local count = request[6] or 1
	local cmd = Command.C_MANOR_MANUFACTURE_INCREASE_LINE_STORAGE_RESPOND

	if not line or not consume_type or not consume_id or not consume_value or not count then
		log.info(string.format("player %d fail to increase line storage, param 2nd or 3rd... is nil", pid))
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
		return
	end

	local lineInfo = GetManufacture(pid)
	local success = lineInfo:IncreaseStorage(line, consume_type, consume_id, consume_value, count)	
	conn:sendClientRespond(cmd, pid, {sn, success and Command.RET_SUCCESS or Command.RET_ERROR});
end)

service:on(Command.C_MANOR_MANUFACTURE_INCREASE_LINE_ORDER_LIMIT_REQUEST, function(conn, pid, request)
	local sn = request[1]
	local line = request[2]
	local consume_type = request[3]
	local consume_id = request[4]
	local consume_value = request[5]
	local count = request[6] or 1
	local cmd = Command.C_MANOR_MANUFACTURE_INCREASE_LINE_ORDER_LIMIT_RESPOND

	if not line or not consume_type or not consume_id or not consume_value or not count then
		log.info(string.format("player %d fail to increase line order limit, param 2nd or 3rd... is nil", pid))
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
		return
	end

	local lineInfo = GetManufacture(pid)
	local success = lineInfo:IncreaseLineOrderLimit(line, consume_type, consume_id, consume_value, count)	
	conn:sendClientRespond(cmd, pid, {sn, success and Command.RET_SUCCESS or Command.RET_ERROR});
end)

service:on(Command.C_MANOR_MANUFACTURE_WORKMAN_TITLE_CHANGE_REQUEST, function(conn, pid, request)
	local sn = request[1]
	local workman = request[2]
	local cmd = Command.C_MANOR_MANUFACTURE_WORKMAN_TITLE_CHANGE_RESPOND

	if not workman then
		log.info("param error")
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
		return
	end

	log.debug(string.format("player %d begin to change the title of workman %d", pid, workman))

	local lineInfo = GetManufacture(pid)
	lineInfo:ReloadData(workman)

	conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS});
end)

service:on(Command.C_MANOR_MANUFACTURE_UNLOCK_LINE_REQUEST, function(conn, pid, request)
	local sn = request[1];
	local line = request[2]
	local cmd = Command.C_MANOR_MANUFACTURE_UNLOCK_LINE_RESPOND

	if not line then
		log.info(string.format("player %d fail to unlock line ,param 2nd is nil", pid))	
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR});
	end

	log.info(string.format('player %d begin to unlock line %d', pid, line));

	local success = UnlockPlayerLine(pid, line) 
	if success then
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS});
	else
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR});
	end
end)

service:on(Command.C_MANOR_MANUFACTURE_QUERY_LINE_OPEN_STATUS_REQUEST, function(conn, pid, request)
	local sn = request[1];
	local line = request[2]
	local target = request[3] or pid
	local cmd = Command.C_MANOR_MANUFACTURE_QUERY_LINE_OPEN_STATUS_RESPOND

	if not line then
		log.info(string.format("player %d fail to query target %d line open status ,param 2nd is nil", pid, target))	
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR});
	end

	log.info(string.format('player %d begin to query target %d line %d open status', pid, target, line));

	local open = checkLineOpen(target, line) 
	conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, open and 1 or 0});
end)

service:on(Command.C_MANOR_MANUFACTURE_COPY_REQUEST, function(conn, pid, request)
	local respond = ManorCopy.get_copy_respond(pid, request)	
	conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_COPY_RESPOND, pid, respond)
end)

-- 庄园副本确认
service:on(Command.C_MANOR_MANUFACTURE_COPY_CHECK_REQUEST, function(conn, pid, request)
	local respond = ManorCopy.get_copy_check_respond(pid, request)
	conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_COPY_CHECK_RESPOND, pid, respond)
end)

service:on(Command.C_MANOR_TASK_REQUEST, function(conn, pid, request)
	local respond = ManorTask2.get_task_respond(pid, request)
	conn:sendClientRespond(Command.C_MANOR_TASK_RESPOND, pid, respond)
end)

service:on(Command.C_MANOR_GET_TASK_REQUEST, function(conn, pid, request)
	local respond = ManorTask2.get_task_todo(pid, request)
	conn:sendClientRespond(Command.C_MANOR_GET_TASK_RESPOND, pid, respond)
end)

service:on(Command.C_MANOR_REFRESH_TASK_REQUEST, function(conn, pid, request)
	local respond = ManorTask2.get_task_refresh(pid, request)
	conn:sendClientRespond(Command.C_MANOR_REFRESH_TASK_RESPOND, pid, respond)
end)

service:on(Command.C_MANOR_TASK_DONE_REQUEST, function(conn, pid, request)
	local respond = ManorTask2.get_task_done(pid, request)
	conn:sendClientRespond(Command.C_MANOR_TASK_DONE_RESPOND, pid, respond)
end)

service:on(Command.C_MANOR_TERM_TASK_REQUEST, function(conn, pid, request)
	local respond = ManorTask2.get_task_term(pid, request)
	conn:sendClientRespond(Command.C_MANOR_TERM_TASK_RESPOND, pid, respond)
end)

service:on(Command.C_MANOR_EARLY_DONE_REQUEST, function(conn, pid, request)
	local respond = ManorTask2.get_task_early_done(pid, request)
	conn:sendClientRespond(Command.C_MANOR_EARLY_DONE_RESPOND, pid, respond)
end)

service:on(Command.C_MANOR_STAR_REWARD_INFO_REQUEST, function(conn, pid, request)
        local respond = ManorTask2.get_task_star_reward_info(pid,request)
        conn:sendClientRespond(Command.C_MANOR_STAR_REWARD_INFO_RESPOND, pid, respond)
end)

service:on(Command.C_MANOR_STAR_REWARD_REQUEST, function(conn, pid, request)
        local respond = ManorTask2.get_task_star_reward(pid,request)
        conn:sendClientRespond(Command.C_MANOR_STAR_REWARD_RESPOND, pid, respond)
end)

service:on(Command.C_MANOR_REFRESH_ALLTASK_REQUEST, function(conn, pid, request)
        local respond = ManorTask2.get_task_refresh_all_tasks(pid,request)
        conn:sendClientRespond(Command.C_MANOR_REFRESH_ALLTASK_RESPOND, pid, respond)
end)

service:on(Command.C_MANOR_MANUFACTURE_SPEEDUP_BY_WORKMAN_REQUEST, function(conn, pid, request)
	local sn    = request[1];
	local idx   = request[2];
	local workman = request[3]

	if not idx or not workman then
		log.debug("fail to speed up by workman, param error")
		return conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_SPEEDUP_BY_WORKMAN_RESPOND, pid, {sn, Command.RET_PARAM_ERROR});
	end

	local info = GetManufacture(pid);
	local result = info:SpeedUpByWorkman(idx, workman);--info:Speedup(idx, speed, forever);
	
	log.debug(string.format('player %d speed up line %d by workman %d', pid, idx, workman));

	local respond = {sn, result and Command.RET_SUCCESS or Command.RET_ERROR,  result}

	conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_SPEEDUP_BY_WORKMAN_RESPOND, pid, respond);
end)

service:on(Command.C_MANOR_MANUFACTURE_CANCEL_ORDER_REQUEST, function(conn, pid, request)
	local sn = request[1];
	local idx = request[2];
	local gid = request[3]
	local count = request[4]

	if not idx or not gid or not count then
		log.debug("fail to cancel order, param error")
		return conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_CANCEL_ORDER_RESPOND, pid, {sn, Command.RET_PARAM_ERROR});
	end

	local info = GetManufacture(pid);
	local lineInfo = info:CancelOrder(idx, gid, count);

	log.debug(string.format('player %d cancel order %d count %d for line %d', pid, gid, count, idx)); 

	local respond = {sn, lineInfo and Command.RET_SUCCESS or Command.RET_ERROR,  lineInfo}

	conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_CANCEL_ORDER_RESPOND, pid, respond);
end);

local fight_record = {} 
service:on(Command.C_MANOR_RESET_LINE_PRODUCE_RATE_FIGHT_PREPARE_REQUEST, function(conn, pid, request)
	local sn = request[1]
	local idx = request[2]
	local target = request[3] or pid

	log.debug(string.format("Player %d begin to query reset_line_produce_rate fightdata of target %d", pid, target))
	if not idx then
		log.debug("fail to query reset_line_produce_rate fightdata , param error")
		return conn:sendClientRespond(Command.C_MANOR_RESET_LINE_PRODUCE_RATE_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_PARAM_ERROR});
	end

	local info = GetManufacture(target)
	local lineInfo = info:GetLineInfo(idx)

	if loop.now() >= lineInfo.line_produce_rate_begin_time and loop.now() <= lineInfo.line_produce_rate_end_time and lineInfo.line_produce_rate_depend_fight > 0 then
		local fightid, fight_data = SocialManager.PVEFightPrepare(pid, lineInfo.line_produce_rate_depend_fight, 1, nil, nil)
		if not fight_data then
			return conn:sendClientRespond(Command.C_MANOR_RESET_LINE_PRODUCE_RATE_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_ERROR})
		end

		fight_record[pid] = {fight_id = fightid, line = idx, target = target, opt_id = pid}	
		return conn:sendClientRespond(Command.C_MANOR_RESET_LINE_PRODUCE_RATE_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_SUCCESS, fightid, fight_data})
	end 

	return conn:sendClientRespond(Command.C_MANOR_RESET_LINE_PRODUCE_RATE_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_ERROR});
end);

service:on(Command.C_MANOR_RESET_LINE_PRODUCE_RATE_FIGHT_CHECK_REQUEST, function(conn, pid, request)
	local sn = request[1]
	local winner = request[2]
	--local starValue = request[3]
	local code = request[4] 

	print("fight check >>>>>>>>>>>>>>>>>>>>>>>>>", winner)
	if not fight_record[pid] then
		log.debug("not has fight record")
		return conn:sendClientRespond(Command.C_MANOR_RESET_LINE_PRODUCE_RATE_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	local fightid = fight_record[pid].fight_id 	
	local line = fight_record[pid].line
	local target = fight_record[pid].target
	local opt_id = fight_record[pid].opt_id
	fight_record[pid] = nil
	if winner ~= 1 then
		return conn:sendClientRespond(Command.C_MANOR_RESET_LINE_PRODUCE_RATE_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_SUCCESS})
	end

	if not fightid then
		log.debug("not has fightid")
		return conn:sendClientRespond(Command.C_MANOR_RESET_LINE_PRODUCE_RATE_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	log.debug(string.format("Player %d begin to check reset_line_produce_rate fight of target %d", pid, target))
	if not code then
		log.debug("fail to check fight, param error")
		return conn:sendClientRespond(Command.C_MANOR_RESET_LINE_PRODUCE_RATE_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_PARAM_ERROR});
	end

	local winner , rewards = SocialManager.PVEFightCheck(pid, fightid, nil, code)
	if not winner then
		return conn:sendClientRespond(Command.C_MANOR_RESET_LINE_PRODUCE_RATE_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_ERROR})
	end

	local ar = {}
	for k, v in ipairs(rewards) do
		table.insert(ar, {v.type, v.id, v.value, v.uuid})
	end
	
	local info = GetManufacture(target)
	local success, lineInfo = info:ResetLineProduceRate(line, opt_id)			
	return conn:sendClientRespond(Command.C_MANOR_RESET_LINE_PRODUCE_RATE_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_SUCCESS, winner, ar, lineInfo})
end)

local fight_record2 = {} 
service:on(Command.C_MANOR_CLEAR_THIEF_FIGHT_PREPARE_REQUEST, function(conn, pid, request)
	local sn = request[1]
	local target = request[2] 
	local idx = request[3]
	local thief = request[4]

	log.debug(string.format("Player %d begin to prepare clear thief fightdata of target %d", pid, target))
	if not target or not idx or not thief then
		log.debug("fail to query clear thief fightdata , param error")
		return conn:sendClientRespond(Command.C_MANOR_CLEAR_THIEF_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_PARAM_ERROR});
	end

	local info = GetManufacture(target)
	local lineInfo = info:GetLineInfo(idx)

	if not lineInfo.thieves[thief] or loop.now() < lineInfo.thieves[thief].begin_time or loop.now() > lineInfo.thieves[thief].end_time then
		log.debug(string.format("not has thief %d ", thief))
		return conn:sendClientRespond(Command.C_MANOR_CLEAR_THIEF_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	local fightid, fightdata = SocialManager.PVEFightPrepare(pid, lineInfo.thieves[thief].depend_fight_id, 1, nil, nil)
	if not fightdata then
		log.debug("not has fight data")
		return conn:sendClientRespond(Command.C_MANOR_CLEAR_THIEF_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_ERROR})
	end

	fight_record2[pid] = {fight_id = lineInfo.thieves[thief].depend_fight_id, line = idx, target = target, opt_id = pid, thief = thief}	
	return conn:sendClientRespond(Command.C_MANOR_CLEAR_THIEF_FIGHT_PREPARE_RESPOND, pid, {sn, Command.RET_SUCCESS, fightid, fightdata})
end);

service:on(Command.C_MANOR_CLEAR_THIEF_FIGHT_CHECK_REQUEST, function(conn, pid, request)
	local sn = request[1]
	local winner = request[2]
	local code = request[4] 

	if not fight_record2[pid] then
		log.debug("not has fight data")
		return conn:sendClientRespond(Command.C_MANOR_CLEAR_THIEF_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	local fightid = fight_record2[pid].fight_id 	
	local line = fight_record2[pid].line
	local opt_id = fight_record2[pid].opt_id
	local thief = fight_record2[pid].thief
	local target = fight_record2[pid].target
	
	fight_record2[pid] = nil
	if winner ~= 1 then
		return conn:sendClientRespond(Command.C_MANOR_CLEAR_THIEF_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_SUCCESS});
	end

	if not fightid then
		log.debug("not has fightid")
		return conn:sendClientRespond(Command.C_MANOR_CLEAR_THIEF_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	log.debug(string.format("Player %d begin to check clear thief fight of target %d", pid, target))
	if not code then
		log.debug("fail to check fight, param error")
		return conn:sendClientRespond(Command.C_MANOR_CLEAR_THIEF_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_PARAM_ERROR});
	end

	local winner , rewards = SocialManager.PVEFightCheck(pid, fightid, nil, code)
	if not winner then
		return conn:sendClientRespond(Command.C_MANOR_CLEAR_THIEF_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_ERROR})
	end

	local ar = {}
	for k, v in ipairs(rewards) do
		table.insert(ar, {v.type, v.id, v.value, v.uuid})
	end
	
	local info = GetManufacture(target)
	local success, lineInfo = info:ClearThief(line, opt_id, thief)			

	return conn:sendClientRespond(Command.C_MANOR_CLEAR_THIEF_FIGHT_CHECK_RESPOND, pid, {sn, Command.RET_SUCCESS, winner, ar, lineInfo})
end)

service:on(Command.C_MANOR_STEAL_REQUEST, function(conn, pid, request)
	local sn = request[1]
	local target = request[2]
	local line = request[3]

	if not target or not line then
		log.debug("fail to steal , param error")
		return conn:sendClientRespond(Command.C_MANOR_STEAL_RESPOND, pid, {sn, Command.RET_ERROR});
	end

	local info = GetManufacture(target)
	local success, lineInfo = info:Steal(line, pid)		

	if not success then
		return conn:sendClientRespond(Command.C_MANOR_STEAL_RESPOND, pid, {sn, Command.RET_ERROR});
	else
		return conn:sendClientRespond(Command.C_MANOR_STEAL_RESPOND, pid, {sn, Command.RET_SUCCESS, lineInfo});
	end	
end)
