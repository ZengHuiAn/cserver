#include <string.h>
#include <time.h>
#include "time.h"

static time_t current = 0;
int module_time_load(int argc, char * argv[])
{
	current = time(0);
	return 0;
}

int module_time_reload()
{
	return 0;
}

void module_time_update(time_t now)
{
	current = now;
}

void module_time_unload()
{

}

time_t agT_current()
{
	return current;
}


int agT_delay(time_t t, void(*cb)(time_t, void*), void * data)
{
	return -1;
}
