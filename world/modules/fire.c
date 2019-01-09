#include <assert.h>
#include <string.h>
#include "property.h"
#include "hero.h"
#include "data/Hero.h"
#include "database.h"
#include "log.h"
#include "package.h"
#include "notify.h"
#include "mtime.h"
#include "map.h"
#include "stringCache.h"
#include "event_manager.h"
#include "backend.h"
#include "protocol.h"
#include <stdint.h>
#include "dlist.h"
#include "logic/aL.h"
#include "modules/fire.h"

void fire_init()
{

}

void * fire_new(Player * player)
{
	Fire * fire = (Fire*)malloc(sizeof(Fire));
    memset(fire, 0, sizeof(Fire));

    unsigned long long pid = player_get_id(player);
    fire->pid = pid;

    return fire;
}

void * fire_load(Player * player)
{
	
	unsigned long long playerid = player_get_id(player);

    WRITE_DEBUG_LOG("player %llu load fire", playerid);

    Fire * fire = 0;

    if (DATA_Fire_load_by_pid(&fire, playerid) != 0) {
        if (fire) free(fire);
        return 0;
    }

    if (fire == 0) {
        fire = (Fire*)malloc(sizeof(Fire));
        memset(fire, 0, sizeof(Fire));
        fire->pid = playerid;

        DATA_Fire_new(fire);
    }

    return fire;
}

int fire_update(Player * player, void * data, time_t now)
{
	return 0;
}

int fire_save(Player * player, void * data, const char * sql, ...)
{
	return 0;
}

int fire_release(Player * player, void * data)
{
	Fire * fire = (Fire*)data;
    DATA_Fire_release(fire);
    return 0;
}


static int add_notify(Fire * fire)
{
    amf_value * value = amf_new_array(5);
    amf_set(value, 0, amf_new_integer(fire->max));
    amf_set(value, 1, amf_new_integer(fire->cur));

    return notification_set(fire->pid, NOTIFY_FIRE, 0, value);
}


int fire_set_max(Player * player, unsigned int max)
{
    Fire * fire = player_get_fire(player);

    if (fire->max == max) {
        return 0;
    }

    DATA_Fire_update_max(fire, max);
    DATA_Fire_update_max_update_time(fire, agT_current());
    //DATA_FLUSH_ALL();
    //unsigned long long pid =player_get_id(player);
    //rank_fire_set(pid,max);
    add_notify(fire);
    return 0;
}

int fire_set_cur(Player * player, unsigned int cur)
{
    Fire * fire = player_get_fire(player);

    DATA_Fire_update_cur(fire, cur);
    DATA_Fire_update_update_time(fire, agT_current());
    //DATA_FLUSH_ALL();

    add_notify(fire);
    return 0;
}

amf_value * fire_build_message(struct Fire * pFire)
{
	if (pFire == 0) {
		return 0;
	}

	amf_value * c = amf_new_array(2);
	amf_set(c,  0, amf_new_integer(pFire->max));
	amf_set(c,  1, amf_new_integer(pFire->cur));

	return c;
}
