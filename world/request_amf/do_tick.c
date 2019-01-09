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
#include "mtime.h"
#include "map.h"
#include "logic/aL.h"
#include "config/hero.h"
#include "timeline.h"

void do_tick(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 1, C_TICK_RESPOND);

	aL_tick(player);

	amf_value * res = amf_new_array(4);
	amf_set(res, 0, amf_new_integer(sn));
	amf_set(res, 1, amf_new_integer(RET_SUCCESS));
	amf_set(res, 2, amf_new_integer(agT_current()));
	amf_set(res, 3, amf_new_integer(get_open_server_time()));

	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}
