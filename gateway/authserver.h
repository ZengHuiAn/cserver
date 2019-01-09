#ifndef _A_GAME_WORLD_AUTHSERVER_H_
#define _A_GAME_WORLD_AUTHSERVER_H_

#include "network.h"
#include "module.h"

DECLARE_MODULE(authserver)

int32_t authserver_auth(resid_t conn, const char* account, const char* token, struct network* net, const char* package_data, size_t package_len, unsigned int client_sn, unsigned int serverid);
void start_authserver(resid_t conn, void* ctx);

#endif
