#include <stdlib.h>
#include <string.h>
#include "xmlHelper.h"
#include "logic_config.h"
#include "hero.h"
#include "map.h"
#include "array.h"
#include "package.h"
#include "rankreward.h"
#include "dlist.h"


#include "config_type.h"

#include "../db_config/TABLE_config_rank_reward.h"
#include "../db_config/TABLE_config_rank_reward.LOADER.h"

static struct map * first_week_daily_rank_reward_map = NULL;
static struct map * normal_daily_rank_reward_map = NULL;
static struct map * first_week_weekly_rank_reward_map = NULL;
static struct map * normal_weekly_rank_reward_map = NULL;

static int parse_rank_reward_config(struct config_rank_reward * row)
{
	int rank_type = row->rank_type;
	if (rank_type < 0 || rank_type > MAX_RANK_TYPE) {
		WRITE_ERROR_LOG("rank_type %d too small or too big", rank_type);
		return -1;
	}

	struct RankRewardConfig * pCfg = LOGIC_CONFIG_ALLOC(RankRewardConfig, 1);
	memset(pCfg, 0, sizeof(struct RankRewardConfig));

	pCfg->rank_type = rank_type;
	pCfg->rank_lower = row->rank_lower;
	pCfg->rank_upper = row->rank_upper;
	pCfg->first_week_reward = row->first_week_reward;
	pCfg->week_reward = row->week_reward;
	pCfg->type = row->reward_type;
	pCfg->id = row->reward_id;
	pCfg->value = row->reward_value;

	dlist_init(pCfg);
	if (pCfg->first_week_reward && !pCfg->week_reward) {
		struct RankRewardConfig * head = (struct RankRewardConfig *)_agMap_ip_get(first_week_daily_rank_reward_map, pCfg->rank_type);
		if (!head) _agMap_ip_set(first_week_daily_rank_reward_map, pCfg->rank_type, pCfg);
		dlist_insert_tail(head, pCfg);
	} else if (!pCfg->first_week_reward && !pCfg->week_reward) {
		struct RankRewardConfig * head = (struct RankRewardConfig *)_agMap_ip_get(normal_daily_rank_reward_map, pCfg->rank_type);
		if (!head) _agMap_ip_set(normal_daily_rank_reward_map, pCfg->rank_type, pCfg);
		dlist_insert_tail(head, pCfg);
	} else if (pCfg->first_week_reward && pCfg->week_reward) {
		struct RankRewardConfig * head = (struct RankRewardConfig *)_agMap_ip_get(first_week_weekly_rank_reward_map, pCfg->rank_type);
		if (!head) _agMap_ip_set(first_week_weekly_rank_reward_map, pCfg->rank_type, pCfg);
		dlist_insert_tail(head, pCfg);
	} else if (!pCfg->first_week_reward && pCfg->week_reward) {
		struct RankRewardConfig * head = (struct RankRewardConfig *)_agMap_ip_get(normal_weekly_rank_reward_map, pCfg->rank_type);
		if (!head) _agMap_ip_set(normal_weekly_rank_reward_map, pCfg->rank_type, pCfg);
		dlist_insert_tail(head, pCfg);
	}

	return 0;
}

static int load_rank_reward_config()
{
	first_week_daily_rank_reward_map = LOGIC_CONFIG_NEW_MAP();
	normal_daily_rank_reward_map = LOGIC_CONFIG_NEW_MAP();
	first_week_weekly_rank_reward_map = LOGIC_CONFIG_NEW_MAP();
	normal_weekly_rank_reward_map = LOGIC_CONFIG_NEW_MAP();
	return foreach_row_of_config_rank_reward(parse_rank_reward_config, 0);
}

struct RankRewardConfig * get_rank_reward_config(int rank_type, int rank, int first_week, int weekly)
{
	struct RankRewardConfig * head = NULL;
	if (first_week && !weekly) {
		head = (struct RankRewardConfig *)_agMap_ip_get(first_week_daily_rank_reward_map, rank_type);
	} else if (!first_week && !weekly) {
		head = (struct RankRewardConfig *)_agMap_ip_get(normal_daily_rank_reward_map, rank_type);
	} else if (first_week && weekly) {
		head = (struct RankRewardConfig *)_agMap_ip_get(first_week_weekly_rank_reward_map, rank_type);
	} else if (!first_week && weekly) {
		head = (struct RankRewardConfig *)_agMap_ip_get(normal_weekly_rank_reward_map, rank_type);
	}
	
	if (!head) {
		return 0;
	}

	struct RankRewardConfig * ite = 0;
	while((ite = dlist_next(head, ite)) != 0) {
		if (rank >= ite->rank_lower && rank <= ite->rank_upper) {
			return ite;
		}
	}

	return 0;
}

int load_rankreward_config()
{
	if (load_rank_reward_config() != 0)
	{
		return -1;
	}
	return 0;
}
