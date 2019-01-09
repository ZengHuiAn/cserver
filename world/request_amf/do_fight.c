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
#include "mtime.h"
#include "map.h"
#include "modules/fight.h"
#include "logic/aL.h"
#include "build_message.h"
#include "config/fight.h"
#include "modules/reward.h"

static void response_result(resid_t conn, unsigned long long pid, int cmd, int sn, int result){
        amf_value * res = amf_new_array(0);
        amf_push(res, amf_new_integer(sn));
        amf_push(res, amf_new_integer(result));
        send_amf_message(conn, pid, cmd, res);
        amf_free(res);
}

void do_pve_query_fight(resid_t conn, unsigned long long playerid, amf_value * v)
{
        CHECK_PARAM(conn, playerid, v, 1, C_QUERY_FIGHT_RESPOND);

        amf_value * res = amf_new_array(0);
        amf_push(res, amf_new_integer(sn));

        amf_push(res, amf_new_integer(RET_SUCCESS));

        amf_value * fight_list = amf_new_array(0);

        struct Fight * iter = NULL;
        while ((iter = fight_next(player, iter)) != NULL)
        {
                amf_value * fight = amf_new_array(0);
                amf_push(fight, amf_new_integer(iter->gid));
                amf_push(fight, amf_new_integer(iter->flag));
                amf_push(fight, amf_new_integer(iter->today_count));
                amf_push(fight, amf_new_integer(iter->update_time));
                amf_push(fight, amf_new_integer(iter->star));
                amf_push(fight_list, fight);
        }

        amf_push(res, fight_list);

        send_amf_message(conn, playerid, cmd, res);
        amf_free(res);
}

void do_pve_fight_prepare(resid_t conn, unsigned long long playerid, amf_value * v)
{
        CHECK_PARAM(conn, playerid, v, 4, C_FIGHT_PREPARE_RESPOND);

        int fight_id = amf_get_integer(amf_get(v, 1));
        int auto_fight = amf_get_integer(amf_get(v, 2));
        int yjdq = amf_get_integer(amf_get(v, 3));

        char buf[SGK_FIGHT_BUFFER_MAX_SIZE] = {0};
        int r = aL_pve_fight_prepare(player, fight_id, auto_fight, yjdq, buf);
        response_result(conn, playerid, cmd, sn, r);
}

void do_pve_fight_check(resid_t conn, unsigned long long playerid, amf_value * v)
{
        CHECK_MIN_PARAM(conn, playerid, v, 4, C_FIGHT_CHECK_RESPOND);

        int gid = amf_get_integer(amf_get(v, 1));
        const char * buf = amf_get_string(amf_get(v, 2));
        if (buf == NULL)
        {
                response_result(conn, playerid, cmd, sn, RET_ERROR);
                return;
        }

        int star = amf_get_integer(amf_get(v, 3));

		unsigned long long heros [5] = {0};
		if (amf_size(v) > 4) {
			amf_value * a_heros = amf_get(v,4);
			if (amf_type(a_heros) == amf_array) {
				for (size_t i = 0; i < amf_size(a_heros) && i < 5; i++) {
					heros[i] = amf_get_integer(amf_get(a_heros,i));	
				}
			}
		}


		struct RewardItem items[20];
		memset(items, 0, sizeof(items));
		int r = aL_pve_fight_confirm(player, gid, star, heros, 5, items, 20);

		amf_value * res = amf_new_array(3);
		amf_set(res, 0, amf_new_integer(sn));
		amf_set(res, 1, amf_new_integer(r));

		amf_value * reward_list = amf_new_array(0);
		amf_set(res, 2, reward_list);

		for (int i = 0; i < 20; i++) {
			if (items[i].type == 0) {
				continue;
			}

			amf_value * rr = amf_new_array(3);
			amf_set(rr, 0, amf_new_integer(items[i].type));
			amf_set(rr, 1, amf_new_integer(items[i].id));
			amf_set(rr, 2, amf_new_integer(items[i].value));
			amf_push(reward_list, rr);
		}


		send_amf_message(conn, playerid, cmd, res);
		amf_free(res);
}

void do_pve_fight_fast_pass(resid_t conn, unsigned long long playerid, amf_value * v)
{
        CHECK_MIN_PARAM(conn, playerid, v, 2, C_PVE_FIGHT_FAST_PASS_RESPOND);

        int id = amf_get_integer(amf_get(v, 1));
		int count = 1;
		if (amf_size(v) > 2) {
			count = amf_get_integer(amf_get(v, 2));
		}
	
		struct RewardItem items[32];
		memset(items, 0, sizeof(items));
		int ret = aL_pve_fight_fast_pass(player, id, count, items, 32);

		amf_value * res = amf_new_array(3);
		amf_set(res, 0, amf_new_integer(sn));
		amf_set(res, 1, amf_new_integer(ret));

		amf_value * reward_list = amf_new_array(0);
		amf_set(res, 2, reward_list);

		for (int i = 0; i < 20; i++) {
			if (items[i].type == 0) {
				continue;
			}

			amf_value * rr = amf_new_array(3);
			amf_set(rr, 0, amf_new_integer(items[i].type));
			amf_set(rr, 1, amf_new_integer(items[i].id));
			amf_set(rr, 2, amf_new_integer(items[i].value));
			amf_push(reward_list, rr);
		}


		send_amf_message(conn, playerid, cmd, res);
		amf_free(res);
}

void do_fight_count_reset(resid_t conn, unsigned long long playerid, amf_value *v)
{	
        CHECK_MIN_PARAM(conn, playerid, v, 2, C_FIGHT_COUNT_RESET_RESPOND);

        int fight_id = amf_get_integer(amf_get(v, 1));
        int battle_id = amf_get_integer(amf_get(v, 2));
        int chapter_id = amf_get_integer(amf_get(v, 3));

		int r = aL_pve_fight_reset_count(player, fight_id, battle_id, chapter_id);

        response_result(conn, playerid, cmd, sn, r);
}
