#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "WELLRNG512a.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

uint32_t WELLRNG512a(struct WELLRNG512aGenerator * generator)
{
	// WELL512 implementation by Chris Lomont (Game Programming Gems 7;
	// http://lomont.org/Math/Papers/2008/Lomont_PRNG_2008.pdf)
	uint32_t a, b, c, d;

	assert(generator->state[0] || generator->state[1]);

	a = generator->state[generator->index];
	c = generator->state[(generator->index + 13) & 15];
	b = a ^ c ^ (a << 16) ^ (c << 15);
	c = generator->state[(generator->index + 9) & 15];
	c ^= (c >> 11);
	a = generator->state[generator->index] = b ^ c;
	d = a ^ ((a << 5) & 0xDA442D24UL);
	generator->index = (generator->index + 15) & 15;
	a = generator->state[generator->index];
	generator->state[generator->index] = a ^ b ^ d ^ (a << 2) ^ (b << 18) ^ (c << 28);

	generator->count ++;

	return generator->state[generator->index];
}

void WELLRNG512a_seed(struct WELLRNG512aGenerator * generator, uint32_t value)
{
	uint32_t i;
	const uint32_t mask = ~0u;

	generator->index = 0;

	// Expand the seed with the same algorithm as boost::random::mersenne_twister
	generator->state[0] = value & mask;
	for (i = 1; i < 16; ++i)
		generator->state[i] = (1812433253UL * (generator->state[i - 1] ^ (generator->state[i - 1] >> 30)) + i) & mask;

	generator->count = 0;
}

void WELLRNG512a_seed16(struct WELLRNG512aGenerator * generator, uint32_t values[16])
{
	uint32_t i;
	generator->index = 0;
	for (i = 0; i < 16; ++i)
		generator->state[i] = values[i];

	generator->count = 0;
}

static int l_new(lua_State * L)
{
	uint32_t seed = luaL_checkinteger(L, 1);

	struct WELLRNG512aGenerator * generator = (struct WELLRNG512aGenerator *)lua_newuserdata(L, sizeof(struct WELLRNG512aGenerator));
	WELLRNG512a_seed(generator, seed);

	return 1;
}

static int l_value(lua_State * L)
{
	struct WELLRNG512aGenerator * generator = (struct WELLRNG512aGenerator *)lua_touserdata(L, 1);
	if (generator) {
		uint32_t value = WELLRNG512a(generator);
		lua_pushinteger(L, value);
		return 1;
	}
	return 0;
}

static luaL_Reg reg[] = {
	{"new",         l_new},
	{"value",       l_value},
	{0, 0},
};

#ifdef __cplusplus
extern "C" {
#endif

	static const char * LIB_NAME = "WELLRNG512a";

	LUALIB_API int luaopen_WELLRNG512a(lua_State *L)
	{
#if LUA_VERSION_NUM == 503
		luaL_newlib(L, reg);
		lua_setglobal(L, LIB_NAME);
		lua_getglobal(L, LIB_NAME);
#else
		luaL_register(L, LIB_NAME, reg);
#endif
		return 1;
	}

#ifdef __cplusplus
}
#endif
