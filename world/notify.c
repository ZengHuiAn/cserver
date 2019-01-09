#include <assert.h>
#include <string.h>

#include "backend.h"
#include "event_manager.h"
#include "log.h"
#include "map.h"
#include "message.h"
#include "mtime.h"
#include "network.h"
#include "notify.h"
#include "package.h"
#include "protocol.h"


typedef struct Notify {
	struct Notify * next;

	unsigned int type;
	unsigned long rkey;

	amf_value * value;
} Notify;

typedef struct PlayerNotify {
	struct PlayerNotify * next;

	unsigned long long playerid;
	//amf_value * message;
	struct map * m;
	Notify * l;
	Notify * t;
} PlayerNotify;

struct map * player_notify_hash = 0;
PlayerNotify * player_notify_list = 0;

static void _nb_init();
static void _nb_destory();
static void _nb_clean(int force);

int module_notify_load(int arg, char * argv[])
{
	_nb_init();

	player_notify_hash = _agMap_new(0); //hash_create_with_number_key(KEY_FUNC(PlayerNotify, playerid));
	return 0;
}

int module_notify_reload()
{
	return 0;
}

void module_notify_update(time_t now)
{
	notification_clean();
}

static void release_player_notify(PlayerNotify * notify)
{
	_agMap_ip_set(player_notify_hash, notify->playerid, (void*)0);

	while(notify->l) {
		Notify * n = notify->l;
		notify->l = n->next;
		free(n);
	}

	_agMap_delete(notify->m);
	free(notify);
}

void module_notify_unload()
{
	while(player_notify_list) {
		PlayerNotify * notify = player_notify_list;
		player_notify_list = notify->next;

		release_player_notify(notify);
	}
	_agMap_delete(player_notify_hash);

	_nb_destory();
}

PlayerNotify * get_player_notify(unsigned long long playerid)
{
	PlayerNotify * notify = (PlayerNotify*)_agMap_ip_get(player_notify_hash, playerid);
	if (notify == 0) {
		notify = (PlayerNotify*)malloc(sizeof(PlayerNotify));
		notify->playerid = playerid;

		notify->m = _agMap_new(0); //hash_create_with_number_key(KEY_FUNC(Notify, rkey));
		notify->l = 0;
		notify->t = 0;

		_agMap_ip_set(player_notify_hash, notify->playerid, notify);

		notify->next = player_notify_list;
		player_notify_list = notify;
	}
	return notify;
}

/*
static const char * notify_str[] = {
	"unknown",
	"NOTIFY_PROPERTY",
	"NOTIFY_RESOURCE",
	"NOTIFY_BUILDING",
	"NOTIFY_TECHNOLOGY",
	"NOTIFY_CITY",
	"NOTIFY_HERO_LIST",
	"NOTIFY_HERO",
	"NOTIFY_ITEM_COUNT",
	"NOTIFY_COOLDOWN",
	"NOTIFY_EQUIP_LIST",
	"NOTIFY_EQUIP",
	"NOTIFY_FARM",
	"NOTIFY_STRATEGY",
	"NOTIFY_STORY",
	"NOTIFY_COMPOSE",
};
*/


Notify * notification_add_r(unsigned long long playerid, unsigned int type, amf_value * value)
{
//	WRITE_DEBUG_LOG("notification_add %s", notify_str[type]);
	PlayerNotify * notify = get_player_notify(playerid);
	
	Notify * msg = (Notify*)malloc(sizeof(Notify));

	msg->type = type;
	msg->rkey  = 0;

	msg->value = value;

	//TODO:
	msg->next = 0;
	if (notify->l == 0) {
		assert(notify->t == 0);
		notify->l = notify->t = msg;
	} else {
		assert(notify->t && notify->t->next == 0);
		notify->t->next = msg;
		notify->t = msg;
	}
	return msg;
}


int notification_add(unsigned long long playerid, unsigned int type, amf_value * value)
{
	if (notification_add_r(playerid, type, value) == 0) {
		return -1;
	}
	return 0;
}

int notification_set(unsigned long long playerid, unsigned int type, unsigned int key, amf_value * value)
{
	PlayerNotify * notify = get_player_notify(playerid);

	unsigned long rkey = (((unsigned long)key) << 32) | type;

	Notify * msg = (Notify*)_agMap_ip_get(notify->m, rkey);
	if (msg) {
		if (msg->value) amf_free(msg->value);
		msg->value = value;
	} else {
		msg = notification_add_r(playerid, type, value);
		msg->rkey = rkey;
		_agMap_ip_set(notify->m, msg->rkey, msg);
	}
	return 0;
}


void broadcast_to_client(const uint32_t cmd, const uint32_t flag, const char* msg, const int32_t msg_len, const int32_t count, const unsigned long long* pids);

int notification_clean()
{
	while(player_notify_list) {
		PlayerNotify * notify = player_notify_list;
		player_notify_list = notify->next;

		_agMap_ip_set(player_notify_hash, notify->playerid, (void*)0);
		
		amf_value * msg = amf_new_array(0);
		amf_push(msg, amf_new_integer(0));
		amf_push(msg, amf_new_integer(RET_SUCCESS));

		//WRITE_DEBUG_LOG("notification_clean %u", notify->playerid);

		while(notify->l) {
			Notify * n = notify->l;
			notify->l = n->next;

			//WRITE_DEBUG_LOG("\t%s", notify_str[n->type]);

			amf_value * c = 0;
			if (n->value) {
				c = amf_new_array(2);
				amf_set(c, 0, amf_new_integer(n->type));
				amf_set(c, 1, n->value);
			} else {
				c = amf_new_array(1);
				amf_set(c, 0, amf_new_integer(n->type));
			}
			amf_push(msg, c);

			// free notify
			_agMap_ip_set(notify->m, n->rkey, (void*)0);

			free(n);
		}


		if (notify->playerid == 0) {
			size_t len = amf_get_encode_length(msg);
			char message[len];
			size_t offset = 0;
			offset += amf_encode(message + offset, sizeof(message) - offset, msg);
			broadcast_to_client(C_PLAYER_DATA_CHANGE, 1, message, offset, 0, 0);
		} else {
			send_amf_message_to(notify->playerid, C_PLAYER_DATA_CHANGE, msg);
		}
		amf_free(msg);

		_agMap_delete(notify->m);
		notify->t = 0;
		free(notify);
	}


	_nb_clean(0);

	return 0;
}

////////////////////////////////////////////////////////////////////////////////
// backend notification

#define NB_COUNT	100
#define NB_DELAY	3

#define NB_PLAYER_MIN		4       // max
#define NB_PLAYER_MAX		24		// max

// 16 充值次数
// 17 - 24 8个充值档位

struct nb_player {
	unsigned long long pid;

	time_t time;

	unsigned int value[NB_PLAYER_MAX+1];
};

static struct {
	struct map * map;

	unsigned int used;
	struct nb_player player[NB_COUNT];
} nb_list = {0, 0};;


static const char * nb_backend[] = {
	"ADSupport",
	0
};

static void _nb_init() 
{
	if (nb_list.map == 0) {
		nb_list.map  = _agMap_new(0);
		nb_list.used = 0;
		memset(nb_list.player, 0, sizeof(nb_list.player));
	}

	// 连接服务器
	int i;
	for(i = 0; nb_backend[i]; i++) {
		backend_get(nb_backend[i], 0);
	}
}

static void _nb_destory()
{
	if (nb_list.map) {
		_agMap_delete(nb_list.map);
	}
}

static struct nb_player * _nb_get(unsigned long long pid)
{
	struct nb_player * player = (struct nb_player*)_agMap_ip_get(nb_list.map, pid);
	if (player) return player;

	if (nb_list.used < NB_COUNT) {
		player = nb_list.player + (nb_list.used++);
		player->pid = pid;
		_agMap_ip_set(nb_list.map, pid, player);
	}
	return player;
}


static void _nb_clean(int force)
{
	unsigned int i = 0; 
	unsigned int used = nb_list.used;
	nb_list.used = 0;

	time_t dead_line = agT_current() - NB_DELAY;

	for (i = 0; i < used; i++) {
		struct nb_player * player = nb_list.player + i;

		if (force || (player->time <= dead_line) ) {
			_agMap_ip_set(nb_list.map, player->pid, 0);

			int i;
			for (i = NB_PLAYER_MIN; i <= NB_PLAYER_MAX; i++) {
				if (player->value[i] > 0) {
					struct pbc_wmessage * msg = protocol_new_w("NotifyADSupportEventRequest");
					pbc_wmessage_integer(msg, "pid", player->pid,   0);
					pbc_wmessage_integer(msg, "eventid", i, 0);
					pbc_wmessage_integer(msg, "value", player->value[i], 0);

					struct pbc_slice slice;
					pbc_wmessage_buffer(msg, &slice);
					int j;
					for(j = 0; nb_backend[j]; j++) {
						struct Backend * backend = backend_get(nb_backend[j], 0);
						if (backend) {
							backend_send(backend, 0, 14006, 2, slice.buffer, slice.len);
						}
					}
					pbc_wmessage_delete(msg);
				}
			}
			memset(player, 0, sizeof(struct nb_player));
		} else {
			struct nb_player * nplayer = nb_list.player + (nb_list.used ++);
			assert(nplayer <= player);
			if (nplayer != player) {
				_agMap_ip_set(nb_list.map, player->pid, nplayer);
				memcpy(nplayer, player, sizeof(struct nb_player));
				memset(player, 0, sizeof(struct nb_player));
			}
		}
	}
}

static void notification_backend(unsigned long long pid, unsigned int type, unsigned int value)
{
	if (type < NB_PLAYER_MIN || type > NB_PLAYER_MAX) {
		return;
	}

	struct nb_player * player = _nb_get(pid);
	if (player == 0) {
		_nb_clean(1);
		player = _nb_get(pid);
	}

	player->value[type] = player->value[type] + value;
	player->time = agT_current();
}

int notification_record_count(unsigned long long playerid, unsigned int event, unsigned int count)
{
	notification_backend(playerid, event, count);
	return 0;
}
