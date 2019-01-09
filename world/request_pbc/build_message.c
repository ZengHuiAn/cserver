#include <assert.h>

#include "build_message.h"
#include "package.h"
#include "mtime.h"
#include "log.h"
#include "dlist.h"
#include "modules/property.h"

extern struct pbc_env * env;


struct pbc_rmessage * read_pbc_message(const char * data, size_t len, const char * type)
{
	struct pbc_slice slice;
	slice.buffer = (void*)data;
	slice.len = len;

	char msg_name[128] = {0};
	sprintf(msg_name, "com.agame.protocol.%s", type);

	return pbc_rmessage_new(env, msg_name, &slice);
}
	
struct pbc_wmessage  * build_pbc_message(uint32_t sn, int result, const char * info, const char * type)
{
	char msg_name[128] = {0};
	sprintf(msg_name, "com.agame.protocol.%s", type);

	struct pbc_wmessage * msg = pbc_wmessage_new(env, msg_name);
	if (msg == 0) {
		return 0;
	}
	if (sn != 0) {
		pbc_wmessage_integer(msg, "sn",  sn, 0);
	}

	pbc_wmessage_integer(msg, "result",   result, 0);
	if (info != 0) {
		pbc_wmessage_string (msg, "info",   info, 0);
	}
	return msg;
}

struct pbc_wmessage  * build_pbc_failed_message(uint32_t sn, int result, const char * info, const char * respond)
{
	return build_pbc_message(sn, result, info, respond);
}

struct pbc_wmessage  * build_pbc_player_info_message(uint32_t sn, Player * player)
{
	assert(player);
	// Property * property = player_get_property(player);
	struct pbc_wmessage * msg = build_pbc_message(sn, RET_SUCCESS, 0, "QueryPlayerRespond");

	pbc_wmessage_integer(msg, "playerid", player_get_id(player), 0);
	pbc_wmessage_string (msg, "name",     player_get_name(player), 0);
	return msg;
}

