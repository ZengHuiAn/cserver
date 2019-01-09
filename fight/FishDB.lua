local database = require "database"

FishPlayerDB = {}
function FishPlayerDB.Select(pid)
 	if type(pid) ~= "number" then
 		log.warning("In_FishPlayerDB_Select: pid is not a number, pid = ", pid)
 		return nil
 	end 
 	local ok, result = database.query([[select pid, tid, fish_status, unix_timestamp(fish_time) as fish_time, unix_timestamp(fish_back_time) as fish_back_time, 
		points, assist_bit, status, power, th, nsec from fish_player where pid = %d;]], pid)
 	if ok and #result > 0 then
 		result[1].is_db = true
 		return result[1]
 	else
 		log.info(string.format("In_FishPlayerDB_Select: player %d not exist.", pid))
 		return nil
 	end
end

function FishPlayerDB.Insert(info)
	if type(info) ~= "table" then
		log.warning("In_FishPlayerDB_Insert: info not a table.")
		return false
	end

	local ok = database.update([[insert into fish_player(pid, tid, fish_status, fish_time, fish_back_time, points, assist_bit, status, power, th, nsec) 
		values(%d, %d, %d, from_unixtime_s(%d), from_unixtime_s(%d), %d, %d, %d, %d, %d, %d);]],
		info.pid, info.tid, info.fish_status, info.fish_time, info.fish_back_time, info.points, info.assist_bit, 
		info.status, info.power, info.th, info.nsec)
	if not ok then
		log.warning("In_FishPlayerDB_Insert: insert into fish_player failed, info is: ")
		log.info(sprinttb(info))
	end

	return ok
end

function FishPlayerDB.Update(info)
	if type(info) ~= "table" then
		log.warning("In_FishPlayerDB_Update: info not a table.")
		return false
	end

	local ok = database.update([[update fish_player set tid = %d, fish_status = %d, fish_time = from_unixtime_s(%d), fish_back_time = from_unixtime_s(%d), points = %d, 
		assist_bit = %d, status = %d, power = %d, th = %d, nsec = %d where pid = %d;]],
		info.tid, info.fish_status, info.fish_time, info.fish_back_time, info.points, info.assist_bit, info.status, info.power, info.th, info.nsec, info.pid)
	if not ok then
		log.warning("In_FishPlayerDB_Update: update fish_player failed, info is: ")
		log.info(sprinttb(info))
	end

	return ok
end

function FishPlayerDB.SyncData(info)
	if type(info) ~= "table" then
		log.warning("In_FishPlayerDB_SyncData: info not a table.")
		return
	end

	local ok = false
	if info.is_db then
		ok = FishPlayerDB.Update(info)
	else
		ok = FishPlayerDB.Insert(info)
		if ok then
			info.is_db = true
		end
	end
	return ok
end

------------------------------------------------------------------------------------------------------
FishTeamDB = {}
function FishTeamDB.Select(tid)
	if type(tid) ~= "number" then
		log.warning("In_FishTeamDB_Select: tid is not a number, tid = ", tid)
		return nil
	end

	local ok, result = database.query([[select tid, pid1, pid2, pid3, pid4, pid5, fight_id from fish_team where tid = %d;]], tid)
	if ok and #result > 0 then
		result[1].is_db = true
		return result[1]
	else
		log.info(string.format("In_FishTeamDB_Select: team %d not exist.", tid))
		return nil
	end
end

function FishTeamDB.Insert(info)
	if type(info) ~= "table" then
		log.warning("In_FishTeamDB_Insert: info is not a table.")
		return false
	end

	local ok = database.update([[insert into fish_team(tid, pid1, pid2, pid3, pid4, pid5, fight_id) values(%d, %d, %d, %d, %d, %d, %d);]],
		info.tid, info.pid1, info.pid2, info.pid3, info.pid4, info.pid5, info.fight_id)
	if not ok then
		log.warning("In_FishTeamDB_Insert: insert into fish_team failed, info is: ")
		log.info(sprinttb(info))
	end

	return ok
end

function FishTeamDB.Update(info)
	if type(info) ~= "table" then
		log.warning("In_FishTeamDB_Update: info is not a table.")
		return false
	end

	local ok = database.update([[update fish_team set pid1 = %d, pid2 = %d, pid3 = %d, pid4 = %d, pid5 = %d, fight_id = %d where tid = %d;]],
		info.pid1, info.pid2, info.pid3, info.pid4, info.pid5, info.fight_id, info.tid)
	if not ok then
		log.warning("In_FishTeamDB_Update: update fish_team failed, info is: ")
		log.info(sprinttb(info))
	end

	return ok
end

function FishTeamDB.SyncData(info)
	if type(info) ~= "table" then
		log.warning("In_FishTeamDB_SyncData: info is not a table.")
		return false
	end

	local ok = false
	if info.is_db then
		ok = FishTeamDB.Update(info)
	else
		ok = FishTeamDB.Insert(info)
		if ok then info.is_db = true end
	end
	return ok
end

function FishTeamDB.Delete(tid)
	if type(tid) ~= "number" then
		log.warning("In_FishTeamDB_Delete: tid is not a number, tid = ", tid)
		return false
	end

	local ok = database.update([[delete from fish_team where tid = %d;]], tid)
	if not ok then
		log.warning("In_FishTeamDB_Delete: delete fish_team failed, tid = ", tid)
	end

	return ok
end

------------------------ 钓鱼记录 -------------------
FishRecordDB = {}
function FishRecordDB.Select(pid)
	if type(pid) ~= "number" then
		log.warning("In_FishRecordDB_Select: pid is not a number.")
		return nil
	end
	local ok, result = database.query([[select pid, `order`, `type`, id, value, tid, unix_timestamp(time) as time from fish_record where pid = %d;]], pid)
	if ok and #result > 0 then
		for i, v in ipairs(result) do
			v.is_db = true
		end
		return result
	end
	return nil
end

function FishRecordDB.Insert(info)
	if type(info) ~= "table" then
		log.warning("In_FishRecordDB_Insert: info is not a table.")
		return false
	end

	local ok = database.update([[insert into fish_record(pid, `order`, `type`, id, value, tid, time) values(%d, %d, %d, %d, %d, %d, from_unixtime_s(%d));]], info.pid, info.order, 
		info.type, info.id, info.value, info.tid, info.time)
	if not ok then
		log.warning("In_FishRecordDB_Insert: insert into fish_record failed, info is: ")
		log.info(sprinttb(info))
	end

	return ok
end

function FishRecordDB.Update(info)
	if type(info) ~= "table" then
		log.warning("In_FishRecordDB_Insert: info is not a table.")
		return false
	end

	local ok = database.update([[update fish_record set `type` = %d, id = %d, value = %d, tid = %d, time = from_unixtime_s(%d) where pid = %d and `order` = %d;]],
		 info.type, info.id, info.value, info.tid, info.time, info.pid, info.order)
	if not ok then
		log.warning("In_FishRecordDB_Update: update fish_record failed, info is: ")
		log.info(sprinttb(info))
	end

	return ok
end

function FishRecordDB.SyncData(info)
	if type(info) ~= "table" then
		log.warning("In_FishRecordDB_Insert: info is not a table.")
		return false
	end

	local ok = false
	if info.is_db then
		ok = FishRecordDB.Update(info)
	else
		ok = FishRecordDB.Insert(info)
		if ok then info.is_db = true end
	end

	return ok
end

function FishRecordDB.Delete(pid)
	if type(pid) ~= "number" then
		log.warning("In_FishRecordDB_Delete: pid is not a number.")
		return false
	end
	local ok = database.update([[delete from fish_record where pid = %d;]], pid)
	if not ok then
		log.warning("In_FishRecordDB_Delete: delete fish_record failed, info is: ")
		log.info(sprinttb(info))
	end

	return ok
end
