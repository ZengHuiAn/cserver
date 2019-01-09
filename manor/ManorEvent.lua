local database = require "database"
local Command = require "Command"
local log = require "log"
local ManorLog = require "ManorLog"

local EVENT_TYPE_POPULAR = 1
local EVENT_TYPE_LUCKY = 2 
local EVENT_TYPE_HERO_LEAVE_TAVERN = 3 

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
	return true;
end


local playerOrderPrice = {}
local ManorOrderPrice = {}

function ManorOrderPrice.Get(pid)
	if not playerOrderPrice[pid] then
		playerOrderPrice[pid] = ManorOrderPrice.New(pid)
	end	
	return playerOrderPrice[pid]
end

function ManorOrderPrice.New(pid)
	local t = {
		pid = pid,
		orders = {},
	}

	local success, result = database.query("select gid, discount, unix_timestamp(begin_time) as begin_time, unix_timestamp(end_time) as end_time from manor_player_order_price where pid = %d", pid)	
	if success then
		for _, row in ipairs(result) do
			t.orders[row.gid] = t.orders[row.gid] or {}
			t.orders[row.gid].discount = row.discount
			t.orders[row.gid].begin_time = row.begin_time
			t.orders[row.gid].end_time = row.end_time
			t.orders[row.gid].db_exists = true
		end
	end
	
	return setmetatable(t, {__index = ManorOrderPrice})
end

function ManorOrderPrice:GetDiscount(gid, time)
	time = time or loop.now()
	if not self.orders[gid] then
		return 100, 0, 0
	end

	local begin_time = self.orders[gid].begin_time
	local end_time = self.orders[gid].end_time
	
	if time >= begin_time and time <= end_time then
		return self.orders[gid].discount, begin_time, end_time
	end

	return 100, 0, 0
end

function ManorOrderPrice:GetTime(gid)
	if not self.orders[gid] then
		return 0, 0
	end	

	return self.orders[gid].begin_time, self.orders[gid].end_time
end

function ManorOrderPrice:UpdateOrderPrice(gid, discount, begin_time, end_time)
	if not self.orders[gid] then
		self.orders[gid] = {}
		self.orders[gid].db_exists = false
	end

	self.orders[gid].discount = discount
	self.orders[gid].begin_time = begin_time
	self.orders[gid].end_time = end_time

	if self.orders[gid].db_exists then
		database.update("update manor_player_order_price set discount = %d, begin_time = from_unixtime_s(%d), end_time = from_unixtime_s(%d) where gid = %d and pid = %d", discount, begin_time, end_time, gid, self.pid)
	else
		database.update("insert into manor_player_order_price (pid, gid, discount, begin_time, end_time) values(%d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d))", self.pid, gid, discount, begin_time, end_time)
		self.orders[gid].db_exists = true
	end
end

local RISK_EVENT = 1
local TRAVEL_EVENT = 2 
local THINK_EVENT = 3
local LAZY_EVENT = 4 
local HARDWORK_EVENT = 5 
local LUCKY_EVENT = 6 
local POPULAR_EVENT = 7 

local ManorEvent = {}
local playerEvent = {}

local mineConfig = nil 
function LoadMineEventConfig(line, type)
	if mineConfig == nil then
		mineConfig = {}
		local success, result = database.query("select * from config_mine_event");
		if success then
			for _, row in ipairs(result) do
				mineConfig[row.event_type] = mineConfig[row.event_type] or {}
				mineConfig[row.event_type][row.line] = mineConfig[row.event_type][row.line] or {}
				mineConfig[row.event_type][row.line].condition_num1 = mineConfig[row.event_type][row.line].condition_num1 or row.condition_num1
				mineConfig[row.event_type][row.line].condition_num2 = mineConfig[row.event_type][row.line].condition_num2 or row.condition_num2
				mineConfig[row.event_type][row.line].condition_num3 = mineConfig[row.event_type][row.line].condition_num3 or row.condition_num3
				mineConfig[row.event_type][row.line].event_max = mineConfig[row.event_type][row.line].event_max or row.event_max
				mineConfig[row.event_type][row.line].event = mineConfig[row.event_type][row.line].event or {}
				local tb = {
					gid = row.gid,
					event_rate = row.event_rate,
					reward_type1 = row.reward_type1,
					reward_id1 = row.reward_id1,
					reward_min1 = row.reward_min1,
					reward_max1 = row.reward_max1,
					weight1 = row.weight1,
					reward_type2 = row.reward_type2,
					reward_id2 = row.reward_id2,
					reward_min2 = row.reward_min2,
					reward_max2 = row.reward_max2,
					weight2 = row.weight2,
				}
				table.insert(mineConfig[row.event_type][row.line].event, tb)
			end
		end
	end

	return mineConfig[type] and mineConfig[type][line] or nil
end

local popularConfig = nil
local popularConfig2 = nil
function LoadPopularConfig(gid, line, type)
	if popularConfig == nil then
		popularConfig = {}
		popularConfig2 = {}
		local success, result = database.query("select gid, line, event_type, event_rate, rate, increase_percent, last_time, add_percent, cd_time, unix_timestamp(add_begin_time) as add_begin_time, unix_timestamp(add_end_time) as add_end_time from config_shop_event");
		if success then
			for _, row in ipairs(result) do
				popularConfig[row.gid] = popularConfig[row.gid] or {}	
				popularConfig[row.gid].event = popularConfig[row.gid].event or {}
				popularConfig[row.gid].rate = row.rate
				popularConfig[row.gid].cd_time = row.cd_time
				local tb = {
					gid = row.gid,
					event_rate = row.event_rate,
					discount = row.increase_percent,
					last_time = row.last_time,
					limit_time_discount = row.add_percent,
					begin_time = row.add_begin_time,
					end_time = row.add_end_time,	
				}
				table.insert(popularConfig[row.gid].event, tb)

				popularConfig2[row.event_type] = popularConfig2[row.event_type] or {}
				popularConfig2[row.event_type][row.line] = popularConfig2[row.event_type][row.line] or {}
				popularConfig2[row.event_type][row.line][row.gid] = popularConfig2[row.event_type][row.line][row.gid] or {}
				popularConfig2[row.event_type][row.line][row.gid].event = popularConfig2[row.event_type][row.line][row.gid].event or {}
				popularConfig2[row.event_type][row.line][row.gid].rate = row.rate
				popularConfig2[row.event_type][row.line][row.gid].cd_time = row.cd_time
				local tb = {
					gid = row.gid,
					event_rate = row.event_rate,
					discount = row.increase_percent,
					last_time = row.last_time,
					limit_time_discount = row.add_percent,
					begin_time = row.add_begin_time,
					end_time = row.add_end_time,	
				}
				table.insert(popularConfig2[row.event_type][row.line][row.gid].event, tb)
			end
		end
	end

	if gid then
		return popularConfig[gid]
	end

	if line and type then 	
		return popularConfig2[type] and popularConfig2[type][line] or nil
	end
end

local heroRiskConfig = nil
function LoadHeroRiskConfig(hero_id)
	if heroRiskConfig == nil then
		heroRiskConfig = {}
		local success, result = database.query("select gid, role_id, event_pool1, event_rate1, event_pool2, event_rate2 from config_pub_event")
		if success then
			for _, row in ipairs(result) do
				heroRiskConfig[row.role_id] = heroRiskConfig[row.role_id] or {}
				heroRiskConfig[row.role_id].event_pool1 = row.event_pool1
				heroRiskConfig[row.role_id].event_rate1 = row.event_rate1
				heroRiskConfig[row.role_id].event_pool2 = row.event_pool2
				heroRiskConfig[row.role_id].event_rate2 = row.event_rate2
			end
		end
	end
	if hero_id then
		return heroRiskConfig[hero_id]
	else
		return heroRiskConfig
	end
end

local riskPoolConfig = nil
local riskPoolCfgByGID = nil
function LoadRiskPoolConfig(pool_id, gid)
	if riskPoolConfig == nil or riskPoolCfgByGID == nil then
		riskPoolConfig = {}
		riskPoolCfgByGID = {}
		local success, result = database.query("select * from config_pub_event_pool")
		if success then
			for _, row in ipairs(result) do
				riskPoolConfig[row.event_pool1] = riskPoolConfig[row.event_pool1] or {}
				riskPoolConfig[row.event_pool1].event = riskPoolConfig[row.event_pool1].event or {}
				local t = {
					gid = row.gid,
					event_time = row.event_time,
					reward_type1 = row.effect_type1,
					reward_id1 = row.effect_id1,
					reward_value_min1 = row.effect_num_min1,
					reward_value_max1 = row.effect_num_max1,
					reward_type2 = row.effect_type2,
					reward_id2 = row.effect_id2,
					reward_value_min2 = row.effect_num_min2,
					reward_value_max2 = row.effect_num_max2,
					reward_type3 = row.effect_type3,
					reward_id3 = row.effect_id3,
					reward_value_min3 = row.effect_num_min3,
					reward_value_max3 = row.effect_num_max3,
				}	
				table.insert(riskPoolConfig[row.event_pool1].event, t)

				riskPoolCfgByGID[row.gid] = riskPoolCfgByGID[row.gid] or {}
				riskPoolCfgByGID[row.gid].event_pool = row.event_pool
				riskPoolCfgByGID[row.gid].event_time = row.event_time
				riskPoolCfgByGID[row.gid].reward_type1 = row.effect_type1
				riskPoolCfgByGID[row.gid].reward_id1 = row.effect_id1
				riskPoolCfgByGID[row.gid].reward_value_min1 = row.effect_num_min1
				riskPoolCfgByGID[row.gid].reward_value_max1 = row.effect_num_max1
				riskPoolCfgByGID[row.gid].reward_type2 = row.effect_type2
				riskPoolCfgByGID[row.gid].reward_id2 = row.effect_id2
				riskPoolCfgByGID[row.gid].reward_value_min2 = row.effect_num_min2
				riskPoolCfgByGID[row.gid].reward_value_max2 = row.effect_num_max2
				riskPoolCfgByGID[row.gid].reward_type3 = row.effect_type3
				riskPoolCfgByGID[row.gid].reward_id3 = row.effect_id3
				riskPoolCfgByGID[row.gid].reward_value_min3 = row.effect_num_min3
				riskPoolCfgByGID[row.gid].reward_value_max3 = row.effect_num_max3
			end
		end
	end
	if pool_id then
		return riskPoolConfig[pool_id]
	end
	if gid then
		return riskPoolCfgByGID[gid]
	end
end

function ManorEvent.GetOrderDiscount(pid, gid, time)
	return ManorOrderPrice.Get(pid):GetDiscount(gid, time)
end

function ManorEvent.Get(pid)
	if not playerEvent[pid] then
		playerEvent[pid] = ManorEvent.New(pid)
	end
	return playerEvent[pid]
end

function ManorEvent.New(pid)
	local t = {
		pid = pid
	}
	return setmetatable(t, {__index = ManorEvent})
end

function ManorEvent:Notify(cmd, msg)
	NetService.NotifyClients(cmd, msg, {self.pid});
end

--[[function ManorEvent:TriggerEvent(event_type, data)
	if event_type == RISK_EVENT then
		return self:TriggerRiskEvent(data)
	elseif event_type == TRAVEL_EVENT then
		return self:TriggerTravelEvent(data)
	elseif event_type == THINK_EVENT then
		return self:TriggerThinkEvent(data)
	elseif event_type == LAZY_EVENT then
		return self:TriggerLazyEvent(data)
	elseif event_type == HARDWORK_EVENT then
		return self:TriggerHardworkEvent(data)
	elseif event_type == LUCKY_EVENT then
		return self:TriggerLuckyEvent(data)
	elseif event_type == POPULAR_EVENT then
		return self:TriggerPopularEvent(data)
	end
end--]]

-- lucky event
function ManorEvent:TriggerLuckyEvent(data)
	local line = data[1]
	local gather_count1 = data[2]
	local gather_count2 = data[3]
	local gather_count3 = data[4]
	local pid = data[5]
	
	local cfg = LoadMineEventConfig(line, 1) 

	if not cfg then
		log.debug(string.format("fail to trigger lucky event, cfg for line %d is nil", line))
		return false
	end

	if not (gather_count1 > cfg.condition_num1 or gather_count2 > cfg.condition_num2 or gather_count3 > cfg.condition_num3) then
		log.debug(string.format("fail to trigger lucky event, check condition fail"))
		return false
	end

	local count = 0 
	local count1 = 0
	local count2 = 0
	local count3 = 0
	
	if gather_count1 > cfg.condition_num1 then
		count1 = math.floor(gather_count1 / cfg.condition_num1)
		if count1 > count then
			count = count1
		end
	end
	if gather_count2 > cfg.condition_num2 then
		count2 = math.floor(gather_count2 / cfg.condition_num2)
		if count2 > count then
			count = count2
		end
	end
	if gather_count3 > cfg.condition_num3 then
		count3 = math.floor(gather_count3 / cfg.condition_num3)
		if count3 > count then
			count = count3
		end
	end

	local lucky_reward = {}
	local event_list = {}
	local event_count = 0 

	for i = 1, count, 1 do
		--select event
		local rand_num = math.random(1, 100)	
		local index = 0
		for k, v in ipairs(cfg.event) do
			if rand_num <= v.event_rate then
				index = k		
				break
			else
				rand_num = rand_num - v.event_rate
			end	
		end

		--select reward
		if index ~= 0 then
			local event = cfg.event[index]
			local rand_num2 = math.random(1, event.weight1 + event.weight2)
			local reward = {}

			if rand_num2 <= event.weight1 then
				reward.type = event.reward_type1
				reward.id = event.reward_id1
				reward.value = math.random(event.reward_min1, event.reward_max1)
			else
				reward.type = event.reward_type2
				reward.id = event.reward_id2
				reward.value = math.random(event.reward_min2, event.reward_max2)
			end

			table.insert(lucky_reward, reward)
			table.insert(event_list, {event.gid, reward.type, reward.id, reward.value, loop.now()})

			event_count = event_count + 1
		end

		if event_count + 1 > cfg.event_max then
			break
		end
	end

	if #lucky_reward > 0 then
		--隐藏道具
		table.insert(lucky_reward, {type = 41, id = 100000, value = 1})
		DOReward(pid, lucky_reward, nil, Command.REASON_MANOR_MANUFACTURE_GATHER, false, loop.now() + 14 * 24 * 3600, nil)
		--self:Notify(Command.NOTIFY_MANOR_LUCKY_EVENT, event_list)
	
		-- add log
		local manor_log = ManorLog.Get(self.pid)
		manor_log:AddLog(EVENT_TYPE_LUCKY, event_list)
	end

	return true, lucky_reward, event_list
end

function ManorEvent:TriggerLuckyEvent2(pid, line, time)
	local cfg = LoadMineEventConfig(line, 2) 
	time = time or loop.now()

	if not cfg then
		log.debug(string.format("fail to trigger lucky event, cfg for line %d is nil", line))
		return false
	end

	local lucky_reward = {}
	local event_list = {}
	local event_count = 0 

	for i = 1, 1, 1 do
		--select event
		local rand_num = math.random(1, 100)	
		local index = 0
		for k, v in ipairs(cfg.event) do
			if rand_num <= v.event_rate then
				index = k		
				break
			else
				rand_num = rand_num - v.event_rate
			end	
		end

		--select reward
		if index ~= 0 then
			local event = cfg.event[index]
			local rand_num2 = math.random(1, event.weight1 + event.weight2)
			local reward = {}

			if rand_num2 <= event.weight1 then
				reward.type = event.reward_type1
				reward.id = event.reward_id1
				reward.value = math.random(event.reward_min1, event.reward_max1)
			else
				reward.type = event.reward_type2
				reward.id = event.reward_id2
				reward.value = math.random(event.reward_min2, event.reward_max2)
			end

			table.insert(lucky_reward, reward)
			table.insert(event_list, {event.gid, reward.type, reward.id, reward.value, time})

			event_count = event_count + 1
		end

		if event_count + 1 > cfg.event_max then
			break
		end
	end

	if #lucky_reward > 0 then
		--隐藏道具
		table.insert(lucky_reward, {type = 41, id = 100000, value = 1})
		DOReward(pid, lucky_reward, nil, Command.REASON_MANOR_MANUFACTURE_GATHER, false, loop.now() + 14 * 24 * 3600, nil)
		--self:Notify(Command.NOTIFY_MANOR_LUCKY_EVENT, event_list)
	
		-- add log
		local manor_log = ManorLog.Get(self.pid)
		manor_log:AddLog(EVENT_TYPE_LUCKY, event_list)
	end

	return true, lucky_reward, event_list
end

--popular event
function ManorEvent:GetRandomDiscount(gid)
	local cfg = LoadPopularConfig(gid)
	local discount = 0
	local last_time = 0

	if cfg then
		local rand_num = math.random(1, 100)
		local index = 0

		for k, v in ipairs(cfg.event) do
			if rand_num <= v.event_rate then
				index = k		
				break
			else
				rand_num = rand_num - v.event_rate
			end	

		end

		if index ~= 0 then
			if loop.now() >= cfg.event[index].begin_time and loop.now() <= cfg.event[index].end_time then
				discount = cfg.event[index].limit_time_discount
			else
				discount = cfg.event[index].discount
			end
			last_time = cfg.event[index].last_time
		end
	end	
	
	return discount, last_time
end

function ManorEvent:PopularEventCoolDown(gid, time)
	time = time or loop.now()
	local player_order_price = ManorOrderPrice.Get(self.pid)
	local begin_time, end_time = player_order_price:GetTime(gid)
	local order_price_cfg = LoadPopularConfig(gid)

	if not order_price_cfg then
		return true
	end

	if begin_time ~= 0 and time - begin_time < order_price_cfg.cd_time then
		return true 
	end

	return false 
end

function ManorEvent:TriggerPopularEvent(pid, line, time, type)
	time = time or loop.now()
	local cfg = LoadPopularConfig(nil, line, type)
	local player_order_price = ManorOrderPrice.Get(pid)

	-- only shop trigger popular event
	--[[if line ~= 31 then
		return false
	end--]]

	--choose order 
	local choose_gid = 0
	local total = 0

	for gid, v in pairs(cfg or {}) do
		total = total + v.rate
	end

	local rand_num = math.random(1, total)

	for gid, v in pairs(cfg or {}) do
		if rand_num <= v.rate then
			choose_gid = gid
			break
		else
			rand_num = rand_num - v.rate
		end
	end

	if choose_gid == 0 then
		return false
	end

	--choose price
	local order_price_cfg = LoadPopularConfig(choose_gid)

	if not order_price_cfg then
		return false
	end

	local max = 0
	local index = 0
	local discount = 0
	local last_time = 0

	for k, v in ipairs(order_price_cfg.event or {}) do
		max = max + v.event_rate
	end

	local rand_num2 = math.random(1, max)

	for k, v in ipairs(order_price_cfg.event or {}) do
		if rand_num2 <= v.event_rate then
			index = k		
			break
		else
			rand_num2 = rand_num2 - v.event_rate
		end	

	end

	if index ~= 0 then
		if time >= order_price_cfg.event[index].begin_time and time <= order_price_cfg.event[index].end_time then
			discount = order_price_cfg.event[index].limit_time_discount
		else
			discount = order_price_cfg.event[index].discount
		end
		last_time = order_price_cfg.event[index].last_time
	end

	local old_discount = player_order_price:GetDiscount(choose_gid)
	if old_discount > 100 or self:PopularEventCoolDown(choose_gid, time) then
		return false
	end	

	player_order_price:UpdateOrderPrice(choose_gid, 100 + discount / 100, time, time + last_time)

	--self:Notify(Command.NOTIFY_MANOR_POPULAR_EVENT, {choose_gid, 100 + discount / 100, time, time + last_time, line})
	
	-- add log
	local manor_log = ManorLog.Get(self.pid)
	manor_log:AddLog(EVENT_TYPE_POPULAR, {choose_gid, 100 + discount / 100, time, time + last_time, line})
	
	return true
end

-- risking and traveling event in manor tavern
local MAX_RISK_EVENT_NUM = 5
function ManorEvent:TriggerRiskingEvent(heros, manor_tavern, time)
	local t = {}
	for k, v in ipairs(heros) do
		local hero_risk_cfg = LoadHeroRiskConfig(v.gid)

		if hero_risk_cfg then
			local rand_num = math.random(1, 100)	

			for i = 1, 2, 1 do
				if rand_num <= hero_risk_cfg["event_rate"..i] then
					if #t >= MAX_RISK_EVENT_NUM then
						local rand1 = math.random(1, 50)
						if rand1 > 50 then
							local rand_index = math.random(1, MAX_RISK_EVENT_NUM)
							t[rand_index] = {uuid = v.uuid, gid = v.gid, pool_id = hero_risk_cfg["event_pool"..i]}
						end
					else
						table.insert(t, {uuid = v.uuid, gid = v.gid, pool_id = hero_risk_cfg["event_pool"..i]})
					end
					break
				else
					rand_num = rand_num - hero_risk_cfg["event_rate"..i]
				end	
			end
		end
	end

	local event = {}
	for k, v in ipairs(t) do
		local risk_event_cfg = LoadRiskPoolConfig(v.pool_id)

		if risk_event_cfg then
			local index = math.random(1, #risk_event_cfg.event)	
			--table.insert(event, {uuid = v.uuid, gid = v.gid, event_id = risk_event_cfg[rand_num].gid})

			manor_tavern:UpdateHeroStatus(v.uuid, time, time + risk_event_cfg.event[index].event_time, 0, risk_event_cfg.event[index].gid)
			--manor_tavern:Notify(Command.NOTIFY_MANOR_HERO_LEAVE_TAVERN, {v.uuid, risk_event_cfg.event[index].gid, time, time + risk_event_cfg.event[index].event_time})

			-- add log
			local manor_log = ManorLog.Get(self.pid)
			manor_log:AddLog(EVENT_TYPE_HERO_LEAVE_TAVERN, {v.uuid, risk_event_cfg.event[index].gid, time, time + risk_event_cfg.event[index].event_time})
		end
	end
	
end

--[[local manor_event_update_time = {}

function ManorEvent.RegisterCommand(service)
	service:on(Command.C_MANOR_MANUFACTURE_TRIGGER_EVENT_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local event_type = request[2]
		local line = request[3]
		local manor_event = ManorEvent.Get(pid)
		
		if not manor_event or not line then
			log.debug("param manor_event or param line is nil")
			return conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_TRIGGER_EVENT_RESPOND, pid, respond);
		end

		log.debug(string.format("Player %d begin to trigger event, type %d", pid, event_type))

		if not manor_event then
			log.debug("cannt get manor_event")
			return conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_TRIGGER_EVENT_RESPOND, pid, respond);
		end

		if event_type == 1 then
			if not manor_event_update_time[EVENT_TYPE_POPULAR] then
				manor_event.TriggerPopularEvent(pid, line)			
			end

			if manor_event_update_time[EVENT_TYPE_POPULAR] then
				local trigger_num = math.floor((loop.now() - manor_event_update_time[EVENT_TYPE_POPULAR]) / (2 * 3600))
				for i = 1, trigger_num, 1 do
					manor_event.TriggerPopularEvent(pid, line, manor_event_update_time[EVENT_TYPE_POPULAR])			
					manor_event_update_time[EVENT_TYPE_POPULAR] = manor_event_update_time[EVENT_TYPE_POPULAR] + 2 * 3600
				end
			end
		end

		if event_type == 2 then
			if not manor_event_update_time[EVENT_TYPE_LUCKY] then
				manor_event.TriggerLuckyEvent(pid, line)			
			end

			if manor_event_update_time[EVENT_TYPE_LUCKY] then
				local trigger_num = math.floor((loop.now() - manor_event_update_time[EVENT_TYPE_LUCKY]) / (2 * 3600))
				for i = 1, trigger_num, 1 do
					manor_event.TriggerLuckyEvent(pid, line)			
					manor_event_update_time[EVENT_TYPE_LUCKY] = manor_event_update_time[EVENT_TYPE_LUCKY] + 2 * 3600
				end
			end
	
		end

		conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_TRIGGER_EVENT_RESPOND, pid, {sn, Command.RET_SUCCESS});
	end)
end--]]

local manor_event_update_time = {
	[EVENT_TYPE_POPULAR] = {},
	[EVENT_TYPE_LUCKY] = {},
}

local CD = 3600 
function ManorEvent.RegisterCommand(service)
	service:on(Command.C_MANOR_MANUFACTURE_TRIGGER_EVENT_REQUEST, function(conn, pid, request)
		local sn = request[1];
		local event_type = request[2]
		local line = request[3]
		local manor_event = ManorEvent.Get(pid)
		
		local last_update_time
		if not manor_event or not line then
			log.debug("param manor_event or param line is nil")
			return conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_TRIGGER_EVENT_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		log.debug(string.format("Player %d begin to trigger event, type %d", pid, event_type))

		if not manor_event then
			log.debug("cannt get manor_event")
			return conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_TRIGGER_EVENT_RESPOND, pid, {sn, Command.RET_ERROR});
		end

		if event_type == 1 then
			if not manor_event_update_time[EVENT_TYPE_POPULAR][line] then
				log.debug("first trigger popular event >>>>>>>>>>>>>>>>>>>>")
				manor_event.TriggerPopularEvent(pid, line, loop.now(), 2)			
				manor_event_update_time[EVENT_TYPE_POPULAR][line] = loop.now()
				last_update_time = manor_event_update_time[EVENT_TYPE_POPULAR][line]
			else	
				local trigger_num = math.min(20, math.floor((loop.now() - manor_event_update_time[EVENT_TYPE_POPULAR][line]) / CD))

				log.debug("trigger popular event>>>>>>>>>>>>>>>>>>, trigger_num", trigger_num)
				for i = 1, trigger_num - 1, 1 do
					manor_event_update_time[EVENT_TYPE_POPULAR][line] = manor_event_update_time[EVENT_TYPE_POPULAR][line] + CD 
					manor_event:TriggerPopularEvent(pid, line, manor_event_update_time[EVENT_TYPE_POPULAR][line], 2)			
				end
				
				manor_event_update_time[EVENT_TYPE_POPULAR][line] = loop.now() 
				manor_event:TriggerPopularEvent(pid, line, manor_event_update_time[EVENT_TYPE_POPULAR][line], 2)			
				last_update_time = manor_event_update_time[EVENT_TYPE_POPULAR][line]
			end
		end

		if event_type == 2 then
			local lineInfo = GetManufacture(pid)
			local info = lineInfo:GetLineInfo(line);

			local workmanCount = 0
			for i= 1 , 5 do
				if info.workmen["workman"..i] and info.workmen["workman"..i] ~= 0 then
					workmanCount = workmanCount + 1
				end	
			end

			if workmanCount <= 0 then
				log.debug(string.format("line %d has no workman, cannt trigger lucky event",line))	
				conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_TRIGGER_EVENT_RESPOND, pid, {sn, Command.RET_ERROR});
			end

			if not manor_event_update_time[EVENT_TYPE_LUCKY][line] then
				log.debug("first trigger lucky event >>>>>>>>>>>>>>>>>>>>")
				manor_event:TriggerLuckyEvent2(pid, line, loop.now())			
				manor_event_update_time[EVENT_TYPE_LUCKY][line] = loop.now()
				last_update_time = manor_event_update_time[EVENT_TYPE_LUCKY][line]
			else	
				local trigger_num = math.min(20, math.floor((loop.now() - manor_event_update_time[EVENT_TYPE_LUCKY][line]) / CD))

				log.debug("trigger lucky event>>>>>>>>>>>>>>>>>>>>>>, trigger_num", trigger_num)
				for i = 1, trigger_num - 1 , 1 do
					manor_event_update_time[EVENT_TYPE_LUCKY][line] = manor_event_update_time[EVENT_TYPE_LUCKY][line] + CD 
					manor_event:TriggerLuckyEvent2(pid, line, manor_event_update_time[EVENT_TYPE_LUCKY][line])			
				end

				manor_event_update_time[EVENT_TYPE_LUCKY][line]= loop.now() 
				manor_event:TriggerLuckyEvent2(pid, line, loop.now())			
				last_update_time = manor_event_update_time[EVENT_TYPE_LUCKY][line]
			end
	
		end

		conn:sendClientRespond(Command.C_MANOR_MANUFACTURE_TRIGGER_EVENT_RESPOND, pid, {sn, Command.RET_SUCCESS, last_update_time});
	end)
end

return ManorEvent 
