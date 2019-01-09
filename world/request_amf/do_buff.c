#include <assert.h>
#include <string.h>

#include "message.h"
#include "player.h"
#include "log.h"
#include "package.h"
#include "mtime.h"
#include "player_helper.h"
#include "build_message.h"
#include "modules/buff.h"
#include "logic/aL.h"

void do_query_buff(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 1, C_QUERY_BUFF_RESPOND);

	WRITE_INFO_LOG("query buff %llu", playerid);

	amf_value * res = amf_new_array(3);
	amf_set(res, 0, amf_new_integer(sn));
	amf_set(res, 1, amf_new_integer(RET_SUCCESS));
	amf_value * buff_list = amf_new_array(0);
	amf_set(res, 2, buff_list);

	Buff * ite = 0;
	while ((ite = buff_next(player, ite)) != 0) {
		amf_value * c = amf_new_array(3);
		amf_set(c,  0, amf_new_integer(ite->buff_id));
		amf_set(c,  1, amf_new_integer(ite->value));
		amf_set(c,  2, amf_new_integer(ite->end_time));
		amf_push(buff_list, c);
	}

	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}
