#ifndef _A_GAME_MODULES_DAILY_H_
#define _A_GAME_MODULES_DAILY_H_

#include "player.h"
#include "data/DailyData.h"

DECLARE_PLAYER_MODULE(daily)


//declare all daily data id
#define DAILY_ITEM_ONLINE 1
#define DAILY_DAILY_TICK  2
//
//
//

#if 0
typedef struct DailyData {
	struct DailyData * prev;
	struct DailyData * next;

	unsigned long long pid;
	unsigned int id;

	unsigned int update_time;
	unsigned int value;
	unsigned int total;
} DailyData;
#endif
typedef struct DailyData DailyData;

DailyData * daily_add(Player * player, unsigned int id);
DailyData * daily_get(Player * player, unsigned int id);
DailyData * daily_next(Player * player, DailyData * daily);

int daily_set(DailyData * daily, unsigned int value);

DailyData * daily_get_raw(Player * player, unsigned int id);
DailyData * daily_next_raw(Player * player, DailyData * daily);


unsigned int daily_get_online_time(Player * player);
void daily_update_online_time(Player * player, time_t now, int force);

int daily_get_value(Player * player, unsigned int id);
void daily_set_value(Player * player, unsigned int id, int value);
void daily_add_value(Player * player, unsigned int id, int value);

int daily_set(DailyData * daily, unsigned int value);



//unsigned int get_daily_value_of_strategy(Player * player);

#endif
