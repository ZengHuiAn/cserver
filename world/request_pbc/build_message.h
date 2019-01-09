#ifndef _A_GAME_WORLD_REQUEST_PBC_BUILD_MESSAGE_H_
#define _A_GAME_WORLD_REQUEST_PBC_BUILD_MESSAGE_H_

#include "modules/property.h"

#ifdef __cplusplus
extern "C" {
#endif
#include "pbc.h"
#ifdef __cplusplus
}
#endif
#include "message.h"

struct pbc_wmessage * build_pbc_building_info_message(uint32_t sn, Player * player);

#endif
