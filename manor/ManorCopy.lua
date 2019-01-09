local database = require "database"
local Command = require "Command"
local cell = require "cell"
local protobuf = require "protobuf"
local log = log

local MAX_NUMBER = 1000000

math.randomseed(os.time())

-- init protocol
local function loadProtocol(file)
	local f = io.open(file, "rb")
	local protocol= f:read "*a"
	f:close()
	protobuf.register(protocol)
end

loadProtocol("../protocol/config.pb");

local function readFile(fileName, protocol)
    local f = io.open(fileName, "rb")
    local content = f:read("*a")
    f:close()

    return protobuf.decode("com.agame.config." .. protocol, content);
end

local function encode(protocol, msg)
	local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
	if code == nil then
		print(string.format(" * encode %s failed", protocol));		
		loop.exit();
		return nil;
	end
	return code;
end

------------------------------------------------------- config ----------------------------------------------------------------------------------

-- 加载挑战积分配置表
local challenge_config_list = {}
local function load_challenge_config()
	local cfg = readFile("../etc/config/manor/config_manor_fight_add.pb", "config_manor_fight_add");
	if not cfg then return end
	for _, v in ipairs(cfg.rows) do
		challenge_config_list[v.property] = challenge_config_list[v.property] or {}
		local consume = {}
		for i = 1, 4 do
			if v["consume_item_type" .. i] > 0 then
				table.insert(consume, { type = v["consume_item_type" .. i], id = v["consume_item_id" .. i], value = v["consume_item_value" .. i] })
			end
		end
		
		challenge_config_list[v.property][v.condition] = { property = v.property, condition = v.condition, fight_id = v.fight_id, element = v.element, role_num = v.role_num,
			add_property = v.add_property, win_times = v.win_times, consume = consume }

	end
end

local manor_battle_config_list = {}
-- 加载庄园战斗配置表
local function load_manor_battle_config()
	local cfg = readFile("../etc/config/manor/config_manor_fight_config.pb", "config_manor_fight_config")
	if not cfg then return end
	for _, v in ipairs(cfg.rows) do
       		manor_battle_config_list[v.gid] = { depend_level_id = v.depend_level_id, depend_fight0_id = v.depend_fight0_id, depend_fight1_id = v.depend_fight1_id }
	end
end

local property_lv_config_list = {}
local function load_property_lv_config()
	local cfg = readFile("../etc/config/manor/config_manor_property_lv.pb", "config_manor_property_lv")
	for _, v in ipairs(cfg.rows) do
		property_lv_config_list[v.work_type] = property_lv_config_list[v.work_type] or {}
		table.insert(property_lv_config_list[v.work_type], { work_type = v.work_type, work_level = v.work_level, property_value = v.property_value })
	end
end

local function get_lv_by_type_value(type, value)
	local list = property_lv_config_list[type]

	for _, v in ipairs(list) do
		if value < v.property_value then
			return v.work_level
		end
	end

	return 1
end


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 加载玩家战斗信息
local user_fight_list = {}
local function load_fight_info(pid)
	local ok, result = database.query("select * from `manor_battle_info` where `pid` = %d;", pid)
	if ok and #result > 0 then
		for i, v in ipairs(result) do
			user_fight_list[v.pid] = user_fight_list[v.pid] or {}
			user_fight_list[v.pid][v.property] = user_fight_list[v.pid][v.property] or {}
			user_fight_list[v.pid][v.property][v.condition] = user_fight_list[v.pid][v.property][v.condition] or {}
			local t = { fight_id = v.fight_id, fight_count = v.fight_count }
			table.insert(user_fight_list[v.pid][v.property][v.condition], t)
		end
	else
		user_fight_list[pid] = {}
	end 
end

-- 战斗信息是否已经存在
local function is_fight_info_exist(pid)
	if user_fight_list[pid] ~= nil then
		return true
	else
		return false
	end
end

local function get_fight_count(pid, property_id, condi)
	if not user_fight_list[pid] or not user_fight_list[pid][property_id] or not user_fight_list[pid][property_id][condi] then
		return 0
	end

	local fightList = user_fight_list[pid][property_id][condi]
	local count = 0
	for _, v in ipairs(fightList) do
		count = count + v.fight_count
	end

	return count
end

-- 是否限制战斗
local function is_fight_limit(pid, property_id, condi, n)
	local count = get_fight_count(pid, property_id, condi)
	if count >= n then
		return true
	else	
		return false
	end
end

-- 通过id获取玩家存储的战斗信息
local function get_fight_info(pid, property_id, condition, fight_id)
	if user_fight_list[pid] == nil or user_fight_list[pid][property_id] == nil or user_fight_list[pid][property_id][condition] == nil then
		return nil
	end
	local list =  user_fight_list[pid][property_id][condition]
	for _, v in ipairs(list) do
		if v.fight_id == fight_id then
			return v
		end
	end

	return nil
end

-- 添加（如果不存在就插入）或者替换
local function replace_fight_info(pid, battle_info)
	local fight_info = get_fight_info(pid, battle_info.property, battle_info.condition, battle_info.fight_id)
	local count = fight_info and fight_info.fight_count or 0			
	local ok = database.update("replace into manor_battle_info(`pid`, `property`, `condition`, `fight_id`, `fight_count`) values(%d, %d, %d, %d, %d);",
		pid, battle_info.property, battle_info.condition, battle_info.fight_id, count)
	if ok then
		yqinfo("replace fight infomation success.")
		user_fight_list[pid] = user_fight_list[pid] or {}
		user_fight_list[pid][battle_info.property] = user_fight_list[pid][battle_info.property] or {}
		user_fight_list[pid][battle_info.property][battle_info.condition] = user_fight_list[pid][battle_info.property][battle_info.condition] or {}
		if not fight_info then
			local t = { fight_id = battle_info.fight_id, fight_count = 0 }
			table.insert(user_fight_list[pid][battle_info.property][battle_info.condition], t)
		end
	end
end

local function add_fight_count(pid, property_id, condition, fight_id)
	if not user_fight_list[pid] or not user_fight_list[pid][property_id] or not user_fight_list[pid][property_id][condition] then
		return false
	end
	local fightList = user_fight_list[pid][property_id][condition]
	for _, v in ipairs(fightList) do
		if v.fight_id == fight_id then
			local n = v.fight_count + 1
			local ok = database.update("update `manor_battle_info` set `fight_count` = %d where `pid` = %d and `property` = %d and `condition` = %d and `fight_id` = %d;", n, pid, property_id, condition, fight_id)
			if ok then	
				v.fight_count = n
				return true
			end
		end
	end
	
	return false
end

--------------------------------------------------------------------------------------------------------
local manor_property_list = {}
local function load_property(pid)
	if not manor_property_list[pid] then
		local ok, result = database.query("select * from manor_manufacture_player_qualified_workman where `pid` = %d;", pid)
		if ok and #result > 0 then
			for _, v in ipairs(result) do
				manor_property_list[v.pid] = manor_property_list[v.pid] or {}
				manor_property_list[v.pid][v.workman_id] = manor_property_list[v.pid][v.workman_id] or {}
				manor_property_list[v.pid][v.workman_id][v.property_id] = v.property_value
			end
		else
			manor_property_list[pid] = {}
		end
	end
end

local function is_property_empty(pid)
	if not manor_property_list[pid] then
		return true
	end
	return false
end

local function replace_property(pid, info)
	if not info then
		return
	end
	local ok = database.update("replace into `manor_manufacture_player_qualified_workman`(`pid`, `workman_id`, `property_id`, `property_value`) values(%d, %d, %d, %d);",
		pid, info.workman_id, info.property_id, info.property_value)
	if ok then
		yqinfo("replace property success")
		manor_property_list[pid] = manor_property_list[pid] or {}
		manor_property_list[pid][info.workman_id] = manor_property_list[pid][info.workman_id] or {}
		manor_property_list[pid][info.workman_id][info.property_id] = info.property_value
	end

	return ok
end

-------------------------------------------------------------------------------------------------------------------

-- 是否依赖其它战斗
local function is_depend_other_fight(fight_id)
	local fight = manor_battle_config_list[fight_id]
	if not fight then
		return false
	end
	if fight.depend_fight0_id ~= 0 or fight.depend_fight1_id ~= 0 then
		return true
	else
		return false
	end
end

-- 获得一场战斗信息
local function get_battle(pid, property_id, condi_val)
	if not challenge_config_list[property_id] then
		return nil
	end

	-- 找到还没打的最小副本
	local n = MAX_NUMBER 
	for i, v in pairs(challenge_config_list[property_id]) do
		local fight_count = get_fight_count(pid, property_id, i)
		if fight_count < v.win_times and i < n and condi_val >= i then
			n = i		
		end
	end
 
	return challenge_config_list[property_id][n]
end


local function get_global_property_value(pid, workman_id, property_id)	
	if is_property_empty(pid) then
		load_property(pid)
	end
	if manor_property_list[pid] and manor_property_list[pid][workman_id] and manor_property_list[pid][workman_id][property_id] then
		return manor_property_list[pid][workman_id][property_id]
	else
		return 0
	end
end


local function get_current_fight_count(pid)
	if not is_fight_info_exist(pid) then
		load_fight_info(pid)
	end

	local ret = {}
	for i, v in pairs(challenge_config_list) do
		for j, _ in pairs(v) do
			local n = get_fight_count(pid, i, j)				-- i: property, j: condition
			if n > 0 then
				table.insert(ret, { i, j, n })
			end
		end
	end

	return ret
end

local function get_add_property(property, condition)
	if not challenge_config_list[property] or not challenge_config_list[property][condition] then
		return 0
	end

	local v = challenge_config_list[property][condition]

	return v and v.add_property or 0
end

local function get_copy_respond(pid, request)
	-- 参数检测
	if type(request) ~= "table" or #request < 4 or type(request[4]) ~= "table" or #request[4] < 1 then
		request[1] = request[1] or 0
		return { request[1], Command.RET_PARAM_ERROR }
	end

	-- 获得用户的property_value值（用来判断是否满足战斗条件）
	local workman = GetManufactureQualifiedWorkmen(pid)
	if not workman then
		log.warning("get_copy_respond: worman not exists, pid = ", pid)
		return { request[1], Command.RET_ERROR } 
	end
 	local val = workman:GetProperty(request[3], request[2], true)

	-- 随机得到一个战斗信息
	local battle_info = get_battle(pid, request[2], val)
	if not battle_info then 
		log.warning("get_copy_respond: get battle information failed, property, condition = ", request[2], val)
		return { request[1], Command.RET_ERROR } 
	end

	-- 是否加载了战斗信息
	if not is_fight_info_exist(pid) then
		load_fight_info(pid)
	end

	-- 战斗次数限制检测
	if is_fight_limit(pid, request[2], battle_info.condition, battle_info.win_times) then
		log.warning("get_copy_respond: fight limit not enough, property, condition, win_times = ", request[2], battle_info.condition, battle_info.win_times)
		return { request[1], Command.RET_DEPEND }
	end
 
	-- 测试依赖
	if is_depend_other_fight(battle_info.fight_id) then
		return { request[1], Command.RET_DEPEND }
	end

	local fight_data, err = cell.PlayerFightPrepare(pid, battle_info.fight_id, request[4]);
	if err then
		log.debug(string.format('load fight data of player %d vs npc %d error %s', pid, battle_info.fight_id, err))
		return { request[1], Command.RET_ERROR}
	end

--[[
	-- 获得攻击者信息
	local attack, err = cell.QueryPlayerFightInfo(pid, false, 0, request[4])	
	if err then
		log.warning("get_copy_respond: get attacker error.")
		return { request[1], Command.RET_ERROR }
	end

	-- 获得防守者信息
	local defend, err = cell.QueryPlayerFightInfo(battle_info.fight_id, true, 100)
	if err then
		log.warning("get_copy_respond: get defender infomation error, fight_id = ", fight_id)
		return { request[1], Command.RET_ERROR }
	end

	local fight_data = {
		attacker = attack,
		defender = defend,
		scene = "18hao",
		seed = math.random(1, 0x7fffffff),
	}
--]]

	local code = encode('FightData', fight_data);
	if code == nil then
		yqinfo("enode error.")
		return { request[1], Command.RET_ERROR };
	end

	-- 更新战斗信息
	replace_fight_info(pid, battle_info)	

	return { request[1], Command.RET_SUCCESS, battle_info.fight_id, code, get_fight_count(pid, battle_info.property, battle_info.condition) }
end

local function get_copy_check_respond(pid, request)
	-- 参数检测
	if type(request) ~= "table" or #request < 5 then
		request[1] = request[1] or 0
		return { request[1], Command.RET_PARAM_ERROR }
	end

	-- 从数据库加载(如果当前不存在)
	if not is_fight_info_exist(pid) then
		load_fight_info(pid)
	end
	local fight_info = get_fight_info(pid, request[3], request[4], request[5])	-- 2: workman_id, 3: property, 4: condition, 5: fight_id 
	if not fight_info then
		log.warning("get_copy_check_respond: fight info not exitst, pid, property, condition, fight_id = ", pid, request[3], request[4], request[5])
		return { request[1], Command.RET_ERROR }
	end

	-- consume
	local consume = challenge_config_list[request[3]][request[4]].consume
	local respond = cell.sendReward(pid, nil, consume, nil)
	if not respond or respond.result ~= 0 then
		log.warning("get_copy_check_respond: consume failed, pid, property, condition = ", pid, request[3], request[4])
		return { request[1], Command.RET_ERROR }
	end

	-- 额外属性是否为空
	if is_property_empty(pid) then
		load_property(pid)
	end

   	-- 更新额外的property_value（如果不存在就插入）
	local value = get_global_property_value(pid, request[2], request[3]) + get_add_property(request[3], request[4]) 
	local lineInfo = GetManufacture(pid)	
	local line, pos, linfo = lineInfo:GetWorkmanLineAndPos(request[2])
	if line > 0 and pos > 0 and linfo then
		local ok = lineInfo:ChangeLineWorkmanSpeedAndProduceRate(linfo, false, replace_property, pid, {workman_id = request[2], property_id = request[3], property_value = value})
		if not ok then
			log.warning("ChangeLineWorkmanSpeedAndProduceRate failed.")
		end
	else
		replace_property(pid, {workman_id = request[2], property_id = request[3], property_value = value})
	end

	-- 增加战斗次数
	local ok = add_fight_count(pid, request[3], request[4], request[5])
	if ok then
		log.warning("update fight_count success!")
	end
	
	return { request[1], Command.RET_SUCCESS }
end

load_challenge_config()
load_manor_battle_config()
load_property_lv_config()

return {
	get_copy_respond = get_copy_respond,
	get_copy_check_respond = get_copy_check_respond,
	get_global_property_value = get_global_property_value,
	get_current_fight_count = get_current_fight_count
}

