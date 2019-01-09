#ifndef _A_GAME_MODULES_ITEM_H_
#define _A_GAME_MODULES_ITEM_H_

#include "player.h"
#include "data/Item.h"
#include "data/Compensate.h"
#include "logic/aL.h"

#if 0
typedef struct Item {
	struct Item * prev;
	struct Item * next;

	unsigned int playerid;
	unsigned int id;

	//int type;
	unsigned int limit;
} Item;
#endif

#define COIN_ID 90002

typedef struct Item Item;

typedef struct Compensate Compensate;

DECLARE_PLAYER_MODULE(item);

Item * item_get(Player * player, unsigned int id);
Item * item_next(Player * player, Item * item);

Item * item_add(Player * player, unsigned int id, unsigned int limit, int reason);
int    item_remove(Item * item, unsigned int limit, int reason);
int    item_use(Item * item, unsigned int count, int reason);
int    item_set(Player * player, unsigned int id, unsigned int limit, int reason);

int    item_set_limit(Item * item, unsigned int limit, int reason);
int    item_set_pos(Item * item, unsigned int pos);

Compensate * compen_item_next(Player *player, Compensate *cur);
int draw_item(Player *player, time_t time, struct DropInfo *drops, int size, int *real_size);

void compensate_all_item(Player* player);
int get_item_count_by_sub_type(Player * player, unsigned int sub_type);

#endif
