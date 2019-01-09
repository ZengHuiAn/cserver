local loop = loop;
local log  = log;
local Class = require "Class"

require("database")
require "printtb"
--require "point_reward"
--require "aiserver"
require "SocialManager"
require "NetService"
--local lottoConfig =require "lottoConfig"
--local lotto = require "lotto"
--local lottoRecord = require "lottoRecord"

local StableTime =require "StableTime"
local get_today_begin_time =StableTime.get_today_begin_time
--local broadcast =require "broadcast"
--require "YQSTR"
--require "util"

--local make_player_rich_text =util.make_player_rich_text;

require "SweepstakeConfig"
local SweepstakePlayerManager = require "SweepstakePlayerManager"
local CheckAndRefreshPool = SweepstakePlayerManager.CheckAndRefreshPool
local SweepstakePoolConfig = require "SweepstakePoolConfig"

local function addToEventList(list, event)
	for k, v in ipairs(list) do
		if v.type == event.type then
			v.value = v.value + event.value
			return	
		end
	end

	table.insert(list, event)
	return
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

local g_reward_pool = {}

-- on load
(function()
 	g_reward_pool ={}
	local ok, reward_list =database.query("SELECT gid, pool_type, sub_type, vip_min, vip_max, player_lv_min, player_lv_max, reward_item_type, reward_item_id, reward_item_value, weight, reward_item_name, reward_item_quality, unix_timestamp(begin_time) as begin_time, unix_timestamp(end_time) as end_time FROM lucky_draw");
	yqassert(ok, "Fail to load reward list.")
	for i=1, #reward_list do
		local reward =reward_list[i]
		local pool_type =reward.pool_type
		local sub_type =reward.sub_type
		g_reward_pool[pool_type] =g_reward_pool[pool_type] or {}
		g_reward_pool[pool_type][sub_type] =g_reward_pool[pool_type][sub_type] or {}
        reward.begin_time = tonumber(reward.begin_time);
        reward.end_time   = tonumber(reward.end_time);
        if reward.end_time == 0 then
            reward.end_time = 1602302400;
        end
		table.insert(g_reward_pool[pool_type][sub_type], reward)

	end
end)()

local function check_pool_type_and_id_vaildate(pool_type,id)
	if not (type(pool_type)=='number') then
		return false
	end
	if not g_reward_pool[pool_type] then
		return false
	end
	local cfg_instance = SweepstakeConfig.Get()
	return cfg_instance:checkIDAndPoolTypeVaild(id,pool_type) 
end

local function make_lucky_draw_reason(pool_type)
    if not pool_type or type(pool_type) ~= 'number' then
        return Command.REASON_LUCKY_DRAW_MIN;
    else
        return math.min(Command.REASON_LUCKY_DRAW_MIN + pool_type, Command.REASON_LUCKY_DRAW_MAX);
    end
end

function process_change_pool(conn, pid, req)
	local id = req[2]
	local t_now = loop.now()
	local cmd = Command.S_SWEEPSTAKE_CHANGE_POOL_RESPOND
	if not id then
		log.debug("fail to change pool param error")
		conn:sendClientRespond(cmd, pid, {req[1], Command.RET_PARAM_ERROR})
	end

	log.debug(string.format("player %d begin to change pool for id %d", pid, id))
		
	local pool_cfg = SweepstakePoolConfig.Get(id)

	if not pool_cfg then
		log.debug("pool config is nil")
		return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
	end
	
	local rand_pool = {}
	for pool_type, v in pairs(pool_cfg) do
		table.insert(rand_pool, pool_type)	
	end
	local index = math.random(1, #rand_pool)
	local select_pool = rand_pool[index]
	
	local cfg_instance = SweepstakeConfig.Get()
	local sweepstake_mapcfg = cfg_instance:getMapConfig() 
	if not (sweepstake_mapcfg and sweepstake_mapcfg[id]) then
		log.debug('cannot get sweepstakeconfig')
		return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
	end
	
	if t_now < sweepstake_mapcfg[id].begin_time or t_now > sweepstake_mapcfg[id].end_time then
		log.debug('not on time')
		return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
	end
	
	local playerDataID = cfg_instance:getPlayerDataIDByID(id)
	local playerManager = SweepstakePlayerManager.Get(pid,playerDataID)
	if not playerManager then
		log.debug('cannot get sweepstake playermanger')
		return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
	end	
	local playerdata = playerManager:getSweepstakePlayerData()

	CheckAndRefreshPool(pid, id)

	if (loop.now() <= playerdata.current_pool_end_time) and (playerdata.current_pool ~= 0) and (playerdata.current_pool_draw_count < pool_cfg[playerdata.current_pool].min_draw_count) then
		log.debug("current pool draw count <= min_draw_count, cannt change pool")	
		return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
	end

	if not (playerdata.total_count == 0 and cfg_instance:changePoolFirstFree(id)) then
		local consume_item = cfg_instance:getChangePoolConsume(id)
		if #consume_item > 0 then
			local ret, errno =conn:exchange(pid, consume_item, nil, Command.REASON_LUCKY_DRAW_CHANGE_POOL)
			if not ret then
				log.debug("consume fail")
				return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
			end
		end
	end	
	
	local success = playerManager:updateSweepstakePlayerData(playerdata.last_free_time, playerdata.total_count, playerdata.has_used_gold, playerdata.last_draw_time, playerdata.today_draw_count, playerdata.random_count, playerdata.randnum, playerdata.flag, select_pool, 0, t_now + pool_cfg[select_pool].duration)
	if not success then
		log.debug('update player data fail')
		return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
	else
		return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_SUCCESS, select_pool})
	end	
end

function process_change_pool_and_sweepstake(conn, pid, req)
	local id = req[2]
	local t_now = loop.now()
	local cmd = Command.S_SWEEPSTAKE_CHANGE_POOL_AND_SWEEPSTAKE_RESPOND
	if not id then
		log.debug("fail to change pool param error")
		conn:sendClientRespond(cmd, pid, {req[1], Command.RET_PARAM_ERROR})
	end

	log.debug(string.format("player %d begin to change pool for id %d and do sweepstake", pid, id))
		
	local pool_cfg = SweepstakePoolConfig.Get(id)

	if not pool_cfg then
		log.debug("pool config is nil")
		return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
	end
	
	local rand_pool = {}
	for pool_type, v in pairs(pool_cfg) do
		table.insert(rand_pool, pool_type)	
	end
	local index = math.random(1, #rand_pool)
	local select_pool = rand_pool[index]
	
	local cfg_instance = SweepstakeConfig.Get()
	local sweepstake_mapcfg = cfg_instance:getMapConfig() 
	if not (sweepstake_mapcfg and sweepstake_mapcfg[id]) then
		log.debug('cannot get sweepstakeconfig')
		return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
	end
	
	if t_now < sweepstake_mapcfg[id].begin_time or t_now > sweepstake_mapcfg[id].end_time then
		log.debug('not on time')
		return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
	end
	
	local playerDataID = cfg_instance:getPlayerDataIDByID(id)
	local playerManager = SweepstakePlayerManager.Get(pid,playerDataID)
	if not playerManager then
		log.debug('cannot get sweepstake playermanger')
		return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
	end	
	local playerdata = playerManager:getSweepstakePlayerData()

	CheckAndRefreshPool(pid, id)

	if (loop.now() <= playerdata.current_pool_end_time) and (playerdata.current_pool ~= 0) and (playerdata.current_pool_draw_count < pool_cfg[playerdata.current_pool].min_draw_count) then
		log.debug("current pool draw count <= min_draw_count, cannt change pool")	
		return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
	end

	local consume_type = cfg_instance:getConsumeTypeByID(id)
	local consume_id = cfg_instance:getConsumeIDByID(id)
	local price = cfg_instance:getPriceByID(id)

	if not consume_type or not consume_id or not price then
		log.debug("cannt get consume config")
		conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
		return	
	end

	local client_send_consume_item = {consume_type, consume_id, price}
	local combo = false
	local last_free_time = playerdata.last_free_time;
	local consume, combo_count, is_use_gold, last_free_time =make_sweepstake_consume_item_list(client_send_consume_item, id, combo, last_free_time)
	for k, v in ipairs(consume_item2 or {}) do
		table.insert(consume_item, v)
	end

	if not (playerdata.total_count == 0 and cfg_instance:changePoolFirstFree(id)) then
		local consume_item = cfg_instance:getChangePoolConsume(id)
	
		if consume then
			for k, v in ipairs(consume_item) do
				table.insert(consume, v)
			end
		end
	end	

	local ret, errno =conn:exchange(pid, consume, nil, Command.REASON_LUCKY_DRAW_CHANGE_POOL)
	if not ret then
		log.debug("consume fail")
		return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
	end
	
	local success = playerManager:updateSweepstakePlayerData(playerdata.last_free_time, playerdata.total_count, playerdata.has_used_gold, playerdata.last_draw_time, playerdata.today_draw_count, playerdata.random_count, playerdata.randnum, playerdata.flag, select_pool, 0, t_now + pool_cfg[select_pool].duration)
	if not success then
		log.debug('update player data fail')
		return conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
	end

	-- do sweepstake	
	if get_player_cache(pid).lucky_draw.sweepstaking then
		yqerror('is sweepstaking.')
		conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
		return
	end

	-- get player info
	local cell_res =cell.getPlayer(pid)
	player_info =cell_res and cell_res.player
	if not player_info then
		yqerror('`%d` is not a validate player id', pid)
		conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
		return
	end

	--get sweepstake config
	local cfg_instance = SweepstakeConfig.Get()
	local sweepstake_mapcfg = cfg_instance:getMapConfig() 
	if not (sweepstake_mapcfg and sweepstake_mapcfg[id]) then
		yqerror('cannot get sweepstakeconfig')
		conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
		return
	end
	
	if t_now < sweepstake_mapcfg[id].begin_time or t_now > sweepstake_mapcfg[id].end_time then
		yqerror('`%d` sweepstake activity not open now%d begin_time`%d` end_time`%d`',id, t_now, sweepstake_mapcfg[id].begin_time, sweepstake_mapcfg[id].end_time)
		conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
		return
	end	

	--get player sweepstake info
	local playerDataID = cfg_instance:getPlayerDataIDByID(id)
	local playerManager = SweepstakePlayerManager.Get(pid,playerDataID,sweepstake_mapcfg[id])
	if not playerManager then
		yqerror(' cannot get sweepstake playermanger')
		conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
		return 
	end	

	local sweepstake_playerdata = playerManager:getSweepstakePlayerData() 
	if not sweepstake_playerdata then
		yqerror('cannot get sweepstake_playerdata')
		conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
		return
	end

	--check condition
	local pool_cfg = SweepstakePoolConfig.Get(id)

	local pool_type = sweepstake_playerdata.current_pool

	if not check_pool_type_and_id_vaildate(pool_type,id) then
		yqerror("id and pool_type not vaild id:%d pool_type:%d", id, pool_type)
		conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
		return
	end
	yqinfo("&&&&&&&&&`%d` sweepstake id `%d` pool_type `%d`", pid, id, pool_type)

	if pool_cfg and pool_cfg[pool_type] then
		if (sweepstake_playerdata.current_pool_draw_count >= pool_cfg[pool_type].max_draw_count) and (pool_cfg[pool_type].max_draw_count ~= 0) then
			log.debug("draw count already max")
			conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
		end

		if (loop.now() > sweepstake_playerdata.current_pool_end_time) and (pool_cfg[pool_type].duration ~= 0) then
			log.debug("this pool already out of date")
			conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
		end
	end

	---- consume item
	local cfg_instance = SweepstakeConfig.Get()
	if not cfg_instance then
		log.debug("cannt get sweepstakeconfig")
		conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
		return 
	end

	local consume_type = cfg_instance:getConsumeTypeByID(id)
	local consume_id = cfg_instance:getConsumeIDByID(id)
	local price = cfg_instance:getPriceByID(id)

	if not consume_type or not consume_id or not price then
		log.debug("cannt get consume config")
		conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
		return	
	end

	local client_send_consume_item = {consume_type, consume_id, price}
	local combo = false
	local use_free_lucky_draw_chance =req[6];

    local last_free_time = sweepstake_playerdata.last_free_time;

	local consume_item, combo_count, is_use_gold, last_free_time =make_sweepstake_consume_item_list(client_send_consume_item, id, combo, last_free_time)
	if not consume_item then
		yqerror("not a validate consume item")
		conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
		return
	end

	---- reward item
	local reward
	local reward_item ={}
    local log_str = ""
    if #consume_item ~= 0 then
        log_str = string.format("  Consume:<%d, %d, %d> Reward:", consume_item[1].type or -1, consume_item[1].id or -1, consume_item[1].value or -1)
    else
        log_str = "  Consume:Free   Reward:"
    end
	local total_count =sweepstake_playerdata.total_count
	local has_used_gold=sweepstake_playerdata.has_used_gold
	local randnum = sweepstake_playerdata.randnum
	local random_count = sweepstake_playerdata.random_count
	local flag = sweepstake_playerdata.flag
    local need_broadcast_name = nil 
	for i=1, combo_count do  
		 yqinfo(string.format("----total_count = %d,randnum = %d,random_count = %d",total_count,randnum,random_count));
		reward, total_count, has_used_gold,randnum,random_count,flag =do_sweepstake(player_info, id, pool_type, is_use_gold, total_count, has_used_gold,randnum,random_count,flag)
		if not reward then
			local szErrMsg =total_count
			yqerror('`%d` fail to sweepstake, get reward_item error %s', pid, szErrMsg)
			conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})
			return
		end
		-- yqinfo(string.format("----total_count = %d,randnum = %d,random_count = %d",total_count,randnum,random_count));
		for j=1, #reward do
			local tmp =reward[j]
			table.insert(reward_item, { type =tmp.reward_item_type, id =tmp.reward_item_id, value =tmp.reward_item_value, quality = tmp.reward_item_quality})

            if tmp.reward_item_quality >= 6 then
                need_broadcast_name = need_broadcast_name and (need_broadcast_name .."、".. tmp.reward_item_name) or tmp.reward_item_name
            end
		end
	end
	---- exechange
	get_player_cache(pid).lucky_draw.sweepstaking =true
	local ret, errno =conn:exchange(pid, nil, reward_item, make_lucky_draw_reason(pool_type))
	get_player_cache(pid).lucky_draw.sweepstaking=false
	if not ret then
		yqerror('cell error')
		conn:sendClientRespond(cmd, pid, {req[1], errno});
		return
	end

	local now = math.floor(t_now);
	local today_draw_count = sweepstake_playerdata.today_draw_count + 1
	local success = playerManager:updateSweepstakePlayerData(last_free_time, total_count, has_used_gold and 1 or 0, now, today_draw_count, random_count, randnum, flag, sweepstake_playerdata.current_pool, sweepstake_playerdata.current_pool_draw_count + 1, sweepstake_playerdata.current_pool_end_time)
	if not success then
		yqinfo('mysql error')
		conn:sendClientRespond(cmd, pid, {req[1], Command.RET_ERROR})	
		return
	end
				
	local reward_item_amf ={}
	local event_list = {}
	for i=1, #reward_item do
		local item =reward_item[i]
		table.insert(reward_item_amf, { item.type, item.id, item.value, item.quality })
		log_str = (log_str.." <"..(item.type)..","..(item.id)..","..(item.value).."> ")
		if id == 2 then
			addToEventList(event_list, {type = 94, id = item.quality, value = 1})
		end
			


		local quest = get_quest(pid, 10, 101091)
		if quest and quest.status == 1 then
			-- 全服广播	
			if item.type == 42 then
				NetService.NotifyClients(Command.NOTIFY_DISPLAY_MESSAGE, { 4, player_info.name, item.id, item.value })
			end
		end
	end
	local name = cell_res.player.name
	conn:sendClientRespond(cmd, pid, {req[1], Command.RET_SUCCESS, reward_item_amf, select_pool})
	log.info('[process_sweepstake] Pooltype:'.. (pool_type) .. " Pid:"..(pid) .. (log_str or ""))

	local rankManager = SweepstakeRankManager.Get(id)
	if not rankManager then
		yqerror("%d fail to save point, cannot get rankManager", pid)
	end
	rankManager:updateRankScore(pid, combo_count*10, now);

	--quest 
	if id == 2 then
		addToEventList(event_list, {type = 4, id = 19, count = combo and combo_count or 1})
	end

	local activity_type = cfg_instance:getActivityTypeByID(id)
	if activity_type then
		addToEventList(event_list, {type = 55, id = activity_type, count = combo and combo_count or 1})
	end

	if #event_list > 0 then
		cell.NotifyQuestEvent(pid, event_list)
	end

end

function process_sweepstake(conn, pid, req)
	local t_now =math.floor(os.time())
	-- check
	if get_player_cache(pid).lucky_draw.sweepstaking then
		yqerror('`%d` fail to sweepstake, is sweepstaking.', pid)
		conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_ERROR})
		return
	end
	--check argument
	local id = req[2]
	--local pool_type =req[3]
	--[[if not check_pool_type_and_id_vaildate(pool_type,id) then
		yqerror("`%d` fail to sweepstake, invalid request argument,id and pool_type not vaild id:%d pool_type:%d", pid, id, pool_type)
		conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_ERROR})
		return
	end
	yqinfo("&&&&&&&&&`%d` sweepstake id `%d` pool_type `%d`", pid, id, pool_type)--]]

	-- get player info
	local cell_res =cell.getPlayer(pid)
	player_info =cell_res and cell_res.player
	if not player_info then
		yqerror('`%d` is not a validate player id', pid)
		conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_ERROR})
		return
	end

	--get sweepstake config
	local cfg_instance = SweepstakeConfig.Get()
	local sweepstake_mapcfg = cfg_instance:getMapConfig() 
	if not (sweepstake_mapcfg and sweepstake_mapcfg[id]) then
		yqerror('`%d` fail to sweepstake, cannot get sweepstakeconfig',pid)
		conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_ERROR})
		return
	end
	
	if t_now < sweepstake_mapcfg[id].begin_time or t_now > sweepstake_mapcfg[id].end_time then
		yqerror('`%d` fail to sweepstake, `%d` sweepstake activity not open now%d begin_time`%d` end_time`%d`',pid, id, t_now, sweepstake_mapcfg[id].begin_time, sweepstake_mapcfg[id].end_time)
		conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_ERROR})
		return
	end	

	--get player sweepstake info
	local playerDataID = cfg_instance:getPlayerDataIDByID(id)
	local playerManager = SweepstakePlayerManager.Get(pid,playerDataID,sweepstake_mapcfg[id])
	if not playerManager then
		yqerror('`%d` fail to sweepstake, cannot get sweepstake playermanger',pid)
		return 
	end	
	local sweepstake_playerdata = playerManager:getSweepstakePlayerData() 
	if not sweepstake_playerdata then
		yqerror('`%d` fail to sweepstake, cannot get sweepstake_playerdata',pid)
		conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_ERROR})
		return
	end

	CheckAndRefreshPool(pid, id)

	--check condition
	local pool_cfg = SweepstakePoolConfig.Get(id)

	if not pool_cfg and not req[3] then
		log.debug("param pool_type is nil")
		return conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_ERROR})
	end

	local pool_type 
	if not pool_cfg then
		pool_type = req[3]
	else
		pool_type = sweepstake_playerdata.current_pool
	end	

	if not check_pool_type_and_id_vaildate(pool_type,id) then
		yqerror("`%d` fail to sweepstake, invalid request argument,id and pool_type not vaild id:%d pool_type:%d", pid, id, pool_type)
		conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_ERROR})
		return
	end
	yqinfo("&&&&&&&&&`%d` sweepstake id `%d` pool_type `%d`", pid, id, pool_type)

	if pool_cfg and pool_cfg[pool_type] then
		if (sweepstake_playerdata.current_pool_draw_count >= pool_cfg[pool_type].max_draw_count) and (pool_cfg[pool_type].max_draw_count ~= 0) then
			log.debug("draw count already max")
			conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_ERROR})
		end

		if (loop.now() > sweepstake_playerdata.current_pool_end_time) and (pool_cfg[pool_type].duration ~= 0) then
			log.debug("this pool already out of date")
			conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_ERROR})
		end
	end

	---- consume item
	local client_send_consume_item =req[4]
	local combo =req[5] and req[5]~=0
	local use_free_lucky_draw_chance =req[6];

    local last_free_time = sweepstake_playerdata.last_free_time;

	local consume_item, combo_count, is_use_gold, last_free_time =make_sweepstake_consume_item_list(client_send_consume_item, id, combo, last_free_time)
	if not consume_item then
		yqerror("`%d` fail to sweepstake, invalid request argument,the 4th arg is not a validate `consume item` or %s.", pid, combo_count)
		conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_ERROR})
		return
	end

    --[[if use_free_lucky_draw_chance and #consume_item > 0 then
		yqerror("`%d` fail to sweepstake, client use free_time", pid);
		conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_ERROR})
		return
    end--]]

	---- reward item
	local reward
	local reward_item ={}
    local log_str = ""
    if #consume_item ~= 0 then
        log_str = string.format("  Consume:<%d, %d, %d> Reward:", consume_item[1].type or -1, consume_item[1].id or -1, consume_item[1].value or -1)
    else
        log_str = "  Consume:Free   Reward:"
    end
	local total_count =sweepstake_playerdata.total_count
	local has_used_gold=sweepstake_playerdata.has_used_gold
	local randnum = sweepstake_playerdata.randnum
	local random_count = sweepstake_playerdata.random_count
	local flag = sweepstake_playerdata.flag
    local need_broadcast_name = nil 
	for i=1, combo_count do  
		 yqinfo(string.format("----total_count = %d,randnum = %d,random_count = %d",total_count,randnum,random_count));
		reward, total_count, has_used_gold,randnum,random_count,flag =do_sweepstake(player_info, id, pool_type, is_use_gold, total_count, has_used_gold,randnum,random_count,flag)
		if not reward then
			local szErrMsg =total_count
			yqerror('`%d` fail to sweepstake, get reward_item error %s', pid, szErrMsg)
			conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_ERROR})
			return
		end
		-- yqinfo(string.format("----total_count = %d,randnum = %d,random_count = %d",total_count,randnum,random_count));
		for j=1, #reward do
			local tmp =reward[j]
			table.insert(reward_item, { type =tmp.reward_item_type, id =tmp.reward_item_id, value =tmp.reward_item_value, quality = tmp.reward_item_quality })
--[[
            if tmp.reward_item_quality >= 6 then
                need_broadcast_name = need_broadcast_name and (need_broadcast_name .."、".. tmp.reward_item_name) or tmp.reward_item_name
            end
--]]
		end
	end
	---- exechange
	get_player_cache(pid).lucky_draw.sweepstaking =true
	local ret, errno =conn:exchange(pid, consume_item, reward_item, make_lucky_draw_reason(pool_type))
	get_player_cache(pid).lucky_draw.sweepstaking=false
	if not ret then
		yqerror('`%d` fail to sweepstake, cell error', pid)
		conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], errno});
		return;
	end

	local now = math.floor(t_now);
	local today_draw_count = sweepstake_playerdata.today_draw_count + 1
	local success = playerManager:updateSweepstakePlayerData(last_free_time, total_count, has_used_gold and 1 or 0, now, today_draw_count, random_count, randnum, flag, sweepstake_playerdata.current_pool, sweepstake_playerdata.current_pool_draw_count + 1, sweepstake_playerdata.current_pool_end_time)
	if not success then
		yqinfo('`%d` fail to sweepstake, mysql error', pid)
		conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_ERROR})	
		return
	end
				
	local reward_item_amf ={}
	local event_list = {}
	for i=1, #reward_item do
		local item =reward_item[i]
		table.insert(reward_item_amf, { item.type, item.id, item.value, item.quality })
		log_str = (log_str.." <"..(item.type)..","..(item.id)..","..(item.value).."> ")
		if id == 2 then
			addToEventList(event_list, {type = 94, id = item.quality, value = 1})
		end

		local quest = get_quest(pid, 10, 101091)
		if quest and quest.status == 1 then
			-- 全服广播	
			if item.type == 42 then
				NetService.NotifyClients(Command.NOTIFY_DISPLAY_MESSAGE, { 4, player_info.name, item.id, item.value })
			end

			if item.quality >= 4 then
				NetService.NotifyClients(Command.NOTIFY_DISPLAY_MESSAGE, { 15, player_info.name, item.id, item.value, item.quality })
			end
		end
	end
	local name = cell_res.player.name
	--[[if need_broadcast_name then
		local str;
		if pool_type >= REWARD_POOL_TYPE_HERO_SOMETIME_FOR_WONDERKNIGHT_MIN and pool_type <=  REWARD_POOL_TYPE_HERO_SOMETIME_FOR_WONDERKNIGHT_MAX then
			str = string.format(YQSTR.LUCKY_DRAW_SOMETIME_POOL_MESSAGE, need_broadcast_name)
		elseif pool_type >= REWARD_POOL_TYPE_HERO_JIANGLIN_FOR_WONDERKNIGHT_MIN and pool_type <= REWARD_POOL_TYPE_HERO_JIANGLIN_FOR_WONDERKNIGHT_MAX then
			str = string.format(YQSTR.LUCKY_DRAW_JIANGLIN_POOL_MESSAGE, need_broadcast_name)
		end

		log.info('xxxxxxxx', pool_type, str, pid, name);
		if str then
			broadcast.SystemBroadcastEasy(Command.SYS_BROADCAST_TYPE_TOP_CENTER, string.format(str, make_player_rich_text(pid, name)))
		end
		-- ai patch
		--if pool_type <= REWARD_POOL_TYPE_HERO_HIGH or (pool_type >= REWARD_POOL_HERO_COUNTRY_MIN and pool_type <= REWARD_POOL_HERO_COUNTRY_MAX) then
		--	aiserver.NotifyAIActionArgStr(pid, Command.ACTION_SHOW_BILLBOARD, { str })
		--end
	end--]]
	conn:sendClientRespond(Command.S_SWEEPSTAKE_RESPOND, pid, {req[1], Command.RET_SUCCESS, reward_item_amf})
	log.info('[process_sweepstake] Pooltype:'.. (pool_type) .. " Pid:"..(pid) .. (log_str or ""))

	local rankManager = SweepstakeRankManager.Get(id)
	if not rankManager then
		yqerror("%d fail to save point, cannot get rankManager", pid)
	end
	rankManager:updateRankScore(pid, combo_count*10, now);

	--quest
	if id == 2 then
		addToEventList(event_list, {type = 4, id = 19, count = combo and combo_count or 1})
	end

	local activity_type = cfg_instance:getActivityTypeByID(id)
	if activity_type then
		addToEventList(event_list, {type = 55, id = activity_type, count = combo and combo_count or 1})
	end

	print("event_list >>>>>>>>>>>>>>", sprinttb(event_list))
	if #event_list > 0 then
		cell.NotifyQuestEvent(pid, event_list)
	end
	--[[if pool_type >= REWARD_POOL_TYPE_HERO_SOMETIME_MIN  and pool_type <= REWARD_POOL_TYPE_HERO_SOMETIME_MAX  then
		SocialManager.NotifyADSupportEvent(pid, 1, combo_count)
	end]]
end

function make_sweepstake_consume_item_list(item, id, combo, last_free_time)
    if not item then
        return nil, 'invalid prop'
    end

    item ={type=item[1], id=item[2], value =item[3]}

    if not item.type or not item.id or not item.value then
        return nil, 'invalid prop'
    end

	local cfg_instance = SweepstakeConfig.Get()
	if not cfg_instance then
		return nil, 'cannot get config'
	end

	local consume_type = cfg_instance:getConsumeTypeByID(id)
	local consume_id = cfg_instance:getConsumeIDByID(id)
	if not consume_type then
		return nil, 'cannot get consume_type'
	end
	if not consume_id then
		return nil, 'canot get consume_id'
	end
	yqinfo("item type%d item id%d, consume_type%d consume_id%d",item.type,item.id,consume_type,consume_id)
    if item.type ~= consume_type or item.id ~= consume_id then
		return nil, "client consume_type or consume_id not same with server config";
	end

	--专门用来几次的道具
	local count_item, _ = cfg_instance:getCountItemByID(id)

	-- use free first
	local can_use_free_draw = false;
	local free_gap = cfg_instance:getFreeTimeGapByID(id)
	if free_gap and free_gap > 0 and not combo then
		local t_now = math.floor(os.time())
		last_free_time = math.floor(last_free_time)
		local t_elapse = t_now - last_free_time
		if t_elapse >= free_gap then
			log.debug(string.format("make_sweepstake_consume_item_list t_elapse %d, free_gap %d, last_free_time %d, t.now %d", t_elapse, free_gap, last_free_time, t_now));
			return {count_item}, 1, false, t_now
		end
	end

	if item.value == 0 then
		if free_gap and free_gap > 0 then
			return nil, 'free time cooldown'
		else
			return nil, 'not support `free draw`'
		end
	end

	if not combo then
		local price = cfg_instance:getPriceByID(id)
		if not price then
			return nil, 'cannot get price'
		end
		item.value = price

		if item.type == TRIPLE_GOLD_TYPE and item.id == TRIPLE_GOLD_ID then
			return { item, count_item }, 1, true, last_free_time
		else
			return { item, count_item }, 1, false, last_free_time
		end
	end

	local combo_count = cfg_instance:getComboCountByID(id)
	if not combo_count then return nil, "cannot get combocount" end

	if combo_count == 0 then
		return nil, 'not support `combo draw`'
	end

	local combo_price = cfg_instance:getComboPriceByID(id)
	if not combo_price then
		return nil, 'cannot get comboprice'
	end

	item.value =combo_count * combo_price
	count_item.value = combo_count * count_item.value 
	if item.type == TRIPLE_GOLD_TYPE and item.id == TRIPLE_GOLD_ID then
		return { item, count_item }, combo_count, true, last_free_time
	else
		return { item, count_item }, combo_count, false, last_free_time
	end
end

local function get_random_num()
    return math.random(5, 9);

    --[[
    local randnum;
    if math.random(1,100) < 80 then
        randnum = math.random(61,80)
    else
        randnum = math.random(1,60)
    end
    return randnum
    --]]
end

local function get_second_random_num()
    return math.random(5, 9);
--[[
    if math.random(1,100) < 95 then
        return math.random(70,90)
    else
        return math.random(10,69)
    end
--]]
end

local function reward_item_is_match(player_info, item)
    local now = loop.now();
    return player_info
        and player_info.level>=item.player_lv_min
        and player_info.level<=item.player_lv_max
        and player_info.vip>=item.vip_min
        and player_info.vip<=item.vip_max
        and now >= item.begin_time
        and now <= item.end_time
end

local function select_reward(player_info, sub_pool,pool_type)
    if not sub_pool then
        return nil, 'sub pool is absent'
    end
    local t_now =os.time()
    -- filter
    local filter_reward_list ={}
    for i=1, #sub_pool do
        if reward_item_is_match(player_info, sub_pool[i]) then
            table.insert(filter_reward_list, sub_pool[i])
        end
    end
    if #filter_reward_list == 0 then
        return nil, 'filter_reward_list is empty'
    end
    local select_item =get_all_fix_and_one_rand(filter_reward_list)
    return select_item
end

function do_sweepstake(player_info, id, pool_type, is_use_gold, total_count, has_used_gold,randnum,random_count,first_draw_flag)
	local sub_type =REWARD_POOL_SUB_TYPE_NORMAL
	local cfg_instance = SweepstakeConfig.Get()
	if not cfg_instance then
		return nil, 'cannot get config'
	end
	local guarantee_count = cfg_instance:getGuaranteeCountByID(id)
	if not guarantee_count then
		return nil, 'cannot get guarantee_count'
	end

	local is_first_draw = (first_draw_flag == 0);

	if randnum == 0 then
		if first_draw_flag == 0 then
			randnum = get_random_num();
			first_draw_flag = 1			
		else
			randnum = get_second_random_num()
		end
	end

	log.info(string.format("player %d sweepstake player info  pool_type:%d, total_count:%d, random_count:%d, randnum:%d",player_info.id,pool_type,total_count,random_count,randnum))

    total_count   = total_count + 1
    random_count  = random_count + 1

	if is_first_draw and g_reward_pool[pool_type][REWARD_POOL_SUB_TYPE_FIRST_DRAW] then -- 普通首抽
		sub_type    = REWARD_POOL_SUB_TYPE_FIRST_DRAW;
	elseif (guarantee_count ~= 0) and (total_count >= guarantee_count) then -- 保底
		if g_reward_pool[pool_type][REWARD_POOL_SUB_TYPE_GUARANTEE] then
			sub_type = REWARD_POOL_SUB_TYPE_GUARANTEE;   
		else
			sub_type = REWARD_POOL_SUB_TYPE_NORMAL
		end
		total_count = 0;
    elseif is_use_gold and not has_used_gold then -- 金币首抽
		if g_reward_pool[pool_type][REWARD_POOL_SUB_TYPE_FIRST_GOLD] then
			sub_type    = REWARD_POOL_SUB_TYPE_FIRST_GOLD; 
		else
			sub_type = REWARD_POOL_SUB_TYPE_NORMAL
		end
		has_used_gold = true;
	else -- 普通抽奖
       if (randnum > 0) and (random_count >= randnum) then
		   if g_reward_pool[pool_type][REWARD_POOL_SUB_TYPE_RANDOM] then
		       sub_type = REWARD_POOL_SUB_TYPE_RANDOM;
		   else
			   sub_type = REWARD_POOL_SUB_TYPE_NORMAL
		   end
		   random_count = 0;
		   randnum = 0;
       else
           sub_type = REWARD_POOL_SUB_TYPE_NORMAL
       end

	   --[[if notHasSubTypeRandom() then
		   sub_type = REWARD_POOL_SUB_TYPE_NORMAL
	   end--]]
	end
	log.info(string.format("  choose sub_type:%d", sub_type));

	-- log.info(string.format("lucky_draw_info_log:total_count = %d,random_count= %d, randnum = %d ,flag =%d ,pool_type= %d,sub_type= %d",total_count,random_count,randnum,first_draw_flag,pool_type,sub_type))
	local reward_item, errMsg = select_reward(player_info, g_reward_pool[pool_type][sub_type],pool_type)    
    if not reward_item then
        return nil,errMsg;
    else
        return reward_item,total_count, has_used_gold,randnum,random_count,first_draw_flag
    end
end

Scheduler.Register(function(now)
	_now = now;
	if 0 == now % 5 then
		--yqinfo("Begin to settle sweepstake reward")
		--get all activity
		local cfg_instance = SweepstakeConfig.Get()
		if not cfg_instance then
			yqerror("fail to settle sweepstake, cannot get sweepstakeconfig")
		end	
		local map_cfg = cfg_instance:getMapConfig()		
		for k, v in pairs(map_cfg) do
			local activity_id = k
			local status = cfg_instance:getStatusByID(activity_id)
			if not status then
				yqerror("fail to settle sweepstake, cannot get status for id:%d", activity_id)
			else	
				local begin_time,end_time = cfg_instance:getActivityTimeByID(activity_id)
				if (not begin_time) or (not end_time) then
					yqerror("fail to settle sweepstake, cannot get activity time for id:%d", activity_id)
				else
					--check
					if _now > end_time and status == 0 then
						yqinfo("Begin to settle sweepstake reward for id:%d", activity_id)
						local rankManager = SweepstakeRankManager.Get(activity_id)
						if not rankManager then
							yqerror("fail to settle sweepstake, cannot get rank manager for id:%d", activity_id)
						else
							local ok = rankManager:settleReward()
							if ok then
								cfg_instance:closeSweepstakeByID(activity_id)	
							else
								yqerror("fail to sett sweepstake, close sweepstake fail")
							end	
						end
					end
				end
			end
		end
	end
end);

--Scheduler.Register(function(now)
--	local cfg_instance = SweepstakeConfig.Get()
--	if not cfg_instance then
--		return yqerror("fail to checkAndAddLimitSweepStake , cannot get cfg")
--	end
--	cfg_instance:checkAndAddLimitSweepstake()
--end);

