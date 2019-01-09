#include <assert.h>
#include <dirent.h>
#include <sys/stat.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int luaopen_mfile(lua_State *L);

#ifdef __cplusplus
}
#endif

#include "mfile.h"

static int l_mfile_write(lua_State * L)
{
	// ref
	unsigned int ref = luaL_checkinteger(L, 1);
	// code
	size_t len = 0;
	const char * code = luaL_checklstring(L, 2, &len);
	// prefix
	const char * prefix = luaL_optstring(L, 3, 0);
	
	unsigned int ret = mfile_write(ref, code, len, prefix);
	if (ret == -1)  {
		return 0;
	}
	assert(ret == ref);
	lua_pushboolean(L, 1);
	return 1;
}

static int l_mfile_read(lua_State * L)
{
	// ref
	unsigned int ref = luaL_checkinteger(L, 1);

	// prefix
	const char * prefix = luaL_optstring(L, 2, 0);

	size_t len = 1024;
	while(1) {
		char buff[len];

		int rlen = mfile_read(ref, buff, sizeof(buff), prefix);
		if (rlen < 0) {
			// error
			return 0;
		}

		if (rlen <= len) {
			lua_pushlstring(L, buff, rlen);
			return 1;
		}
		len = rlen;
	}
}

int luaopen_mfile(lua_State *L)
{
	luaL_Reg reg[] = {
		{"write", l_mfile_write},
		{"read",  l_mfile_read},
		{0,	0},
	};
	luaL_register(L,"mfile", reg);
	return 0;
}
