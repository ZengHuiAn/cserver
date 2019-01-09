#ifndef _A_GAME_MODULES_PROPERTY_H_
#define _A_GAME_MODULES_PROPERTY_H_

#include "player.h"
#include "data/Property.h"

DECLARE_PLAYER_MODULE(property)

#define PLAYER_RETURN_STATUS_VALID  1
#define PLAYER_RETURN_STATUS_REWARD 2
/*
#define PROPERTY_BUILDING_GUANFU_LEVEL	0
#define PROPERTY_BUILDING_JIUGUAN_LEVEL	1
*/
typedef struct Property Property;

int property_add_exp(Player * player, int exp);
int property_set_exp(Player * player, unsigned int exp);
int add_property_notify(Player * player);
amf_value* get_property_as_amf_value(Player* player);
int property_init_skill(Player * player);
int property_set_skill(Player * player, int32_t skillid[5]);
int property_set_nick_name(Player* player, const char* name);
void property_set_military_power_dirty(Player* player);
int64_t property_get_military_power(Player* player, const int32_t factor);

int property_set_return_7_time(Player * player, time_t t);


int property_change_nick(Player* player, const char * nick);
int property_change_head(Player* player, int head);

int property_set_title(Player * player, int title);
int property_change_total_star(Player * player, int total_star);
int property_change_max_floor(Player * player, int floor);

#endif
