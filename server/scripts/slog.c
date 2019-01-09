#include <string.h>

#include "log.h"

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int luaopen_log(lua_State *L);

#ifdef __cplusplus
}
#endif

#define LOG_PTR		"c_logger_ptr"

static struct logger * getLog(lua_State * L)
{
	lua_getglobal(L, "log");
	lua_getfield(L, -1, LOG_PTR);
	struct logger * log = (struct logger*)lua_touserdata(L, -1);
	lua_pop(L, 2);
	return log;
}

static int l_log_debug(lua_State * L)
{
	char message[4096] = {0};
	size_t offset = 0;

	int i, top = lua_gettop(L);
	for(i = 1; i <= top; i++) {
		offset += snprintf(message + offset, sizeof(message) - offset, "%s\t", lua_tostring(L, i));
	}

	if (offset > 0) {
		struct logger * log = getLog(L);
		if (log) {
			_agL_write(log, LOG_DEBUG, "%s", message);
		} else {
			WRITE_DEBUG_LOG("%s", message);
		}
	}
	return 0;
}

static int l_log_info(lua_State * L)
{

	char message[4096] = {0};
	size_t offset = 0;
	int i, top = lua_gettop(L);
	for(i = 1; i <= top; i++) {
		offset += snprintf(message + offset, sizeof(message) - offset, "%s\t", lua_tostring(L, i));
	}

	if (offset > 0) {
		struct logger * log = getLog(L);
		if (log) {
			_agL_write(log, LOG_INFO, "%s", message);
		} else {
			WRITE_INFO_LOG("%s", message);
		}
	}
	return 0;
}

static int l_log_warning(lua_State * L)
{
	char message[4096] = {0};
	size_t offset = 0;
	int i, top = lua_gettop(L);
	for(i = 1; i <= top; i++) {
		offset += snprintf(message + offset, sizeof(message) - offset, "%s\t", lua_tostring(L, i));
	}

	if (offset > 0) {
		struct logger * log = getLog(L);
		if (log) {
			_agL_write(log, LOG_WARNING, "%s", message);
		} else {
			WRITE_WARNING_LOG("%s", message);
		}
	}
	
	return 0;
}

static int l_log_error(lua_State * L)
{
	char message[4096] = {0};
	size_t offset = 0;
	int i, top = lua_gettop(L);
	for(i = 1; i <= top; i++) {
		offset += snprintf(message + offset, sizeof(message) - offset, "%s\t", lua_tostring(L, i));
	}

	if (offset > 0) {
		struct logger * log = getLog(L);
		if (log) {
			_agL_write(log, LOG_ERROR, "%s", message);
		} else {
			WRITE_ERROR_LOG("%s", message);
		}
	}
	return 0;
}


int luaopen_log(lua_State *L)
{
	luaL_Reg reg[] = {
		{"debug" ,  l_log_debug},
		{"info" ,   l_log_info},
		{"warning", l_log_warning},
		{"error" ,  l_log_error},
		{0,         0},
	};

	luaL_register(L,"log", reg);

	return 0;
}

int lua_set_log(lua_State * L, struct logger * log)
{
	struct logger * old_log = getLog(L);
	if (old_log) {
		_agL_close(old_log);
	}
	lua_getglobal(L, "log");
	if (log) {
		lua_pushlightuserdata(L, log);
	} else {
		lua_pushnil(L);
	}
	lua_setfield(L, -2, LOG_PTR);
	lua_pop(L, 1);
	return 0;
}
