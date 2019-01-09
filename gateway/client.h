#ifndef _A_GAME_GATEWAY_CLIENT_H_
#define _A_GAME_GATEWAY_CLIENT_H_

#include <stdint.h>

#include "module.h"
#include "network.h"
#include "world.h"
#include "account.h"

DECLARE_MODULE(client)

typedef struct client 
{
	resid_t conn;
	unsigned int world;
	unsigned long long playerid;

	struct client * prev;
	struct client * next;
	time_t last_active;

	unsigned int protocol_flag;

	int adult;
	unsigned int vip;
	unsigned int vip2;
} client;

client * client_new(resid_t conn, unsigned int world, unsigned long long playerid);
void client_free(client * c);

int client_set(client * c, resid_t conn, unsigned int world, unsigned long long playerid);
client * client_get_by_playerid(unsigned long long playerid);

int client_send(client * client, unsigned int cmd, unsigned int flag, const void * msg, size_t len);
int client_broadcast(unsigned int cmd, unsigned int flag, const void * msg, size_t len);
int client_foreach(void(*cb)(client*,void*), void*ctx);

#endif
