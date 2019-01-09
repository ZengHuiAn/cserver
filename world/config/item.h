#ifndef _A_GAME_WORLD_CONFIG_ITEM_H_
#define _A_GAME_WORLD_CONFIG_ITEM_H_

#include <time.h>

int load_item_config();

struct ItemGrowInfo {
	struct ItemGrowInfo * next;

	time_t begin_time;
	time_t end_time;
	int    period;

	int    amount;
	int    limit;
	int    is_reset;
};

struct ItemConfig
{
	struct ItemConfig * grow_next;


    int id;
    int type;
    int compose_num;

	struct ItemGrowInfo * grow;
};

struct ItemNpcFavorConfig
{
	int id;
	int npc_id;
	int degree[6];
};

struct ItemConfig * get_item_base_config(int id);

struct ItemConfig * get_grow_item_config();

struct ItemNpcFavorConfig * get_favor_item_config(int id);

#endif
