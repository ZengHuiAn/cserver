#include <assert.h>
#include <string.h>

#include "message.h"
#include "player.h"
#include "log.h"
#include "package.h"
#include "mtime.h"
#include "player_helper.h"
#include "build_message.h"
#include "config/title.h"
#include "logic/title.h"

void do_query_title(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 1, C_QUERY_PLAYER_TITLE_RESPOND);

	WRITE_INFO_LOG("query title %llu", playerid);

	amf_value * res = amf_new_array(0);
	amf_push(res, amf_new_integer(sn));
	amf_push(res, amf_new_integer(RET_SUCCESS));
	amf_value * t = amf_new_array(0);

	TitleConfig * ite = 0;
	while ((ite = title_config_next(ite)) != 0) {
		/*if (ite->id == 410016 || ite->id == 410015) {
			continue;
		}*/

		if (ite->id > 0) {
			amf_value * c = amf_new_array(2);

			amf_set(c, 0, amf_new_integer(ite->id));
			int stat = check_player_title(player, ite->id);
			amf_set(c, 1, amf_new_integer(stat));	
			amf_push(t, c);
		}
	}

	amf_push(res, t);

	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}

void do_query_title_by_id(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_QUERY_ITEM_RESPOND);

	int id = amf_get_integer(amf_get(v, 1));
	WRITE_INFO_LOG("query title %llu id %d", playerid, id);

	amf_value * res = amf_new_array(0);
	amf_push(res, amf_new_integer(sn));

	TitleConfig * cfg = get_title_config(id);

	if (cfg) {
		int stat = check_player_title(player, id);
		amf_push(res, amf_new_integer(RET_SUCCESS));
		amf_push(res, amf_new_integer(stat));	
	} 
	else
	{
		amf_push(res, amf_new_integer(RET_ERROR));
	}

	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}

