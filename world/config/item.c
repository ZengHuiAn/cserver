#include <stdlib.h>
#include <string.h>

#include "logic_config.h"
#include "xmlHelper.h"

#include "package.h"
#include "item.h"
#include "map.h"
#include "reward.h"
#include "mtime.h"

#include "config_type.h"

#include "db_config/TABLE_config_item.h"
#include "db_config/TABLE_config_item.LOADER.h"

#include "db_config/TABLE_item_generate.h"
#include "db_config/TABLE_item_generate.LOADER.h"

#include "db_config/TABLE_config_arguments_npc.h"
#include "db_config/TABLE_config_arguments_npc.LOADER.h"


static struct ItemConfig * grow_item_list = 0;
struct map * item_base_map = NULL;

struct map * favor_item_map = NULL;

static int parse_item_config(struct config_item * row)
{
	struct ItemConfig * pCfg = LOGIC_CONFIG_ALLOC(ItemConfig, 1);
	memset(pCfg, 0, sizeof(ItemConfig));

	pCfg->id          = row->id;
	pCfg->type        = row->type;
	pCfg->compose_num = row->compose_num;

	if (_agMap_ip_set(item_base_map, pCfg->id, pCfg) != NULL) {
		WRITE_ERROR_LOG("duplicate item id %d", pCfg->id);
		return -1;
	}

	return 0;
}

static struct ItemConfig * add_fake_item_config(int id) 
{
	struct ItemConfig * pCfg = LOGIC_CONFIG_ALLOC(ItemConfig, 1);
	memset(pCfg, 0, sizeof(ItemConfig));

	pCfg->id  = id;

	void * p = _agMap_ip_set(item_base_map, pCfg->id, pCfg) ;
	assert(p == 0);

	return pCfg;
}

static int load_item_base_config()
{
	item_base_map = LOGIC_CONFIG_NEW_MAP();

	return foreach_row_of_config_item(parse_item_config, 0);
}

struct ItemConfig * get_item_base_config(int id)
{
	struct ItemConfig * item = (struct ItemConfig*)_agMap_ip_get(item_base_map, id);
	if (item == 0) {
		item = add_fake_item_config(id);
	}
	return item;
}

static int parse_item_grow_config(struct item_generate *row)
{
	if (row->end_time <= agT_current()) {
		return 0;
	}

	if (row->type != REWARD_TYPE_ITEM) {
		WRITE_ERROR_LOG("item_generate id %d type %d can't grow", row->id, row->type);
		return -1;
	}

	if (row->begin_time >= row->end_time) {
		WRITE_ERROR_LOG("item_generate id %d item %d grow config begin_time(%d) >= end_time(%d)", row->id, row->item_id, row->begin_time, row->end_time);
		return -1;
	}

	struct ItemConfig * item = get_item_base_config(row->item_id);

	if (item->grow == 0) {
		item->grow_next = grow_item_list;
		grow_item_list = item;
	}


	struct ItemGrowInfo * info = LOGIC_CONFIG_ALLOC(ItemGrowInfo, 1);
	info->begin_time = row->begin_time;
	info->end_time   = row->end_time;
	info->period     = row->period;
	info->amount     = row->amount;
	info->limit      = row->limit;
	info->is_reset   = row->is_reset;

	struct ItemGrowInfo * ite = item->grow;
	if (ite == 0 || info->end_time < ite->begin_time) {
		info->next = item->grow;
		item->grow = info;
	} else {
		for (; ite; ite = ite->next) {
			if (ite->next == 0 || info->end_time < ite->next->begin_time) {
				if (ite->end_time >= info->begin_time) {
					WRITE_ERROR_LOG("item_generate for item %d end_time (%d) >= id %d begin_time(%d)", row->item_id, (int)ite->end_time, row->id, (int)info->begin_time);
					return -1;
				}

				info->next = ite->next;
				ite->next = info;
				break;
			}
		}
	}

	return 0;
}

static int load_item_grow_config()
{
	return foreach_row_of_item_generate(parse_item_grow_config, 0);
}

struct ItemConfig * get_grow_item_config()
{
	return grow_item_list;
}

static void str_to_array(char * str, int arr[], unsigned n) 
{
	const char * temp = NULL;
	unsigned i = 0;

	temp = strtok(str, "|");
	while (temp != NULL && i < n) {
		arr[i++] = atoi(temp);
		temp = strtok(NULL, "|");
	}
}

static int parse_config_arguments_npc(struct config_arguments_npc * row) 
{
	struct ItemNpcFavorConfig * cfg = NULL;

	if (row->arguments_item_id == 0) {
		return 0;
	}

	cfg = (struct ItemNpcFavorConfig *) _agMap_ip_get(favor_item_map, row->arguments_item_id);
	if (cfg != NULL) {
		WRITE_ERROR_LOG("parse config_arguments_npc failed, %d is repeated.", row->arguments_item_id);
		return -1;
	}

	cfg = LOGIC_CONFIG_ALLOC(ItemNpcFavorConfig, 1); 
	memset(cfg, 0, sizeof(struct ItemNpcFavorConfig));

	cfg->id = row->arguments_item_id;
	cfg->npc_id = row->npc_id;

	size_t n = strlen(row->qinmi_max);
	char * degree_str = (char *) malloc(n + 1);
	strncpy(degree_str, row->qinmi_max, n);
	degree_str[n] = '\0';
	str_to_array(degree_str, cfg->degree, 6);
	free(degree_str);

	_agMap_ip_set(favor_item_map, cfg->id, cfg);

	return 0;
}

static int load_favor_item_config() 
{
	favor_item_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_arguments_npc(parse_config_arguments_npc, 0);
}

struct ItemNpcFavorConfig * get_favor_item_config(int id)
{
	return (struct ItemNpcFavorConfig *) _agMap_ip_get(favor_item_map, id);	
}

int load_item_config()
{
	if (load_item_base_config() != 0
		|| load_item_grow_config() != 0
		|| load_favor_item_config() != 0) {
		return -1;
	}
	return 0;
}


