#include <assert.h>
#include <sys/time.h>
#include <signal.h>
#include <libgen.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include "network.h"
#include "service.h"
#include "memory.h"
#include "buffer.h"
#include "string.h"
#include "config.h"
#include "log.h"
#include "version.h"

unsigned int g_sid = 0;

static time_t    last = 0;
static void timer(time_t t, void * ctx)
{
	// first time ?
	if (last == 0) { last = t - 1; }

	//printf("timer %lu -> %lu\n", last, t);

	int i;
	for(i = last + 1; i <= t; i++) {
		service_update(i);
		last = i;
	}
	assert(last >= t);
}

static void Usage(const char * prog)
{
	printf("Usage: %s opt\n",prog);
	printf("    -d               run as daemon\n");
	printf("    -c config        load config file from\n");
	printf("    -sid sid\n");
	printf("    -h               show this\n");
	printf("    -v/--version     version\n");
	exit(0);
}

static void Version()
{
	printf("Version: %s\n", VERSION);
	exit(0);
}

int main(int argc, char * argv[])
{
	int isdaemon = 0;
	int i;
	const char * configfile = 0;
	for(i = 1; i < argc; i++) {
		if (strcmp(argv[i], "-d") == 0) {
			isdaemon = 1;
		} else if (strcmp(argv[i], "-c") == 0) {
			if (i != argc - 1) {
				configfile = argv[++i];
			}
		} else if (strcmp(argv[i], "-sid") == 0) {
			if (i != argc - 1) {
				g_sid = atoi(argv[++i]);
			}
		} else if (strcmp(argv[i], "-h") == 0) {
			Usage(argv[0]);
		} else if ( (strcmp(argv[i], "-v")==0) || (strcmp(argv[i], "--version")==0) ) {
			Version();
		}
	}

	char rfile[256];
	if (configfile) {
		strcpy(rfile, configfile);
	} else {
		sprintf(rfile, "../etc/config/%s.xml", basename(argv[0]));
	}
	if (agC_open(rfile) != 0 && configfile) {
		WRITE_ERROR_LOG("open config %s failed", rfile);
		return -1;
	}

	char dir[256] = "../log";
	xml_node_t * path = agC_get("Log", "FileDir", 0);
	if (path) {
		const char * ptr = xmlGetValue(path, 0);
		if (ptr && ptr[0]) {
			strncpy(dir, ptr, sizeof(dir));
		}
	}

	char logfilename[256] = {0};
	sprintf(logfilename, "%s/%s_%%T.log", dir, basename(argv[0]));
	WRITE_DEBUG_LOG("write log to %s", logfilename);
	agL_open(logfilename, LOG_DEBUG);

	pid_t pid = getpid();

	if (isdaemon) {
		int fd = open("/dev/null", O_RDWR);
		dup2(fd, 0);
		dup2(fd, 1);
		dup2(fd, 2);
	}

	// init service
	if (service_init(argc, argv)) {
		return -1;
	}

	if (isdaemon && pid == getpid()) {
		if(0 != daemon(1, 0)){
			perror("fail to call daemon:");
		}
	}

	// set update
	agN_set_timer(timer ,0);

	// main loop
	agN_loop();

	// unload
	service_unload();

	// close network
	agN_free();

	agC_close();

	agL_open(0, LOG_DEBUG);

	_agB_statistic();
	_agM_statistic();

	return 0;
}
