#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <stdarg.h>

struct Process
{
	pid_t pid;
	const char * workdir;
	const char * file;
	char * argv[32];
	const char * tag;
};

struct Process process[] = {
	{-1, "../bin",       "../bin/authserver",     {"../bin/authserver",     "-c", "../etc/authserver.xml",     "-d" }, "authserver"},
	{-1, "../bin",       "../bin/world",          {"../bin/world",          "-c", "../etc/lksg.xml"                 }, "world"     },
	{-1, "../bin",       "../bin/gmserver",       {"../bin/gmserver",       "-c", "../etc/lksg.xml",           "-d" }, "gmserver"  },
	{-1, "../arena",     "../bin/server",         {"../bin/server",         "-c", "../etc/lksg.xml", "arena.lua"    }, "arena"     },
	{-1, "../fight",     "../bin/server",         {"../bin/server",         "-c", "../etc/lksg.xml", "fight.lua"    }, "fight"     },
	{-1, "../chat",      "../bin/server",         {"../bin/server",         "-c", "../etc/lksg.xml", "chat.lua"     }, "chat"      },
	{-1, "../manor",     "../bin/server",         {"../bin/server",         "-c", "../etc/lksg.xml", "manor.lua"    }, "manor"     },
	{-1, "../map",       "../bin/server",         {"../bin/server",         "-c", "../etc/lksg.xml", "map.lua"      }, "map"       },
	{-1, "../quiz",      "../bin/server",         {"../bin/server",         "-c", "../etc/lksg.xml", "quiz.lua"     }, "quiz"      },
	{-1, "../guild",     "../bin/server",         {"../bin/server",         "-c", "../etc/lksg.xml", "guild.lua"    }, "guild"     },
	{-1, "../consume",   "../bin/server",         {"../bin/server",         "-c", "../etc/lksg.xml", "consume.lua"  }, "consume"   },
	{-1, "../ai",        "../bin/server",         {"../bin/server",         "-c", "../etc/lksg.xml", "ai.lua"       }, "ai"   },
	{-1, "../gm",        "../bin/server",         {"../bin/server",         "-c", "../etc/lksg.xml", "gm.lua"       }, "gm"   },
	{-1, "../bin",       "../bin/gateway",        {"../bin/gateway",        "-c", "../etc/lksg.xml"                 }, "gateway"   },

	{-1, 0, 0, {0,}},
};

static void write_log(const char * fmt, ...)
{
	struct timeval timer;
	gettimeofday(&timer, NULL);
	time_t now = timer.tv_sec;

	struct tm t; 
	localtime_r(&now, &t); 
	char date[64] = {0};
	fprintf(stdout, "[%02d-%02d-%02d %02d:%02d:%02d.%03u] ", 
			t.tm_year + 1900, t.tm_mon + 1, t.tm_mday, 
			t.tm_hour, t.tm_min, t.tm_sec,
			(unsigned int)timer.tv_usec/1000);

	va_list args;
	va_start(args, fmt);
	vfprintf(stdout, fmt, args);
	va_end(args);

	fflush(stdout);
}

static int stop = 0;
static pid_t wait_children()
{
	int status = 0;
	pid_t pid = wait(&status);
	if (pid == -1) {
		return pid;
	}

	int i;
	for (i = 0; process[i].file; i++) {
		if (process[i].pid == pid) {
			write_log("%s(%d) exists\n", process[i].tag, pid);
			process[i].pid = -1;
		}
	}
	return pid;
}

static void signal_children(int signal)
{
	int i;
	for (i = 0; process[i].file; i++) {
		if (process[i].pid > 0) {
			kill(process[i].pid, signal);
		}
	}
}

static void on_signal(int signal)
{
	if (signal == SIGTERM || signal == SIGUSR1 || signal == SIGUSR2 || signal == SIGINT) {
		signal_children(signal);
	}

	if (signal == SIGTERM || signal == SIGINT) {
		stop = 1;
	}
}

int main(int argc, char * argv[])
{
	const char * basedir = ".";
	if (argc > 1) {
		basedir = argv[1];
	}

	signal(SIGCHLD, on_signal);
	signal(SIGTERM, on_signal);
	signal(SIGUSR2, on_signal);
	signal(SIGUSR1, on_signal);
	signal(SIGINT,  on_signal);

	while(!stop) {
		int i;
		for (i = 0; process[i].file; i++) {
			if (process[i].pid == -1) {
				pid_t pid = fork();
				switch(pid) {
					case -1:
						write_log("fork: %s", strerror(errno));
						return -1;
					case 0: {
							int fd = open("/dev/null", O_RDWR);
							dup2(fd, 0);
							dup2(fd, 1);
							dup2(fd, 2);
							char dir[256] = {0};
							sprintf(dir, "%s/%s", basedir, process[i].workdir);
							chdir(dir);
							execv(process[i].file, process[i].argv);
							exit(0);
						}
						break;
					default:
						write_log("start process %s(%d)\n", process[i].tag, pid);
						process[i].pid = pid;
						break;
				}
			}
		}

		wait_children();

		time_t now = time(0);
		while(time(0) <= now && !stop) {
			sleep(1);
		}
	}

	write_log("wait for child exit\n");

	while(1) {
		signal_children(SIGTERM);

		int status = 0;
		pid_t pid = wait_children();
		if (pid == -1  && errno == ECHILD) {
			break;
		}
	}
}
