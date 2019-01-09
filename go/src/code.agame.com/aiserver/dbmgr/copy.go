package dbmgr
import(
	"fmt"
	"database/sql"
	"code.agame.com/aiserver/log"
	"code.agame.com/aiserver/config"
)

// query vip exp
func QueryVipExp(server_id int64 , pid uint32) int64 {
	// prepare & check
	from_dbmgr := GetDBMgr(server_id)
	if from_dbmgr==nil {
		log.Error("Fail to QueryVipExp(%d, %d), not found db", server_id, pid)
		return 0
	}
	from_gamedb := from_dbmgr.Gamedb
	if from_gamedb==nil {
		log.Error("Fail to QueryVipExp(%d, %d), not found db", server_id, pid)
		return 0
	}

	// load data
	var vip_exp int64
	err := from_gamedb.QueryRow("SELECT `exp` FROM `vipinfo` WHERE `pid`=?", pid).Scan(&vip_exp)
	if err != nil {
		log.Error("Fail to QueryVipExp(%d, %d), %s", server_id, pid, err.Error())
		return 0
	} else {
		return vip_exp
	}
}

// copy player
func CopyPlayer(from_server_id int64 , from_pid uint32, to_server_id int64, to_pid uint32)bool{
	// prepare & check
	from_dbmgr := GetDBMgr(from_server_id)
	to_dbmgr   := GetDBMgr(to_server_id)
	if from_dbmgr==nil || to_dbmgr==nil {
		log.Error("Fail to CopyPlayer(%d, %d, %d, %d), from_dbmgr is %v, to_dbmgr is %v", from_server_id, from_pid, to_server_id, to_pid, from_dbmgr, to_dbmgr)
		return false
	}
	from_gamedb := from_dbmgr.Gamedb
	to_gamedb   := to_dbmgr.Gamedb
	if from_gamedb==nil || to_gamedb==nil {
		log.Error("Fail to CopyPlayer(%d, %d, %d, %d), from_gamedb is %v, to_gamedb is %v", from_server_id, from_pid, to_server_id, to_pid, from_gamedb, to_gamedb)
		return false
	}

	// check freezed
	var freezed int64
	err := to_gamedb.QueryRow("SELECT `freezed` FROM `ai` WHERE `pid`=?", to_pid).Scan(&freezed)
	if err != nil {
		log.Error("Fail to CopyPlayer(%d, %d, %d, %d), mysql error %s", from_server_id, from_pid, to_server_id, to_pid, err.Error())
		return false
	}
	if freezed != 0 {
		return false
	}

	// inner copy
	if inner_copy_player(from_gamedb, from_pid, to_gamedb, to_pid) {
		log.Info("CopyPlayer(%d, %d, %d, %d), from_dbmgr is %v, to_dbmgr is %v", from_server_id, from_pid, to_server_id, to_pid, from_dbmgr, to_dbmgr)
		return true
	}
	return false
}
func inner_copy_player(from_gamedb *sql.DB, from_pid uint32, to_gamedb *sql.DB, to_pid uint32)bool{
	return copy_armament(from_gamedb, from_pid, to_gamedb, to_pid) &&
	       copy_tactic(from_gamedb, from_pid, to_gamedb, to_pid) &&
	       copy_vipinfo(from_gamedb, from_pid, to_gamedb, to_pid) &&
	       copy_property(from_gamedb, from_pid, to_gamedb, to_pid) &&
	       copy_fire(from_gamedb, from_pid, to_gamedb, to_pid) &&
	       copy_king_avatar(from_gamedb, from_pid, to_gamedb, to_pid) &&
	       copy_guild_active_apply_info(from_gamedb, from_pid, to_gamedb, to_pid);
}

// special copy
func copy_armament(from_gamedb *sql.DB, from_pid uint32, to_gamedb *sql.DB, to_pid uint32)bool{
	// load data
	rows, err := from_gamedb.Query("SELECT `gid`, `level`, `stage`, `placeholder` FROM `armament` WHERE `pid`=? AND `placeholder` BETWEEN ? AND ?",
			from_pid, config.Config.ArmamentPlaceholderMinCopy, config.Config.ArmamentPlaceholderMaxCopy)
	if err != nil {
		log.Error("Fail to copy_armament, mysql query error %s", err.Error())
		return false
	}

	// build values string
	var values_str string =""
	for rows.Next() {
		var gid, level, stage, placeholder int32
		if err := rows.Scan(&gid, &level, &stage, &placeholder); err!=nil {
			log.Error("Fail to copy_armament, mysql scan error %s", err.Error())
			return false
		}
		if (gid/100 == 1401) || (gid/100 == 1402) {
			continue
		}
		if len(values_str) > 0 {
			values_str += ","
		}
		values_str +=fmt.Sprintf("(%d, %d, %d, %d, %d)", to_pid, gid, level, stage, placeholder)
	}
	if len(values_str) == 0 {
		log.Error("Fail to copy_armament, row count is 0")
		return false
	}

	// build querys tring
	query_str := "INSERT INTO `armament`(`pid`, `gid`, `level`, `stage`, `placeholder`)VALUES" + values_str

	// clean & insert
	if _, err := to_gamedb.Exec("DELETE FROM `armament` WHERE `pid` = ?", to_pid); err!=nil {
		log.Error("Fail to copy_armament, mysql query error %s", err.Error())
		return false
	}
	if _, err := to_gamedb.Exec(query_str); err!=nil {
		log.Error("Fail to copy_armament, mysql exec error %s", err.Error())
		return false
	}
	return true
}
func copy_tactic(from_gamedb *sql.DB, from_pid uint32, to_gamedb *sql.DB, to_pid uint32)bool{
	// load data
	rows, err := from_gamedb.Query("SELECT `id`, `level`, `bag_id`, `pos`, unix_timestamp(`gettime`) FROM `tactic` WHERE `pid`=? AND `bag_id` BETWEEN ? AND ?",
			from_pid, config.Config.TacticBagIdMinCopy, config.Config.TacticBagIdMaxCopy)
	if err != nil {
		log.Error("Fail to copy_tactic, mysql query error %s", err.Error())
		return false
	}

	// build values string
	var values_str string =""
	for rows.Next() {
		var id, level, bag_id, pos, gettime int64
		if err := rows.Scan(&id, &level, &bag_id, &pos, &gettime); err!=nil {
			log.Error("Fail to copy_tactic, mysql scan error %s", err.Error())
			return false
		}
		if len(values_str) > 0 {
			values_str += ","
		}
		values_str +=fmt.Sprintf("(%d, %d, %d, %d, %d, from_unixtime(%d))", to_pid, id, level, bag_id, pos, gettime)
	}
	if len(values_str) == 0 {
		return true
	}

	// build querys tring
	query_str := "INSERT INTO `tactic`(`pid`, `id`, `level`, `bag_id`, `pos`, `gettime`)VALUES" + values_str

	// clean & insert
	if _, err := to_gamedb.Exec("DELETE FROM `tactic` WHERE `pid` = ?", to_pid); err!=nil {
		log.Error("Fail to copy_tactic, mysql query error %s", err.Error())
		return false
	}
	if _, err := to_gamedb.Exec(query_str); err!=nil {
		log.Error("Fail to copy_tactic, mysql query error %s", err.Error())
		return false
	}
	return true
}
func copy_vipinfo(from_gamedb *sql.DB, from_pid uint32, to_gamedb *sql.DB, to_pid uint32)bool{
	// load data
	var exp int64
	err := from_gamedb.QueryRow("SELECT `exp` FROM `vipinfo` WHERE `pid`=?", from_pid).Scan(&exp)
	if err != nil {
		log.Error("Fail to copy_vipinfo, mysql query error %s", err.Error())
		return false
	}

	// update
	if _, err := to_gamedb.Exec("REPLACE INTO `vipinfo`(`pid`, `exp`)VALUES(?, ?)", to_pid, exp); err!=nil {
		log.Error("Fail to copy_vipinfo, mysql query error %s", err.Error())
		return false
	}
	return true
}
func copy_property(from_gamedb *sql.DB, from_pid uint32, to_gamedb *sql.DB, to_pid uint32)bool{
	// load data
	var horseExp, total_star_count, total_star_count_modify_time, head, exp, military_power, military_power_modify_time int64
	err := from_gamedb.QueryRow("SELECT `horseExp`, `total_star_count`, `total_star_count_modify_time`, `head`, `exp`, `military_power`, `military_power_modify_time` FROM `property` WHERE `pid`=?", from_pid).Scan(&horseExp, &total_star_count, &total_star_count_modify_time, &head, &exp, &military_power, &military_power_modify_time)
	if err != nil {
		log.Error("Fail to copy_property, mysql query error %s", err.Error())
		return false
	}
	log.Debug("property exp =%d", exp)

	// update
	if _, err := to_gamedb.Exec("UPDATE `property` SET `horseExp` =?, `total_star_count` =?, `total_star_count_modify_time` =?, `head` =?, `exp` =?, `military_power` =?, `military_power_modify_time` =? WHERE `pid` =?", horseExp, total_star_count, total_star_count_modify_time, head, exp, military_power, military_power_modify_time, to_pid); err!=nil {
		log.Error("Fail to copy_property, mysql query error %s", err.Error())
		return false
	}
	return true
}
func copy_fire(from_gamedb *sql.DB, from_pid uint32, to_gamedb *sql.DB, to_pid uint32)bool{
	// load data
	var max int64
	var cur int64
	err := from_gamedb.QueryRow("SELECT `max`,`cur` FROM `fire` WHERE `pid`=?", from_pid).Scan(&max, &cur)
	if err != nil {
		log.Error("Fail to copy_fire, mysql query error %s", err.Error())
		return false
	}

	// update
	if _, err := to_gamedb.Exec("UPDATE `fire` SET `max` =?, `cur`=?, `update_time`=now(), `max_update_time`=now() WHERE `pid` =?", max, cur, to_pid); err!=nil {
		log.Error("Fail to copy_fire, mysql query error %s", err.Error())
		return false
	}
	return true
}
func copy_king_avatar(from_gamedb *sql.DB, from_pid uint32, to_gamedb *sql.DB, to_pid uint32)bool{
	// load data
	var banner_id, scale, hero_skin_id, weapon_skin_id, mount_skin_id int64
	var hero_body_type, weapon_body_type, mount_body_type string
	err := from_gamedb.QueryRow("SELECT `banner_id`, `scale`, `hero_skin_id`, `hero_body_type`, `weapon_skin_id`, `weapon_body_type`, `mount_skin_id`, `mount_body_type` FROM `kingavatar` WHERE `pid`=?", from_pid).Scan(&banner_id, &scale, &hero_skin_id, &hero_body_type, &weapon_skin_id, &weapon_body_type, &mount_skin_id, &mount_body_type)
	if err != nil {
		log.Error("Fail to copy_king_avatar, mysql query error %s", err.Error())
		return false
	}

	// update
	if _, err := to_gamedb.Exec("UPDATE `kingavatar` SET `banner_id`=?, `scale`=?, `hero_skin_id`=?, `hero_body_type`=?, `weapon_skin_id`=?, `weapon_body_type`=?, `mount_skin_id`=?, `mount_body_type`=? WHERE `pid` =?", banner_id, scale, hero_skin_id, hero_body_type, weapon_skin_id, weapon_body_type, mount_skin_id, mount_body_type, to_pid); err!=nil {
		log.Error("Fail to copy_king_avatar, mysql query error %s", err.Error())
		return false
	}
	return true
}
func copy_guild_active_apply_info(from_gamedb *sql.DB, from_pid uint32, to_gamedb *sql.DB, to_pid uint32)bool{
	// get to guild id
	var to_gid int32
	err := to_gamedb.QueryRow("SELECT `gid` FROM guildmember WHERE `pid`=?", to_pid).Scan(&to_gid)
	if err != nil {
		log.Debug("Fail to copy_guild_active_apply_info, %s", err.Error())
		return false
	}

	// load data
    var level,attack,defend,max_hp, hp,fix_hurt,fix_reduce_hurt,crit_ratio,crit_immune_ratio,crit_hurt,crit_immune_hurt,disparry_ratio,parry_ratio,init_power,incr_power,attack_speed,move_speed,field_of_view,true_blood_ratio, skill0_id, skill1_id, scale, hero_skin_id,weapon_skin_id,mount_skin_id,quality,pos,timestamp int64
	var name, hero_body_type, weapon_body_type, mount_body_type string
	err = from_gamedb.QueryRow("SELECT level,attack,defend,max_hp, hp,fix_hurt,fix_reduce_hurt,crit_ratio,crit_immune_ratio,crit_hurt,crit_immune_hurt,disparry_ratio,parry_ratio,init_power,incr_power,attack_speed,move_speed,field_of_view,true_blood_ratio, skill0_id, skill1_id, scale, hero_skin_id,hero_body_type,weapon_skin_id,weapon_body_type,mount_skin_id,mount_body_type,name ,quality,pos,timestamp FROM guild_queue WHERE `pid`=?", from_pid).Scan(&level,&attack,&defend,&max_hp,&hp,&fix_hurt,&fix_reduce_hurt,&crit_ratio,&crit_immune_ratio,&crit_hurt,&crit_immune_hurt,&disparry_ratio,&parry_ratio,&init_power,&incr_power,&attack_speed,&move_speed,&field_of_view,&true_blood_ratio,&skill0_id,&skill1_id,&scale,&hero_skin_id,&hero_body_type,&weapon_skin_id,&weapon_body_type,&mount_skin_id,&mount_body_type,&name,&quality,&pos,&timestamp)
	if err != nil {
		log.Error("Fail to copy_guild_active_apply_info, mysql query error %s", err.Error())
		return false
	}

	// replace into
	if _, err := to_gamedb.Exec("REPLACE INTO guild_queue(pid,gid,level,attack,defend,max_hp, hp,fix_hurt,fix_reduce_hurt,crit_ratio,crit_immune_ratio,crit_hurt,crit_immune_hurt,disparry_ratio,parry_ratio,init_power,incr_power,attack_speed,move_speed,field_of_view,true_blood_ratio, skill0_id, skill1_id, scale, hero_skin_id,hero_body_type,weapon_skin_id,weapon_body_type,mount_skin_id,mount_body_type,name ,quality,pos,timestamp)values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?, ?, ?)",
		  to_pid,to_gid,level,attack,defend,max_hp,hp,fix_hurt,fix_reduce_hurt,crit_ratio,
		  crit_immune_ratio,crit_hurt,crit_immune_hurt,disparry_ratio,parry_ratio,
		  init_power,incr_power,attack_speed,move_speed,field_of_view,true_blood_ratio,
		  skill0_id,skill1_id, scale,hero_skin_id,hero_body_type,weapon_skin_id,weapon_body_type,mount_skin_id,mount_body_type,name,quality,pos,timestamp); err != nil {
		log.Error("Fail to copy_guild_active_apply_info, mysql query error %s", err.Error())
		return false
	}
	return true
}
