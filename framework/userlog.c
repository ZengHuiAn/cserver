#include <unistd.h>
#include <assert.h>
#include <string.h>
#include <stdarg.h>
#include <sys/time.h>
#include <libgen.h>
#include <stdio.h>

#include "log.h"
#include "config.h"
#include "memory.h"
#include "mtime.h"

////////////////////////////////////////////////////////////////////////////////
// user logger
static struct logger * user_logger[MAX_USER_LOGGER_COUNT] = {0};
static const char* user_logger_name[MAX_USER_LOGGER_COUNT] ={
	"resource",
	"armament",
	"tactic",
	"item",
	"playerexp",
	"level_up",
	"vip_up",
	"create_player",
	"login_logout",
	"create_account",
	"change_name",
	"online",
	"quest",
};
static long long user_logger_flush_time[MAX_USER_LOGGER_COUNT] ={0};
static const char* _get_user_logger_name(int type){
	return user_logger_name[type];
}
static void _try_open_user_logger(int type){
	if(user_logger[type] == 0){
		agL_open_user_logger(type);
	}
}
int agL_open_user_logger(int type)
{
	// check type
	if(type<0 || type>=MAX_USER_LOGGER_COUNT){
		return -1;
	}

	// close
	if(user_logger[type]){
		_agL_close(user_logger[type]);
		user_logger[type] = 0;
	}

	// open
	const char* name = _get_user_logger_name(type);
	char dir[256] = "../log";
	xml_node_t * path = agC_get("Log", "FileDir", 0);
	if(path){
		const char * ptr = xmlGetValue(path, 0);
		if (ptr && ptr[0]) {
			strncpy(dir, ptr, sizeof(dir));
		}
	}
	char logfilename[256] = {0};
	sprintf(logfilename, "%s/%s_%%T.log", dir, name);
	user_logger[type] = _agL_open(logfilename, LOG_DEBUG);
	return user_logger[type] ? 0 : -1;
}

int agL_set_user_logger_level(int type, int level){
	// check type
	if(type<0 || type>=MAX_USER_LOGGER_COUNT){
		return -1;
	}

	// try open
	_try_open_user_logger(type);

	// set level
	if(user_logger[type]){
		return _agL_set_level(user_logger[type], level);
	} else {
		return 0;
	}
}

static int server_id = 0;
int agL_write_user_logger(int type, int level, const char * fmt, ...){
	// check type
	if(type<0 || type>=MAX_USER_LOGGER_COUNT){
		return -1;
	}

	// try open
	_try_open_user_logger(type);

	if (server_id == 0) {
		server_id = agC_get_server_id();
	}

	// write
	if(user_logger[type]){
		va_list args;
		va_start(args, fmt);

		char sfmt[256] = {0};
		sprintf(sfmt, "%d,%s", server_id, fmt);

		int ret = _agL_writev(user_logger[type], level, sfmt, args);
		va_end(args);

		const long long now =agT_current();
		if((now - user_logger_flush_time[type]) > 5){
			user_logger_flush_time[type] =now;
			_agL_flush(user_logger[type]);
		}
		return ret;
	}
	else{
		return 0;
	}
}

void agL_flush_user_logger(int type){
	// check type
	if(type<0 || type>=MAX_USER_LOGGER_COUNT){
		return;
	}

	// flush
	if(user_logger[type]){
		_agL_flush(user_logger[type]);
	}
}
