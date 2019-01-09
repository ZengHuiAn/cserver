#ifndef _A_GAME_COMM_BASE_H_
#define _A_GAME_COMM_BASE_H_

int setnblock(int fd);
int listen_on(const char * host, unsigned short port, int backlog);
int connect_to(const char * host, unsigned short port, int * done);

#endif
