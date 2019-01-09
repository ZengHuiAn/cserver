#ifndef _A_GAME_WORLD_REQUEST_PBC_DO_H_
#define _A_GAME_WORLD_REQUEST_PBC_DO_H_

#include <stdint.h>
#include "network.h"
#include "protocol.h"
#include "pbc_int64.h"

#define READ_REAL(name) double name = pbc_rmessage_real(request, #name, 0)
#define READ_INT(name) unsigned int name = pbc_rmessage_integer(request, #name, 0, 0)
#define READ_STR(name) const char * name = pbc_rmessage_string (request, #name, 0, 0)
#define READ_INT64(name) unsigned long long name = pbc_rmessage_int64(request, #name, 0)

#define WRITE_INT(name) pbc_wmessage_integer(respond, #name, name, 0);
#define WRITE_INT64(name) pbc_wmessage_int64(respond, #name, name);
#define WRITE_STR(name) pbc_wmessage_string (respond, #name, name, 0);

#define INIT_REQUET_RESPOND(req, res) \
	struct pbc_rmessage * request = protocol_new_r(req, data, len); \
	if (request == 0) { WRITE_DEBUG_LOG("decode request messsage %s failed", req); return;} \
	unsigned int result = RET_ERROR; \
	READ_INT(sn); \
	struct pbc_wmessage * respond = protocol_new_w(res); \
	if (respond == 0) { WRITE_DEBUG_LOG("build respond message %s failed", res); pbc_rmessage_delete(request); return; } \
	WRITE_INT(sn) \

#define FINI_REQUET_RESPOND(cmd, result) \
	pbc_wmessage_integer(respond, "result", result, 0); \
	send_pbc_message(conn, channel, cmd, respond); \
	pbc_rmessage_delete(request); \
	pbc_wmessage_delete(respond) 

#define BEGIN_FUNCTION(name, req, res) \
	void do_pbc_##name(resid_t conn, unsigned long long channel, const char * data, size_t len) \
	{ \
		INIT_REQUET_RESPOND(req, res); \
		struct Player * player = player_get(channel); \
		if (player == 0) { \
			WRITE_DEBUG_LOG("player `%llu` is not exist", channel); 	\
			result = RET_CHARACTER_NOT_EXIST; \
		} else  {


#define END_FUNCTION(cmd) \
		} \
		FINI_REQUET_RESPOND(cmd, result); \
	}
	


void do_pbc_login(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_logout(resid_t conn, unsigned long long channel, const char * data, size_t len);

void do_pbc_query_player(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_create_player(resid_t conn, unsigned long long channel, const char * data, size_t len);

//do_cell
void do_pbc_add_player_notification(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_get_player_info(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_get_player_hero_info(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_get_player_return_info(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_admin_reward(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_set_player_status(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_admin_player_kick(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_set_adult(resid_t conn, unsigned long long channel, const char * data, size_t len);

void do_pbc_query_item_package(resid_t conn, uint32_t channel, const char * data, size_t len);
void do_pbc_set_item_package(resid_t conn, uint32_t channel, const char * data, size_t len);
void do_pbc_del_item_package(resid_t conn, uint32_t channel, const char * data, size_t len);

void do_pbc_query_player_fight_info(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_player_fight_prepare(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_player_fight_confirm(resid_t conn, unsigned long long channel, const char * data, size_t len);

void do_pbc_quest_query_info(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_quest_set_status(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_quest_on_event(resid_t conn, unsigned long long channel, const char * data, size_t len);

void do_pbc_query_recommend_fight_info(resid_t conn, unsigned long long channel, const char * data, size_t len);


void fill_player_fight_data(struct pbc_wmessage * msg, struct Player * player, int ref, unsigned long long * heros, unsigned long long * assists, int nassists);

//ai
void do_pbc_query_unactive_ai(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_update_ai_active_time(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_change_ai_nick_name(resid_t conn, unsigned long long channel, const char * data, size_t len);

//buff
void do_pbc_change_buff(resid_t conn, unsigned long long channel, const char * data, size_t len);
void do_pbc_save_hero_capacity(resid_t conn, unsigned long long channel, const char * data, size_t len);

void do_pbc_query_server_info(resid_t conn, unsigned long long channel, const char * data, size_t len);

//trade
void do_pbc_trade_with_system(resid_t conn, unsigned long long channel, const char * data, size_t len); 


void do_pbc_unload_player(resid_t conn, uint32_t channel, const char * data, size_t len);
#endif
