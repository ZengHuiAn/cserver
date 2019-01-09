#include <assert.h>

#include "build_message.h"
#include "package.h"
#include "mtime.h"
#include "log.h"
#include "dlist.h"
#include "modules/hero.h"

amf_value  * build_message(uint32_t sn, int result,
		const char * info)
{
	// WRITE_DEBUG_LOG("build_message");
	amf_value * v = 0;
	if (info) {
		v = amf_new_array(3);
	} else {
		v = amf_new_array(2);
	}
	amf_set(v, 0, amf_new_integer(sn));
	amf_set(v, 1, amf_new_integer(result));
	if (info) {
		amf_set(v, 2, amf_new_string(info, 0));
	}
	return v;
}

amf_value  * build_failed_message(uint32_t sn, int result,
		const char * info)
{
	return build_message(sn, result, info);
}

amf_value  * build_player_info_message(uint32_t sn, Player * player)
{
	// prepare
	const unsigned long long playerid =player_get_id(player);
	Property * property = player_get_property(player);
	assert(property);

	// make value
	amf_value * v = amf_new_array(0);
	amf_push(v, amf_new_integer(sn));
	amf_push(v, amf_new_integer(RET_SUCCESS));
	amf_push(v, amf_new_double((double)playerid));
	amf_push(v, amf_new_string(player_get_name(player), 0));
	amf_push(v, amf_new_integer(property->create));
	amf_push(v, amf_new_integer(player_get_exp(player)));
	amf_push(v, amf_new_integer(player_get_level(player)));
	amf_push(v, amf_new_integer(property->head));
	amf_push(v, amf_new_integer(property->title));
	amf_push(v, amf_new_integer(property->login));
	amf_push(v, amf_new_integer(property->total_star));
	amf_push(v, amf_new_integer(property->max_floor));

	return v;
}
