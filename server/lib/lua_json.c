#include "cJSON.h"
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int luaopen_json(lua_State *L);

#ifdef __cplusplus
}
#endif

static void foreachJson(lua_State *L, cJSON * object)
{	
	cJSON *elem;
	int i = 1;
	cJSON_ArrayForEach(elem, object) {
		/* field */
		if (elem->string) {
			lua_pushstring(L, elem->string);
		}
		else {
			lua_pushnumber(L, i);
			i++;		
		}
		/* value */
		if (elem->type & cJSON_String) {
			lua_pushstring(L, elem->valuestring);
			lua_settable(L, -3);
		}
		else if (elem->type & cJSON_Number) {
			lua_pushnumber(L, elem->valuedouble);
			lua_settable(L, -3);
		}
		else if (elem->type & cJSON_NULL) {
			lua_pushnil(L);
			lua_settable(L, -3);
		}
		else if (elem->type & cJSON_True) {
			lua_pushboolean(L, 1);
			lua_settable(L, -3);	
		}
		else if (elem->type & cJSON_False) {	
			lua_pushboolean(L, 0);
			lua_settable(L, -3);
		}
		else if (elem->type & cJSON_Object || elem->type & cJSON_Array) {	
			lua_newtable(L);
			foreachJson(L, elem);	
			lua_settable(L, -3);
		}
	}
}


/* convert json string to table */
static int toTable(lua_State *L)
{
	size_t len;
	cJSON * obj;
	const char * str;
	char err[1024];	

	str = luaL_checklstring(L, -1, &len);
	obj = cJSON_Parse(str);
	if (0 == obj) {
		lua_pushnil(L);
		snprintf(err, sizeof(err), "parse json str error in %s.", cJSON_GetErrorPtr());
		lua_pushstring(L, err);
                return 2;
	}
	lua_newtable(L);
	/* foreach json object */
	foreachJson(L, obj);
	lua_pushnil(L);
	
	cJSON_Delete(obj);

	return 2;
}

int luaopen_json(lua_State *L)
{
	luaL_Reg reg[] = {
		{ "toTable", toTable },
		{ 0, 0 }
	};
	luaL_register(L, "json", reg);

	return 0;
}
