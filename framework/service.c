#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <assert.h>
#include <signal.h>
#include <pthread.h>
#include <libgen.h>
#include <fcntl.h>
#include <sys/stat.h>

#include "network.h"
#include "module.h"
#include "config.h"
#include "log.h"
#include "mtime.h"
#include "service.h"

static int _stoped = 0;
static void on_signal(int sig)
{
	if (sig == SIGUSR1) {
		service_reload();
	} else {
		agN_stop();
		_stoped = 1;
	}
}

int service_init(int argc, char * argv[])
{
	_stoped = 0;
	signal(SIGINT,  on_signal);
	signal(SIGTERM, on_signal);
	signal(SIGUSR1, on_signal);
	signal(SIGUSR2, on_signal);

	WRITE_INFO_LOG("service start");

	module_log_load(argc, argv);
	module_time_load(argc, argv);

	struct module * ite;
	for(ite = modules; ite->name; ite++) {
		if (ite->on_load) {
			if (ite->on_load(argc, argv) != 0) {
				WRITE_ERROR_LOG("module %s load failed", ite->name);
				return -1;
			}
			WRITE_INFO_LOG("module %s load success", ite->name);

		}

		if (_stoped) {
			WRITE_INFO_LOG("receive stop signal");
			return -1;
		}
	}
	return 0;
}

int service_reload()
{
	module_log_reload();
	module_time_reload();

	struct module * ite;
	for(ite = modules; ite->name; ite++) {
		if (ite->on_reload) {
			if (ite->on_reload() != 0) {
				WRITE_ERROR_LOG("module %s reload failed", ite->name);
			} else {
				WRITE_INFO_LOG("module %s reload success", ite->name);
			}
		}
	}
	return 0;
}

void service_update(time_t now)
{
	module_time_update(now);
	//module_config_update(now);
	module_log_update(now);

	struct module * ite;
	for(ite = modules; ite->name; ite++) {
		if (ite->on_update) {
			ite->on_update(now);
		}
	}
}

void service_unload()
{
	struct module * ite;
	int i = 0;
	for(ite = modules; ite->name; ite++) {
		i++;
	}

	for(i = i - 1; i >= 0; i --) {
		ite = modules + i;
		if (ite->on_unload) {
			ite->on_unload();
			WRITE_INFO_LOG("module %s unload", ite->name);
		}
	}

	WRITE_INFO_LOG("service_unload");

	module_log_unload();
	//module_config_unload();
	module_time_unload();
}
