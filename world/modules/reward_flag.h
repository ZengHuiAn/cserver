#ifndef _A_GAME_MODULES_REWARDFLAG_H_
#define _A_GAME_MODULES_REWARDFLAG_H_

#include "player.h"
#include "data/RewardFlag.h"

typedef struct RewardFlag RewardFlag;

DECLARE_PLAYER_MODULE(reward_flag);

RewardFlag * reward_flag_next(Player * player, RewardFlag * reward_flag);

int reward_flag_get(Player * player, unsigned int id);
int reward_flag_set(Player * player, unsigned int id);

#endif
