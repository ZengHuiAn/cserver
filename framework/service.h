#ifndef _A_GAME_NETWORK_SERVICE_H_
#define _A_GAME_NETWORK_SERVICE_H_

#include <time.h>

#include "module.h"

int  service_init(int argc, char * argv[]);
int  service_reload();
void service_update(time_t now);
void service_unload();

#define SERVICE_BEGIN()  \
	struct module modules[] = {

#define SERVICE_END()  \
		{0, 0, 0, 0, 0} \
	};
#endif
