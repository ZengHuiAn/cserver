#ifndef _A_GAME_GATEWAY_ACCOUNT_H_
#define _A_GAME_GATEWAY_ACCOUNT_H_

#include <stdint.h>

#include "module.h"
#include "network.h"

DECLARE_MODULE(account)

typedef struct account 
{
	char name[128];
	unsigned long long playerid;
	int last_world;
} account;

#define INVALID_PLAYER_ID ((uint32_t)-1)

account * account_new(const char * name, unsigned long long playerid);
account * account_get(const char * name);
account * account_get_by_pid(unsigned long long pid);
int32_t account_parse_pid_by_name(resid_t conn, struct network *net, const char *name, unsigned long long *ppid, const char *data, size_t len, unsigned int serverid);
int account_change(unsigned long long pid, const char* name);
//int32_t account_parse_pid_by_name(const char* name, unsigned int* ppid);

#endif
