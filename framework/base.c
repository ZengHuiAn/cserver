#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <netdb.h>
#include <arpa/inet.h>
#include <fcntl.h>

//#include <event.h>

#include <unistd.h>
#include <assert.h>
#include <errno.h>
#include <sys/un.h>

#include <time.h>

#include "base.h"

static int socktoaddr(const char* host, unsigned short port, 
		struct sockaddr_in *addr)
{
	struct hostent *host_ent;
	memset(addr, 0, sizeof(struct sockaddr_in));
	addr->sin_family = AF_INET;
	addr->sin_port   = htons(port);
	//获得主机信息入口
	if ((host_ent=gethostbyname(host))!=NULL) {
		memcpy(&addr->sin_addr, host_ent->h_addr, host_ent->h_length);
	} else {
		//xxx.xxx.xxx.xxx
		if ((addr->sin_addr.s_addr = inet_addr(host)) == INADDR_NONE) {
			return -1;
		}
	}
	return 0;
}


int setnblock(int fd)
{
	int flags;
	flags = fcntl(fd, F_GETFL, 0);
	flags |= O_NONBLOCK;
	flags |= O_NDELAY;
	fcntl(fd, F_SETFL, flags);
	return 0;
}

static int setreuse(int fd)
{
	int flag = 1;
	if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR,
				(char *)&flag, sizeof(flag)) != 0) {
		return -1;
	}
	return 0;
}


static int check_path(const char * path) 
{
/*
	int fd = open(path,  O_RDONLY);
	if (fd >= 0) {
		close(fd);
	} else {
		if (errno != ENOENT) {
			// invalid error
			return -1;
		}
	}
*/
	return 0;
}

static int listen_on_unix(const char * path, unsigned backlog)
{
	int fd;
	struct sockaddr_un addr;
	
	if (check_path(path) != 0) {
		return -1;
	}

	unlink(path);

	memset(&addr, 0, sizeof(addr));
	addr.sun_family = AF_UNIX;
	strcpy(addr.sun_path, path);


	fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (fd == -1) {
		return -1;
	}
	if (setreuse(fd) != 0 || 
			setnblock(fd) != 0 ||
			bind(fd, (struct sockaddr*)&addr, sizeof(addr)) != 0 ||
			listen(fd, backlog) != 0) {
		close(fd);
		return -1;
	}
	return fd;  
}

static int connect_to_unix(const char * path, int * done)
{
	int fd;
	struct sockaddr_un addr;

	if (check_path(path) != 0) {
		return -1;
	}

	memset(&addr, 0, sizeof(addr));
	addr.sun_family = AF_UNIX;
	strcpy(addr.sun_path, path);

	fd = socket(AF_UNIX, SOCK_STREAM, 0);

	if (fd == -1) {
		return -1;
	}

	if (setnblock(fd) != 0) {
	    close(fd);
	    return -1;
	}
    
	if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) == 0) {
		if (done) *done = 1;
		return fd;
	}

	if (errno == EINPROGRESS||errno==EWOULDBLOCK) {
		if (done) *done = 0;
		return fd;
	} else {
		close(fd);
		return -1;
	}
}

int listen_on(const char * host, unsigned short port, int backlog)
{
	if (strncmp(host, "unix://", 7) == 0) {
			return listen_on_unix(host+7, backlog);
	}

	int fd;
	struct sockaddr_in addr;
	if (socktoaddr(host, port, &addr) != 0) {
		return -1;
	}

	fd = socket(AF_INET, SOCK_STREAM, 0);
	if (fd == -1) {
		return -1;
	}

	if (setreuse(fd) != 0 || 
			setnblock(fd) != 0 ||
			bind(fd, (struct sockaddr*)&addr, sizeof(addr)) != 0 ||
			listen(fd, backlog) != 0) {
		close(fd);
		return -1;
	}
	return fd;  
}

int connect_to(const char * host, unsigned short port, int * done)
{
	if (strncmp(host, "unix://", 7) == 0) {
			return connect_to_unix(host+7, done);
	}

	int fd;
	struct sockaddr_in addr;

	if (socktoaddr(host, port, &addr) != 0) {
		return -1;
	}

	fd = socket(AF_INET, SOCK_STREAM, 0);

	if (fd == -1) {
		return -1;
	}

	if (setnblock(fd) != 0) {
	    close(fd);
	    return -1;
	}
    
	if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) == 0) {
		if (done) *done = 1;
		return fd;
	}
	if (errno == EINPROGRESS||errno==EWOULDBLOCK) {
		if (done) *done = 0;
		return fd;
	} else {
		close(fd);
		return -1;
	}
}
