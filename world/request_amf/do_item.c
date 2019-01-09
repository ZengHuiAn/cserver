#include <assert.h>
#include <string.h>

#include "message.h"
#include "player.h"
#include "log.h"
#include "package.h"
#include "mtime.h"
#include "player_helper.h"
#include "build_message.h"
#include "modules/item.h"
#include "logic/aL.h"

void do_query_item(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 1, C_QUERY_ITEM_RESPOND);

	WRITE_INFO_LOG("query item %llu", playerid);

	amf_value * res = amf_new_array(0);
	amf_push(res, amf_new_integer(sn));
	amf_push(res, amf_new_integer(RET_SUCCESS));

	Item * ite = 0;
	while ((ite = item_next(player, ite)) != 0) {
		/*if (ite->id == 410016 || ite->id == 410015) {
			continue;
		}*/

		if (ite->limit > 0) {
			amf_value * c = amf_new_array(3);

			amf_set(c, 0, amf_new_integer(ite->id));
			amf_set(c, 1, amf_new_integer (ite->limit));
			amf_set(c, 2, amf_new_integer(ite->pos));
		
			amf_push(res, c);
		}
	}

	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}

