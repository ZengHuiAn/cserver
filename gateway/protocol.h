#ifndef _A_GAME_WORLD_protocol_h_
#define _A_GAME_WORLD_protocol_h_

#include "module.h"

#ifdef __cplusplus
extern "C" {
#endif
#include "pbc.h"
#ifdef __cplusplus
}
#endif


DECLARE_MODULE(protocol);

struct pbc_wmessage * protocol_new_w(const char * name);
struct pbc_rmessage * protocol_new_r(const char * name, const char * ptr, size_t len);

#endif
