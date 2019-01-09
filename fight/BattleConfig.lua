
require "protobuf"
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
end


local cfg = readFile("../etc/config/team/config_team_pve_fight_config.pb", "config_team_pve_fight_config");
for _, v in ipairs(cfg.rows) do
	v.battle_id = v.battle_id or v.gid_id;
	fights[v.gid] = v;

	if v.battle_id > 0 then
		if not battles[v.battle_id] then
			log.error(string.format('battle %d of team fight %d not exists', v.battle_id, v.gid));
		end

		battles[v.battle_id].fights[v.gid] = v;
	end
end


local team_fight_score_config = {}

local cfg = readFile("../etc/config/team/team_fight_score.pb", "team_fight_score");
for _, v in ipairs(cfg.rows) do
	team_fight_score_config[v.type] = team_fight_score_config[v.type] or {}

	team_fight_score_config[v.type][v.lv] = {
		damage = v.damage_coefficient,
		health = v.treat_coefficient,
		dead   = v.death_coefficient,

		rating = {
			v.sss_min,
			v.ss_min,
			v.s_min,
			v.a_min,
			v.b_min,
			v.c_min,
			v.d_min,
		}
	}
end

function BattleConfig.Get(id)
	return fights[id];
end

function BattleConfig.GetTeamFightScoreConfig(type, level)
	if not type or not team_fight_score_config[type] then
		return;
	end
	return  team_fight_score_config[type][level];
end

function BattleConfig.GetBattleConfig(battle_id)
	return battles[battle_id] and battles[battle_id].cfg or nil
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

return BattleConfig
