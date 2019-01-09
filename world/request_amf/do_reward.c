#include <assert.h>
#include <string.h>

#include "network.h"
#include "log.h"
#include "message.h"
#include "player.h"
#include "package.h"
#include "amf.h"
#include "mtime.h"
#include "build_message.h"
#include "modules/reward.h"
#include "modules/reward_flag.h"
#include "config/general.h"

#include "logic/aL.h"

void do_query_reward(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_PARAM(conn, playerid, v, 1, C_QUERY_REWARD_RESPOND);

	WRITE_INFO_LOG("player %llu query reward", playerid);

	amf_value * respond = amf_new_array(3);
	amf_set(respond, 0, amf_new_integer(sn));
	amf_set(respond, 1, amf_new_integer(RET_SUCCESS));
	amf_value * content = amf_new_array(0);
	amf_set(respond, 2, content);

	struct Reward * ite = 0;
	while((ite = reward_next(player, ite)) != 0) {
		amf_value * r = amf_new_array(2);
		amf_set(r, 0, amf_new_integer(ite->reason));
		amf_set(r, 1, amf_new_string(ite->name, 0));
		amf_push(content, r); 
	}

	send_amf_message(conn, playerid, cmd, respond);
	amf_free(respond);
	return;
}

void do_receive_reward(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_PARAM(conn, playerid, v, 2, C_RECEIVE_REWARD_RESPOND);

	unsigned int from = amf_get_integer(amf_get(v, 1));

	WRITE_INFO_LOG("player %llu recv reward from %u", playerid, from);

	amf_value * respond = 0;

	struct RewardContent content[10];
	memset(&content, 0, sizeof(content));
	int ret = aL_receive_reward(player, from, content, 10);

	if (ret != RET_SUCCESS) {
		respond = amf_new_array(2);
		amf_set(respond, 0, amf_new_integer(sn));
		amf_set(respond, 1, amf_new_integer(ret));
	} else {
		respond = amf_new_array(4);
		amf_set(respond, 0, amf_new_integer(sn));
		amf_set(respond, 1, amf_new_integer(ret));
		amf_set(respond, 2, amf_new_integer(from));
		amf_value * cc = amf_new_array(0);
		amf_set(respond, 3, cc);

		// append content
		int i;
		for(i = 0; i < 10; i++) {
			if (content[i].value == 0) {
				continue;
			}

			amf_value * r = amf_new_array(3);
			amf_set(r, 0, amf_new_integer(content[i].type));
			amf_set(r, 1, amf_new_integer(content[i].key));
			amf_set(r, 2, amf_new_integer(content[i].value));

			amf_push(cc, r);
		}
	}

	send_amf_message(conn, playerid, cmd, respond);
	amf_free(respond);
}

void do_gm_send_reward(resid_t conn, unsigned long long playerid, amf_value * v)
{
	if (!get_general_config()->enable_reward_from_client) {
		return;
	}

	CHECK_MIN_PARAM(conn, playerid, v, 5, C_GM_SEND_REWARD_RESPOND);
	unsigned long long pid = amf_get_double(amf_get(v, 1));
	pid = (pid == 0) ? playerid : pid;

	int r = 0;
	Player * reward_player = player_get(pid);
	if (reward_player != NULL)
	{
		int type = amf_get_integer(amf_get(v, 2));
		int id = amf_get_integer(amf_get(v, 3));
		int value = amf_get_integer(amf_get(v, 4));
		unsigned long long uuid = (amf_size(v) > 5) ? amf_get_double(amf_get(v, 5)) : 0;

		WRITE_DEBUG_LOG("player send gm reward %d, %d, %d, %llu", type, id, value, uuid);

		r = sendReward(player, uuid, "gm reward", 0, 0, RewardAndConsumeReason_GM, 1, type, id, value);
	}
	else
	{
		r = RET_NOT_EXIST;
	}

	struct amf_value * respond = amf_new_array(0);
	if (respond != NULL)
	{
		amf_push(respond, amf_new_integer(sn));
		amf_push(respond, amf_new_integer(r));
		send_amf_message(conn, playerid, cmd, respond);
		amf_free(respond);
	}
}


void do_query_one_time_reward(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_PARAM(conn, playerid, v, 1, C_QUERY_ONE_TIME_REWARD_RESPOND);

	WRITE_INFO_LOG("player %llu query reward flag", playerid);

	amf_value * respond = amf_new_array(3);
	amf_set(respond, 0, amf_new_integer(sn));
	amf_set(respond, 1, amf_new_integer(RET_SUCCESS));
	amf_value * content = amf_new_array(0);
	amf_set(respond, 2, content);

	struct RewardFlag * ite = 0;
	while((ite = reward_flag_next(player, ite)) != 0) {
		amf_value * r = amf_new_array(2);
		amf_set(r, 0, amf_new_integer(ite->id));
		if (ite->value >= AMF_INTEGER_MAX) {
			amf_set(r, 1, amf_new_double(ite->value));
		} else {
			amf_set(r, 1, amf_new_integer(ite->value));
		}
		amf_push(content, r); 
	}

	send_amf_message(conn, playerid, cmd, respond);
	amf_free(respond);
	return;
}

void do_recv_one_time_reward(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_PARAM(conn, playerid, v, 2, C_RECV_ONE_TIME_REWARD_RESPOND);

	unsigned int id = amf_get_integer(amf_get(v, 1));

	WRITE_INFO_LOG("player %llu query reward flag", playerid);

	int ret = aL_recv_one_time_reward(player, id);

	amf_value * respond = amf_new_array(3);
	amf_set(respond, 0, amf_new_integer(sn));
	amf_set(respond, 1, amf_new_integer(ret));

	send_amf_message(conn, playerid, cmd, respond);
	amf_free(respond);
	return;
}
