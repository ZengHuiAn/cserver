#ifndef _A_GAME_WORLD_CONFIG_GENERAL_H_
#define _A_GAME_WORLD_CONFIG_GENERAL_H_

struct GeneralConfig {
	int enable_reward_from_client;
};


int load_general_config();

struct GeneralConfig *  get_general_config();

struct CreatePlayerItem {
	struct CreatePlayerItem * next;
	int type;
	int id;
	int value;
	int pos;
};

struct CreatePlayerItem * get_create_player_item();

#endif
