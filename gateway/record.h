#ifndef _A_GAME_GATEWAY_RECORD_H_
#define _A_GAME_GATEWAY_RECORD_H_

#include <stdlib.h>

#include "module.h"

DECLARE_MODULE(record)

void record(unsigned int id, const char * msg, size_t len);

#endif
