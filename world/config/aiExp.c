#include <stdlib.h>
#include <string.h>

#include "logic_config.h"
#include "xmlHelper.h"

#include "package.h"
#include "mtime.h"
#include "aiExp.h"
#include "map.h"

#include "config_type.h"

#include "db_config/TABLE_config_AI_extraEXP.h"
#include "db_config/TABLE_config_AI_extraEXP.LOADER.h"
#include "db_config/TABLE_config_AI_levellimit.h"
#include "db_config/TABLE_config_AI_levellimit.LOADER.h"

struct map * ai_exp_map = NULL;
struct map * ai_level_limit_map = NULL;
int max_day = 0;
static int parse_ai_exp_config(struct config_AI_extraEXP * row)
{
	struct AIExpConfig * pCfg = LOGIC_CONFIG_ALLOC(AIExpConfig, 1);
	memset(pCfg, 0, sizeof(AIExpConfig));

	pCfg->level       = row->level;
	pCfg->min_exp     = row->minEXP;
	pCfg->max_exp     = row->maxEXP;
	pCfg->min_star    = row->min_star_num;
	pCfg->max_star    = row->max_star_num;

	if (!ai_exp_map) ai_exp_map = LOGIC_CONFIG_NEW_MAP();
	if (_agMap_ip_set(ai_exp_map, pCfg->level, pCfg) != NULL) {
		WRITE_ERROR_LOG("duplicate ai exp level %d", pCfg->level);
		return -1;
	}

	return 0;
}

static int parse_ai_level_limit_config(struct config_AI_levellimit * row)
{
	struct AILevelLimitConfig * pCfg = LOGIC_CONFIG_ALLOC(AILevelLimitConfig, 1);
	memset(pCfg, 0, sizeof(AILevelLimitConfig));

	pCfg->day       	  = row->day;
	pCfg->limit_level     = row->levellimit;

	if (row->day > max_day) max_day = row->day;

	if (!ai_level_limit_map) ai_level_limit_map = LOGIC_CONFIG_NEW_MAP();
	if (_agMap_ip_set(ai_level_limit_map, pCfg->day, pCfg) != NULL) {
		WRITE_ERROR_LOG("duplicate ai level limit day %d", pCfg->day);
		return -1;
	}

	return 0;
}


static int load_exp_config()
{
	ai_exp_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_AI_extraEXP(parse_ai_exp_config, 0);
}

struct AIExpConfig * get_ai_exp_config(int level)
{
	return (struct AIExpConfig *)_agMap_ip_get(ai_exp_map, level);
}

static int load_level_limit_config()
{
	ai_level_limit_map = LOGIC_CONFIG_NEW_MAP();
	return  foreach_row_of_config_AI_levellimit(parse_ai_level_limit_config, 0);
}

struct AILevelLimitConfig * get_ai_level_limit_config(int day)
{
	day = day > max_day ? max_day : day;	
	return (struct AILevelLimitConfig *)_agMap_ip_get(ai_level_limit_map, day);
}

int load_ai_exp_config()
{
	if (load_exp_config() != 0 || load_level_limit_config() != 0) {
		return -1;
	}
	return 0;
}
