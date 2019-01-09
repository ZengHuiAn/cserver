#ifndef _A_GAME_TIMELINE_H_
#define _A_GAME_TIMELINE_H_

#include "module.h"

DECLARE_MODULE(timeline)

time_t timeline_get(time_t base, unsigned int loop);
time_t timeline_get_sec(time_t now);
time_t timeline_get_day(time_t now);
time_t timeline_get_week(time_t now);

time_t get_open_server_time();

#define GET_DAY_BEGIN_TIME(x) \
    (x - (x + 8 * 3600) % 86400)

#endif
