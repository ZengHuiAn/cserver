#ifndef _A_GAME_WORLD_BACKEND_H_
#define _A_GAME_WORLD_BACKEND_H_


#include "network.h"
#include "module.h"

struct Backend; 

#define MAX_BACK_END	30

//MODULE_BEGIN(chat)
DECLARE_MODULE(backend)

struct Backend * backend_get(unsigned long long pid, unsigned int cmd);

int backend_send(struct Backend * peer, unsigned long long channel,
		unsigned int cmd,
		unsigned int flag, const void * msg, size_t len);

int backend_broadcast(unsigned long long channel, unsigned int cmd,
		unsigned int flag, const void * msg, size_t len);


struct Backend * backend_next(struct Backend * ite) ;
int backend_avalible(struct Backend *);
int backend_get_id(struct Backend *);
const char * backend_get_name(struct Backend *);

#endif
