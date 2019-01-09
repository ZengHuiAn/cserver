#include "timeline.h"
#include "database.h"
#include "log.h"
#include "mtime.h"

#include <assert.h>

time_t _startTime = 0;
time_t _open_server_time = 0;



static int onQuery(struct slice * fields, void * ctx)
{
	_startTime = atoll((const char*)fields[0].ptr);
	return 0;
}

static int initOpenServerTime(struct slice * fields, void * ctx)
{
	_open_server_time = atoll((const char*)fields[0].ptr);
	return 0;
}

const static int DAY_SEC  = 3600 * 24;
const static int WEEK_SEC = 3600 * 24 * 7;

const static time_t time_base = 1295712000;

static time_t adjustTime(time_t now)
{
	// 从周一开始，不是周日
	time_t start = time_base + 3600 * 24;
	time_t sep = now - start;
	return start + (sep - sep % WEEK_SEC);
}

int module_timeline_load(int arg, char * argv[])
{
	_startTime = 0;

	extern struct DBHandler * role_db;
	if (database_query(role_db, onQuery, 0, "select V from RECORD where K = 'system_start_time'") < 0) {
		return -1;
	}

	if (_startTime == 0) {
		_startTime = adjustTime(agT_current());
		if (database_update(role_db, "replace into RECORD (K, V) values('system_start_time', %lu)", _startTime) < 0) {
			return -1;
		}
	}
	_startTime = adjustTime(_startTime);


	return 0;
}

int module_timeline_reload()
{
	return 0;
}

void module_timeline_update(time_t now)
{
}

void module_timeline_unload()
{
}

time_t timeline_get(time_t now, unsigned int loop)
{
	if (loop == 0) loop = 1;

	if (now < _startTime) { return 0; }
	return (now - _startTime) / loop + 1;
}

time_t timeline_get_sec(time_t now)
{
	return timeline_get(now, 1);
}

time_t timeline_get_day(time_t now)
{
	return timeline_get(now, DAY_SEC);
}

time_t timeline_get_week(time_t now)
{
	return timeline_get(now, WEEK_SEC);
}

time_t get_open_server_time()
{
	if (_open_server_time == 0) {
		/*FILE *fp = fopen("../world/open_server.txt","rb");
		char buff[100];
		if (!fp)
		{
		    _open_server_time = 1;
		   	return _open_server_time; 
		}
		fread(buff,sizeof(buff),1,fp);
		printf ("%s  \n",buff);
		_open_server_time = atoll(buff);	
		fclose(fp);	*/
		
		extern struct DBHandler * role_db;
		if (database_query(role_db, initOpenServerTime, 0, "select unix_timestamp(`create`) as `create` from `property` where pid = 100000") < 0) _open_server_time = 1; 
		
		return _open_server_time;
	}
	return _open_server_time;
}
 
