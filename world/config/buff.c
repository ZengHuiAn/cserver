#include <stdlib.h>
#include <string.h>
#include "xmlHelper.h"
#include "logic_config.h"
#include "hero.h"
#include "map.h"
#include "array.h"
#include "package.h"
#include "equip.h"
#include "buff.h"


#include "config_type.h"

#include "../db_config/TABLE_config_buff.h"
#include "../db_config/TABLE_config_buff.LOADER.h"

static struct map * buff_config = NULL;

static int parse_buff_config(struct config_buff * row)
{
	int buff_id = row->buff_id;
	if (buff_id <= 0) {
		WRITE_ERROR_LOG("buff config buff_id(%d) <= 0", buff_id);
		return -1;
	}

	struct BuffConfig * pCfg = LOGIC_CONFIG_ALLOC(BuffConfig, 1);
	memset(pCfg, 0, sizeof(BuffConfig));

/*
	if (row->duration == 0 && row->end_time == 0) {
		WRITE_WARNING_LOG("buff config %d, both duration and end_time are 0", pCfg->buff_id);
		return -1;
	}
*/

	pCfg->buff_id           = buff_id;
	pCfg->group             = row->group;
	pCfg->type              = row->type;
	pCfg->value             = row->value;
	pCfg->duration          = row->duration;
	pCfg->hero_id           = row->hero_id;
	pCfg->end_time          = row->end_time;

	if (_agMap_ip_set(buff_config, pCfg->buff_id, pCfg)  != 0) {
		WRITE_WARNING_LOG("duplicate buff config %d", pCfg->buff_id);
		return -1;
	}

	return 0;
}

int load_buff_config()
{
	buff_config = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_buff(parse_buff_config, 0);
}

struct BuffConfig * get_buff_config(int buff_id)
{
	return (struct BuffConfig *)_agMap_ip_get(buff_config, buff_id);
}
