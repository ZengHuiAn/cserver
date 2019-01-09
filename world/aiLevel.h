#ifndef _A_GAME_AI_LEVEL_h_
#define _A_GAME_AI_LEVEL_h_

#include "module.h"

DECLARE_MODULE(aiLevel);

typedef struct aiLevel {
	struct aiLevel * prev;
	struct aiLevel * next;

	unsigned long long pid;
	int level;
} AILevel;

typedef struct playerLevel {
	unsigned long long pid;
	int level;
	int idx;
} PlayerLevel;

void onLevelChange(unsigned long long pid, int new_level);
AILevel * aiLevel_next(AILevel * iter, int level);
unsigned long long GetAIModePID(int level);

#endif
