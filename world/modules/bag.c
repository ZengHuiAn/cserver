#include <assert.h>
#include <string.h>
#include "bag.h"
#include "item.h"
#include "config/item.h"
#include "log.h"

int BAG_SLOT_MAX = 0;

void bag_init()
{
}

void * bag_new(Player * player)
{
	Bag * bag = (Bag*)malloc(sizeof(Bag) + sizeof(struct BagItem) * BAG_SLOT_MAX);
	memset(bag, 0, sizeof(Bag) + sizeof(struct BagItem) * BAG_SLOT_MAX);
	return bag;
}

int bag_set(Bag * bag, int index, enum BagItemType type, void * p);

void * bag_load(Player * player)
{
	unsigned long long playerid = player_get_id(player);

	Bag * bag = (Bag*)malloc(sizeof(Bag) + sizeof(struct BagItem) * BAG_SLOT_MAX);
	memset(bag, 0, sizeof(Bag) + sizeof(struct BagItem) * BAG_SLOT_MAX);

	Item * item = 0;
	while((item = item_next(player, item)) != 0) {
		if (item->limit == 0) {
			continue;
		} else if (item->pos >= (unsigned int)BAG_SLOT_MAX || bag_get(bag, item->pos) != 0) {
			int index = bag_push(bag, BAG_ITEM_ITEM, item);
			if (index < 0) {
				WRITE_DEBUG_LOG("player %llu bag is full", playerid);
				item_set_pos(item, -1);
			}
		} else {
			bag_set(bag, item->pos, BAG_ITEM_ITEM, item);
		}
	}
	return bag; 
}


int bag_update(Player * player, void * data, time_t now)
{
	return 0;
}

int bag_save(Player * player, void * data, const char * sql, ... )
{
	return 0;
}

int bag_release(Player * player, void * data)
{
	Bag * bag = (Bag *)data;
	if(bag) { free(bag); }
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
struct BagItem * bag_get(Bag * bag, int index)
{
	if (index < 0 || index >= BAG_SLOT_MAX) {
		return 0;
	}

	if (bag->items[index].type == BAG_ITEM_NULL) {
		return 0;
	}
	return bag->items + index;
}

static int set_bag_item_pos(enum BagItemType type, void * p, int pos)
{
	switch(type) {
		case BAG_ITEM_ITEM:
			return item_set_pos((Item*)p, pos);
		case BAG_ITEM_NULL:
			return 0;
		default:
			return -1;
	}
}

int bag_set(Bag * bag, int index, enum BagItemType type, void * p)
{
	bag->items[index].type = type;
	bag->items[index].ptr  = p;

	set_bag_item_pos(type, p, index);
	return 0;
}

int bag_push(Bag * bag, enum BagItemType type, void * p)
{
	int i, empty = -1;
	for(i = 0; i < BAG_SLOT_MAX; i++) {
		if (bag->items[i].ptr == p) {
			// 已经存在
			empty = i;
			break;
		}

		if (empty == -1 && bag->items[i].type == BAG_ITEM_NULL) {
			empty = i;
		}
	} 

	if (empty >= 0 && empty < BAG_SLOT_MAX) {
		bag->items[empty].type = type;
		bag->items[empty].ptr  = p;
		set_bag_item_pos(type, p, empty);
	}
	return empty;
}

int bag_remove(Bag * bag, int index)
{
	bag->items[index].type = BAG_ITEM_NULL ;
        bag->items[index].ptr  = 0;
	return 0;
}

int bag_exchange(Bag * bag, int index1, int index2)
{
	if (index1 < 0 || index1 >= BAG_SLOT_MAX 
			|| index2 < 0 || index2 >= BAG_SLOT_MAX) {
		return -1;
	}

	enum BagItemType t1 = bag->items[index1].type;
	enum BagItemType t2 = bag->items[index2].type;

	void * p1 = bag->items[index1].ptr;
	void * p2 = bag->items[index2].ptr;

	bag->items[index1].type = t2;
	bag->items[index1].ptr  = p2;

	set_bag_item_pos(t2, p2, index1);

	bag->items[index2].type = t1;
	bag->items[index2].ptr  = p1;

	set_bag_item_pos(t1, p1, index2);

	return 0;
}

unsigned int bag_get_capacity(Bag * bag)
{
	return BAG_SLOT_MAX;
}
