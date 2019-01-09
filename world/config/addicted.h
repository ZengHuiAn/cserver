#ifndef _A_GAME_WORLD_CONFIG_ADDICTED_H_
#define _A_GAME_WORLD_CONFIG_ADDICTED_H_

typedef struct AddictedConfig {
	unsigned int enable;
	unsigned int kickTime;
	unsigned int notifyTime;
	unsigned int restTime;
	char notifyMessage[256];
} AddictedConfig;

int load_addicted_config();

AddictedConfig * get_addicted_config();

#endif
