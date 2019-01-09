#ifndef _A_GAME_COMM_MODULES_TIME_H_
#define _A_GAME_COMM_MODULES_TIME_H_

#include "module.h"

DECLARE_MODULE(time);

time_t agT_current();

int agT_delay(time_t t, void(*cb)(time_t, void*), void * data);

#endif
