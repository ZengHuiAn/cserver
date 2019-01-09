#include <string.h>

#include "log.h"

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int luaopen_report(lua_State *L);

#ifdef __cplusplus
}
#endif

#define LOG_PTR		"c_logger_ptr"
static time_t _t_last = 0;

static int lua_set_log(lua_State * L, struct logger * log, const char * name);
static struct logger * getLog(lua_State * L, const char * name, int createIfNotExist) {
	lua_getglobal(L, "report");
	lua_getfield(L, -1, name);
	struct logger * log = (struct logger*)lua_touserdata(L, -1);
	lua_pop(L, 2);
    if (log == 0 && createIfNotExist) {
       char fname[256] = {0};
       sprintf(fname, "%s_%%T.log", name);
       log = _agL_open(fname, LOG_INFO);
       lua_set_log(L, log, name);
    }
	return log;
}

static int l_write(lua_State * L) {
    const char * name = luaL_checkstring(L, 1);
    char message[4096] = {0};
	size_t offset = 0;
	int i, top = lua_gettop(L);
	for(i = 2; i <= top; i++) {
		offset += snprintf(message + offset, sizeof(message) - offset, "%s,", lua_tostring(L, i));
	}
	if (offset > 0) {
		struct logger * log = getLog(L, name, 1);
		if (log) {
			_agL_write(log, LOG_INFO, "%s", message);
            time_t now = time(0); 
            if(now - _t_last > 1){
                _agL_flush(log);
                _t_last = now;
            }
		} else {
			WRITE_INFO_LOG("%s", message);
		}
	}
	return 0;
}

int luaopen_report(lua_State *L) {

	luaL_Reg reg[] = {
		{"write" ,  l_write},
		{0,         0},
	};

	luaL_register(L,"report", reg);

	return 0;
}

static int lua_set_log(lua_State * L, struct logger * log, const char * name) {
	struct logger * old_log = getLog(L, name, 0);
	if (old_log) {
		_agL_close(old_log);
	}
	lua_getglobal(L, "report");
	if (log) {
		lua_pushlightuserdata(L, log);
	} else {
		lua_pushnil(L);
	}
	lua_setfield(L, -2, name);
	lua_pop(L, 1);
	return 0;
}
