#ifndef _A_GAME_PBC_LUA_H_
#define _A_GAME_PBC_LUA_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "pbc.h"
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
//#include "luajit.h"


int luaopen_protobuf_c(lua_State *L);

#ifdef __cplusplus
}
#endif


#endif
