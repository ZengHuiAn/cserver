#include <assert.h>
#include <stdlib.h>
#include <mysql.h>

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#ifdef __cplusplus
}
#endif

static int l_mysql_open(lua_State * L)
{
	const char * host = luaL_checkstring(L, 1);
	const char * user = luaL_checkstring(L, 2);
	const char * passwd = luaL_optstring(L, 3, 0);
	const char * db = luaL_optstring(L, 4, 0);
	unsigned int port = luaL_optinteger(L, 5, 3306);
	const char * socket = luaL_optstring(L, 6, 0);

	MYSQL * mysql = mysql_init(0);

	if (mysql_real_connect(mysql, host, user, passwd, db, port, socket, 0) == 0) {
		lua_pushnil(L);
		lua_pushstring(L, mysql_error(mysql));
		mysql_close(mysql);
		return 2;
	}

	lua_pushlightuserdata(L, mysql);
	return 1;
}

static int l_mysql_close(lua_State * L)
{
	MYSQL * db = (MYSQL*)lua_touserdata(L, 1);
	if (db) {
		mysql_close(db);
	}
	return 0;
}

static int l_mysql_command(lua_State * L)
{
	MYSQL * mysql = (MYSQL*)lua_touserdata(L, 1);
	size_t len;
	const char * sql = luaL_checklstring(L, 2, &len);

	
	if (mysql_real_query(mysql, sql, len) != 0) {
		lua_pushboolean(L, 0);
		lua_pushstring(L, mysql_error(mysql));
		return 2;
	}


	MYSQL_RES * result = mysql_store_result(mysql);
	if (result) {
		unsigned int num_fields = mysql_num_fields(result);
		// retrieve rows, then call mysql_free_result(result)

		MYSQL_FIELD * fields = mysql_fetch_fields(result);
		lua_pushboolean(L, 1);
		lua_newtable(L);
		{
			int count = 1;
			MYSQL_ROW row; 
			while ((row = mysql_fetch_row(result)))
			{
				lua_pushinteger(L, count++);
				lua_newtable(L);
				{
					unsigned long *lengths;
					lengths = mysql_fetch_lengths(result);

				
					int i;
					for(i = 0; i < num_fields; i++)
					{
						if (row[i]) {
							lua_pushstring(L, fields[i].name);
							switch(fields[i].type) {
								case MYSQL_TYPE_TINY:
								case MYSQL_TYPE_SHORT:
								case MYSQL_TYPE_LONG:
								case MYSQL_TYPE_INT24:
									lua_pushinteger(L, atoll(row[i]));
									break;
								case MYSQL_TYPE_FLOAT:
								case MYSQL_TYPE_DOUBLE:
								case MYSQL_TYPE_DECIMAL:
									{
										double d = atof(row[i]);
										lua_pushnumber(L, d);
									}
									break;
								case MYSQL_TYPE_LONGLONG:
								{
									double d = atof(row[i]);
									lua_pushnumber(L, d);
								}
								break;
								case MYSQL_TYPE_NULL:
								case MYSQL_TYPE_TIMESTAMP:
								case MYSQL_TYPE_DATE:
								case MYSQL_TYPE_TIME:
								case MYSQL_TYPE_DATETIME:
								case MYSQL_TYPE_YEAR:
								case MYSQL_TYPE_NEWDATE:
								case MYSQL_TYPE_VARCHAR:
								case MYSQL_TYPE_BIT:
								case MYSQL_TYPE_NEWDECIMAL:
								case MYSQL_TYPE_ENUM:
								case MYSQL_TYPE_SET:
								case MYSQL_TYPE_TINY_BLOB:
								case MYSQL_TYPE_MEDIUM_BLOB:
								case MYSQL_TYPE_LONG_BLOB:
								case MYSQL_TYPE_BLOB:
								case MYSQL_TYPE_VAR_STRING:
								case MYSQL_TYPE_STRING:
								case MYSQL_TYPE_GEOMETRY:
								default:
									lua_pushlstring(L, row[i], lengths[i]);
									break;
							}
							lua_settable(L, -3);
						} 
					}
				}
				lua_settable(L, -3);
			}
		}
		mysql_free_result(result);
		return 2;
	} else  {
		// mysql_store_result() returned nothing; should it have?
		if(mysql_field_count(mysql) == 0) {
			// query does not return data
			// (it was not a SELECT)
			unsigned int num_rows = mysql_affected_rows(mysql);
			lua_pushboolean(L, 1);
			lua_newtable(L);
			{
			}
			return 2;
		} else {
			// mysql_store_result() should have returned data
			lua_pushboolean(L, 0);
			lua_pushstring(L, mysql_error(mysql));
			return 2;
		}
	}
}

int l_mysql_error(lua_State * L)
{
	MYSQL * mysql = (MYSQL*)lua_touserdata(L, 1);

	lua_pushstring(L, mysql_error(mysql));
	return 1;
}

int l_mysql_errno(lua_State * L)
{
	MYSQL * mysql = (MYSQL*)lua_touserdata(L, 1);
	lua_pushinteger(L, mysql_errno(mysql));
	return 1;
}

int l_mysql_last_id(lua_State * L)
{
	MYSQL * mysql = (MYSQL*)lua_touserdata(L, 1);
	lua_pushinteger(L, mysql_insert_id(mysql));
	return 1;
}

int luaopen_mysql(lua_State *L)
{
	luaL_Reg reg[] = {
		{"open", 	l_mysql_open},
		{"close", 	l_mysql_close},
		{"command", 	l_mysql_command},
		{"error",	l_mysql_error},
		{"errno",	l_mysql_errno},
		{"last_id",	l_mysql_last_id}, 
		{0,         0},
	};

	luaL_register(L,"mysql", reg);
	return 0;
}
