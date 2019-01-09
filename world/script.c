#include <assert.h>

#include "script.h"
#include "log.h"
#include "player.h"

//#include "scripts/player.h"
//#include "scripts/resources.h"
/*
#include "scripts/property.h"
#include "scripts/building.h"
#include "scripts/technology.h"
#include "scripts/city.h"
#include "scripts/hero.h"
#include "scripts/item.h"
#include "scripts/cooldown.h"
#include "scripts/farm.h"
#include "scripts/equip.h"
#include "scripts/story.h"
#include "scripts/daily.h"
#include "scripts/strategy.h"
#include "scripts/compose.h"
*/


static void push_amf(lua_State * L, amf_value * v)
{
	switch(amf_type(v)) {
		case amf_integer:
			lua_pushinteger(L, amf_get_integer(v));
			break;
		case amf_undefine:
		case amf_null:
			lua_pushnil(L);
			break;
		case amf_false:
			lua_pushboolean(L, 0);
			break;
		case amf_true:
			lua_pushboolean(L, 1);
			break;
		case amf_double:
			lua_pushnumber(L, amf_get_double(v));
			break;
		case amf_string:
			{
				const char * s = amf_get_string(v);
				lua_pushlstring(L, s, amf_size(v));
			}
			break;
		case amf_array:
			{
				lua_newtable (L);
				size_t i;
				for(i = 0; i < amf_size(v); i++) {
					lua_pushinteger(L, i+1);
					push_amf(L, amf_get(v, i));
					lua_settable(L, -3);
				}
			}
			break;
		default:
			assert(0 && "error amf type");
			break;
	}
}



#define IMPORT_SCRIPT_MODULE(m) \
	{ #m, script_register_##m }

struct ScriptModule {
	const char * name;
	int (*_register)(lua_State * L);
} script_modules[] = {
	//IMPORT_SCRIPT_MODULE(player),
	//IMPORT_SCRIPT_MODULE(resources),
/*
	IMPORT_SCRIPT_MODULE(property),
	IMPORT_SCRIPT_MODULE(building),
	IMPORT_SCRIPT_MODULE(technology),
	IMPORT_SCRIPT_MODULE(city),
	IMPORT_SCRIPT_MODULE(hero),
	IMPORT_SCRIPT_MODULE(item),
	IMPORT_SCRIPT_MODULE(cooldown),
	IMPORT_SCRIPT_MODULE(farm),
	IMPORT_SCRIPT_MODULE(equip),
	IMPORT_SCRIPT_MODULE(story),
	IMPORT_SCRIPT_MODULE(daily),
	IMPORT_SCRIPT_MODULE(strategy),
	IMPORT_SCRIPT_MODULE(compose),
*/
	{0},
};


static lua_State * L = 0;

int module_script_load(int argc, char * argv[])
{
	return module_script_reload();
}

int module_script_reload()
{
	if (L) lua_close(L);

	L = luaL_newstate();
	if (L == 0) {
		WRITE_ERROR_LOG("luaL_newstate failed");		
		return -1;
	}
	luaL_openlibs(L);

	int i;
	for(i = 0; script_modules[i].name; i++) {
		if (script_modules[i]._register(L) != 0) {
			WRITE_ERROR_LOG("register script %s failed",
					script_modules[i].name);
			return -1;	
		}
	}

	if (luaL_dofile(L, "../script/loader.lua") != 0) {
		WRITE_ERROR_LOG("run test.lua failed: %s", lua_tostring(L, -1));
		return -1;
	}
	return 0;
}

void module_script_update(time_t now)
{
}

void module_script_unload()
{
	if (L) lua_close(L);
	L = 0;
}

int script_test()
{
	if (luaL_dofile(L, "./test.lua") != 0) {
		WRITE_ERROR_LOG("run test.lua failed: %s", lua_tostring(L, -1));
		return -1;
	}
	return 0;
}

#define RELOAD_SCRIPT

int script_run(const char * func, amf_value * v, ...)
{
#ifdef RELOAD_SCRIPT
	if (L) {
		lua_close(L);
	}

	module_script_load(0, 0);
#endif
	lua_getglobal(L, func);
	if (lua_type(L, -1) != LUA_TFUNCTION) {
		return -1;
	}

	size_t pc = 0;
	va_list args;
	va_start(args, v);
	while(v) {
		pc ++;
		push_amf(L, v);
		v = va_arg(args, amf_value *);
	}
	va_end(args);

	if(lua_pcall (L, pc, 1, 0) != 0) {
		WRITE_ERROR_LOG("run do_command failed: %s",
				lua_tostring(L, -1));
		return -1;
	}

	if (lua_isnil(L, -1)) {
		return 0;
	}

	int ret = lua_tointeger(L, -1);
	lua_pop(L, 1);
	return ret;
}
