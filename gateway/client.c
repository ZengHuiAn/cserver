#include <assert.h>
#include <arpa/inet.h>

#include "client.h"
#include "network.h"
#include "dlist.h"
#include "mtime.h"
#include "log.h"
#include "package.h"
#include "map.h"

static struct map * client_hash = 0;
static client * client_queue = 0;
static int client_count = 0;

int module_client_load(int argc, char * argv[])
{
	client_hash = _agMap_new(0);
	if (client_hash == 0) {
		return -1;
	}
	return 0;
}

int module_client_reload()
{
	return 0;
}

void module_client_update(time_t now)
{
}

void module_client_unload()
{
	while(client_queue) {
		client * c = client_queue;
		dlist_remove(client_queue, c);
		free(c);
	}
	_agMap_delete(client_hash);
}

client * client_new(resid_t conn, unsigned int world, unsigned long long playerid)
{
#if 0
	client * c = client_queue;
	if (client_count <= 10000 || 
			agT_current() - c->last_active < 60 * 60) {
		c = (client*)malloc(sizeof(client));
		if (c) client_count++;
	}
#endif
	client * c = 0;
	if (client_count < 10000) {
		c = (client*)malloc(sizeof(client));
	}

	if (c) {
		client_count ++;

		dlist_init(c);
		c->last_active = agT_current();
		c->conn = conn;
		c->world = world;
		c->playerid = playerid;
		c->adult = 0;
		c->vip = 0;
		c->vip2 = 0;
		_agMap_ip_set(client_hash, c->playerid, c);
		dlist_insert_tail(client_queue, c);
	}
	return c;
}

void client_free(client * c)
{
	if (c) {
		_agMap_ip_set(client_hash, c->playerid, 0);
		dlist_remove(client_queue, c);
		free(c);
		client_count --;
	}
}

int client_set(client * c, resid_t conn, unsigned int world, unsigned long long playerid)
{
	assert(c && playerid != INVALID_PLAYER_ID);

	if (c->playerid != INVALID_PLAYER_ID) {
		_agMap_ip_set(client_hash, c->playerid, 0);
	}

	if (c->next && c->prev ) {
		dlist_remove(client_queue, c);
	}

	c->last_active = agT_current();
	c->conn = conn;
	c->world = world;
	c->playerid = playerid;
	_agMap_ip_set(client_hash, c->playerid, c);
	dlist_insert_tail(client_queue, c);
	return 0;
}

//struct cleint * client_get_by_conn(resid_t conn);
client * client_get_by_playerid(unsigned long long playerid)
{
	client * c = (client*)_agMap_ip_get(client_hash, playerid);
	if (c) {
		dlist_remove(client_queue, c);
		c->last_active = agT_current();
		dlist_insert_tail(client_queue, c);
	}
	return c;
}

int client_foreach(void(*cb)(client*,void*), void*ctx) 
{
	if (cb == 0) return 0;

	struct client * ite = 0;
	while((ite = dlist_next(client_queue, ite)) != 0) {
		if (ite->conn != INVALID_ID) {
			cb(ite, ctx);
		}
	}
	return 0;
}

int client_broadcast(unsigned int cmd, unsigned int flag, const void * msg, size_t len)
{
	WRITE_DEBUG_LOG("broad cast %zu byte(s) to clients, cmd %u", len, cmd);
	struct client_header header;
	header.len = htonl(sizeof(header) + len);
	header.flag = htonl(flag);
	header.cmd  = htonl(cmd);

	struct client * ite = 0;
	while((ite = dlist_next(client_queue, ite)) != 0) {
		if (ite->conn != INVALID_ID) {
			struct iovec iov[2];
			iov[0].iov_base = &header;
			iov[0].iov_len  = sizeof(header);

			iov[1].iov_base = (char*)msg;
			iov[1].iov_len  = len;
			agN_writev(ite->conn, iov, 2);
		}
	}
	return 0;
}

int client_send(client * client, unsigned int cmd, unsigned int flag, const void * msg, size_t len)
{
	if (client == 0) {
		return -1;
	}

	struct client_header h;
	h.len  = htonl(len+sizeof(h));
	h.flag = htonl(flag);
	h.cmd  = htonl(cmd);

	struct iovec iov[2];
	iov[0].iov_base = &h;
	iov[0].iov_len  = sizeof(h);

	iov[1].iov_base = (char*)msg;
	iov[1].iov_len  = len;

	return agN_writev(client->conn, iov, 2);
}
