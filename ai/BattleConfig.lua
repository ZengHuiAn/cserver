
require "protobuf"
require "ConditionConfig"
require "printtb"
local log = require "log"
local StableTime = require "StableTime"
local openServerTime = StableTime.get_open_server_time()
local get_begin_time_of_day = StableTime.get_begin_time_of_day

local BattleConfig = {}



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
	local content = f:read "*a"
	f:close()

	return protobuf.decode("com.agame.config." .. protocol, content);
end

local battles = {}
local fights = {}
local drops = {}
local groups = {}

local reference_time = 946656000 --2000-01-01

local cfg = readFile("../etc/config/team/config_team_battle_config.pb", "config_team_battle_config");
for _, v in ipairs(cfg.rows) do
	v.battle_id = v.battle_id or v.gid_id;

	if v.begin_time < reference_time then
		v.begin_time = get_begin_time_of_day(openServerTime) + v.begin_time
	end
	if v.end_time < reference_time then
		v.end_time = get_begin_time_of_day(openServerTime) + v.end_time 
	end	
	battles[v.battle_id] = { fights = {}, cfg = v }

	groups[v.battle_id] = { cfg = v}

	if v.difficult == 1 or v.difficult == 2 then --difficult 1 日常副本  2 一周副本
		LoadConditionConfigForTeamFight(v.battle_id)
	end
end


local cfg = readFile("../etc/config/team/config_team_pve_fight_config.pb", "config_team_pve_fight_config");
for _, v in ipairs(cfg.rows) do
	v.battle_id = v.battle_id or v.gid_id;
	fights[v.gid] = v;
	if v.battle_id > 0 then
		battles[v.battle_id].fights[v.gid] = v;
	end
end

function BattleConfig.Get(id)
	return fights[id];
end

function BattleConfig.GetBattleConfig(battle_id)
	return battles[battle_id] and battles[battle_id].cfg or nil
end

function BattleConfig.GetGroupConfig(group_id)
	return groups[group_id] and groups[group_id].cfg or nil
end

function BattleConfig.GetBattleFights(battle_id)
	return battles[battle_id] and battles[battle_id].fights or nil
end

function BattleConfig.CheckBattleOnTime(battle_id, time)
	if not battle_id then
		log.debug("check battle on time fail , battle_id is nil")
		return false 
	end

	time = time or loop.now()	
	log.debug(string.format("Begin check battle on time for battle:%d, time:%d", battle_id, time))

	local cfg = battles[battle_id] and battles[battle_id].cfg or nil
	if not cfg then
		log.debug(string.format("check battle on time fail , config for battle:%d is nil", battle_id))
		return false 
	end

	local beginTime = cfg.begin_time
	local endTime = cfg.end_time
	if (beginTime > 0 and time < beginTime) or (endTime > 0 and time > endTime) then
		log.debug(string.format("  not in time %d - %d", beginTime, endTime));
		return false 
	end

	local currentPeriod = math.ceil((time - beginTime) / cfg.duration_per_period)
	local validBeginTime = beginTime + (currentPeriod - 1) * cfg.duration_per_period
	local validEndTime = validBeginTime + cfg.valid_per_period;
	log.debug(string.format("beginTime:%d endTime:%d duration_per_period:%d valid_per_period:%d validBeginTime:%d   validEndTime:%d", beginTime, endTime, cfg.duration_per_period, cfg.valid_per_period, validBeginTime, validEndTime))
	if time >= validBeginTime and time <= validEndTime then
		return true 
	end
end

function BattleConfig.CheckNewPeriod(battle_id, ref_time, time)
	if not battle_id then
		log.debug("check new period fail , battle_id is nil")
		return false
	end

	-- log.debug(string.format("Begin check new period for battle:%d, ref_time:%d  time:%d", battle_id, ref_time, time))
	
	if ref_time > time then
		log.debug("check new period fail, ref_time > time")
		return false
	end

	local cfg = battles[battle_id] and battles[battle_id].cfg or nil
	if not cfg then
		log.debug(string.format("check new period fail , config for battle:%d is nil", battle_id))
		return false 
	end
	
	local beginTime = cfg.begin_time
	local endTime = cfg.end_time

	if ref_time < beginTime and (time >= beginTime and time <= endTime) then
		return true
	end

	if (ref_time >= beginTime and ref_time <= endTime) and (time >= beginTime and time <= endTime) then
		local ref_period = math.ceil((ref_time - beginTime) / cfg.duration_per_period)
		local period = math.ceil((time - beginTime) / cfg.duration_per_period)
		return ref_period ~= period	
	end

	return false
end

local BinaryConfig = require "BinaryConfig"

local npcConfig = nil
function LoadNpcConfig()
	local rows = BinaryConfig.Load("config_all_npc", "fight")	
	npcConfig = {}

	for _, row in ipairs(rows) do
		npcConfig[row.gid] = row
	end
end

LoadNpcConfig()

function BattleConfig.GetNpcConfig(id)
	return npcConfig[tonumber(id)]
end

function BattleConfig.GetBountyNpcPos(mapid)
	local pos = {{x = 0, y = 0, z= 0},  {x = 1, y = 0, z= 0}, {x = 2, y = 0, z= 0}, {x = 3, y = 0, z= 0}}
	for i = 1, 4, 1 do
		local gid = '4'..string.format("%03d", mapid)..tostring(989+i) 
		local npc_cfg = npcConfig[tonumber(gid)]
		if npc_cfg then
			pos[i] =  {x = npc_cfg.Position_x, y = npc_cfg.Position_z, z = npc_cfg.Position_y}
		end
	end
	
	return pos
end

local allPosConfig = nil
function LoadAllPosConfig()
	local rows = BinaryConfig.Load("config_all_position", "ai")
	allPosConfig = {}

	for _, row in ipairs(rows) do
		allPosConfig[row.map_id] = allPosConfig[row.map_id] or {}
		table.insert(allPosConfig[row.map_id], {x = row.Position_x, y = row.Position_z, z = row.Position_y})
	end
end

LoadAllPosConfig()

function BattleConfig.GetAllPosConfig(mapid)
	return allPosConfig[mapid] and allPosConfig[mapid] or nil
end

local activityConfig
function LoadActivityConfig()
	local rows = BinaryConfig.Load("config_all_activity", "fight")	
	activityConfig = {}

	for _, row in ipairs(rows) do
		activityConfig[row.id] = row
	end
end

LoadActivityConfig()

function BattleConfig.GetActivityConfig(id)
	return activityConfig[id]
end

quest_config = {}
local function load_quest_config()
	local rows = BinaryConfig.Load("config_bounty_quest", "bounty")	

	quest_config = {}
	quest_config.list = {}
    if rows then
        for _, row in ipairs(rows) do
			LoadConditionConfigForBounty(row.activity_id)
            quest_config.list[row.activity_id] = quest_config.list[row.activity_id] or { weight = 0 }
            quest_config.list[row.activity_id].active = quest_config.list[row.activity_id].active or {}
            local t = {
                id     = row.quest_id,
				map_id = row.map_id,
                weight = row.weight,
                count  = row.times,
                begin_time = row.begin_time,
                end_time = row.end_time,
            }
            table.insert(quest_config.list[row.activity_id].active, t)
            quest_config.list[row.activity_id].weight = quest_config.list[row.activity_id].weight + row.weight
        end
    end
end

load_quest_config()

function GetBountyQuestConfig(activity_id, quest_id)
	if not quest_config.list[activity_id] then
		return
	end

	for k, v in ipairs(quest_config.list[activity_id].active or {}) do
		if v.id == quest_id then
			return v
		end
	end
end

pos_config = {}
local function load_position_config()
	local rows = BinaryConfig.Load("config_random_position", "ai")	

	local t = {}
	pos_config.map_pool = {}
	pos_config.map = {}
	pos_config.npc = {}
	pos_config.guild = {}
    if rows then
        for _, row in ipairs(rows) do
			if row.type == 1 then
				pos_config.map[row.key_id] = pos_config.map[row.key_id] or {}
				table.insert(pos_config.map[row.key_id], {x = row.Position_x, y = row.Position_z, z = row.Position_y})
				if not t[row.key_id] then
					table.insert(pos_config.map_pool, row.key_id)
					t[row.key_id] = true
				end
			elseif row.type == 2 then
				pos_config.npc[row.key_id] = pos_config.npc[row.key_id] or {}
				table.insert(pos_config.npc[row.key_id], {x = row.Position_x, y = row.Position_z, z = row.Position_y})
			elseif row.type == 3 then
				pos_config.guild[row.key_id] = pos_config.guild[row.key_id] or {}
				table.insert(pos_config.guild[row.key_id], { x = row.Position_x, y = row.Position_z, z = row.Position_y })
			end
        end
    end
end

load_position_config()

function BattleConfig.GetPosCfg(id, type)
	id = tonumber(id)
	if type == 1 then
		if id ~= 0 then
			if pos_config.map[id] then
				local idx = math.random(1, #pos_config.map[id])
				return pos_config.map[id][idx], id
			end	
		else
			local idx = math.random(1, #pos_config.map_pool)
			local mid = pos_config.map_pool[idx]
			if pos_config.map[mid] then
				idx = math.random(1, #pos_config.map[mid])
				return pos_config.map[mid][idx], mid	
			end	
		end
		return nil
	elseif type == 2 then
		if pos_config.npc[id] then
			local idx = math.random(1, #pos_config.npc[id])
			return pos_config.npc[id][idx], id	
		end	
		return nil
	elseif type == 3 then
		if pos_config.guild[id] then
			local idx = math.random(1, #pos_config.guild[id])
			return pos_config.guild[id][idx], id
		end
		return nil	
	end
	
	return nil
end

function BattleConfig.CheckPosInFreeMoveMap(mapid, pos)
	for mid, v in pairs(pos_config.map) do
		if mapid == mid then
			for k2, v2 in ipairs(v) do	
				if v2.x == pos.x and v2.y == pos.y and v2.z == pos.z then
					return true
				end
			end
		end
	end 

	return false
end

local map_config 
local function load_map_config()
	local rows = BinaryConfig.Load("config_all_map", "ai")	

	map_config = {}
    if rows then
        for _, row in ipairs(rows) do
			map_config[row.gid] = map_config[row.gid] or {
				x = row.initialposition_x,
				y = row.initialposition_z,
				z = row.initialposition_y,
			}
        end
    end
end

load_map_config()

function BattleConfig.GetInitPos(mapid)
	if not map_config[mapid] then
		return nil		
	end

	return map_config[mapid]
end

local quest_config 
local function load_quest_config()
	local rows = BinaryConfig.Load("config_AI_tasksimulation", "ai")	

	quest_config = {}
    if rows then
        for _, row in ipairs(rows) do
			quest_config[row.step] = quest_config[row.step] or {
				mapid = row.mapID,
				x = row.posX,
				y = row.posZ,
				z = row.posY,
				min_time = row.minwaittime,
				max_time = row.maxwaittime,
				exp = row.exp,
				next_step = row.nextstep
			}
        end
    end
end

load_quest_config()

function BattleConfig.GetQuestConfig(step)
	if not quest_config[step] then
		return nil		
	end

	return quest_config[step]
end

local head_config 
local function load_head_config()
	local rows = BinaryConfig.Load("config_AI_image", "ai")	

	head_config = {}
    if rows then
        for _, row in ipairs(rows) do
			table.insert(head_config, {min = row.levelmin, max = row.levelmax, head = row.icon, model = row.model})
        end
    end
end

load_head_config()

function BattleConfig.GetHeadConfig(level)
	local t = {}
	for k, v in ipairs(head_config) do
		if level >= v.min and level <= v.max then
			table.insert(t, v)	
		end	
	end

	return #t > 0 and t or nil
end

return BattleConfig
