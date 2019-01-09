#ifndef _A_GAME_WORLD_addicted_h_
#define _A_GAME_WORLD_addicted_h_

#include "module.h"
#include "player.h"

DECLARE_MODULE(addicted);

void addicted_login(unsigned long long id);
void addicted_logout(unsigned long long id);

void addicted_set_adult(unsigned long long id);
void addicted_set_minority(unsigned long long id);

int addicted_can_login(unsigned long long id);

void addicted_notify(Player * player);


int addicted_is_young_player(unsigned long long id);

#endif
