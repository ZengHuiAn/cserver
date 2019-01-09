#include <assert.h>
#include <string.h>

#include "log.h"
#include "message.h"
#include "player.h"
#include "package.h"
#include "amf.h"
#include "build_message.h"

#include "logic/aL.h"

void do_login(resid_t conn, unsigned long long playerid, amf_value * v)
{
	assert(v);

	if (amf_size(v) < 1) {
		return;
	}

	uint32_t sn = amf_get_integer(amf_get(v, 0));
	// const char * name = amf_get_string(amf_get(v, 1));
	const char * account = 0;
	if (amf_size(v) >= 2) {
		account = amf_get_string(amf_get(v, 1));
	}

	const char * token = 0;
	if (amf_size(v) >= 3) {
		token = amf_get_string(amf_get(v, 2));
	}

	char buff[256] = {0};
	if (token == 0) {
		sprintf(buff, "%llu:0:error token !!!!", playerid);
		token = buff;
	}

	WRITE_INFO_LOG("player %llu login: %s", playerid, token);

	unsigned int ret = aL_login(playerid, token, account);

	amf_value * v_res = 0;
	if (ret == RET_SUCCESS) {
		// struct Player * player = player_get(playerid);
		v_res = amf_new_array(3);
		amf_set(v_res, 0, amf_new_integer(sn));
		amf_set(v_res, 1, amf_new_integer(ret));

		amf_set(v_res, 2, amf_new_double(playerid));
	} else {
		v_res = amf_new_array(2);
		amf_set(v_res, 0, amf_new_integer(sn));
		amf_set(v_res, 1, amf_new_integer(ret));
	}

	send_amf_message(conn, playerid, C_LOGIN_RESPOND, v_res);

	amf_free(v_res);
	return;
}

void do_logout(resid_t conn, unsigned long long playerid, amf_value * v)
{
	uint32_t sn = 0;
	if (amf_size(v) > 0) {
		sn = amf_get_integer(amf_get(v, 0));
	}

	unsigned int reason = 0;
	if (amf_size(v) > 1) {
		reason = amf_get_integer(amf_get(v, 1));
	}

	WRITE_INFO_LOG("player %llu logout, reason %d", playerid, reason);

	aL_logout(playerid);

	amf_value * v_res = amf_new_array(2);
	amf_set(v_res, 0, amf_new_integer(sn));
	amf_set(v_res, 1, amf_new_integer(RET_SUCCESS));
	send_amf_message(conn, playerid, C_LOGOUT_RESPOND, v_res);
	amf_free(v_res);

	return;
}
