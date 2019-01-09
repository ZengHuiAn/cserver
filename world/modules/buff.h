#ifndef _A_GAME_MODULES_BUFF_H_
#define _A_GAME_MODULES_BUFF_H_

#include "player.h"
#include "data/Buff.h"

typedef struct Buff Buff;

// #define MAX_BUFF_EFFECT_COUNT 64

DECLARE_PLAYER_MODULE(buff);

Buff * buff_get(Player * player, unsigned int id);
Buff * buff_next(Player * player, Buff * buff);

Buff * buff_add(unsigned long long pid, unsigned int id, int value, time_t end_time);
int buff_remove(unsigned long long pid, unsigned int id, int value);

#endif
