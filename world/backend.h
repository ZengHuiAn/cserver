#ifndef _A_GAME_WORLD_BACKEND_H_
#define _A_GAME_WORLD_BACKEND_H_


#include "network.h"
#include "module.h"

struct Backend; 

DECLARE_MODULE(backend)

void backend_connect(const char * name);

struct Backend * backend_get(const char * name, unsigned long long pid);

int backend_send(struct Backend * peer, unsigned long long channel,
		unsigned int cmd,
		unsigned int flag, const void * msg, size_t len);

int backend_send_pbc(struct Backend * peer,
		unsigned long long channel, unsigned int cmd,
		struct pbc_wmessage * msg);

int backend_avalible(struct Backend *);
int backend_get_id(struct Backend *);
const char * backend_get_name(struct Backend *);

struct Backend * backend_new(const char * name, int id, const char * host, int port, int timeout);

#endif
