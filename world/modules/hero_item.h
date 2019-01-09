#ifndef _SGK_HERO_ITEM_H_
#define _SGK_HERO_ITEM_H_ 

#include "player.h"
#include "data/HeroItem.h"

DECLARE_PLAYER_MODULE(hero_item);


#define HERO_ITEM_ID_TALENT_POINT 1
#define HERO_ITEM_ID_SKILL_TREE_POINT 2
#define HERO_ITEM_ID_TITILE_1_POINT 3
#define HERO_ITEM_ID_TITILE_2_POINT 4

struct HeroItem * hero_item_next(struct Player * player, struct HeroItem * hero);
int hero_item_count(Player * player, unsigned long long uuid, int id);
int hero_item_set(Player * player, unsigned long long uuid, int id, int value, int reason, int status);
int hero_item_add(Player * player, unsigned long long uuid, int id, int value, int reason, int status);
int hero_item_remove(Player * player, unsigned long long uuid, int id, int value, int reason);
struct HeroItem * hero_item_get(Player * player, unsigned long long uuid, int id);

#endif
