require("database")
--require "YQSTR"
require "PlayerManager"
--require "util"
--require "aiserver"
require "SocialManager"

local get_today_begin_time =StableTime.get_today_begin_time

--local make_player_rich_text =util.make_player_rich_text;

-- local var
-- local broadcast =require "broadcast"
local g_gift_bag ={}
local g_player_open_history = {}

-- on load
(function()
	local ok, gift_item_list =database.query("SELECT gid, item_type, item_id, item_value, drop_id, is_consume,lucky_count,weight,item_name,  need_broadcast, unix_timestamp(begin_time) as begin_time, unix_timestamp(end_time) as end_time, `group` FROM gift_bag");
	yqassert(ok, "Fail to load gift item list.")
	for i=1, #gift_item_list do
		local gift_item =gift_item_list[i]
		local gid =gift_item.gid
		local lc =gift_item.lucky_count
		local tmp ={
			type =gift_item.item_type,
			id =gift_item.item_id,
			value =gift_item.item_value,
			drop = gift_item.drop_id,
			weight =gift_item.weight,
			name = gift_item.item_name,
			need_broadcast = gift_item.need_broadcast,
            begin_time = tonumber(gift_item.begin_time),
            end_time = tonumber(gift_item.end_time),
			group = gift_item.group
		}

        if tmp.end_time == 0 then
            tmp.end_time = 1602302400;
        end

		g_gift_bag[gid] =g_gift_bag[gid] or {}
		g_gift_bag[gid][lc] =g_gift_bag[gid][lc] or { consume_item={}, reward_item={} }
		if lc~=0 then
			g_gift_bag[gid]._enable_lucky_count_ =true
		end
		if 1==gift_item.is_consume then
			table.insert(g_gift_bag[gid][lc].consume_item, tmp)
		else
			table.insert(g_gift_bag[gid][lc].reward_item, tmp)
		end
	end
end)();
--printtb(g_gift_bag)
function load_open_gift_bag_history(pid)
	g_player_open_history[pid] ={}
	local ok, history_list=database.query("SELECT pid, gid, `count`, today_count, unix_timestamp(today_time) as today_time FROM open_gift_bag_history WHERE pid=%d", pid);
	yqassert(ok, "Fail to load open gift bag history list.")
	for i=1, #history_list do
		local history =history_list[i]

		g_player_open_history[pid][history.gid] ={ 
            count = history.count ,
            today_count = history.today_count,
            today_time  = tonumber(history.today_time),
        }
	end	
end
function unload_open_gift_bag_history(pid)
	g_player_open_history[pid] =nil
end
function try_load_open_gift_bag_history(pid)
	if not g_player_open_history[pid] then
		load_open_gift_bag_history(pid)
	end
end

local function get_gift_bag_open_count(pid, gid)
    if g_player_open_history[pid] == nil then
        load_open_gift_bag_history(pid)
    end

    local history = g_player_open_history[pid][gid];
    if history and history.today_time >= get_today_begin_time() then
        return history.count, history.today_count;
    end

    return history and history.count or 0, 0;
end

local function set_gift_bag_open_count(pid, gid, count, today_count)
    if g_player_open_history[pid] == nil then
        load_open_gift_bag_history(pid)
    end

    local history = g_player_open_history[pid][gid];
    if history == nil then
         history = {
             count = count,
             today_count = today_count,
             today_time = loop.now(),
         }
         g_player_open_history[pid][gid] = history;
    else
        history.count = count;
        history.today_time = loop.now();
        history.today_count = today_count;
    end

    database.update(string.format("REPLACE INTO open_gift_bag_history(pid, gid, `count`, today_count, today_time)VALUES(%d, %d, %d, %d, from_unixtime_s(%d))", 
        pid, gid, count, today_count, loop.now()))
end

-- process request
function process_get_open_gift_bag_history(conn, pid, req)
	-- arg
	local gift_gid =req[2]

	-- try load
	try_load_open_gift_bag_history(pid)	

	-- respond
	if gift_gid and type(gift_gid)=='number' then
        local open_count, today_count = get_gift_bag_open_count(pid, gift_gid);
        log.debug(string.format("process_get_open_gift_bag_history %d, %d, %d", gift_gid, open_count, today_count));
		conn:sendClientRespond(Command.S_GET_OPEN_GIFT_BAG_HISTORY, pid, {req[1], Command.RET_SUCCESS, {{gift_gid, open_count, today_count}}})
	else
		local item_list ={}
		local history =g_player_open_history[pid]
		for k, v in pairs(history) do
			table.insert(item_list, {k, v.count})
		end
		conn:sendClientRespond(Command.S_GET_OPEN_GIFT_BAG_HISTORY, pid, {req[1], Command.RET_SUCCESS, item_list})
	end
	yqinfo("`%d` success in S_GET_OPEN_GIFT_BAG_HISTORY", pid)
end
function process_get_gift_bag(conn, pid, req)
	-- check
	local gift_gid =req[2]
	if not gift_gid then
		yqerror("`%d` fail to GET_GIFT_BAG, invalid request argument,the 2th arg must be a validate `gift gid`.", pid)
		conn:sendClientRespond(Command.S_GET_GIFT_BAG, pid, {req[1], Command.RET_ERROR})
		return
	end

	-- prepare consume item & reward item
	local gift_item =g_gift_bag[gift_gid]
	if not gift_item then
		yqerror("`%d` fail to GET_GIFT_BAG, gift `%d` is not exists.", pid, gift_gid)
		conn:sendClientRespond(Command.S_GET_GIFT_BAG, pid, {req[1], Command.RET_ERROR})
		return
	end
	local results ={}
	for k, v in pairs(gift_item) do
		if type(k) == "number" then
			local consume_item ={}
			for i=1, #gift_item[k].consume_item do
				local item =gift_item[k].consume_item[i]
				table.insert(consume_item, {item.type,item.id,item.value})
			end
			local reward_item ={}
			for i=1, #gift_item[k].reward_item do
				local item =gift_item[k].reward_item[i]
				table.insert(reward_item, {item.type,item.id,item.value})
			end
			table.insert(results, {k, consume_item, reward_item})
		end
	end

	-- response
	yqinfo("`%d` GET_GIFT_BAG `%d`.", pid, gift_gid)
	conn:sendClientRespond(Command.S_GET_GIFT_BAG, pid, {req[1], Command.RET_SUCCESS, results})
end

function get_item_client_name(v)
	return "#[type=goods,gid="..(v.id)..",gtype="..(v.type).."]#[end]";
end

function get_gift_bag_consume_name(item)
	for k, v in pairs(item) do	
		if v.need_broadcast == 1 then
			return true, get_item_client_name(v); 
		end
	end
	return false, '';
end

function get_gift_bag_reward_name(item)
	local t_name;
	for k, v in pairs(item) do
		if v.need_broadcast == 1 then
			if not t_name then
				t_name = get_item_client_name(v); 
			else
				t_name = t_name .. '、' .. get_item_client_name(v); 
			end
		end
	end
	if not t_name then
		return false, '';
	else
		return true, t_name;
	end
end

function process_open_gift_bag(conn, pid, req)
	-- check
	yqinfo("Begin to process_open_gfit_bag pid:%d",pid)
	local gift_gid =req[2]
	local value=req[3] or 1
	log.info(string.format("count of open gift_bag is %d ",value));
	if not gift_gid then
		yqerror("`%d` fail to OPEN_GIFT_BAG, invalid request argument,the 2th arg must be a validate `gift gid`.", pid)
		conn:sendClientRespond(Command.S_OPEN_GIFT_BAG, pid, {req[1], Command.RET_ERROR})
		return
	end
	if not g_gift_bag[gift_gid] then
		yqerror("`%d` fail to OPEN_GIFT_BAG, gift `%d` is not exists.", pid, gift_gid)
		conn:sendClientRespond(Command.S_OPEN_GIFT_BAG, pid, {req[1], Command.RET_ERROR})
		return
	end
	if g_player_open_history[pid] == nil then
		load_open_gift_bag_history(pid)
	end

	-- prepare consume item & reward item
    local open_count, today_count  = get_gift_bag_open_count(pid, gift_gid);
    --[[if gift_gid == 420103 or gift_gid == 420104 then
        local player = PlayerManager.Get(pid, true);
        local vip_limit = 10 + player.vip * 10;
        if today_count + value > vip_limit then
            yqerror("`%d` fail to OPEN_GIFT_BAG %d, vip limit %d+%d > %d.", pid, gift_gid, today_count, value, vip_limit)
            conn:sendClientRespond(Command.S_OPEN_GIFT_BAG, pid, {req[1], Command.RET_VIP_LEVEL_LIMIT})
        end
    end]]

	local reward_item={}
	local reward_drops = {}
	--local consume_item =gift_item.consume_item
	local gift_itme={}
	local consume_items={}
    local now = loop.now();
	for i=1,value do 
		if g_gift_bag[gift_gid]._enable_lucky_count_ then
			open_count  = open_count + 1;
            today_count = today_count + 1;
		end
		yqdebug(string.format("gid=%d ,open_count=%d ",gift_gid,open_count))
		gift_item=g_gift_bag[gift_gid][open_count];
		if gift_item then
			open_count=0
        else
			gift_item=g_gift_bag[gift_gid][0]
		end

		if not gift_item then
			yqerror("`%d` fail to OPEN_GIFT_BAG, gift `%d` is not exists.", pid, gift_gid)
			conn:sendClientRespond(Command.S_OPEN_GIFT_BAG, pid, {req[1], Command.RET_ERROR})
			return
		end

        local rewardList = {};
        for _, v in ipairs(gift_item.reward_item) do
            if v.begin_time <= now and v.end_time >= now then
				rewardList[v.group] = rewardList[v.group] or {}
                table.insert(rewardList[v.group], v);
            end
        end

		for k, v in pairs (rewardList) do
			local reward_item_list=get_all_fix_and_one_rand(v);
			for i=1,#reward_item_list do 
				local item=reward_item_list[i]
				log.info(string.format("type=%d,id=%d,value=%d",reward_item_list[i].type,reward_item_list[i].id,reward_item_list[i].value))
				table.insert(reward_item,{type=item.type,id=item.id,value=item.value,need_broadcast=item.need_broadcast})
				if item.drop > 0 then table.insert(reward_drops, item.drop); end
			end
		end
	end

	local consume_item=gift_item.consume_item;
	for i=1,#consume_item do 
        local tmp=consume_item[i];
        if tmp.begin_time <= now and tmp.end_time >= now then
            log.info(string.format("consume_item[%d],type=%d,id=%d,value=%d",i,tmp.type,tmp.id,tmp.value));
            table.insert(consume_items,{id=tmp.id,type=tmp.type,value=tmp.value*value,need_broadcast=tmp.need_broadcast});
        end
	end

	--[[local need_broadcast1, consume_name = get_gift_bag_consume_name(consume_items);
    if gift_gid == 420103 or gift_gid == 420104 then
        consume_name = "寻宝";
    end--]]

	local need_broadcast2, reward_name  = get_gift_bag_reward_name(reward_item);
	local items ={}
	local broadcast_items = {}
	for i=1, #reward_item do
		table.insert(items, {reward_item[i].type, reward_item[i].id, reward_item[i].value})
		if reward_item[i].need_broadcast == 1 then
			table.insert(broadcast_items, {reward_item[i].type, reward_item[i].id, reward_item[i].value})	
		end
	end

	-- exchange
	local ok, errno=conn:exchange(pid, consume_items, reward_item, Command.REASON_OPEN_GIFT_BAG, reward_drops)
	if ok then
		if g_gift_bag[gift_gid]._enable_lucky_count_ then
            set_gift_bag_open_count(pid, gift_gid, open_count, today_count);
		end
		if need_broadcast2 then
			NetService.NotifyClients(Command.NOTIFY_ACTION_BROADCAST, {pid, broadcast_items, 1})
		end
		--[[if need_broadcast1 and need_broadcast2 then
			local player_info = PlayerManager.Get(pid);
			local player_name = player_info.name or '';
            player_name = make_player_rich_text(pid, player_name);
			yqinfo("%s %s %s", player_name, consume_name, reward_name);
			local str =string.format( YQSTR.GIFT_BAG_REWARD_MESSAGE, consume_name, reward_name);
            broadcast.SystemBroadcastEasy(Command.SYS_BROADCAST_TYPE_TOP_CENTER, string.format(str, player_name))
			-- ai patch
			aiserver.NotifyAIActionArgStr(pid, Command.ACTION_SHOW_BILLBOARD, { str })
		end--]]
		yqinfo("`%d` OPEN_GIFT_BAG `%d`.", pid, gift_gid)
		conn:sendClientRespond(Command.S_OPEN_GIFT_BAG, pid, {req[1], Command.RET_SUCCESS,items, open_count})

		--[[if gift_gid == 420003 or gift_gid == 420013 then
			SocialManager.NotifyADSupportEvent(pid, 3, value)
		elseif gift_gid == 430293 then
			SocialManager.NotifyADSupportEvent(pid, 25, value) -- 许愿红包
		elseif gift_gid == 430294 or gift_gid == 430336  then
			SocialManager.NotifyADSupportEvent(pid, 26, value) -- 红包 / 猴赛雷红包
		end

		if gift_gid == 420103 or gift_gid == 420104 then
			cell.addActivityPoint(pid, Command.ACTIVITY_SHOP_BOX);
		end
		if gift_gid == 420103 then
			cell.disPatchQuestEvent(pid, 41, value);
		end
		if gift_gid == 420104 then
			cell.disPatchQuestEvent(pid, 42, value);
		end--]]
	else
		yqerror("`%d` fail to OPEN_GIFT_BAG `%d`, cell error.", pid, gift_gid)
		conn:sendClientRespond(Command.S_OPEN_GIFT_BAG, pid, {req[1], errno });
	end
end
