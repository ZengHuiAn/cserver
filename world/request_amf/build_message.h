#ifndef _A_GAME_WORLD_REQUEST_BUILD_MESSAGE_H_
#define _A_GAME_WORLD_REQUEST_BUILD_MESSAGE_H_

#include "amf.h"
#include "modules/property.h"

#define SEND_PLAYER_INFO(player) \
	do {	\
		amf_value * v = build_player_info_message(sn, player); \
		send_amf_message_to(player_get_id(player), C_QUERY_PLAYER_RESPOND, v); \
		amf_free(v); \
	} while(0)

#define SEND_ALL_INFO(player) \
	do {	\
		SEND_PLAYER_INFO(player); 	\
	} while(0)

#define SEND_INFO(playerid, cmd, sn, ret, info) \
	do { \
		amf_value * v = build_message(sn, ret, info); \
		send_amf_message_to(playerid, cmd, v); \
		amf_free(v); \
	} while(0);


#define SEND_RESPOND(conn, channel, cmd, sn, ret, info) \
        do { \
		amf_value * v = amf_new_array((info)?3:2); \
		amf_set(v, 0, amf_new_integer(sn)); \
		amf_set(v, 1, amf_new_integer(ret)); \
		if (info) amf_set(v, 2, amf_new_string(info, 0)); \
		send_amf_message(conn, channel, cmd, v); \
		amf_free(v);  \
	} while(0)


#define CHECK_PARAM(conn, channel, request, n, rcmd) \
	if (amf_type(v) != amf_array || amf_size(v) != n) { \
		SEND_RESPOND(conn, channel, rcmd, 0, RET_PARAM_ERROR, 0); \
		return; \
	} \
	uint32_t sn = amf_get_integer(amf_get(v, 0)); \
	struct Player * player = player_get(channel); \
	unsigned int cmd = rcmd; \
	if (player == 0) { \
		SEND_RESPOND(conn, channel, rcmd, sn, RET_CHARACTER_NOT_EXIST, 0); \
		return; \
	} \

#define CHECK_MIN_PARAM(conn, channel, request, n, rcmd) \
	if (amf_type(v) != amf_array || amf_size(v) < n) { \
		SEND_RESPOND(conn, channel, rcmd, 0, RET_PARAM_ERROR, 0); \
		return; \
	} \
	uint32_t sn = amf_get_integer(amf_get(v, 0)); \
	struct Player * player = player_get(channel); \
	unsigned int cmd = rcmd; \
	if (player == 0) { \
		SEND_RESPOND(conn, channel, rcmd, sn, RET_CHARACTER_NOT_EXIST, 0); \
		return; \
	} \


	
amf_value * build_message(uint32_t sn, int result,
		const char * info);
amf_value * build_failed_message(uint32_t sn, int result,
		const char * info);
amf_value * build_player_info_message(uint32_t sn, Player * player);
amf_value * build_building_info_message(uint32_t sn, Player * player);
amf_value * build_resources_info_message(uint32_t sn, Player * player);
amf_value * build_technoloty_info_message(uint32_t sn, Player * player);
amf_value * build_hero_info_message(uint32_t sn, Player * player);
amf_value * build_idle_hero_info_message(uint32_t sn, Player * player);
amf_value * build_visit_hero_info_message(uint32_t sn, Player * player);
amf_value * build_cooldown_info_message(uint32_t sn, Player * player);
amf_value * build_battle_info_message(uint32_t sn, unsigned long long playerid);
amf_value * build_city_info_message(uint32_t sn, Player * player);
amf_value * build_world_map_message(uint32_t sn, int x, int y);
amf_value * build_farm_info_message(uint32_t sn, Player * player);
//amf_value *  build_fight_message(uint32_t sn, Fight * fight);

#endif
