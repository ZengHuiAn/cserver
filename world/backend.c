#include <arpa/inet.h>
#include <assert.h>

#include "backend.h"
#include "config.h"
#include "network.h"
#include "log.h"
#include "map.h"
#include "memory.h"
#include "package.h"
#include "protocol.h"

struct Backend
{
	struct {
		unsigned int min;
		unsigned int max;
	} cmd;

	unsigned int id;

	char name[256];
	char host[256];
	int  port;
	int  timeout;
	resid_t conn;
	int reconnected;
};

static struct map * backends = 0;

#define UNUSED(x) ((void)(x))
static struct network_handler backend_handler;

static void   on_connected(struct network * net, resid_t c, void * ctx);
static void   on_closed(struct network * net, resid_t c, int error, void * ctx);
static size_t on_message(struct network * net, resid_t c, const char * msg, size_t len, void * ctx);

#define ATOI(x, def) ( (x) ? atoi(x) : (def))

unsigned int port_base = 9810;

static int parseBackendConfig(xml_node_t * node, void * ctx)
{
	unsigned int id  = ATOI(xmlGetAttribute(node, "id",  0), 0);
	unsigned int min = ATOI(xmlGetAttribute(node, "min", 0), 0);
	unsigned int max = ATOI(xmlGetAttribute(node, "max", 0), 0);

	if (id <= 10 || min == 0 || max < min) {
		WRITE_ERROR_LOG("social config error: id %u min %u max %u", id, min, max);
		return -1;
	}

	struct Backend * backend = MALLOC_N(struct Backend, 1);

	backend->cmd.min = min;
	backend->cmd.max = max;
	backend->id = id;

	strcpy(backend->host, xmlGetValue(xmlGetChild(node, "host", 0), "localhost"));
	backend->port = ATOI(xmlGetValue(xmlGetChild(node, "port", 0), 0), port_base + id);
	backend->timeout = ATOI(xmlGetValue(xmlGetChild(node, "timeout", 0), 0), 5);
	backend->conn = INVALID_ID;

	const char * name = xmlGetAttribute(node, "name", 0);
	if (name == 0) {
		strcpy(backend->name, xmlGetName(node));
	} else {
		strcpy(backend->name, name);
	}

	backend->reconnected = 0;

	_agMap_sp_set(backends, backend->name, backend);

	return 0;
}

int module_backend_load(int argc, char * argv[])
{
	port_base = ATOI(xmlGetValue(agC_get("PortBase"), 0), 9810);

	backends = _agMap_new(0);

	xml_node_t * social = agC_get("Social");
	if(foreachChildNodeWithName(social, 0, parseBackendConfig, 0) != 0) {
		WRITE_ERROR_LOG("loadBackendConfig failed");
		return -1;
	}

	backend_handler.on_connected = on_connected;
	backend_handler.on_accept = 0;
	backend_handler.on_closed = on_closed;
	backend_handler.on_message = on_message;

	return 0;
}

int module_backend_reload()
{
	module_backend_unload();
	return module_backend_load(0, 0);
}

static void reconnect_backend(const char * key, void *p, void * ctx)
{
	struct Backend * backend = (struct Backend*)p;
	if (backend->conn == INVALID_ID && backend->reconnected) {
		WRITE_DEBUG_LOG("backend %s %s:%u reconnecting", backend->name, backend->host, backend->port);	
		backend->conn = agN_connect(backend->host, backend->port, backend->timeout, &backend_handler, backend);
	}
}

void module_backend_update(time_t now)
{
	_agMap_sp_foreach(backends, reconnect_backend, 0);
}

static void unload_backend(const char * key, void *p, void * ctx)
{
	struct Backend * backend = (struct Backend*)p;
	if (backend->conn != INVALID_ID) {
		agN_close(backend->conn);
	}
	FREE(backend);
}

void module_backend_unload()
{
	_agMap_sp_foreach(backends, unload_backend, 0);
	_agMap_delete(backends);
	backends = 0;
}

static void on_connected(struct network * net, resid_t c, void * ctx)
{
	struct Backend * peer = (struct Backend*)ctx;
	WRITE_INFO_LOG("backend %s connect success", peer->name);	
}

static void on_closed(struct network * net, resid_t c, int error, void * ctx)
{
	struct Backend * peer = (struct Backend*)ctx;
	WRITE_WARNING_LOG("backend %s with connection %u closed", peer->name, c);
	assert(c == peer->conn);
	peer->conn = INVALID_ID;
	peer->reconnected = 1;
}

static size_t on_message(struct network * net, resid_t conn, const char * data, size_t len, void * ctx)
{
	if (len < sizeof(struct translate_header)) {
		return 0;
	}

	struct translate_header * tran_info = (struct translate_header*)data;
	size_t package_len = ntohl(tran_info->len);
	if (len < package_len) {
		return 0;
	}

	struct Backend * peer = (struct Backend*)ctx;

	uint32_t flag    = ntohl(tran_info->flag);
	uint32_t command = ntohl(tran_info->cmd);
	unsigned long long channel = ntohl(tran_info->playerid);

	size_t data_len = package_len;
	data += sizeof(struct translate_header);
	data_len -= sizeof(struct translate_header);

	UNUSED(peer);
	UNUSED(flag);
	UNUSED(command);
	UNUSED(channel);
	UNUSED(data);
	UNUSED(data_len);

	return package_len;
}

void backend_connect(const char * name)
{
	struct Backend * backend = (struct Backend*)_agMap_sp_get(backends, name);
	if (backend && backend->conn == INVALID_ID) {
		WRITE_DEBUG_LOG("backend %s %s:%u connecting", backend->name, backend->host, backend->port);	
		backend->conn = agN_connect(backend->host, backend->port, backend->timeout, &backend_handler, backend);
	}
}


struct Backend * backend_new(const char * name, int id, const char * host, int port, int timeout)
{
	if (_agMap_sp_get(backends, name)) {
		return 0;
	}

	struct Backend * backend = MALLOC_N(struct Backend, 1);

	backend->cmd.min = 0;
	backend->cmd.max = 0;
	backend->id      = 0;
	
	strcpy(backend->host, host ? host : "localhost");
	backend->port = port ? port : (port_base + id);
	backend->timeout = timeout ? timeout : 5;
	backend->conn = INVALID_ID;

	strcpy(backend->name, name ? name : "backend");
	backend->reconnected = 0;

	_agMap_sp_set(backends, name, backend);

	return backend_get(name, 0);
}

struct Backend * backend_get(const char * name, unsigned long long pid)
{
	struct Backend * backend = (struct Backend*)_agMap_sp_get(backends, name);
	if (backend && backend->conn == INVALID_ID) {
		WRITE_DEBUG_LOG("backend %s %s:%u connecting", backend->name, backend->host, backend->port);	
		backend->conn = agN_connect(backend->host, backend->port, backend->timeout, &backend_handler, backend);
	}
	return backend;
}

int backend_send(struct Backend * peer,
		unsigned long long channel,
		unsigned int cmd,
		unsigned int flag,
		const void * msg, size_t len) 
{
	WRITE_DEBUG_LOG("player(%llu) -> backend(%s)  command %u, len %zu",
			channel, peer->name, cmd, len);

	struct translate_header theader;
	theader.len      = htonl(sizeof(theader) + len);
	theader.playerid = htonl(channel);
	theader.flag     = htonl(flag);
	theader.cmd      = htonl(cmd);

	struct iovec iov[2];
	iov[0].iov_base = &theader;
	iov[0].iov_len  = sizeof(theader);

	iov[1].iov_base = (char*)msg;
	iov[1].iov_len  = len;

	return agN_writev(peer->conn, iov, 2);
}

int backend_send_pbc(struct Backend * peer,
		unsigned long long channel, unsigned int cmd,
		struct pbc_wmessage * msg)
{
	WRITE_DEBUG_LOG("player(%llu) -> backend(%s)  command %u", channel, peer->name, cmd);

	struct pbc_slice slice;
	pbc_wmessage_buffer(msg, &slice);

	struct translate_header theader;
	memset(&theader, 0, sizeof(theader));
	theader.len      = htonl(sizeof(theader) + slice.len);
	theader.playerid = htonl(channel);
	theader.flag     = htonl(2);
	theader.cmd      = htonl(cmd);

	struct iovec iov[2];
	iov[0].iov_base = &theader;
	iov[0].iov_len  = sizeof(theader);

	iov[1].iov_base = (char*)slice.buffer;
	iov[1].iov_len  = slice.len;

	return agN_writev(peer->conn, iov, 2);
}


int backend_avalible(struct Backend * backend)
{
	return backend->conn != INVALID_ID;
}

int backend_get_id(struct Backend * backend)
{
	return backend->id;
}

const char * backend_get_name(struct Backend * backend)
{
	return backend->name;
}
