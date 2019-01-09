#include <assert.h>
#include <memory.h>
#include <stdlib.h>
#include <string.h>
#include "dlist.h"
#include "message.h"
#include "player.h"
#include "log.h"
#include "array.h"
#include "package.h"
#include "player_helper.h"
#include "build_message.h"
#include "config/equip.h"
#include "modules/equip.h"
#include "modules/reward.h"
#include "mtime.h"
#include "map.h"
#include "logic/aL.h"
#include "dispatch.h"

static void response_result(resid_t conn, unsigned long long pid, int cmd, int sn, int result)
{
	amf_value * res = amf_new_array(0);
	amf_push(res, amf_new_integer(sn));
	amf_push(res, amf_new_integer(result));
	send_amf_message(conn, pid, cmd, res);
	amf_free(res);
}

void do_query_equip_info(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 1, C_QUERY_EQUIP_INFO_RESPOND);

	amf_value * res = amf_new_array(0);
	amf_push(res, amf_new_integer(sn));
	amf_push(res, amf_new_integer(RET_SUCCESS));

	amf_value * equip_list = amf_new_array(0);

	struct Equip * iter = NULL;
	while ((iter = equip_next(player, iter)) != 0) {
		amf_value * item = build_equip_message(iter);

		amf_push(equip_list, item);
	}

	amf_push(res, equip_list);
	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}

void do_query_equip_info_by_uuid(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 3, C_QUERY_EQUIP_INFO_BY_UUID_RESPOND);

	unsigned long long target = amf_get_double(amf_get(v, 1));
	unsigned long long uuid = amf_get_double(amf_get(v, 2));
	
	amf_value * res = amf_new_array(0);
	amf_push(res, amf_new_integer(sn));
	amf_push(res, amf_new_integer(RET_SUCCESS));

	Player * target_player = player_get(target);
	if (target_player) {
		struct Equip * equip = equip_get(target_player, uuid);
		if (equip) {
			amf_value * item = build_equip_message(equip);
			amf_push(res, item);
		}
	}

	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}

void do_equip_level_up(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 3, C_EQUIP_LEVEL_UP_RESPOND);
		
	unsigned long long uuid = amf_get_double(amf_get(v, 1));
	int count = amf_get_integer(amf_get(v, 2));
	int exp   = amf_get_integer(amf_get(v, 3));

	int r = aL_equip_level_up(player, uuid, count, exp);
	response_result(conn, playerid, cmd, sn, r);

	struct Equip * equip = equip_get(player, uuid);
	if (equip == NULL) {
		return;
	}
	struct EquipConfig * cfg = get_equip_config(equip->gid);
	if (NULL == cfg) {
		return;
	}
	if (equip->level >= (unsigned int)cfg->max_level && IS_EQUIP_TYPE_1(cfg->type)) {
		amf_value * v = amf_new_array(4);
		amf_push(v, amf_new_integer(13));
		amf_push(v, amf_new_string(player_get_name(player), 0));
		amf_push(v, amf_new_integer(equip->gid));
		amf_push(v, amf_new_integer(equip->level));
				
		char msg[1024] = { 0 };
		int32_t size = 0;
		size = amf_encode(msg, sizeof(msg), v);
		/* 增加全服公告 */	
		broadcast_to_client(C_PLAYER_DATA_CHANGE, 1, msg, size, 0, NULL);
		amf_free(v);
	}
}

void do_equip_stage_up(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_EQUIP_STAGE_UP_RESPOND);

	unsigned long long uuid = amf_get_double(amf_get(v, 1));

	int r = aL_equip_stage_up(player, uuid);

/*
	amf_value * info = amf_get(v, 2);

	int r = 0;
	int count = amf_size(info);

	if (count > 0) {
		int index = 0;
		for (; index < count; ++index) {
			// amf_value * sub = amf_get(info, index);
			// unsigned long long src  = amf_get_double(amf_get(sub, 0));
			// int inherit             = amf_get_integer(amf_get(sub, 1));
			// int flag                = amf_get_integer(amf_get(sub, 2));
			r = aL_equip_stage_up(player, uuid);
			if (r != RET_SUCCESS) {
				break;
			}
		}
	} else {
		r = aL_equip_stage_up(player, uuid, 0);
	}
*/

	response_result(conn, playerid, cmd, sn, r);
}

void do_equip_update_fight_formation(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_EQUIP_UPDATE_FIGHT_FORMATION_RESPOND);

	unsigned long long uuid = amf_get_double(amf_get(v, 1));

	int heroid = 0;
	int place  = 0;	

	if (amf_size(v) > 3) {
		heroid = amf_get_integer(amf_get(v, 2));
		place = amf_get_integer(amf_get(v, 3));
	}

	unsigned long long hero_uuid = 0;
	if (amf_size(v) > 4) {
		hero_uuid = amf_get_double(amf_get(v, 4));	
	}
	
	int r = aL_equip_update_fight_formation(player, uuid, heroid, place, hero_uuid);
	response_result(conn, playerid, cmd, sn, r);
}

void do_equip_eat(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_EQUIP_EAT_RESPOND);

	unsigned long long uuid = amf_get_double(amf_get(v, 1));
	int count = 1;
	if (amf_size(v) > 2) {
		count = amf_get_integer(amf_get(v,2));
	}

	int r = aL_equip_affix_grow(player, uuid, count);
/*

	amf_value * info = amf_get(v, 2);

	int r = 0;
	int count = amf_size(info);
	int index = 0;
	for (; index < count; ++index) {
		amf_value * sub = amf_get(info, index);
		unsigned long long src  = amf_get_double(amf_get(sub, 0));
		// int flag = amf_get_integer(amf_get(sub, 1));
		r = aL_equip_eat(player, uuid, src);
		if (r != RET_SUCCESS) {
			break;
		}
	}
*/
	response_result(conn, playerid, cmd, sn, r);
}

void do_equip_replace_property(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 4, C_EQUIP_REPLACE_PROPERTY_RESPOND);

	unsigned long long uuid = amf_get_double(amf_get(v, 1));
	int index = amf_get_integer(amf_get(v, 2));
	int property_item_id = amf_get_integer(amf_get(v,3));

	int ret = aL_equip_replace_property(player, uuid, index, property_item_id);

	response_result(conn, playerid, cmd, sn, ret);
}

void do_equip_refresh_property(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 4, C_EQUIP_REFRESH_PROERPTY_RESPOND);

	unsigned long long uuid = amf_get_double(amf_get(v, 1));
	int index   = amf_get_integer(amf_get(v, 2));
	int confirm = amf_get_integer(amf_get(v,3));

	int id = 0, value = 0;
	int ret = aL_equip_refresh_property(player, uuid, index, confirm, &id, &value);
	if (ret != RET_SUCCESS) {
		response_result(conn, playerid, cmd, sn, ret);
	} else {
		amf_value * res = amf_new_array(4);
		amf_set(res, 0, amf_new_integer(sn));
		amf_set(res, 1, amf_new_integer(RET_SUCCESS));
		amf_set(res, 2, amf_new_integer(id));
		amf_set(res, 3, amf_new_integer(value));
		send_amf_message(conn, playerid, cmd, res);
		amf_free(res);
	}
}

void do_equip_affix_grow(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_EQUIP_AFFIX_GROW_RESPOND);

	unsigned long long uuid = amf_get_double(amf_get(v, 1));
	int count = amf_get_integer(amf_get(v, 2));

	int ret = aL_equip_affix_grow(player, uuid, count);

	response_result(conn, playerid, cmd, sn, ret);
}



void do_equip_decompose(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_EQUIP_DECOMPOSE_RESPOND);

	unsigned long long uuid = amf_get_double(amf_get(v, 1));

	struct RewardItem items[32];
	memset(items, 0, sizeof(items));

	int ret = aL_equip_decompose(player, uuid, items, 32);

	if (ret != RET_SUCCESS) {
		response_result(conn, playerid, cmd, sn, ret);
	} else {
		amf_value * res = amf_new_array(3);
		amf_set(res, 0, amf_new_integer(sn));
		amf_set(res, 1, amf_new_integer(RET_SUCCESS));

		amf_value * ss = amf_new_array(4);
		amf_set(res, 2, ss);

		int i;
		for (i = 0; i < 32; i++) {
			if (items[i].type == 0) {
				break;
			}

			amf_value * s = amf_new_array(3);
			amf_set(s, 0, amf_new_integer(items[i].type));
			amf_set(s, 1, amf_new_integer(items[i].id));
			amf_set(s, 2, amf_new_integer(items[i].value));
			amf_push(ss, s);
		}

		send_amf_message(conn, playerid, cmd, res);
		amf_free(res);
	}
}

//test
/*void do_equip_sell_to_system(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_EQUIP_SELL_TO_SYSTEM_RESPOND);

	unsigned long long uuid = amf_get_double(amf_get(v, 1));
	int ret = aL_equip_sell_to_system(player, uuid, 0, 0, 0);

	response_result(conn, playerid, cmd, sn, ret);
}

void do_equip_buy_from_system(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_EQUIP_BUY_FROM_SYSTEM_RESPOND);

	unsigned long long uuid = amf_get_double(amf_get(v, 1));
	int ret = aL_equip_buy_from_system(player, uuid, 0, 0, 0);

	response_result(conn, playerid, cmd, sn, ret);

}*/
