#include <string.h>
#include "common.h"
#include "logic_config.h"
#include "package.h"
#include "../db_config/TABLE_config_common.h"
#include "../db_config/TABLE_config_common.LOADER.h"
#include "../db_config/TABLE_config_common_consume.h"
#include "../db_config/TABLE_config_common_consume.LOADER.h"
#include "map.h"
#include "log.h"

static struct map * _common_map = 0;
static struct map * _consume_map = 0;

static int parse_common_config(struct config_common * row)
{
	if (_agMap_ip_get(_common_map, row->id) != 0) {
		WRITE_ERROR_LOG("id %d of config_common duplicate", row->id);
		return -1;
	}
	struct CommonCfg * cfg = LOGIC_CONFIG_ALLOC(CommonCfg, 1);
	memset(cfg, 0, sizeof(struct CommonCfg));
	cfg->id = row->id;
	cfg->para1 = row->para1;
	cfg->para2 = row->para2;

	_agMap_ip_set(_common_map, cfg->id, cfg);

	return 0;
}

static int parse_consume_config(struct config_common_consume * row) 
{
	if (_agMap_ip_get(_consume_map, row->id) != 0) {
		WRITE_ERROR_LOG("id %d of config_common_consume duplicate", row->id);	
		return -1;
	}
	struct ConsumeCfg * cfg = LOGIC_CONFIG_ALLOC(ConsumeCfg, 1);
	memset(cfg, 0, sizeof(struct ConsumeCfg));
	cfg->id = row->id;
	cfg->item_type = row->type;
	cfg->item_id = row->item_id;
	cfg->item_value = row->item_value;
	
	_agMap_ip_set(_consume_map, cfg->id, cfg);

	return 0;
}

int load_common_config()
{
	_common_map = LOGIC_CONFIG_NEW_MAP();
	int ret1 = foreach_row_of_config_common(parse_common_config, 0);	
	_consume_map = LOGIC_CONFIG_NEW_MAP();
	int ret2 = foreach_row_of_config_common_consume(parse_consume_config, 0);
		
	if (ret1 != 0 || ret2 != 0) {
		return -1;
	}
	else{
		return 0;
	}
}

struct CommonCfg * get_common_config(int id)
{
	return (struct CommonCfg *)_agMap_ip_get(_common_map, id);
}

struct ConsumeCfg * get_consume_config(int id)
{
	return (struct ConsumeCfg *)_agMap_ip_get(_consume_map, id);	
}
