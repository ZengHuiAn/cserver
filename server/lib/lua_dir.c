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

int luaopen_dir(lua_State *L);

#ifdef __cplusplus
}
#endif

static int l_dir_list(lua_State * L)
{
	const char * path = luaL_checkstring(L, 1);
	DIR * dir = opendir(path);
	if (dir == 0) {
		return 0;
	}

	lua_newtable(L);
	int c = 0;
	struct dirent * dent = 0;
	while((dent = readdir(dir)) != 0) {
		if (strcmp(dent->d_name, ".") == 0) {
			continue;
		} else if (strcmp(dent->d_name, "..") == 0) {
			continue;
		}
		lua_pushinteger(L, ++c);
		lua_pushstring(L, dent->d_name);
		lua_settable(L, -3);
	}
	closedir(dir);
	return 1;
}

static int l_dir_isdir(lua_State * L)
{
	const char * path = luaL_checkstring(L, 1);
	struct stat fstat;
	if (lstat(path, &fstat) != 0) {
		return 0;
	}

	lua_pushboolean(L, fstat.st_mode & S_IFDIR);
	return 1;
}

int luaopen_dir(lua_State *L)
{
	luaL_Reg reg[] = {
		{"list", l_dir_list},
		{"isdir", l_dir_isdir},
		{0,	0},
	};
	luaL_register(L,"dir", reg);
	return 0;
}
