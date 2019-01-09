#include <assert.h>
#include <string.h>
#include "property.h"
#include "database.h"
#include "log.h"
#include "package.h"
#include "notify.h"
#include "mtime.h"
#include "stringCache.h"

#include "event_manager.h"
#include "backend.h"
#include "protocol.h"
#include <stdint.h>
#include "rankreward.h"


#define YQ_MILITARY_POWER_FRESH_PERIOD 60
static struct Property *  alloc_property()
{
	struct Property * p = (struct Property*)malloc(sizeof(struct Property));
	memset(p, 0, sizeof(struct Property));
	return p;
}

static void release_property(struct Property * p)
{
	assert(p);
	DATA_Property_release(p);
}

// module operation
void property_init()
{
}

void * property_new(Player * player) 
{
	struct Property * property = alloc_property();
	memset(property, 0, sizeof(Property));

	property->pid = player_get_id(player);
	property->name = player_get_name(player);

	property->create = agT_current();
	property->login  = agT_current();
	property->ip     = "";
	property->title  = 0;
	property->total_star = 0;
	property->total_star_change_time = agT_current();

	if (DATA_Property_new(property) != 0) {
		release_property(property);
		return 0;
	}

	return property;
}

void * property_load(Player * player) 
{
	/* prepare */
	unsigned long long playerid = player_get_id(player);
	WRITE_DEBUG_LOG("player %llu load property", playerid);

	/* load from database */
	struct Property * property = 0; 
	if (DATA_Property_load_by_pid(&property, playerid) != 0) {
		if (property) free(property);
		return 0;
	}
	if (property == 0) {
		return 0;
	}

	return property;
}

int    property_update(Player * player, void * data, time_t now) 
{
	return 0;
}

int    property_save(Player * player, void * data, const char * sql, ...) 
{
	return 0;
}

int    property_release(Player * player, void * data) 
{
	struct Property * property = (struct Property*)data;
	release_property(property);
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
// get and set

static int add_notify(Property * property)
{
	amf_value * v = amf_new_array(4);
	// amf_set(v, 0, amf_new_double(property->pid));
	amf_set(v, 0, amf_new_string(property->name, 0));
	amf_set(v, 1, amf_new_integer(property->head));
	amf_set(v, 2, amf_new_integer(property->title));
	amf_set(v, 3, amf_new_integer(property->total_star));

	notification_set(property->pid, NOTIFY_PROPERTY, 0, v);
	return 0;
}

int add_property_notify(Property * property)
{
	return add_notify(property);
}

int property_change_nick(Player* player, const char * nick) 
{
	Property * property = player_get_property(player);

	DATA_Property_update_name(property, agSC_get(nick, 0));


	add_notify(property);

	return RET_SUCCESS;
}

int property_change_head(Player* player, int head)
{
	Property * property = player_get_property(player);
	DATA_Property_update_head(property, head);

	add_notify(property);

	return RET_SUCCESS;
}

int property_set_title(Player * player, int title)
{
	Property * property = player_get_property(player);
	DATA_Property_update_title(property, title);

	add_notify(property);

	return RET_SUCCESS;
}

int property_change_total_star(Player * player, int total_star) 
{
	Property * property = player_get_property(player);
	if ((unsigned int)total_star > property->total_star) {
		DATA_Property_update_total_star(property, total_star);
		DATA_Property_update_total_star_change_time(property, agT_current());
	}

	rank_star_set(property->pid, property->total_star);
	add_notify(property);

	return RET_SUCCESS;
}

int property_change_max_floor(Player * player, int floor) 
{
	Property * property = player_get_property(player);
	if ((unsigned int)floor > property->max_floor) {
		DATA_Property_update_max_floor(property, floor);
		DATA_Property_update_max_floor_change_time(property, agT_current());
		WRITE_DEBUG_LOG("player %llu max floor change %d->%d", property->pid, property->max_floor, floor);
		rank_tower_set(property->pid, property->max_floor);
	}

	return RET_SUCCESS;
}
