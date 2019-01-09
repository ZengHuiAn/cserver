package logic

import (
	agame "code.agame.com/com_agame_protocol"
	colog "code.agame.com/comma_logger"
	"code.agame.com/config"
	"code.agame.com/database"
	"code.agame.com/service"
	"crypto/md5"
	"encoding/json"
	"fmt"
	"log"
	"time"
)

type JsonRequest struct {
	ServerID interface{} `json:"server_id,omitempty"`
	Pid      uint64      `json:"pid,omitempty"`
	Rolename string      `json:"rolename,omitempty"`
	UserName string      `json:"username,omitempty"`
	From     uint32      `json:"goto,omitempty"`
}

type JsonRespond struct {
	Errno int    `json:"errno"`
	Error string `json:"error"`
}

func toInteger(v interface{}) uint32 {
	switch v.(type) {
	case uint:
		return uint32(v.(uint))
	case uint8:
		return uint32(v.(uint8))
	case uint16:
		return uint32(v.(uint16))
	case uint32:
		return uint32(v.(uint32))
	case uint64:
		return uint32(v.(uint64))
	case int:
		return uint32(v.(int))
	case int8:
		return uint32(v.(int8))
	case int16:
		return uint32(v.(int16))
	case int32:
		return uint32(v.(int32))
	case int64:
		return uint32(v.(int64))
	case string:
		var r uint32 = 0
		fmt.Sscanf(v.(string), "%d", &r)
		return r
	default:
		var r uint32 = 0
		fmt.Sscanf(fmt.Sprint(v), "%d", &r)
		return r
	}
}

func HandleCommand(cmd string, request *JsonRequest, bs []byte, sign bool) []byte {
	if request == nil {
		request = &JsonRequest{}
		if err := json.Unmarshal(bs, request); err != nil {
			log.Println("logic json.Unmarshal failed:", err)
			log.Printf("bs is %s\n", string(bs))
			return buildErrorMessage(ERROR_PARAM_ERROR)
		}
	}

	/*
		serverid := toInteger(request.ServerID);

		if serverid != config.GetServerID() {
			log.Println("serverid", serverid, request.ServerID, config.GetServerID());
			return buildErrorMessage(ERROR_SERVER_ID);
		}
	*/

	log.Println("CMD is", cmd)
	switch cmd {
	case "query":
		return doQuery(request, bs, sign)
	case "queryhistory":
		return doQueryHistory(request, bs, sign)
	case "query_return_info":
		return doQueryReturnInfo(request, bs, sign)
	case "exchange":
		return doExchange(request, bs, sign)
	case "ban":
		return doSetPlayerStatus(request, bs, sign)
	case "kick":
		return doKickPlayer(request, bs, sign)
	case "reward":
		return doReward(request, bs, sign)
	case "punish":
		return doPunish(request, bs, sign)
	case "rewardall":
		return doRewardAll(request, bs, sign)
	case "notify":
		return doNotify(request, bs, sign)
	case "sendnotify":
		return doNotify(request, bs, sign)
	case "querynotify":
		return queryNotify(request, bs, sign)
	case "delnotify":
		return delNotify(request, bs, sign)
	case "sendmail":
		return sendMail(request, bs, sign)
	case "querymail":
		return queryMail(request, bs, sign)
	case "delmail":
		return deleteMail(request, bs, sign)
	case "setadult":
		return setAdult(request, bs, sign)
	case "vip":
		return addVipExp(request, bs, sign)
	case "addvipexp":
		return addVipExp(request, bs, sign)
	case "query_exchange_record":
		return doQueryExchangeRecord(request, bs, sign)
	case "unload_player":
		return doUnloadPlayer(request, bs, sign)
	case "buy_month_card":
		return doBuyMonthCard(request, bs, sign)
	case "query_armament":
		return doQueryPlayerArmament(request, bs, sign)
	case "query_resource":
		return doQueryPlayerResource(request, bs, sign)
	case "query_tactic":
		return doQueryPlayerTactic(request, bs, sign)
	case "query_item":
		return doQueryPlayerItem(request, bs, sign)
	case "query_fire":
		return doQueryPlayerFire(request, bs, sign)
	case "query_story":
		return doQueryPlayerStory(request, bs, sign)
	case "query_guild":
		return doQueryPlayerGuild(request, bs, sign)

	case "query_all_bonus":
		return doQueryAllBonus(request, bs, sign)
	case "query_bonus":
		return doQueryBonus(request, bs, sign)
	case "update_bonus":
		return doUpdateBonus(request, bs, sign)
	case "add_bonus":
		return doAddBonus(request, bs, sign)
	case "remove_bonus":
		return doRemoveBonus(request, bs, sign)

	case "query_exchange_gift":
		return doQueryExchangeGift(request, bs, sign)
	case "replace_exchange_gift":
		return doReplaceExchangeGift(request, bs, sign)

	case "query_accumulate_gift":
		return doQueryAccumulateGift(request, bs, sign)
	case "replace_accumulate_gift":
		return doReplaceAccumulateGift(request, bs, sign)

	case "query_accumulate_exchange":
		return doQueryAccumulateExchange(request, bs, sign)
	case "replace_accumulate_exchange":
		return doReplaceAccumulateExchange(request, bs, sign)

	case "query_festival_reward":
		return doQueryFestivalReward(request, bs, sign)
	case "replace_festival_reward":
		return doReplaceFestivalReward(request, bs, sign)

	case "query_item_package":
		return doQueryItemPackage(request, bs, sign)
	case "del_item_package":
		return doDelItemPackage(request, bs, sign)
	case "set_item_package":
		return doSetItemPackage(request, bs, sign)

	case "fresh_point_reward":
		return doFreshPointReward(request, bs, sign)
	case "query_point_reward":
		return doQueryPointReward(request, bs, sign)

	case "bind7725":
		return doBind7725(request, bs, sign)
	case "fresh_limited_shop":
		return doAdminFreshLimitedShop(request, bs, sign)

	case "set_salary":
		return doSetSalary(request, bs, sign)

	case "adsupport_add_group":
		return doAdsupportAddGroup(request, bs, sign)
	case "adsupport_add_quest":
		return doAdsupportAddQuest(request, bs, sign)
	case "adsupport_get_groupid":
		return doAdsupportGetGroupid(request, bs, sign)
	case "adsupport_reload_config":
		return doAdsupportreloadConfig(request, bs, sign)
	case "adsupport_insert_event":
		return doAdsupportinsertevent(request, bs, sign)
	case "change_account":
		return doChangeAccount(request, bs, sign)
	case "adsupport_add_login_group":
		return doAdsupportAddLoginGroup(request, bs, sign)
	case "adsupport_add_invest_group":
		return doAdsupportAddInvestGroup(request, bs, sign)

	default:
		return doGMCommand(cmd, bs)
	}
}

const (
	ERROR_EXCHANGE_ID_ERROR = -10
	ERROR_BUSY              = -9
	ERROR_PREMISSIONS       = -8
	ERROR_PARAM_ERROR       = -7
	ERROR_CONNECTION        = -6
	ERROR_SYSTEM            = -5
	ERROR_GAME_ID           = -4
	ERROR_SERVER_ID         = -3
	ERROR_USER_NOT_EXIST    = -2
	ERROR_UNKNOWN_COMMAND   = -1
	ERROR_SUCCESS           = 0
	ERROR_PLAYER_NOT_EXIST  = 3
)

func Error(errno int) string {
	switch errno {
	case ERROR_EXCHANGE_ID_ERROR:
		return "exchange id error"
	case ERROR_PARAM_ERROR:
		return "request param error"
	case ERROR_GAME_ID:
		return "game id error"
	case ERROR_SERVER_ID:
		return "server id error"
	case ERROR_USER_NOT_EXIST:
		return "user not exist"
	case ERROR_UNKNOWN_COMMAND:
		return "unknown command"
	case ERROR_SUCCESS:
		return "success"
	case ERROR_PLAYER_NOT_EXIST:
		return "player not exist"
	case ERROR_PREMISSIONS:
		return "premission denied"
	case ERROR_CONNECTION:
		return "lost connection"
	case ERROR_SYSTEM:
		return "system error"
	default:
		return "other error"
	}
}

func BuildRespond(v interface{}) []byte {
	return buildRespond(v)
}

func BuildErrorMessage(err int) []byte {
	return buildErrorMessage(err)
}

func buildRespond(v interface{}) []byte {
	bs, _ := json.Marshal(v)
	return bs
}

func buildErrorMessage(err int) []byte {
	return buildRespond(&JsonRespond{Errno: err, Error: Error(err)})
}

func pidFromJsonRequest(request *JsonRequest) (uint64, error) {
	if request.Pid > 0 {
		return request.Pid, nil
	}

	if request.UserName != "" {
		if request.From == 0 {
			request.From = 1
		}

		db, err := database.Get("Account")
		if err != nil {
			log.Println(err)
			return 0, err
		}
		defer db.Release()

		rows, err := db.Query("select id, `from` from account where account = ?", request.UserName)
		if err != nil {
			log.Println(err)
			return 0, err
		}
		defer rows.Close()

		var choose uint64 = 0
		for rows.Next() {
			var pid uint64
			var from uint32
			if err = rows.Scan(&pid, &from); err != nil {
				return 0, err
			}

			if from == request.From {
				choose = pid
				break
			} else if from == 1 || choose == 0 {
				// 优先选中 from = 1 的 记录
				choose = pid
			}
		}

		if choose > 0 {
			return choose, nil
		} else {
			return 0, service.ErrPlayerNotExist
		}
	}

	if request.Rolename != "" {
		db, err := database.Get("Role")
		if err != nil {
			log.Println(err)
			return 0, err
		}
		defer db.Release()

		rows, err := db.Query("select pid from property where name = ?", request.Rolename)
		if err != nil {
			log.Println(err)
			return 0, err
		}
		defer rows.Close()

		for rows.Next() {
			var pid uint64
			if err = rows.Scan(&pid); err != nil {
				log.Println(err)
				return 0, err
			}
			return pid, nil
		}
		return 0, service.ErrPlayerNotExist
	}
	return 0, service.ErrPlayerNotExist
}

func doQueryPlayerArmament(_ *JsonRequest, bs []byte, sign bool) []byte {
	type ArmamentInfo struct {
		Gid         int32 `json:"gid"`
		Level       int32 `json:"level"`
		Stage       int32 `json:"stage"`
		Placeholder int64 `json:"placeholder"`
	}
	var request JsonRequest
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	pid, err := pidFromJsonRequest(&request)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}
	type ArmamentRespond struct {
		JsonRespond
		ArmamentInfoList []ArmamentInfo `json:"armament_info_list"`
	}
	var respond ArmamentRespond
	db, err := database.Get("Role")
	defer db.Release()
	if err != nil {
		log.Printf("fail to query armament, get role database error:%s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}

	// item history
	rows, err := db.Query("SELECT gid, level, stage, placeholder FROM armament WHERE pid=?", pid)
	if err != nil {
		log.Printf("fail to query item history, %s", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	respond.ArmamentInfoList = make([]ArmamentInfo, 0)
	for rows.Next() {
		item := ArmamentInfo{}
		if err := rows.Scan(&item.Gid, &item.Level, &item.Stage, &item.Placeholder); err != nil {
			log.Printf("fail to query armament, scan error, %s", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
		respond.ArmamentInfoList = append(respond.ArmamentInfoList, item)
		log.Printf("gid is `%v`, level is `%v`, stage is `%v`, placeholder is `%v`", item.Gid, item.Level, item.Stage, item.Placeholder)
	}
	log.Printf("respond is `%+v`", respond)
	return buildRespond(respond)
}

func doQueryPlayerResource(_ *JsonRequest, bs []byte, sign bool) []byte {
	type ResourceInfo struct {
		Gid        int32  `json:"gid"`
		Value      int32  `json:"value"`
		UpdateTime string `json:"update_time"`
	}
	var request JsonRequest
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	pid, err := pidFromJsonRequest(&request)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}
	type ResourceRespond struct {
		JsonRespond
		ResourceInfoList []ResourceInfo `json:"resource_info_list"`
	}
	var respond ResourceRespond
	db, err := database.Get("Role")
	defer db.Release()
	if err != nil {
		log.Printf("fail to query resource, get role database error:%s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	// item history
	rows, err := db.Query("SELECT id, value, update_time FROM resource WHERE pid=?", pid)
	if err != nil {
		log.Printf("fail to query resource, select from resource error %s", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	respond.ResourceInfoList = make([]ResourceInfo, 0)
	for rows.Next() {
		item := ResourceInfo{}
		if err := rows.Scan(&item.Gid, &item.Value, &item.UpdateTime); err != nil {
			log.Printf("fail to query resource, scan error, %s", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
		respond.ResourceInfoList = append(respond.ResourceInfoList, item)
		log.Printf("gid is `%v`, value is `%v`, update_time is `%v`", item.Gid, item.Value, item.UpdateTime)
	}
	log.Printf("respond is `%+v`", respond)
	return buildRespond(respond)
}

func doQueryPlayerTactic(_ *JsonRequest, bs []byte, sign bool) []byte {
	type TacticInfo struct {
		Gid     int32  `json:"gid"`
		Level   int32  `json:"level"`
		BagId   int32  `json:"bag_id"`
		Pos     int64  `json:"pos"`
		GetTime string `json:"get_time"`
	}
	var request JsonRequest
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	pid, err := pidFromJsonRequest(&request)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}
	type TacticRespond struct {
		JsonRespond
		TacticInfoList []TacticInfo `json:"tactic_info_list"`
	}
	var respond TacticRespond
	db, err := database.Get("Role")
	defer db.Release()
	if err != nil {
		log.Printf("fail to query tactic, get role database error:%s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	// item history
	rows, err := db.Query("SELECT id, level, bag_id, pos, gettime FROM tactic WHERE pid=?", pid)
	if err != nil {
		log.Printf("fail to query tactic, select from tactic error %s", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	respond.TacticInfoList = make([]TacticInfo, 0)
	for rows.Next() {
		item := TacticInfo{}
		if err := rows.Scan(&item.Gid, &item.Level, &item.BagId, &item.Pos, &item.GetTime); err != nil {
			log.Printf("fail to query tactic, scan error, %s", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
		if item.BagId >= 2 && item.BagId <= 6 {
			item.BagId = item.BagId - 1
			if item.Pos >= 0 && item.Pos <= 5 {
				item.Pos = item.Pos + 1
			}
			respond.TacticInfoList = append(respond.TacticInfoList, item)
		}
		log.Printf("gid is `%v`, level is `%v`, bag_id is `%v`, pos is `%v`, gettime is `%v`", item.Gid, item.Level, item.BagId, item.Pos, item.GetTime)
	}
	log.Printf("respond is `%+v`", respond)
	return buildRespond(respond)
}

func doQueryHistory(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		Goods string `json:"goods"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	pid, err := pidFromJsonRequest(&request.JsonRequest)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}
	switch request.Goods {
	case "item":
		return query_item(pid)
	case "tactic":
		return query_tactic(pid)
	case "armament":
		return query_armament(pid)
	case "playerexp":
		return query_exp(pid)
	default:
		return buildErrorMessage(ERROR_PARAM_ERROR)
	}
}

func query_item(pid uint64) []byte {
	type item_history struct {
		Uuid    int32 `json:"gid"`
		EvtType int32 `json:"evt_type"`
		Time    int32 `json:"time"`
		Id      int32 `json:"id"`
		Count   int32 `json:"count"`
	}
	var respond struct {
		JsonRespond
		ItemHistorys []item_history `json:"items,omitempty"`
	}
	db, err := database.Get("Log")
	if err != nil {
		log.Printf("fail to query itemlog, get Log error:%s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	defer db.Release()

	// item history
	rows, err := db.Query("SELECT uuid, evt_type, `time`,`id`,`count` FROM itemlog WHERE pid=?", pid)
	if err != nil {
		log.Printf("fail to query item history, %s", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	respond.ItemHistorys = make([]item_history, 0)
	for rows.Next() {
		item := item_history{}
		if err := rows.Scan(&item.Uuid, &item.EvtType, &item.Time, &item.Id, &item.Count); err != nil {
			log.Printf("fail to query item history, scan error, %s", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
		respond.ItemHistorys = append(respond.ItemHistorys, item)
	}
	return buildRespond(respond)
}
func query_armament(pid uint64) []byte {
	type armament_history struct {
		Uuid        int32 `json:"uuid"`
		EvtType     int32 `json:"evt_type"`
		Time        int32 `json:"time"`
		Gid         int32 `json:"gid"`
		Level       int32 `json:"level"`
		Stage       int32 `json:"stage"`
		Placeholder int32 `json:"placeholder"`
	}
	var respond struct {
		JsonRespond
		ItemHistorys []armament_history `json:"items,omitempty"`
	}
	db, err := database.Get("Log")
	if err != nil {
		log.Printf("fail to query armament log, get Log error:%s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	defer db.Release()

	// item history
	rows, err := db.Query("SELECT uuid,evt_type,`time`,gid,`level`,stage,placeholder FROM armamentlog WHERE pid=?", pid)
	if err != nil {
		log.Printf("fail to query armament history, %s", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	respond.ItemHistorys = make([]armament_history, 0)
	for rows.Next() {
		item := armament_history{}
		if err := rows.Scan(&item.Uuid, &item.EvtType, &item.Time, &item.Gid, &item.Level, &item.Stage, &item.Placeholder); err != nil {
			log.Printf("fail to query item history, scan error, %s", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
		respond.ItemHistorys = append(respond.ItemHistorys, item)
	}
	return buildRespond(respond)
}

func query_tactic(pid uint64) []byte {
	type tactic_history struct {
		Uuid        int32 `json:"uuid"`
		EvtType     int32 `json:"evt_type"`
		Time        int32 `json:"time"`
		Tuid        int32 `json:"tactic_uuid"`
		Id          int32 `json:"id"`
		Level       int32 `json:"level"`
		Bagid       int32 `json:"bag_id"`
		Placeholder int32 `json:"pos"`
	}
	var respond struct {
		JsonRespond
		ItemHistorys []tactic_history `json:"items,omitempty"`
	}
	db, err := database.Get("Log")
	if err != nil {
		log.Printf("fail to query tactic log, get Log error:%s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	defer db.Release()
	// item history
	rows, err := db.Query("SELECT uuid, evt_type, `time`, tactic_uuid, `id`, `level`, bag_id, pos FROM tacticlog WHERE pid=?", pid)
	if err != nil {
		log.Printf("fail to query tactic history, %s", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	respond.ItemHistorys = make([]tactic_history, 0)
	for rows.Next() {
		item := tactic_history{}
		if err := rows.Scan(&item.Uuid, &item.EvtType, &item.Time, &item.Tuid, &item.Id, &item.Level, &item.Bagid, &item.Placeholder); err != nil {
			log.Printf("fail to query item history, scan error, %s", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
		respond.ItemHistorys = append(respond.ItemHistorys, item)
	}
	return buildRespond(respond)
}

func query_exp(pid uint64) []byte {
	type exp_history struct {
		Uuid    int32 `json:"gid"`
		EvtType int32 `json:"evt_type"`
		Time    int32 `json:"time"`
		Exp     int32 `json:"exp"`
		Vipexp  int32 `json:"vipexp"`
	}
	var respond struct {
		JsonRespond
		ItemHistorys []exp_history `json:"items,omitempty"`
	}
	db, err := database.Get("Log")
	if err != nil {
		log.Printf("fail to query player log, get Log error:%s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	defer db.Release()
	// item history
	rows, err := db.Query("SELECT uuid, evt_type ,`time`, `exp`, `vip_exp` FROM playerexplog WHERE pid=?", pid)
	if err != nil {
		log.Printf("fail to query player history, %s", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	respond.ItemHistorys = make([]exp_history, 0)
	for rows.Next() {
		item := exp_history{}
		if err := rows.Scan(&item.Uuid, &item.EvtType, &item.Time, &item.Exp, &item.Vipexp); err != nil {
			log.Printf("fail to query item history, scan error, %s", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
		respond.ItemHistorys = append(respond.ItemHistorys, item)
	}
	return buildRespond(respond)
}

func doQuery(request *JsonRequest, bs []byte, sign bool) []byte {
	pid, err := pidFromJsonRequest(request)


	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	rolename := request.Rolename

	player, err := service.QueryPlayer(pid, rolename)

	if err == service.ErrPlayerNotExist {
		return buildErrorMessage(ERROR_PLAYER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	var username string = request.UserName
	if username == "" {
		db, err := database.Get("Account")

		if err == nil {
			defer db.Release()
			rows, err := db.Query("select account from account where id = ?", pid)
			if err == nil {
				for rows.Next() {
					rows.Scan(&username)
				}
			}
		}
	}

	var respond struct {
		JsonRespond
		Pid         uint64 `json:"pid"`
		Name        string `json:"name"`
		UserName    string `json:"username"`
		Level       uint32 `json:"level"`
		Country     uint32 `json:"country"`
		TodayOnline uint32 `json:"today_online"`
		//TODO
		Status     uint32 `json:"status"`
		CreateTime uint32 `json:"create_time"` // property -> create_time
		LoginTime  uint32 `json:"login_time"`
		LogoutTime uint32 `json:"logout_time"`
		Vip        uint32 `json:"vip_level"`
		Tower      uint32 `json:"tower"`

		Vit struct {
			Value      uint32 `json:"value"` // resource id =
			UpdateTime uint32 `json:"update_time"`
		} `json:"vit"`

		Salary uint32 `json:"salary"`
	}

	respond.Errno = 0
	respond.Error = Error(0)
	respond.Pid = pid
	respond.Name = player.GetName()
	respond.UserName = username
	respond.Level = player.GetLevel()
	respond.Country = player.GetCountry()
	respond.TodayOnline = player.GetTodayOnline()

	respond.LoginTime = player.GetLogin()
	respond.LogoutTime = player.GetLogout()
	respond.Status = player.GetStatus()
	respond.Vip = player.GetVip()
	respond.Tower = player.GetTower()
	respond.Salary = player.GetSalary()

	/*
		db, err := database.Get("Role")
		defer db.Release()
		if err != nil {
			log.Printf("fail to query player info, get role database error:%s\n", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
		// property
		rows, err := db.Query("SELECT unix_timestamp(`create`) as `create` FROM property  WHERE pid=?", pid)
		if err != nil {
			log.Printf("fail to query story, select from story error %s", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
		for rows.Next() {
			if err := rows.Scan(&respond.CreateTime); err != nil {
				log.Printf("fail to query player info, scan create time error, %s", err.Error())
				return buildErrorMessage(ERROR_SYSTEM)
			}
		}

		//resource
		rows, err = db.Query("SELECT `value`, unix_timestamp(`update_time`) as update_time FROM resource WHERE pid=?", pid)
		if err != nil {
			log.Printf("fail to query resource, select from resource error %s", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
		for rows.Next() {
			if err := rows.Scan(&respond.Vit.Value, &respond.Vit.UpdateTime); err != nil {
				log.Printf("fail to query player vit, scan resource error, %s", err.Error())
				return buildErrorMessage(ERROR_SYSTEM)
			}
		}
	*/
	log.Printf("doQuery, respond is `%+v`", respond)
	return buildRespond(respond)
}

func doQueryReturnInfo(request *JsonRequest, bs []byte, sign bool) []byte {
	pid, err := pidFromJsonRequest(request)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	rolename := request.Rolename

	info, err := service.QueryPlayerReturnInfo(pid, rolename)
	if err == service.ErrPlayerNotExist {
		return buildErrorMessage(ERROR_PLAYER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	var respond struct {
		JsonRespond
		Return_7_time  uint64 `json:"return_7_time"`
		Return_15_time uint64 `json:"return_15_time"`
		Return_30_time uint64 `json:"return_30_time"`
	}

	respond.Errno = 0
	respond.Error = Error(0)
	respond.Return_7_time = info.GetReturn_7Time()
	respond.Return_15_time = info.GetReturn_15Time()
	respond.Return_30_time = info.GetReturn_30Time()

	return buildRespond(respond)
}

type ExchangeJsonRequest struct {
	JsonRequest

	ExchangeID string      `json:"exchange_id"`
	Passage    interface{} `json:"passage,omitempty"`
	OrderID    interface{} `json:"order_id,omitempty"`

	GameCoin  uint32 `json:"game_coin"`
	Coin      uint32 `json:"coin"`
	TotalCoin uint32 `json:"total_coin"`

	Time string `json:"time"`
	Sign string `json:"sign"`
}

func recordExchange(pid uint64, request *ExchangeJsonRequest) int {
	db, err := database.Get("Log")
	if err != nil {
		return ERROR_SYSTEM
	}
	defer db.Release()

	_, err = db.Exec(`insert into exchange_log(exchange_id, pid, username, order_id, passage, 
		server_id, game_coin, coin, total_coin, timestamp)
		values(?, ?, ?, ?, ?, ?, ?, ?, ?, now())`,
		request.ExchangeID,
		pid,
		request.UserName,
		request.OrderID,
		request.Passage,
		request.ServerID,
		request.GameCoin,
		request.Coin,
		request.TotalCoin)
	if err != nil {
		log.Printf("request is %+v", request)
		log.Printf("fail to recordExchange, mysql error:%s\n", err.Error())
		return ERROR_EXCHANGE_ID_ERROR
	}
	return ERROR_SUCCESS
}
func deleteRecordExchange(pid uint64, request *ExchangeJsonRequest) int {
	db, err := database.Get("Log")
	if err != nil {
		return ERROR_SYSTEM
	}
	defer db.Release()

	_, err = db.Exec(`delete from exchange_log where exchange_id=?`, request.ExchangeID)
	if err != nil {
		log.Printf("request is %+v", request)
		log.Printf("fail to deleteRecordExchange, mysql error:%s\n", err.Error())
		return ERROR_EXCHANGE_ID_ERROR
	}
	return ERROR_SUCCESS
}

func doExchange(r *JsonRequest, bs []byte, sign bool) []byte {
	var request ExchangeJsonRequest

	err := json.Unmarshal(bs, &request)
	if err != nil {
		log.Printf("json.Unmarshal failed: %v", err)
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	if sign {
		key := config.GetGMServerKey()
		if key != "" {

			s := fmt.Sprintf("%s%s%d%d%d%s%s",
				request.ExchangeID, request.UserName, request.GameCoin, request.Coin, request.TotalCoin, request.Time, key)
			log.Println(s)

			h := md5.New()
			fmt.Fprintf(h, "%s%s%d%d%d%s%s",
				request.ExchangeID, request.UserName, request.GameCoin, request.Coin, request.TotalCoin, request.Time, key)

			check := fmt.Sprintf("%x", h.Sum(nil))
			if check != request.Sign {
				log.Println(check)
				return buildErrorMessage(ERROR_PREMISSIONS)
			}
		}
	}

	pid, err := pidFromJsonRequest(&request.JsonRequest)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	code := recordExchange(pid, &request)
	if code != ERROR_SUCCESS {
		return buildErrorMessage(code)
	}

	err = service.SendReward(pid, 10003, false, 0, "", service.Rewards(service.Money(request.GameCoin)))
	if err == service.ErrPlayerNotExist {
		deleteRecordExchange(pid, &request)
		return buildErrorMessage(ERROR_PLAYER_NOT_EXIST)
	} else if err != nil {
		deleteRecordExchange(pid, &request)
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		// service.AddVIPExp(pid, request.GameCoin);
		colog.Println(fmt.Sprintf("%v,%v,1,%v,%v", pid, time.Now().Unix(), request.ExchangeID, request.GameCoin))
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doSetPlayerStatus(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		Status uint32 `json:"status"`
	}

	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	pid, err := pidFromJsonRequest(&request.JsonRequest)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	err = service.SetPlayerStatus(pid, request.Status)
	if err == service.ErrPlayerNotExist {
		return buildErrorMessage(ERROR_PLAYER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doKickPlayer(request *JsonRequest, bs []byte, sign bool) []byte {
	pid, err := pidFromJsonRequest(request)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	err = service.KickPlayer(pid)
	if err == service.ErrPlayerNotExist {
		return buildErrorMessage(ERROR_PLAYER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doRewardTo(pid uint64, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest

		Reason uint32 `json:"reason"`
		Limit  uint32 `json:"limit,omitempty"`
		Name   string `json:"name,omitempty"`
		Manual bool   `json:"manual,omitempty"`

		Content []*agame.Reward `json:"content,omitempty"`

		Condition *agame.PAdminRewardRequest_Condition `json:"condition,omitempty"`
	}

	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	log.Printf("%+v\n", request)

	err = service.SendRewardWithCondition(pid, request.Reason, request.Manual, request.Limit, request.Name, request.Content, request.Condition)

	if err == service.ErrPlayerNotExist {
		return buildErrorMessage(ERROR_PLAYER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doReward(request *JsonRequest, bs []byte, sign bool) []byte {
	pid, err := pidFromJsonRequest(request)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	return doRewardTo(pid, bs, sign)
}

func doPunish(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		Reason  uint32                               `json:"reason"`
		Consume []*agame.PAdminRewardRequest_Consume `json:"consumes"`
	}

	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	pid, err := pidFromJsonRequest(&request.JsonRequest)
	request.Reason = uint32(1038)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}
	err = json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	log.Printf("%+v\n", request)
	err = service.SendPunish(pid, request.Reason, request.Consume)
	if err == service.ErrPlayerNotExist {
		return buildErrorMessage(ERROR_PLAYER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doRewardAll(_ *JsonRequest, bs []byte, sign bool) []byte {
	return doRewardTo(0, bs, sign)
}

func doNotify(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		Start    uint32 `json:"start"`
		Duration uint32 `json:"duration"`
		Interval uint32 `json:"interval"`
		Type     uint32 `json:"type"`
		Msg      string `json:"message"`
	}

	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	if request.Msg == "" {
		return buildErrorMessage(ERROR_PARAM_ERROR)
	}

	if request.Start == 0 {
		request.Start = uint32(time.Now().Unix())
	}

	id, err := service.SendBroadCast(request.Start, request.Duration, request.Interval, request.Type, request.Msg)
	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	var respond struct {
		JsonRespond
		ID uint32 `json:"id"`
	}

	respond.ID = id
	respond.Errno = ERROR_SUCCESS
	respond.Error = Error(ERROR_SUCCESS)

	return buildRespond(&respond)
}

func queryNotify(request *JsonRequest, bs []byte, sign bool) []byte {
	notifys, err := service.QueryBroadCast()
	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	var respond struct {
		JsonRespond
		Notify interface{} `json:"notify"`
	}

	respond.Errno = 0
	respond.Error = Error(0)
	respond.Notify = notifys
	if notifys == nil {
		respond.Notify = make([]int32, 0)
	}

	return buildRespond(&respond)
}

func delNotify(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		ID uint32 `json:"id"`
	}

	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	err = service.DeleteBroadCast(request.ID)
	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func sendMail(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest

		Title    string                `json:"title"`
		Content  string                `json:"content"`
		Type     uint32                `json:"type,omitempty"`
		Appendix []service.TypeIdValue `json:"appendix,omitempty"`
	}

	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	pid, err := pidFromJsonRequest(&request.JsonRequest)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	if request.Type == 0 {
		request.Type = 1
	}
	err = service.SendMail(0, pid, uint32(request.Type), request.Title, request.Content, request.Appendix)
	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func queryMail(request *JsonRequest, bs []byte, sign bool) []byte {
	pid, err := pidFromJsonRequest(request)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	mails, err := service.QueryMail(pid)
	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	type sMail struct {
		Id      uint32      `json:"id"`
		From    interface{} `json:"from"`
		To      interface{} `json:"to"`
		Type    uint32      `json:"type"`
		Title   string      `json:"title"`
		Content string      `json:"content"`
		Time    uint32      `json:"timestamp"`
		Status  uint32      `json:"status"`
	}

	var respond struct {
		JsonRespond
		Mail []*sMail `json:"mail"`
	}

	respond.Errno = 0
	respond.Error = Error(0)
	if mails == nil {
		respond.Mail = make([]*sMail, 0)
	} else {
		respond.Mail = make([]*sMail, len(mails))
		for i := 0; i < len(mails); i++ {
			mail := mails[i]
			rmail := &sMail{
				Id:      mail.GetId(),
				From:    mail.GetFrom(),
				To:      mail.GetTo(),
				Type:    mail.GetType(),
				Title:   mail.GetTitle(),
				Content: mail.GetContent(),
				Time:    mail.GetTime(),
				Status:  mail.GetStatus(),
			}
			respond.Mail[i] = rmail
		}
	}

	return buildRespond(&respond)
}

func deleteMail(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		ID uint32 `json:"id"`
	}

	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	err = service.DeleteMail(request.ID)
	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func setAdult(request *JsonRequest, bs []byte, sign bool) []byte {
	return buildErrorMessage(ERROR_SYSTEM)
}

func addVipExp(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		Exp uint32 `json:"exp"`
	}

	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	pid, err := pidFromJsonRequest(&request.JsonRequest)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	err = service.AddVIPExp(pid, request.Exp)
	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		return buildErrorMessage(ERROR_SUCCESS)
	}
}
func doQueryExchangeRecord(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request JsonRequest
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	pid, err := pidFromJsonRequest(&request)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	type exchange_log struct {
		ExchangeID string      `json:"exchange_id"`
		OrderID    interface{} `json:"order_id,omitempty"`
		Passage    interface{} `json:"passage,omitempty"`
		ServerID   string      `json:"server_id"`

		GameCoin  uint32 `json:"game_coin"`
		Coin      uint32 `json:"coin"`
		TotalCoin uint32 `json:"total_coin"`

		Time string `json:"time"`
	}
	var respond struct {
		JsonRespond
		Pid  uint64         `json:"pid"`
		logs []exchange_log `json:"logs,omitempty"`
	}
	respond.Pid = pid

	// query
	db, err := database.Get("Log")
	if err != nil {
		log.Printf("fail to doQueryExchangeRecord, get Log error:%s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	defer db.Release()
	rows, err := db.Query(`select exchange_id, order_id, passage, server_id, game_coin, coin, total_coin, timestamp from exchange_log where pid=?`, pid)
	respond.logs = make([]exchange_log, 0)
	for rows.Next() {
		lg := exchange_log{}
		if err := rows.Scan(&lg.ExchangeID, &lg.OrderID, &lg.Passage, &lg.ServerID, &lg.GameCoin, &lg.Coin, &lg.TotalCoin, &lg.Time); err != nil {
			log.Printf("fail to doQueryExchangeRecord, scan error:%s\n", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
		respond.logs = append(respond.logs, lg)
	}

	return buildRespond(respond)
}
func doUnloadPlayer(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request JsonRequest

	err := json.Unmarshal(bs, &request)
	if err != nil {
		log.Printf("bs is %s\n", string(bs))
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	pid, err := pidFromJsonRequest(&request)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	err = service.UnloadPlayer(pid)
	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doBuyMonthCard(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request ExchangeJsonRequest
	log.Println("begin doBuyMonthCard")

	err := json.Unmarshal(bs, &request)
	if err != nil {
		log.Println("fail to doBuyMonthCard, json.Unmarshal error")
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	pid, err := pidFromJsonRequest(&request.JsonRequest)
	if err == service.ErrPlayerNotExist || pid == 0 {
		log.Println("fail to doBuyMonthCard, player not exist")
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		log.Printf("fail to doBuyMonthCard, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}

	code := recordExchange(pid, &request)
	if code != ERROR_SUCCESS {
		return buildErrorMessage(code)
	}

	err = service.BuyMonthCard(pid)
	if err != nil {
		deleteRecordExchange(pid, &request)
		log.Printf("`%d` fail doBuyMonthCard, %s\n", pid, err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Println("success doBuyMonthCard")
		colog.Println(fmt.Sprintf("%v,%v,2,%v,300", pid, time.Now().Unix(), request.ExchangeID))
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doQueryPlayerItem(_ *JsonRequest, bs []byte, sign bool) []byte {
	type ItemInfo struct {
		Gid   int32 `json:"gid"`
		Limit int32 `json:"value"`
		Pos   int32 `json:"pos"`
	}
	var request JsonRequest
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	pid, err := pidFromJsonRequest(&request)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}
	type ItemRespond struct {
		JsonRespond
		ItemInfoList []ItemInfo `json:"item_info_list"`
	}
	var respond ItemRespond
	db, err := database.Get("Role")
	defer db.Release()
	if err != nil {
		log.Printf("fail to query item, get role database error:%s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	// item history
	rows, err := db.Query("SELECT id, `limit`, pos FROM item WHERE pid=?", pid)
	if err != nil {
		log.Printf("fail to query item, select from item error %s", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	respond.ItemInfoList = make([]ItemInfo, 0)
	for rows.Next() {
		item := ItemInfo{}
		if err := rows.Scan(&item.Gid, &item.Limit, &item.Pos); err != nil {
			log.Printf("fail to query item, scan error, %s", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
		respond.ItemInfoList = append(respond.ItemInfoList, item)
	}
	log.Printf("respond is `%+v`", respond)
	return buildRespond(respond)
}

func doQueryPlayerFire(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request JsonRequest
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	pid, err := pidFromJsonRequest(&request)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}
	type FireRespond struct {
		JsonRespond
		MaxFloor   int32  `json:"max_floor"`
		CurFloor   int32  `json:"cur_floor"`
		UpdateTime string `json:"update_time"`
	}
	var respond FireRespond
	db, err := database.Get("Role")
	defer db.Release()
	if err != nil {
		log.Printf("fail to query fire, get role database error:%s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	// item history
	rows, err := db.Query("SELECT `max`, `cur`,update_time FROM fire WHERE pid=?", pid)
	if err != nil {
		log.Printf("fail to query fire, select from fire error %s", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	for rows.Next() {
		if err := rows.Scan(&respond.MaxFloor, &respond.CurFloor, &respond.UpdateTime); err != nil {
			log.Printf("fail to query fire, scan error, %s", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
	}
	log.Printf("respond is `%+v`", respond)
	return buildRespond(respond)
}

func doQueryPlayerStory(_ *JsonRequest, bs []byte, sign bool) []byte {
	type StoryInfo struct {
		Gid         int32  `json:"gid"`
		Flag        int32  `json:"flag"`
		Time        string `json:"time"`
		Daily       int32  `json:"daily"`
		DailyUpdate string `json:"daily_update"`
	}
	var request JsonRequest
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	pid, err := pidFromJsonRequest(&request)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}
	type StoryRespond struct {
		JsonRespond
		StoryInfoList []StoryInfo `json:"story_info_list"`
	}
	var respond StoryRespond
	db, err := database.Get("Role")
	defer db.Release()
	if err != nil {
		log.Printf("fail to query story, get role database error:%s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	// story history
	rows, err := db.Query("SELECT `id`,`flag`,`time`,`daily`, `daily_update` FROM story WHERE pid=?", pid)
	if err != nil {
		log.Printf("fail to query story, select from story error %s", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	respond.StoryInfoList = make([]StoryInfo, 0)
	for rows.Next() {
		story := StoryInfo{}
		if err := rows.Scan(&story.Gid, &story.Flag, &story.Time, &story.Daily, &story.DailyUpdate); err != nil {
			log.Printf("fail to query story, scan error, %s", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
		respond.StoryInfoList = append(respond.StoryInfoList, story)
	}
	log.Printf("respond is `%+v`", respond)
	return buildRespond(respond)
}
func doQueryAllBonus(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request JsonRequest
	type TimeRange struct {
		Uuid      int64 `json:"uuid"`
		Ratio     int64 `json:"ratio"`
		BeginTime int64 `json:"begin_time"`
		EndTime   int64 `json:"end_time"`
	}

	type BonusItem struct {
		BonusId     int64        `json:bonus_id`
		BonusReward []*TimeRange `json:"bonus_reward"`
		BonusCount  []*TimeRange `json:"bonus_count"`
	}
	type BonusRespond struct {
		JsonRespond
		Bonus []*BonusItem `json:"bonus"`
	}

	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	bonus_list, err := service.QueryAllBonus()
	if err != nil {
		log.Printf("the err is %v", err)
		return buildErrorMessage(ERROR_SYSTEM)
	}
	var respond BonusRespond
	respond.Bonus = make([]*BonusItem, len(bonus_list))
	for i := 0; i < len(bonus_list); i++ {
		var bonus_id = bonus_list[i].GetBonusId()
		var reward_list = bonus_list[i].GetReward()
		var count_list = bonus_list[i].GetCount()

		var item = &BonusItem{}
		item.BonusId = bonus_id
		item.BonusReward = make([]*TimeRange, len(reward_list))
		item.BonusCount = make([]*TimeRange, len(count_list))

		// add reward
		for j := 0; j < len(reward_list); j++ {
			v := reward_list[j]
			t_reward := &TimeRange{
				Uuid:      v.GetUuid(),
				Ratio:     v.GetRatio(),
				BeginTime: v.GetBeginTime(),
				EndTime:   v.GetEndTime(),
			}
			item.BonusReward[j] = t_reward
		}
		//add count
		for j := 0; j < len(count_list); j++ {
			v := count_list[j]
			t_count := &TimeRange{
				Uuid:      v.GetUuid(),
				Ratio:     v.GetRatio(),
				BeginTime: v.GetBeginTime(),
				EndTime:   v.GetEndTime(),
			}
			item.BonusCount[j] = t_count
		}
		respond.Bonus[i] = item
	}
	return buildRespond(respond)
}

func doQueryBonus(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		BonusId int64 `json:"bonus_id"`
	}
	type TimeRange struct {
		Uuid      int64 `json:"uuid"`
		Ratio     int64 `json:"ratio"`
		BeginTime int64 `json:"begin_time"`
		EndTime   int64 `json:"end_time"`
	}

	type BonusRespond struct {
		JsonRespond
		BonusId     int64        `json:bonus_id`
		BonusReward []*TimeRange `json:"bonus_reward"`
		BonusCount  []*TimeRange `json:"bonus_count"`
	}

	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	respond_bonus_id, reward, count, err := service.QueryBonus(request.BonusId)
	if err != nil {
		log.Printf("the err is %v", err)
		return buildErrorMessage(ERROR_SYSTEM)
	}
	var respond BonusRespond
	respond.BonusId = respond_bonus_id
	respond.BonusReward = make([]*TimeRange, len(reward))
	for i := 0; i < len(reward); i++ {
		v := reward[i]
		t_reward := &TimeRange{
			Uuid:      v.GetUuid(),
			Ratio:     v.GetRatio(),
			BeginTime: v.GetBeginTime(),
			EndTime:   v.GetEndTime(),
		}
		respond.BonusReward[i] = t_reward
	}

	respond.BonusCount = make([]*TimeRange, len(count))
	for i := 0; i < len(count); i++ {
		v := count[i]
		t_count := &TimeRange{
			Uuid:      v.GetUuid(),
			Ratio:     v.GetRatio(),
			BeginTime: v.GetBeginTime(),
			EndTime:   v.GetEndTime(),
		}
		respond.BonusCount[i] = t_count
	}
	return buildRespond(respond)
}

func doAddBonus(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		BonusId   int64 `json:"bonus_id"`
		Flag      int64 `json:"flag"`
		Ratio     int64 `json:"ratio"`
		BeginTime int64 `json:"begin_time"`
		EndTime   int64 `json:"end_time"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	uuid, err := service.AddBonus(request.BonusId, request.Flag, request.Ratio, request.BeginTime, request.EndTime)
	if err != nil {
		log.Printf("the err is %v", err)
		return buildErrorMessage(ERROR_SYSTEM)
	}
	var respond struct {
		JsonRespond
		Uuid int64 `json:"uuid"`
	}
	respond.Uuid = uuid
	return buildRespond(respond)
}

func doRemoveBonus(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		BonusId int64 `json:"bonus_id"`
		UUID    int64 `json:"uuid"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	err = service.RemoveBonus(request.BonusId, request.UUID)
	if err != nil {
		log.Printf("fail remove bonus, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Println("success remove bonus\n")
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doUpdateBonus(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		BonusId int64 `json:"bonus_id"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	err = service.UpdateBonus(request.BonusId)
	if err != nil {
		log.Printf("fail update bonus, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Println("success update bonus\n")
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doQueryExchangeGift(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request JsonRequest
	type Reward struct {
		ConsumeValue int64 `json:"consume_value"`
		Type         int64 `json:"type"`
		Id           int64 `json:"id"`
		Value        int64 `json:"value"`
		Flag         int64 `json:"flag"`
	}
	var respond struct {
		JsonRespond
		OpenTime int64     `json:"open_time"`
		Rewards  []*Reward `json:"rewards"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	open_time, rewards, err := service.QueryExchangeGift()
	if err != nil {
		log.Printf("fail to query exchange gift, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	respond.OpenTime = open_time
	respond.Rewards = make([]*Reward, len(rewards))
	for i := 0; i < len(rewards); i++ {
		v := rewards[i]
		t_reward := &Reward{
			ConsumeValue: v.GetConsumeValue(),
			Type:         v.GetType(),
			Id:           v.GetId(),
			Value:        v.GetValue(),
			Flag:         v.GetFlag(),
		}
		respond.Rewards[i] = t_reward
	}
	return buildRespond(respond)
}

func doReplaceExchangeGift(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		OpenTime int64                                            `json:"open_time"`
		Rewards  []*agame.ReplaceExchangeGiftRewardRequest_Reward `json:"rewards"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	err = service.ReplaceExchangeGift(request.OpenTime, request.Rewards)
	if err != nil {
		log.Printf("fail to replace_exchange_gift, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Println("success replace_exchange_gift")
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doQueryFestivalReward(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request JsonRequest
	type Reward struct {
		Offset int64 `json:"offset"`
		Date   int64 `json:"date"`
		Type   int64 `json:"type"`
		Id     int64 `json:"id"`
		Value  int64 `json:"value"`
	}
	var respond struct {
		JsonRespond
		Rewards []*Reward `json:"rewards"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	rewards, err := service.QueryFestivalReward()
	if err != nil {
		log.Printf("fail to query festival reward, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	respond.Rewards = make([]*Reward, len(rewards))
	for i := 0; i < len(rewards); i++ {
		v := rewards[i]
		t_reward := &Reward{
			Offset: v.GetOffset(),
			Date:   v.GetDate(),
			Type:   v.GetType(),
			Id:     v.GetId(),
			Value:  v.GetValue(),
		}
		respond.Rewards[i] = t_reward
	}
	return buildRespond(respond)
}

func doReplaceFestivalReward(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		Rewards []*agame.ReplaceFestivalRewardRequest_Reward `json:"rewards"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	err = service.ReplaceFestivalReward(request.Rewards)
	if err != nil {
		log.Printf("fail to replace_festival_reward, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Println("success replace_festival_reward")
		return buildErrorMessage(ERROR_SUCCESS)
	}
}
func doQueryAccumulateGift(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request JsonRequest
	type Reward struct {
		ConsumeValue int64 `json:"consume_value"`
		Type         int64 `json:"type"`
		Id           int64 `json:"id"`
		Value        int64 `json:"value"`
		Flag         int64 `json:"flag"`
	}
	var respond struct {
		JsonRespond
		BeginTime int64     `json:"begin_time"`
		EndTime   int64     `json:"end_time"`
		Rewards   []*Reward `json:"rewards"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	begin_time, end_time, rewards, err := service.QueryAccumulateGift()
	if err != nil {
		log.Printf("fail to query accumulate gift, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	respond.BeginTime = begin_time
	respond.EndTime = end_time
	respond.Rewards = make([]*Reward, len(rewards))
	for i := 0; i < len(rewards); i++ {
		v := rewards[i]
		t_reward := &Reward{
			ConsumeValue: v.GetConsumeValue(),
			Type:         v.GetType(),
			Id:           v.GetId(),
			Value:        v.GetValue(),
			Flag:         v.GetFlag(),
		}
		respond.Rewards[i] = t_reward
	}
	return buildRespond(respond)
}

func doQueryAccumulateExchange(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request JsonRequest
	type Reward struct {
		ExchangeValue int64 `json:"exchange_value"`
		Type          int64 `json:"type"`
		Id            int64 `json:"id"`
		Value         int64 `json:"value"`
	}
	var respond struct {
		JsonRespond
		BeginTime int64     `json:"begin_time"`
		EndTime   int64     `json:"end_time"`
		Rewards   []*Reward `json:"rewards"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	begin_time, end_time, rewards, err := service.QueryAccumulateExchange()
	if err != nil {
		log.Printf("fail to query accumulate gift, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	respond.BeginTime = begin_time
	respond.EndTime = end_time
	respond.Rewards = make([]*Reward, len(rewards))
	for i := 0; i < len(rewards); i++ {
		v := rewards[i]
		t_reward := &Reward{
			ExchangeValue: v.GetExchangeValue(),
			Type:          v.GetType(),
			Id:            v.GetId(),
			Value:         v.GetValue(),
		}
		respond.Rewards[i] = t_reward
	}
	return buildRespond(respond)
}

func doReplaceAccumulateGift(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		BeginTime int64                                                     `json:"begin_time"`
		EndTime   int64                                                     `json:"end_time"`
		Rewards   []*agame.ReplaceAccumulateConsumeGoldRewardRequest_Reward `json:"rewards"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	err = service.ReplaceAccumulateGift(request.BeginTime, request.EndTime, request.Rewards)
	if err != nil {
		log.Printf("fail to replace_accumulate_gift, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Println("success replace_accumulate_gift")
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doReplaceAccumulateExchange(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		BeginTime int64                                                  `json:"begin_time"`
		EndTime   int64                                                  `json:"end_time"`
		Rewards   []*agame.ReplaceAccumulateExchangeRewardRequest_Reward `json:"rewards"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	err = service.ReplaceAccumulateExchange(request.BeginTime, request.EndTime, request.Rewards)
	if err != nil {
		log.Printf("fail to replace_accumulate_exchange, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Println("success replace_accumulate_exchange")
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doFreshPointReward(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		Items []*agame.AdminFreshPointRewardRequest_Item `json:"items"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	err = service.FreshPointReward(request.Items)
	if err != nil {
		log.Printf("fail to fresh point reward, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Println("success to fresh point reward")
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doQueryPointReward(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request JsonRequest
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	items, err := service.QueryPointReward()
	if err != nil {
		log.Printf("fail to query point reward, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	type item struct {
		PoolType  int64 `json:"pool_type"`
		BeginTime int64 `json:"begin_time"`
		EndTime   int64 `json:"end_time"`
	}
	var respond struct {
		JsonRespond
		Items []*item `json:"items"`
	}
	respond.Items = make([]*item, len(items))
	for i := 0; i < len(items); i++ {
		v := items[i]
		t_item := &item{
			PoolType:  v.GetPoolType(),
			BeginTime: v.GetBeginTime(),
			EndTime:   v.GetEndTime(),
		}
		respond.Items[i] = t_item
	}
	return buildRespond(respond)
}

func doQueryItemPackage(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request JsonRequest
	type RespondItem struct {
		Type  int64 `json:"type"`
		Id    int64 `json:"id"`
		Value int64 `json:"value"`
	}
	type RespondPackage struct {
		PackageId int64          `json:"package_id"`
		Items     []*RespondItem `json:"items"`
	}
	var respond struct {
		JsonRespond
		Packages []*RespondPackage `json:"packages"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	package_list, err := service.QueryItemPackage()
	if err != nil {
		log.Printf("fail to doQueryItemPackage, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	respond.Packages = make([]*RespondPackage, len(package_list))
	for i := 0; i < len(package_list); i++ {
		arr_item := package_list[i]
		item_list := arr_item.GetItem()

		var pkg = &RespondPackage{}
		pkg.PackageId = arr_item.GetPackageId()
		pkg.Items = make([]*RespondItem, len(item_list))

		for j := 0; j < len(item_list); j++ {
			tmp := item_list[j]
			pkg.Items[j] = &RespondItem{
				Type:  tmp.GetType(),
				Id:    tmp.GetId(),
				Value: tmp.GetValue(),
			}
		}
		respond.Packages[i] = pkg
	}
	return buildRespond(respond)
}
func doSetItemPackage(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		PackageId int64                               `json:"package_id"`
		Items     []*agame.SetItemPackageRequest_Item `json:"items"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	err = service.SetItemPackage(request.PackageId, request.Items)
	if err != nil {
		log.Printf("fail to doSetItemPackage, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		return buildErrorMessage(ERROR_SUCCESS)
	}
}
func doDelItemPackage(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		PackageId int64 `json:"package_id"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	err = service.DelItemPackage(request.PackageId)
	if err != nil {
		log.Printf("fail to doDelItemPackage, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doBind7725(_ *JsonRequest, bs []byte, sign bool) []byte {
	// unmarshal request
	var request JsonRequest
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	// parse pid from request
	pid, err := pidFromJsonRequest(&request)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	// do job
	err = service.Bind7725(pid)
	if err != nil {
		log.Printf("fail to bind7725, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Println("success bind7725")
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doAdminFreshLimitedShop(_ *JsonRequest, bs []byte, sign bool) []byte {
	// unmarshal request
	var request struct {
		JsonRequest
		ShopType    uint32 `json:"shop_type"`
		FreshPeriod uint32 `json:"fresh_period"`
		FreshCount  uint32 `json:"fresh_count"`
		BeginTime   uint32 `json:"begin_time"`
		EndTime     uint32 `json:"end_time"`
	}
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	// do job
	err = service.AdminFreshLimitedShop(request.ShopType, request.FreshPeriod, request.FreshCount, request.BeginTime, request.EndTime)
	if err != nil {
		log.Printf("fail to fresh_limited_shop, %s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Println("success fresh_limited_shop")
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doQueryPlayerGuild(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request JsonRequest
	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	pid, err := pidFromJsonRequest(&request)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	type GuildRespond struct {
		JsonRespond
		Gid          uint32 `json:"gid"`
		Exp          uint32 `json:"exp"`
		Name         string `json:"name"`
		Leader       uint32 `json:"leader"`
		Title        uint32 `json:"title"`
		TotalCont    uint32 `json:"total_cont"`
		LastCont     uint32 `json:"last_cont"`
		LastContTime uint32 `json:"last_cont_time"`
	}
	var guild GuildRespond

	db, err := database.Get("Role")
	defer db.Release()
	if err != nil {
		log.Printf("fail to query guild, get role database error:%s\n", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	rows, err := db.Query("SELECT  a.gid, a.name, a.exp, a.leader, b.title, b.total_cont, b.today_cont, unix_timestamp(b.cont_time) as cont_time FROM guild a, guildmember b WHERE b.pid= ? and a.gid = b.gid", pid)
	if err != nil {
		log.Printf("fail to query resource, select from guild error %s", err.Error())
		return buildErrorMessage(ERROR_SYSTEM)
	}
	for rows.Next() {
		if err := rows.Scan(&guild.Gid, &guild.Name, &guild.Exp, &guild.Leader, &guild.Title, &guild.TotalCont, &guild.LastCont, &guild.LastContTime); err != nil {
			log.Printf("fail to query player vit, scan guild error, %s", err.Error())
			return buildErrorMessage(ERROR_SYSTEM)
		}
	}
	guild.Error = Error(0)
	log.Printf("doQueryPlayerGuild, respond is `%+v`", guild)
	return buildRespond(guild)
}

func doSetSalary(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest

		Salary uint32
	}

	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	pid, err := pidFromJsonRequest(&request.JsonRequest)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	err = service.SetSalary(pid, request.Salary)
	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

//doAdsupportAddLoginGroup

func doAdsupportAddLoginGroup(_ *JsonRequest, bs []byte, sign bool) []byte {
	log.Println("doAdsupportAddLoginGroup")

	var request agame.ADSupportAddLoginGroupRequest
	log.Printf("----------------")
	err := json.Unmarshal(bs, &request)
	if err != nil {
		log.Println("json error", err)
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	log.Printf("%v", request)
	err = service.ADSupportAddLoginGroup(&request)
	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Printf("doAdsupportAddLoginGroup success,%v", request)
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doAdsupportAddInvestGroup(_ *JsonRequest, bs []byte, sign bool) []byte {
	log.Println("doAdsupportAddInvestGroup")

	var request agame.ADSupportAddInvestGroupRequest
	log.Printf("----------------")
	err := json.Unmarshal(bs, &request)
	if err != nil {
		log.Println("json error", err)
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	log.Printf("%v", request)
	err = service.ADSupportAddInvestGroup(&request)
	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Printf("doAdsupportAddInvestGroup success,%v", request)
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doAdsupportAddGroup(_ *JsonRequest, bs []byte, sign bool) []byte {
	log.Println("doAdsupportAddGroup")

	var request agame.ADSupportAddGroupRequest

	err := json.Unmarshal(bs, &request)
	if err != nil {
		log.Println("json error", err)
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	log.Printf("%v", request)
	err = service.ADSupportAddGroup(&request)

	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Printf("doAdsupportAddGroup success,%v", request)
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doAdsupportAddQuest(_ *JsonRequest, bs []byte, sign bool) []byte {
	log.Println("doAdsupportAddQuest")

	var request agame.ADSupportAddQuestRequest

	err := json.Unmarshal(bs, &request)
	if err != nil {
		log.Println("json error", err)
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	log.Printf("%v", request)
	err = service.ADSupportAddQuest(&request)

	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Printf("doAdsupportAddQuest success,%v", request)
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doAdsupportGetGroupid(_ *JsonRequest, bs []byte, sign bool) []byte {
	log.Println("doAdsupportGetGroupid")

	var request agame.ADSupportGetGroupidRequest

	err := json.Unmarshal(bs, &request)
	if err != nil {
		log.Println("json error", err)
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	log.Printf("%v", request)
	err = service.ADSupportGetGroupid(&request)

	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Printf("doAdsupportGetGroupid success,%v", request)
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doAdsupportreloadConfig(_ *JsonRequest, bs []byte, sign bool) []byte {
	log.Println("doAdsupportreloadConfig")

	var request agame.ADSupportreloadConfigRequest

	err := json.Unmarshal(bs, &request)
	if err != nil {
		log.Println("json error", err)
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	log.Printf("%v", request)
	err = service.ADSupportreloadConfig(&request)

	if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Printf("doAdsupportreloadConfig success,%v", request)
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doAdsupportinsertevent(_ *JsonRequest, bs []byte, sign bool) []byte {
	log.Println("doAdsupportinsertevent")

	var request agame.NotifyADSupportEventRequest

	err := json.Unmarshal(bs, &request)
	if err != nil {
		log.Println("json error", err)
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}
	log.Printf("%v", request)
	err = service.ADSupportInsertEvent(&request)

	if err != nil {
		log.Printf("doAdsupportinsertevent error,%v", request)
		return buildErrorMessage(ERROR_SYSTEM)
	} else {
		log.Printf("doAdsupportinsertevent success,%v", request)
		return buildErrorMessage(ERROR_SUCCESS)
	}
}

func doChangeAccount(_ *JsonRequest, bs []byte, sign bool) []byte {
	var request struct {
		JsonRequest
		New_account string `json:"new_account"`
		Channel     string `json:"channel"`
	}

	err := json.Unmarshal(bs, &request)
	if err != nil {
		return buildErrorMessage(ERROR_UNKNOWN_COMMAND)
	}

	pid, err := pidFromJsonRequest(&request.JsonRequest)
	if err == service.ErrPlayerNotExist || pid == 0 {
		return buildErrorMessage(ERROR_USER_NOT_EXIST)
	} else if err != nil {
		return buildErrorMessage(ERROR_SYSTEM)
	}

	if request.New_account == "" {
		log.Printf("new_account is empty", request)
		return buildErrorMessage(ERROR_PARAM_ERROR)
	}

	db, err := database.Get("Account")
	if err != nil {
		log.Println(err)
		return buildErrorMessage(ERROR_SYSTEM)
	}
	defer db.Release()

	var new_account string
	if request.Channel == "" {
		new_account = request.New_account
	} else {
		new_account = request.Channel + "." + request.New_account + "@an"
	}

	log.Printf("player %d change account to %s", pid, new_account)

	_, err = db.Exec("update account set account = ? where id = ?", new_account, pid)
	if err != nil {
		log.Println(err)
		return buildErrorMessage(ERROR_PARAM_ERROR)
	}
	return buildErrorMessage(ERROR_SUCCESS)
}

func doGMCommand(cmd string, bs []byte) []byte {
	bs, _ = service.SendGMCommand(cmd, bs)
	return bs
}
