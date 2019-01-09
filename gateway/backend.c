#include <arpa/inet.h>
#include <assert.h>

#include "backend.h"

#include "network.h"
#include "log.h"
#include "package.h"
#include "memory.h"
#include "client.h"
#include "config.h"
#include "protocol.h"
#include "pbc_int64.h"

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
};

static struct Backend all[MAX_BACK_END];
//static size_t back_end_count = 0;

#define UNUSED(x) ((void)(x))
static struct network_handler backend_handler;

static void   on_connected(struct network * net, resid_t c, void * ctx);
static void   on_closed(struct network * net, resid_t c, int error, void * ctx);
static size_t on_message(struct network * net, resid_t c, const char * msg, size_t len, void * ctx);

#define ATOI(x, def) ( (x) ? atoi(x) : (def))

unsigned int port_base = 9810;

static int parseBackendConfig(xml_node_t * node, void * ctx)
{

	/*
	   <Social>            <!-- social -->
	   <Arena min="200" max="299" id = "11">       <!-- 竞技场 -->
	   <!-- host>localhost</host -->
	   <!-- port>9807</port -->
	   </Arena>

	*/

	unsigned int id  = ATOI(xmlGetAttribute(node, "id",  0), 0);
	unsigned int min = ATOI(xmlGetAttribute(node, "min", 0), 0);
	unsigned int max = ATOI(xmlGetAttribute(node, "max", 0), 0);

	if (id <= 10 || id >= MAX_BACK_END || min == 0 || max < min) {
		WRITE_ERROR_LOG("social config error: id %u min %u max %u", id, min, max);
		return -1;
	}

	struct Backend * ite = all + id - 10;

	ite->cmd.min = min;
	ite->cmd.max = max;
	ite->id = id;

	strcpy(ite->host, xmlGetValue(xmlGetChild(node, "host", 0), "localhost"));
	ite->port = ATOI(xmlGetValue(xmlGetChild(node, "port", 0), 0), port_base + id);
	ite->timeout = ATOI(xmlGetValue(xmlGetChild(node, "timeout", 0), 0), 5);
	ite->conn = INVALID_ID;
	strcpy(ite->name, xmlGetAttribute(node, "name", "UnknownService"));

	return 0;
}

int module_backend_load(int argc, char * argv[])
{
	port_base = ATOI(xmlGetValue(agC_get("PortBase"), 0), 9810);

	memset(&all, 0, sizeof(all));
	xml_node_t * social = agC_get("Social");
	if(foreachChildNodeWithName(social, 0, parseBackendConfig, 0) != 0) {
		WRITE_ERROR_LOG("loadBackendConfig failed");
		return -1;
	}

	backend_handler.on_connected = on_connected;
	backend_handler.on_accept = 0;
	backend_handler.on_closed = on_closed;
	backend_handler.on_message = on_message;

	size_t idx;
	for(idx = 0; idx < MAX_BACK_END; idx++) {
		struct Backend * ite = all + idx;
		if (ite->id == 0) continue;

		WRITE_DEBUG_LOG("backend %s %s:%u connecting", ite->name, ite->host, ite->port);	
		ite->conn = agN_connect(ite->host, ite->port, ite->timeout, &backend_handler, ite);
	}
	return 0;
}

int module_backend_reload()
{
	module_backend_unload();
	return module_backend_load(0, 0);
}

void module_backend_update(time_t now)
{
	size_t idx;
	for(idx = 0; idx < MAX_BACK_END; idx++) {
		struct Backend * ite = all + idx;
		if (ite->id == 0) continue;

		if (ite->conn == INVALID_ID) {
			WRITE_INFO_LOG("backend %s %s:%u reconnecting", ite->name, ite->host, ite->port);	
			ite->conn = agN_connect(ite->host, ite->port, ite->timeout, &backend_handler, ite);
		}
	}
}

void module_backend_unload()
{
	size_t idx;
	for(idx = 0; idx < MAX_BACK_END; idx++) {
		struct Backend * ite = all + idx;
		if (ite->id == 0) continue;

		if (ite->conn != INVALID_ID) {
			agN_close(ite->conn);
		}
	}
}


static void append_player(struct client * c, void * ctx)
{
	// struct Backend * peer = (structBackend*)cfg;
	struct pbc_wmessage * request = (struct pbc_wmessage*)ctx;
	if (c->playerid > 0) {
		WRITE_DEBUG_LOG("append %llu to players", c->playerid);
		pbc_wmessage_int64(request, "players", c->playerid);
	}
}

static void on_connected(struct network * net, resid_t c, void * ctx)
{
	struct Backend * peer = (struct Backend*)ctx;
	WRITE_INFO_LOG("backend %s connect success, register service", peer->name);	

	// 注册服务, 附带当前在线人数
	struct pbc_wmessage * request = protocol_new_w("ServiceRegisterRequest");
	pbc_wmessage_string(request, "type", "GATEWAY", 0);
	pbc_wmessage_integer(request, "id", agC_get_server_id(), 0);

	// TODO:  send login to world
	client_foreach(append_player, request);

	struct pbc_slice slice;
	pbc_wmessage_buffer(request, &slice);
	backend_send(peer, 0, S_SERVICE_REGISTER_REQUEST, 2, slice.buffer, slice.len);
	pbc_wmessage_delete(request);
}

static void on_closed(struct network * net, resid_t c, int error, void * ctx)
{
	struct Backend * peer = (struct Backend*)ctx;
	WRITE_WARNING_LOG("backend %s with connection %u closed", peer->name, c);
	assert(c == peer->conn);
	peer->conn = INVALID_ID;
}

static void broadcast_to_client(struct Backend * peer, struct pbc_rmessage * request)
{
	unsigned int sn = pbc_rmessage_integer(request, "sn", 0, 0);
	unsigned int cmd = pbc_rmessage_integer(request, "cmd", 0, 0);
	unsigned int flag = pbc_rmessage_integer(request, "flag", 0, 0);

	int sz;
	const char * ptr = pbc_rmessage_string(request, "msg", 0, &sz);

	unsigned int i, n = pbc_rmessage_size(request, "pid");
	if (n == 0) {
		client_broadcast(cmd, flag, ptr, sz);
	} else {
		for(i = 0; i < n; i++) {
			unsigned long long pid = (unsigned long long)pbc_rmessage_int64(request, "pid", i);
			client * c = client_get_by_playerid(pid);
			if (c) client_send(c, cmd, flag, ptr, sz);
		}
	}
	
	struct pbc_wmessage * respond = protocol_new_w("ServiceBroadcastRespond");
	pbc_wmessage_integer(respond, "sn", sn, 0);
	pbc_wmessage_integer(respond, "result", RET_SUCCESS, 0);

	struct pbc_slice slice;
	pbc_wmessage_buffer(respond, &slice);

	backend_send(peer, 0, S_SERVICE_BROADCAST_RESPOND, 2, slice.buffer, slice.len);

	pbc_wmessage_delete(respond);
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

	uint32_t flag = ntohl(tran_info->flag);
	uint32_t command = ntohl(tran_info->cmd);
	unsigned long long playerid = ntohl(tran_info->playerid);
	unsigned int serverid = ntohl(tran_info->serverid);
	NTOHL_PID_AND_SID(playerid, serverid);

	size_t data_len = package_len;
	data += sizeof(struct translate_header);
	data_len -= sizeof(struct translate_header);

	if (command == C_LOGOUT_RESPOND) {
		// 丢掉登出消息
		return package_len;
	}

	if (command == S_SERVICE_REGISTER_RESPOND) {
		return package_len;		
	}

	
	if (command == S_SERVICE_BROADCAST_REQUEST) {
		WRITE_DEBUG_LOG("backend %s broad cast", peer->name);
		if (playerid != 0) {
			// failed
			WRITE_DEBUG_LOG("    channel != 0, drop");
			return package_len;
		}

		struct pbc_rmessage * request = protocol_new_r("ServiceBroadcastRequest", data, data_len);
		broadcast_to_client(peer, request); //protocol_new_r("ServiceBroadcastRequest", data, data_len));
		pbc_rmessage_delete(request);
		return package_len;
	}

	client * client = client_get_by_playerid(playerid);
	//resid_t c = player_get_conn(playerid);
	if (client && client->conn != INVALID_ID) {
		WRITE_DEBUG_LOG("backend(%s) -> player(%llu)  command %u, len %zu, conn %u",
				peer->name, playerid, command, data_len, client->conn);
		client_send(client, command, flag, data, data_len);
	} else {
		WRITE_DEBUG_LOG("backend %s send %zu bytes to disconnected player %llu" , peer->name, data_len, playerid);
	}
	return package_len;
}

struct Backend * backend_get(unsigned long long pid, unsigned int cmd)
{
	UNUSED(pid);

	size_t idx;
	for(idx = 0; idx < MAX_BACK_END; idx++) {
		struct Backend * ite = all + idx;
		if (ite->id == 0) continue;

		if (ite->cmd.min <= cmd && ite->cmd.max >= cmd) {
			return ite;
		}
	}
	return 0;
}

int backend_send(struct Backend * peer, unsigned long long channel,
		unsigned int cmd,
		unsigned int flag, const void * msg, size_t len) 
{
	WRITE_DEBUG_LOG("player(%llu) -> backend(%s)  command %u, len %zu",
			channel, peer->name, cmd, len);

	struct translate_header theader;
	unsigned int sid = 0;
	TRANSFORM_PLAYERID(channel, 1, sid);
	theader.serverid = htonl(sid);
	theader.len = htonl(sizeof(theader) + len);
	theader.playerid = htonl(channel);
	theader.flag = htonl(flag);
	theader.cmd  = htonl(cmd);

	struct iovec iov[2];
	iov[0].iov_base = &theader;
	iov[0].iov_len  = sizeof(theader);

	iov[1].iov_base = (char*)msg;
	iov[1].iov_len  = len;

	return agN_writev(peer->conn, iov, 2);
}

/*
int backend_writev(struct Backend * peer, struct iovec *iov, int iovcnt)
{
	WRITE_DEBUG_LOG("send xx byte(s) to backend %s", peer->name);
	return agN_writev(peer->conn, iov, iovcnt);
}
*/

int backend_broadcast(unsigned long long channel, unsigned int cmd, unsigned int flag, const void * msg, size_t len)
{
	WRITE_DEBUG_LOG("broad cast %zu byte(s) to backends, cmd %u, channel %llu", len, cmd, channel);

	struct translate_header theader;
	unsigned int sid = 0;
	TRANSFORM_PLAYERID(channel, 1, sid);
	theader.serverid = htonl(sid);
	theader.len = htonl(sizeof(theader) + len);
	theader.playerid = htonl(channel);
	theader.flag = htonl(flag);
	theader.cmd  = htonl(cmd);

	size_t idx;
	for(idx = 0; idx < MAX_BACK_END; idx++) {
		struct Backend * ite = all + idx;
		if (ite->id == 0) { continue; }

		if (ite->conn != INVALID_ID) {
			struct iovec iov[2];
			iov[0].iov_base = &theader;
			iov[0].iov_len  = sizeof(theader);

			iov[1].iov_base = (char*)msg;
			iov[1].iov_len  = len;

			agN_writev(ite->conn, iov, 2);
		}
	}
	return 0;
}

struct Backend * backend_next(struct Backend * ite) 
{
	if (ite == 0) {
		ite = all;
	} else {
		if (ite < all && ite >= all + MAX_BACK_END) {
			return 0;
		}
		ite = ite + 1;
	}

	while(ite->id == 0 && ite < all + MAX_BACK_END) {
		ite++;
	}

	if (ite >= all + MAX_BACK_END) {
		ite = 0;
	}
	return ite;
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
