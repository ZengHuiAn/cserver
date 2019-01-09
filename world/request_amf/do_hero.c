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
#include "modules/hero.h"
#include "modules/hero_item.h"
#include "mtime.h"
#include "map.h"
#include "logic/aL.h"
#include "config/hero.h"
#include "dispatch.h"

static void response_error(resid_t conn, unsigned long long pid, int cmd, int sn){
	amf_value * res = amf_new_array(0);
	amf_push(res, amf_new_integer(sn));
	amf_push(res, amf_new_integer(RET_ERROR));
	send_amf_message(conn, pid, cmd, res);
	amf_free(res);
}

void do_query_hero(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 1, C_QUERY_HERO_RESPOND);

	unsigned long long pid = (unsigned long long)amf_get_double(amf_get(v, 1));
	if (pid == 0)
	{
		pid = playerid;
	}

	Player * query_player = player_get(pid);
	if (query_player == NULL)
	{
		response_error(conn, pid, cmd, sn);
		return;
	}

	amf_value * res = amf_new_array(0);
	amf_push(res, amf_new_integer(sn));
	amf_push(res, amf_new_integer(RET_SUCCESS));

	amf_value * hero_list = amf_new_array(0);
	struct Hero * it = NULL;
	while((it = hero_next(player, it)) != 0)
	{
		if (pid != playerid && it->placeholder == 0) {
			continue;
		}

		amf_push(hero_list, hero_build_message(it));
	}

	amf_push(res, hero_list);

	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);

#if 0
	int index = 0;
	for (; index < HERO_INTO_BATTLE_MAX; ++index)
	{
		struct Hero * p = set->fight_formation[index];
		if (p != NULL)
		{
			WRITE_DEBUG_LOG("player %llu index %d place %d hero %d", playerid, index, p->placeholder, p->gid);
		}
		else
		{
			WRITE_DEBUG_LOG("player %llu index %d nullptr", playerid, index);
		}

	}
#endif
}

void do_query_hero_item(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 1, C_QUERY_HERO_ITEM_RESPOND);

	amf_value * res = amf_new_array(3);
	amf_set(res, 0, amf_new_integer(sn));
	amf_set(res, 1, amf_new_integer(RET_SUCCESS));

	amf_value * hero_item_list = amf_new_array(0);
	struct HeroItem * it = NULL;
	while((it = hero_item_next(player, it)) != 0)
	{
		if (it->value <= 0) {
			continue;
		}

		amf_value * item = amf_new_array(4);

		amf_set(item,  0, amf_new_integer(it->uid));
		amf_set(item,  1, amf_new_integer(it->id));
		amf_set(item,  2, amf_new_integer(it->value));
		amf_set(item,  3, amf_new_integer(it->status));

		amf_push(hero_item_list, item);
	}

	amf_set(res, 2, hero_item_list);

	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}

void do_hero_item_set(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 4, C_HERO_ITEM_SET_RESPOND);

	unsigned long long uid = amf_get_integer(amf_get(v, 1));
 	unsigned id = amf_get_integer(amf_get(v, 2));
	int status = amf_get_integer(amf_get(v, 3));	

	int ret = aL_hero_item_set(player, uid, id, status);

	amf_value * res = amf_new_array(2);
	amf_set(res, 0, amf_new_integer(sn));
	amf_set(res, 1, amf_new_integer(ret));

	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}

void do_hero_get_fashion(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 3, C_GET_FASHION_RESPOND);

	unsigned long long pid = amf_get_double(amf_get(v, 1));
	unsigned long long uuid = amf_get_double(amf_get(v, 2));

	int fashion_id = 0;
	int ret =aL_hero_get_fashion_id(pid, uuid, &fashion_id);	
	amf_value * res = amf_new_array(3);
	amf_set(res, 0, amf_new_integer(sn));
	amf_set(res, 1, amf_new_integer(ret));
	amf_set(res, 2, amf_new_integer(fashion_id));

	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}

void do_gm_add_hero(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_TEST_ADD_HERO_RESPOND);
	/*
	   HeroSet * set = (HeroSet *)player_get_module(player, PLAYER_MODULE_HERO);
	   if (set == NULL)
	   {
	   response_error(conn, playerid, cmd, sn);
	   return;
	   }
	   */

	unsigned int gid = amf_get_integer(amf_get(v, 1));

	struct Hero * hero = aL_hero_add(player, gid, 1);

	amf_value * result = amf_new_array(0);
	amf_push(result, amf_new_integer(sn));
	amf_push(result, amf_new_integer(hero ? RET_SUCCESS : RET_ERROR));

	send_amf_message(conn, playerid, cmd, result);
	amf_free(result);
}

void do_hero_add_exp(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 3, C_HERO_ADD_EXP_RESPOND);
	
	unsigned int gid = amf_get_integer(amf_get(v, 1));
	int exp = amf_get_integer(amf_get(v, 2));
	int type = amf_get_integer(amf_get(v, 3));
	unsigned long long uuid = (amf_size(v) > 4) ? amf_get_double(amf_get(v, 4)) : 0;

	int r = aL_hero_add_exp(player, gid, exp, 0, type, uuid);
	amf_value * result = amf_new_array(0);
	amf_push(result, amf_new_integer(sn));
	amf_push(result, amf_new_integer(r));
	send_amf_message(conn, playerid, cmd, result);
	amf_free(result);	
}

//消耗道具给某个英雄加经验
void do_hero_add_exp_by_item(resid_t conn, unsigned long long playerid, amf_value *v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 3, C_HERO_ADD_EXP_BY_ITEM_RESPOND);
	unsigned long long uuid = amf_get_double(amf_get(v, 1));
	unsigned int cfg_id = amf_get_integer(amf_get(v, 2));

	int r = aL_hero_add_exp_by_item(player, uuid, 0, cfg_id);
	amf_value * result = amf_new_array(0);
	amf_push(result, amf_new_integer(sn));
	amf_push(result, amf_new_integer(r));
	send_amf_message(conn, playerid, cmd, result);
	amf_free(result);
}

/*
void do_hero_level_up(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 3, C_HERO_LEVEL_UP_REQUEST);

	unsigned int gid = amf_get_integer(amf_get(v, 1));
	int count = amf_get_integer(amf_get(v, 2));
	unsigned long long uuid = (amf_size(v) > 3) ? amf_get_double(amf_get(v, 3)) : 0;

	int r = aL_hero_level_up(player, gid, count, uuid);
	amf_value * result = amf_new_array(0);
	amf_push(result, amf_new_integer(sn));
	amf_push(result, amf_new_integer(r));
	send_amf_message(conn, playerid, cmd, result);
	amf_free(result);
}
*/

void do_hero_star_up(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_HERO_STAR_UP_RESPOND);
	
	unsigned int gid = amf_get_integer(amf_get(v, 1));
	int type = amf_get_integer(amf_get(v, 2));
	unsigned long long uuid = (amf_size(v) > 3) ? amf_get_double(amf_get(v, 3)) : 0;
	
	int old_star = 0;
	int r = aL_hero_star_up(player, gid, type, uuid, &old_star);
	amf_value * result = amf_new_array(0);
	amf_push(result, amf_new_integer(sn));
	amf_push(result, amf_new_integer(r));
	send_amf_message(conn, playerid, cmd, result);
	amf_free(result);	
	
	if (RET_SUCCESS == r) {
		struct Hero * hero = NULL;

		hero = hero_get(player, 0, uuid);
		if (hero != NULL) {		
			int star, id;

			if (Up_Hero == type) {
				star = hero->star;
				id = 8;
			}
			else {
				star = hero->weapon_star;
				id = 10;
			}

			if (old_star / 6 != star / 6) {	
				amf_value * v = amf_new_array(4);
				amf_push(v, amf_new_integer(id));
				amf_push(v, amf_new_string(player_get_name(player), 0));
				amf_push(v, amf_new_integer(uuid));
				amf_push(v, amf_new_integer(star));
				
				char msg[1024] = { 0 };
				int32_t size = 0;
				size = amf_encode(msg, sizeof(msg), v);
				/* 增加全服公告 */	
				broadcast_to_client(C_PLAYER_DATA_CHANGE, 1, msg, size, 0, NULL);
				amf_free(v);
			}
		}
	}
}

void do_hero_stage_up(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_HERO_STAGE_UP_RESPOND);
	
	unsigned int gid = amf_get_integer(amf_get(v, 1));
	int type = amf_get_integer(amf_get(v, 2));
	unsigned long long uuid = (amf_size(v) > 3) ? amf_get_double(amf_get(v, 3)) : 0;

	int old_stage = 0;
	int r = aL_hero_stage_up(player, gid, type, uuid, &old_stage);
	amf_value * result = amf_new_array(0);
	amf_push(result, amf_new_integer(sn));
	amf_push(result, amf_new_integer(r));
	send_amf_message(conn, playerid, cmd, result);
	amf_free(result);

	if (RET_SUCCESS == r && Up_Hero == type) {
		struct Hero * hero = NULL;

		hero = hero_get(player, 0, uuid);
		if (hero != NULL && hero->stage / 4 != old_stage / 4) {
			amf_value * v = amf_new_array(4);
			amf_push(v, amf_new_integer(9));
			amf_push(v, amf_new_string(player_get_name(player), 0));
			amf_push(v, amf_new_integer(uuid));
			amf_push(v, amf_new_integer(hero->stage));
				
			char msg[1024] = { 0 };
			int32_t size = 0;
			size = amf_encode(msg, sizeof(msg), v);
			/* 增加全服公告 */	
			broadcast_to_client(C_PLAYER_DATA_CHANGE, 1, msg, size, 0, NULL);
			amf_free(v);	
		}
	}
}

void do_hero_stage_slot_unlock(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 3, C_HERO_STAGE_SLOT_UNLOCK_RESPOND);

	unsigned int gid = amf_get_integer(amf_get(v, 1));
	int index = amf_get_integer(amf_get(v, 2));
	int type = amf_get_integer(amf_get(v, 3));
	unsigned long long uuid = (amf_size(v) > 4) ? amf_get_double(amf_get(v, 4)) : 0;

	int r = aL_hero_stage_slot_unlock(player, gid, index, type, uuid);
	amf_value * result = amf_new_array(0);
	amf_push(result, amf_new_integer(sn));
	amf_push(result, amf_new_integer(r));
	send_amf_message(conn, playerid, cmd, result);
	amf_free(result);	
}

void do_hero_update_fight_formation(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_HERO_UPDATE_FIGHT_FORMATION_RESPOND);

	amf_value * info = amf_get(v, 1);
	int size = amf_size(info);
	int index = 0;
	int r = 0;
	for (; index < size; ++index)
	{
		amf_value * sub_info = amf_get(info, index);
		unsigned int gid = amf_get_integer(amf_get(sub_info, 0));
		int place = amf_get_integer(amf_get(sub_info, 1));
		unsigned long long uuid = (amf_size(sub_info) > 2) ? amf_get_double(amf_get(sub_info, 2)) : 0;

		r = aL_hero_update_fight_formation(player, gid, place, uuid);
		if (r != 0)
		{
			break;
		}
	}

	amf_value * result = amf_new_array(0);
	amf_push(result, amf_new_integer(sn));
	amf_push(result, amf_new_integer(r));
	send_amf_message(conn, playerid, cmd, result);
	amf_free(result);
}

void do_hero_select_skill(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_HERO_SELECT_SKILL_RESPOND);

	unsigned long long uuid = amf_get_double(amf_get(v, 1));
	int group = amf_get_integer(amf_get(v, 2));

	int skills[6] = {0, 0, 0, 0};
	if (group == 0) {
		if (amf_size(v) > 3) {
			amf_value * a_skills = amf_get(v, 3);
			if (amf_size(a_skills) > 0) skills[0] = amf_get_integer(amf_get(a_skills, 0));
			if (amf_size(a_skills) > 1) skills[1] = amf_get_integer(amf_get(a_skills, 1));
			if (amf_size(a_skills) > 2) skills[2] = amf_get_integer(amf_get(a_skills, 2));
			if (amf_size(a_skills) > 3) skills[3] = amf_get_integer(amf_get(a_skills, 3));
			if (amf_size(a_skills) > 4) skills[4] = amf_get_integer(amf_get(a_skills, 4));
			if (amf_size(a_skills) > 5) skills[5] = amf_get_integer(amf_get(a_skills, 5));
		}
	}

	int ret = aL_hero_select_skill(player, uuid, group, skills[0], skills[1], skills[2], skills[3], skills[4], skills[5]);

	amf_value * result = amf_new_array(0);
	amf_push(result, amf_new_integer(sn));
	amf_push(result, amf_new_integer(ret));
	send_amf_message(conn, playerid, cmd, result);
	amf_free(result);
}
