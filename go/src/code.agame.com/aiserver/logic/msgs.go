package logic
import(
	"math/rand"
	"code.agame.com/aiserver/common"
	"code.agame.com/aiserver/log"
	"code.agame.com/aiserver/config"
)

// register
func init(){
	OnMsg(common.C_LOGIN_RESPOND,         on_login_msg)
	OnMsg(common.C_QUERY_PLAYER_RESPOND,  on_query_player_msg)
	OnMsg(common.C_LOGOUT_RESPOND,        on_logout_msg)
	OnMsg(common.C_CREATE_PLAYER_RESPOND, on_create_player_msg)

	OnMsg(common.C_GUILD_QUERY_APPLY_RESPOND, on_guild_query_apply_msg)
	OnMsg(common.C_GUILD_QUERY_GUILD_LIST_RESPOND, on_guild_query_guild_list_msg)
	OnMsg(common.C_GUILD_QUERY_MEMBERS_RESPOND, on_guild_query_members_msg)

	OnMsg(common.C_MANOR_ENTER_RESPOND, on_manor_enter_msg)
	OnMsg(common.C_MANOR_QUERY_PLACEHOLDER_RESPOND, on_manor_query_plaeholder_msg)
	OnMsg(common.C_MANOR_PREPARE_ATTACK_MONSTER_RESPOND, on_manor_prepare_attack_monster_msg)

	OnMsg(common.C_ARENA_JOIN_RESPOND, on_arena_join_msg)
	OnMsg(common.C_MAIL_CONTACT_GET_RESPOND, on_mail_contat_get_msg)
	OnMsg(common.C_MAIL_CONTACT_RECOMMEND_RESPOND, on_mail_contact_recommend_msg)
}

// callback
func on_login_msg(header common.ClientPacketHeader, bs []byte, request []interface{}, ai *common.AIObject)bool{
	log.Info("AI `%d` on_login_msg", ai.Pid)
	// [sn, result, playerid]
	if len(request) < 2 {
		return true
	}
	result := common.I2Int64(request[1])
	switch result {
	case common.RET_SUCCESS:
		log.Debug("AI `%d` on_login_msg, RET_SUCCESS", ai.Pid)
		ai.QueryPlayerInfo()
		return true
	case common.RET_CHARACTER_NOT_EXIST:
		log.Debug("AI `%d` on_login_msg, RET_CHARACTER_NOT_EXIST", ai.Pid)
		ai.CreatePlayer()
		return true
	default:
		log.Debug("AI `%d` on_login_msg, %d", ai.Pid, result)
		return false
	}
}
func on_query_player_msg(header common.ClientPacketHeader, bs []byte, request []interface{}, ai *common.AIObject)bool{
	log.Info("AI `%d` on_query_player_msg", ai.Pid)
	// [sn, result, playerid]
	if len(request) < 15 {
		return true
	}
	result := common.I2Int64(request[1])
	vip_lv := common.I2Int64(request[14])
	log.Debug("AI `%d` on_query_player_msg, %d", ai.Pid, result)
	if ai.IsLoging() {
		switch result {
		case common.RET_SUCCESS:
			ai.Name =common.I2String(request[3])
			return ai.OnLogin(vip_lv)
		default:
			return false
		}
	} else {
		return true
	}
}
func on_mail_contact_recommend_msg(header common.ClientPacketHeader, bs []byte, request []interface{}, ai *common.AIObject)bool{
	log.Info("AI `%d` on_mail_contact_recommend_msg", ai.Pid)
	// [sn, result, players]
	if len(request) < 3 {
		return true
	}
	sn := uint32(common.I2Int64(request[0]))
	result := common.I2Int64(request[1])
	log.Debug("AI `%d` on_mail_contact_recommend_msg, %d", ai.Pid, result)
	if result != common.RET_SUCCESS {
		return true
	}
	rpc_data := ai.GetData(sn)
	if rpc_data == nil {
		return true
	}
	friend_pids := rpc_data.([]int64)
	players := common.I2Array(request[2])
	if nil == players {
		return true
	}
	for i:=0; i<len(players); i++ {
		// prepare
		player := common.I2Array(players[i])
		if len(player) < 5 {
			continue
		}
		pid := common.I2Int64(player[0])

		// check dup
		var is_exist bool
		is_exist =false
		for j:=0; j<len(friend_pids); j++ {
			if friend_pids[j] == pid {
				is_exist =true
				break
			}
		}

		// try add
		if is_exist == false {
			ai.MailContactAdd(pid)
		}
	}
	return true
}
func on_logout_msg(header common.ClientPacketHeader, bs []byte, request []interface{}, ai *common.AIObject)bool{
	log.Info("AI `%d` on_logout_msg", ai.Pid)
	return false
}
func on_create_player_msg(header common.ClientPacketHeader, bs []byte, request []interface{}, ai *common.AIObject)bool{
	log.Info("AI `%d` on_create_player_msg", ai.Pid)
	if len(request) < 2 {
		return true
	}
	sn := uint32(common.I2Int64(request[0]))
	result := common.I2Int64(request[1])
	log.Debug("AI `%d` on_create_player_msg, %d", ai.Pid, result)

	rpc_data := ai.GetData(sn)
	if rpc_data == nil {
		return true
	}
	switch result {
	case common.RET_SUCCESS:
		ai.Name =common.I2String(rpc_data)
		ai.OnLogin(0)
		return true
	default:
		return false
	}
}
// guild
func on_guild_query_apply_msg(header common.ClientPacketHeader, bs []byte, request []interface{}, ai *common.AIObject)bool{
	log.Info("AI `%d` on_guild_query_apply_msg", ai.Pid)
	// [sn, ret, [playerid, name, level], ...];
	if len(request) < 2 {
		return true
	}
	result := common.I2Int64(request[1])
	log.Debug("AI `%d` on_guild_query_apply_msg, %d", ai.Pid, result)
	if result != common.RET_SUCCESS {
		return true
	}
	if len(request) < 3 {
		return true
	}
	applys:= common.I2Array(request[2])
	if nil == applys {
		return true
	}
	for i:=0; i<len(applys); i++ {
		list := common.I2Array(applys[i])
		if len(list) <= 0 {
			continue
		}
		pid := common.I2Int64(list[0])
		ai.GuildAudit(uint32(pid), 1)
	}
	return true
}
func on_guild_query_members_msg(header common.ClientPacketHeader, bs []byte, request []interface{}, ai *common.AIObject)bool{
	log.Info("AI `%d` on_guild_query_members_msg", ai.Pid)
	// [sn, result, "info"]
	if len(request) < 2 {
		return true
	}
	result := common.I2Int64(request[1])
	log.Debug("AI `%d` on_guild_query_members_msg, %d", ai.Pid, result)
	switch result {
	case common.RET_SUCCESS:
		return true
	case common.RET_GUILD_NOT_EXIST:
		ai.QueryGuildList()
		return true
	default:
		return true
	}
}
func on_guild_query_guild_list_msg(header common.ClientPacketHeader, bs []byte, request []interface{}, ai *common.AIObject)bool{
	log.Info("AI `%d` on_guild_query_guild_list_msg", ai.Pid)
	if len(request) < 2 {
		return true
	}
	result := common.I2Int64(request[1])
	log.Debug("AI `%d` on_guild_query_guild_list_msg, %d", ai.Pid, result)
	if result != common.RET_SUCCESS {
		return true
	}
	if len(request) < 3 {
		return true
	}
	guild_list := common.I2Array(request[2])
	if guild_list == nil {
		return true
	}
	guild_cnt := len(guild_list)
	if guild_cnt == 0 {
		log.Debug("guild_cnt is 0, ")
		return true
	}

	// rand join
	rand_num := int(rand.Int())
	for i :=0; i<3; i++ {
		idx := (rand_num + i) % guild_cnt
		guild_info := common.I2Array(guild_list[idx])
		if len(guild_info) < 1 {
			continue
		}
		guild_id := int32(common.I2Int64(guild_info[0]))
		if guild_id > 0 {
			ai.GuildJoin(guild_id)
		}
	}
	return true
}
// manor
func on_manor_enter_msg(header common.ClientPacketHeader, bs []byte, request []interface{}, ai *common.AIObject)bool{
	log.Info("AI `%d` on_manor_enter_msg", ai.Pid)
	if len(request) < 2 {
		return true
	}
	sn := uint32(common.I2Int64(request[0]))
	result := common.I2Int64(request[1])
	log.Debug("AI `%d` on_manor_enter_msg, %d", ai.Pid, result)
	if result != common.RET_SUCCESS {
		return true
	}
	rpc_data := ai.GetData(sn)
	if rpc_data == nil {
		return true
	}
	cache := rpc_data.([]interface{})
	manor_type := uint32(common.I2Int64(cache[0]))
	manor_id := uint32(common.I2Int64(cache[1]))
	log.Debug("AI `%d` manor type is %d, manor id is %d", ai.Pid, manor_type, manor_id)
	if manor_type != common.MANOR_WORLD {
		if manor_id == ai.Pid {
			ai.ManorAttackBoss(manor_id)
			ai.ManorGatherResource(common.MANOR_RESOURCE_LQ)
			ai.ManorGatherResource(common.MANOR_RESOURCE_WJXD)
			ai.ManorGatherResource(common.MANOR_RESOURCE_NC)
			ai.ManorGatherResource(common.MANOR_RESOURCE_YB)
		} else {
			ai.ManorAssistResource(manor_id, common.MANOR_RESOURCE_LQ)
			ai.ManorAssistResource(manor_id, common.MANOR_RESOURCE_WJXD)
			ai.ManorAssistResource(manor_id, common.MANOR_RESOURCE_NC)
			ai.ManorAssistResource(manor_id, common.MANOR_RESOURCE_YB)
		}
		ai.ManorGetPlaceholderList(manor_id)
	}
	return true
}
func on_manor_query_plaeholder_msg(header common.ClientPacketHeader, bs []byte, request []interface{}, ai *common.AIObject)bool{
	log.Info("AI `%d` on_manor_query_plaeholder_msg", ai.Pid)
	if len(request) < 2 {
		return true
	}
	sn := uint32(common.I2Int64(request[0]))
	result := common.I2Int64(request[1])
	log.Debug("AI `%d` on_manor_query_plaeholder_msg, %d", ai.Pid, result)
	if result != common.RET_SUCCESS {
		return true
	}
	if len(request) < 3 {
		return true
	}
	list := common.I2Array(request[2])
	if list == nil {
		return true
	}
	rpc_data := ai.GetData(sn)
	if rpc_data == nil {
		return true
	}
	manor_id := uint32(common.I2Int64(rpc_data))
	for i:=0; i<len(list); i++ {
		placeholder_info := common.I2Array(list[i])
		if len(placeholder_info)==3 {
			placeholder := int32(common.I2Int64(placeholder_info[0]))
			t := int32(common.I2Int64(placeholder_info[1]))
			// id := int32(common.I2Int64(placeholder_info[2]))

			if t == common.MANOR_PLACEHOLDER_TYPE_MONSTER {
				ai.ManorPrepareAttackMonster(manor_id, placeholder)
			} else if t == common.MANOR_PLACEHOLDER_TYPE_TREASURE {
				ai.ManorPickTreasure(placeholder)
			}
		}
	}
	return true
}
func on_manor_prepare_attack_monster_msg(header common.ClientPacketHeader, bs []byte, request []interface{}, ai *common.AIObject)bool{
	log.Info("AI `%d` on_manor_prepare_attack_monster_msg", ai.Pid)
	if len(request) < 4 {
		return true
	}
	sn := uint32(common.I2Int64(request[0]))
	result := common.I2Int64(request[1])
	fight_data := common.I2String(request[3])
	log.Debug("AI `%d` on_manor_prepare_attack_monster_msg, %d", ai.Pid, result)
	if result != common.RET_SUCCESS {
		return true
	}
	rpc_data := ai.GetData(sn)
	if rpc_data == nil {
		return true
	}
	cache_data := rpc_data.([]int64)
	manor_id := uint32(cache_data[0])
	placeholder := int32(cache_data[1])
	ai.ManorCheckAttackMonster(manor_id, placeholder, fight_data)
	return true
}
// arena
func on_arena_join_msg(header common.ClientPacketHeader, bs []byte, request []interface{}, ai *common.AIObject)bool{
	log.Info("AI `%d` on_arena_join_msg", ai.Pid)
	if len(request) < 3 {
		return true
	}
	// sn := uint32(common.I2Int64(request[0]))
	result := common.I2Int64(request[1])
	//self_pos := common.I2Int64(request[2])
	log.Debug("AI `%d` on_arena_join_msg, %d", ai.Pid, result)
	if result != common.RET_SUCCESS {
		return true
	}
	neighbors := common.I2Array(request[3])
	neighbor_cnt :=len(neighbors)
	if neighbor_cnt <= 1 {
		log.Debug("len(neighbors) is <= 1")
		return true
	}

	// prepare pos list
	pos_list := make([]int32, 0, neighbor_cnt)
	for i:=0; i<neighbor_cnt; i++ {
		neighbor := common.I2Array(neighbors[i])
		if len(neighbor) == 2 {
			if ai.Pid == uint32(common.I2Int64(neighbor[1])) {
				break
			}
			pos_list = append(pos_list, int32(common.I2Int64(neighbor[0])))
		}
	}
	if len(pos_list) > 0 {
		defend_pos := pos_list[rand.Int() % (len(pos_list))]
		ai.ArenaAttack(defend_pos)
	}
	return true
}
// mail contact
func on_mail_contat_get_msg(header common.ClientPacketHeader, bs []byte, request []interface{}, ai *common.AIObject)bool{
	log.Info("AI `%d` on_mail_contat_get_msg", ai.Pid)
	if len(request) < 3 {
		return true
	}
	sn := uint32(common.I2Int64(request[0]))
	result := common.I2Int64(request[1])
	log.Debug("AI `%d` on_mail_contat_get_msg, %d", ai.Pid, result)
	if result != common.RET_SUCCESS {
		return true
	}
	rpc_data := ai.GetData(sn)
	if rpc_data == nil {
		return true
	}
	flag   := common.I2Int64(rpc_data)
	list := common.I2Array(request[2])
	if len(list) == 0 {
		log.Debug("AI `%d` has not any friends", ai.Pid)
		return true
	}

	if flag == common.FLAG_MANOR_ENTER {
		idx := rand.Int() % len(list)
		friend := common.I2Array(list[idx])
		if len(friend) == 0 {
			log.Debug("unknown respond value")
			return true
		}
		friend_pid := uint32(common.I2Int64(friend[0]))
		if friend_pid != 0 {
			ai.ManorEnter(common.MANOR_HOME, friend_pid)
		}
	} else if flag == common.FLAG_MAIL_CONTACT_AUTO_ADD {
		if int64(len(list)) < config.Config.AutoAddFriendUpperBound {
			friend_pids :=make([]int64, 0)
			for i:=0; i<len(list); i++ {
				friend := common.I2Array(list[i])
				if len(friend) == 0 {
					log.Debug("unknown respond value")
					return true
				}
				friend_pid := common.I2Int64(friend[0])
				friend_pids =append(friend_pids, friend_pid)
			}
			ai.QueryMailContactRecommend(friend_pids)
		}
	}
	return true
}
