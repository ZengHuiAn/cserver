#ifndef _A_GAME_WORLD_CONFIG_STAR_H_
#define _A_GAME_WORLD_CONFIG_STAR_H_

#include <stdint.h>

/* macro */
#define YQ_BATTLE_REWARD_COUNT 3
#define YQ_BATTLE_REWARD_ITEM_COUNT 5

/* loader */
struct tagREWARD_ITEM{
	int32_t type;
	int32_t id;
	int32_t value;
};

typedef struct tagSTAR_REWARD_CONFIG{
	int32_t battle_id;
	struct tagREWARD_ITEM reward_item[YQ_BATTLE_REWARD_COUNT*YQ_BATTLE_REWARD_ITEM_COUNT];
}STAR_REWARD_CONFIG, *PSTAR_REWARD_CONFIG;
int load_star_reward_config();
PSTAR_REWARD_CONFIG get_star_reward_config_by_battle_id(uint32_t battle_id);

#endif
