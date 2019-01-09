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
#include "modules/talent.h"
#include "mtime.h"
#include "map.h"
#include "config/talent.h"
#include "logic/aL.h"
#include "config/openlv.h"

static void response_result(resid_t conn, unsigned long long pid, int cmd, int sn, int result)
{
	amf_value * res = amf_new_array(0);
	amf_push(res, amf_new_integer(sn));
	amf_push(res, amf_new_integer(result));
	send_amf_message(conn, pid, cmd, res);
	amf_free(res);
}

void do_query_talent(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 1, C_QUERY_TALENT_RESPOND);

	unsigned long long pid   = (amf_size(v) > 1) ? (unsigned long long)amf_get_double(amf_get(v, 1)) : 0;
	int refid                = (amf_size(v) > 2) ? amf_get_integer(amf_get(v, 2)) : 0;
	int type                 = (amf_size(v) > 3) ? amf_get_integer(amf_get(v,3)) : 0;
	unsigned long long id    = (amf_size(v) > 4) ? (unsigned long long)amf_get_double(amf_get(v, 4)) : 0;

	pid =  pid ? pid : playerid;

	Player * query_player = player_get(pid);
	amf_value * res = amf_new_array(0);
	amf_push(res, amf_new_integer(sn));
	amf_push(res, amf_new_integer(query_player ? RET_SUCCESS : RET_NOT_EXIST));

	if (query_player) {
		if (refid != 0 || id != 0) {
			unsigned long long uuid = 0;
			int real_type = 0;
			const char * data = aL_talent_get_data(query_player, type, id, refid, &uuid, &real_type);

			amf_push(res, amf_new_integer(real_type));
			amf_push(res, amf_new_integer(refid));
			amf_push(res, amf_new_string(data ? data : "", 0));
			amf_push(res, amf_new_double(uuid));
		} else {
			amf_value * ts = amf_new_array(0);

			amf_push(res, amf_new_integer(0));
			amf_push(res, ts);

			Talent * talent = 0;
			while((talent = talent_next(query_player, talent)) != 0) {
				amf_value * t = amf_new_array(4);

				amf_set(t, 0, amf_new_integer(talent->talent_type));
				amf_set(t, 1, amf_new_integer(talent->refid));
				amf_set(t, 2, amf_new_string (talent->data, 0));
				amf_set(t, 3, amf_new_double (talent->id));

				amf_push(ts, t);
			}
		}
	}

	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}

void do_reset_talent(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_RESET_TALENT_RESPOND);
	int refid             = amf_get_integer(amf_get(v, 1));
	int type              = (amf_size(v) > 2) ? amf_get_integer(amf_get(v,2)) : 0;
	unsigned long long id = (amf_size(v) > 3) ? (unsigned long long)amf_get_double(amf_get(v, 3)) : 0;

	int result = aL_talent_reset(player, type, id, refid);

	response_result(conn, playerid, cmd, sn, result);
}

void do_update_talent(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 3, C_UPDATE_TALENT_RESPOND);
	int refid             = amf_get_integer(amf_get(v, 1));
	amf_value * data      = amf_get(v, 2);
	int type              = (amf_size(v) > 3) ? amf_get_integer(amf_get(v,3)) : 0;
	unsigned long long id = (amf_size(v) > 4) ? (unsigned long long)amf_get_double(amf_get(v, 4)) : 0;

	/* 角色称号功能开启等级测试 */
	Player *p =  player_get(playerid);
	if (NULL == p) {
		WRITE_WARNING_LOG("%s: player not exist, pid is %lld.", __FUNCTION__, playerid);
		response_result(conn, playerid, cmd, sn, RET_NOT_EXIST);
		return;
	}
	int level = player_get_level(p);
	if (type == TalentType_Hero_fight || type == TalentType_Hero_work) {
		OpenLevCofig *cfg = get_openlev_config(ROLE_TITLE);
		int open_level = cfg ? cfg->open_lev : 0;
		if (level < open_level) {
			WRITE_WARNING_LOG("%s: role title change failed, level is not enough, level is %d, open level is %d.", __FUNCTION__, level, open_level);
			response_result(conn, playerid, cmd, sn, RET_PERMISSION);	
			return;	
		}
	}

	int i, size = amf_size(data);
	char talent_data[TALENT_MAXIMUM_DATA_SIZE+1] = {0};
	for (i = 0; i < TALENT_MAXIMUM_DATA_SIZE; i++) {
		talent_data[i] = '0';
	}

	for (i = 0; i < size; i++) {
		amf_value * sub = amf_get(data, i);
		int id = amf_get_integer(amf_get(sub, 0));
		int value = amf_get_integer(amf_get(sub, 1));
		if (id < 1 || id > TALENT_MAXIMUM_DATA_SIZE) {
			response_result(conn, playerid, cmd, sn, RET_PARAM_ERROR);
			return;
		}
		talent_data[id-1] = '0' + value;
	}

	int result = aL_talent_update(player, type, id, refid, talent_data);

	response_result(conn, playerid, cmd, sn, result);
}
