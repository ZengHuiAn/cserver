#ifndef _A_GAME_COMM_MODULES_LOG_H_
#define _A_GAME_COMM_MODULES_LOG_H_

#include "module.h"

DECLARE_MODULE(log);

#ifdef _DEBUG
# include <stdio.h>
#endif

#include <time.h>
#include <stdarg.h>

#define LOG_DEBUG   0
#define LOG_INFO	1
#define LOG_WARNING	2
#define LOG_ERROR	3
#define LOG_FLAT    4

#define LOG_LEVEL LOG_DEBUG

/* internal  */
struct logger;

struct logger * _agL_open (const char * filename, int level);
int  _agL_set_level(struct logger * log, int level);
int  _agL_write(struct logger * log, int level, const char * fmt, ...) 
	__attribute__((format(printf, 3, 4)));  /* 3=format 4=params */

int  _agL_writev(struct logger * log, int level, const char * fmt, va_list args);
void _agL_flush(struct logger * log);
void _agL_close(struct logger * log);

/* default logger */
int  agL_open (const char * filename, int level);
int  agL_set_level(int level);
int  agL_write(int level, const char * fmt, ...)
	__attribute__((format(printf, 2, 3)));
void agL_flush();

/* user logger */
enum{
	RESOURCE_LOGGER,
	ARMAMENT_LOGGER,
	TACTIC_LOGGER,
	ITEM_LOGGER,
	PLAYER_EXP_LOGGER,

	PLAYER_LEVEL_UP_LOGGER,
	PLAYER_VIP_UP_LOGGER,
	CREATE_PLAYER_LOGGER,
	LOGIN_LOGOUT_LOGGER,
	CREATE_ACCOUNT_LOGGER,

	PLAYER_CHANGE_NAME_LOGGER,
	ONLINE_LOGGER,
	QUEST_LOGGER,

	MAX_USER_LOGGER_COUNT
};
int agL_open_user_logger(int type);
int agL_set_user_logger_level(int type, int level);
int agL_write_user_logger(int type, int level, const char * fmt, ...)
	__attribute__((format(printf, 3, 4)));
void agL_flush_user_logger(int type);

/* macro */
#define WRITE_TIME(out) \
	do { \
		struct tm t; \
		time_t now = time(0); \
		localtime_r(&now, &t); \
		fprintf(out, "[%02d-%02d-%02d %02d:%02d:%02d] ", \
				t.tm_year + 1900, t.tm_mon, t.tm_mday, \
				t.tm_hour, t.tm_min, t.tm_sec); \
	} while(0)


#ifndef CONSOLE_LOG

# define WRITE_LOG(out, level, ...) agL_write(LOG_##level, __VA_ARGS__);

#endif

#ifndef WRITE_LOG
# define WRITE_LOG(out, level, ...) \
	do { \
		if(LOG_LEVEL <= LOG_##level) { \
			WRITE_TIME(out); \
			fprintf(out, "[" #level "] "); \
			fprintf(out, __VA_ARGS__); \
			fprintf(out, "\n"); \
		} \
	} while(0)
#endif


#ifndef WRITE_DEBUG_LOG
#  define WRITE_DEBUG_LOG(...) WRITE_LOG(stdout, DEBUG, __VA_ARGS__);
# endif

#ifndef WRITE_ERROR_LOG
#  define WRITE_ERROR_LOG(...) WRITE_LOG(stderr, ERROR, __VA_ARGS__);
#endif

#ifndef WRITE_INFO_LOG
#  define WRITE_INFO_LOG(...) WRITE_LOG(stdout, INFO, __VA_ARGS__);
#endif 

#ifndef WRITE_WARNING_LOG
#  define WRITE_WARNING_LOG(...) WRITE_LOG(stdout, WARNING, __VA_ARGS__);
#endif 

#endif
