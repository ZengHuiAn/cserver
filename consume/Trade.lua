local Scheduler = require "Scheduler"
local TradeConfig = require "TradeConfig"
local timeControl = require "timeControl"
local timeControlActivityType = require "timeControlActivityType"
local cell = require "cell"
require "MailReward" 
require "printtb"
require "Thread"
local YQSTR = require "YQSTR"
require "PlayerManager"

local ORIGIN_TIME = 1514736000			-- 2018-1-01 0:0:0
local THIS_YEAR_FIRSTDAY_8 = 1514764800		-- 2018-01-01 8:0:0
local ONE_DAY = 86400

local tax = 0
local function GetTradingTax(now)
	local time_control = timeControl.Get(timeControlActivityType.TYPE_TRADE_BANK)
	local time_tb = time_control:getTime(0)
	for k, v in ipairs(time_tb or {}) do
       		local beginTime = v.begin_time
                local endTime = v.end_time
                local nowPeriod = math.ceil((now - beginTime) / v.duration_per_period)
                local validBeginTime = beginTime + (nowPeriod - 1) * v.duration_per_period
                local validEndTime = validBeginTime + v.valid_time_per_period
                yqinfo("timeControl beginTime %d endTime %d validBeginTime:%d validEndTime:%d",beginTime,endTime,validBeginTime, validEndTime)
                if (not (now < beginTime or now > endTime)) and (now >= validBeginTime and now <= validEndTime) then
                	tax = v.trading_rate
                        break
                end 
	end
	
	return tax/100	
end

local function CheckCommodityValid(commodity)
	local commodity_type = commodity.type
	local commodity_id = commodity.id
	local commodity_value = commodity.value
	local cfg = TradeConfig.GetTradeConfig(commodity_type, commodity_id)
	if not cfg then
		log.debug(string.format("CheckCommodityValid fail, cannt get cfg for commodity:%d %d", commodity_type, commodity_id))
		return false
	end

	print('===============================================  cfg.sale_value commodity_value ',cfg.sale_value,commodity_value)
	if cfg.sale_value ~= commodity_value then
		log.debug(string.format("CheckCommodityValid fail, cfg.sale_value ~= commodity_value"))
		return false
	end

	return true
end

local function CheckPriceValid(assess_price, commodity_type, commodity_id, commodity_value, cost)
	local cfg = TradeConfig.GetTradeConfig(commodity_type, commodity_id)
	if not cfg then
		log.debug(string.format("CheckPriceValid fail, cannt get cfg for commodity:%d %d", commodity_type, commodity_id))
		return false
	end
	
	if cfg.assess_price.type ~= cost.type or cfg.assess_price.id ~= cost.id then
		log.debug(string.format("CheckPriceValid fail, cost of commodity:%d-%d is not %d-%d", commodity_type, commodity_id, cost.type, cost.id))
		return false
	end

	--local price = assess_price * commodity_value
	local price = assess_price
	if cost.value > math.floor(price * 1.5) or cost.value < math.floor(price * 0.5) then
		log.debug(string.format("CheckPriceValid fail, price is too low or too high"))	
		return false
	end

	return true
end

local AllPlayerOrders = {}
local PlayerOrders = {}
local MAX_ORDER = 8
function PlayerOrders.New(pid)
	local t = {
		pid = pid,
		orders = {},
	}	

	return setmetatable(t, {__index = PlayerOrders})
end

function PlayerOrders:AlreadyHasOrder(gid)
	for k, v in ipairs(self.orders) do
		if v.gid == gid then
			return true, k
		end
	end

	return false, nil
end

function PlayerOrders:AddOrder(gid, commodity, cost, putaway_time)
	local already_has_order, idx = self:AlreadyHasOrder(gid) 
	if not already_has_order then
		if #self.orders >= MAX_ORDER then
--			log.warning(string.format("Player %d fail to AddOrder, order reach max", self.pid))
			return false
		end
		table.insert(self.orders, {gid = gid, commodity = commodity, cost = cost, putaway_time = putaway_time})
		return true
	end

	self.orders[idx].commodity = commodity
	self.orders[idx].cost = cost
	self.orders[idx].putaway_time = putaway_time
	return true
end

function PlayerOrders:RemoveOrder(gid)
	-- find index
	local idx = 0
	for k, order in ipairs(self.orders) do
		if order.gid == gid then
			idx = k
			break
		end	
	end
	
	if idx ~= 0 then
		--print('玩家订单删除成功...     idx = '..idx)
		table.remove(self.orders, idx)
		--TODO NOTFIY
		
		--for k,v in ipairs(self.orders) do
		--	print("删除订单后剩下的订单  idx gid: ",k,v.gid)	
		--end
		print('--------------3',gid,idx)
		return true
	end
--	log.warning(string.format("Player %d fail to RemoveOrder for gid %d , order not exist", self.pid, gid))
	return false
end

function PlayerOrders:QueryPlayerOrder()
	return self.orders
end

local function GetPlayerOrders(pid)
	if not AllPlayerOrders[pid] then
		AllPlayerOrders[pid] = PlayerOrders.New(pid)
	end 

	return AllPlayerOrders[pid]
end

local sales_yesterday = {}
local function select_yesterday_sales_db(commodity_type,commodity_id)
	local success, result = database.query("select commodity_type,commodity_id,commodity_value,sales_num,sales_price from trade_yesterday_sales where commodity_type = %d and commodity_id = %d",commodity_type,commodity_id)
	if success and #result > 0 then
		local row = result[1]
		sales_yesterday[row.commodity_type] = sales_yesterday[row.commodity_type] or {}
		sales_yesterday[row.commodity_type][row.commodity_id] = { commodity_type = row.commodity_type,commodity_id = row.commodity_id,commodity_value = row.commodity_value, sales_num = row.sales_num,sales_price = row.sales_price }
		return sales_yesterday[row.commodity_type][row.commodity_id]
	else
		return false
	end
	
end

local function update_yesterday_sales_db(info)
	if type(info) ~= "table"  then
                return false
        end
        if info.is_db then
                local ok = database.update("update trade_yesterday_sales set commodity_value= %d,sales_num = %d,sales_price = %d where commodity_type = %d and commodity_id = %d;",info.commodity_value,info.sales_num,info.sales_price,info.commodity_type,info.commodity_id)
                if ok then
                        return true
                end
        else
		local ok = database.update("insert into trade_yesterday_sales(commodity_type,commodity_id,commodity_value,sales_num,sales_price) values (%d,%d,%d,%d,%d)",info.commodity_type,info.commodity_id,info.commodity_value,info.sales_num,info.sales_price)
                        info.is_db = true
                        return true
        end
        return false	
end

local commodity_orders_count = {}
local function select_commodity_orders_count(commodity_type,commodity_id)
	local success, result = database.query("select commodity_type,commodity_id,ai_sell_count,ai_buy_count,unix_timestamp(next_sell_time) as next_sell_time,unix_timestamp(next_buy_time) as next_buy_time from trade_commodity_orders where commodity_type = %d and commodity_id = %d",commodity_type,commodity_id)
        if success and #result > 0 then
                local row = result[1]
		
                commodity_orders_count[row.commodity_type] = commodity_orders_count[row.commodity_type] or {}
                commodity_orders_count[row.commodity_type][row.commodity_id] = { ai_sell_count = row.ai_sell_count,ai_buy_count = row.ai_buy_count,next_sell_time = row.next_sell_time,next_buy_time = row.next_buy_time }
		return commodity_orders_count[row.commodity_type][row.commodity_id]
	else
		return false
        end
end

local function update_commodity_orders_db(info)
	if type(info) ~= "table"  then
                return false
        end
        if info.is_db then
		local ok = database.update("update trade_commodity_orders set ai_sell_count = %d, ai_buy_count = %d , next_sell_time = from_unixtime_s(%d) ,next_buy_time = from_unixtime_s(%d)  where commodity_type = %d and commodity_id = %d;",info.ai_sell_count,info.ai_buy_count,info.next_sell_time,info.next_buy_time,info.commodity_type,info.commodity_id)
		
               	if ok then
               		return true
                end
        else
                local ok = database.update("insert into trade_commodity_orders(commodity_type,commodity_id,ai_sell_count,ai_buy_count,next_sell_time,next_buy_time) values (%d,%d,%d,%d,from_unixtime_s(%d),from_unixtime_s(%d))",info.commodity_type,info.commodity_id,info.ai_sell_count,info.ai_buy_count,info.next_sell_time,info.next_buy_time)
		if ok then
                        info.is_db = true
                        return true
		else
        		return false
	
        	end
	end
end

local commodity_concern = {}
local function select_trade_commodity_concern(pid)
	local success, result = database.query("select pid,gid from trade_commodity_concern where pid = %d",pid)
	if success and #result > 0 then
		for _,v in ipairs(result) do
			commodity_concern[pid] = commodity_concern[pid] or {}
			table.insert(commodity_concern[pid],v.gid)
		end
		return commodity_concern[pid]	
	else
		return false
	end
end

local function deal_trade_commodity_concern(gid,pid)
	if type(gid) ~= "number" then
		return false
	end
	if pid then
		local ok = database.update("insert into trade_commodity_concern(pid,gid) values(%d,%d)",pid,gid)
		if ok then
			return true
		end
	else
		local ok = database.update("delete from trade_commodity_concern where gid = %d",gid)			
		if ok then
			return true
		end
	end
	
	return false
end

local function remove_concern_orders(pid,gid)	-- 从玩家关注的订单中移除某个订单
	for i,v in ipairs(commodity_concern[pid] or {}) do
                if v == gid then
                        table.remove(commodity_concern[pid],i)
			return true
                end
        end

	return false
end

local function get_commodity_concern(pid)
	if not commodity_concern[pid] then
		local concern = select_trade_commodity_concern(pid)
		if not concern then
			commodity_concern[pid] = {}
		else
			commodity_concern[pid] = concern
		end
	end
	return commodity_concern[pid]
end

local function get_yesterday_sales(commodity_type,commodity_id)
	sales_yesterday[commodity_type] = sales_yesterday[commodity_type] or {}
	if not sales_yesterday[commodity_type][commodity_id] then
		local sales = select_yesterday_sales_db(commodity_type,commodity_id)
		if not sales then
			return false
		end
		
		sales_yesterday[commodity_type][commodity_id] = {commodity_type = sales.commodity_type,commodity_id = sales.commodity_id,commodity_value = sales.commodity_value, sales_num = sales.sales_num,sales_price = sales.sales_price,is_db = true }
	end
	
	return sales_yesterday[commodity_type][commodity_id]
end

local function get_commodity_orders_count(commodity_type,commodity_id)
	commodity_orders_count[commodity_type] = commodity_orders_count[commodity_type] or {}
	if not commodity_orders_count[commodity_type][commodity_id] then
		local res = select_commodity_orders_count(commodity_type,commodity_id)
		if not res then
			commodity_orders_count[commodity_type][commodity_id] = { ai_sell_count = 0 ,ai_buy_count = 0, next_sell_time = ORIGIN_TIME,next_buy_time = ORIGIN_TIME,is_db = false}
		else
			commodity_orders_count[commodity_type][commodity_id] = { ai_sell_count = res.ai_sell_count,ai_buy_count = res.ai_buy_count,next_sell_time = res.next_sell_time,next_buy_time = res.next_buy_time,is_db = true }
		end
	else
		commodity_orders_count[commodity_type][commodity_id].is_db = true
	end
	
	return commodity_orders_count[commodity_type][commodity_id]
end


local COMMODITY_TYPE_ITEM = 41
local COMMODITY_TYPE_EQUIP = 45
local COMMODITY_TYPE_EQUIP2 = 43

local TradeOrders = {
	[COMMODITY_TYPE_ITEM] = {},
	[COMMODITY_TYPE_EQUIP] = {},
	[COMMODITY_TYPE_EQUIP2] = {},
	valid_time = 60,
}

function TradeOrders.LoadAllTradeOrders()
	local success, result = database.query("select gid, seller, commodity_type, commodity_id, commodity_value, commodity_uuid,commodity_equip_level,commodity_equip_quality ,cost_type, cost_id, cost_value, unix_timestamp(putaway_time) as putaway_time ,concern_count from trade_orders ORDER BY cost_value, putaway_time")

	if success and #result > 0 then
		for i = 1, #result, 1 do
			local row = result[i]
			if TradeOrders[row.commodity_type] then
				TradeOrders.SetOrder(row.seller, row.gid, {type = row.commodity_type, id = row.commodity_id, value = row.commodity_value, uuid = row.commodity_uuid,equip_level = row.commodity_equip_level,equip_quality = row.commodity_equip_quality}, {type = row.cost_type, id = row.cost_id, value = row.cost_value}, row.putaway_time, false,row.concern_count)
				
				local player_orders = GetPlayerOrders(row.seller)
				player_orders:AddOrder(row.gid, {type = row.commodity_type, id = row.commodity_id, value = row.commodity_value, uuid = row.commodity_uuid}, {type = row.cost_type, id = row.cost_id, value = row.cost_value}, row.putaway_time)
			end	
		end 
	end
end

function TradeOrders.ValidTime(time)
	if loop.now() - time > TradeOrders.valid_time then
		return true
	end

	return false
end

local precision = 0.000001
local function FloatEqual(a, b)
	if math.abs((a - b)) < precision then
		return true
	end

	return false
end

local function FloatLess(a, b)
	if not FloatEqual(a, b) and a - b < 0 then
		return true	
	end

	return false
end

local function FloatMore(a, b)
	if not FloatEqual(a, b) and a - b > 0 then
		return true	
	end

	return false
end

function TradeOrders.OnSell(putaway_time)
	assert(putaway_time)
	return loop.now() - putaway_time <= 24 * 3600	-- 5 * 60
end

-- 订单过期
function TradeOrders.OrderOutdate(putaway_time)
	return loop.now() - putaway_time > 24 * 3600
end


--插入新订单或修改原订单
local MAX_PRICE = 100000
local function get_last_gid_trade_orders()
	local success, result = database.query(" select gid from trade_orders order by gid desc limit 1 ")
	if success and #result > 0 then
		return result[1].gid
	else
		return 0
	end
end

local last_gid = get_last_gid_trade_orders() 
function TradeOrders.SetOrder(pid, gid, commodity, cost, putaway_time, update_database,concern_count)
	if update_database ~= nil then
		update_database = update_database
	else
		update_database = true
	end
--	gid = gid or database.last_id() + 1
        gid = gid or last_gid + 1
	concern_count = concern_count or 0
	local commodity_type = commodity.type
	local commodity_id = commodity.id
	local commodity_value = commodity.value
	local commodity_uuid = commodity.uuid
	local commodity_equip_level = commodity.equip_level
	local commodity_equip_quality = commodity.equip_quality
	local cost_type = cost.type
	local cost_id = cost.id
	local cost_value = cost.value
	local average_cost_value = cost_value / commodity_value
	if cost_value <= 0 or commodity_value <= 0 then
		log.warning("SetOrder fail,  cost value or commodity value is invalid")	
		return false
	end
	
	if not TradeOrders[commodity_type] then
		log.warning(string.format("commodity for type %d is not allowed to sell", commodity_type))
		return false
	end

	TradeOrders[commodity_type][commodity_id] = TradeOrders[commodity_type][commodity_id] or {rank = {}, orders = {}}
	TradeOrders.addressing_map = TradeOrders.addressing_map or {}
	local rank = TradeOrders[commodity_type][commodity_id].rank
	local orders = TradeOrders[commodity_type][commodity_id].orders
	local addressing_map = TradeOrders.addressing_map

	--[[if not TradeOrders.ValidTime(putaway_time) then
		return false
	end--]]
	local item 
	if not orders[gid] then
		--新订单或者是第一次载入数据
		item = {gid = gid, seller = pid, commodity = {type = commodity_type, id = commodity_id, value = commodity_value, uuid = commodity_uuid, equip_level = commodity_equip_level, equip_quality = commodity_equip_quality}, cost = {type = cost_type, id = cost_id, value = cost_value}, putaway_time = putaway_time, pos = #rank + 1, db_exist = not update_database,concern_count = concern_count}
		
		orders[gid] = item
		--未过期订单才插入排行榜
		if not TradeOrders.OrderOutdate(putaway_time) then
			--item.pos = nil
			table.insert(rank, item)
		end
	else	
		--订单已存在
		item = orders[gid]
		if item.seller ~= pid then
			log.warning(string.format("SetOrder fail, order not belong to player %d", pid))
			return false
		end

		if item.commodity.type ~= commodity_type or item.commodity.id ~= commodity_id then
			log.warning(string.format("SetOrder fail, commodity type and id not fit with old order", pid))
			return false
		end

		if TradeOrders.OnSell(item.putaway_time) then
			log.warning(string.format("SetOrder fail, order is on sell"))
			return false
		end

		if not orders[gid].pos then
			--订单已从排行榜移除
			orders[gid].pos = #rank + 1
			orders[gid].cost.value = cost_value 
			orders[gid].putaway_time = putaway_time
			table.insert(rank, item)
		end
			--订单未从排行榜移除
			--DO NOTHING
	end

	local old_average_cost_value = item.cost.value / item.commodity.value

--[[
	if cost_value == item.cost.value and commodity_value == item.commodity.value and item.putaway_time == putaway_time then
		print('--------------cost_value == item.cost.value')
		return item.pos
	end
--]]
	local oldpos = orders[gid].pos

	--过期订单没有pos
	if oldpos then
		local step = -1;
		local change = 1;
		local stop = 1;

		if item.cost.value ~= 0 and average_cost_value > old_average_cost_value then
			step = 1;
			change = -1;
			stop = table.maxn(rank);
		end

		item.cost.value = cost_value
		item.putaway_time = putaway_time

		for ite = oldpos, stop, step do
			local front = rank[ite + step];
			local front_average_cost_value
			if front then
				front_average_cost_value = front.cost.value / front.commodity.value
			end
			if front == nil or FloatLess(front_average_cost_value, average_cost_value) or (FloatEqual(front_average_cost_value, average_cost_value) and front.putaway_time < putaway_time) or (FloatEqual(front_average_cost_value, average_cost_value) and front.putaway_time == putaway_time and front.gid < item.gid)then
				rank[ite] = item;
				item.pos = ite;
				break;
			else
				rank[ite] = front;
				front.pos = ite;
			end
		end
	end

	addressing_map[gid] = {addressing_type = commodity_type, addressing_id = commodity_id}	

	if update_database then
		if item.db_exist then
			database.update("update trade_orders set commodity_type = %d, commodity_id = %d, commodity_value = %d, commodity_uuid = %d, commodity_equip_level = %d,commodity_equip_quality = %d,cost_type = %d, cost_id = %d, cost_value = %d, putaway_time = from_unixtime_s(%d) where gid = %d", item.commodity.type, item.commodity.id, item.commodity.value, item.commodity.uuid,item.commodity.equip_level ,item.commodity.equip_quality ,item.cost.type, item.cost.id, item.cost.value, item.putaway_time,gid)	
		else
			database.update("insert into trade_orders(seller, commodity_type, commodity_id, commodity_value, commodity_uuid, commodity_equip_level,commodity_equip_quality ,cost_type, cost_id, cost_value, putaway_time) values (%d, %d, %d, %d, %d,%d, %d, %d, %d, %d, from_unixtime_s(%d))", item.seller, item.commodity.type, item.commodity.id, item.commodity.value, item.commodity.uuid, item.commodity.equip_level ,item.commodity.equip_quality,item.cost.type, item.cost.id, item.cost.value, item.putaway_time)
			item.db_exist = true
			
			last_gid = database.last_id()	
		end
	end
	return true, item.pos, item.gid;
end

--仅从排行榜移除订单
function TradeOrders.RemoveRank(gid)
	local addressing_map = TradeOrders.addressing_map 
	
	if not addressing_map or not addressing_map[gid] then
		log.warning(string.format("fail to RemoveRank, order %d not exist, it may remove by TradeOrders.RemoveOrder", gid))
		return false
	end

	local commodity_type = addressing_map[gid].addressing_type 
	local commodity_id = addressing_map[gid].addressing_id 
	assert(TradeOrders[commodity_type][commodity_id])
	local rank = TradeOrders[commodity_type][commodity_id].rank

	local orders = TradeOrders[commodity_type][commodity_id].orders
	local item = orders[gid]	-- 为何orders的pos会为空?????
	--assert(item.pos)
	--[[
	if item.pos then		
		print('############### item.pos = '.. item.pos)	-- 此处寻找的pos有点问题,暂时不用,待完善
		for pos,v in ipairs(rank) do
			print('移除前：',v.gid,pos)
		end
		table.remove(rank, item.pos)	
		item.pos = nil
		for pos,v in ipairs(rank) do
                        print('移除后：',v.gid,pos)
                end
	end --]]

	for pos,v in ipairs(rank) do
		if v.gid == gid then 
			table.remove(rank,pos)
			print('---------------------------------')
			if v.seller < 100000 then	-- AI
				print('=============================== AI 过期订单处理')
				database.update("delete from trade_orders where gid = %d",gid)
				orders[gid] = nil
				if commodity_orders_count[v.commodity.type] and commodity_orders_count[v.commodity.type][v.commodity.id] then 
					print('===========================')
					commodity_orders_count[v.commodity.type][v.commodity.id] = {ai_sell_count = 0 ,ai_buy_count = 0, next_sell_time = ORIGIN_TIME,next_buy_time = ORIGIN_TIME }
					local temp = commodity_orders_count[v.commodity.type][v.commodity.id]
					local ok = database.update("update trade_commodity_orders set ai_sell_count = %d, ai_buy_count = %d , next_sell_time = from_unixtime_s(%d) ,next_buy_time = from_unixtime_s(%d)  where commodity_type = %d and commodity_id = %d;",temp.ai_sell_count,temp.ai_buy_count,temp.next_sell_time,temp.next_buy_time,v.commodity.type,v.commodity.id)
                			if ok then
						commodity_orders_count[v.commodity.type][v.commodity.id] = nil
                			end
				end
			else
				local suc1 = database.update("update trade_orders set concern_count = %d where gid = %d",orders[gid].concern_count,gid)
				local suc2 = database.update("delete from trade_commodity_concern where gid = %d",gid)
				if not suc1 or not suc2 then
					return false
				end				

				orders[gid].concern_count = 0
				for p,g in ipairs(commodity_concern) do
					remove_concern_orders(p,gid)
				end
			end
		end
	end
end

--移除订单(若排行榜有该订单则也移除)
function TradeOrders.RemoveOrder(gid)
	local addressing_map = TradeOrders.addressing_map 
	
	if not addressing_map or not addressing_map[gid] then
		log.warning(string.format("fail to RemoveOrder, order %d not exist", gid))
		return false
	end

	local commodity_type = addressing_map[gid].addressing_type 
	local commodity_id = addressing_map[gid].addressing_id 
	assert(TradeOrders[commodity_type][commodity_id])
	local rank = TradeOrders[commodity_type][commodity_id].rank
	local orders = TradeOrders[commodity_type][commodity_id].orders
	local item = orders[gid]
	--[[
	for _,v in ipairs(rank) do
		print('start rank:',v.gid,v.pos)
	end--]]
	if not item then 
		log.warning(string.format("fail to RemoveOrder, order %d not exist", gid))
		return false 
	end 
	if  item.pos then
		print('-----------2:item.pos = '..item.pos)
		local idx = 0
		for k,order in ipairs(rank) do
			if order.gid == gid then
				idx = k
				break
			end
		end	
		if idx ~= 0 then
			table.remove(rank, idx)
		end	

--		table.remove(rank, item.pos)
--		item.pos = nil
	end
	--[[
	for _,v in ipairs(rank) do
		print('end rank:',v.gid,v.pos)
	end--]]
	orders[gid] = nil
	addressing_map[gid] = nil

	database.update("delete from trade_orders where gid = %d", gid)

	local player_orders = GetPlayerOrders(item.seller)
	player_orders:RemoveOrder(gid)
	return true
end

function TradeOrders.GetOrder(gid)
	local addressing_map = TradeOrders.addressing_map 
	
	if not addressing_map or not addressing_map[gid] then
		log.warning(string.format("fail to GetOrder, order %d not exist", gid))
		return false
	end

	local commodity_type = addressing_map[gid].addressing_type 
	local commodity_id = addressing_map[gid].addressing_id 
	assert(TradeOrders[commodity_type][commodity_id])
	local rank = TradeOrders[commodity_type][commodity_id].rank
	local orders = TradeOrders[commodity_type][commodity_id].orders

	return orders[gid]
end

local function get_concern_value(concerns,order)
	for _,v in ipairs(concerns) do
		if v == order.gid then 
			return 1
		end
        end
	return 0
end

local function insert_unoverdue_orders(now,concerns,amf,order)
	if now - order.putaway_time < ONE_DAY then
        	concern = get_concern_value(concerns,order)
                table.insert(amf, {order.gid, {order.commodity.type,order.commodity.id,order.commodity.value,order.commodity.uuid}, {order.cost.type,order.cost.id,order.cost.value}, order.putaway_time,order.concern_count,concern})
        end
end

function TradeOrders.GetRank(commodity_type, commodity_id, ite, len,level_min,level_max,quality,pid)
	if not TradeOrders[commodity_type] then
		return {}
	end

	if not TradeOrders[commodity_type][commodity_id] then
		return {}
	end

	local rank = TradeOrders[commodity_type][commodity_id].rank
	
	local concerns = get_commodity_concern(pid)
        if not concerns then
		return false
	end
	
	local now = loop.now()
	local concern = nil
	local amf = {}
	if commodity_type == COMMODITY_TYPE_ITEM then
		local start, stop , step
		if ite > 0 then
			start = ite
			stop = math.min(ite + len, #rank)
			step = 1	
		else
			start = #rank
			stop = math.max(#rank - len, 1)
			step = -1
		end	
		for i = start, stop, step do
			local order = rank[i]
			insert_unoverdue_orders(now,concerns,amf,order)				-- 插入未过期的订单到amf中 
		end
	elseif commodity_type == COMMODITY_TYPE_EQUIP or commodity_type == COMMODITY_TYPE_EQUIP2 then
		local e_num = 0
		if level_min and level_max and quality then
			if ite > 0 then
		 		for i = 1,#rank,1 do
                                	local order = rank[i]
                                	if order.commodity.equip_level >= level_min and order.commodity.equip_level <= level_max and order.commodity.equip_quality == quality then
						insert_unoverdue_orders(now,concerns,amf,order)
                                       	 	e_num = e_num + 1
                                        	if e_num == len then break end
                                	end
                        	end 

			else
				for i = #rank,1,-1 do
					local order = rank[i]
					if order.commodity.equip_level >= level_min and order.commodity.equip_level <= level_max and order.commodity.equip_quality == quality then
						insert_unoverdue_orders(now,concerns,amf,order)						
						e_num = e_num + 1
						if e_num == len then break end
					end	
				end
			end
		elseif level_min and level_max then
			if ite > 0 then
                                for i = 1,#rank,1 do
                                        local order = rank[i]
                                        if order.commodity.equip_level >= level_min and order.commodity.equip_level <= level_max then
						insert_unoverdue_orders(now,concerns,amf,order)
						e_num = e_num + 1
                                                if e_num == len then break end
                                        end
                                end

                        else
                                for i = #rank,1,-1 do
                                        local order = rank[i]
                                        if order.commodity.equip_level >= level_min and order.commodity.equip_level <= level_max then
						insert_unoverdue_orders(now,concerns,amf,order)
                                                e_num = e_num + 1
                                                if e_num == len then break end
                                        end
                                end
                        end
		elseif quality then
			if ite > 0 then
                                for i = 1,#rank,1 do
                                        local order = rank[i]
                                        if order.commodity.equip_quality == quality then
						insert_unoverdue_orders(now,concerns,amf,order)
                                                e_num = e_num + 1
                                                if e_num == len then break end
                                        end
                                end

                        else
                                for i = #rank,1,-1 do
                                        local order = rank[i]
                                        if order.commodity.equip_quality == quality then
						insert_unoverdue_orders(now,concerns,amf,order)
                                                e_num = e_num + 1
                                                if e_num == len then break end
                                        end
                                end
                        end
		elseif not level_min and not level_max and not quality then
			local start, stop , step
                	if ite > 0 then
                        	start = ite
                        	stop = math.min(ite + len, #rank)
                        	step = 1
                	else
                        	start = #rank
                        	stop = math.max(#rank - len, 1)
                        	step = -1
                	end
			for i = start, stop, step do
	                        local order = rank[i]
				insert_unoverdue_orders(now,concerns,amf,order)
			end
		else
			return false				
		end
	end
	return amf
end


local COIN_TYPE = 41
local COIN_ID = 90002

local function CalcServiceCharge(price, service_charge_rate)
	local charge = math.floor(price * service_charge_rate / 100)

	if charge < 100 then
		return 100
	end
	
	if charge > 10000 then
		return 10000
	end

	return charge 
end

local function Charge(pid, commodity, fee)

	local commodity_type = commodity.type	
	local commodity_id = commodity.id
	local commodity_value = commodity.value	
	
	if commodity_type ~= COMMODITY_TYPE_ITEM then
		log.warning("Charge error commodity_type id not item")
		return false
	end

	local consume = {{type = commodity_type, id = commodity_id, value = commodity_value}, fee}
	
	local ret = cell.sendReward(pid, nil, consume, Command.REASON_TRADE)
	if ret and ret.result == Command.RET_SUCCESS then
		return true
	else
		log.warning("Charge fail, cell error")
		return false
	end
end

local function SendCommodity(pid, commodity)
	local ret = cell.sendReward(pid, {commodity}, nil, Command.REASON_TRADE)
	if ret and ret.result == Command.RET_SUCCESS then
		return true
	else
		log.warning("SendCommodity fail, cell error")
		return false
	end
end

local function SendCommodityEquip(pid,commodity)
	print('======================================== ',commodity.id,commodity.uuid)
	local ret,level,quality = cell.TradeEquipWithSystem(pid, commodity.id,commodity.uuid,nil,nil)
        if ret then
                return true
        else
                log.warning("SendCommodityEquip fail, cell error")
                return false
        end		
end

local function Exchange(pid,reward,consume)
	local ret = cell.sendReward(pid,reward, consume, Command.REASON_TRADE)

	if ret and ret.result == Command.RET_SUCCESS then
		return true
	else
		log.warning("Exchange fail, cell error")
		return false
	end
end

-------------------------------------  交易记录
local TYPE_SELL = 1
local TYPE_BUY  = 2
local TradeRecord = {}
local function doTradeRecord(buyer,seller,gid,commodity,cost)
	print('**************************seller = '..seller,'buyer = '..buyer)
	TradeRecord[seller]	    = TradeRecord[seller] or {}
	TradeRecord[seller][TYPE_SELL] = TradeRecord[seller][TYPE_SELL] or {}
	table.insert(TradeRecord[seller][TYPE_SELL],{trader = buyer,commodity_type = commodity.type,commodity_id = commodity.id,commodity_value = commodity.value,commodity_uuid = commodity.uuid,cost_type = cost.type,cost_id = cost.id,cost_value = cost.value})

	TradeRecord[buyer]            = TradeRecord[buyer] or {}
        TradeRecord[buyer][TYPE_BUY]  = TradeRecord[buyer][TYPE_BUY] or {}
	table.insert(TradeRecord[buyer][TYPE_BUY],{trader = seller,commodity_type = commodity.type,commodity_id = commodity.id,commodity_value = commodity.value,commodity_uuid = commodity.uuid,cost_type = cost.type,cost_id = cost.id,cost_value = cost.value})	

	local d1 = database.update("insert into trade_records(pid,type,gid,trader,commodity_type,commodity_id,commodity_value,commodity_uuid,cost_type,cost_id,cost_value) values (%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)",seller,TYPE_SELL,gid,buyer,commodity.type,commodity.id,commodity.value,commodity.uuid,cost.type,cost.id,cost.value)
	local d2 = database.update("insert into trade_records(pid,type,gid,trader,commodity_type,commodity_id,commodity_value,commodity_uuid,cost_type,cost_id,cost_value) values (%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)",buyer,TYPE_BUY,gid,seller,commodity.type,commodity.id,commodity.value,commodity.uuid,cost.type,cost.id,cost.value)
	if not d1 or not d2 then
		return false
	end
        return true		
end

local RECORD_NUM = 90
local function getTradeRecord(pid,type)
	local amf = {}
	TradeRecord[pid] = TradeRecord[pid] or {}
	if not TradeRecord[pid][type] then
		TradeRecord[pid][type] = {}
		local ok,res = database.query("select pid,type,gid,trader,commodity_type,commodity_id,commodity_value,cost_type,cost_id,cost_value from trade_records where pid = %d and type = %d;",pid,type)
		local num = #res
		print('record num = '..num)
		if ok and num > 0 then
			for _,v in ipairs(res) do

				table.insert(TradeRecord[pid][type],{trader = v.trader,commodity_type = v.commodity_type,commodity_id = v.commodity_id,commodity_value = v.commodity_value,commodity_uuid = v.commodity_uuid,cost_type = v.cost_type,cost_id = v.cost_id,cost_value = v.cost_value})

			end
			if num >= RECORD_NUM then
				for i = num,num - RECORD_NUM + 1,-1 do
					local tmp = res[i]
					table.insert(amf,{trader = tmp.trader,commodity_type = tmp.commodity_type,commodity_id = tmp.commodity_id,commodity_value = tmp.commodity_value,commodity_uuid = tmp.commodity_uuid,cost_type = tmp.cost_type,cost_id = tmp.cost_id,cost_value = tmp.cost_value})

				end
			else
				for i = num,1,-1 do
                                        local tmp = res[i]
                                        table.insert(amf,{trader = tmp.trader,commodity_type = tmp.commodity_type,commodity_id = tmp.commodity_id,commodity_value = tmp.commodity_value,commodity_uuid = tmp.commodity_uuid,cost_type = tmp.cost_type,cost_id = tmp.cost_id,cost_value = tmp.cost_value})

                                end
			end			
		else
			return nil
		end
	else
		local res = TradeRecord[pid][type]
		local num = #res
		if num >= RECORD_NUM then
			for i = num,num - RECORD_NUM + 1,-1 do
				local tmp = res[i]
				table.insert(amf,{trader = tmp.trader,commodity_type = tmp.commodity_type,commodity_id = tmp.commodity_id,commodity_value = tmp.commodity_value,commodity_uuid = tmp.commodity_uuid,cost_type = tmp.cost_type,cost_id = tmp.cost_id,cost_value = tmp.cost_value})
			end	
		else
			for i = num,1,-1 do
				local tmp = res[i]
				table.insert(amf,{trader = tmp.trader,commodity_type = tmp.commodity_type,commodity_id = tmp.commodity_id,commodity_value = tmp.commodity_value,commodity_uuid = tmp.commodity_uuid,cost_type = tmp.cost_type,cost_id = tmp.cost_id,cost_value = tmp.cost_value})

                                end
		end 
	end

	return amf
end

local function query_tradeorders(pid,record_type,type)
	print('***************pid = '..pid)
	local records = getTradeRecord(pid,record_type)
	if not records or #records <= 0 then 
		log.warning('there is no record...')
		return {}
	end			

	if type == 2 then	-- 清空记录...
		TradeRecord[pid][record_type] = nil
		database.update("delete from trade_records where pid = %d and type = %d;",pid,record_type)
		return {}
	end
	
	local amf = {}
	for i,v in ipairs(records) do
		if i > RECORD_NUM then
			break
		end
			
		table.insert(amf,{v.trader,{v.commodity_type,v.commodity_id,v.commodity_value,v.commodity_uuid},{v.cost_type,v.cost_id,v.cost_value}})		
	end
	return amf
end


--LOGIC
--查询玩家订单
local function process_trade_query_player_orders(conn, pid, req)
	local cmd = Command.C_TRADE_QUERY_PLAYER_ORDERS_RESPOND
	local sn = req[1]

	local player_orders = GetPlayerOrders(pid)
	local orders = player_orders:QueryPlayerOrder()	
	print("**************查自己:")
	local amf = {}
	for k, order in ipairs(orders) do
		print('订单:',order.gid)
		table.insert(amf, {order.gid, {order.commodity.type, order.commodity.id, order.commodity.value, order.commodity.uuid}, {order.cost.type, order.cost.id, order.cost.value}, order.putaway_time})
	end
		
	conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, amf})
end

--查询商品配置
local function process_trade_query_commodity_config(conn, pid, req)
	local cmd = Command.C_TRADE_QUERY_COMMODITY_CONFIG_RESPOND
	local sn = req[1]

	local cfg = TradeConfig.GetAllTradeConfig()
	print("-----------------start query_commodity_config:")
	local amf = {}
	for type, v in pairs(cfg or {}) do
		for id, v2 in pairs(v) do
			local sale_record = GetRecord(type, id)
			local assess_price = sale_record:GetTodayAssessPrice()
			table.insert(amf, {type, id, v2.sale_value, v2.assess_price.type, v2.assess_price.id, assess_price, v2.fee_type, v2.fee_id, v2.fee_rate})	
		end
	end
	conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS, amf,GetTradingTax(loop.now())})
end

--上架
local function process_trade_sell(conn, pid, req)
	local cmd = Command.C_TRADE_SELL_RESPOND
	local sn = req[1]
	local commodity = req[2]
	local price = req[3]
	local gid = req[4]

--	print("上架:  gid = "..gid)
	--check
	print('---------------------------------------process_trade_sell........')
	if not commodity or #commodity ~= 4 then
		log.debug("Fail to process_trade_sell, param commodity is nil")
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
		return
	end
			
	if not price then
		log.debug("Fail to process_trade_sell, param price is nil")
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
		return 
	end

	if not gid then
		log.debug(string.format("Player %d begin to process_trade_sell", pid))
	else
		log.debug(string.format("Player %d begin to process_trade_resell for order %d", pid, gid))
	end

	commodity = {type = commodity[1], id = commodity[2], value = commodity[3], uuid = commodity[4]}
	print('----------------------- commodity.uuid = '..commodity.uuid)
	if not CheckCommodityValid(commodity) then
		log.debug("Fail to process_trade_sell, commodity not valid")
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		return
	end
	local cfg = TradeConfig.GetTradeConfig(commodity.type, commodity.id)
	if not cfg then
		log.debug(string.format("Fail to process_trade_sell, trade config is nil for type %d id %d", commodity.type, commodity.id))
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		return
	end
	cost = {type = cfg.assess_price.type, id = cfg.assess_price.id, value = price}
	
	local sale_record = GetRecord(commodity.type, commodity.id)
	local assess_price = sale_record:GetTodayAssessPrice()
	if not CheckPriceValid(assess_price, commodity.type, commodity.id, commodity.value, cost) then
		log.debug("Fail to process_trade_sell, price not valid")
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		return
	end

	--手续费
	local fee = {}
	if cfg.fee_type == cost.type and cfg.fee_id == cost.id then
		fee = {type = cfg.fee_type, id = cfg.fee_id, value = CalcServiceCharge(cost.value, cfg.fee_rate)}	
	else
		--汇率转换
		local rate_cfg = TradeConfig.GetTradeExchangeRateConfig(cost.id, cfg.fee_id)
		if not rate_cfg then
			fee = {type = cfg.fee_type, id = cfg.fee_id, value = CalcServiceCharge(cost.value, cfg.fee_rate)}	
		else
			local after_change_cost_value = math.floor(rate_cfg.rate2 / rate_cfg.rate1 * cost.value)
			fee = {type = cfg.fee_type, id = cfg.fee_id, value = CalcServiceCharge(after_change_cost_value, cfg.fee_rate)}	
		end	
	end	

	if commodity.type == COMMODITY_TYPE_EQUIP or commodity.type == COMMODITY_TYPE_EQUIP2 then
		if not gid then
			print('pid, commodity.id,commodity.uuid = ',pid, commodity.id,commodity.uuid)
			local result,level,quality = cell.TradeEquipWithSystem(pid, commodity.id,commodity.uuid , 1, {fee})
			if not result then
				conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
                        	return
			end
			print('-------------------level,quality = ',level,quality)	
			commodity.equip_level = level
			commodity.equip_quality = quality
		else
			if not Exchange(pid, nil, {fee}) then	-- 重新上架仍需扣除手续费
				return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
			end
		end
	elseif commodity.type == COMMODITY_TYPE_ITEM then
		print('--------------------------------------------- fee.value = '..fee.value)
		if not gid then
			if not Charge(pid, commodity, fee) then
                		log.debug("Fail to process_trade_sell, charge fail")
                		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
			end
		else
			if not Exchange(pid, nil, {fee}) then
				return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
			end
        	end
		commodity.equip_level = 0
		commodity.equip_quality = 0
	else
		log.error("item type is error...")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end
	print('------------------------------------------------------ commodity.uuid  = '..commodity.uuid)
	local success, pos, ngid = TradeOrders.SetOrder(pid, gid, commodity, cost, loop.now(), true)
	if not success then
		log.error("Fail to process_trade_sell, set order fail")
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		return
	end

	local player_orders = GetPlayerOrders(pid)
	player_orders:AddOrder(ngid, {type = commodity.type, id = commodity.id, value = commodity.value, uuid = commodity.uuid}, {type = cost.type, id = cost.id, value = cost.value}, loop.now())

	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS})
end

--下架
local function process_trade_take_back(conn, pid, req)
	local cmd = Command.C_TRADE_TAKE_BACK_RESPOND
	local sn = req[1]
	local gid = req[2]
	print("------------------------------take_back:")
	if not gid then
		log.debug("Fail to process_trade_take_back, param gid is nil")
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
		return 
	end
	
	log.debug(string.format("Player %d begin to process_trade_take_back for order %d", pid, gid))

	local order = TradeOrders.GetOrder(gid)
	if not order then
		log.debug("Fail to process_trade_take_back, order not exist")
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_NOT_EXIST})
		return 
	end

	if order.seller ~= pid then
		log.debug(string.format("Fail to process_trade_take_back, order not belong to Player %d", player))
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		return 
	end

	local commodity = order.commodity 
	print('------------------------------------',commodity.uuid)
	if commodity.type == COMMODITY_TYPE_ITEM then
		if not SendCommodity(order.seller, commodity) then
                	log.debug(string.format("Fail to process_trade_take_back, send commodity fail"))
                	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end
	elseif commodity.type == COMMODITY_TYPE_EQUIP or commodity.type == COMMODITY_TYPE_EQUIP2 then
		if not SendCommodityEquip(order.seller,commodity) then
			log.debug(string.format("Fail to process_trade_take_back, send commodityequip fail"))
	                return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end
	end

	if not TradeOrders.RemoveOrder(gid) then
		log.error("Fail to process_trade_take_back, remove order fail")
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		return 
	end

	conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS})
end

--购买
local tax_rate = 9
local function process_trade_buy(conn, pid, req)
	local cmd = Command.C_TRADE_BUY_RESPOND
	local sn = req[1]
	local gid = req[2]
	print('buy gid = ' .. gid)
	print('-----------------------start process_trade_buy:')
	if not gid then
		log.warning("Fail to process_trade_buy, param gid is nil")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end
	log.debug(string.format("Player %d begin to process_trade_buy or order %d", pid, gid))
	print("购买：gid = "..gid)
	local order = TradeOrders.GetOrder(gid)	
	if not order then
		log.warning("Fail to process_trade_buy, order not exist")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_TRADE_NOT_EXIST})
	end
	if TradeOrders.OrderOutdate(order.putaway_time) then
		log.warning("Fail to process_trade_buy, order out of date")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_TRADE_OUTOFDATE})
	end

	local commodity = order.commodity 	
	local cost = order.cost
	--tax
	local tax = {type = cost.type, id = cost.id, value = math.floor(cost.value * GetTradingTax(loop.now()))}

	-- 生成出售、购买记录
	if not doTradeRecord(pid,order.seller,gid,commodity,cost) then
               	log.warning("Fail to generate record...")
               	return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
       	end

	-- 发邮件、
	local cfg = TradeConfig.GetTradeConfig(commodity.type, commodity.id)
        if not cfg then
                log.debug(string.format("Fail to process_trade_sell, trade config is nil for type %d id %d", commodity.type, commodity.id))
                return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
        end

	local item_name = nil
	local item_cfg = TradeConfig.GetItemConfig(commodity.id)
	if item_cfg then
		item_name = item_cfg.item_name
	else
		item_name = ""				-- 有些装备的名字暂时取不到,配置表里无对应装备
	end
	local player = PlayerManager.Get(pid, false)
	local player_name = player.name
	local buyer_name
	if player_name then
		print(player_name)
		buyer_name = string.len(player_name) < 3 and player_name or string.sub(player_name,1,3)
	else
		buyer_name = ""
	end
	local profit_value = cost.value - tax.value
	local profit = { type = cost.type,id = cost.id,value = profit_value } 
        local tax_today = tax_rate
        --local str_time = os.date("%Y年%m月%d日",loop.now())

	print('==================================='..item_name,buyer_name,profit_value,tax_today)
	send_reward_by_mail(order.seller,YQSTR.TRADEBANK_TRADESUCCESS_TITLE,string.format(YQSTR.TRADEBANK_TRADESUCCESS_CONTENT,tostring(item_name),tostring(buyer_name),profit_value,tax_today),{ profit })

	if not Exchange(pid, nil, {cost}) then
		log.debug("Fail to process_trade_buy, consume fail")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_TRADE_EXCHAGE_FAIL})
	end
	local _commodity = {type = commodity.type,id = commodity.id,value = commodity.value}

	--buyer
	if commodity.type == COMMODITY_TYPE_EQUIP  or commodity.type == COMMODITY_TYPE_EQUIP2 then
		local buy = cell.TradeEquipWithSystem(pid, commodity.id,commodity.uuid , nil, nil)
                if not buy then
                       return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
                end	

	else
		if not Exchange(pid,{_commodity},nil) then
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end
		--seller
	--	Exchange(order.seller,nil, {_commodity})
	end 
	
	if not TradeOrders.RemoveOrder(gid) then
		log.error("Fail to process_trade_buy, remove order fail")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR}) 
	end
	
       	local ok = database.update("delete from trade_commodity_concern where gid = %d",gid)
	if not ok then 
		log.warning("delete trade_commodity_concern erro...")
		return 
	end
			
	remove_concern_orders(pid,gid)
	                
	local sale_record = GetRecord(commodity.type, commodity.id)	
	local today_avg_price = sale_record:GetAvgPrice()
	local today_sales = sale_record:GetSales()
	sale_record:UpdateTodaySaleRecord(((today_avg_price * today_sales + cost.value) / (today_sales + commodity.value)), today_sales + commodity.value)

	conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS})
end

--查询商品价格排行榜
local function process_trade_query_orders_rank(conn, pid, req)
	local cmd = Command.C_TRADE_QUERY_ORDERS_RANK_RESPOND
	local sn = req[1]
	local target_type = req[2]
	local target_id = req[3]
	local begin = req[4]
	local len = req[5]
	local equip_level_min = req[6]      -- 装备等级范围
	local equip_level_max = req[7]
	local equip_quality = req[8]	    -- 品质

	if not target_type or not target_id or not begin or not len then
		log.debug("Fail to process_trade_query_orders_rank, param error")
		conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
		return
	end
	print("--------------------------trade_query_orders_rank:")
	if len > 50 then
		len = 50
	end
	local ret = TradeOrders.GetRank(target_type, target_id, begin, len,equip_level_min,equip_level_max,equip_quality,pid)
	return conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR, ret})
end

local function process_query_tradeorders(conn, pid, req)
	local cmd = Command.C_TRADE_QUERY_TRADEORDERS_RESPOND
	local sn  = req[1]
	local record_type  = req[2]   --  1:卖记录  2:买记录
	local _type        = req[3]   --  1:查看    2:清除
	print('================== record_type、_type = ' .. record_type,_type)
	if type(record_type) ~= "number" or type(_type) ~= "number" then
		log.warning('param is not correct...')
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end
	print("--------------------------start query_trade_orders:")
	print("record_type = "..record_type,"_type = ".._type)
	local ret = query_tradeorders(pid,record_type,_type)

	return conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR, ret})
end

local function process_set_commodity_concern(conn, pid, req)
	local cmd = Command.C_TRADE_SET_COMMODITY_CONCERN_RESPOND
	local sn = req[1]
	local _type = req[2]	-- 1 关注 0 取消关注
	local gid = req[3]
	print('=============================== start set commodity_concern:')

	if type(_type) ~= "number" then
		log.warning('param is not correct...')
                return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	local concerns = get_commodity_concern(pid)
	if not concerns then
                return conn:sendClientRespond(cmd, pid, {sn,Command.RET_ERROR})
	end
	
	local order = TradeOrders.GetOrder(gid)		
	if not order then
		log.warning("there is no the order ...")
		return conn:sendClientRespond(cmd, pid, {sn,Command.RET_ERROR})
	end
	local result = nil
	if _type == 1 then
		if #concerns >= 8 then	-- 最多关注8个订单
			return conn:sendClientRespond(cmd, pid, {sn,Command.RET_ERROR})
		end 
		
		print('type id = ',order.commodity.type,order.commodity.id)
		local cfg = TradeConfig.GetTradeConfig(order.commodity.type, order.commodity.id)		
		if not cfg then
           	     	print('there is no commodity in config file ...')
                	return conn:sendClientRespond(cmd, pid, {sn,Command.RET_ERROR})
        	end
		if cfg.is_special == 1 then
			for _,v in ipairs(concerns) do
				if v == gid then return conn:sendClientRespond(cmd, pid, {sn,Command.RET_ERROR}) end	-- 订单已被关注,无法再次关注
			end	
			table.insert(commodity_concern[pid],gid)
			result = deal_trade_commodity_concern(gid,pid)
			if result then
				order.concern_count = order.concern_count + 1
			end
		else
			log.warning("commodity is not be concerned...")
			return conn:sendClientRespond(cmd, pid, {sn,Command.RET_ERROR})
		end
	elseif _type == 0 then
		remove_concern_orders(pid,gid)
		
		result = deal_trade_commodity_concern(gid)
		if result then -- result then
			if order.concern_count > 0 then order.concern_count = order.concern_count - 1 end
		end
	else
		return conn:sendClientRespond(cmd, pid, {sn,Command.RET_PARAM_ERROR})
	end
	
	if result then
		database.update("update trade_orders set concern_count = %d where gid = %d",order.concern_count,gid)			
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_SUCCESS })
	end
end

local function process_query_commodity_concern(conn, pid, req)
	local cmd = Command.C_TRADE_QUERY_COMMODITY_CONCERN_RESPOND
	local sn = req[1]
	print('=============================== start query commodity_concern:')

	local concerns = get_commodity_concern(pid)
	local amf = {}
	if not concerns then
		return conn:sendClientRespond(cmd, pid, {sn,Command.RET_SUCCESS,amf})
	else
		local concern = nil
		for _,v in ipairs(concerns) do
			local order = TradeOrders.GetOrder(v)
			if order and loop.now() - order.putaway_time < ONE_DAY then
				concern = get_concern_value(concerns,order)			
				print('type id concern_count concern = ',order.commodity.type,order.commodity.id,order.concern_count,concern)
				table.insert(amf, {order.gid, {order.commodity.type, order.commodity.id, order.commodity.value, order.commodity.uuid}, {order.cost.type, order.cost.id, order.cost.value}, order.putaway_time,order.concern_count,concern})	
			end
		end
		return conn:sendClientRespond(cmd, pid, {sn,Command.RET_SUCCESS,amf})	
	end
end

local function process_auto_buy_vip(conn, pid, req)
	local cmd = Command.C_TRADE_AUTO_BUY_RESPOND
	local sn  = req[1]	
	local player = PlayerManager.Get(pid, false)	

	local vip = player.vip	
	if vip >= 100 and vip < 10000 then
		log.warning("vip is not meet...")
		return conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_SUCCESS, ret})
	else	
		return conn:sendClientRespond(cmd, pid, {sn, ret and Command.RET_SUCCESS or Command.RET_ERROR, ret})
	end
end

TradeOrders.LoadAllTradeOrders()

local function CleanOutOfDataOrder(now)
	local quickly_out_of_date_order = {}

	for item_id, v in pairs(TradeOrders[COMMODITY_TYPE_ITEM]) do
		for gid, order in pairs(v.orders or {}) do
			if TradeOrders.OrderOutdate(order.putaway_time) then
                        	table.insert(quickly_out_of_date_order, order.gid)
                        end
                end
        end
	
	for _, gid in ipairs(quickly_out_of_date_order) do
		TradeOrders.RemoveRank(gid)
	end
end

--定时器   任务：1清除过期订单，从排行榜清除剩余时间小于1分钟的订单  2....
Scheduler.Register(function(now)
	if now % 60 == 0 then
		CleanOutOfDataOrder(now)
	end
end)

--Sale Record

local DAY_SEC = 24 * 3600 
local ASSESS_PRICE_PERIOD = 14
local MAX_RECORD_LENGTH = 14  --数据库保存数据的有效长度
assert(ASSESS_PRICE_PERIOD <= MAX_RECORD_LENGTH)
local SaleRecord = {}

local AllRecords = {}
function GetRecord(type, id)
	if not AllRecords[type] then
		AllRecords[type] = {}
	end

	if not AllRecords[type][id] then
		AllRecords[type][id] = SaleRecord.New(type, id)
	end

	return AllRecords[type][id]
end

function SaleRecord.New(type, id)
	local cfg = TradeConfig.GetTradeConfig(type, id)
	local success, result = database.query("select type, id, avg_price1, sales1, avg_price2, sales2, avg_price3, sales3, avg_price4, sales4, avg_price5, sales5, avg_price6, sales6, avg_price7, sales7, avg_price8, sales8, avg_price9, sales9, avg_price10, sales10, avg_price11, sales11, avg_price12, sales12, avg_price13, sales13, avg_price14, sales14, today_avg_price, today_sales, unix_timestamp(last_trade_time) as last_trade_time from trade_item_sale_record where type = %d and id = %d", type, id)

	local t = {
		type = type,
		id = id,
		avg_price = {},
		sales = {},
		today_avg_price = 0,
		today_sales = 0,
		last_trade_time = 0,
		today_assess_price = cfg and cfg.assess_price.value or 0, 
		db_exist = false, 
	}

	for i = 1, MAX_RECORD_LENGTH, 1 do
		table.insert(t.avg_price, 0)
		table.insert(t.sales, 0)
	end

	if success and #result > 0 then
		local row = result[1]
		for i = 1, MAX_RECORD_LENGTH, 1 do
			t.avg_price[i] = row["avg_price"..tostring(i)]
			t.sales[i] = row["sales"..tostring(i)]
			t.today_avg_price = row.today_avg_price
			t.today_sales = row.today_sales
			t.last_trade_time = row.last_trade_time
			t.db_exist = true
		end
	end

	return setmetatable(t, {__index = SaleRecord})
end

--获取前len天对应的索引表
function SaleRecord:GetLastPeriodIndexTb(idx, len)
	local beg = idx -len 
	local t = {}
	if beg > 0 then
		for i = beg, idx - 1, 1 do
			table.insert(t, i)	
		end		
	else
		local beg1 = MAX_RECORD_LENGTH + beg	
		for i = beg1, MAX_RECORD_LENGTH, 1 do
			table.insert(t, i)
		end	

		for i = 1, idx - 1 , 1 do
			table.insert(t, i)
		end
	end

	return t
end

--调用此函数时 所有数据必须已更新过
function SaleRecord:CalcTodayAssessPrice()
	local p2 = self:GetPeriod(loop.now())
	local idx = self:Mod(p2, MAX_RECORD_LENGTH)
	local idx_t = self:GetLastPeriodIndexTb(idx, ASSESS_PRICE_PERIOD)
	local total = 0
	for _, index in ipairs(idx_t) do
		total = total + self.avg_price[index]
	end
	return total / ASSESS_PRICE_PERIOD
end


require "StableTime"
local openServerTime = StableTime.get_open_server_time()
local get_begin_time_of_day = StableTime.get_begin_time_of_day
local reference_time = get_begin_time_of_day(openServerTime)

function SaleRecord:GetPeriod(t)
	t = t or loop.now()

	--特殊处理
	if t == 0 then
		return 0
	end

	assert(t > reference_time)
	return math.ceil((t - reference_time)/DAY_SEC)
end

function SaleRecord:Mod(a, b)
	local mod = a % b
	if mod == 0 then 
		return b
	end

	return mod
end

-- 更新至最新数据
function SaleRecord:Update()
	local p1 = self:GetPeriod(self.last_trade_time)
	local p2 = self:GetPeriod(loop.now())
	assert (p1 <= p2)
	--如果不是当天数据则更新
	if p1 ~= p2 then
		if p2 - p1 >= MAX_RECORD_LENGTH or p1 == 0 then 
			--数据过期已超过数据库保存数据的长度
			for i = 1, MAX_RECORD_LENGTH, 1 do
				--if i ~= self:Mod(p2, MAX_RECORD_LENGTH) then
					self.avg_price[i] = self.today_assess_price 
					self.sales[i] = 0
				--end
			end
			self.today_assess_price = self:CalcTodayAssessPrice()
			self.today_avg_price = self.today_assess_price
			self.today_sales = 0
			self.last_trade_time = loop.now()
		else
			local idx_t = self:GetLastPeriodIndexTb(self:Mod(p2, MAX_RECORD_LENGTH), p2 - p1)
			for _, i in ipairs(idx_t) do
				if i == self:Mod(p1, MAX_RECORD_LENGTH) then
					self.avg_price[i] = self.today_avg_price
					self.sales[i] = self.today_sales
				else
					self.avg_price[i] = self.today_assess_price 
					self.sales[i] = 0
				end
			end

			self.today_assess_price = self:CalcTodayAssessPrice()
			self.today_avg_price = self.today_assess_price 
			self.today_sales = 0
			self.last_trade_time = loop.now()
		end	
	end
end

-- day 负数:-1 前一天。。。     nil 当天 
function SaleRecord:GetAvgPrice(day)
	day = day or 0
	assert(math.abs(day) <= MAX_RECORD_LENGTH)
	self:Update()
	if day < 0 then
		local p = self:GetPeriod()
		local idx_t = self:GetLastPeriodIndexTb(self:Mod(p, MAX_RECORD_LENGTH), math.abs(day))
		return self.avg_price[idx_t[1]]
	else
		return self.today_avg_price
	end
end

function SaleRecord:GetSales(day)
	day = day or 0
	assert(math.abs(day) <= MAX_RECORD_LENGTH)
	self:Update()
	if day < 0 then
		local p = self:GetPeriod()
		local idx_t = self:GetLastPeriodIndexTb(self:Mod(p, MAX_RECORD_LENGTH), math.abs(day))
		return self.sales[idx_t[1]]
	else
		return self.today_sales
	end
end

function SaleRecord:GetTodayAssessPrice()
	self:Update()
	return self.today_assess_price
end

function SaleRecord:UpdateTodaySaleRecord(avg, sales)
	self:Update()

	self.today_avg_price = avg
	self.today_sales = sales

	if self.db_exist then
		--database.update("update trade_item_sale_record set today_avg_price = %f, today_sales = %d where type = %d and id = %d", avg, sales, self.type, self.id)
		database.update("update trade_item_sale_record set avg_price1=%f, sales1=%d, avg_price2=%f, sales2=%d, avg_price3=%f, sales3=%d, avg_price4=%f, sales4=%d, avg_price5=%f, sales5=%d, avg_price6=%f, sales6=%d, avg_price7=%f, sales7=%d, avg_price8=%f, sales8=%d, avg_price9=%f, sales9=%d, avg_price10=%f, sales10=%d, avg_price11=%f, sales11=%d, avg_price12=%f, sales12=%d, avg_price13=%f, sales13=%d, avg_price14=%f, sales14=%d, today_avg_price=%f, today_sales=%d, last_trade_time=from_unixtime_s(%d) where type = %d and id = %d",self.avg_price[1], self.sales[1], self.avg_price[2], self.sales[2], self.avg_price[3], self.sales[3], self.avg_price[4], self.sales[4], self.avg_price[5], self.sales[5], self.avg_price[6], self.sales[6], self.avg_price[7], self.sales[7], self.avg_price[8], self.sales[8], self.avg_price[9], self.sales[9], self.avg_price[10], self.sales[10], self.avg_price[11], self.sales[11], self.avg_price[12], self.sales[12], self.avg_price[13], self.sales[13], self.avg_price[14], self.sales[14], self.today_avg_price, self.today_sales, self.last_trade_time,self.type, self.id)
	else
		database.update("insert into trade_item_sale_record(type, id , avg_price1, sales1, avg_price2, sales2, avg_price3, sales3, avg_price4, sales4, avg_price5, sales5, avg_price6, sales6, avg_price7, sales7, avg_price8, sales8, avg_price9, sales9, avg_price10, sales10, avg_price11, sales11, avg_price12, sales12, avg_price13, sales13, avg_price14, sales14, today_avg_price, today_sales, last_trade_time) values(%d, %d, %f, %d, %f, %d, %f, %d, %f, %d, %f, %d, %f, %d, %f, %d, %f, %d, %f, %d, %f, %d, %f, %d, %f, %d, %f, %d, %f, %d, %f, %d, from_unixtime_s(%d))", self.type, self.id, self.avg_price[1], self.sales[1], self.avg_price[2], self.sales[2], self.avg_price[3], self.sales[3], self.avg_price[4], self.sales[4], self.avg_price[5], self.sales[5], self.avg_price[6], self.sales[6], self.avg_price[7], self.sales[7], self.avg_price[8], self.sales[8], self.avg_price[9], self.sales[9], self.avg_price[10], self.sales[10], self.avg_price[11], self.sales[11], self.avg_price[12], self.sales[12], self.avg_price[13], self.sales[13], self.avg_price[14], self.sales[14], self.today_avg_price, self.today_sales, self.last_trade_time)
		self.db_exist = true
	end
end


--test case
--[[local conn = {}
function conn:sendClientRespond(cmd, pid, respond)
	return 
end--]]

--[[for i = 1, 100, 1 do
	process_trade_sell(conn, i, {1, {41, math.random(900005, 900016), 1, 0}, math.random(100, 500)})
end--]]

--process_trade_sell(conn, 1, {1, {41, 50001, 50, 0}, 1000})

--process_trade_take_back(conn, 1, {1, 1})


--[[local instance = GetRecord(41, 900006)
local today_access_price = instance:GetTodayAssessPrice()
local today_avg_price = instance:GetAvgPrice()
local today_sales = instance:GetSales()
local period = instance:GetPeriod()
print("today_assess_price  today_avg_price  today_sales  period>>>>>>>>>>>", today_access_price, today_avg_price, today_sales, period)

print("sell one")
instance:UpdateTodaySaleRecord(((today_avg_price * today_sales + 16) / (today_sales + 1)), today_sales + 1)
print("sell another")
today_avg_price = instance:GetAvgPrice()
today_sales = instance:GetSales()
instance:UpdateTodaySaleRecord(((today_avg_price * today_sales + 17) / (today_sales + 1)), today_sales + 1)--]]


local function Test(pid,gid,commodity,cost)
	local success, pos, ngid = TradeOrders.SetOrder(pid, gid, commodity, cost, loop.now(), true)
        if not success then
                print("生成订单失败...")
		return
        end

        local player_orders = GetPlayerOrders(pid)
        player_orders:AddOrder(ngid, {type = commodity.type, id = commodity.id, value = commodity.value, uuid = commodity.uuid}, {type = cost.type, id = cost.id, value = cost.value}, loop.now())	
	
end

local function PrintPlayerOrder(pid)
	local player_orders = GetPlayerOrders(1)
        local orders = player_orders:QueryPlayerOrder()
        for k, order in ipairs(orders) do
                print('玩家订单:',order.gid)
        end
end


----[[ AI
local function is_zero_time(now)
        local INTEVAL = 24 * 3600
        if (now - ORIGIN_TIME) % INTEVAL == 0 then
                return true
        end
        return false
end

local sale_record 	= GetRecord(41,71005)
print('**************************************************************')
local assess_price 	= sale_record:GetTodayAssessPrice()
print('**************************************************************')
local cfg_assess_price 	= TradeConfig.GetTradeConfig(41,71005).assess_price.value

print('================ 红烧龙肉面：',assess_price,cfg_assess_price)


local function hahaha(amf,type)
	for id,v in pairs(TradeOrders[type]) do
                for _,order in pairs(v.orders or {}) do
                        local commodity = order.commodity
                        local sale_record = GetRecord(type, commodity.id)
                        local assess_price = sale_record:GetTodayAssessPrice()
			local cfg_assess_price = TradeConfig.GetTradeConfig(type,id).assess_price.value
			local rate = (assess_price - cfg_assess_price)/cfg_assess_price
			local is_changed = ""
			if assess_price ~= cfg_assess_price then
				is_changed = "是"
			end	
                      	table.insert(amf,{type,id,assess_price,cfg_assess_price,rate,is_changed})
			break
                end
        end
end

local function doTodaySaleRecord()
	local amf = {}
	hahaha(amf,41)
	hahaha(amf,43)
	hahaha(amf,45)
	return amf
end


--[[
Scheduler.Register(function(now)
--	if is_zero_time(now) then
	if now%5 == 0 then
		print('=====================================')
		local myTest = "类型	商品id		评估价格	配置原始价格	价格涨幅	价格是否变化	生成时间\r\n"
		local str_time = os.date("%Y年%m月%d日%H:%M:%S",now)
		local text = doTodaySaleRecord()
		for _,v in ipairs(text) do
    			local temp = string.format("%d	%d		%d		%d		%f	%s		%s\r\n",v[1],v[2],v[3],v[4],v[5],v[6],str_time)	
			myTest = myTest .. temp
		end

		local file = io.open("../ztest/value_files/file.txt","w")
		if file then
			file:write(myTest)
			file:close()
		end
	end
end) --]]


local function process_AI_buy(now)
	print('===================process_AI_buy')
        for item_id, v in pairs(TradeOrders[COMMODITY_TYPE_ITEM]) do
                for _, order in pairs(v.orders or {}) do
                        local commodity = order.commodity
			print('------------------2:',order.gid,commodity.type,commodity.id,commodity.value)
                        local items = TradeOrders.GetRank(commodity.type,commodity.id,0,math.ceil(#v.rank))          -- 最低的一半物品(系统发起购买)
			local item = items[1]
		
			local total_time = (now - item[4])/3600    -- 上架总时间
                        local sale_record = GetRecord(commodity.type,commodity.id)
                        local assess_price = sale_record:GetTodayAssessPrice()
                        local buy_probability = total_time * 0.2 + (assess_price -  item[3][3]) * 0.1
			local half_num = math.floor(item[2][3])		-- math.floor(item[2][3]/2)
			local half_value = math.floor(item[3][3])	-- math.floor(item[3][3]/2)
			if half_num > 0 then
				local cost = {type = item[3][1],id = item[3][2],value = half_value}	
				print(cost.type,cost.id,cost.value)
                        	if buy_probability >= 1 then    -- 发起购买
					if Exchange(order.seller,{cost}, nil) then	
						TradeOrders.RemoveOrder(item[1])
						print('success')
					end
        	        	end
			end
		end
	end
end
local function process_sell(commodity,price)
	local gid = nil
	local pid = 0
	local commodity = { type = commodity.commodity_type,id = commodity.commodity_id,value = commodity.commodity_value,uuid = commodity.uuid, equip_level = commodity.equip_level,equip_quality = commodity.equip_quality }
	if not CheckCommodityValid(commodity) then
		print('CheckCommodityValid')
		return
	end
	local cfg = TradeConfig.GetTradeConfig(commodity.type, commodity.id)
	if not cfg then
		print('TradeConfig.GetTradeConfig')
		return
	end
	cost = {type = cfg.assess_price.type, id = cfg.assess_price.id, value = price}
	local sale_record = GetRecord(commodity.type, commodity.id)
	local assess_price = sale_record:GetTodayAssessPrice()
	if not CheckPriceValid(assess_price, commodity.type, commodity.id, commodity.value, cost) then
		print('CheckPriceValid is valid')
		return
	end


	local success, pos, ngid = TradeOrders.SetOrder(pid, gid, commodity, cost, loop.now(), true)
	if not success then
		print('not success')
		return
	end

	local player_orders = GetPlayerOrders(pid)
	player_orders:AddOrder(ngid, {type = commodity.type, id = commodity.id, value = commodity.value, uuid = commodity.uuid}, {type = cost.type, id = cost.id, value = cost.value}, loop.now())


end

local function process_AI_sell(now)
	local t_sales = {}
	for type,v1 in pairs(sales_yesterday) do
		for id,v2 in pairs(v1 or {} ) do
			if sales_yesterday[type] and sales_yesterday[type][id] then
                                table.insert(t_sales,{ commodity_type = type,commodity_id = id,num = sales_yesterday[type][id].sales_num })
                        end	
		end
	end
	table.sort(t_sales,function(a,b)
		return a.num > b.num
	end)		

	-- 系统上架 ------------------------------------------------------------------------------
	local w = t_sales[1] or {}
	if w.commodity_type and w.commodity_id then
		local co_type = w.commodity_type
		local co_id   = w.commodity_id
		local sale_record = GetRecord(w.commodity_type,w.commodity_id)
		local assess_price = sale_record:GetTodayAssessPrice()
		local num = sale_record.today_sales
		if sales_yesterday[co_type] and sales_yesterday[co_type][co_id] and  num < sales_yesterday[co_type][co_id].sales_num * 0.05 then
			local yesterday_num   = sales_yesterday[co_type][co_id].sales_num
			local yesterday_price = sales_yesterday[co_type][co_id].sales_price
			--if i <= count then
				--w.commodity_value = yesterday_num / 2	
				local is_continue = false	
                        	if num > 100 and sale_record.today_avg_price >= yesterday_price * 1.3 then	-- 防止奸商囤货
                                	if now % 60 == 0 then   --此时上架10件物品
                                        	if num < yesterday_num * 0.05 then -- 上架上限
							is_continue = true	
							process_sell(w,yesterday_price)
                                        	end
                                	end
                       		end			
			--end
			if not is_continue then
				process_sell(w,yesterday_price)
			end
		end
	else		
			-- 初始第一天无销量时，自动上架所有物品各10件
			--[[
			local cfg = TradeConfig.GetAllTradeConfig()
        		for type, v in pairs(cfg or {}) do
				print(type)
                		for id, v2 in pairs(v) do
					local commodity = {commodity_type = type,commodity_id = id, value = 10 } 		
					print(commodity.commodity_type,commodity.commodity_id,commodity.value)
			--		process_sell( commodity ,v2.assess_price.value)	
                		end
        		end
			--]]
			
			local cfg = TradeConfig.GetTradingAIConfig(1)
			for type,v in pairs(cfg or {}) do
				for id,v2 in pairs(v or {}) do
					local commodity = TradeConfig.GetTradeConfig(type,id)
					local rate = math.random(-5,5)*10 /100
					local sell_value = commodity.assess_price.value  *  (1 + rate)
					local commodity_sell = { commodity_type = type,commodity_id = id,commodity_value = commodity.sale_value} 
					process_sell( commodity_sell, sell_value)

				end
			end
	end
end

local function random_AI_name()
	math.randomseed(os.time())
	local sex = math.random(0,1)
	local ai_name = GetAIRandomName(sex)

end

local AI_is_trade = false
Scheduler.Register(function(now)
	if not AI_is_trade then
		--process_AI_sell(now)
		--process_AI_buy(now)
		--AI_is_trade = true
	end
	if not is_zero_time(now) then
		return
	end
	
	for item_id, v in pairs(TradeOrders[COMMODITY_TYPE_ITEM]) do
                for gid, order in pairs(v.orders or {}) do
                       	local commodity = order.commodity
			local co_type = commodity.type
			local co_id   = commodity.id
			local sale_record = GetRecord(co_type,co_id)
			local sales = get_yesterday_sales(co_type,co_id)
			if not sales then
				sales_yesterday[co_type] = sales_yesterday[co_type] or {}
				sales_yesterday[co_type][co_id] = { sales_num = sale_record.today_sales,sales_price = sale_record.today_avg_price,is_db = false }
			else
				sales.sales_num = sale_record.today_sales
				sales.sales_price = sale_record.today_avg_price
			end
			print('--------------------',sales.sales_num,sales.sales_price)	
			update_yesterday_sales_db(sales_yesterday[co_type][co_id])
                end
        end

	AI_is_trade = false--]]
end)

local function begin_time(now)
	local n = math.floor((now - THIS_YEAR_FIRSTDAY_8) / ONE_DAY)
	return THIS_YEAR_FIRSTDAY_8 + n * ONE_DAY
end

local function begin_time_hour(now)
        local n = math.floor((now - THIS_YEAR_FIRSTDAY_8) / 7200)
        return THIS_YEAR_FIRSTDAY_8 + n * 7200
end

-- local sum = 120
local ai_sell_num = {}
local ai_buy_num = {}
local sell_cfg = TradeConfig.GetTradingAIConfig(1)
local buy_cfg  = TradeConfig.GetTradingAIConfig(2)
local prepare_sell = {}
--local temp_prepare_sell = {}
local num = 0
local COMMODITY_COUNT = 0
for type,v in pairs(sell_cfg or {}) do
	for id,v2 in pairs(v or {}) do
		COMMODITY_COUNT = COMMODITY_COUNT + 1		
	end
end
print('COMMODITY_COUNT = ' .. COMMODITY_COUNT)
local function process_trade_config_ai()
	for type,v in pairs(sell_cfg or {}) do
		for id,v2 in pairs(v or {}) do
			ai_sell_num[type] = ai_sell_num[type] or {}
	                ai_sell_num[type][id] = 0
	
			ai_buy_num[type] = ai_buy_num[type] or {}
			ai_buy_num[type][id] = v2.grounding_num_conditon
			table.insert(prepare_sell,{type = type,id = id,ai_info = v2})
		end
	end
--	temp_prepare_sell = prepare_sell
end


--process_trade_config_ai()

local function isAITradeTime(cfg)	-- AI可以交易的起始时间
        local now = loop.now()
        if now < cfg.begin_time or now >= cfg.end_time then
                return false
        end

        return true
end

-- 新行为
local function process_AI_sell2(now)
        for type,v in pairs(sell_cfg or {}) do
                for id,v2 in pairs(v or {}) do
			if isAITradeTime(v2) then				
				local orders_count = get_commodity_orders_count(type,id)
				local is_db = true
				if orders_count.ai_sell_count < v2.grounding_num_conditon then		-- 出售数量上限
					if now > orders_count.next_sell_time then
						local commodity = TradeConfig.GetTradeConfig(type,id)
						local rate = math.random(-5,5)*10 /100
                        			local sell_value = commodity.assess_price.value  *  (1 + rate)
	                        		local commodity_sell = { commodity_type = type,commodity_id = id,commodity_value = commodity.sale_value,equip_level = 0,equip_quality = 0}

						process_sell(commodity_sell, sell_value) 
						orders_count.ai_sell_count = orders_count.ai_sell_count + 1
					
						local temp = {commodity_type = type,commodity_id = id,ai_sell_count = orders_count.ai_sell_count,ai_buy_count = orders_count.ai_buy_count,next_sell_time = orders_count.next_sell_time,next_buy_time = orders_count.next_buy_time,is_db = orders_count.is_db}
						if orders_count.ai_sell_count == v2.grounding_num_conditon then
							local next_time = begin_time_hour(now)	+ v2.time_cd
							temp.next_sell_time = next_time
							orders_count.next_sell_time = next_time
						end
						
						update_commodity_orders_db(temp)
					end
				end
       			 end
		end
	end
end

local OrderCommodities = {}

local function insertOrders(type)
	for item_id, v in pairs(TradeOrders[type]) do
                for _, order in pairs(v.orders or {}) do
                        local commodity = order.commodity
                        local type = commodity.type
                        local id   = commodity.id
                        local value = commodity.value
                        OrderCommodities[type] = OrderCommodities[type] or {}
                        OrderCommodities[type][id] = OrderCommodities[type][id] or {}
                        table.insert(OrderCommodities[type][id],{gid = order.gid })
                end
        end
end

local function doOrderCommodity()
	insertOrders(COMMODITY_TYPE_ITEM)
	insertOrders(COMMODITY_TYPE_EQUIP)
	insertOrders(COMMODITY_TYPE_EQUIP2)
end

local function process_AI_buy2(now)
	doOrderCommodity()

	for type,v in pairs(OrderCommodities or {}) do
		for id,v2 in pairs(v) do
			local cfg = buy_cfg[type][id]
			if isAITradeTime(cfg) and OrderCommodities[type][id][1] then
				local orders_count = get_commodity_orders_count(type,id)
				if orders_count.ai_buy_count < cfg.grounding_num_conditon and now > orders_count.next_buy_time then	-- 购买数量上限
					TradeOrders.RemoveOrder(OrderCommodities[type][id][1].gid)
					OrderCommodities[type][id] = nil
					if commodity_orders_count[type] and commodity_orders_count[type][id] then
						orders_count.ai_sell_count = orders_count.ai_sell_count - 1
						orders_count.ai_buy_count = orders_count.ai_buy_count + 1
					end	
					local temp = { commodity_type = type,commodity_id = id,ai_sell_count = orders_count.ai_sell_count,ai_buy_count = orders_count.ai_buy_count,next_sell_time = orders_count.next_sell_time,next_buy_time = orders_count.next_buy_time,is_db = orders_count.is_db }	
					if orders_count.ai_buy_count == cfg.grounding_num_conditon then
						local next_time = begin_time_hour(now) + cfg.time_cd
                                                temp.next_buy_time = next_time
						orders_count.next_buy_time = next_time

						temp.ai_buy_count = 0
						orders_count.ai_buy_count = 0
                                        end
					update_commodity_orders_db(temp)
				end
			end
		end
	end	
end

local count_sell = 0
local ONCE_MAX_NUM = 20
local had_sell = {}
local function process_AI_sell3(now)
	if #prepare_sell == 0 then
		--prepare_sell = temp_prepare_sell
		process_trade_config_ai()
	end	
	if #had_sell == COMMODITY_COUNT then had_sell = {} end

	if #had_sell > 0 then
		for i,v in ipairs(had_sell) do
			for j,w in ipairs(prepare_sell) do
				if v.type == w.type and v.id == w.id then table.remove(prepare_sell,j) end
			end
		end
	end
	for index,v in ipairs(prepare_sell) do
		if count_sell < ONCE_MAX_NUM then
			table.insert(had_sell,{type = v.type,id = v.id})
			count_sell = count_sell + 1
		else
			count_sell = 0
			break
		end
		
		local info = {begin_time = v.ai_info.begin_time,end_time = v.ai_info.end_time} 
		local type = v.type
		local id = v.id
		local grounding_num_conditon = v.ai_info.grounding_num_conditon
		local time_cd = v.ai_info.time_cd
		if isAITradeTime(info) then
			local orders_count = get_commodity_orders_count(type,id)
                	local is_db = true
                	if orders_count.ai_sell_count < grounding_num_conditon and now > orders_count.next_sell_time then          -- 出售数量上限		
	                        local commodity = TradeConfig.GetTradeConfig(type,id)
                                local rate = math.random(-5,5)*10 /100
                                local sell_value = commodity.assess_price.value  *  (1 + rate)
				print("oooooooooooooooooooooooooooooooooooo 	sell_value = " .. sell_value,"assess_price = "..commodity.assess_price.value,"rate = "..rate)
                                local commodity_sell = { commodity_type = type,commodity_id = id,commodity_value = commodity.sale_value,uuid = 0,equip_level = 0,equip_quality = 0}
				for i = 1,grounding_num_conditon,1 do	
					--print('*********************************   先让系统获得一件道具')
					--print('&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&   ',commodity_sell.commodity_id,commodity_sell.uuid)
					--local result,level,quality,uuid = cell.TradeEquipWithSystem(100000,commodity_sell.commodity_id,commodity_sell.uuid,nil,nil)
					--local result,level,quality,uuid = cell.TradeEquipWithSystem(100000,83003,414,nil,nil)
					--commodity_sell.uuid = uuid
					--print("====================== uuid = ",uuid)
	                        	process_sell(commodity_sell, sell_value)
				end
                                orders_count.ai_sell_count = orders_count.ai_sell_count + grounding_num_conditon
				if orders_count.ai_sell_count > grounding_num_conditon then
					orders_count.ai_sell_count = grounding_num_conditon
				elseif orders_count.ai_sell_count < 0 then
					orders_count.ai_sell_count = 0
				end
                                local temp = { commodity_type = type,commodity_id = id,ai_sell_count = orders_count.ai_sell_count,ai_buy_count = orders_count.ai_buy_count, next_sell_time = orders_count.next_sell_time,next_buy_time = orders_count.next_buy_time,is_db = orders_count.is_db}
                                if orders_count.ai_sell_count == grounding_num_conditon then
                                	local next_time = begin_time_hour(now)  + time_cd
                                        temp.next_sell_time = next_time
                                        orders_count.next_sell_time = next_time
                                end
				--table.insert(had_sell,{type = v.type,id = v.id})
                                update_commodity_orders_db(temp)
                	end
		end
	end
end

local function process_AI_buy3(now)
	doOrderCommodity()
	for type,v in pairs(OrderCommodities or {}) do
		for id,v2 in pairs(v) do
			if buy_cfg[type] and buy_cfg[type][id] and OrderCommodities[type][id][1] then	-- AI购买的暂时只购买AI出售的,忽略掉玩家出售的订单
				local cfg = buy_cfg[type][id]
				if isAITradeTime(cfg) then
					local orders_count = get_commodity_orders_count(type,id)
					if orders_count.ai_buy_count < cfg.grounding_num_conditon and now > orders_count.next_buy_time then	-- 购买数量上限
						TradeOrders.RemoveOrder(OrderCommodities[type][id][1].gid)
						--TradeOrders.RemoveRank(OrderCommodities[type][id][1].gid)
						OrderCommodities[type][id] = nil
						if commodity_orders_count[type] and commodity_orders_count[type][id] then
							orders_count.ai_sell_count = orders_count.ai_sell_count - 1
							orders_count.ai_buy_count = orders_count.ai_buy_count + 1
						end	
						if orders_count.ai_sell_count < 0 then
							orders_count.ai_sell_count = 0
						end
						local temp = { commodity_type = type,commodity_id = id,ai_sell_count = orders_count.ai_sell_count,ai_buy_count = orders_count.ai_buy_count,next_sell_time = orders_count.next_sell_time,next_buy_time = orders_count.next_buy_time,is_db = orders_count.is_db }	
						if orders_count.ai_buy_count == cfg.grounding_num_conditon then
							local next_time = begin_time_hour(now) + cfg.time_cd
                                         		temp.next_buy_time = next_time
							orders_count.next_buy_time = next_time

							temp.ai_buy_count = 0
							orders_count.ai_buy_count = 0
                                        	end
						update_commodity_orders_db(temp)
					end
				end
			end
		end
	end	
end

Scheduler.Register(function(now)
	local beginTime = begin_time(now)
	if now%30 == 0 then
		process_AI_sell3(now)
	end
	if now%60 == 0 then
	        process_AI_buy3(now)
	end
end)

--[[RunThread(function ()
	while true do
		if not AI_is_trade then	
			local now = loop.now()
			local beginTime = begin_time(now)
			if now >= beginTime and now < beginTime + 3600 then	-- 每天8-9点买卖
				process_AI_buy(now)
		
				process_AI_sell(now)
				
				AI_is_trade = true
			end
		end

		Sleep(1)
	end
end)--]]

function TradeOrders.RegisterCommand(service)
	service:on(Command.C_TRADE_QUERY_PLAYER_ORDERS_REQUEST, process_trade_query_player_orders)
	service:on(Command.C_TRADE_SELL_REQUEST, process_trade_sell)
	service:on(Command.C_TRADE_TAKE_BACK_REQUEST, process_trade_take_back)
	service:on(Command.C_TRADE_BUY_REQUEST, process_trade_buy)
	service:on(Command.C_TRADE_QUERY_ORDERS_RANK_REQUEST, process_trade_query_orders_rank)
	service:on(Command.C_TRADE_QUERY_COMMODITY_CONFIG_REQUEST, process_trade_query_commodity_config)
	service:on(Command.C_TRADE_QUERY_TRADEORDERS_REQUEST,process_query_tradeorders)
	service:on(Command.C_TRADE_SET_COMMODITY_CONCERN_REQUEST,process_set_commodity_concern)	
	service:on(Command.C_TRADE_QUERY_COMMODITY_CONCERN_REQUEST,process_query_commodity_concern)
	
--	service:on(Command.C_TRADE_AUTO_BUY_REQUEST,process_auto_buy_vip)	--	自动收购商品的vip特权	
end

return TradeOrders
