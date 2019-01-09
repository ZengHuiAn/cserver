#include <assert.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <libgen.h>

#include "addicted.h"
#include "config/addicted.h"
#include "config.h"
#include "dlist.h"
#include "log.h"
#include "map.h"
#include "memory.h"
#include "mtime.h"
#include "network.h"
#include "notify.h"
#include "package.h"
#include "player.h"
#include "timer.h"

struct PlayerAddictedInfo {
	struct {
		struct PlayerAddictedInfo * prev;
		struct PlayerAddictedInfo * next;
	} kick;

	struct {
		struct PlayerAddictedInfo * prev;
		struct PlayerAddictedInfo * next;
	} notify;

	unsigned long long pid;
/*

	time_t played;
	time_t login;
	time_t logout;
*/
	struct Timer * timer;
	// struct Timer * notifyTimer;
	int sended;
};

#define PLAYED(info, now) (info->played + now - info->login)

static struct map * players = 0;
static struct map * force_young_player = 0;


struct PlayerAddictedInfo adultPlayer;

static int _parse_adult(struct slice * fields, void * ctx){
	unsigned long long pid = atoll((const char*)fields[0].ptr);
	//TRANSFORM_PLAYERID_TO_64(pid, AG_SERVER_ID, atoll(fields[0].ptr));

	_agMap_ip_set(force_young_player, pid, (void*)1);
	return 0;
}
int module_addicted_load(int argc, char * argv[]) 
{
	if (load_addicted_config() != 0) {
		return -1;
	}

	players     = _agMap_new(0);
	force_young_player = _agMap_new(0);

	// load adult
	return database_query(role_db, _parse_adult, 0, "select `pid` from `adult_player`");
}

static void _free_player(void * p)
{
	// struct PlayerAddictedInfo * info = (struct PlayerAddictedInfo*)p;
	if (p && p != &adultPlayer) {
		FREE(p);
	}
}

int module_addicted_reload()
{
	if (load_addicted_config() != 0) {
		return -1;
	}
	// TODO: update all timer
	return 0;
}

void module_addicted_update(time_t now)
{
}

void module_addicted_unload()
{
	_agMap_empty(players, _free_player);
	_agMap_delete(players);
	players = 0;

	_agMap_delete(force_young_player);
	force_young_player = 0;
}


void kickPlayer(unsigned long long playerid, unsigned int reason);

static void checkPlayer(time_t now, void * data)
{
	AddictedConfig * cfg = get_addicted_config();

	struct PlayerAddictedInfo * info = (struct PlayerAddictedInfo *)data;

	WRITE_DEBUG_LOG("addicted checkPlayer %llu, %d", info->pid, info->sended);

	struct Player * player = player_get_online(info->pid);
	// assert(player);
	if (player == 0) {
		WRITE_DEBUG_LOG(" addicted not online");
		// player not exist
		_agMap_ip_set(players, info->pid, 0);
		FREE(info);
		return;
	}
	struct Property * property = player_get_property(player);

	info->timer = 0;
	time_t played = PLAYED(property, now);

	if (played >= cfg->kickTime + 3) {
		WRITE_DEBUG_LOG("kick player %llu by addicted", info->pid);

		if (property->login > 0) {
			kickPlayer(info->pid, LOGOUT_ADDICTED);
		}
	} else {
		int type = 0;
		if (played >= cfg->kickTime) {
			type = 2;
		} else if (played % cfg->notifyTime == 0) {
			type = 1;
		}


		int dosend = 1;
		if (type == 0 && info->sended == 0 && (now - property->login) < 60) {
			dosend = 0;
		} 

		WRITE_DEBUG_LOG(" addicted send message type %d dosend %d", type, dosend);

		if (dosend) {
			amf_value * v = amf_new_array(2);
			amf_set(v, 0, amf_new_integer(type));
			amf_set(v, 1, amf_new_integer(played));
			notification_set(info->pid, NOTIFY_ADDICTED_CHANGE, 0, v);

			info->sended ++;

			WRITE_DEBUG_LOG("NOTIFY_ADDICTED_CHANGE %llu, %u, %lu", info->pid, type, played);
		}

		// set next check
		int secKick   = cfg->kickTime - played + 5;
		int secNotify = cfg->notifyTime - (played % cfg->notifyTime);
		if (info->sended == 0) {
			int t = 60 - (now - property->login);
			secNotify = ( (t<secNotify) ? t : secNotify );
		}

		int step = (secKick > secNotify) ? secNotify : secKick;
		if (step >= timer_max_sec()) {
			step = timer_max_sec();
		}
		WRITE_DEBUG_LOG("addicted add timer on %d", step);
		info->timer = timer_add(now + step, checkPlayer, info);
	}
}

void addicted_notify(Player * player)
{
	unsigned long long pid = player_get_id(player);
	struct PlayerAddictedInfo * info = (struct PlayerAddictedInfo*)_agMap_ip_get(players, pid);
	if (info == &adultPlayer || info == 0 || info->sended > 0) {
		return;
	}

	time_t now = agT_current();

	struct Property * property = player_get_property(player);
	time_t played = PLAYED(property, now);

	amf_value * v = amf_new_array(2);
	amf_set(v, 0, amf_new_integer(0));
	amf_set(v, 1, amf_new_integer(played / 3600));
	notification_set(info->pid, NOTIFY_ADDICTED_CHANGE, 0, v);

	info->sended ++;

	WRITE_DEBUG_LOG("NOTIFY_ADDICTED_CHANGE %llu, %u, %lu", info->pid, 0, played);
}

void addicted_login(unsigned long long id)
{
	AddictedConfig * cfg = get_addicted_config();
	if (!cfg->enable) {
		return;
	}

	if (players == 0) {
		WRITE_WARNING_LOG("addicted_login: players ptr is NULL");
		return;
	}

	struct PlayerAddictedInfo * info = (struct PlayerAddictedInfo*)_agMap_ip_get(players, id);
	if (info == &adultPlayer) {
		return;
	}

	if (info == 0) { 
		info = MALLOC_N(struct PlayerAddictedInfo, 1);
		memset(info, 0, sizeof(struct PlayerAddictedInfo));
		dlist_init_with(info, kick);
		dlist_init_with(info, notify);

		info->pid    = id;
		info->timer  = 0;
		info->sended = 0;

		_agMap_ip_set(players, id, info);
		WRITE_DEBUG_LOG("addicted_login start check player %llu", id);

		// 延迟检查
		info->timer = timer_add(agT_current() + 5, checkPlayer, info);
	}
}

int addicted_can_login(unsigned long long id)
{
	AddictedConfig * cfg = get_addicted_config();
	if (!cfg->enable) {
		return 1;
	}

	if (players == 0) {
		WRITE_WARNING_LOG("addicted_can_login: players ptr is NULL");
		return 1;
	}

	struct PlayerAddictedInfo * info = (struct PlayerAddictedInfo*)_agMap_ip_get(players, id);
	if (info == &adultPlayer) {
		return 1;
	}

	struct Player * player = player_get(id);
	if (player == 0) {
		return 1;
	}
	struct Property * property = player_get_property(player);

	// reset
	unsigned int rest = agT_current() - property->logout;
	if (property->played != 0 && rest >= cfg->restTime) {
		WRITE_DEBUG_LOG("player %llu addicted reset %d/%u", id, rest, cfg->restTime);
		// property->played = 0;
		DATA_Property_update_played(property, 0);
	}

	if (property->played >= cfg->kickTime) {
		WRITE_DEBUG_LOG("player %llu addicted check failed %u, %d", id, property->played, rest);
		return 0;
	}
	return 1;
}

void addicted_logout(unsigned long long id)
{
	AddictedConfig * cfg = get_addicted_config();
	if (!cfg->enable) {
		return;
	}

	if (players == 0) {
		WRITE_WARNING_LOG("addicted_can_login: players ptr is NULL");
		return;
	}

	struct PlayerAddictedInfo * info = (struct PlayerAddictedInfo*)_agMap_ip_get(players, id);
	if (info == 0 || info == &adultPlayer) {
		WRITE_DEBUG_LOG("addicted_logout player %llu not exist", id);
		return;
	}


	WRITE_DEBUG_LOG("addicted_logout remove player %llu", id);

	if (info->timer) timer_remove(info->timer);
	_agMap_ip_set(players, id, 0);

	unsigned long long pid = info->pid;

	FREE(info);

	struct Player * player = player_get_online(pid);
	if (player == 0) {
		return;
	}
	struct Property * property = player_get_property(player);
	assert(property);

	if (property->login > property->logout) {
		int played = agT_current() - property->login;
		// property->login = 0;

		// 短时间登出的不计时
		// if (played > 10) {
			DATA_Property_update_played(property, property->played + played);
			// info->logout = agT_current();
		// }
	}
}

int addicted_is_young_player(unsigned long long id)
{
	return (long)_agMap_ip_get(force_young_player, id);
}


void addicted_set_adult(unsigned long long id)
{
	struct PlayerAddictedInfo * info = (struct PlayerAddictedInfo*)_agMap_ip_get(players, id);
	if (info == &adultPlayer) {
		WRITE_DEBUG_LOG("addicted_set_adult player %llu %s", id,
				info ? "already adult":"not checking");
		return;
	}


	WRITE_DEBUG_LOG("addicted_set_adult player %llu", id);
	_agMap_ip_set(players, id, &adultPlayer);

	if (info) {
		if (info->timer) timer_remove(info->timer);
		FREE(info);
	}
}


void addicted_set_minority(unsigned long long id)
{
	struct PlayerAddictedInfo * info = (struct PlayerAddictedInfo*)_agMap_ip_get(players, id);
	if (info && info != &adultPlayer) {

		WRITE_DEBUG_LOG("addicted_set_minority player %llu already checking", id)
		return;
	}

	WRITE_DEBUG_LOG("addicted_set_minority start watching player %llu", id);

	_agMap_ip_set(players, id, 0);
	addicted_login(id);
}
