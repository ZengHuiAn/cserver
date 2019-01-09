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

int module_log_load(int argc, char * argv[])
{
#if 0
	xmlNode * log = agC_get("Log", "file", 0);
	char logfilename[256] = {0};
	if (log) {
		strncpy(logfilename, xmlGetValue(log, 0), 256);	
	} else {
		sprintf(logfilename, "../log/%s_%%T.log", basename(argv[0]));
	}
	WRITE_DEBUG_LOG("write log to %s", logfilename);
	agL_open(logfilename, LOG_DEBUG);
#endif
	return 0;
}

int module_log_reload()
{
	return 0;
}

void module_log_update(time_t now)
{
	agL_flush();
}

void module_log_unload()
{
	agL_open(0, 0);
}

static FILE * reopen_log_file(const char * name, time_t now)
{
	if (isatty(STDOUT_FILENO)) {
		return stdout;
	}

	if (strcmp(name, "-")  == 0) {
		return stdout;
	}

	char real_file_name[256] = {0};

	struct tm t; 
	localtime_r(&now, &t); 
	char date[32] = {0};
	sprintf(date, "%04d%02d%02d_%02d",
			t.tm_year + 1900, t.tm_mon + 1, t.tm_mday, t.tm_hour);

	int i, j = 0;
	int tlen = strlen(name);
	for(i = 0; i < tlen; i++) {
		if (i < tlen - 1 && name[i] == '%' 
				&& name[i+1] == 'T') {
			strcpy(real_file_name + j, date);
			j+= strlen(date);
			i++;
		} else {
			real_file_name[j++] = name[i];
		}
	}
	return fopen(real_file_name, "a");
}

struct logger
{
	char   name[256];
	FILE * file;
	time_t topen;
	int    level;
};

struct logger * _agL_open (const char * filename, int level)
{
	time_t now = time(0);
	FILE * file = reopen_log_file(filename, now);
	if (file == 0) return 0;

	struct logger * log = (struct logger*)MALLOC(sizeof(struct logger));

	log->file = file;
	strncpy(log->name, filename, sizeof(log->name));
	log->topen = now;
	log->level = level;

	return log;
}
int  _agL_set_level(struct logger * log, int level)
{
	if (log == 0) return 0;
	int olevel = log->level;
	log->level = level;
	return olevel;
}

static const char * LOG_LEVEL_DESC[] = {
	" DEBUG ",
	" INFO  ",
	"WARNING",
	" ERROR ",
	"UNKNOWN",
};

static const int log_level_count = sizeof(LOG_LEVEL_DESC) / sizeof(LOG_LEVEL_DESC[0]);

int  _agL_write(struct logger * log, int level, const char * fmt, ...)
{
	va_list args;
	va_start(args, fmt);
	int ret = _agL_writev(log, level, fmt, args);
	va_end(args);
	return ret;
}

int  _agL_writev(struct logger * log, int level, const char * fmt, va_list args)
{
	// check
	if (log && level < log->level) {
		return 0;
	}

	// set to stdout
	static struct logger defaultLog;
	defaultLog.level = 0;
	defaultLog.file = stdout;

	if (log == 0 || log->file == 0) {
		log = &defaultLog;
	}

	// pre time
	struct tm t; 
	struct timeval timer;
	gettimeofday(&timer, NULL);
	time_t now = timer.tv_sec;

	const int sec_of_hour = 60 * 60;
	int rhour = log->topen / sec_of_hour;
	int chour = now / sec_of_hour;

	// try reopen
	if (rhour != chour || level == LOG_FLAT || (log->file == stdout && !isatty(STDOUT_FILENO))) {
		FILE * file = reopen_log_file(log->name, now);
		if (file) {
			if (log->file && log->file != stdout && log->file != stdin && log->file != stderr) {
				fclose(log->file);
			}
			log->file = file;
			log->topen = now;
		}
	}

	/* write header */
	localtime_r(&now, &t); 
	if(level != LOG_FLAT){
		fprintf(log->file, "[%02d-%02d-%02d %02d:%02d:%02d.%03u] ", 
				t.tm_year + 1900, t.tm_mon + 1, t.tm_mday, 
				t.tm_hour, t.tm_min, t.tm_sec,
				(unsigned int)timer.tv_usec/1000);

		if (level < 0 || level >= log_level_count) {
			level = log_level_count - 1;
		}

		fprintf(log->file, "[%s] ", LOG_LEVEL_DESC[level]);
	}

	/* write body */
	//va_list args;
	//va_start(args, fmt);
	vfprintf(log->file, fmt, args);
	//va_end(args);

	fprintf(log->file, "\n");
	//agL_flush();
	return 0;
}

void _agL_flush(struct logger * log)
{
	if (log && log->file) {
		fflush(log->file);
	}
}

void _agL_close(struct logger * log)
{
	if (log) {
		if (log->file && log->file != stdout && log->file != stdin && log->file != stderr) {
			fclose(log->file);
		}
		FREE(log);
	}
}


////////////////////////////////////////////////////////////////////////////////
// default logger
static struct logger * default_logger = 0;

int  agL_open (const char * filename, int level)
{
	if (default_logger) {
		_agL_close(default_logger);
		default_logger = 0;
	}

	if (filename) {
		default_logger = _agL_open(filename, level);
	}
	return default_logger ? 0 : -1;
}

int  agL_set_level(int level)
{
	if (default_logger) {
		return _agL_set_level(default_logger, level);
	} else {
		return 0;
	}
}

int  agL_write(int level, const char * fmt, ...)
{
	va_list args;
	va_start(args, fmt);
	int ret = _agL_writev(default_logger, level, fmt, args);
	va_end(args);
	return ret;
}

void agL_flush()
{
	if (default_logger) {
		_agL_flush(default_logger);
	}
}
