#include <assert.h>

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int luaopen_bit32(lua_State *L);

#ifdef __cplusplus
}
#endif

static int l_bit32_and(lua_State * L)
{
	int top = lua_gettop(L);

	unsigned int v = 0xffffffff;

	int i;
	for (i = 1; i <= top; i++) {
		unsigned int c = luaL_checkinteger(L, i);
		v = v & c;
	}

	if (top == 0) {
		lua_pushinteger(L, 0);
	} else {
		lua_pushinteger(L, v);
	}
	return 1;
}

static int l_bit32_or(lua_State * L)
{
	int top = lua_gettop(L);
	unsigned int v = 0;
	int i;
	for (i = 1; i <= top; i++) {
		unsigned int c = luaL_checkinteger(L, i);
		v = v | c;
	}
	lua_pushinteger(L, v);
	return 1;
}
static int l_bit32_lshift(lua_State* L){
	int top = lua_gettop(L);
	if(top < 2){
		lua_pushstring(L, "invalid args, when call l_bit32_lshift");
		lua_error(L);
		return 0;
	}
	unsigned int src=luaL_checkinteger(L, 1);
	unsigned int n  =luaL_checkinteger(L, 2);
	lua_pushinteger(L, src << n);
	return 1;
}
static int l_bit32_rshift(lua_State* L){
	int top = lua_gettop(L);
	if(top < 2){
		lua_pushstring(L, "invalid args, when call l_bit32_rshift");
		lua_error(L);
		return 0;
	}
	unsigned int src=luaL_checkinteger(L, 1);
	unsigned int n  =luaL_checkinteger(L, 2);
	lua_pushinteger(L, src >> n);
	return 1;
}
static int l_bit32_negate(lua_State* L){
	int top = lua_gettop(L);
	if(top < 1){
		lua_pushstring(L, "invalid args, when call l_bit32_negate");
		lua_error(L);
		return 0;
	}
	unsigned int src=luaL_checkinteger(L, 1);
	unsigned int dst =~src;
	lua_pushinteger(L, dst);
	return 1;
}

static int l_bit32_lshift_long(lua_State* L){
	int top = lua_gettop(L);
	if(top < 2){
		lua_pushstring(L, "invalid args, when call l_bit32_lshift");
		lua_error(L);
		return 0;
	}
	double src = luaL_checknumber(L, 1);
	double n   = luaL_checknumber(L, 2);
	lua_pushnumber(L, (unsigned long long)src << (unsigned long long)n);
	return 1;
}
static int l_bit32_rshift_long(lua_State* L){
	int top = lua_gettop(L);
	if(top < 2){
		lua_pushstring(L, "invalid args, when call l_bit32_rshift");
		lua_error(L);
		return 0;
	}
	double src = luaL_checknumber(L, 1);
	double n   = luaL_checknumber(L, 2);
	lua_pushnumber(L, (unsigned long long)src >> (unsigned long long)n);
	return 1;
}

int luaopen_bit32(lua_State *L)
{
	luaL_Reg reg[] = {
		{"band", l_bit32_and},
		{"bor",  l_bit32_or},
		{"lshift",  l_bit32_lshift},
		{"rshift",  l_bit32_rshift},
		{"negate",  l_bit32_negate},
        {"lshift_long",  l_bit32_lshift_long},
        {"rshift_long",  l_bit32_rshift_long},
		{0,	0},
	};
	luaL_register(L,"bit32", reg);
	return 0;
}
