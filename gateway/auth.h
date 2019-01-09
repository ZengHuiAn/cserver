#ifndef _A_GAME_GATEWAY_AUTH_H_
#define _A_GAME_GATEWAY_AUTH_H_

#include "network.h"

void start_auth(resid_t conn);
void remove_waiting(resid_t conn);
void respond_auth(resid_t conn, unsigned int sn, unsigned int result);
void respond_auth_fail_and_close(resid_t conn, unsigned int sn, unsigned int result);

#endif
