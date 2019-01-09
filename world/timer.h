#ifndef _A_GAME_WORLD_timer_h_
#define _A_GAME_WORLD_timer_h_

#include "module.h"

DECLARE_MODULE(timer);

struct Timer;

typedef void (*TimerCallBack)(time_t now, void * data);

int timer_max_sec();

struct Timer * timer_add(time_t at, TimerCallBack cb, void * data);
void           timer_remove(struct Timer * timer);

#endif
