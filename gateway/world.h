#ifndef _A_GAME_GATEWAY_WORLD_H_
#define _A_GAME_GATEWAY_WORLD_H_

#include "module.h"

#define INVALID_WORLD_ID ((unsigned int)-1)

DECLARE_MODULE(world);

unsigned int world_get_idle_world(unsigned long long pid);
int world_is_valid(unsigned int world);

int world_increase_player(unsigned int world);
int world_reduce_player(unsigned int world);

int world_send_message(unsigned int world, unsigned long long playerid, unsigned int cmd, unsigned int flag, const void * msg, int len);

#endif
