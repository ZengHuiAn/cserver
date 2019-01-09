#include <string.h>
#include "openlv.h"
#include "logic_config.h"
#include "../db_config/TABLE_config_openlev.h"
#include "../db_config/TABLE_config_openlev.LOADER.h"
#include "map.h"
#include "log.h"

static struct map * _openlev_map = NULL;

static int parse_openlev_config(struct config_openlev * row)
{
	if (_agMap_ip_get(_openlev_map, row->id) != 0) {
		WRITE_ERROR_LOG("id %d of config_openlev duplicate", row->id);
		return -1;
	}
	OpenLevCofig * cfg = LOGIC_CONFIG_ALLOC(OpenLevCofig, 1);
	memset(cfg, 0, sizeof(OpenLevCofig));
	cfg->id = row->id;
	cfg->open_lev = row->open_lev;

	cfg->condition.type  = row->event_type1;
	cfg->condition.id    = row->event_id1;
	cfg->condition.count = row->event_count1;

	_agMap_ip_set(_openlev_map, cfg->id, cfg);

	return 0;
}

OpenLevCofig * get_openlev_config(int id)
{
	return (OpenLevCofig *)_agMap_ip_get(_openlev_map, id);
}

int load_openlev_config()
{
	_openlev_map = LOGIC_CONFIG_NEW_MAP();
	int ret = foreach_row_of_config_openlev(parse_openlev_config, 0);

	return ret;
}
