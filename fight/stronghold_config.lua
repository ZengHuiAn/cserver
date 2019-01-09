local protobuf = require "protobuf"
local cell = require "cell"

MapConfig = {}				-- 地图配置
PitfallConfig = {}			-- 系陷阱配置
ExchangeConfig = {}			-- 兑换配置
BossConfig = {}				-- BOSS配置
AttractConfig = {}			-- 诱敌配置
TimeConfig = {}				-- 时间配置
ResourceConfig = {}			-- 资源配置
PackageConfig = {}			-- 宝箱配置
BuffConfig = {}				-- buff配置
BossConditionConfig = {}		-- boss掉血掉落宝箱配置
GameRewardConfig = {}		-- 游戏结束奖励配置

math.randomseed(os.time())

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

----------------------------------------------------------------
function MapConfig.Load()
	local cfg = readFile("../etc/config/fight/config_hessboard.pb", "config_hessboard")
	if cfg then
		log.debug("load MapConfig success.")
		MapConfig.content = cfg.rows
	end
end

function MapConfig.IsEmpty()
	if not MapConfig.content or #MapConfig.content == 0 then
		return true
	end
	return false
end

function MapConfig.GetMap()
	if MapConfig.IsEmpty() then
		MapConfig.Load()
	end
	if MapConfig.content == nil then
		return nil
	end

	-- 资源类型池
	local type_pool = {1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1}

	-- 陷阱池
	local pitfall_pool = {1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 1, 2, 3, 4, 1, 2}

	local ret = {}
	for i, v in ipairs(MapConfig.content) do
		local resource_type = 0
		if v.Resources_type1 == 99 then
			local i = math.random(#type_pool)
			resource_type = type_pool[i]
			table.remove(type_pool, i)
		end
		-- 陷阱id
		local pitfall_type = 0
		if v.Is_Pitfall == 1 then	
			local i = math.random(#pitfall_pool)	
			pitfall_type = pitfall_pool[i]
			table.remove(pitfall_pool, i)
		end

		local t = { site_id = v.Site_id, site_type = v.Site_type, resource1_type = resource_type, resource1_value = v.Resources_value1, resource2_probability = v.Resources_probability, attract_value = 0,
		 	pitfall_type = pitfall_type, pitfall_level = 1, resource2_type = v.Resources_type2, resource2_value = v.Resources_value2, fight_probability = v.Probability, fight_id = v.Combat_id, 
			is_exchange = v.Is_exchange, box_id = 0, is_diversion = v.Is_diversion, last_collect_time = 0, site_status = 0, buff_id = 0 }
	
		if t.pitfall_type ~= 0 then	
			local pitfall = PitfallConfig.GetDamage(t.pitfall_type, t.pitfall_level)
			t.buff_id = BuffConfig.GetRandomBuff(pitfall.buff_id).Id
		end
		ret[v.Site_id] = t
	end

	return ret
end

function MapConfig.GetRouteRelation()
	if MapConfig.route then
		return MapConfig.route
	end
	
	local route = {}
	
	route[10001] = { next1 = 10002, next2 = 10003, next3 = 10004 }	

	route[10002] = { next1 = 10005 }
	route[10003] = { next1 = 10005, next2 = 10006 }
	route[10004] = { next1 = 10006 }
	
	route[10005] = { previous1 = 10002, previous2 = 10003, next1 = 10007, next2 = 10008 }
	route[10006] = { previous1 = 10003, previous2 = 10004, next1 = 10008, next2 = 10009 }

	route[10007] = { previous1 = 10005, next1 = 10010 }
	route[10008] = { previous1 = 10005, previous2 = 10006, next1 = 10010, next2 = 10011 }
	route[10009] = { previous1 = 10006, next1 = 10011 }

	route[10010] = { previous1 = 10007, previous2 = 10008, next1 = 10012, next2 = 10013 }
	route[10011] = { previous1 = 10008, previous2 = 10009, next1 = 10013, next2 = 10014 }

	route[10012] = { previous1 = 10010, next1 = 10015 }
	route[10013] = { previous1 = 10010, previous2 = 10011, next1 = 10015 }
	route[10014] = { previous1 = 10011, next1 = 10015 }	
	
	MapConfig.route = route

	return MapConfig.route
end

function MapConfig.GetNearSites(point)
	local route = MapConfig.GetRouteRelation()
	if not route then
		return {}
	end
	local site = route[point]
	if not site[point] then
		return {}
	end

	local ret = {}
	if site[point].next1 then
		table.insert(ret, site[point].next1)
	end		

	if site[point].next2 then
		table.insert(ret, site[point].next2)
	end		
	if site[point].previous1 then
		table.insert(ret, site[point].previous1)
	end		
	if site[point].previous2 then
		table.insert(ret, site[point].previous2)
	end		

	return ret	
end

function MapConfig.GetOrigin()
	return 10001
end

function MapConfig.GetEnd()
	return 10015
end

function MapConfig.GetRefreshSite()
	if MapConfig.IsEmpty() then
		MapConfig.Load()
	end

	local ret = {}
	for i, v in ipairs(MapConfig.content) do
		if v.Site_id ~= MapConfig.GetOrigin() and v.Site_id ~= MapConfig.GetEnd() then
			table.insert(ret, v.Site_id)	
		end
	end
	
	return ret
end

--------------------------------------------------------------------
function PitfallConfig.Load()
	local cfg = readFile("../etc/config/fight/config_hessboard_pitfall.pb", "config_hessboard_pitfall")
	if cfg then
		log.debug("load PitfallConfig success.")
		PitfallConfig.content = {}	
		for i, v in ipairs(cfg.rows) do
			PitfallConfig.content[v.Pitfall_type] = PitfallConfig.content[v.Pitfall_type] or {}
			local t = { air = v.Type1, air_damage = v.Value1, dirt = v.Type2, dirt_damage = v.Value2, water = v.Type3, water_damage = v.Value3, 
				fire = v.Type4, fire_damage = v.Value4, light = v.Type5, light_damage = v.Value5, dark = v.Type6, dark_damage = v.Value6, consume_type1 = v.Consume_type1, 
				consume_value1 = v.Consume_value1, consume_type2 = v.Consume_type2, consume_value2 = v.Consume_value2, buff_id = v.Buff_id, is_buff = v.Is_buff, time_cd = v.Time_cd }
			PitfallConfig.content[v.Pitfall_type][v.Pitfall_level] = t
		end
	end
end

function PitfallConfig.IsEmpty()
	if not PitfallConfig.content then
		return true
	end
	return false
end

-- 获得对boss的损伤效果
function PitfallConfig.GetDamage(type, level)
	if PitfallConfig.IsEmpty() then
		PitfallConfig.Load()
	end

	return PitfallConfig.content[type][level]
end

function PitfallConfig.GetCD(type, level)	
	if PitfallConfig.IsEmpty() then
		PitfallConfig.Load()
	end

	local t = PitfallConfig.content[type][level]

	return t and t.time_cd or 0
end

--------------------------------------------------------------------
function ExchangeConfig.Load()
	local cfg = readFile("../etc/config/fight/config_hessboard_exchange.pb", "config_hessboard_exchange")
	if cfg then
		log.debug("load ExchangeConfig success.")
		ExchangeConfig.content = {}
		for i, v in ipairs(cfg.rows) do 
			ExchangeConfig.content[v.Resource_id] = { exchange_resource1 = v.Exchange_resource1, resource_value1 = v.Exchange_resource1, 
					exchange_resource2 = v.Exchange_resource2, resource_value2 = v.Exchange_resource2, time_cd = v.Time_cd }
		end
	end
end

function ExchangeConfig.IsEmpty()
	if not ExchangeConfig.content then
		return true
	end
	return false
end

function ExchangeConfig.GetCD()
	if ExchangeConfig.IsEmpty() then
		ExchangeConfig.Load()
	end

	return ExchangeConfig.content[1].time_cd
end

--------------------------------------------------------------------
function BossConfig.Load()
	local cfg = readFile("../etc/config/fight/config_hessboard_monster.pb", "config_hessboard_monster")
	if cfg then
		log.debug("load BossConfig success.")
		BossConfig.content = {}
		for i, v in ipairs(cfg.rows) do
			BossConfig.content[v.Id] = { mode = v.Monster_mode, type = v.Monster_type, hp = v.Monster_hp, 
				player_incident1 = v.Player_incident1, player_incident2 = v.Player_incident2, player_incident3 = v.Player_incident3, player_incident4 =  v.Player_incident4 }
		end
	end
end

function BossConfig.IsEmpty()
	if not BossConfig.content then
		return true
	end
	return false
end

function BossConfig.GetBoss(id)
	if BossConfig.IsEmpty() then
		BossConfig.Load()
	end

	return BossConfig.content[id]
end


function BossConfig.GetBossIdList()
	if BossConfig.IsEmpty() then
		BossConfig.Load()
	end

	local ret = {}

	for i, v in pairs(BossConfig.content) do
		table.insert(ret, i)
	end

	return ret
end

function BossConfig.GetRandomIncident(boss_id)
	if BossConfig.IsEmpty() then
		BossConfig.Load()
	end

	local boss = BossConfig.content[boss_id]
	if boss then
		local t = { boss.player_incident1, boss.player_incident2, boss.player_incident3, boss.player_incident4 }
		local i = math.random(#t)
		return t[i]
	else
		return 0
	end
end

--------------------- 诱敌配置 ---------------------------
function AttractConfig.Load()	
	local cfg = readFile("../etc/config/fight/config_diversion.pb", "config_diversion")
	if cfg then
		log.debug("load AttractConfig success.")
		AttractConfig.content = cfg.rows
	end
end

function AttractConfig.IsEmpty()
	if not AttractConfig.content or #AttractConfig.content == 0 then
		return true
	end
	return false
end

function AttractConfig.GetAttractConfig()
	if AttractConfig.IsEmpty() then
		AttractConfig.Load()
	end

	return AttractConfig.content[1]
end

function AttractConfig.GetCD()
	if AttractConfig.IsEmpty() then
		AttractConfig.Load()
	end

	return AttractConfig.content[1].Time_cd
end

-------------------- 时间配置 ----------------------------
function TimeConfig.Load()
	local cfg = readFile("../etc/config/fight/config_hessboard_time.pb", "config_hessboard_time")
	if cfg then
		log.debug("load TimeConfig success.")
		TimeConfig.content = {}
		for i, v in ipairs(cfg.rows) do
			TimeConfig.content[v.Type] = TimeConfig.content[v.Type] or {}
			table.insert(TimeConfig.content[v.Type], { monster_id = v.Monster_id, move_time = v.Move_time, stay_time = v.Stay_time, gather_time = v.Gather_time, move_cd = v.Move_cd, 
			resource_time = v.Resoure_produce_time, incident1_time = v.incident1_time, incident2_time = v.incident2_time,
			incident3_time = v.incident3_time, Openbox_time = v.Openbox_time, Repair_time = v.Repair_time, Imprison_time = v.Imprison_time, Forbid_time = v.Forbid_time })
		end
	end
end

function TimeConfig.IsEmpty()
	if not TimeConfig.content or #TimeConfig.content == 0 then
		return true
	end
	return false
end

function TimeConfig.GetMoveCD()
	if TimeConfig.IsEmpty() then
		TimeConfig.Load()
	end

	return TimeConfig.content[2][1].move_cd / 1000
end


function TimeConfig.GetGatherCD()
	if TimeConfig.IsEmpty() then
		TimeConfig.Load()
	end

	return TimeConfig.content[2][1].gather_time / 1000
end

function TimeConfig.GetBossMoveTime(boss_id)
	if TimeConfig.IsEmpty() then
		TimeConfig.Load()
	end
	
	for i, v in pairs(TimeConfig.content[1]) do
		if boss_id == v.monster_id then
			return v.move_time / 1000	
		end
	end

	return 0
end

function TimeConfig.GetBossStayTime(boss_id)
	if TimeConfig.IsEmpty() then
		TimeConfig.Load()
	end
	
	for i, v in pairs(TimeConfig.content[1]) do
		if boss_id == v.monster_id then
			return v.stay_time / 1000	
		end
	end

	return 0
end

function TimeConfig.GetResourceProduceTime()
	if TimeConfig.IsEmpty() then
		TimeConfig.Load()
	end

	local t = TimeConfig.content[3][1]

	return t and t.resource_time / 1000 or 0 
end

function TimeConfig.GetRandomIncident(boss_id)	
	if TimeConfig.IsEmpty() then
		TimeConfig.Load()
	end

	for i, v in pairs(TimeConfig.content[1]) do
		if boss_id == v.monster_id then
			local t = {}
			table.insert(t, { 1, v.incident1_time })	
			table.insert(t, { 2, v.incident2_time })	
			table.insert(t, { 3, v.incident3_time })
			local n = math.random(#t)
			return t[n]	
		end
	end

	return {}
end

function TimeConfig.GetDestroyTime(boss_id)
	if TimeConfig.IsEmpty() then
		TimeConfig.Load()
	end

	for i, v in pairs(TimeConfig.content[1]) do
		if boss_id == v.monster_id then
			return v.incident1_time / 1000
		end
	end
	return 0
end

function TimeConfig.GetPlayerMoveTime()
	if TimeConfig.IsEmpty() then
		TimeConfig.Load()
	end
	
	local config = TimeConfig.content[2][1]
	if config then
		return config.move_time / 1000
	else
		return 0
	end	
end

function TimeConfig.GetPlayerDebarTime()	
	if TimeConfig.IsEmpty() then
		TimeConfig.Load()
	end
	
	local config = TimeConfig.content[2][1]
	if config then
		return config.Imprison_time / 1000
	else
		return 0
	end
end

function TimeConfig.GetPlayerForbiddenTime()	
	if TimeConfig.IsEmpty() then
		TimeConfig.Load()
	end

	local config = TimeConfig.content[2][1]
	if config then
		return config.Forbid_time / 1000
	else
		return 0
	end
end

---------------------- 资源配置 ----------------------------------
function ResourceConfig.Load()
	local cfg = readFile("../etc/config/fight/config_hessboard_resoure.pb", "config_hessboard_resoure")
	if cfg then
		log.debug("load ResourceConfig success.")
		ResourceConfig.content = {}
		for i, v in ipairs(cfg.rows) do
			ResourceConfig.content[v.Resource_id] = { Resource_limit = v.Resource_limit, Resource_exp = v.Resource_exp, Resource_limitexp = v.Resource_limitexp }
		end
	end
end

function ResourceConfig.IsEmpty()
	if not ResourceConfig.content or #ResourceConfig.content == 0 then
		return true
	end

	return false
end

function ResourceConfig.GetResourceIdList()
	if ResourceConfig.IsEmpty() then
		ResourceConfig.Load()
	end	

	local ret = {}
	for i, v in pairs(ResourceConfig.content) do 
		table.insert(ret, i)
	end

	return ret
end

function ResourceConfig.GetExperiment(id)
	if ResourceConfig.IsEmpty() then
		ResourceConfig.Load()
	end	
	
	local t = ResourceConfig.content[id]

	return t and t.Resource_exp or 0
end

function ResourceConfig.GetExpLimit(id)
	if ResourceConfig.IsEmpty() then
		ResourceConfig.Load()
	end

	local t = ResourceConfig.content[id]

	return t and t.Resource_limitexp or 0
end

----------------------------- 宝箱配置 --------------------------------
function PackageConfig.Load()
	local cfg = readFile("../etc/config/fight/config_hessboard_package.pb", "config_hessboard_package")
	if cfg then
		log.debug("load PackageConfig success.")
		PackageConfig.content = {}
		for i, v in ipairs(cfg.rows) do
			PackageConfig.content[v.Id] = { type = v.Type, item_type1 = v.Item_type, item_id1 = v.Item_id, item_value1 = v.Item_value, 
				item_type2 = v.Item_type2, item_id2 = v.Item_id2, item_value2 = v.Item_value2 }
		end
	end
end

function PackageConfig.IsEmpty()
	if PackageConfig.content == nil or #PackageConfig.content == 0 then
		return true
	end
	return false
end

function PackageConfig.GetPackageIdList(type)
	if PackageConfig.IsEmpty() then
		PackageConfig.Load()
	end
	
	local ret = {}

	for i, v in pairs(PackageConfig.content) do
		if v.type == type then
			table.insert(ret, i)
		end
	end
	
	return ret
end

function PackageConfig.GetReward(reward_id)
	if PackageConfig.IsEmpty() then
		PackageConfig.Load()
	end
	local ret = {}
	local t = PackageConfig.content[reward_id]
	if t then
		if t.item_type1 > 0 then
			table.insert(ret, { type = t.item_type1, id = t.item_id1, value = t.item_value1 })
		end
		if t.item_type2 > 0 then
			table.insert(ret, { type = t.item_type2, id = t.item_id2, value = t.item_value2 })
		end
	end

	return ret
end

-------------------------- buff 配置 ------------------------------
function BuffConfig.Load() 	
	local cfg = readFile("../etc/config/fight/config_hessboard_buff.pb", "config_hessboard_buff")

	if cfg then
		log.debug("load BuffConfig success.")
		BuffConfig.content = cfg.rows
	end
end

function BuffConfig.IsEmpty()
	if BuffConfig.content == nil or #BuffConfig.content == 0 then
		return true
	end

	return false
end

function BuffConfig.Count()
	if BuffConfig.IsEmpty() then
		BuffConfig.Load()
	end
	return #BuffConfig.content
end

-- m^n
local function exp(m, n)
	local num = 1
	for i = 1, n do
		num = num * m 
	end

	return num
end

function BuffConfig.GetRandomBuff(num)
	local tn = BuffConfig.Count()
	num = num % exp(2, tn)
	local t = {}
	for i = 1, tn do
		if math.floor(num / exp(2, tn - i)) == 1 then
			table.insert(t, i)	
		end
		num = num % exp(2, tn - i)
	end
	local ran = math.random(#t)
	
	return BuffConfig.content[ran]	
end

function BuffConfig.GetBuff(id)
	for _, v in ipairs(BuffConfig.content) do
		if id == v.Id then
			return v
		end
	end
	return nil
end

----------------------------------------------------------------------
function BossConditionConfig.Load()	
	local cfg = readFile("../etc/config/fight/config_monster_condition.pb", "config_monster_condition")

	if cfg then 
		log.debug("load BossConditionConfig success.")
		BossConditionConfig.content = {}
		for i, v in ipairs(cfg.rows) do
			BossConditionConfig.content[v.Hp] = { type1 = v.Type1, type2 = v.Type2, type3 = v.Type3, type4 = v.Type4, type5 =v.Type5, type6 = v.Type6, type7 = v.Type7, drop = v.Drop }
		end
	end
end

function BossConditionConfig.IsEmpty()
	if BossConditionConfig.content == nil then
		return true
	end	

	return false
end

function BossConditionConfig.GetTypeList(condition)
	if BossConditionConfig.IsEmpty() then
		BossConditionConfig.Load()
	end

	local t = BossConditionConfig.content[condition]
	if t then
		return { t.type1, t.type2, t.type3, t.type4, t.type5, t.type6, t.type7 }
	end

	return nil
end

function BossConditionConfig.GetRewardId(condition)
	if BossConditionConfig.IsEmpty() then
		BossConditionConfig.Load()
	end

	local t = BossConditionConfig.content[condition]

	return t and t.drop or 0
end

--------------------------------------------------------
function GameRewardConfig.Load()
	local cfg = readFile("../etc/config/fight/config_fight_reward.pb", "config_fight_reward")

	if cfg then
		log.debug("load config_fight_reward success.")
		local temp = {}
		for i, v in ipairs(cfg.rows) do
			temp[v.drop_id] = temp[v.drop_id] or {}
			temp[v.drop_id][v.group] = temp[v.drop_id][v.group] or {}
			table.insert(temp[v.drop_id][v.group], { type = v.type, id = v.id, min_value = v.min_value, max_value = v.max_value, min_incr = v.min_incr, max_incr = v.max_incr })
		end
		GameRewardConfig.content = temp
	end
end

function GameRewardConfig.IsEmpty()
	if GameRewardConfig.content == nil then
		return true
	end
	return false
end

function GameRewardConfig.GetReward(drop_id, pid)
	if GameRewardConfig.IsEmpty() then
		GameRewardConfig.Load()
	end

	local temp = GameRewardConfig.content[drop_id]
	if temp == nil then
		return {}
	end

	
	local info = cell.getPlayerInfo(pid)
	local level = 0
	if info then
		level = info.level
	else
		log.warning("GameRewardConfig.GetReward: get player info failed.")
	end		

	local ret = {}
	for i, v in pairs(temp) do
		local n = math.random(#v)
		local t = v[n]
		
		local value = t.min_value + t.min_incr * level
		table.insert(ret, { type = t.type, id = t.id, value = value })
	end

	return ret
end
