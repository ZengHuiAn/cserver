#include <assert.h>
#include <arpa/inet.h>

#include "player.h"

#include "dispatch.h"
#include "network.h"
#include "package.h"
#include "log.h"
#include "amf.h"
#include "message.h"
#include "script.h"

#include "request_amf/do.h"
#include "request_pbc/do.h"

#include "realtime.h"
#include "addicted.h"

#include "logic/aL.h"

#include "notify.h"
#include "mtime.h"

#include "event_manager.h"

#include "modules/request_queue.h"

#include "config.h"
#include "config/hero.h"

static int process_request(struct network * net, resid_t conn, unsigned long long playerid, unsigned int command, unsigned int flag, const char* data, unsigned int data_len);
void do_echo(resid_t conn, unsigned long long playerid, uint32_t cmd, amf_value * v)
{
	send_amf_message(conn, playerid, cmd, v);
}

void do_amf_dispatch(resid_t conn, unsigned long long playerid, uint32_t command, const char * data, size_t data_len);
void do_pbc_dispatch(resid_t conn, unsigned long long playerid, uint32_t command, const char * data, size_t data_len);

static void do_pbc_service_register(resid_t conn, uint32_t channel, const char * data, size_t len);

static void Kick(struct network * net, unsigned int conn, unsigned long long pid, unsigned int reason) 
{
	char res_buf[1024] = {0};
	struct translate_header * res_header = (struct translate_header*)res_buf;
	res_header->flag = htonl(1);
	res_header->playerid = htonl(pid);
	res_header->cmd = htonl(C_LOGOUT_RESPOND);
	size_t offset = sizeof(struct translate_header);
	size_t tlen = sizeof(res_buf);
	offset += amf_encode_array(res_buf + offset, tlen - offset, 3);
	offset += amf_encode_integer(res_buf + offset, tlen - offset, 0);
	offset += amf_encode_integer(res_buf + offset, tlen - offset, 0);
	offset += amf_encode_integer(res_buf + offset, tlen - offset, reason);
	res_header->len = htonl(offset);
	_agN_send(net, conn, res_buf, offset);
}

static size_t process_message(struct network * net, resid_t conn,
		const char * data, size_t len,
		void * ctx)
{
	if (len < sizeof(struct translate_header)) {
		return 0;
	}

	struct translate_header * tran_info = (struct translate_header*)data;
	size_t package_len = ntohl(tran_info->len);
	if (len < package_len) {
		return 0;
	}
	try_unload_player_from_zombie_list();

	uint32_t flag = ntohl(tran_info->flag);
	uint32_t command = ntohl(tran_info->cmd);
	unsigned long long playerid = ntohl(tran_info->playerid);
	unsigned int serverid = ntohl(tran_info->serverid);
	size_t data_len = package_len;

	if (serverid == 0 && playerid != 0)
	{
		WRITE_ERROR_LOG("process_message flag %d, command %d, playerid %llu, serverid = 0!", flag, command, playerid);
		return 0;
	}
	if (playerid > 0) {
		//CHECK_PID_AND_TRANSFORM(playerid);
		NTOHL_PID_AND_SID(playerid, serverid);

		Player * player = player_get_online(playerid);
		if (player) {
			// 在线 踢掉
			resid_t xconn = player_get_conn(playerid);
			if (xconn != conn) {
				Kick(net, xconn, playerid, LOGOUT_ANOTHER_LOGIN);
			}
		}

		if (!addicted_can_login(playerid)) {
			if (command != C_LOGIN_REQUEST && command != C_LOGOUT_REQUEST) {
				// 防沉迷时间已到, 只接收login和logout消息
				// login时候可能修改用户的防沉迷状态
				return package_len;
			}
		} else {
			if (player_get(playerid) != 0) {
				// 创建了角色的用户才算作在线
				realtime_online_add(playerid);
			}
			addicted_login(playerid);
		}
		player_set_conn(playerid, conn);
	}

	data += sizeof(struct translate_header);
	data_len -= sizeof(struct translate_header);

	WRITE_DEBUG_LOG("recv command %d of player %llu @ conn %u",
			command, playerid, conn);
	if(playerid && command!=C_LOGIN_REQUEST && command!=C_CREATE_PLAYER_REQUEST){
		request_queue_push(playerid, net, command, flag, data, data_len);
		while(PNR_MORE == process_next_request(playerid));
		return package_len;
	}
	else{
		if(0 == process_request(net, conn, playerid, command, flag, data, data_len)){
			WRITE_DEBUG_LOG("finished command %d of player %llu @ conn %u\n---------", command, playerid, conn);
			return package_len;
		}
		else{
			agEvent_schedule();
			DATA_FLUSH_ALL();
			notification_clean();
			WRITE_DEBUG_LOG("fail to process command %d of player %llu @ conn %u\n---------", command, playerid, conn);
			return 0;
		}
	}
}

static int process_request(struct network * net, resid_t conn, unsigned long long playerid, unsigned int command, unsigned int flag, const char* data, unsigned int data_len)
{
	size_t read_len = 0;
	amf_value * v = 0;
	switch(flag) {
		case 1:
			// amf_dump(data, data_len);
			v = amf_read(data, data_len, &read_len);
			if (v == 0) {
				WRITE_ERROR_LOG("player %u parse amf failed", conn);
				// char filename[256] = {0};
				// sprintf(filename, "./amf.error.%lu.data", agT_current());
				// FILE * f = fopen(filename, "wb");
				// fwrite(data, 1, data_len, f);
				// fclose(f);
				Kick(net, conn, playerid, LOGOUT_ADMIN_KICK);
				// _agN_close(net, conn);
				return -1;
			}

			// assert(read_len == data_len);
			if (read_len != data_len) {
				WRITE_WARNING_LOG("player %llu amf format error read_len != data_len, kick", playerid);
				Kick(net, conn, playerid, LOGOUT_ADMIN_KICK);
				return -1;
			};

			// assert(amf_type(v) == amf_array);
			if (amf_type(v) != amf_array) {
				WRITE_WARNING_LOG("player %llu amf message is not array, kick", playerid);
				Kick(net, conn, playerid, LOGOUT_ADMIN_KICK);
				return -1;
			}
			//do_amf_dispatch(conn, playerid, command, data, data_len);
			break;
		case 2:
			//do_pbc_dispatch(conn, playerid, command, data, data_len);
			break;
		default:
			Kick(net, conn, playerid, LOGOUT_ADMIN_KICK);
			WRITE_ERROR_LOG("unknown flag %u of message "
					"from conn %u failed", flag, conn);
			return -1;
	}


#define COMMAND_AMF_ENTRY(REQUEST, func) \
	case REQUEST: \
		if (flag == 1) do_##func(conn, playerid, v); \
		break

#define COMMAND_PBC_ENTRY(REQUEST, func) \
	case REQUEST: \
		if (flag == 2) do_pbc_##func(conn, playerid, data, data_len); \
		break

#define COMMAND_ENTRY(REQUEST, func) \
	case REQUEST: \
		if (flag == 1) do_##func(conn, playerid, v); \
		else if (flag == 2) do_pbc_##func(conn, playerid, data, data_len); \
		break;


	WRITE_DEBUG_LOG("start do command %d of player %llu @ conn %u",
			command, playerid, conn);

        switch(command) {
                COMMAND_AMF_ENTRY(C_LOGIN_REQUEST,                              login);
                COMMAND_AMF_ENTRY(C_LOGOUT_REQUEST,                             logout);
                COMMAND_AMF_ENTRY(C_QUERY_PLAYER_REQUEST,                       query_player);
                COMMAND_AMF_ENTRY(C_CREATE_PLAYER_REQUEST,                      create_player);
				COMMAND_AMF_ENTRY(C_QUERY_PLAYER_POWER_REQUEST,                 query_player_power);
				COMMAND_PBC_ENTRY(S_UNLOAD_PLAYER_REQUEST, 		unload_player);

                COMMAND_AMF_ENTRY(C_QUERY_ITEM_REQUEST,                         query_item);

                COMMAND_AMF_ENTRY(C_QUERY_REWARD_REQUEST,                       query_reward);
                COMMAND_AMF_ENTRY(C_RECEIVE_REWARD_REQUEST,                     receive_reward);

                COMMAND_AMF_ENTRY(C_QUERY_ONE_TIME_REWARD_REQUEST,              query_one_time_reward);
                COMMAND_AMF_ENTRY(C_RECV_ONE_TIME_REWARD_REQUEST,               recv_one_time_reward);

                COMMAND_AMF_ENTRY(C_QUERY_HERO_REQUEST,                         query_hero);
                COMMAND_AMF_ENTRY(C_QUERY_HERO_ITEM_REQUEST,                    query_hero_item);
                COMMAND_AMF_ENTRY(C_TEST_ADD_HERO_REQUEST,                      gm_add_hero);
                COMMAND_AMF_ENTRY(C_HERO_ADD_EXP_REQUEST,                       hero_add_exp);
                COMMAND_AMF_ENTRY(C_HERO_STAR_UP_REQUEST,                       hero_star_up);
                COMMAND_AMF_ENTRY(C_HERO_STAGE_UP_REQUEST,                      hero_stage_up);
                COMMAND_AMF_ENTRY(C_HERO_STAGE_SLOT_UNLOCK_REQUEST,             hero_stage_slot_unlock);
                COMMAND_AMF_ENTRY(C_QUERY_TALENT_REQUEST,                       query_talent);
                COMMAND_AMF_ENTRY(C_RESET_TALENT_REQUEST,                       reset_talent);
                COMMAND_AMF_ENTRY(C_UPDATE_TALENT_REQUEST,                      update_talent);
                COMMAND_AMF_ENTRY(C_GM_SEND_REWARD_REQUEST,                     gm_send_reward);
                COMMAND_AMF_ENTRY(C_HERO_UPDATE_FIGHT_FORMATION_REQUEST,        hero_update_fight_formation);
                COMMAND_AMF_ENTRY(C_HERO_SELECT_SKILL_REQUEST,                  hero_select_skill);
		COMMAND_AMF_ENTRY(C_HERO_ITEM_SET_REQUEST, 			hero_item_set);

                COMMAND_AMF_ENTRY(C_QUERY_EQUIP_INFO_REQUEST,                   query_equip_info);
                COMMAND_AMF_ENTRY(C_EQUIP_LEVEL_UP_REQUEST,                     equip_level_up);
                COMMAND_AMF_ENTRY(C_EQUIP_STAGE_UP_REQUEST,                     equip_stage_up);
                COMMAND_AMF_ENTRY(C_EQUIP_EAT_REQUEST,                          equip_eat);
				COMMAND_AMF_ENTRY(C_EQUIP_REPLACE_PROPERTY_REQUEST,             equip_replace_property);
				COMMAND_AMF_ENTRY(C_EQUIP_REFRESH_PROPERTY_REQUEST,             equip_refresh_property);
                COMMAND_AMF_ENTRY(C_EQUIP_UPDATE_FIGHT_FORMATION_REQUEST,       equip_update_fight_formation);
                COMMAND_AMF_ENTRY(C_EQUIP_DECOMPOSE_REQUEST,                    equip_decompose);
                COMMAND_AMF_ENTRY(C_EQUIP_AFFIX_GROW_REQUEST,                   equip_affix_grow);

                COMMAND_AMF_ENTRY(C_QUERY_ITEM_PACKAGE_REQUEST,                 query_item_package);
                COMMAND_AMF_ENTRY(C_QUERY_CONSUME_ITEM_PACKAGE_REQUEST,         query_consume_item_package);
                COMMAND_PBC_ENTRY(S_SET_ITEM_PACKAGE_REQUEST,                   set_item_package);
                COMMAND_PBC_ENTRY(S_DEL_ITEM_PACKAGE_REQUEST,                   del_item_package);
                COMMAND_PBC_ENTRY(S_QUERY_ITEM_PACKAGE_REQUEST,                 query_item_package);

                COMMAND_AMF_ENTRY(C_QUERY_FIGHT_REQUEST,                        pve_query_fight);
                COMMAND_AMF_ENTRY(C_FIGHT_PREPARE_REQUEST,                      pve_fight_prepare);
                COMMAND_AMF_ENTRY(C_FIGHT_CHECK_REQUEST,                        pve_fight_check);
                COMMAND_AMF_ENTRY(C_PVE_FIGHT_FAST_PASS_REQUEST,                pve_fight_fast_pass);
		COMMAND_AMF_ENTRY(C_FIGHT_COUNT_RESET_REQUEST,			fight_count_reset);

                // COMMAND_AMF_ENTRY(C_HERO_LEVEL_UP_REQUEST,                   hero_level_up);
				COMMAND_AMF_ENTRY(C_NICK_NAME_CHANGE_REQUEST, 			        change_nick_name);
				
				COMMAND_ENTRY(C_QUERY_QUEST_REQUEST,                            quest_query_info);
				COMMAND_ENTRY(C_SET_QUEST_STATUS_REQUEST,                       quest_set_status);
				COMMAND_ENTRY(C_QUEST_ON_EVENT_REQUEST,                         quest_on_event);
				COMMAND_AMF_ENTRY(C_QUEST_GM_FORCE_SET_STATUS_REQUEST,          quest_gm_force_set_status);
				COMMAND_PBC_ENTRY(S_NOTIFY_QUSET_EVENT_REQUEST,                 quest_on_event);

                COMMAND_AMF_ENTRY(C_TICK_REQUEST,                               tick);

                COMMAND_PBC_ENTRY(S_SERVICE_REGISTER_REQUEST,                   service_register);
                COMMAND_PBC_ENTRY(S_GET_PLAYER_INFO_REQUEST,                    get_player_info);
                COMMAND_PBC_ENTRY(S_GET_PLAYER_HERO_INFO_REQUEST,               get_player_hero_info);
                COMMAND_PBC_ENTRY(S_ADD_PLAYER_NOTIFICATION_REQUEST,            add_player_notification);
                COMMAND_PBC_ENTRY(S_ADMIN_REWARD_REQUEST,                       admin_reward);

				COMMAND_PBC_ENTRY(S_QUERY_PLAYER_FIGHT_INFO_REQUEST,            query_player_fight_info);
				COMMAND_PBC_ENTRY(S_PLAYER_FIGHT_PREPARE_REQUEST,               player_fight_prepare);
				COMMAND_PBC_ENTRY(S_PLAYER_FIGHT_CONFIRM_REQUEST,               player_fight_confirm);
				COMMAND_PBC_ENTRY(S_QUERY_RECOMMEND_FIGHT_INFO_REQUEST,         query_recommend_fight_info);
				COMMAND_PBC_ENTRY(S_SET_PLAYER_STATUS_REQUEST, set_player_status);

                COMMAND_AMF_ENTRY(C_QUERY_PLAYER_TITLE_REQUEST,                 query_title);

				COMMAND_PBC_ENTRY(S_QUERY_UNACTIVE_AI_REQUEST, query_unactive_ai);
				COMMAND_PBC_ENTRY(S_UPDATE_AI_ACTIVE_TIME_REQUEST, update_ai_active_time);
				COMMAND_PBC_ENTRY(S_CHANGE_AI_NICK_NAME_REQUEST, change_ai_nick_name);

				//buff
                COMMAND_AMF_ENTRY(C_QUERY_BUFF_REQUEST,                        query_buff);
	
                COMMAND_AMF_ENTRY(C_QUERY_COMPEN_ITEM_REQUEST, query_compen_item);

                COMMAND_AMF_ENTRY(C_DRAW_COMPEN_ITEM_REQUEST, draw_compen_item);
		
                COMMAND_PBC_ENTRY(S_CHANGE_BUFF_REQUEST,                       change_buff);
                COMMAND_PBC_ENTRY(S_SAVE_HERO_CAPACITY_REQUEST,                save_hero_capacity);

                COMMAND_AMF_ENTRY(C_HERO_ADD_EXP_BY_ITEM_REQUEST,              hero_add_exp_by_item);
                COMMAND_AMF_ENTRY(C_QUERY_RANK_REQUEST,                        query_rank);
                COMMAND_AMF_ENTRY(C_QUERY_FIRE_REQUEST,                        query_fire);

                COMMAND_PBC_ENTRY(S_GET_SERVER_INFO_REQUEST,	query_server_info);

                //COMMAND_AMF_ENTRY(C_EQUIP_SELL_TO_SYSTEM_REQUEST,              equip_sell_to_system);
                //COMMAND_AMF_ENTRY(C_EQUIP_BUY_FROM_SYSTEM_REQUEST,             equip_buy_from_system);
                COMMAND_AMF_ENTRY(C_QUERY_EQUIP_INFO_BY_UUID_REQUEST,          query_equip_info_by_uuid);
				COMMAND_PBC_ENTRY(S_TRADE_WITH_SYSTEM_REQUEST,	trade_with_system);

                COMMAND_AMF_ENTRY(C_GET_FASHION_REQUEST, hero_get_fashion);
				
                default:
                        //script_run(command, playerid, v);
                        WRITE_WARNING_LOG("client %u unknown command %u", 
                                conn, command);
                        break;
        }
        if (v) amf_free(v);

        agEvent_schedule();
        DATA_FLUSH_ALL();
        notification_clean();
        return 0;
}
/* 返回值:0 => 有更多待处理请求, 1 => 正在忙, 2 => 无更多待处理请求, -1 => 出错
enum {
	PNR_ERROR  = -1,
	PNR_MORE   =  0,
	PNR_BUSY   =  1,
	PNR_EMPTY  =  2,
}
*/
int process_next_request(unsigned long long pid){
	Player* player =player_get_online(pid);
	if(!player) return PNR_EMPTY;

	PREQUEST_ITEM item =request_queue_front(pid);
	if(item == 0){
		return PNR_EMPTY;
	}	
	if(item->busy){
		return PNR_BUSY;
	}
	const char* data      =item->data;
	unsigned int data_len =item->length;
	unsigned long long playerid =item->playerid;
	unsigned int command  =item->cmd;
	unsigned int flag     =item->flag;
	struct network * net  =item->net;
	resid_t conn          =player_get_conn(playerid);
	

	if(-1 == process_request(net, conn, playerid, command, flag, data, data_len)){
		WRITE_DEBUG_LOG("fail to process command %d of player %llu @ conn %u\n---------", command, playerid, conn);
		return PNR_ERROR;
	}

	// try process next
	PREQUEST_ITEM tmp_item =request_queue_front(pid);
	if(item == tmp_item){
		if(item->busy){
			WRITE_DEBUG_LOG("pending command %d of player %llu @ conn %u\n---------", command, playerid, conn);
			return PNR_BUSY;
		}
		else{
			request_queue_pop(playerid);
			WRITE_DEBUG_LOG("finished command %d of player %llu @ conn %u\n---------", command, playerid, conn);
			item =request_queue_front(playerid);
			return item ? PNR_MORE : PNR_EMPTY;
		}
	}
	else{
		if(tmp_item != 0){
			WRITE_ERROR_LOG("WTF(1) %s(%d), tmp_item musqt be 0", __FUNCTION__, __LINE__);
		}
		if(SUPPORT_ZOMBIE_LIST){
			WRITE_ERROR_LOG("WTF(1) %s(%d)---------", __FUNCTION__, __LINE__);
		}
		if (command != C_LOGOUT_REQUEST) {
			WRITE_ERROR_LOG("WTF(2) %s(%d)---------", __FUNCTION__, __LINE__);
		}
		return PNR_EMPTY;
	}
}

static resid_t gateway_conn = INVALID_ID;
resid_t get_gateway_conn(){
	return gateway_conn;
}
void reset_gateway_conn(){
	gateway_conn =INVALID_ID;
}
static void do_pbc_service_register(resid_t conn, uint32_t channel, const char * data, size_t len)
{
	const char * proto = "ServiceRegisterRequest";
	struct pbc_rmessage * request = protocol_new_r(proto, data, len);
	if (request == 0) {
		WRITE_DEBUG_LOG("decode request messsage %s failed", proto);
		return;
	} 

	unsigned int type = pbc_rmessage_integer(request, "type", 0, 0);
	if (type == 1) {
		realtime_online_clean();

		unsigned int i;
		unsigned int n = pbc_rmessage_size(request, "players");
		for(i = 0; i < n ; i++) {
			unsigned long long pid = (unsigned long long)pbc_rmessage_real(request, "players", i);
			realtime_online_add(pid);
		}

		WRITE_DEBUG_LOG("gateway reconnected, count %u", realtime_online_count());
		gateway_conn =conn;
	}
	pbc_rmessage_delete(request);
}

static void on_closed(struct network * net, resid_t conn, int error, void * ctx)
{
	WRITE_WARNING_LOG("client %u closed %d", conn, error);
}

static struct network_handler dispatch_handler = {0};
int start_dispatch(resid_t conn)
{
	if (dispatch_handler.on_message == 0) {
		dispatch_handler.on_message = process_message;
		dispatch_handler.on_closed = on_closed;
	}

	agN_set_handler(conn, &dispatch_handler, 0);
	return 0;
}

int aL_logout(unsigned long long playerid);	
void kickPlayer(unsigned long long playerid, unsigned int reason)
{
	resid_t xconn = player_get_conn(playerid);
	char res_buf[1024] = {0};
	struct translate_header * res_header = (struct translate_header*)res_buf;
	res_header->flag = htonl(1);
	res_header->playerid = htonl(playerid);
	res_header->cmd = htonl(C_LOGOUT_RESPOND);
	size_t offset = sizeof(struct translate_header);
	size_t tlen = sizeof(res_buf);

	offset += amf_encode_array(res_buf + offset, tlen - offset, 3);
	offset += amf_encode_integer(res_buf + offset, tlen - offset, 0);
	offset += amf_encode_integer(res_buf + offset, tlen - offset, 0);
	offset += amf_encode_integer(res_buf + offset, tlen - offset, reason);

	res_header->len = htonl(offset);
	agN_send(xconn, res_buf, offset);

	aL_logout(playerid);
}
void broadcast_to_client(const uint32_t cmd, const uint32_t flag, const char* msg, const int32_t msg_len, const int32_t count, const unsigned long long* pids){
	if(!msg || msg_len<=0){
		return;
	}
	const resid_t conn =get_gateway_conn();
	if(conn == INVALID_ID){
		WRITE_DEBUG_LOG("fail to call %s, gateway not connect", __FUNCTION__);
		return;
	}
	struct pbc_wmessage * req = protocol_new_w("ServiceBroadcastRequest");
	if (req == 0){
		WRITE_DEBUG_LOG("fail to call %s, build request message ServiceBroadcastRequest failed", __FUNCTION__);
		return;
	}
	int32_t i=0;
	for(i=0; i<count; ++i){
		pbc_wmessage_integer(req, "pid", pids[i], 0);
	}
	pbc_wmessage_integer(req, "cmd", cmd, 0);
	pbc_wmessage_integer(req, "flag", flag, 0);
	pbc_wmessage_string(req, "msg", msg, msg_len);
	send_pbc_message(conn, 0, S_SERVICE_BROADCAST_REQUEST, req);
	pbc_wmessage_delete(req);
}
