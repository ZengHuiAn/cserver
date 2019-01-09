#ifndef _SGK_FIRE_H_
#define _SGK_FIRE_H_ 

#include "player.h"
#include "data/Fire.h"

DECLARE_PLAYER_MODULE(fire);

int fire_set_max(Player * player, unsigned int max);
int fire_set_cur(Player * player, unsigned int cur);
amf_value * fire_build_message(struct Fire * pFire);

#define player_get_fire(player) (struct Fire*)player_get_module(player, PLAYER_MODULE_FIRE)

#endif
