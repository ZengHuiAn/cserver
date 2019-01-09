local database = require "database"

---------------------------- 玩家数据库表操作 -------------------------
PlayerTable = {}
function PlayerTable.Insert(info)
	local ok = database.update([[replace into `defend_player_info`(`pid`, `box_count`, `box_deadtime`, `team_id`, `player_index`, `collect_count`, `pitfall_time`, `attract_time`, `exchange_time`, 
	`move_time`,`collect_time`, `reward_id`, `exp_limit`, `is_stay`, `stay_time`, `last_index`) 
	values(%d, %d, from_unixtime_s(%d), %d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), from_unixtime_s(%d), %d, %d, %d, from_unixtime_s(%d), %d);]],
	info.pid, info.box_count, info.box_deadtime, info.team_id, info.player_index, info.collect_count, info.pitfall_time, info.attract_time, info.exchange_time, info.move_time, info.collect_time, 
	info.reward_id, info.exp_limit, info.is_stay, info.stay_time, info.last_index)
	if ok then
		log.debug("replace into defend_player_info success: ", info.pid)
	end

	return ok
end

function PlayerTable.Select(pid)
	local ok, result = database.query([[select `pid`, `box_count`, unix_timestamp(`box_deadtime`) as `box_deadtime`, `team_id`, `player_index`, `collect_count`,
	unix_timestamp(`pitfall_time`) as `pitfall_time`, unix_timestamp(`attract_time`) as `attract_time`, unix_timestamp(`exchange_time`) as `exchange_time`, unix_timestamp(`move_time`) as `move_time`,
	unix_timestamp(`collect_time`) as `collect_time`, `reward_id`, `exp_limit`, `is_stay`, unix_timestamp(`stay_time`) as `stay_time`, `last_index` from `defend_player_info` where `pid` = %d;]], pid)
	if ok and #result > 0 then
		return result[1] 
	end
	return nil	
end

function PlayerTable.UpdateCollectCount(pid, n)
	local ok = database.update("update `defend_player_info` set `collect_count` = %d where `pid` = %d;", n, pid)
	if ok then
		log.debug("update defend_player_info set collect_count success: ", pid, n)		
	end

	return ok
end

function PlayerTable.UpdatePosition(pid, p)
	local ok = database.update("update `defend_player_info` set `player_index` = %d where `pid` = %d;", p, pid)
	if ok then
		log.debug("update `defend_player_info` set `player_index` success: ", pid, p)
	end

	return ok
end

function PlayerTable.UpdateMoveTime(pid, time)
	local ok = database.update("update `defend_player_info` set `move_time` = from_unixtime_s(%d) where `pid` = %d;", time, pid)
	if ok then
		log.debug("update defend_player_info move_time success.")
	end
	
	return ok
end

function PlayerTable.UpdateCollectTime(pid, time)
	local ok = database.update("update `defend_player_info` set `collect_time` = from_unixtime_s(%d) where `pid` = %d;", time, pid)
	if ok then
		log.debug("update defend_player_info collect_time success.")
	end
	
	return ok
end

function PlayerTable.UpdatePitfallTime(pid, time)
	local ok = database.update("update `defend_player_info` set `pitfall_time` = from_unixtime_s(%d) where `pid` = %d;", time, pid)
	if ok then
		log.debug("update defend_player_info pitfall_time success.")
	end
	
	return ok
end

function PlayerTable.UpdateExchangeTime(pid, time)
	local ok = database.update("update `defend_player_info` set `exchange_time` = from_unixtime_s(%d) where `pid` = %d;", time, pid)
	if ok then
		log.debug("update defend_player_info exchange_time success.")
	end
	
	return ok
end

function PlayerTable.UpdateAttractTime(pid, time)
	local ok = database.update("update `defend_player_info` set `attract_time` = from_unixtime_s(%d) where `pid` = %d;", time, pid)
	if ok then
		log.debug("update defend_player_info attract_time success.")
	end
	
	return ok
end

function PlayerTable.UpdateRewardId(pid, reward_id)
	local ok = database.update("update `defend_player_info` set `reward_id` = %d where `pid` = %d;", reward_id, pid)
	if ok then
		log.debug("update defend_player_info set reward_id success: ", pid, reward_id)
	end

	return ok
end

function PlayerTable.UpdateBoxCount(pid, n)	
	local ok = database.update("update `defend_player_info` set `box_count` = %d where `pid` = %d;", n, pid)
	if ok then
		log.debug("update defend_player_info set box_count success: ", pid, n)
	end

	return ok
end

function PlayerTable.UpdateDeadTime(pid, time)
	local ok = database.update("update `defend_player_info` set `box_deadtime` = from_unixtime_s(%d) where `pid` = %d;", time, pid)
	if ok then
		log.debug("update defend_player_info set box_deadtime success.")
	end

	return ok
end

function PlayerTable.UpdateExperimentLimit(pid, limit)
	local ok = database.update("update `defend_player_info` set `exp_limit` = from_unixtime_s(%d) where `pid` = %d;", limit, pid)
	if ok then
		log.debug("update defend_player_info set exp_limit success.")
	end

	return ok
end

function PlayerTable.Delete(pid)
	local ok = database.update("delete from `defend_player_info` where `pid` = %d;", pid)
	if ok then
		log.debug("delete player success: pid = ", pid)
	end

	return ok
end

function PlayerTable.RemoveTeamInfo(pid)
	local ok = database.update([[update `defend_player_info` set `team_id` = %d, `player_index` = %d, `collect_count` = %d, `pitfall_time` = from_unixtime_s(%d), `attract_time` = from_unixtime_s(%d), 
		`exchange_time` = from_unixtime_s(%d), `move_time` = from_unixtime_s(%d), `collect_time` = from_unixtime_s(%d), `reward_id` = %d, `is_stay` = %d, `stay_time` = from_unixtime_s(%d), `last_index` = %d
		where `pid` = %d;]], 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, pid)
	if ok then
		log.debug("remove team info success.")
	end

	return ok	
end

function PlayerTable.UpdateStayStatus(pid, status, time)
	local ok = database.update([[update `defend_player_info` set `is_stay` = %d, `stay_time` = from_unixtime_s(%d) where `pid` = %d;]], status, time, pid)
	if ok then
		log.debug("update `defend_player_info` set `is_stay` and `stay_time` success: ", pid, status, time)
	end

	return ok
end

function PlayerTable.UpdateLastIndex(pid, index)
	local ok = database.update("update `defend_player_info` set `last_index` = %d where `pid` = %d;", index, pid)
	if ok then
		log.debug("update `defend_player_info` set `last_index` success: ", pid, index)
	end
	
	return ok
end

---------------------------- 队伍数据库表操作 -------------------------
TeamTable = {}
function TeamTable.Insert(team)
	local ok = database.update([[insert into `defend_team_info`(`team_id`, `player_id1`, `player_id2`, `player_id3`, `player_id4`, `player_id5`, `boss_id`, `boss_mode`, `boss_type`, `boss_hp`, `boss_index`, 
	`game_begin`, `boss_status`, `begin_time`, `last_index`) values(%d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), %d, from_unixtime_s(%d), %d);]],
	team.team_id, team.player_id1, team.player_id2, team.player_id3, team.player_id4, team.player_id5, team.boss_id, team.boss_mode, team.boss_type, team.boss_hp, team.boss_index, 
	team.game_begin, team.boss_status, team.begin_time, team.last_index)
	if ok then 
		log.debug("insert into defend_team_info success.")
	end

	return ok
end

function TeamTable.SelectTeamId(pid_list)
	local pid1 = pid_list[1] or 0
  	local pid2 = pid_list[2] or 0
  	local pid3 = pid_list[3] or 0
  	local pid4 = pid_list[4] or 0
  	local pid5 = pid_list[5] or 0
	local ok, result = database.query("select `team_id` from `defend_team_info` where `player_id1` = %d and `player_id2` = %d and `player_id3` = %d and `player_id4` = %d and `player_id5` = %d;", pid1, pid2, pid3, pid4, pid5)
	if ok and #result > 0 then
		return result[1].team_id
	end

	return 0
end

function TeamTable.Select(team_id)
	local ok, result = database.query([[select `team_id`,`player_id1`, `player_id2`, `player_id3`, `player_id4`, `player_id5`, `boss_id`, `boss_mode`, `boss_type`, `boss_hp`, 
	`boss_index`, unix_timestamp(`game_begin`) as `game_begin`, `boss_status`, unix_timestamp(`begin_time`) as `begin_time`, `last_index` from `defend_team_info` where `team_id` = %d;]],
			team_id)
	if ok and #result > 0 then
		return result[1]
	end

	return nil
end

function TeamTable.UpdateBossIndex(team_id, index)
	local ok = database.update("update `defend_team_info` set `boss_index` = %d where `team_id` = %d;", index, team_id)
	if ok then
		log.debug("update `defend_team_info` set `boss_index` success:  ", team_id, index)
	end	
	return ok
end

function TeamTable.UpdateBossHp(team_id, hp)
	local ok = database.update("update `defend_team_info` set `boss_hp` = %d where `team_id` = %d;", hp, team_id)
	if ok then
		log.debug("update defend_team_info set boss_hp success: ", team_id, hp)
	end

	return ok
end

function TeamTable.UpdateBossStatus(team_id, status, time)
	local ok = database.update("update `defend_team_info` set `boss_status` = %d, `begin_time` = from_unixtime_s(%d) where `team_id` = %d;", status, time, team_id)
	if ok then
		log.debug("update `defend_team_info` set boss_status success: ", team_id, status, time)
	end

	return ok
end

function TeamTable.UpdateLastIndex(team_id, index)
	local ok = database.update("update `defend_team_info` set `last_index` = %d where `team_id` = %d;", index, team_id)
	if ok then
		log.debug("update `defend_team_info` set `last_index` success: ", team_id, index)
	end

	return ok
end

function TeamTable.Delete(team_id)
	local ok = database.update("delete from `defend_team_info` where `team_id` = %d;", team_id)
	if ok then
		log.debug("delete defend_team_info success: team_id = ", team_id)
	end

	return ok
end

---------------------------- 队伍地图数据库表操作 ---------------------
MapTable = {}
function MapTable.Select(team_id)
	local ok, result = database.query([[select `site_id`, `site_type`, `resource1_type`, `resource1_value`, `resource2_type`, `resource2_value`, `resource2_probability`, `fight_probability`,
		`fight_id`, `pitfall_type`, `pitfall_level`, `attract_value`, `box_id`, `is_exchange`, `is_diversion`, unix_timestamp(`last_collect_time`) as `last_collect_time`, 
		`site_status`, `buff_id` from `defend_team_map` where `team_id` = %d;]], team_id)
	local ret = {}
	if ok and #result > 0 then
		log.debug("select defend_team_map success: team_id = ", team_id)
		for i, v in ipairs(result) do
			ret[v.site_id] = { site_type = v.site_type, resource1_type = v.resource1_type, resource1_value = v.resource1_value, resource2_type = v.resource2_type, resource2_value = v.resource2_value,
			resource2_probability = v.resource2_probability, fight_probability = v.fight_probability, fight_id = v.fight_id, pitfall_type = v.pitfall_type, pitfall_level = v.pitfall_level, 
			attract_value = v.attract_value, box_id = v.box_id, is_exchange = v.is_exchange, is_diversion = v.is_diversion, last_collect_time = v.last_collect_time, site_status = v.site_status,
			buff_id = v.buff_id }
		end
	end

	return ret
end

local function Push(t1, t2)
	for _, v in ipairs(t2) do
		table.insert(t1, v)
	end
end

function MapTable.InsertMap(team_id, map)
	if not map or not team_id then
		return
	end
	
	local sql = [[replace into `defend_team_map`(`team_id`, `site_id`, `site_type`, `resource1_type`, `resource1_value`, `resource2_type`, `resource2_value`,
		`resource2_probability`, `fight_probability`, `fight_id`, `pitfall_type`, `pitfall_level`, `attract_value`, `box_id`, `is_exchange`, `is_diversion`, `last_collect_time`, `site_status`, 
		`buff_id`) values]]
	local str = [[(%d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, from_unixtime_s(%d), %d, %d)]]
	local para_list = {}
	for i, v in pairs(map) do
		sql = sql .. str .. ","
				
		local t =  { team_id, v.site_id, v.site_type, v.resource1_type, v.resource1_value, v.resource2_type, v.resource2_value, v.resource2_probability, v.fight_probability, v.fight_id,
		v.pitfall_type, v.pitfall_level, v.attract_value, v.box_id, v.is_exchange, v.is_diversion, v.last_collect_time, v.site_status, v.buff_id }
		Push(para_list, t)
	end	
	sql = string.sub(sql, 1, string.len(sql) - 1)
	local ok = database.update(sql, unpack(para_list))

	if ok then
		log.debug("replace into defend_team_map success: team_id =  ", team_id)
	end
end

-- 更新陷阱等级
function MapTable.UpdateLevel(team_id, site, level)
	local ok = database.update("update `defend_team_map` set `pitfall_level` = %d where `team_id` = %d and `site_id` = %d;", level, team_id, site)
	if ok then 
		log.debug("update defend_team_map set pitfall_level success:  ", team_id, site, level)
	end

	return ok
end

-- 更新诱敌诱敌率
function MapTable.UpdateAttactValue(team_id, site, value)
	local ok = database.update("update `defend_team_map` set `attract_value` = %d where `team_id` = %d and `site_id` = %d;", value, team_id, site)
	if ok then
		log.debug("update `defend_team_map` set `attract_value` success: ", team_id, site, value)
	end

	return ok
end

function MapTable.UpdateBoxId(team_id, site, box_id)	
	local ok = database.update("update `defend_team_map` set `box_id` = %d where `team_id` = %d and `site_id` = %d;", box_id, team_id, site)
	if ok then
		log.debug("update `defend_team_map` set `box_id` success: ", team_id, site, box_id)
	end

	return ok
end

function MapTable.Delete(team_id)
	local ok = database.update("delete from `defend_team_map` where `team_id` = %d;", team_id)
	if ok then
		log.debug("delete from `defend_team_map` success: team_id = ", team_id)
	end

	return ok
end

function MapTable.UpdateResourceType(team_id, site_id, type1)	
	local ok = database.update("update `defend_team_map` set `resource1_type` = %d where `team_id` = %d and `site_id` = %d;", type1, team_id, site_id)
	if ok then
		log.debug("update `defend_team_map` set `resource1_type` success: ", team_id, site_id, type1)
	end

	return ok
end


function MapTable.UpdateLastCollectTime(team_id, site_id, time)	
	local ok = database.update("update `defend_team_map` set `last_collect_time` = %d where `team_id` = %d and `site_id` = %d;", time, team_id, site_id)
	if ok then
		log.debug("update `defend_team_map` set `last_collect_time` success: ", team_id, site_id, time)
	end

	return ok
end

function MapTable.UpdateSiteStatus(team_id, site_id, status)
	local ok = database.update([[update `defend_team_map` set `site_status` = %d where `team_id` = %d and `site_id` = %d;]], status, team_id, site_id)
	if ok then
		log.debug("update `defend_team_map` set `site_status` success: ", team_id, site_id, status)
	end

	return ok
end

--------------------------- 队伍资源数据库操作 ---------------------------
TeamResourceTable = {}
function TeamResourceTable.Select(team_id)
	local ok, result = database.query("select * from `defend_team_resource` where `team_id` = %d;", team_id)
	local ret = {}
	if ok and #result then
		for i, v in ipairs(result) do
			ret[v.resource_id] = v.resource_value
		end
	end

	return ret
end

function TeamResourceTable.Insert(team_id, resource)
	if not resource or not team_id then
		return
	end

	local ok = database.update("insert into `defend_team_resource`(`team_id`, `resource_id`, `resource_value`) values(%d, %d, %d);", team_id, resource.resource_id, resource.resource_value)
	if ok then
		log.debug("insert into `defend_team_resource` success, team_id = ", team_id)
	end
end

function TeamResourceTable.UpdateCount(team_id, resource_id, value)
	local ok = database.update("update `defend_team_resource` set `resource_value` = %d where `team_id` = %d and `resource_id` = %d;", value, team_id, resource_id)
	if ok then
		log.debug("update defend_team_resource success: ", team_id, resource_id, value)
	end

	return ok
end

function TeamResourceTable.Delete(team_id)
	local ok = database.update("delete from `defend_team_resource` where `team_id` = %d;", team_id)
	if ok then
		log.debug("delete from defend_team_resource success: team_id = %d;", team_id)
	end

	return ok
end

