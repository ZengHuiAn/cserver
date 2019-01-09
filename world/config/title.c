#include <stdlib.h>
#include <string.h>
#include "xmlHelper.h"
#include "logic_config.h"
#include "hero.h"
#include "map.h"
#include "array.h"
#include "package.h"
#include "dlist.h"
#include "title.h"


#include "config_type.h"

#include "../db_config/TABLE_config_honor_condition.h"
#include "../db_config/TABLE_config_honor_condition.LOADER.h"

static struct map * title_map = NULL;
static struct TitleConfig * head = NULL;
static int parse_title(struct config_honor_condition * row) 
{
	int id = row->gid;
	if (id <= 0) {
		WRITE_ERROR_LOG("parse title config fail, id %d <= 0;", id);
		return -1;
	}

	struct TitleConfig * pCfg = LOGIC_CONFIG_ALLOC(TitleConfig, 1);
	memset(pCfg, 0, sizeof(struct TitleConfig));

	dlist_init(pCfg);

	pCfg->id                = id;
	pCfg->type              = row->type;
	pCfg->condition1        = row->condition1;
	pCfg->condition2        = row->condition2;
	pCfg->condition3        = row->condition3;
	pCfg->being_icon        = row->being_icon;

	if ((struct TitleConfig *)_agMap_ip_get(title_map, pCfg->id) != 0) 
	{
		WRITE_ERROR_LOG("parse title config fail , duplicate id");
		return -1;
	}

	dlist_insert_tail(head, pCfg);
	_agMap_ip_set(title_map, pCfg->id, pCfg);

	return 0;
}

static int load_title()
{
	title_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_honor_condition(parse_title, 0);
}

struct TitleConfig * get_title_config(int id)
{
	struct TitleConfig * pCfg = (struct TitleConfig *)_agMap_ip_get(title_map, id);
	return pCfg;
}

struct TitleConfig * title_config_next(TitleConfig * cfg)
{
	return dlist_next(head, cfg);	
}

int load_title_config()
{
	if (load_title() != 0)
	{
		return -1;
	}

	return 0;
}
