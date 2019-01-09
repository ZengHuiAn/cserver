#ifndef _A_GAME_WORLD_CHANNEL_H_
#define _A_GAME_WORLD_CHANNEL_H_

#include "module.h"

DECLARE_MODULE(channel)

int    channel_record(unsigned int channel, const char * account, const char * ip);
void   channel_release(unsigned int channel);
void * channel_read(unsigned int channel, char *  ip);

#endif
