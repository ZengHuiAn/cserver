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
#include "config/hero.h"
#include "logic/aL.h"
#include "config/reward.h"
#include "talent.h"
#include "config/talent.h"
#include "modules/item.h"
#include "modules/hero_item.h"
#include "config/item.h"

typedef struct HeroItemSet {
	struct map *uuid;
	struct HeroItem * list;
} HeroItemSet;

void hero_item_init()
{

}

void * hero_item_new(Player * player)
{
	HeroItemSet * set = (HeroItemSet*)malloc(sizeof(HeroItemSet));
	memset(set, 0, sizeof(HeroItemSet));
	set->uuid = _agMap_new(0);
	set->list = NULL;
	return set;
}

void * hero_item_load(Player * player)
{
	if (player == NULL)
	{
		return NULL;
	}

	unsigned long long pid = player_get_id(player);

	struct HeroItem * list = NULL;
	if (DATA_HeroItem_load_by_pid(&list, pid) != 0) {
		return NULL;
	}

	HeroItemSet * set = (HeroItemSet*)malloc(sizeof(HeroItemSet));
	memset(set, 0, sizeof(HeroItemSet));
	set->uuid = _agMap_new(0);
	set->list = NULL;
	while (list)
	{
		struct HeroItem * cur = list;
		list = list->next;

		if (cur->id <= 0) {
			WRITE_WARNING_LOG("  hero item id %d error", cur->id);
			free(cur);
			continue;
		}

		struct map * arr = (struct map*)_agMap_ip_get(set->uuid, cur->uid);
		if (arr == 0) {
			arr = _agMap_new(0);
			_agMap_ip_set(set->uuid, cur->uid, arr);
		}

		dlist_init(cur);
		dlist_insert_tail(set->list, cur);

		_agMap_ip_set(arr, cur->id, cur);
	}
	return set;
}

int hero_item_update(Player * player, void * data, time_t now)
{
	return 0;
}

int hero_item_save(Player * player, void * data, const char * sql, ...)
{
	return 0;
}

static void free_map(uint64_t, void * p, void *)
{
	struct map* m = (struct map*)p;
	_agMap_delete(m);
}

int hero_item_release(Player * player, void * data)
{
	HeroItemSet * set = (HeroItemSet *)data;
	if (set != NULL)
	{
		while(set->list)
		{
			struct HeroItem * node = set->list;
			dlist_remove(set->list, node);
			DATA_HeroItem_release(node);
		}

		_agMap_ip_foreach(set->uuid, free_map, 0);

		_agMap_delete(set->uuid);
		free(set);
	}
	return 0;
}

struct HeroItem * hero_item_get(Player * player, unsigned long long uuid, int id)
{
	if (id <= 0) {
		return 0;
	}

	HeroItemSet * set = (HeroItemSet*)player_get_module(player, PLAYER_MODULE_HEROITEM);
	if (set == NULL) {
		return 0;
	}

	struct map * m = (struct map*)_agMap_ip_get(set->uuid, uuid);
	if (m == 0) {
		return 0;
	}

	return (struct HeroItem*) _agMap_ip_get(m, id);
}


int hero_item_count(Player * player, unsigned long long uuid, int id)
{
	HeroItem * item = hero_item_get(player, uuid, id);
	return item ? item->value : 0;
}

static int hero_item_add_notify(struct HeroItem * item)
{
	if (item != NULL) {
		amf_value * c = amf_new_array(4);
		amf_set(c,  0, amf_new_integer(item->uid));
		amf_set(c,  1, amf_new_integer(item->id));
		amf_set(c,  2, amf_new_integer(item->value));
		amf_set(c,  3, amf_new_integer(item->status));	
		return notification_add(item->pid, NOTIFY_HERO_ITEM, c);
	}
	return 1;
}

int hero_item_set(Player * player, unsigned long long uuid, int id, int value, int reason, int status)
{
	if (id <= 0) {
		return -1;
	}

	HeroItemSet * set = (HeroItemSet*)player_get_module(player, PLAYER_MODULE_HEROITEM);
	if (set == NULL) {
		return -1;
	}

	struct map * arr = (struct map*)_agMap_ip_get(set->uuid, uuid);
	if (arr == 0) {
		arr = _agMap_new(0);
		_agMap_ip_set(set->uuid, uuid, arr);
	}


	struct HeroItem * item = (struct HeroItem*) _agMap_ip_get(arr, id);
	if (item == 0) {
		item = (struct HeroItem*)malloc(sizeof(struct HeroItem));
		memset(item, 0, sizeof(struct HeroItem));
		item->pid = player_get_id(player);
		item->uid = uuid;
		item-> id = id;
		item->value = value;
		item->status = status; 

		WRITE_DEBUG_LOG("player %llu hero %llu item %u limit %u -> %u",
				item->pid, item->uid, item->id, 0, item->value);
	
		DATA_HeroItem_new(item);

		dlist_init(item);
		dlist_insert_tail(set->list, item);

		_agMap_ip_set(arr, id, item);
	} else {
		WRITE_DEBUG_LOG("player %llu hero %llu item %u limit %u -> %u",
				item->pid, item->uid, item->id, item->value, value);

		DATA_HeroItem_update_value(item, value);
		DATA_HeroItem_update_status(item, status);
	}

	hero_item_add_notify(item);

	return 0;
}

int hero_item_add(Player * player, unsigned long long uuid, int id, int value, int reason, int status)
{
	if (value < 0) {
		return -1;
	}

	if (value == 0) {
		return 0;
	}

	if (id <= 0) {
		return -1;
	}

	HeroItemSet * set = (HeroItemSet*)player_get_module(player, PLAYER_MODULE_HEROITEM);
	if (set == NULL) {
		return -1;
	}

	struct map * arr = (struct map*)_agMap_ip_get(set->uuid, uuid);
	if (arr == 0) {
		arr = _agMap_new(0);
		_agMap_ip_set(set->uuid, uuid, arr);
	}

	struct HeroItem * item = (struct HeroItem*) _agMap_ip_get(arr, id);
	if (item == 0) {
		item = (struct HeroItem*)malloc(sizeof(struct HeroItem));
		memset(item, 0, sizeof(struct HeroItem));
		item->pid = player_get_id(player);
		item->uid = uuid;
		item->id = id;
		item->value = value;
		item->status = status;

		WRITE_DEBUG_LOG("player %llu hero %llu item %u limit %u -> %u",
				item->pid, item->uid, item->id, 0, item->value);

	
		DATA_HeroItem_new(item);

		dlist_init(item);
		dlist_insert_tail(set->list, item);

		_agMap_ip_set(arr, id, item);
	} else {
		WRITE_DEBUG_LOG("player %llu hero %llu item %u limit %u + %u",
				item->pid, item->uid, item->id, item->value, value);

		DATA_HeroItem_update_value(item, item->value + value);
	}

	hero_item_add_notify(item);

	return 0;
}

int hero_item_remove(Player * player, unsigned long long uuid, int id, int value, int reason)
{
	if (value < 0) {
		return -1;
	}

	if (value == 0) {
		return 0;
	}

	struct HeroItem * item = hero_item_get(player, uuid, id);
	if (item == 0 || item->value < (unsigned int)value) {
		return -1;
	}

	WRITE_DEBUG_LOG("player %llu hero %llu item %u limit %u - %u",
			item->pid, item->uid, item->id, item->value, value);

	DATA_HeroItem_update_value(item, item->value - value);

	hero_item_add_notify(item);

	return 0;
}

struct HeroItem * hero_item_next(struct Player * player, struct HeroItem * item)
{
	struct HeroItemSet * set = (struct HeroItemSet*)player_get_module(player, PLAYER_MODULE_HEROITEM);
	if (set == NULL) {
		return 0;
	}

	return dlist_next(set->list, item);
}
