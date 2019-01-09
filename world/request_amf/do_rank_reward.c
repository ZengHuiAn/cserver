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
#include "rankreward.h"
#include "mtime.h"
#include "map.h"
#include "logic/aL.h"
#include "modules/hero.h"

void do_query_rank(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_QUERY_RANK_RESPOND);
	int rank_type = amf_get_integer(amf_get(v, 1));
	int32_t open_flag = get_flag_of_rank();
	uint32_t first_begin_time = get_first_begin_time();

    amf_value * res = amf_new_array(5);
    amf_set(res, 0, amf_new_integer(sn));
    amf_set(res, 1, amf_new_integer(RET_SUCCESS));
    amf_set(res, 2, amf_new_integer(open_flag));
    amf_set(res, 3, amf_new_integer(first_begin_time));
    amf_set(res, 4, amf_new_integer(RANK_PERIOD));
    int i;
    amf_value * rank = amf_new_array(RANK_COUNT);
	if (rank_type == RANK_TYPE_EXP) {
		for(i = 0; i < RANK_COUNT; i++) {
			unsigned int value = 0;
			unsigned long long id = rank_exp_get(i+1, &value);
			amf_value * tmp = amf_new_array(2);
			amf_set(tmp, 0, amf_new_double(id));
			unsigned int level = transfrom_exp_to_level(value, 1, LEADING_ROLE);
			amf_set(tmp, 1, amf_new_integer(level));
			amf_set(rank, i, tmp);
		}
	} else if (rank_type == RANK_TYPE_STAR) {
		for(i = 0;i < RANK_COUNT; i++) {
			unsigned int value = 0;
			unsigned long long id = rank_star_get(i+1, &value);
			amf_value * tmp = amf_new_array(2);
			amf_set(tmp, 0, amf_new_double(id));
			amf_set(tmp, 1, amf_new_integer(value));
			amf_set(rank,i,tmp);
		}
	} else if (rank_type == RANK_TYPE_TOWER) {
		for(i = 0;i < RANK_COUNT; i++) {
			unsigned int value = 0;
			unsigned long long id = rank_tower_get(i+1, &value);
			WRITE_DEBUG_LOG(">>>>>>>>>>>>>>   rank %d  pid %llu value %d", i+1, id, value);
			amf_value * tmp = amf_new_array(2);
			amf_set(tmp, 0, amf_new_double(id));
			amf_set(tmp, 1, amf_new_integer(value));
			amf_set(rank,i,tmp);
		}
	}

    amf_push(res,rank);
    send_amf_message(conn, playerid, cmd, res);
    amf_free(res);
}

