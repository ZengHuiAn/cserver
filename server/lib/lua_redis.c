#include <assert.h>

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int luaopen_redis(lua_State *L);

#ifdef __cplusplus
}
#endif

#include "hiredis.h"

static int l_redis_connect(lua_State * L)
{
	const char * host = luaL_checkstring(L, 1);
	int port = luaL_optinteger(L, 2, 6379);

	redisContext  * _db = redisConnect(host, port);
	if (_db == 0 || _db->err) {
		return 0;
	}
	lua_pushlightuserdata(L, _db);
	return 1;

}

static int l_redis_close(lua_State * L)
{
	if(!lua_islightuserdata(L, 1)) {
		return luaL_error(L, "redis.close require lightuserdata as param 1");
	}

	redisContext * db = (redisContext*)lua_touserdata(L, 1);
	redisFree(db);
	return 0;
}


static void pushReply(lua_State * L, redisReply * reply)
{
	switch(reply->type) {
		case REDIS_REPLY_STRING:  lua_pushstring(L, reply->str); break;
		case REDIS_REPLY_INTEGER: lua_pushinteger(L, reply->integer); break;
		case REDIS_REPLY_NIL:     lua_pushnil(L); break;
		case REDIS_REPLY_STATUS:  lua_pushinteger(L, reply->integer); break;
		case REDIS_REPLY_ARRAY:
			lua_newtable(L);
			{
				int i;
				for(i = 0; i < reply->elements; i++) {
					lua_pushinteger(L, i+1);
					pushReply(L, reply->element[i]);
					lua_settable(L, -3);
				}
			}
			break;
		default:
			assert(0);
	}
}

static int l_redis_command(lua_State * L)
{
	if(!lua_islightuserdata(L, 1)) {
		return luaL_error(L, "redis.command require db as param 1");
	}

	redisContext * db = (redisContext*)lua_touserdata(L, 1);
	const char * sql = luaL_checkstring(L, 2);
	
	redisReply * reply = (redisReply*)redisCommand(db, sql);
	if (reply == 0) {
		lua_pushnil(L);
		lua_pushstring(L, db->errstr);
		return 2;
	}

	if (reply->type == REDIS_REPLY_ERROR) {
		lua_pushboolean(L, 0);
		lua_pushstring(L, reply->str);
		freeReplyObject(reply);
		return 2;
	} 

	lua_pushboolean(L, 1);
	pushReply(L, reply);

	freeReplyObject(reply);

	return 2;
}

#define END "\r\n"
static void decode_single_line(const char * ptr, size_t len)
{
	//With a single line reply the first byte of the reply will be "+"
	while(len > 0) {
	}

}

static void decode_error_message_line()
{
	//With an error message the first byte of the reply will be "-"
}

static void decode_integer_number()
{
	//With an integer number the first byte of the reply will be ":"
}

static void decode_bulk()
{
	//With bulk reply the first byte of the reply will be "$"
}

static void decode_multi_bulk()
{
	//With multi-bulk reply the first byte of the reply will be "*"
}

static int l_redis_decode(lua_State * L)
{
	size_t len;
	const char * ptr = luaL_checklstring(L, 1, &len);

	return 0;
}


int luaopen_redis(lua_State *L)
{
	luaL_Reg reg[] = {
		{"connect", 	l_redis_connect},
		{"close", 	l_redis_close},
		{"command", 	l_redis_command},
		{"decode",	l_redis_decode},
		{0,         0},
	};

	luaL_register(L,"redis", reg);
	return 0;
}
