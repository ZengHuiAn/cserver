#ifndef _A_GAME_GATEWAY_TRANSLATE_H_
#define _A_GAME_GATEWAY_TRANSLATE_H_

#include "network.h"
#include "client.h"

#include "package.h"

void start_translate(resid_t conn, client* c, struct network* net, void* package_data, size_t package_len);
//void translate_to_client(struct translate_header * header);

#endif
