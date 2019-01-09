require("database")
package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path  .. ";../lib/?.lua";
local StableTime =require "StableTime"
local get_today_begin_time =StableTime.get_today_begin_time
require "PlayerManager"
--local limit = require "limit"
require "timeControl"
require "timeControlActivityType"
require "consume_condition"
require "printtb"
require "protobuf"
require "NetService"
local BinaryConfig = require "BinaryConfig"

local openlev = require "OpenlevConfig"		-- 功能开启等级配置
local StableTime = require "StableTime"

local function ProtobufDecode(code, protocol)
    return protobuf.decode("com.agame.protocol." .. protocol, code);
end

local function get_quest(pid, type, id)
	local quests, err = cell.QueryPlayerQuestList(pid, { type }, true)
	if not quests then
		log.warning(string.format("query type %d, id %d quest failed.", type, id))
		return nil
	end

	for _, v in ipairs(quests) do
		if v.id == id then
			return v
		end
	end

	return nil
end

local product_price_config 
local function LoadProductPriceConfig()
	local rows = BinaryConfig.Load("config_product_price", "shop")
   	product_price_config = {}	

    for _, row in ipairs(rows) do
        product_price_config[row.gid] = product_price_config[row.gid] or {}
		product_price_config[row.gid][row.number] = {consume_value1 = row.value1, consume_value2 = row.value2}
    end
end

LoadProductPriceConfig()

local function GetProductPrice(gid, buy_count)
	if not product_price_config[gid] then
		return nil
	end

	if not product_price_config[gid][buy_count] then
		local idx = #(product_price_config[gid])
		return product_price_config[gid][idx]
	end

	return product_price_config[gid][buy_count]
end

-- local var --
local g_product_pool ={}
local g_player_buy_history = {}

local function shop_type_is_validate(shop_type)
	return type(shop_type)=='number' and g_product_pool[shop_type] and BuyConfig[shop_type]
end

local function shop_type_is_force_freshable(shop_type)
	return shop_type_is_validate(shop_type) and BuyConfig[shop_type].CanForceFresh
end

local function select_product_list(shop_type, player_info, item_tb, cnt)
	local t_now =os.time()
	local list ={}
	for k,v in pairs(item_tb) do
		if key_visiable(k) and ShopCheckCondition(shop_type, player_info, v, t_now) then
			table.insert(list, v)
		end
	end
	return get_rand_list_by_weight_list(list, cnt)
end

local function make_buy_reason(shop_type)
    if not shop_type or type(shop_type) ~= 'number' then
        return Command.REASON_BUY_MIN;
    else
        return math.min(Command.REASON_BUY_MIN + shop_type, Command.REASON_BUY_MAX);
    end
end

local function make_product_gid(shop_type, product_gid, special_shop)
	-- buy goods by random
	if  BuyConfig[shop_type].CanRandomBuy  then 
		math.randomseed(math.floor(os.time()))
		local ls ={}
		for k, _ in pairs(special_shop) do
			if type(k) == 'number' then
				table.insert(ls, k)
			end
		end
		if #ls > 0 then
			local pos = math.random(#ls)
			return ls[pos]
		else
			yqwarn("special_shop is empty")
			return 0
		end
	end
	return product_gid
end

local function addItemToList(list, item, n)
	for _, v in ipairs(list) do
		if v.type == item.type and v.id == item.id then
			v.value = v.value + item.value * n
			return
		end
	end

	table.insert(list, {type = item.type, id = item.id, value = item.value * n});

	return list
end

local function mergeItem(list1, list2, n)
	n = n or 1

	for _, v in ipairs(list2) do
		addItemToList(list1, v, n);
	end	
	return list1
end


local function make_consume_item(shop_type, product_gid,consume_item, player_buy_count, buy_history, product)
	local calc_consume_item ={ };
	local price_cfg 
	for k, v in ipairs(consume_item) do
		if v.type ~= 0 then
			local n = player_buy_count
			local today_buy_count = product.buy_count--buy_history.today_buy_count
			while n > 0 do
				price_cfg = GetProductPrice(product_gid, today_buy_count + 1)
				if not price_cfg then
					break
				end

				local price = price_cfg["consume_value"..k] > 0 and price_cfg["consume_value"..k] or v.value
				mergeItem(calc_consume_item, {{ type=v.type, id=v.id, value= price}});
				n = n - 1
				today_buy_count = today_buy_count + 1
			end

			if not price_cfg then
				table.insert(calc_consume_item, { type=v.type, id=v.id, value= v.value * player_buy_count });
			end
		end
	end
	
	return calc_consume_item
end

local WELLRNG512a_ = require "WELLRNG512a"
local function WELLRNG512a(seed)
	local rng = WELLRNG512a_.new(seed);
	return setmetatable({rng=rng, c=0}, {__call=function(t) 
			t.c = t.c + 1;
			local v = WELLRNG512a_.value(t.rng);
			return v;
	end})
end

local g_product_item_grow_info = nil;


local function check_min_max(min, max, tips)
	if min > max then
		log.warning(tips, 'error max value');
		min = max
	end

	if min < 0 then
		log.warning(tips, 'error min value')
		min = 0;
		if max < 0 then max = 0; end
	end

	return min, max;
end

local function random_range(rng, min, max)
	assert(min <= max)
	local v  = WELLRNG512a_.value(rng);
	return min + (v % (max - min + 1))
end

local function get_product_grow_rate(shop_id, item_id, grow_id)
	if g_product_item_grow_info == nil then
		g_product_item_grow_info = {}
		local ok, records = database.query("SELECT `grow_id`, `item_id`, `shop_id`, `grow_rating`, `grow_min`, `grow_max`, `down_rating`, `down_min`, `down_max` from product_item_grow_config");
		if not ok then
			return 10000;
		end

		for _, v in ipairs(records) do
			local info = {
				grow = {rate = v.grow_rating, min = v.grow_min, max = v.grow_max},
				down = {rate = v.down_rating, min = v.down_min, max = v.down_max},
			}

			info.grow.min, info.grow.max = check_min_max(info.grow.min, info.grow.max, string.format('product_item_grow_config item_id %d, shop_id %d, grow ', v.item_id, v.shop_id));
			info.down.min, info.down.max = check_min_max(info.down.min, info.down.max, string.format('product_item_down_config item_id %d, shop_id %d, down ', v.item_id, v.shop_id));

			g_product_item_grow_info[v.grow_id] = g_product_item_grow_info[v.grow_id] or {shop_list = {}}
			g_product_item_grow_info[v.grow_id][v.item_id] = g_product_item_grow_info[v.grow_id][v.item_id] or {}
			g_product_item_grow_info[v.grow_id][v.item_id][v.shop_id] = info;

		end
	end

	if g_product_item_grow_info[grow_id] == nil then
		return 10000
	end

	if g_product_item_grow_info[grow_id][item_id] == nil then
		return 10000;
	end

	local item_info = g_product_item_grow_info[grow_id][item_id][shop_id];

	if item_info == nil then
		return 10000
	end

	local period = math.floor(loop.now() / (24 * 3600));

	if not item_info.selected or item_info.selected.period ~= period then
		local seed = period + item_id + shop_id + 38134 + grow_id;

		local rng = WELLRNG512a_.new(seed);

		local grow = 10000;
		if random_range(rng, 1, 10000) <= item_info.grow.rate then
			grow = 	random_range(rng, item_info.grow.min, item_info.grow.max);
		elseif random_range(rng, 1, 10000) <= item_info.down.rate then
			grow = 	random_range(rng, item_info.down.min, item_info.down.max);
		else
			-- print('chose nothing');
		end

		item_info.selected = {grow = grow, period = period};
	end

	return item_info.selected.grow;
end

local g_product_item = nil


local function get_product_item_list(id)
	if g_product_item == nil then
		g_product_item = {}

		local ok, product_item_list = database.query("SELECT `id`, `idx`, `item_type`, `item_id`, `item_count`, `grow_id` from product_item");
		if not ok then
			return nil;
		end
		for _, row in ipairs(product_item_list) do
			g_product_item[row.id] = g_product_item[row.id] or {}
			g_product_item[row.id][row.idx] = {
				idx     = row.idx,
				type    = row.item_type,
				id      = row.item_id,
				value   = row.item_count,
				grow_id = row.grow_id,
			}
		end
	end
	return g_product_item[id];
end

local function select_product_item(id, idx)
	local item_list = get_product_item_list(id)
	return item_list and item_list[idx]
end

local function fresh_product_pool(shop_type)
	local t_now =os.time()
	-- load
	local szFilter =''
	if shop_type then
		szFilter =string.format(" WHERE shop_type=%d", shop_type) 
		g_product_pool[shop_type] =nil
	else
		g_product_pool ={}
	end
	local ok, product_item_list =database.query("SELECT gid, shop_type, vip_min, vip_max, vip_extra, player_lv_min, player_lv_max, product_item_type, product_item_id, product_item_value, consume_item_type, consume_item_id, consume_item_value, consume1_item_type, consume1_item_id, consume1_item_value, unix_timestamp(begin_time) as begin_time, unix_timestamp(end_time) as end_time, is_active, storage, special_flag, original_price, discount, weight, `drop` FROM product" .. szFilter);
	if not ok then
		return nil, 'mysql error'
	end
	for i=1, #product_item_list do
		local product_item =product_item_list[i]
		local shop_type =product_item.shop_type
		local gid =product_item.gid
		g_product_pool[shop_type] =g_product_pool[shop_type] or { }

		if not shop_type_is_validate(shop_type) then
			yqerror("shop_type `%d` is invalidate", shop_type);
			os.exit();
		end
	
		g_product_pool[shop_type]._fresh_period_ =math.floor( (t_now - BuyConfig[shop_type].Offset) / BuyConfig[shop_type].FreshPeriod)
		g_product_pool[shop_type]._count_ =g_product_pool[shop_type]._count_ or 0
		g_product_pool[shop_type]._count_ =g_product_pool[shop_type]._count_ + 1

		g_product_pool[shop_type][gid] =product_item
		product_item.begin_time = tonumber(product_item.begin_time)
		product_item.end_time = tonumber(product_item.end_time)
		product_item.consume_item ={ {type=product_item.consume_item_type, id=product_item.consume_item_id, value=product_item.consume_item_value},{type=product_item.consume1_item_type, id=product_item.consume1_item_id, value=product_item.consume1_item_value} }
		product_item.product_item ={ type=product_item.product_item_type, id=product_item.product_item_id, value=product_item.product_item_value }
		product_item.drop = product_item.drop
		product_item.consume_item_type =nil
		product_item.consume_item_id =nil
		product_item.consume_item_value =nil
		product_item.consume1_item_type =nil
		product_item.consume1_item_id =nil
		product_item.consume1_item_value =nil
		product_item.product_item_type =nil
		product_item.product_item_id =nil
		product_item.product_item_value =nil

		local open_server_time = StableTime.get_open_server_time()

		assert(product_item.begin_time, string.format('product %d begin_time = nil', product_item.gid));

		if product_item.begin_time <= 1000 then
			product_item.begin_time = (product_item.begin_time - 1) * 86400 + StableTime.get_begin_time_of_day(open_server_time)
		end 

		assert(product_item.begin_time, string.format('product %d end_time = nil', product_item.gid));
		if product_item.end_time <= 1000 then
			product_item.end_time = (product_item.end_time - 1) * 86400 + StableTime.get_begin_time_of_day(open_server_time) - 1
		end 
	end
	return true
end

local function get_buy_history(pid, shop_type)
	local buy_history = g_player_buy_history[pid]
	if buy_history == nil then
		buy_history = {}
		g_player_buy_history[pid] =buy_history
	end
	if not buy_history[shop_type] then
		local ok, result = database.query("SELECT today_buy_count, last_buy_time , buy_count , today_fresh_count, last_fresh_time FROM buy_history WHERE shop_type = %d AND pid = %d", shop_type,pid)
		if ok and #result >= 1 then
			local row =result[1]
			buy_history[shop_type] ={today_buy_count =row.today_buy_count, last_buy_time =row.last_buy_time, buy_count = row.buy_count, today_fresh_count = row.today_fresh_count, last_fresh_time = row.last_fresh_time}
		else
			buy_history[shop_type] ={today_buy_count =0, last_buy_time =0, buy_count = 0, today_fresh_count = 0, last_fresh_time = 0}
            database.update("INSERT INTO buy_history(pid,shop_type,today_buy_count, last_buy_time,buy_count,today_fresh_count,last_fresh_time) values(%d,%d,0,0,0,0,0)", pid, shop_type);
		end
	end
	if buy_history[shop_type].last_buy_time < get_today_begin_time() then
		buy_history[shop_type].today_buy_count = 0;
	end
	if buy_history[shop_type].last_fresh_time < get_today_begin_time() then
		buy_history[shop_type].today_fresh_count = 0;
	end
	return buy_history[shop_type]
end

local function force_fresh_special_shop(conn, pid, shop_type, consume)
	-- check
	if not shop_type_is_validate(shop_type) then
		return nil, string.format('shop type `%d` is invalidate', shop_type)
	end
	if not shop_type_is_force_freshable(shop_type) then
		return nil, string.format('shop type `%d` is not support force fresh', shop_type)
	end

	local player_info = PlayerManager.Get(pid, true);
    local buy_history = get_buy_history(pid, shop_type);

    local count_limit = nil;
    if consume and BuyConfig[shop_type].VipFreshLimitCount and BuyConfig[shop_type].VipFreshLimit[player_info.vip] then
        count_limit = BuyConfig[shop_type].VipFreshLimit[player_info.vip];
    elseif consume and BuyConfig[shop_type].VipFreshLimitParams then
        local vipLimit = BuyConfig[shop_type].VipFreshLimitParams;
        count_limit = vipLimit.init + player_info.vip * vipLimit.incr;
    end

    if count_limit and buy_history.today_fresh_count >= count_limit then
        return nil, string.format('`%d` could not fresh shop , max fresh count',pid)
    end

	-- calc fresh_count & fresh_period
	local fresh_count =math.min(g_product_pool[shop_type]._count_, BuyConfig[shop_type].FreshCount)
	local fresh_period =math.floor( (os.time() - BuyConfig[shop_type].Offset) / BuyConfig[shop_type].FreshPeriod)

	-- try fresh global shop
	local global_shop =g_product_pool[shop_type]
	if global_shop._fresh_period_ < fresh_period then
		if not fresh_product_pool(shop_type) then
			return nil, string.format("fail to fresh product pool `%d`", shop_type)
		end
	end

	-- consume
	if consume and BuyConfig[shop_type].ForceFreshConsume then
		if not consume[1] or not consume[2] or not consume[3] then
			return nil, 'invalidate consume item'
		end
		client_send_consume_item ={type =consume[1], id=consume[2], value =consume[3]}
		if not client_send_consume_item.type or not client_send_consume_item.id or not client_send_consume_item.value then
			return nil, 'invalidate client send consume item'
		end
		local consume_item
		for i=1,#(BuyConfig[shop_type].ForceFreshConsume) do
			local item =BuyConfig[shop_type].ForceFreshConsume[i]
			if item.Type==client_send_consume_item.type and item.Id==client_send_consume_item.id then
				consume_item ={
					{
						type =item.Type,
						id =item.Id,
						value =item.Value
					}
				}
				break
			end
		end
		if not consume_item then
			return nil, 'consume item is invalidate'
		end

		-- check consume
		local ok =conn:exchange(pid, consume_item, {}, Command.REASON_FRESH_MYSTICAL_SHOP)
		if not ok then
			return nil, 'cell error'
        else
            buy_history.today_fresh_count = buy_history.today_fresh_count + 1
            buy_history.last_fresh_time   = os.time();
            database.update("UPDATE buy_history SET today_fresh_count = %d ,last_fresh_time = %d WHERE pid = %d AND shop_type= %d", 
                    buy_history.today_fresh_count,
                    buy_history.last_fresh_time,
                    pid,
                    shop_type);
        end
	end
	
	-- delete cache
	if not database.update("DELETE FROM player_shop WHERE pid=%d AND shop_type=%d AND fresh_period=%d", pid, shop_type, fresh_period) then
		return nil, 'mysql error'
	end
	get_player_cache(pid).buy[shop_type] =nil

	-- get player info
	local cell_res =cell.getPlayer(pid)
	local player_info =cell_res and cell_res.player
	if not player_info then
		return nil, string.format('`%d` is not a validate player id', pid)
	end

	--select
	local product_item_tb =g_product_pool[shop_type]
	local selected_item =select_product_list(shop_type, player_info, product_item_tb, BuyConfig[shop_type].FreshCount)

	-- save to cache & sql
	if #selected_item > 0 then
		local special_shop ={ _fresh_period_ =fresh_period }
		local szValues =''
		for i=1, #selected_item do
			if #szValues>0 then
				szValues =szValues .. ","
			end
			szValues =szValues .. string.format("(%d,%d,%d,%d,0)", pid, shop_type, fresh_period, selected_item[i].gid)
			special_shop[selected_item[i].gid] ={product =selected_item[i], buy_count =0}
		end
		get_player_cache(pid).buy[shop_type] =special_shop
		if #szValues>0 then
			if not database.update("INSERT INTO player_shop(pid, shop_type, fresh_period, product_id, buy_count)VALUES%s", szValues) then
				get_player_cache(pid).buy[shop_type] =nil
				return nil, 'mysql error'
			end
		end
	else
		get_player_cache(pid).buy[shop_type] =nil
		return nil, "select_product_list return empty array"
	end
	return true
end

local function get_special_shop(pid, shop_type)
	if not shop_type_is_validate(shop_type) then
		return nil, string.format('shop type `%d` is invalidate', shop_type or -1)
	end
	local t_now =os.time()
	-- check time limit
	--if not(BuyConfig[shop_type].BeginTime==0 or (t_now>=BuyConfig[shop_type].BeginTime and t_now<=BuyConfig[shop_type].EndTime)) then
	local time_control = timeControl.Get(timeControlActivityType.TYPE_SHOP)
	if not time_control:onTime(shop_type) then
		yqinfo("get_special_shop fail, Closing time")
		return nil, 'Closing Time'
	end

	-- get player info
	local cell_res =cell.getPlayer(pid)
	local player_info =cell_res and cell_res.player
	if not player_info then
		return nil, string.format('`%d` is not a validate player id', pid)
	end

	-- try fresh global shop
	local global_shop =g_product_pool[shop_type]
	local fresh_count =math.min(g_product_pool[shop_type]._count_, BuyConfig[shop_type].FreshCount)
	local fresh_period =math.floor( (t_now -  BuyConfig[shop_type].Offset) / BuyConfig[shop_type].FreshPeriod)
	if global_shop._fresh_period_ < fresh_period then
		if not fresh_product_pool(shop_type) then
			return nil, string.format("fail to fresh product pool `%d`", shop_type)
		end
	end

	-- prepare special shop cache
	local special_shop =get_player_cache(pid).buy[shop_type]
	if  BuyConfig[shop_type].FreshCount == 0 then
		local all_item_info = g_product_pool[shop_type]
		if not special_shop then
			special_shop ={ _fresh_period_ =fresh_period }
			
			local q_ok, result =database.query("SELECT product_id,buy_count FROM player_shop WHERE pid=%d AND shop_type=%d AND fresh_period=%d", pid, shop_type, fresh_period)
			if not q_ok then
				log.info(pid,"get_special_shop query buy_count from player_shop failed as FreshCount=0")
				return nil, 'mysql error'
			end

			for i=1, #result do
				if all_item_info[result[i].product_id] then
					special_shop[result[i].product_id] = {buy_count = result[i].buy_count, db_exist = 1}
				end
           	end

			for k, product in pairs(all_item_info) do	
				local origin_buy_count = 0
				local origin_db_exist = 0
				if type(k) == "number" and ShopCheckCondition(shop_type, player_info, product, t_now) then
					if special_shop[k] ~= nil then
						origin_buy_count = special_shop[k].buy_count
						origin_db_exist  = special_shop[k].db_exist
					end
					special_shop[k] = {product = all_item_info[k], buy_count = origin_buy_count, db_exist = origin_db_exist}
					assert(all_item_info[k], k .. "  not exists");
				end
            end
			get_player_cache(pid).buy[shop_type] =special_shop
		end

		if special_shop._fresh_period_ < fresh_period then
			special_shop ={ _fresh_period_ =fresh_period }
			for k, product in pairs(all_item_info) do
                if type(k) == "number" and ShopCheckCondition(shop_type, player_info, product, t_now)  then
					special_shop[k] = {product = all_item_info[k], buy_count = 0, db_exist = 0 }
					assert(all_item_info[k], k .. "  not exists");
				end
			end
			get_player_cache(pid).buy[shop_type] =special_shop	
		end

		return special_shop, fresh_period
	end	

	if not special_shop then
		-- get data
		local ok, result =database.query("SELECT product_id, buy_count FROM player_shop WHERE pid=%d AND shop_type=%d AND fresh_period=%d", pid, shop_type, fresh_period)	
		if not ok then
			return nil, 'mysql error'
		end
		if #result>0 then
			special_shop ={ _fresh_period_ =fresh_period }
			for i=1, #result do
				local result_item =result[i]
				local product_item =g_product_pool[shop_type][result_item.product_id]
				if product_item then
					special_shop[result_item.product_id] ={product =product_item, buy_count =result_item.buy_count}
				else
					return nil, string.format('product `%d` is not exists.', result_item.product_id)
				end
			end
			get_player_cache(pid).buy[shop_type] =special_shop
		end
	end

	--try generate 
	if not special_shop or special_shop._fresh_period_ < fresh_period then
		--select
		local product_item_tb =g_product_pool[shop_type]
		local selected_item =select_product_list(shop_type, player_info, product_item_tb, fresh_count)
		-- save to cache & sql
		special_shop ={ _fresh_period_ =fresh_period }
		local szValues =''
		for i=1, #selected_item do
			if #szValues>0 then
				szValues =szValues .. ","
			end
			szValues =szValues .. string.format("(%d,%d,%d,%d,0)", pid, shop_type, fresh_period, selected_item[i].gid)
			special_shop[selected_item[i].gid] ={product =selected_item[i], buy_count =0}
		end
		get_player_cache(pid).buy[shop_type] =special_shop
		if #szValues>0 then
			local ok =database.update("INSERT INTO player_shop(pid, shop_type, fresh_period, product_id, buy_count)VALUES%s", szValues)
			if not ok then
				get_player_cache(pid).buy[shop_type] =nil
				return nil, 'mysql error'
			end
		end
	end
	return special_shop, fresh_period
end

-- init pool --
fresh_product_pool();

local function make_fresh_consume_amf(freshConsume)
	freshConsume = freshConsume or {} 
	local amf_fresh_consume = {}
	for i=1,#freshConsume do
		local item = freshConsume[i]
		amf_fresh_consume ={
			{
				item.Type,
				item.Id,
				item.Value
			}
		}
		break
	end
	return amf_fresh_consume
end

local function build_product_item_select_list(shop_id, product)
	local item_list = nil
	if product.product_item.type == 80 then
		item_list = {}
		local list = get_product_item_list(product.product_item.id)
		for _, v in pairs(list or {}) do
			local grow = get_product_grow_rate(shop_id, v.id, v.grow_id);
			table.insert(item_list, {v.idx, v.type, v.id, v.value, grow});
		end
	end
	return item_list
end

-- process request --
function process_fresh_special_shop(conn, pid, req)
	-- check
	local shop_type=req[2]
	if not shop_type_is_validate(shop_type) then
		yqerror("`%d` fail to FRESH_SPECIAL_SHOP, invalid request argument,the 3th arg must be a validate `shop_type`.", pid)
		conn:sendClientRespond(Command.S_FRESH_SPECIAL_SHOP, pid, {req[1], Command.RET_ERROR})
		return
	end

	-- fresh
	local client_send_consume_item ={req[3], req[4], req[5]}
	local ok, szErrMsg =force_fresh_special_shop(conn, pid, shop_type, client_send_consume_item)
	if not ok then
		yqerror("`%d` fail to FRESH_SPECIAL_SHOP `%d`, %s", pid, shop_type, szErrMsg)
		conn:sendClientRespond(Command.S_FRESH_SPECIAL_SHOP, pid, {req[1], Command.RET_ERROR})
		return
	end
	-- get special shop
	local special_shop, fresh_period =get_special_shop(pid, shop_type)
	if not special_shop then
		local szErrMsg =fresh_period
		yqerror("`%d` fail to FRESH_SPECIAL_SHOP `%d`, %s", pid, shop_type, szErrMsg)
		conn:sendClientRespond(Command.S_FRESH_SPECIAL_SHOP, pid, {req[1], Command.RET_ERROR})
		return
	end
	local next_fresh_time =(fresh_period + 1) * BuyConfig[shop_type].FreshPeriod + BuyConfig[shop_type].Offset;
    yqinfo("the next_fresh_time is `%d`", next_fresh_time);

	-- response
	local product_item_list ={}
	for k,v in pairs(special_shop) do
		if type(k)=='number' then
			local p =v.product
			table.insert(product_item_list, {
				p.gid, 
				p.product_item.type, 
				p.product_item.id, 
				p.product_item.value, 
				p.consume_item[1].type, 
				p.consume_item[1].id,
				p.consume_item[1].value, 
				p.consume_item[2].type,
				p.consume_item[2].id,
				p.consume_item[2].value,
				p.storage,
				p.special_flag, 
				p.original_price, 
				p.discount, 
				v.buy_count,
				p.vip_extra,
				{p.vip_min, p.vip_max, p.begin_time, p.end_time, p.player_lv_min, p.player_lv_max},
				build_product_item_select_list(shop_type, p),
			}) 
		end
	end
	yqinfo("`%d` FRESH_SPECIAL_SHOP `%d`", pid, shop_type)
	local cd =next_fresh_time - os.time()
	--cell.disPatchQuestEvent(pid, 26, 1)

	--quest
	cell.NotifyQuestEvent(pid, {{type = 47, id = shop_type, count = 1}})
	conn:sendClientRespond(Command.S_FRESH_SPECIAL_SHOP, pid, {req[1], Command.RET_SUCCESS, next_fresh_time, shop_type_is_force_freshable(shop_type) and 1 or 0, product_item_list, make_fresh_consume_amf(BuyConfig[shop_type].ForceFreshConsume)})--cd, product_item_list})
end

function process_get_special_shop(conn, pid, req)
	-- check
	local shop_type=req[2]
	if not shop_type_is_validate(shop_type) then
		local shop_type_str =shop_type and tostring(shop_type) or ''
		yqerror("`%d` fail to GET_SPECIAL_SHOP, invalid request argument,the 3th arg must be a validate shop_type `%s`.", pid, shop_type_str)
		conn:sendClientRespond(Command.S_GET_SPECIAL_SHOP, pid, {req[1], Command.RET_ERROR})
		return
	end

	-- get special shop
	local special_shop, fresh_period =get_special_shop(pid, shop_type)
	if not special_shop then
		local szErrMsg =fresh_period
		yqerror("`%d` fail to GET_SPECIAL_SHOP `%d`, %s", pid, shop_type, szErrMsg)
		conn:sendClientRespond(Command.S_GET_SPECIAL_SHOP, pid, {req[1], Command.RET_ERROR})
		return
	end
	local next_fresh_time =(fresh_period + 1) * BuyConfig[shop_type].FreshPeriod + BuyConfig[shop_type].Offset
    yqinfo("the next_fresh_time is %d",next_fresh_time);

	-- response
	local product_item_list ={}
	for k,v in pairs(special_shop) do
		if type(k)=='number' then
			local p =v.product
			if p.gid == 1020001 then
				print("buy_count >>>>>>>>>>>>>", v.buy_count)
			end
			table.insert(product_item_list, {p.gid, 
				p.product_item.type, 
				p.product_item.id, 
				p.product_item.value, 
				p.consume_item[1].type, 
				p.consume_item[1].id, 
				p.consume_item[1].value,
				p.consume_item[2].type,
				p.consume_item[2].id,
				p.consume_item[2].value, 
				p.storage, 
				p.special_flag, 
				p.original_price, 
				p.discount, 
				v.buy_count,
				p.vip_extra,
				{p.vip_min, p.vip_max, p.begin_time, p.end_time, p.player_lv_min, p.player_lv_max} ,
				build_product_item_select_list(shop_type, p),
			}) 
		end
	end

	yqinfo("`%d` GET_SPECIAL_SHOP `%d`", pid, shop_type)
	local cd =next_fresh_time - os.time()
	conn:sendClientRespond(Command.S_GET_SPECIAL_SHOP, pid, {req[1], Command.RET_SUCCESS, next_fresh_time, shop_type_is_force_freshable(shop_type) and 1 or 0, product_item_list, make_fresh_consume_amf(BuyConfig[shop_type].ForceFreshConsume)})--, cd, product_item_list})
end

function process_buy(conn, pid, req)
	-- check
	local product_gid = req[2]
	local shop_type   = req[3]
	local player_buy_count = req[4] or 1

    log.debug("process_buy", pid, shop_type, product_gid, player_buy_count);

	local param = req[5] or {}; 
	if type(req[5]) == "number" then -- old protocol style
		param = { consume_uuid = {} }
		for k = 5, #req do
			param.consume_uuid[k-4] = req[k];
		end
	elseif type(req[5]) == 'string' then
		param = ProtobufDecode(req[5] or "", 'ShopBuyParam');
	end

	param.consume_uuid  = param.consume_uuid  or {}
	param.guild         = param.guild         or {type = 0, level = 0}
	param.product_index = param.product_index or 0
	param.hero_uuid     = param.hero_uuid     or 0;

	-- check base para
	if not product_gid then
		yqerror("`%d` fail to BUY, invalid request argument,the 2th arg must be a validate `product gid`.", pid)
		conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
		return
	end

	if not shop_type_is_validate(shop_type) then
		yqerror("`%d` fail to BUY `%d`, Invalid request argument,the 3th arg is not a validate `shop_type(%f)`.", pid, product_gid, shop_type or 1.1)
		conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
		return
	end

	if type(player_buy_count) ~= 'number' or player_buy_count <= 0 then
		yqerror("`%d` fail to BUY `%d`,count not correct.", pid, product_gid)
		conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
		return
	end	

    local player_info = PlayerManager.Get(pid, true);

	--limit shop 
	local now=loop.now()
	--if shop_type == SHOP_TYPE_LIMITED and (now < BuyConfig[shop_type].BeginTime or now > BuyConfig[shop_type].EndTime) then
	local time_control = timeControl.Get(timeControlActivityType.TYPE_SHOP)
	if not time_control:onTime(shop_type) then
		yqerror("fail to buy in %d shop ,closing time",shop_type)
		conn:sendClientRespond(Command.S_BUY,pid,{req[1],Command.RET_ERROR})
		return 
	end

	-- get player special shop
	local special_shop, fresh_period =get_special_shop(pid, shop_type)
	if not special_shop then
		local szErrMsg =fresh_period
		yqerror("`%d` fail to BUY `%d`, %s.", pid, product_gid, szErrMsg)
		conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
		return
	end

	--if the shop is random shop, should give player random product_gid
	product_gid = make_product_gid(shop_type, product_gid, special_shop)
	local product =special_shop[product_gid]
	if not product then
		yqerror("`%d` fail to BUY `%d`, not exists.", pid, product_gid)
		conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
		return
	end

	-- check storage
	local storage =g_product_pool[shop_type][product_gid].storage
	if 0 ~= storage  then
		if player_info.level < product.product.player_lv_min or player_info.level > product.product.player_lv_max then
			yqerror("`%d` fail to BUY `%d`, level %d ( %d - %d).", pid, product_gid, player_info.level, product.product.player_lv_min, product.product.player_lv_max);
			conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
			return
		end

		storage = storage + g_product_pool[shop_type][product_gid].vip_extra * player_info.vip;
		if product.buy_count>=storage or player_buy_count>storage or product.buy_count+player_buy_count>storage then
			yqerror("`%d` fail to BUY `%d`, not enough.  storage %d", pid, product_gid, storage)
			conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
			return
		end
	end

	-- check guild build level
	if not ProductItemCanBuy(shop_type, product_gid, pid, param.guild.type, param.guild.level) then
		yqerror("`%d` fail to BUY `%d`, cannot buy.", pid, product_gid)
		conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
		return
	end

	local tmp =product.product.consume_item
	tmp = GetConsumeByShopType(shop_type, product_gid, tmp, pid, param.guild.type, param.guild.level)
	if not tmp then
		yqerror("`%d` fail to BUY `%d`, get consume fail", pid, product_gid)
		conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
		return 
	end

    -- make consume
	local buy_history = get_buy_history(pid, shop_type);
	local consume_item = make_consume_item(shop_type,product_gid,tmp,player_buy_count, buy_history,product);
	for k, v in ipairs(consume_item) do
		v.uuid = param.consume_uuid[i];
	end

	-- make reward
	local t_product_item ={ type =product.product.product_item.type, id =product.product.product_item.id, value =product.product.product_item.value*player_buy_count }
	if t_product_item.type == 80 then
		-- select from product item list
		local real_item = select_product_item(t_product_item.id, param.product_index)
		if not real_item then
			yqerror("`%d` fail to BUY `%d`, select index %d not exists.", pid, product_gid, param.product_index)
			return conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
		end

		local grow  = get_product_grow_rate(shop_type, real_item.id, real_item.grow_id);
		local value = math.floor(t_product_item.value * (real_item.value / 10000) * (grow / 10000));
		t_product_item = {type = real_item.type, id = real_item.id, value = value}
	end

	if t_product_item.type == 90 then
		-- hero item need hero uuid
		if param.hero_uuid == 0 then
			yqerror("`%d` fail to BUY `%d`, need hero uuid.", pid, product_gid)
			return conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
		end
		t_product_item.uuids = {param.hero_uuid}
	end

	local reward_item ={}
	if t_product_item.type ~= 0 and t_product_item.id ~= 0 then
		if t_product_item.value > 2000000000 or t_product_item.value < 0 then
			yqerror("`%d` fail to BUY `%d`, too bigger value 2000000000 or too small.", pid, product_gid)
			conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
			return
		end
		reward_item ={ t_product_item }
    end 

	local ok, errno=conn:exchange(pid, consume_item, reward_item, make_buy_reason(shop_type));

	
	local quest = get_quest(pid, 10, 101091)
	if quest and quest.status == 1 then
		-- 如果是角色，则通知客户端
		for _, item in ipairs(reward_item) do
			if item.type == 42 then
				NetService.NotifyClients(Command.NOTIFY_DISPLAY_MESSAGE, { 5, player_info.name, item.id, item.value })
			end
		end
	end
	
	-- drop
	local cell_res = cell.getPlayer(pid)
	local player_info =cell_res and cell_res.player
	local drop
	if player_info then
		if product.product.drop ~= 0 then 
			drop = {{id = product.product.drop, level = player_info.level}}
		end
	end

	if ok then
		local drop_rewards = {}
		if drop then
			local rewards = cell.sendDropReward(pid, drop, make_buy_reason(shop_type))
			for k, v in ipairs(rewards) do
				table.insert(drop_rewards, {v.type, v.id, v.value, v.uuid})
			end	
		end

		if BuyConfig[shop_type].FreshCount == 0  then
			product.buy_count =product.buy_count + player_buy_count
			if product.db_exist == 0 then
				if not database.update("INSERT INTO player_shop(pid, shop_type, fresh_period, product_id, buy_count)VALUES(%d,%d,%d,%d,%d)", pid, shop_type, fresh_period, product_gid, product.buy_count) then
					yqerror("`%d` BUY insert `%d`, mysql error", pid, product_gid)
					conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
                                        return nil, 'mysql error'
 				end
					get_player_cache(pid).buy[shop_type][product_gid].db_exist = 1
			else
				if not database.update("UPDATE player_shop SET buy_count=%d WHERE pid=%d AND fresh_period=%d AND product_id=%d", product.buy_count, pid, fresh_period, product_gid) then
	                        	yqerror("`%d` BUY update `%d`, mysql error", pid, product_gid)
        	                	conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
                	        	return nil, 'mysql error'
               			end
			end

			--quest
			cell.NotifyQuestEvent(pid, {{type = 32, id = shop_type, count = 1}})
			cell.NotifyQuestEvent(pid, {{type = 32, id = product_gid, count = 1}})

			yqinfo("`%d` BUY `%d`.", pid, product_gid)
            conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_SUCCESS, drop_rewards})--,product_gid,buy_history and  buy_history.today_buy_count or 0})
			return
			
			
		end
			
		product.buy_count =product.buy_count + player_buy_count
		if not database.update("UPDATE player_shop SET buy_count=%d WHERE pid=%d AND fresh_period=%d AND product_id=%d", product.buy_count, pid, fresh_period, product_gid) then
			yqerror("`%d` BUY `%d`, mysql error", pid, product_gid)
			conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_ERROR})
			return	
		end
		
		--quest
		cell.NotifyQuestEvent(pid, {{type = 32, id = shop_type, count = 1}})
		cell.NotifyQuestEvent(pid, {{type = 32, id = product_gid, count = 1}})
	
		yqinfo("`%d` BUY `%d`.", pid, product_gid)
		conn:sendClientRespond(Command.S_BUY, pid, {req[1], Command.RET_SUCCESS, drop_rewards})--,product_gid,buy_history and  buy_history.today_buy_count or 0})
	else
		yqerror("`%d` fail to BUY `%d`, cell error.", pid, product_gid)
		conn:sendClientRespond(Command.S_BUY, pid, {req[1], errno});
	end
end

function process_get_buy_history(conn, pid, req)
	yqinfo("Begin: C_GET_BUY_HISTORY")
	local shop_type=req[2]
	if not shop_type_is_validate(shop_type) then
		yqerror("`%d` fail to get buy histroy, shop_type is not vailed type `%d`",pid,shop_type or -1)
		conn:sendClientRespond(Command.S_GET_BUY_HISTORY, pid, {req[1], Command.RET_ERROR})
		return
	end
	local pid_history = get_buy_history(pid, shop_type)
	local histroy = {pid_history.today_buy_count, pid_history.last_buy_time, pid_history.buy_count, pid_history.today_fresh_count}
	if histroy then 
		conn:sendClientRespond(Command.S_GET_BUY_HISTORY, pid, {req[1],Command.RET_SUCCESS, unpack(histroy)})
		yqinfo("`%d` success to S_GET_BUY_HISTORY", pid or -1)
	else
		conn:sendClientRespond(Command.S_GET_BUY_HISTORY, pid, {req[1], Command.RET_ERROR})
		yqwarn("`%d` failed to S_GET_BUY_HISTORY", pid or -1)
	end


end

function process_get_buy_history(conn, pid, req)
	yqinfo("Begin: C_GET_BUY_HISTORY")
	local shop_type=req[2]
	if not shop_type_is_validate(shop_type) then
		yqerror("`%d` fail to get buy histroy, shop_type is not vailed type `%d`",pid,shop_type or -1)
		conn:sendClientRespond(Command.S_GET_BUY_HISTORY, pid, {req[1], Command.RET_ERROR})
		return
	end
	local pid_history = get_buy_history(pid, shop_type)
	local histroy = {pid_history.today_buy_count, pid_history.last_buy_time, pid_history.buy_count, pid_history.today_fresh_count}
	if histroy then 
		conn:sendClientRespond(Command.S_GET_BUY_HISTORY, pid, {req[1],Command.RET_SUCCESS, unpack(histroy)})
		yqinfo("`%d` success to S_GET_BUY_HISTORY", pid or -1)
	else
		conn:sendClientRespond(Command.S_GET_BUY_HISTORY, pid, {req[1], Command.RET_ERROR})
		yqwarn("`%d` failed to S_GET_BUY_HISTORY", pid or -1)
	end
end

function process_get_valid_time(conn, pid, req)
	yqinfo("Begin get valid time")
	local activity_type = req[2]
	local activity_id = req[3]
	if not activity_type then
		yqinfo("fail to get valid time, arg 2nd activity_type is nil")
		conn:sendClientRespond(Command.S_GET_VALID_TIME, pid, {req[1], Command.RET_ERROR})
	end

	-- 增加功能开启判断
	--[[if not openlev.isLvOK(pid, 2401) then	
		yqinfo("fail to get valid time, player level not enough.")
		conn:sendClientRespond(Command.S_GET_VALID_TIME, pid, {req[1], Command.RET_ERROR})
	end--]]

	local time_control = timeControl.Get(activity_type)
	local time_tb = time_control:getTime(activity_id)
	
	local amf_array = {}
	local now = loop.now()
	if not activity_id then
		for id,tb in pairs(time_tb or {}) do
			for k, v in ipairs(tb) do
				if now >= v.begin_time and now <= v.end_time then
					local temp = {
						v.begin_time,
						v.end_time,
						v.duration_per_period,
						v.valid_time_per_period,
						id,	
					}
					table.insert(amf_array, temp)
				end
			end 
		end
	else
		for k, v in ipairs(time_tb or {}) do
			if now >= v.begin_time and now <= v.end_time then
				local temp = {
					v.begin_time,
					v.end_time,
					v.duration_per_period,
					v.valid_time_per_period,
					activity_id,
				}
				table.insert(amf_array, temp)
			end
		end
	end	
	conn:sendClientRespond(Command.S_GET_VALID_TIME, pid, {req[1], Command.RET_SUCCESS, amf_array})
end

function process_buy_for_guild_shop(conn, pid, req)
	local param = { guild = {type = req[5], level = req[6];} }
	req[5] = param
	return process_buy(conn, pid, req);
end

function process_buy_for_hero_item(conn, pid, req)
    log.debug("process_buy_for_hero_item", pid, unpack(req));
	local param = { hero_uuid = req[6][1] , consume_uuid = req[5]};
	req[5] = param
	return process_buy(conn, pid, req);
end

-- for shop_id = 1001, 1005 do print('!!!!!!!!!!', shop_id, get_product_grow_rate(shop_id, 1411000, 1)); end
