local database = require "database"
local Command = require "Command"
local Agent = require "Agent"
local BinaryConfig = require "BinaryConfig"
local cell = require "cell"
require "ContactManager"
require "MailReward"
local log = log

local FavorCollection = {}
local FavorManager = { map = {} }
local FavorDB = {}

----------------------------- config --------------------------------

EffectConfig = {}
local function LoadFavorEffectConfig() 
	local rows = BinaryConfig.Load("config_arguments_reward", "chat")
	if rows then
		for _, v in ipairs(rows) do
			EffectConfig[v.type] = EffectConfig[v.type] or {}
			table.insert(EffectConfig[v.type], v)
		end
	end
end
LoadFavorEffectConfig()
 
FavorConfig = {} 
local function LoadFavorConfig()
	local rows = BinaryConfig.Load("config_friend_gift", "chat")
	if rows then
		for _, v in ipairs(rows) do
			FavorConfig[v.type] = FavorConfig[v.type] or {}
			FavorConfig[v.type][v.consume_item_id1] = v
		end
	end
end
LoadFavorConfig()

PackageConfig = {}
local function LoadPackageConfig()
	local ok, result = database.query("select `package_id`, `item_type`, `item_id`, `item_value` from `item_package_config`;")
	if ok then
		for _, v in ipairs(result) do
			PackageConfig[v.package_id] = PackageConfig[v.package_id] or {}
			table.insert(PackageConfig[v.package_id], { type = v.item_type, id = v.item_id, value = v.item_value })
		end
	end
end
LoadPackageConfig()

local function OriginTime(time)
	local begin_time = 1517414400
	local period = 24 * 3600
	return begin_time + math.floor((time - begin_time) / period) * period
end
	
function FavorDB.Load(pid)	
	local ok, result = database.query("select pid1, pid2, source, value, unix_timestamp(origin_time) as origin_time, count from friend_favor where pid1 = %d or pid2 = %d;", pid, pid)
	if ok and #result > 0 then
		for _, v in ipairs(result) do
			v.is_db = true
			local index2 = pid == v.pid1 and v.pid2 or v.pid1
			local min = v.pid1
			local max = v.pid2
			FavorCollection[min .. "_" .. max] = FavorCollection[min .. "_" .. max] or {}
			FavorCollection[min .. "_" .. max][v.source] = v
			FavorManager.map[pid] = FavorManager.map[pid] or {}
			FavorManager.map[pid][index2] = FavorManager.map[pid][index2] or {}
			FavorManager.map[pid][index2][v.source] = v
		end	
	end
end

function FavorDB.Sync(info)
	if type(info) ~= "table" then
		log.warning("favor sync, info is not a table.")
		return nil
	end	
	
	local ok = false
	if info.is_db then
		ok = database.update("update friend_favor set value = %d, origin_time = from_unixtime_s(%d), count = %d where pid1 = %d and pid2 = %d and source = %d;", info.value, info.origin_time, info.count,
			info.pid1, info.pid2, info.source)
	else
		ok = database.update("insert into friend_favor(pid1, pid2, source, value, origin_time, count) values(%d, %d, %d, %d, from_unixtime_s(%d), %d);", 
			info.pid1, info.pid2, info.source, info.value, info.origin_time, info.count)
		if ok then
			info.is_db = true
		end
	end

	return ok
end

function FavorManager.GetFavor(pid)
	if FavorManager.map[pid] == nil then
		FavorDB.Load(pid)
		FavorManager.map[pid] = FavorManager.map[pid] or {}
	end	
	
	return FavorManager.map[pid]	
end

function FavorManager.GetFavor2(pid1, pid2)
	FavorManager.GetFavor(pid1)
	FavorManager.GetFavor(pid2)

	local min = math.min(pid1, pid2)
	local max = math.max(pid1, pid2)
	FavorManager.map[pid1][pid2] = FavorManager.map[pid1][pid2] or {}
	FavorManager.map[pid2][pid1] = FavorManager.map[pid2][pid1] or {}
	FavorCollection[min .. "_" .. max] = FavorCollection[min .. "_" .. max] or {}	

	return FavorCollection[min .. "_" .. max]
end

function FavorManager.GetFavorBySource(pid1, pid2, source)
	local m = FavorManager.GetFavor2(pid1, pid2)
	
	local min = math.min(pid1, pid2)
	local max = math.max(pid1, pid2)
	if m[source] == nil then
		local t = { pid1 = min, pid2 = max, source = source, value = 0, origin_time = OriginTime(loop.now()), count = 0, is_db = false }
		m[source] = t
		FavorManager.map[pid1][pid2][source] = t
		FavorManager.map[pid2][pid1][source] = t
	end
	
	return m[source]
end

------------------------------ interfaces ----------------------------
-- 赠送体力和团队活动增加好感度
function FavorManager.AddFavor(pid1, pid2, source, gift_id)
	local favor = FavorManager.GetFavorBySource(pid1, pid2, source)
	local cfg = FavorConfig[source][gift_id or 0]
	if not cfg then
		log.warning(string.format("add favor failed, source %d config is not exist.", source))
		return
	end

	local old_value = FavorManager.TotalFavor(pid1, pid2)

	-- 检查当天的赠送数量
	if source == 1 or source == 2 then	-- 1是赠送体力，2是团队活动，3是赠送礼物
		local today_origin_time = OriginTime(loop.now())
		if today_origin_time == favor.origin_time then
			if favor.count >= cfg.get_limit then
				log.debug(string.format("%d, %d favor count is %d, now is %d, origin time is %d.", pid1, pid2, favor.count, loop.now(), today_origin_time))
				return
			end
		else
			favor.count = 0
			favor.origin_time = today_origin_time
		end
	end

	favor.value = favor.value + cfg.arguments_value
	favor.count = favor.count + 1
	FavorDB.Sync(favor)
	
	-- 通知玩家，好感度变化了	
	local cmd = Command.C_FAVOR_CHANGER_NOTIFY
	local agent1 = Agent.Get(pid1)
	local total = FavorManager.TotalFavor(pid1, pid2)
	if agent1 then
		agent1:Notify({ cmd, { pid2, total } })
	end
	local agent2 = Agent.Get(pid2)
	if agent2 then
		agent2:Notify({ cmd, { pid1, total } })
	end
	
	-- 好感度到达一定程度，发放奖励
	local cfgs = FavorManager.GetCfgs(pid1, pid2, old_value)
	for _, v in ipairs(cfgs) do
		if old_value < v.condition_value and PackageConfig[v.reward_package] then
			send_reward_by_mail(pid1, "好感度奖励", string.format("好感度达到%d，获得相应奖励~", total), PackageConfig[v.reward_package])
			send_reward_by_mail(pid2, "好感度奖励", string.format("好感度达到%d，获得相应奖励~", total), PackageConfig[v.reward_package])
		end
	end
end

-- 清除好感度（当删除好友时）
function FavorManager.ClearFavor(pid1, pid2)
	local favors = FavorManager.GetFavor2(pid1, pid2)

	for _, favor in pairs(favors) do
		favor.value = 0
		FavorDB.Sync(favor)
	end
end

-- 计算总好感度
function FavorManager.TotalFavor(pid1, pid2)
	local n = 0
	local favors = FavorManager.GetFavor2(pid1, pid2)
	for _, favor in pairs(favors) do
		n = n + favor.value
	end

	return n
end

-- 根据好感度数值来获取config
function FavorManager.GetCfgs(pid1, pid2, old)
	local cfg = EffectConfig[1]
	local total = FavorManager.TotalFavor(pid1, pid2)
	local ret = {}

	for _, v in ipairs(cfg) do
		if total >= v.condition_value and old < v.condition_value then
			table.insert(ret, v)
		end
	end

	return ret
end

function FavorManager.GetConfig(pid1, pid2)
	local cfg = EffectConfig[1]
	local total = FavorManager.TotalFavor(pid1, pid2)

	for _, v in ipairs(cfg) do
		if total >= v.condition_value then
			return v
		end
	end

	return nil
end

-- 赠送时之力是否翻倍
function FavorManager.IsDoublePresent(pid1, pid2)
	local cfg = FavorManager.GetConfig(pid1, pid2)
	if not cfg then
		return false
	end

	local rate = cfg.double_tili
	if rate <= math.random(10000) then
		return true
	end

	return false
end

----------------------------- commands --------------------------------
function FavorManager.RegisterCommands(service)
	service:on(Command.C_QUERY_FAVOR_REQUEST, function (conn, pid, request)
		local cmd = Command.C_QUERY_FAVOR_RESPOND
		log.debug(string.format("cmd: %d, player %d query favor.", cmd, pid))

		if type(request) ~= "table" or #request < 1 then
			log.warning(string.format("cmd: %d, param error.", cmd))
			return conn:sendClientRespond(cmd, pid, { 1, Command.RET_PARAM_ERROR })
		end
		local sn = request[1]

		local favors = FavorManager.GetFavor(pid)
		local ret = {}
		for fid, v in pairs(favors) do
			for _, v2 in pairs(v) do
				if v2.value > 0 then
					table.insert(ret, { fid, v.value })			
				end
			end
		end
	
		conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, ret })
	end)

	service:on(Command.S_ADD_FAVOR_NOTIFY, "AddFavorNotify", function (conn, channel, request)
		if channel ~= 0 then
			log.warning("AddFavorNotify failed, channel is not 0.")
			return
		end
		local pid1 = request.pid1
		local pid2 = request.pid2
		local source = request.source
		log.debug(string.format("AddFavorNotify: %d, %d, %d = ", pid1, pid2, source))
		
		local contact1 = ContactManager.Get(pid1)
		local contact2 = ContactManager.Get(pid2)
		if contact1 and contact2 and contact1:isTruelyFriend(pid2) and contact2:isTruelyFriend(pid1) then
			FavorManager.AddFavor(pid1, pid2, source)
		end		
	end)

	-- 查询可以赠送的礼物
	service:on(Command.C_QUERY_GIFT_LIST_REQUEST, function (conn, pid, request)
		local cmd = Command.C_QUERY_GIFT_LIST_RESPOND
		log.debug(string.format("cmd: %d, player %d query presentable gift.", cmd, pid))

		if type(request) ~= "table" or #request < 1 then
			log.warning(string.format("cmd: %d, param error.", cmd))
			return conn:sendClientRespond(cmd, pid, { 1, Command.RET_PARAM_ERROR })
		end
		local sn = request[1]
		local ret = {}

		for id, _ in pairs(FavorConfig[3] or {}) do
			table.insert(ret, id)
		end
	
		conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS, ret })
	end)

	-- 赠送好友礼物
	service:on(Command.C_PRESENT_GIFT_REQUEST, function (conn, pid, request)
		local cmd = Command.C_PRESENT_GIFT_RESPOND
		log.debug(string.format("cmd: %d, player %d present gift.", cmd, pid))

		if type(request) ~= "table" or #request < 3 then
			log.warning(string.format("cmd: %d, param error.", cmd))
			return conn:sendClientRespond(cmd, pid, { 1, Command.RET_PARAM_ERROR })
		end
		local sn = request[1]
		local pid2 = request[2]
		local gift_id = request[3]

		local cfg = FavorConfig[3][gift_id]
		if not cfg then
			log.warning(string.format("cmd: %d, gift_id %d is not exist.", cmd, gift_id))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_EXIST })
		end
	
		local contact1 = ContactManager.Get(pid)
		local contact2 = ContactManager.Get(pid2)
		if not contact1 or not contact2 or not contact1:isTruelyFriend(pid2) or not contact2:isTruelyFriend(pid) then
			log.warning(string.format("cmd: %d, player1 %d and player2 %d is not friend.", cmd, pid, pid2))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_DEPEND })
		end

		-- 先消耗计数道具
		local code2 = cell.sendReward(pid, nil, { { type = cfg.consume_item_type2, id = cfg.consume_item_id2, value = cfg.consume_item_value2 } }, Command.REASON_FAVOR_GIFT2)
		if not code2 or code2.result ~= 0 then
			log.warning(string.format("cmd: %d, count item is not enough.", cmd))
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_NOT_ENOUGH })
		end

		-- 赠送礼物
		local code = cell.sendReward(pid, nil, { { type = cfg.consume_item_type1, id = cfg.consume_item_id1, value = cfg.consume_item_value1 } }, Command.REASON_FAVOR_GIFT)
		if code and code.result == 0 then
			FavorManager.AddFavor(pid, pid2, 3, gift_id)
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_SUCCESS })
		else
			log.warning(string.format("cmd: %d, player %d present %d failed.", cmd, pid, gift_id))
			-- 返还计数道具	
			cell.sendReward(pid, { { type = cfg.consume_item_type2, id = cfg.consume_item_id2, value = cfg.consume_item_value2 } }, nil, Command.REASON_FAVOR_GIFT2)
			return conn:sendClientRespond(cmd, pid, { sn, Command.RET_RESOURCES })
		end
	end)
end

return FavorManager
