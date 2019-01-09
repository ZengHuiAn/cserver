#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <dlfcn.h>

#include "log.h"

void * so = 0;

int  (*ProfilerStart)(const char* fname);
void (*ProfilerStop)();

int module_profiler_load(int argc, char * argv[])
{
	so = dlopen("libprofiler.so", RTLD_NOW);

	if (so == 0) {
		WRITE_WARNING_LOG("[PROFILER] open libprofiler.so failed: %s", strerror(errno));
		return 0; // 非关键组件
	}

	ProfilerStart = (int(*)(const char*)) dlsym(so, "ProfilerStart");
	ProfilerStop  = (void(*)())dlsym(so, "ProfilerStop");

	assert(ProfilerStart);
	assert(ProfilerStop);

	WRITE_DEBUG_LOG("[PROFILER] load");
	char fname[256] = {0};
	sprintf(fname, "%s.prof", argv[0]);
	WRITE_DEBUG_LOG("write profiler %s", fname);
	ProfilerStart(fname);
	return 0;
}

int module_profiler_reload()
{
	return 0;
}

void module_profiler_update(time_t now)
{
}

void module_profiler_unload()
{
	WRITE_DEBUG_LOG("[PROFILER] unload");
	if (so) {
		ProfilerStop();
		dlclose(so);
	}
}
