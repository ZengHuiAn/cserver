#include <assert.h>

#include <sys/types.h>
#include <regex.h>

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#ifdef __cplusplus
}
#endif

static int l_regex_match(lua_State * L)
{
	size_t length;
	const char * string = luaL_checklstring(L, 1, &length);
	const char * pattern = luaL_checkstring(L, 2);


	regex_t reg;
	if (regcomp(&reg, pattern, 0) != 0) {
		lua_pushnil(L);
		lua_pushstring(L, "regcomp");
		return 2;
	}

	//size_t regerror(int errcode, const regex_t *restrict preg, char *restrict errbuf, size_t errbuf_size);
	size_t nmatch = 256;
	regmatch_t match[256];

	int ret = regexec(&reg, string, nmatch, match, 0);
	if (ret == REG_NOMATCH) {
		lua_pushboolean(L, 0);
		lua_pushstring(L, "no match");
	} else if (ret < 0) {
		lua_pushnil(L);
		lua_pushstring(L, "regexec");
	} else {
		lua_pushlstring(L, string + match[0].rm_so, match[0].rm_eo - match[0].rm_so);
		lua_newtable(L);
		int i;
		for (i = 1; match[i].rm_so != -1; i++) {
			lua_pushinteger(L, i);
			lua_pushlstring(L, string + match[i].rm_so, match[i].rm_eo - match[i].rm_so);
			lua_settable(L, -3);
		}
	}
	regfree(&reg);
	return 2;
}

int luaopen_regex(lua_State *L)
{
	luaL_Reg reg[] = {
		{"match", l_regex_match},
		{0,         0},
	};

	luaL_register(L,"regex", reg);
	return 0;
}
