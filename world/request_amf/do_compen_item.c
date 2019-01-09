#include "message.h"
#include "player.h"
#include "log.h"
#include "package.h"
#include "mtime.h"
#include "player_helper.h"
#include "build_message.h"
#include "modules/item.h"
#include "logic/aL.h"
#include "modules/reward.h"

void do_query_compen_item(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 1, C_QUERY_COMPEN_ITEM_RESPOND);
	
	amf_value * res = amf_new_array(0);
	amf_push(res, amf_new_integer(sn));
	amf_push(res, amf_new_integer(RET_SUCCESS));
	
	compensate_all_item(player);

	Compensate *cur = NULL;
	while ((cur = compen_item_next(player, cur)) != NULL) {
		amf_value *arr = amf_get(res, 2);
		if (NULL == arr) {
			arr = amf_new_array(0);
			amf_push(res, arr);
		}

		amf_value * c = amf_new_array(3);
		amf_set(c, 0, amf_new_integer(cur->time));
		amf_set(c, 1, amf_new_integer(cur->drop_id));
		amf_set(c, 2, amf_new_integer(cur->count));
		amf_push(arr, c);	
	}	

	send_amf_message(conn, playerid, cmd, res);
	amf_free(res);
}

void do_draw_compen_item(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_MIN_PARAM(conn, playerid, v, 2, C_DRAW_COMPEN_ITEM_RESPOND);

	time_t time = amf_get_integer(amf_get(v, 1)); 	
	struct RewardItem items[200];
	int ret, i;

	memset(items, 0, sizeof(items));
	ret = aL_draw_compen_item(player, time, items, 200);

	amf_value * res = amf_new_array(0);
	amf_push(res, amf_new_integer(sn));
	amf_push(res, amf_new_integer(ret));

	amf_value *arr = amf_new_array(0);
	for (i = 0; i < 200; i++) {
		if (items[i].type > 0 && items[i].id > 0 && items[i].value > 0) {
			amf_value *a = amf_new_array(0);
			amf_push(a, amf_new_integer(items[i].type));
			amf_push(a, amf_new_integer(items[i].id));
			amf_push(a, amf_new_integer(items[i].value));
			amf_push(arr, a);
		}
		else {
			break;
		}
	}
	amf_push(res, arr);
	
	send_amf_message(conn, playerid, cmd, res);

	amf_free(res);
}
