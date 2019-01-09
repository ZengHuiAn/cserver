#ifndef _A_GAME_WORLD_realtime_h_
#define _A_GAME_WORLD_realtime_h_

#include "module.h"

DECLARE_MODULE(realtime);

void realtime_online_add(unsigned long long id);
void realtime_online_remove(unsigned long long id);

void realtime_online_clean();
unsigned int realtime_online_count();

#endif
