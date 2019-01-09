#include "fashion.h"
#include "string.h"
#include "map.h"
#include "log.h"
#include "config_type.h"
#include "logic_config.h"
#include "../db_config/TABLE_config_fashion.h"
#include "../db_config/TABLE_config_fashion.LOADER.h"

static struct map * fashion_map;

static int parse_fashion_config(struct config_fashion * row)
{
	Fashion *cfg, *cur;

	cur = LOGIC_CONFIG_ALLOC(Fashion, 1);
	memset(cur, 0, sizeof(Fashion));
	cur->role_id = row->role_id;
	cur->fashion_id = row->fashion_id;
	cur->effect_type = row->effect_type;
	cur->effect_value = row->effect_value;
	cur->item = row->is_get;
	cur->next = NULL;

	cfg = (Fashion *) _agMap_ip_get(fashion_map, row->role_id);
	if (cfg) {
		cur->next = cfg;
		cfg = cur;
	} 
	else {
		cfg = cur;
	}
	_agMap_ip_set(fashion_map, cfg->role_id, cfg);

	return 0;
}

Fashion * get_fashion_cfgs(int role_id)
{
	return (Fashion *) _agMap_ip_get(fashion_map, role_id);
}

Fashion * get_fashion_cfg(int role_id, int fashion_id)
{
	Fashion *cfg;

	cfg = (Fashion *) _agMap_ip_get(fashion_map, role_id);
	while (cfg) {
		if (cfg->fashion_id != fashion_id) {
			cfg = cfg->next;
		}
		else {
			return cfg;
		}
	}

	return NULL;
}

Fashion * get_fashion_by_item(int role_id, int item_id)
{
	Fashion *cfg;

	cfg = (Fashion *) _agMap_ip_get(fashion_map, role_id);
	while (cfg) {
		if (cfg->item != item_id) {
			cfg = cfg->next;
		}
		else {
			return cfg;
		}
	}

	return NULL;
}

int load_fashion_config()
{
	if (fashion_map == NULL) {
		fashion_map = LOGIC_CONFIG_NEW_MAP();
	}

	if (foreach_row_of_config_fashion(parse_fashion_config, 0) != 0) {
		return -1;
	}

	return 0;
}
