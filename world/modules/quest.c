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
#include "modules/quest.h"
#include "config/item.h"

typedef struct QuestSet {
	struct map * m;
	struct Quest * list;
} QuestSet;

void quest_init()
{

}

void * quest_new(Player * player)
{
	QuestSet * set = (QuestSet*)malloc(sizeof(QuestSet));
	memset(set, 0, sizeof(QuestSet));
	set->m = _agMap_new(0);
	set->list = NULL;
	return set;
}

void * quest_load(Player * player)
{
	if (player == NULL)
	{
		return NULL;
	}

	unsigned long long pid = player_get_id(player);

	struct Quest * list = NULL;
	if (DATA_Quest_load_by_pid(&list, pid) != 0) {
		return NULL;
	}

	QuestSet * set = (QuestSet*)malloc(sizeof(QuestSet));
	memset(set, 0, sizeof(QuestSet));
	set->m = _agMap_new(0);
	set->list = NULL;
	while (list)
	{
		struct Quest * cur = list;
		list = list->next;

		if (cur->id <= 0) {
			WRITE_WARNING_LOG("  quest id %d error", cur->id);
			free(cur);
			continue;
		}

		_agMap_ip_set(set->m, cur->id, cur);

		dlist_init(cur);
		dlist_insert_tail(set->list, cur);
	}

	return set;
}

int quest_update(Player * player, void * data, time_t now)
{
	return 0;
}

int quest_save(Player * player, void * data, const char * sql, ...)
{
	return 0;
}

int quest_release(Player * player, void * data)
{
	QuestSet * set = (QuestSet *)data;
	if (set != NULL)
	{
		while(set->list)
		{
			struct Quest * node = set->list;
			dlist_remove(set->list, node);
			if (node->data_flag == 0x100) {
				free(node);
			} else {
				DATA_Quest_release(node);
			}
		}

		_agMap_delete(set->m);
		free(set);
	}
	return 0;
}


struct amf_value * quest_encode_amf(struct Quest * quest)
{
	if (quest) {
		amf_value * c = amf_new_array(10);
		amf_set(c,  0, amf_new_integer(quest->id));
		amf_set(c,  1, amf_new_integer(quest->id));
		amf_set(c,  2, amf_new_integer(quest->status));
		amf_set(c,  3, amf_new_integer(quest->record_1));
		amf_set(c,  4, amf_new_integer(quest->record_2));
		amf_set(c,  5, amf_new_integer(quest->count));
		amf_set(c,  6, amf_new_integer(quest->consume_item_save_1));
		amf_set(c,  7, amf_new_integer(quest->consume_item_save_2));
		amf_set(c,  8, amf_new_integer(quest->accept_time));
		amf_set(c,  9, amf_new_integer(quest->submit_time));

		return c;
	}
	return 0;
}

static int quest_add_notify(struct Quest * quest)
{
	if (quest != NULL) {
		return notification_set(quest->pid, NOTIFY_QUEST, quest->id, quest_encode_amf(quest));
	}
	return 1;
}


struct Quest * quest_get(Player * player, int id)
{
	QuestSet * set = (QuestSet*)player_get_module(player, PLAYER_MODULE_QUEST);
	if (set == NULL) {
		return 0;
	}
	return (struct Quest*) _agMap_ip_get(set->m, id);
}

struct Quest * quest_add(Player * player, int id, int status, time_t accept_time)
{
	WRITE_DEBUG_LOG("player %llu add quest %d, status %d", player_get_id(player), id, status);

	QuestSet * set = (QuestSet*)player_get_module(player, PLAYER_MODULE_QUEST);
	if (set == NULL) {
		return 0;
	}

	struct Quest * item = (struct Quest*)malloc(sizeof(struct Quest));
	memset(item, 0, sizeof(struct Quest));
	item->pid = player_get_id(player);
	item-> id = id;
	item->status = status;
	item->accept_time = accept_time;
	item->submit_time = 0;

	if (status == QUEST_STATUS_INIT_WITH_OUT_SAVE) {
		WRITE_DEBUG_LOG("  QUEST_STATUS_INIT_WITH_OUT_SAVE");
		item->status = QUEST_STATUS_INIT;
		item->data_flag = 0x100;
	} else {
		DATA_Quest_new(item);
	}

	dlist_init(item);
	dlist_insert_tail(set->list, item);

	_agMap_ip_set(set->m, item->id, item);

	if (status != QUEST_STATUS_INIT_WITH_OUT_SAVE) {
		quest_add_notify(item);
	}

	return item;
}

int quest_remove(Player * player, int id)
{
	WRITE_DEBUG_LOG("player %llu remove quest %d", player_get_id(player), id);

	QuestSet * set = (QuestSet*)player_get_module(player, PLAYER_MODULE_QUEST);
	if (set == NULL) {
		return -1;
	}

	struct Quest * item = (struct Quest*) _agMap_ip_get(set->m, id);
	if (item == 0) {
		WRITE_DEBUG_LOG(" quest not exists");
		return -1;
	}

	item->id = 0;
	quest_add_notify(item);
	dlist_remove(set->list, item);

	if (item->data_flag == 0x100) {
		free(item);
	} else {
		DATA_Quest_delete(item);
	}

	return 0;
}

struct Quest * quest_next(struct Player * player, struct Quest * item)
{
	struct QuestSet * set = (struct QuestSet*)player_get_module(player, PLAYER_MODULE_QUEST);
	if (set == NULL) {
		return 0;
	}

	return dlist_next(set->list, item);
}

void quest_update_status(struct Quest * quest, int status, int record_1, int record_2, int count, int consume_item_save_1, int consume_item_save_2, time_t accept_time, time_t submit_time)
{
	if (quest == 0) {
		return;
	}


	int changed = false;
#define TRY_UPDATE(KEY)                         \
	if (KEY >= 0 && KEY != (int)quest->KEY) {       \
		WRITE_DEBUG_LOG("player %llu update quest %d filed %s, %d => %d", quest->pid, quest->id,  #KEY, (int)quest->KEY, (int)KEY); \
		if (quest->data_flag == 0x100) {      \
			quest->KEY = KEY;                      \
		} else {                              \
			DATA_Quest_update_##KEY(quest, KEY);  \
		}                                     \
		changed = true;                       \
	}

	TRY_UPDATE(status);
	TRY_UPDATE(record_1);
	TRY_UPDATE(record_2);
	TRY_UPDATE(count);
	TRY_UPDATE(consume_item_save_1);
	TRY_UPDATE(consume_item_save_2);

	if (accept_time != 0) {
		TRY_UPDATE(accept_time)
	}	

	if (submit_time != 0) {
		TRY_UPDATE(submit_time)
	}	
#undef TRY_UPDATE

	if (changed) {
		if (quest->data_flag & 0x100) {
			DATA_Quest_new(quest);
		}
		quest_add_notify(quest);
	}
}
