#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>

#include "memory.h"

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

struct logger {
	FILE * file;
	int    level;
	char   fname[256];
	time_t topen;
};

#define LOG_DEBUG      	0
#define LOG_INFO	1
#define LOG_WARNING	2
#define LOG_ERROR	3

static FILE * reopen_log(const char * fname, time_t now)
{
	if (strcmp(fname, "-") == 0) {
		return stdout;
	}

	char real_file_name[256] = {0};

	struct tm t; 
	localtime_r(&now, &t); 
	char date[32] = {0};
	size_t dl = sprintf(date, "%04d%02d%02d", t.tm_year + 1900, t.tm_mon + 1, t.tm_mday);

	int i, j = 0;
	for(i = 0; fname[i] && j < 256; i++) {
		if (fname[i] == '%' && fname[i+1] == 'T') {
			strcpy(real_file_name + j, date);
			j += dl;
			i++;
		} else {
			real_file_name[j++] = fname[i];
		}
	}
	return fopen(real_file_name, "a");
}

static struct logger * agL_open(const char * filename, int level)
{
	time_t now = time(0);
	FILE * f = reopen_log(filename, now);
	if (f == 0) {
		return 0;
	}

	struct logger * log = (struct logger*)malloc(sizeof(struct logger));
	strncpy(log->fname, filename, sizeof(log->fname));
	log->level = level;
	log->file = f;
	log->topen = time(0);

	return log;
}

static const char * LOG_LEVEL_DESC[] = {
	" DEBUG ",
	" INFO  ",
	"WARNING",
	" ERROR ",
	"UNKNOWN",
};

static const int log_level_count = sizeof(LOG_LEVEL_DESC) / sizeof(LOG_LEVEL_DESC[0]);

static void agL_write(struct logger * log, int level, const char * fmt, ...)
{
	if (level < log->level) {
		return;
	}

	struct tm t; 

	struct timeval timer;
	gettimeofday(&timer, NULL);
	time_t now = timer.tv_sec;

	const int sec_of_day = 24 * 60 * 60;
	int rday = log->topen / sec_of_day;
	int cday = now / sec_of_day;

	if (rday != cday) {
		if (log && log->file && log->file != stdout && log->file != stderr) {
			fclose(log->file);
		}
		log->file = reopen_log(log->fname, now);
	}

	if (log->file == 0) {
		return;
	}

	localtime_r(&now, &t); 

	fprintf(log->file, "[%02d-%02d-%02d %02d:%02d:%02d.%03u] ", 
			t.tm_year + 1900, t.tm_mon + 1, t.tm_mday, 
			t.tm_hour, t.tm_min, t.tm_sec,
			(unsigned int)timer.tv_usec/1000);

	if (level < 0 || level >= log_level_count) {
		level = log_level_count - 1;
	}

	fprintf(log->file, "[%s] ", LOG_LEVEL_DESC[level]);

	va_list args;
	va_start(args, fmt);

	vfprintf(log->file, fmt, args);

	va_end(args);

	fprintf(log->file, "\n");
}

static void agL_flush(struct logger * log)
{
	if (log->file && log->file != stdout && log->file != stderr) {
		fflush(log->file);
	}
}

static void agL_close(struct logger * log)
{
	if (log && log->file && log->file != stdout && log->file != stderr) {
		fclose(log->file);
	}
	free(log);
}

static int l_log_debug(lua_State * L)
{
	luaL_checktype(L, 1, LUA_TTABLE);
	lua_getfield(L, 1, "c_ptr");
	struct logger * log = (struct logger*)lua_touserdata(L, -1);
	lua_pop(L, 1);

	if (log == 0) {
		return 0;
	}

	const char * s = luaL_checkstring(L, 2);
	agL_write(log, LOG_DEBUG, "%s", s);
	return 0;
}

static int l_log_info(lua_State * L)
{
	luaL_checktype(L, 1, LUA_TTABLE);
	lua_getfield(L, 1, "c_ptr");
	struct logger * log = (struct logger*)lua_touserdata(L, -1);
	lua_pop(L, 1);

	if (log == 0) {
		return 0;
	}

	const char * s = luaL_checkstring(L, 2);
	agL_write(log, LOG_INFO, "%s", s);
	return 0;
}

static int l_log_warning(lua_State * L)
{
	luaL_checktype(L, 1, LUA_TTABLE);
	lua_getfield(L, 1, "c_ptr");
	struct logger * log = (struct logger*)lua_touserdata(L, -1);
	lua_pop(L, 1);

	if (log == 0) {
		return 0;
	}

	const char * s = luaL_checkstring(L, 2);
	agL_write(log, LOG_WARNING, "%s", s);
	return 0;
}

static int l_log_error(lua_State * L)
{
	luaL_checktype(L, 1, LUA_TTABLE);
	lua_getfield(L, 1, "c_ptr");
	struct logger * log = (struct logger*)lua_touserdata(L, -1);
	lua_pop(L, 1);

	if (log == 0) {
		return 0;
 	}

	const char * s = luaL_checkstring(L, 2);
	agL_write(log, LOG_ERROR, "%s", s);

	return 0;
}

static int l_log_close(lua_State * L)
{
	luaL_checktype(L, 1, LUA_TTABLE);
	lua_getfield(L, 1, "c_ptr");
	struct logger * log = (struct logger*)lua_touserdata(L, -1);
	lua_pop(L, 1);

	agL_close(log);

	return 0;
}

static int l_log_flush(lua_State * L)
{
	luaL_checktype(L, 1, LUA_TTABLE);
	lua_getfield(L, 1, "c_ptr");
	struct logger * log = (struct logger*)lua_touserdata(L, -1);
	lua_pop(L, 1);

	agL_flush(log);

	return 0;
}



#define lua_setfield_cfunction(L, index, field, func) \
	do { \
		int i = (index); \
		lua_pushcfunction((L), (func)); \
		if (i < 0)  i --; \
		lua_setfield((L), i, (field)); \
	} while(0)
	

static void l_push_log_metatable(lua_State * L)
{
	if (luaL_newmetatable(L, "c_logger_metatable") == 1) {
		lua_newtable(L);

		lua_setfield_cfunction(L, -1, "debug", l_log_debug);
		lua_setfield_cfunction(L, -1, "info", l_log_info);
		lua_setfield_cfunction(L, -1, "warning", l_log_warning);
		lua_setfield_cfunction(L, -1, "error", l_log_error);
		lua_setfield_cfunction(L, -1, "close", l_log_close);
		lua_setfield_cfunction(L, -1, "flush", l_log_flush);

		lua_setfield(L, -2, "__index");
	}
}


static int l_log_open(lua_State * L)
{
	const char * fname = luaL_checkstring(L, 1);
	int level = luaL_optinteger(L, 2, 0);

	struct logger * log = agL_open(fname, level);
	if (log == 0) {
		return 0;
	}

	lua_newtable(L);

	lua_pushlightuserdata(L, log);
	lua_setfield(L, -2, "c_ptr");

	l_push_log_metatable(L);
	lua_setmetatable (L, -2);

	return 1;
}

int luaopen_log(lua_State *L)
{
	luaL_Reg reg[] = {
		{"open",	l_log_open},
		{0,	0},
	};
	luaL_register(L,"log", reg);
	return 0;
}
