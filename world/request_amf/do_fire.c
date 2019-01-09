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
#include "modules/fire.h"

void do_query_fire(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 1, C_QUERY_FIRE_RESPOND);

	struct Fire * fire = player_get_fire(player);
    amf_value * res = amf_new_array(0);
    amf_set(res, 0, amf_new_integer(sn));
    amf_set(res, 1, amf_new_integer(RET_SUCCESS));
    amf_push(res, amf_new_integer(fire->max));
    amf_push(res, amf_new_integer(fire->cur));
    send_amf_message(conn, playerid, cmd, res);
    amf_free(res);
}

