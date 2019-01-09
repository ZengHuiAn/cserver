#ifndef _A_GAME_WORLD_SCRIPT_H_
#define _A_GAME_WORLD_SCRIPT_H_

#include "module.h"

#ifdef __cplusplus
extern "C" {
#endif
	#include "lua.h"
	#include "lualib.h"
	#include "lauxlib.h"
#ifdef __cplusplus
}
#endif

#include "amf.h"


/*
   typedef struct luaL_Reg {
   const char *name;
   lua_CFunction func;
   } luaL_Reg;
 */

#define DECLARE_SCRIPT_MODULE(m) \
	int script_register_##m(lua_State * L);

//MODULE_BEGIN(script)
DECLARE_MODULE(script)

int script_run(const char * func, amf_value * v, ...);

int script_test();

#endif
