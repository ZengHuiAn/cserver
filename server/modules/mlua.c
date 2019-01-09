#include <unistd.h>

#include "mlua.h"
#include "config.h"
#include "network.h"
#include "log.h"
#include "time.h"

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int luaopen_loop(lua_State * L);
int luaopen_network(lua_State * L);
int luaopen_log(lua_State * L);

#ifdef __cplusplus
}
#endif

struct Script {
	lua_State * L;
	lua_State * coroutine;
	struct Script * next;
	char file[256];
	char load[256];
	char update[256];
	char unload[256];
	struct logger * log;
};

static struct Script * script_list = 0;

static int loadScript(xml_node_t * node, void * data)
{
	const char * file = xmlGetValue(node, 0);

	struct Script * script = (struct Script*)malloc(sizeof(struct Script));
	memset(script, 0, sizeof(struct Script));

	script->L = luaL_newstate();
	script->coroutine = 0;
	luaL_openlibs(script->L);
	luaopen_loop(script->L);
	luaopen_network(script->L);
	luaopen_log(script->L);

	script->log = 0;

	const char * cpath = xmlGetAttribute(node, "cpath", 0);
	if (cpath) {
		char trunk[1024] = {0};
		sprintf(trunk, "package.cpath=package.cpath .. \";%s\"", cpath);
		if (luaL_dostring(script->L, trunk) != 0) {
			return -1;
		}
	}

	const char * path  = xmlGetAttribute(node, "path", 0);
	if (path) {
		char trunk[1024] = {0};
		sprintf(trunk, "package.path=package.path .. \";%s\"", path);
		if (luaL_dostring(script->L, trunk) != 0) {
			return -1;
		}
	}
	
	strcpy(script->file, file);

	if (luaL_dofile(script->L, script->file) != 0) {
		WRITE_ERROR_LOG("%s", lua_tostring(script->L, -1));
		return -1;
	}

#define READ_ATTRIBUTE(x) \
	do { \
		const char * x = xmlGetAttribute(node, #x, 0); \
		if (x) strcpy(script->x, x); \
	} while(0)

	READ_ATTRIBUTE(load);
	READ_ATTRIBUTE(update);
	READ_ATTRIBUTE(unload);

	script->next = 0;

	if (script_list == 0) {
		script_list = script;
	} else {
		struct Script * ite = script_list;
		while(ite->next) {
			ite = ite->next;
		}
		ite->next = script;
	}
	return 0;
}

int lua_set_log(lua_State * L, struct logger * log);

int module_lua_load(int argc, char * argv[])
{
       srand(time(0));


	agN_init(2000);

#if 1
	int i;
	for(i = 1; i < argc; i++) {
		const char * file = argv[i];

		if (file[0] == '-') {
			if (file[1] == 'c') {
				i++;
			}

			if (strcmp(file+1, "sid") == 0) {
				i++;
			}
			continue;
		}

		struct Script * script = (struct Script*)malloc(sizeof(struct Script));
		memset(script, 0, sizeof(struct Script));

		script->L = luaL_newstate();
		luaL_openlibs(script->L);
		luaopen_loop(script->L);
		luaopen_network(script->L);
		luaopen_log(script->L);

		strcpy(script->file, file);

		char logname[256];
		size_t offset = sprintf(logname, xmlGetValue(agC_get("Log", "FileDir", 0), "../log"));

		strcat(logname, "/");
		offset += 1;

		size_t len = strlen(file);
		if (len > 4 && strcmp(file + len - 4, ".lua") == 0) {
			strncpy(logname + offset, file, len - 4);
			logname[offset + len - 4] = 0;
		} else {
			strncpy(logname + offset, file, sizeof(logname) - offset);
		}
		strcat(logname, "_%T.log");

		script->log = _agL_open(logname, LOG_DEBUG);
		lua_set_log(script->L, script->log);

#if 0
		lua_State * coroutine = lua_newthread(script->L);
		luaL_loadfile(coroutine, script->file);
		if (lua_resume(coroutine, 0) == LUA_YIELD) {
			script->coroutine = coroutine;
		}
#else
		lua_pushlightuserdata(script->L, script->L);
		lua_setglobal(script->L, "c_main_state");

		if (luaL_dofile(script->L, script->file) != 0) {
			_agL_write(script->log, LOG_ERROR, "%s", lua_tostring(script->L, -1));
			lua_pop(script->L, 1);
			return -1;
		}
#endif

		strcpy(script->load, "onLoad"); 
		strcpy(script->update, "onUpdate"); 
		strcpy(script->unload, "onUnload"); 
		script->next = 0;

		if (script_list == 0) {
			script_list = script;
		} else {
			struct Script * ite = script_list;
			while(ite->next) {
				ite = ite->next;
			}
			ite->next = script;
		}
	}
	((void)loadScript);
#else
	xml_node_t * node = agC_get("Scripts", 0);

	if (foreachChildNodeWithName(node, "Script", loadScript, 0) != 0) {
		return -1;
	}
#endif

	struct Script * ite = script_list;
	for(ite = script_list; ite ; ite = ite->next) {
		if (ite->load[0] == 0) {
			continue;
		}

		lua_getglobal(ite->L, ite->load);
		if (!lua_isfunction(ite->L, -1)) {
			_agL_write(ite->log, LOG_DEBUG, "script %s is not function", ite->load);
			lua_pop(ite->L, 1);
			ite->load[0] = 0;
		} else {
			if(lua_pcall (ite->L, 0, 0, 0) != 0) {
				_agL_write(ite->log, LOG_ERROR, "%s", lua_tostring(ite->L, -1));
				lua_pop(ite->L, 1);
				return -1;
			}
		}
	}
	return 0;
}

int module_lua_reload()
{
	struct Script * ite = script_list;
	for(ite = script_list; ite ; ite = ite->next) {
		if (ite->load[0] == 0) {
			continue;
		}

		lua_getglobal(ite->L, "onReload");
		if (!lua_isfunction(ite->L, -1)) {
			_agL_write(ite->log, LOG_DEBUG, "script onReload is not function");
			lua_pop(ite->L, 1);
			ite->load[0] = 0;
		} else {
			if(lua_pcall (ite->L, 0, 0, 0) != 0) {
				_agL_write(ite->log, LOG_ERROR,"%s", lua_tostring(ite->L, -1));
				lua_pop(ite->L, 1);
				return -1;
			}
		}
	}
	return 0;

}

void module_lua_update(time_t now)
{
	struct Script * ite = script_list;
	for(ite = script_list; ite ; ite = ite->next) {
		if (ite->log) {
			_agL_flush(ite->log);
		}
	
		if (ite->update[0] == 0) {
			continue;
		}

		lua_State * L = ite->L; //lua_newthread(ite->L);
		lua_getglobal(L, ite->update);
		if (!lua_isfunction(L, -1)) {
			lua_pop(L, 1);
			_agL_write(ite->log, LOG_DEBUG, "script %s is not function", ite->update);
			ite->update[0] = 0;
		} else {
			lua_pushinteger(L, now);
			if (lua_pcall(L, 1, 0, 0) != 0) {
				_agL_write(ite->log, LOG_ERROR, "%s", lua_tostring(L, -1));
				lua_pop(L, 1);
			} 
		}
	}
}

void module_lua_unload()
{
	while(script_list) {
		struct Script * ite = script_list;
		script_list = ite->next;

		if (ite->unload[0] != 0) {
			lua_getglobal(ite->L, ite->unload);

			if (!lua_isfunction(ite->L, -1)) {
				lua_pop(ite->L, 1);
				_agL_write(ite->log, LOG_DEBUG, "script %s is not function", ite->unload);
			} else {
				if(lua_pcall (ite->L, 0, 0, 0) != 0) {
					const char * errinfo = lua_tostring(ite->L, -1);
					printf("%s\n", errinfo);
					_agL_write(ite->log, LOG_ERROR, "%s", errinfo);
					lua_pop(ite->L, 1);
				}
			}
		}

		if (ite->log) {
			_agL_close(ite->log);
		}

		free(ite);
	}
}

void lua_exec(lua_State* L, const char* szScript){
	if(L && szScript){
		int top =lua_gettop(L);
		if(0!=luaL_dostring(L, szScript)){
			puts(lua_tostring(L, -1));
		}
		lua_settop(L, top);
	}
}
