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
#include "config/quest.h"
#include "modules/quest.h"
#include "mtime.h"
#include "map.h"
#include "logic/aL.h"
#include "config/general.h"

/*
#define C_QUERY_QUEST_REQUEST 76 // 查询任务
#define C_QUERY_QUEST_RESPOND 77 

#define C_SET_QUEST_STATUS_REQUEST 78 // 完成、放弃任务
#define C_SET_QUEST_STATUS_RESPOND 79 
*/

void do_quest_query_info(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 1, C_QUERY_QUEST_RESPOND);

	int include_finished_and_canceled = 0;
	if (amf_size(v) > 1) {
		include_finished_and_canceled = amf_get_integer(amf_get(v,1));
	}

	int type = 0;
	if (amf_size(v) > 2) {
		type = amf_get_integer(amf_get(v,2));
	}

	amf_value * res = amf_new_array(3);
	amf_set(res, 0, amf_new_integer(sn));
	amf_set(res, 1, amf_new_integer(RET_SUCCESS));
	amf_value * quest_list = amf_new_array(0);
	amf_set(res, 2, quest_list);

	struct Quest * iter = NULL;
	while ((iter = quest_next(player, iter)) != 0) {
		aL_update_quest_status(iter, 0);

		if (!include_finished_and_canceled && iter->status != QUEST_STATUS_INIT) {
			continue;
		}

		if (type != 0) {
			struct QuestConfig * cfg = get_quest_config(iter->id);
			if (cfg == 0 || cfg->type != type) {
				continue;	
			}
		}

		amf_push(quest_list, quest_encode_amf(iter));
	}

	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}

void do_quest_set_status(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 3, C_SET_QUEST_STATUS_RESPOND);

	int id = amf_get_integer(amf_get(v, 1));
	int status = amf_get_integer(amf_get(v, 2));

	int result = RET_ERROR;
	if (status == QUEST_STATUS_INIT) {
		result = aL_quest_accept(player, id, 1);
	} else if (status == QUEST_STATUS_FINISH) {
		int next_quest_id = amf_get_integer(amf_get(v,3));
		result = aL_quest_submit(player, id, 0, 1, next_quest_id);
	} else if (status == QUEST_STATUS_CANCEL) {
		result = aL_quest_cancel(player, id, 1);
	}

	amf_value * res = amf_new_array(2);
	amf_set(res, 0, amf_new_integer(sn));
	amf_set(res, 1, amf_new_integer(result));
	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}

void do_quest_gm_force_set_status(resid_t conn, unsigned long long playerid, amf_value * v)
{
	if (!get_general_config()->enable_reward_from_client) {
		return;
	}

	CHECK_MIN_PARAM(conn, playerid, v, 2, C_QUEST_GM_FORCE_SET_STATUS_RESPOND);
	int quest_id = amf_get_integer(amf_get(v, 1));

	int result = RET_ERROR;
	result = aL_quest_gm_force_submit(player, quest_id);

	amf_value * res = amf_new_array(2);
	amf_set(res, 0, amf_new_integer(sn));
	amf_set(res, 1, amf_new_integer(result));
	send_amf_message(conn, playerid, cmd, res);
}

void do_quest_on_event(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 4, C_QUEST_ON_EVENT_RESPOND);

	int type = amf_get_integer(amf_get(v, 1));
	int id = amf_get_integer(amf_get(v, 2));
	int count = amf_get_integer(amf_get(v, 3));

	int result = RET_ERROR;
	if (event_can_trigger_by_client(type, id)) {
		result = aL_quest_on_event(player, type, id, count);
	}

	amf_value * res = amf_new_array(2);
	amf_set(res, 0, amf_new_integer(sn));
	amf_set(res, 1, amf_new_integer(result));
	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}
