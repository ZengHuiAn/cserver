#include <assert.h>

#include "sqlite3.h"

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#ifdef __cplusplus
}
#endif

static int l_sqlite_open(lua_State * L)
{
	const char * file = luaL_checkstring(L, 1);

	sqlite3 * db = 0;
	int ret = sqlite3_open(file, &db);
	if (ret == SQLITE_OK) {
		lua_pushlightuserdata(L, db);
		return 1;
	}
	if (db) {
		lua_pushnil(L);
		lua_pushstring(L, sqlite3_errmsg(db));
		sqlite3_close(db);
		return 2;
	}
	return 0;
}

static int l_sqlite_close(lua_State * L)
{
	sqlite3 * db = lua_touserdata(L, 1);

	if (db) {
		sqlite3_close(db);
	}
	return 0;
}


int cb(void*data,int c,char** cp1,char** cp2)  /* Callback function */
{
	return 0;
}

static int l_sqlite_command(lua_State * L)
{
	sqlite3 * db = lua_touserdata(L, 1);
	size_t len;
	const char * sql = luaL_checklstring(L, 2, &len);

	
	sqlite3_stmt * stmt = 0;
	int ret = sqlite3_prepare(db, sql, len, &stmt, 0);
	if (ret != SQLITE_OK) {
		assert(stmt == 0);
		lua_pushboolean(L, 0);
		lua_pushstring(L, sqlite3_errmsg(db));
		return 2;
	}

	lua_pushboolean(L, 1);

	lua_newtable(L);
	int row = 0;
	while (1) {
		int s = sqlite3_step (stmt);
		if (s == SQLITE_ROW) {
			row ++;
			lua_pushinteger(L, row);
			lua_newtable(L);
			{
				int column = sqlite3_column_count(stmt);
				int i;
				for (i = 0; i < column; i++) {
					const char * key = sqlite3_column_name(stmt, i);
					lua_pushstring(L, key);
					switch(sqlite3_column_type(stmt, i)) {
						case SQLITE_INTEGER:
							{
								sqlite3_int64 v = sqlite3_column_int64(stmt, i);
								if ((v >> 32) == 0) {
									lua_pushinteger(L, (int)(v & 0xffffffff));
								} else {
									lua_pushnumber(L, v);
								}
							}
							break;
						case SQLITE_FLOAT:
							lua_pushnumber(L, sqlite3_column_double(stmt, i));
							break;
						case SQLITE_TEXT:
							lua_pushstring(L, sqlite3_column_text(stmt, i));
							break;
						case SQLITE_BLOB:
							lua_pushlstring(L, sqlite3_column_blob(stmt, i), sqlite3_column_bytes(stmt, i));
							break;
						case SQLITE_NULL:
							lua_pushnil(L);
							break;
						default:
							assert(0);
							lua_pushnil(L);
					}
					lua_settable(L, -3);
				}
			}
			lua_settable(L, -3);
		} else if (s == SQLITE_DONE) {
			break;
		} else {
			lua_pop(L, 2);
			lua_pushboolean(L, 0);
			lua_pushstring(L, sqlite3_errmsg(db));
			break;
		}
	}
	sqlite3_finalize(stmt);
	return 2;
}

int luaopen_sqlite(lua_State *L)
{
	luaL_Reg reg[] = {
		{"open", 	l_sqlite_open},
		{"close", 	l_sqlite_close},
		{"command", 	l_sqlite_command},
		{0,         0},
	};

	luaL_register(L,"sqlite", reg);
	return 0;
}
