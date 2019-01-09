#include "network.h"
#include "mtime.h"

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int luaopen_loop(lua_State *L);

static int l_exit(lua_State * L)
{
	agN_stop();
	return 0;
}

static int l_now(lua_State * L)
{
	lua_pushinteger(L, agT_current());
	return 1;
}
	
int luaopen_loop(lua_State *L)
{
	luaL_Reg reg[] = {
		{"exit" ,   l_exit},
		{"now" ,    l_now},
		{0,         0},
	};

	luaL_register(L,"loop", reg);
	return 0;
}

#ifdef __cplusplus
}
#endif
