#include "config_type.h"
#include "compensate.h"
#include "map.h"
#include "logic_config.h"
#include "log.h"
#include "../db_config/TABLE_config_delay_exp.h"
#include "../db_config/TABLE_config_delay_exp.LOADER.h"

static struct map * _map = NULL;
static struct CompensateCfg * cfg_list = NULL;

static int parse_compensate_cfg(struct config_delay_exp *row)
{
	struct CompensateCfg *cfg;
	struct array *arr;

	if (NULL == row) {
		WRITE_ERROR_LOG("%s: row is NULL.", __FUNCTION__);
		return -1;
	}
	
	arr = (struct array *)_agMap_ip_get(_map, row->count_id);		
	if (NULL == arr) {
		arr = array_new(256);
		_agMap_ip_set(_map, row->count_id, arr);
	}
	
	cfg = LOGIC_CONFIG_ALLOC(CompensateCfg, 1);
	memset(cfg, 0, sizeof(struct CompensateCfg));
	
	cfg->id = row->count_id;
	cfg->num = row->reduce_num;
	cfg->min_level = row->minlevel;
	cfg->max_level = row->maxlevel;
	cfg->drop1 = row->drop1;
	cfg->drop2 = row->drop2;
	cfg->drop3 = row->drop3;
	cfg->next = NULL;
	
	array_push(arr, cfg);

	if (NULL == cfg_list) {
		cfg_list = cfg;
		cfg_list->next = NULL;
	}
	else {
		cfg->next = cfg_list;
		cfg_list = cfg;
	}

	return 0;
}

int load_compensate_config()
{	
	_map = LOGIC_CONFIG_NEW_MAP();
	
	if (NULL == _map) {
		WRITE_ERROR_LOG("%s: malloc failed.", __FUNCTION__);
		return -1; 
	}	

	return foreach_row_of_config_delay_exp(parse_compensate_cfg, 0);
}

CompensateCfg * get_compensate_cfg(int id, int level)
{
	struct array *a;
	struct CompensateCfg *cfg;
	size_t i;

	a = (struct array *)_agMap_ip_get(_map, id);
	if (NULL == a) {
		return NULL;
	}

	for (i = 0; i < array_count(a); i++) {
		cfg = (struct CompensateCfg *) array_get(a, i);
		if (cfg && level >= cfg->min_level && level <= cfg->max_level) {
			return cfg;
		}
	} 

	return NULL;
}

CompensateCfg * compensate_next(CompensateCfg *cfg)
{
	if (NULL == cfg) {
		return cfg_list; 
	} else {
		return cfg->next;
	}
}
