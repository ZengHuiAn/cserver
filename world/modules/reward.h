#ifndef _A_GAME_MODUELS_REWARD_H_
#define _A_GAME_MODUELS_REWARD_H_

#include "player.h"
#include "data/Reward.h"
#include "data/RewardContent.h"

DECLARE_PLAYER_MODULE(reward);

struct RewardItem {
	int type;
	int id;
	int value;
	unsigned long long uuid;
};

typedef struct Reward Reward;
typedef struct RewardContent RewardContent;

Reward * reward_next(Player * player, Reward * reward);
Reward * reward_get(Player * player, unsigned int reason);

// 检查定时奖励
int reward_check_type_0(Player * player);
// 检查全员奖励
int reward_to_all_check(Player * player);

int reward_remove(Reward * reward, Player * player);
RewardContent * reward_get_content(Reward * reward);
int             reward_receive(Reward * reward, Player * player, struct RewardContent * content, size_t n);

Reward *        reward_create(unsigned int reason, unsigned int limit, unsigned int manual, const char * name);
RewardContent * reward_add_content(Reward * reward, unsigned long long hero_uuid, unsigned int type, unsigned int key, unsigned int value);
int             reward_commit(Reward * reward, unsigned long long pid, struct RewardItem * record, int nitem);
int             reward_rollback(Reward * reward);

int reward_can_add_reward(struct Player * player, struct RewardContent * reward);
int reward_add_one(struct Player * player, struct RewardContent * content, int reason, struct RewardItem * record, int nitem);

#endif
