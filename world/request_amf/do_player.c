#include <assert.h>
#include <string.h>

#include "network.h"
#include "log.h"
#include "message.h"
#include "player.h"
#include "package.h"
#include "amf.h"
#include "mtime.h"
#include "build_message.h"
#include "config.h"
#include "modules/hero.h"

#include "logic/aL.h"
#define _GET_I32(node, name) ATOLL(xmlGetValue(xmlGetChild(node, name, 0), "0"))

void do_query_player(resid_t conn, unsigned long long playerid, amf_value * v)
{
	
	if (v == 0 || amf_size(v) != 2) {
		SEND_RESPOND(conn, playerid, C_QUERY_PLAYER_RESPOND, 0, RET_PARAM_ERROR, 0);
		return;
	}

	uint32_t sn = amf_get_integer(amf_get(v, 0));
	unsigned long long query_player = amf_get_double(amf_get(v, 1));
	if (query_player == 0) {
		query_player = playerid;
	}

	if (query_player > AI_MAX_ID)
	CHECK_PID_AND_TRANSFORM(query_player);

	WRITE_INFO_LOG("player %llu query player %llu", playerid, query_player);

	struct Player * player = player_get(query_player);

	if (player == 0) {
		if (player_is_not_exist(playerid)) {
			SEND_RESPOND(conn, playerid, C_QUERY_PLAYER_RESPOND, sn, RET_CHARACTER_NOT_EXIST, 0);
		} else {
			SEND_RESPOND(conn, playerid, C_QUERY_PLAYER_RESPOND, sn, RET_ERROR, 0);
		}
	} else {
		amf_value * v = build_player_info_message(sn, player); 
		send_amf_message(conn, playerid, C_QUERY_PLAYER_RESPOND, v);
		amf_free(v); 
	}
	return;
}

void do_create_player(resid_t conn, unsigned long long playerid, amf_value * v)
{
	// assert(amf_type(v) == amf_array && amf_size(v) >= 4);
	if (amf_type(v) != amf_array || amf_size(v) < 2) {
		SEND_RESPOND(conn, playerid, C_CREATE_PLAYER_RESPOND, 0, RET_PARAM_ERROR, 0);
		return ;
	}

	WRITE_INFO_LOG("playe %llu create", playerid);

	uint32_t sn = amf_get_integer(amf_get(v, 0));
	const char * nick = amf_get_string(amf_get(v, 1));
	unsigned int head = LEADING_ROLE;

	int ret = aL_create_player(playerid, nick, head);
	if (ret != RET_SUCCESS) {
		SEND_RESPOND(conn, playerid, C_CREATE_PLAYER_RESPOND, sn, ret, 0);
	} else {
		struct Player * player = player_get(playerid);
		amf_value * v = build_player_info_message(sn, player); 
		send_amf_message(conn, playerid, C_CREATE_PLAYER_RESPOND, v);
		amf_free(v); 
	}
	return;
}

void fill_player_fight_data(struct pbc_wmessage * msg, struct Player * player, int ref, unsigned long long * heros, unsigned long long * assists, int nassists);
void do_query_player_power(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 1, C_QUERY_PLAYER_POWER_RESPOND);

	unsigned long long pid = playerid;
	if (amf_size(v) > 1) {
		pid = (unsigned long long)amf_get_double(amf_get(v, 1));
	}

	unsigned long long heros[HERO_INTO_BATTLE_MAX] = {0};
	unsigned long long nheros = 0;
	if (amf_size(v) > 2 && amf_type(amf_get(v, 2)) == amf_array) {
		amf_value * aheros = amf_get(v,2);
		unsigned int i;
		for (i = 0; i < amf_size(aheros) && i < HERO_INTO_BATTLE_MAX; i++) {
			heros[i] = (unsigned long long) amf_get_double(amf_get(aheros, i));
			nheros++;
		}
	}

	pid = (pid == 0) ? playerid : pid;

	struct Player * query_player = player_get(pid);

	if (query_player == 0) {
		SEND_RESPOND(conn, playerid, cmd, sn, RET_NOT_EXIST, 0);
		return;
	}

	struct pbc_wmessage * msg = protocol_new_w("FightPlayer");
	fill_player_fight_data(msg, query_player, 0, nheros ? heros : 0, 0, 0);

	struct pbc_slice slice;
	pbc_wmessage_buffer(msg, &slice);

	amf_value * res = amf_new_array(4);
	amf_set(res, 0, amf_new_integer(sn));
	amf_set(res, 1, amf_new_integer(RET_SUCCESS));
	amf_set(res, 2, amf_new_double(pid));
	amf_set(res, 3, amf_new_byte_array((const char*)slice.buffer, slice.len));
	send_amf_message(conn, playerid, cmd, res);

	pbc_wmessage_delete(msg);

	amf_free(res);
}


void do_change_nick_name(resid_t conn,  unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_NICK_NAME_CHANGE_RESPOND);
	
	const char * nickname = amf_get_string(amf_get(v, 1));
	int head = 0;
	if (amf_size(v) > 2) {
		head = amf_get_integer(amf_get(v, 2));
	}

	int title = -1;
	if (amf_size(v) > 3) {
		title = amf_get_integer(amf_get(v, 3));
	}

	int ret = aL_change_nick_name(player, nickname, head, title);

	SEND_RESPOND(conn, playerid, cmd, sn, ret, 0);

	return;
}

