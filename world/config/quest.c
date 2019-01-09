#include <stdlib.h>
#include <string.h>
#include "xmlHelper.h"
#include "logic_config.h"
#include "hero.h"
#include "map.h"
#include "array.h"
#include "package.h"
#include "quest.h"
#include "dlist.h"
#include "modules/property.h"
#include "player.h"
#include "timeline.h"
#include "mtime.h"


#include "config_type.h"

#include "../db_config/TABLE_config_quest.h"
#include "../db_config/TABLE_config_quest.LOADER.h"

#include "../db_config/TABLE_config_advance_quest.h"
#include "../db_config/TABLE_config_advance_quest.LOADER.h"

#include "../db_config/TABLE_quest_pool.h"
#include "../db_config/TABLE_quest_pool.LOADER.h"

#include "../db_config/TABLE_config_quest_menu.h"
#include "../db_config/TABLE_config_quest_menu.LOADER.h"

#include "../db_config/TABLE_config_7day_delay.h"
#include "../db_config/TABLE_config_7day_delay.LOADER.h"

#include "../db_config/TABLE_quest_rule.h"
#include "../db_config/TABLE_quest_rule.LOADER.h"

#include "../db_config/TABLE_quest_event_permission.h"
#include "../db_config/TABLE_quest_event_permission.LOADER.h"

static struct map * quest_group = NULL;
static struct map * quest_list = NULL;
static struct map * quest_delay_list = NULL;
static QuestConfig * auto_accept_quest_list = NULL;

static int parse_quest_config(struct config_quest * row) 
{
	if (row->id <= 0) {
		WRITE_ERROR_LOG("parse quest fail, id(%d) <= 0;", row->id);
		return -1;
	}

	struct QuestConfig * pCfg = LOGIC_CONFIG_ALLOC(QuestConfig, 1);
	memset(pCfg, 0, sizeof(struct QuestConfig));

	pCfg->id   = row->id;
	pCfg->type = row->type;
	pCfg->only_accept_by_other_activity = 1;

#define READ_STRUCT(TYPE, IDX, FIELD) \
	pCfg->TYPE[IDX-1].FIELD = row->TYPE##_##FIELD####IDX
	
	READ_STRUCT(event, 1, id); READ_STRUCT(event, 1, count); 
	READ_STRUCT(event, 2, id); READ_STRUCT(event, 2, count); 

	READ_STRUCT(consume, 1, type); READ_STRUCT(consume, 1, id); READ_STRUCT(consume, 1, value);
	READ_STRUCT(consume, 2, type); READ_STRUCT(consume, 2, id); READ_STRUCT(consume, 2, value);

	pCfg->consume[0].need_reset = pCfg->consume[0].need_reset ? pCfg->consume[0].need_reset : QUEST_CONSUME_ITEM_FLAG_CONSUME_ON_SUBMIT;
	pCfg->consume[1].need_reset = pCfg->consume[1].need_reset ? pCfg->consume[1].need_reset : QUEST_CONSUME_ITEM_FLAG_CONSUME_ON_SUBMIT;

	READ_STRUCT(reward, 1, type); READ_STRUCT(reward, 1, id); READ_STRUCT(reward, 1, value); READ_STRUCT(reward, 1, richvalue); pCfg->reward[0].count = 9999;
	READ_STRUCT(reward, 2, type); READ_STRUCT(reward, 2, id); READ_STRUCT(reward, 2, value); READ_STRUCT(reward, 2, richvalue); pCfg->reward[1].count = 9999;
	READ_STRUCT(reward, 3, type); READ_STRUCT(reward, 3, id); READ_STRUCT(reward, 3, value); READ_STRUCT(reward, 3, richvalue); pCfg->reward[2].count = 9999;

#undef READ_STRUCT

	pCfg->count_limit = row->time_limit;


	if (_agMap_ip_set(quest_list, pCfg->id, pCfg) != 0) {
		WRITE_ERROR_LOG("duplicate quest id %d", pCfg->id);
		return -1;
	}
	return 0;
}

/*#define GET_DAY_BEGIN_TIME(x) \
    x - (x + 8 * 3600) % 86400*/


#define ATOI(x, def) ( (x) ? atoi(x) : (def))

/*
static void init_type_array(int * array, int count, const char * str)
{
	int n = 0;
	char * ptr;
	char str_copy[256];
	memset(str_copy, 0, sizeof(str_copy));
	strcpy(str_copy, str);
	ptr = strtok(str_copy, "|");
	while(ptr != NULL && n < count) {
		array[n] = ATOI(ptr, 0);
		ptr = strtok(NULL, "|");
		n++;	
	}		

	for (int i = 0; i < count; i++) {
		WRITE_DEBUG_LOG("i :%d type :%d", i, array[i]);
	}
}
*/

static int parse_advance_quest_config(struct config_advance_quest * row) 
{
	if (row->id <= 0) {
		WRITE_ERROR_LOG("parse quest fail, id(%d) <= 0;", row->id);
		return -1;
	}

	struct QuestConfig * pCfg = LOGIC_CONFIG_ALLOC(QuestConfig, 1);
	memset(pCfg, 0, sizeof(struct QuestConfig));

	pCfg->id   = row->id;
	pCfg->type = row->type;

#define READ_STRUCT(TYPE, IDX, FIELD) \
	pCfg->TYPE[IDX-1].FIELD = row->TYPE##_##FIELD####IDX
	
	READ_STRUCT(event, 1, type); READ_STRUCT(event, 1, id); READ_STRUCT(event, 1, count); 
	READ_STRUCT(event, 2, type); READ_STRUCT(event, 2, id); READ_STRUCT(event, 2, count); 

	READ_STRUCT(consume, 1, type); READ_STRUCT(consume, 1, id); READ_STRUCT(consume, 1, value); READ_STRUCT(consume, 1, need_reset);
	READ_STRUCT(consume, 2, type); READ_STRUCT(consume, 2, id); READ_STRUCT(consume, 2, value); READ_STRUCT(consume, 2, need_reset);

	pCfg->consume[0].need_reset = pCfg->consume[0].need_reset ? pCfg->consume[0].need_reset : QUEST_CONSUME_ITEM_FLAG_CONSUME_ON_SUBMIT;
	pCfg->consume[1].need_reset = pCfg->consume[1].need_reset ? pCfg->consume[1].need_reset : QUEST_CONSUME_ITEM_FLAG_CONSUME_ON_SUBMIT;

	READ_STRUCT(reward, 1, type); READ_STRUCT(reward, 1, id); READ_STRUCT(reward, 1, value); READ_STRUCT(reward, 1, richvalue); READ_STRUCT(reward, 1, count);
	READ_STRUCT(reward, 2, type); READ_STRUCT(reward, 2, id); READ_STRUCT(reward, 2, value); READ_STRUCT(reward, 2, richvalue); READ_STRUCT(reward, 2, count);
	READ_STRUCT(reward, 3, type); READ_STRUCT(reward, 3, id); READ_STRUCT(reward, 3, value); READ_STRUCT(reward, 3, richvalue); READ_STRUCT(reward, 3, count);

#undef READ_STRUCT

	pCfg->depend.quest = row->depend_quest_id;
	pCfg->depend.fight = row->depend_fight_id;
	pCfg->depend.level = row->depend_level;
	pCfg->depend.item  = row->depend_item;

	pCfg->group        = row->mutex_id;
	pCfg->group_next   = 0;

	pCfg->extra_reward_time_limit = row->extrareward_timelimit;
	pCfg->extra_reward.type = row->extrareward_type;
	pCfg->extra_reward.id = row->extrareward_id;
	pCfg->extra_reward.value = row->extrareward_value;

	if (pCfg->group > 0) {
		struct QuestConfig * head = (struct QuestConfig*)_agMap_ip_get(quest_group, pCfg->group); 
		if (head == 0) {
			_agMap_ip_set(quest_group, pCfg->group, pCfg);
		} else {
			pCfg->group_next = head->group_next;
			head->group_next = pCfg;
		}
	}

	/*
	if (row->begin_time < 100 && row->begin_time != 0) {
		time_t open_server_time = GET_DAY_BEGIN_TIME(get_open_server_time());
		
		pCfg->time.begin    = open_server_time + (row->begin_time - 1) * 86400;
		pCfg->time.end      = open_server_time + (row->end_time - 1) * 86400;
	}
	else 
	*/
	{
		pCfg->time.begin    = row->begin_time;
		pCfg->time.end      = row->end_time;
	}
	pCfg->time.period   = row->period;
	pCfg->time.duration = row->duration;

	pCfg->count_limit = row->count;
	pCfg->next_quest  = row->next_id;
	pCfg->next_quest_group  = row->next_quest_group;
	pCfg->next_quest_menu   = row->next_quest_menu;
	pCfg->auto_accept = row->auto_accept;

	pCfg->drop_id = row->drop_id;
	pCfg->drop_count = row->drop_count;

	pCfg->relative_to_born = row->relative_to_born;
	pCfg->time_limit = row->time_limit;	
	pCfg->type_flag = row->type_flag;

	if (_agMap_ip_set(quest_list, pCfg->id, pCfg) != 0) {
		WRITE_ERROR_LOG("duplicate quest id %d", pCfg->id);
		return -1;
	}

	if ((pCfg->auto_accept & 0x01)) {
		if (pCfg->only_accept_by_other_activity == 0 
				&& pCfg->depend.fight == 0
				&& pCfg->depend.quest == 0 
				&& pCfg->depend.level == 0 
				&& pCfg->depend.item  == 0 
				&& (pCfg->consume[0].need_reset & 12) == 0  
				&& (pCfg->consume[1].need_reset & 12) == 0  
		   ) {
			dlist_init(pCfg);
			if (!auto_accept_quest_list) {
				pCfg->prev = pCfg->next = pCfg;
				auto_accept_quest_list = pCfg;
			} else {
				dlist_insert_tail(auto_accept_quest_list, pCfg);
			}
		}
	}

	return 0;
}

struct QuestConfig * get_quest_config(int id)
{
	struct QuestConfig * cfg = (struct QuestConfig*)_agMap_ip_get(quest_list, id);
	if (!cfg) return 0;
	
	if (cfg->time.begin < 100 && cfg->time.begin != 0 && cfg->relative_to_born == 0) {
		time_t open_server_time = GET_DAY_BEGIN_TIME(get_open_server_time());
		
		cfg->time.begin    = open_server_time + (cfg->time.begin - 1) * 86400;
		cfg->time.end      = open_server_time + (cfg->time.end - 1) * 86400 - 1;

	}
	return cfg;//(struct QuestConfig*)_agMap_ip_get(quest_list, id);
}

struct QuestConfig * get_quest_list_of_group(int group)
{
	return (struct QuestConfig*)_agMap_ip_get(quest_group, group);
}

struct QuestConfig * auto_accept_quest_next(struct QuestConfig * it)
{
	if (auto_accept_quest_list == NULL) {
		return 0;
	}
	
	return dlist_next(auto_accept_quest_list, it);
}

static struct map * quest_pool = 0;
static struct map * quest_menu = 0;

struct QuestConfig * get_quest_from_pool(int id, int level)
{
	struct QuestPool * pool = (struct QuestPool *)_agMap_ip_get(quest_pool, id);
	if (pool == 0) {
		return 0;
	}


	int weight = 0;

	struct QuestPoolItem * ite = pool->items;
	for (; ite != 0 ; ite = ite->next) {
		if (ite->lev_min > level || (ite->lev_max > 0 && ite->lev_max < level)) {
			continue;
		}

		weight += ite->weight;
	}

	if (weight == 0) {
		return 0;
	}

	int value = rand() % weight + 1;

	ite = pool->items;
	for (; ite != 0 ; ite = ite->next) {
		if (ite->lev_min > level || (ite->lev_max > 0 && ite->lev_max < level)) {
			continue;
		}

		if (ite->weight >= value) {
			break;
		}
		value -= ite->weight;
	}

	return ite ? get_quest_config(ite->quest) : 0;
}

static int parse_quest_pool_item(struct quest_pool * row)
{
	struct QuestPool * pool = (struct QuestPool *)_agMap_ip_get(quest_pool, row->id);
	if (pool == 0) {
		pool = LOGIC_CONFIG_ALLOC(QuestPool, 1);
		pool->id = row->id;
		pool->weight = 0;
		pool->items = 0;
		_agMap_ip_set(quest_pool, row->id, pool);
	}

	struct QuestPoolItem * item = LOGIC_CONFIG_ALLOC(QuestPoolItem, 1);
	item->quest = row->quest;
	item->weight = row->weight;
	item->lev_min = row->lv_min;
	item->lev_max = row->lv_max;
	pool->weight += row->weight;
	item->next = pool->items;
	pool->items = item;

	if (_agMap_ip_get(quest_list, item->quest) == 0) {
		WRITE_ERROR_LOG(" quest %d in quest_pool not exit", item->quest);
		return -1;
	}

	return 0;
}

struct QuestConfig * get_quest_from_menu(int id, int level, int select)
{
	struct QuestPool * menu = (struct QuestPool *)_agMap_ip_get(quest_menu, id);
	if (menu == 0) {
		return 0;
	}


	struct QuestPoolItem * ite = menu->items;
	for (; ite != 0 ; ite = ite->next) {
		if (ite->lev_min > level || (ite->lev_max > 0 && ite->lev_max < level)) {
			continue;
		}

		if (ite->quest == select) {
			break;
		}
	}

	return ite ? get_quest_config(ite->quest) : 0;
}


static int parse_quest_menu_item(struct config_quest_menu * row)
{
	struct QuestPool * menu = (struct QuestPool *)_agMap_ip_get(quest_menu, row->id);
	if (menu == 0) {
		menu = LOGIC_CONFIG_ALLOC(QuestPool, 1);
		menu->id = row->id;
		menu->weight = 0;
		menu->items = 0;
		_agMap_ip_set(quest_menu, row->id, menu);
	}

	struct QuestPoolItem * item = LOGIC_CONFIG_ALLOC(QuestPoolItem, 1);
	item->quest = row->quest;
	item->weight = 0;
	item->lev_min = row->lv_min;
	item->lev_max = row->lv_max;
	item->next = menu->items;
	menu->items = item;

	if (item->quest != 0 && _agMap_ip_get(quest_list, item->quest) == 0) {
		WRITE_ERROR_LOG(" quest %d in config_quest_menu not exit", item->quest);
		return -1;
	}

	return 0;
}

static int parse_quest_delay(struct config_7day_delay * row) 
{
	if (row->quest_id <= 0) {
		WRITE_ERROR_LOG("parse quest delay fail, id(%d) <= 0;", row->quest_id);
		return -1;
	}

	struct QuestDelayConfig * pCfg = LOGIC_CONFIG_ALLOC(QuestDelayConfig, 1);
	memset(pCfg, 0, sizeof(struct QuestDelayConfig));

	pCfg->id   = row->quest_id;
	pCfg->delay = row->delay_time;

	if (_agMap_ip_set(quest_delay_list, pCfg->id, pCfg) != 0) {
		WRITE_ERROR_LOG("duplicate quest id %d in config_7day_delay", pCfg->id);
		return -1;
	}

	return 0;
}

struct QuestDelayConfig * get_quest_delay(int id)
{
	return (struct QuestDelayConfig*)_agMap_ip_get(quest_delay_list, id);
}


static struct map * override_event_map = NULL;
static int parse_quest_rule(struct quest_rule * row)
{
	struct OverrideQuestEvent * ov_quest = (struct OverrideQuestEvent *)_agMap_ip_get(override_event_map, row->event_type);
	if (!ov_quest) {
		ov_quest = LOGIC_CONFIG_ALLOC(OverrideQuestEvent, 1);
		memset(ov_quest, 0, sizeof(struct OverrideQuestEvent));
		ov_quest->type = row->event_type;

		if (row->min_value) {
			ov_quest->min_id[0] = row->event_id;
		}
	
		if (row->max_value) {
			ov_quest->max_id[0] = row->event_id;
		}
		
		_agMap_ip_set(override_event_map, row->event_type, ov_quest);
	} else {
		int i;
		if (row->min_value) {
			for (i = 0; i < OVERRIDE_QUEST_EVENT_NUM; i++) {
				int id = ov_quest->min_id[i];
				if (id == row->event_id) {
					WRITE_ERROR_LOG("%s:duplicate quest id %d for type %d", __FUNCTION__, row->event_id, row->event_type);
					return -1;	
				}

				if (id == 0) {
					ov_quest->min_id[i] = row->event_id;
					break;
				}
			}
			if (i == OVERRIDE_QUEST_EVENT_NUM) {
				WRITE_ERROR_LOG("%s:max event for quest type %d", __FUNCTION__, row->event_type);
				return -1;
			}
		}

		if (row->max_value) {
			for (i = 0; i < OVERRIDE_QUEST_EVENT_NUM; i++) {
				int id = ov_quest->max_id[i];
				if (id == row->event_id) {
					WRITE_ERROR_LOG("%s:duplicate quest id %d for type %d", __FUNCTION__, row->event_id, row->event_type);
					return -1;	
				}

				if (id == 0) {
					ov_quest->max_id[i] = row->event_id;
					break;
				}
			}
			if (i == OVERRIDE_QUEST_EVENT_NUM) {
				WRITE_ERROR_LOG("%s:max event for quest type %d", __FUNCTION__, row->event_type);
				return -1;
			}
		}

	}

	return 0;
}

int quest_need_override_max(int type, int id)
{
	struct OverrideQuestEvent * ov_quest = (struct OverrideQuestEvent *)_agMap_ip_get(override_event_map, type);
	if (!ov_quest) {
		return 0;
	}

	int i;
	for (i = 0; i < OVERRIDE_QUEST_EVENT_NUM; i ++)	{
		if (ov_quest->max_id[i] == id) {
			return 1;
		}

		if (ov_quest->max_id[i] == 0) {
			return 0;
		}
	}

	return 0;
}

int quest_need_override_min(int type, int id)
{
	struct OverrideQuestEvent * ov_quest = (struct OverrideQuestEvent *)_agMap_ip_get(override_event_map, type);
	if (!ov_quest) {
		return 0;
	}

	int i;
	for (i = 0; i < OVERRIDE_QUEST_EVENT_NUM; i ++)	{
		if (ov_quest->min_id[i] == id) {
			return 1;
		}

		if (ov_quest->min_id[i] == 0) {
			return 0;
		}
	}

	return 0;
}

static struct map * quest_event_permission_map = NULL;
int has_permission = 1;
static int parse_quest_event_permission(struct quest_event_permission * row)
{
	struct map * event_map = (struct map *)_agMap_ip_get(quest_event_permission_map, row->event_type);
	if (!event_map) {
		event_map = LOGIC_CONFIG_NEW_MAP();	
		_agMap_ip_set(event_map, row->event_id, &has_permission);
		_agMap_ip_set(quest_event_permission_map, row->event_type, event_map);
	} else {
		if (_agMap_ip_set(event_map, row->event_id, &has_permission) != 0) {
			WRITE_DEBUG_LOG("%s: duplicate event type %d, id %d", __FUNCTION__, row->event_type, row->event_id);
			return -1;
		}
	}

	return 0;
}

int event_can_trigger_by_client(int type, int id)
{
	struct map * event_map = (struct map *)_agMap_ip_get(quest_event_permission_map, type);
	if (!event_map) {
		return 0;
	}

	int * permission = (int *)_agMap_ip_get(event_map, id);
	if (permission == &has_permission) {
		return 1;
	} else {
		return 0;
	}
}


int load_quest_config()
{
	quest_list = LOGIC_CONFIG_NEW_MAP();
	quest_group = LOGIC_CONFIG_NEW_MAP();
	if (foreach_row_of_config_quest(parse_quest_config, 0) != 0) {
		return -1;
	}

	if (foreach_row_of_config_advance_quest(parse_advance_quest_config, 0) != 0) {
		return -1;
	}

	quest_pool = LOGIC_CONFIG_NEW_MAP();
	if (foreach_row_of_quest_pool(parse_quest_pool_item, 0) != 0) {
		return -1;
	}

	quest_menu = LOGIC_CONFIG_NEW_MAP();
	if (foreach_row_of_config_quest_menu(parse_quest_menu_item, 0) != 0) {
		return -1;
	}

	quest_delay_list = LOGIC_CONFIG_NEW_MAP();
	if (foreach_row_of_config_7day_delay(parse_quest_delay, 0) != 0) {
		return -1;
	}

	override_event_map = LOGIC_CONFIG_NEW_MAP();
	if (foreach_row_of_quest_rule(parse_quest_rule, 0) != 0) {
		return -1;
	}

	quest_event_permission_map = LOGIC_CONFIG_NEW_MAP();
	if (foreach_row_of_quest_event_permission(parse_quest_event_permission, 0) != 0) {
		return -1;
	}
			
	return 0;
}
