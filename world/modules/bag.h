#ifndef _A_GAME_MODULES_BAG_H_
#define _A_GAME_MODULES_BAG_H_

#include "player.h"

// extern int BAG_SLOT_MAX;

typedef struct Bag Bag;

DECLARE_PLAYER_MODULE(bag);

enum BagItemType {
	BAG_ITEM_NULL = 0,
	BAG_ITEM_EQUIP,
	BAG_ITEM_ITEM,
	BAG_ITEM_GEM,
};

struct BagItem {
	enum BagItemType type;
	void * ptr;
};

struct Bag {
	struct BagItem items[0];
};

#define player_get_bag(player) ((Bag*)player_get_module(player, PLAYER_MODULE_BAG))

struct BagItem * bag_get(Bag * bag, int index);
int bag_set(Bag * bag, int index, enum BagItemType, void * p);
int bag_push(Bag * bag, enum BagItemType, void * p);
int bag_exchange(Bag * bag, int index1, int index2);
int bag_remove(Bag * bag, int index);

unsigned int bag_get_capacity(Bag * bag);

#endif
