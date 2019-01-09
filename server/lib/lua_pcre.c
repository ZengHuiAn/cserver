#include <assert.h>

#include <pcre.h>

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#ifdef __cplusplus
}
#endif

static int l_pcre_match(lua_State * L)
{
	size_t length;
	const char * string = luaL_checklstring(L, 1, &length);
	const char * pattern = luaL_checkstring(L, 2);

	int ovector[256] = {0};;

	const char *error;
	int   erroffset;
	pcre * code = pcre_compile(pattern,       /* the pattern */
			0,                    /* default options */
			&error,               /* for error message */
			&erroffset,           /* for error offset */
			0);                   /* use default character tables */

	char info[1024];
	if (!code) {
		lua_pushnil(L);
		sprintf(info, "pcre_compile failed (offset: %d), %s\n", erroffset, error);
		lua_pushstring(L, info);
		return 2;
	}

	int rc = pcre_exec (
			code,                   /* the compiled pattern */
			0,                    /* no extra data - pattern was not studied */
			string,                  /* the string to match */
			length,          /* the length of the string */
			0,                    /* start at offset 0 in the subject */
			0,                    /* default options */
			ovector,              /* output vector for substring information */
			256);           /* number of elements in the output vector */

	if (rc < 0) {
		switch (rc) {
			case PCRE_ERROR_NOMATCH:
				lua_pushboolean(L, 0);
				lua_pushstring(L, "no match");
				break;
			default:
				lua_pushnil(L);
				sprintf(info, "Error while matching: %d\n", rc);
				lua_pushstring(L, info);
				break;
		}
	} else {
		lua_pushlstring(L, string + ovector[0], ovector[1] - ovector[0]);
		lua_newtable(L);
		int i;
		for (i = 1; i < rc; i++) {
			lua_pushinteger(L, i);
			lua_pushlstring(L, string + ovector[2*i], ovector[2*i+1] - ovector[2*i]);
			lua_settable(L, -3);
		}
	}
	free(code);
	return 2;
}

int luaopen_pcre(lua_State *L)
{
	luaL_Reg reg[] = {
		{"match", l_pcre_match},
		{0,         0},
	};

	luaL_register(L,"pcre", reg);
	return 0;
}
