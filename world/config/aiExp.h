#ifndef _A_GAME_WORLD_CONFIG_AIEXP_H_
#define _A_GAME_WORLD_CONFIG_AIEXP_H_

#include <time.h>

int load_ai_exp_config();

struct AIExpConfig {
	int level;
	int min_exp;
	int max_exp;
	int min_star;
	int max_star;
};

struct AILevelLimitConfig {
	int day;
	int limit_level;	
};

struct AIExpConfig * get_ai_exp_config(int level);
struct AILevelLimitConfig * get_ai_level_limit_config(int day);

#endif
