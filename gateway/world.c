#include <assert.h>
#include <string.h>
#include <arpa/inet.h>

#include "world.h"
#include "network.h"
#include "log.h"
#include "package.h"
#include "client.h"

#include "protocol.h"
#include "mtime.h"
#include "map.h"
#include "dlist.h"

//#include "translate.h"
#include "auth.h"

#include "config.h"

#include "amf.h"
#include "backend.h"

typedef struct WorldConfig
{
	char name[64];
	char host[64];
	short port;
	int max_count;

	// update in process
	unsigned int id;
	int ok;
	resid_t conn;
	int player_count;
} WorldConfig;

static WorldConfig world_config [10];

static int max_world_id =  sizeof(world_config) / sizeof(world_config[0]);

static struct network_handler world_handler = {0};


#if 0
static void send_login(struct client * c, void * ctx)
{
/*
	WorldConfig * cfg = (WorldConfig*)cfg;
	if (c->world == INVALID_WORLD_ID || !world_is_valid(c->world)) {
		c->world = world_get_idle_world(c->world);	
		WRITE_INFO_LOG("client %u player %u change to new world %u",
			c->conn, (unsigned int)c->playerid, c->world);
		world_increase_player(c->world);
	}
*/

}
#endif 

static void send_logout_to_backend(unsigned long long playerid)
{
	char msg[4096] = {0};
	size_t offset = 0;

	//array
	offset += amf_encode_array(msg + offset, sizeof(msg) - offset, 2);

	//sn
	offset += amf_encode_integer(msg + offset, sizeof(msg) - offset, 0);

	// reason
	offset += amf_encode_integer(msg + offset, sizeof(msg) - offset, 1);

	unsigned int cmd  = C_LOGOUT_REQUEST;

	// 登出请求发给所有后端
	backend_broadcast(playerid, cmd, 1, msg, offset);
}
static void append_player(struct client * c, void * ctx)
{
	// struct Backend * peer = (structBackend*)cfg;
	struct pbc_wmessage * request = (struct pbc_wmessage*)ctx;
	if (c->playerid > 0) {
		WRITE_DEBUG_LOG("append %llu to players", c->playerid);
		pbc_wmessage_integer(request, "players", c->playerid, 0);
	}
}

static void on_connected(struct network * net, resid_t c, void * ctx)
{
	WorldConfig * cfg = (WorldConfig*)ctx;
	cfg->ok= 1;
	cfg->max_count = 2000;
	WRITE_INFO_LOG("cell %s(%u) with connection %u connected",
			cfg->name, cfg->id, c);

	// TODO:  send login to world
	// client_foreach(send_login, cfg);


	// 注册服务, 附带当前在线人数
	struct pbc_wmessage * request = protocol_new_w("ServiceRegisterRequest");
	pbc_wmessage_string(request, "type", "GATEWAY", 0);

	// TODO:  send login to world
	client_foreach(append_player, request);

	struct pbc_slice slice;
	pbc_wmessage_buffer(request, &slice);
	world_send_message(cfg->id, 0, S_SERVICE_REGISTER_REQUEST, 2, slice.buffer, slice.len);
	pbc_wmessage_delete(request);
}

static void on_closed(struct network * net, resid_t c, int error, void * ctx)
{
	WorldConfig * cfg = (WorldConfig*)ctx;
	WRITE_WARNING_LOG("cell %s(%u) with connection %u closed",
			cfg->name, cfg->id, c);
	cfg->ok = 0;
	cfg->conn = INVALID_ID;
	cfg->player_count = 0;
	cfg->max_count = 0;
	cfg->id += max_world_id;
	if (cfg->id == INVALID_WORLD_ID) {
		cfg->id += max_world_id;
	}
}

static void translate_to_client(struct translate_header * header);

static void broadcast_to_client(unsigned int world, struct pbc_rmessage * request)
{
	unsigned int sn = pbc_rmessage_integer(request, "sn", 0, 0);
	unsigned int cmd = pbc_rmessage_integer(request, "cmd", 0, 0);
	unsigned int flag = pbc_rmessage_integer(request, "flag", 0, 0);

	// broadcast
	int sz;
	const char * ptr = pbc_rmessage_string(request, "msg", 0, &sz);
	unsigned int i, n = pbc_rmessage_size(request, "pid");
	if (n == 0) {
		client_broadcast(cmd, flag, ptr, sz);
	} else {
		for(i = 0; i < n; i++) {
			unsigned long long pid = (unsigned long long)pbc_rmessage_real(request, "pid", i);
			client * c = client_get_by_playerid(pid);
			if (c) client_send(c, cmd, flag, ptr, sz);
		}
	}
	
	// respond
	struct pbc_wmessage * respond = protocol_new_w("ServiceBroadcastRespond");
	pbc_wmessage_integer(respond, "sn", sn, 0);
	pbc_wmessage_integer(respond, "result", RET_SUCCESS, 0);
	struct pbc_slice slice;
	pbc_wmessage_buffer(respond, &slice);
	world_send_message(world, 0, S_SERVICE_BROADCAST_RESPOND, 2, slice.buffer, slice.len);
	pbc_wmessage_delete(respond);
}
static size_t process_message(struct network * net, resid_t conn,
		const char * msg, size_t len,
		void * ctx)
{

	WorldConfig * cfg = (WorldConfig*)ctx;

	if (len < sizeof(struct translate_header)) {
		return 0;
	}

	struct translate_header * header = (struct translate_header*) msg;
	size_t package_len = ntohl(header->len);
	if (len < package_len) {
		return 0;
	}
	unsigned int command = ntohl(header->cmd);
	unsigned long long playerid = ntohl(header->playerid);
	unsigned int serverid = ntohl(header->serverid);
	NTOHL_PID_AND_SID(playerid, serverid);
	const char * data = ((const char*)header) + sizeof(struct translate_header);
	const size_t data_len = len - sizeof(struct translate_header);
	WRITE_DEBUG_LOG("cell(%u) -> player(%llu)  command %u", cfg->id, playerid, command);

	if (command == S_SERVICE_BROADCAST_REQUEST) {
		WRITE_DEBUG_LOG("cell(%u) broad cast", cfg->id);
		if (playerid != 0) {
			// failed
			WRITE_DEBUG_LOG("    channel != 0, drop");
			return package_len;
		}

		struct pbc_rmessage * request = protocol_new_r("ServiceBroadcastRequest", data, data_len);
		if (request != 0) {
			broadcast_to_client(cfg->id, request);
			pbc_rmessage_delete(request);
		}
		return package_len;
	}

	translate_to_client(header);

	return package_len;
}


static unsigned int port_base = 9810;

#define ATOI(x, def) ((x) ? atoi(x) : (def))

static int parseWorldConfig(xml_node_t * node, void * data)
{
/*
	unsigned int idx = ATOI(xmlGetAttribute(node, "idx", 0), 0);
	if (idx == 0 || idx > 10) {
		WRITE_ERROR_LOG("cell config error, idx miss");
		return -1;
	}
*/
	unsigned int idx = 0;
	int i = 0;
	for(i = 0;  i < max_world_id; i++) {
		if (world_config[i].port == 0) {
			idx = i+1;
			break;
		}
	}

	if (idx == 0) {
		WRITE_ERROR_LOG("too many cells");
	}

	unsigned int port = ATOI(xmlGetValue(xmlGetChild(node, "port"), 0), port_base + idx);
	if(port == 0) {
		WRITE_ERROR_LOG("cell config error, port error");
		return -1;
	}

	WorldConfig * cfg = world_config + idx - 1;
	if (cfg->port != 0) {
		WRITE_ERROR_LOG("more than one cell with same idx %u", idx);
	}
	//cfg->id = idx;

	strcpy(cfg->name, xmlGetName(node));

	strcpy(cfg->host, xmlGetValue(xmlGetChild(node, "host", 0), "localhost"));
	cfg->port = port;
	cfg->max_count = ATOI(xmlGetValue(xmlGetChild(node, "max", 0), 0), 2000);

	return 0;
}

int module_world_load(int argc, char * argv[])
{
	port_base = ATOI(xmlGetValue(agC_get("PortBase"), 0), 9810);

	memset(&world_handler, 0, sizeof(world_handler));
	world_handler.on_message = process_message;
	world_handler.on_connected = on_connected;;
	world_handler.on_closed = on_closed;

	memset(world_config, 0, sizeof(world_config));

	xml_node_t * root = agC_get("Cells");
	if (root == 0) {
		strcpy(world_config[0].name, "Cell_1");
		strcpy(world_config[0].host, "localhost");
		world_config[0].port = port_base + 1;
		world_config[0].max_count = 200;
		world_config[0].id = 1;
	} else {
		if(foreachChildNodeWithName(root, 0, parseWorldConfig, 0) != 0) {
			return -1;
		}
	}

	int i = 0;
	for(i = 0; i < max_world_id; i++) {
		WorldConfig * cfg = world_config + i;
		if (cfg->port == 0) {
			continue;
		}

		WRITE_INFO_LOG("cell %s(%u) %s:%u connecting",
			cfg->name, cfg->id, cfg->host, cfg->port);

		cfg->ok = 0;
		cfg->player_count = 0;
		cfg->id = i;
		if (cfg->id == INVALID_WORLD_ID) {
			cfg->id += max_world_id;
		}
		world_config[i].conn = agN_connect(cfg->host, cfg->port, 5, &world_handler, cfg);
	}
	return 0;
}

int module_world_reload()
{
	return 0;
}

void module_world_update(time_t now)
{
	int i = 0;
	for(i = 0; i < max_world_id; i++) {
		WorldConfig * cfg = world_config + i;
		if (cfg->port == 0) {
			continue;
		}

		if (cfg->conn == INVALID_ID) {

			WRITE_INFO_LOG("cell %s(%u) %s:%u reconnecting",
					cfg->name, cfg->id, cfg->host, cfg->port);
			world_config[i].conn = agN_connect(cfg->host,
					cfg->port,
					5, &world_handler, cfg);
		}
	}
}
void module_world_unload()
{
	int i = 0;
	for(i = 0; i < max_world_id; i++) {
		WorldConfig * cfg = world_config + i;
		if (cfg->port == 0) {
			continue;
		}
		
		WRITE_INFO_LOG("close connect to cell %s", cfg->name);
		agN_close(cfg->conn);
		cfg->id += max_world_id;
		if (cfg->id == INVALID_WORLD_ID) {
			cfg->id += max_world_id;
		}
	}
}

unsigned int world_get_idle_world(unsigned long long pid)
{
	unsigned int wcount = 0;
	int i = 0;
	for(i = 0;  i < max_world_id; i++) {
		if (world_config[i].port == 0) {
			break;
		}
		wcount ++;
	}
	return world_config[pid % wcount].id;
/*
	if (old != INVALID_WORLD_ID) {
		int real_pos = old % max_world_id;
		int new_id = world_config[real_pos].id;
		if(world_is_valid(new_id) && 
			world_config[real_pos].max_count
				> world_config[real_pos].player_count) {
			return new_id;
		}
	}

	int min_world = -1;
	int i;
	for(i = 0; i < max_world_id; i++) {
		if(!world_is_valid(world_config[i].id)) {
			continue;
		}

		if (min_world == -1 || 
				world_config[min_world].player_count
				> world_config[i].player_count) {
			min_world = i;
		}
	}
	if (min_world == -1) {
		return INVALID_WORLD_ID;
	}
	return world_config[min_world].id;
*/
}

int world_increase_player(unsigned int world)
{
	unsigned int real = world % max_world_id;
	world_config[real].player_count++;
	return 0;
}

int world_reduce_player(unsigned int world)
{
	int real = world % max_world_id;
	if (world_config[real].player_count > 0) {
		world_config[real].player_count--;
	}
	return 0;
}

int world_is_valid(unsigned int world)
{
	int real = world % max_world_id;
	if (world != world_config[real].id) {
		return 0;
	}
	
	return (world_config[real].conn != INVALID_ID
			&& world_config[real].ok);
}

//int world_send_message(unsigned int world, const void * msg, int len)

int world_send_message(unsigned int world, unsigned long long playerid, unsigned int cmd, unsigned int flag, const void * msg, int len)
{
	if(!world_is_valid(world)) {
		return -1;
	}

	WRITE_DEBUG_LOG("player(%llu) -> cell(%u)  command %u", playerid, world, cmd);


	int real = world % max_world_id;
	WorldConfig * cfg = world_config + real;

	//WRITE_DEBUG_LOG("send %d byte(s) to world %d", len, world);
	struct translate_header theader;
	unsigned int sid = 0;
	TRANSFORM_PLAYERID(playerid, 1, sid);
	theader.serverid = htonl(sid);
	theader.len = htonl(sizeof(theader) + len);
	theader.playerid = htonl(playerid);
	theader.flag = htonl(flag);
	theader.cmd  = htonl(cmd);

	struct iovec iov[2];
	iov[0].iov_base = &theader;
	iov[0].iov_len  = sizeof(theader);

	iov[1].iov_base = (char*)msg;
	iov[1].iov_len  = len;

	return agN_writev(cfg->conn, iov, 2);
}

static void translate_to_client(struct translate_header * header)
{
	size_t len = ntohl(header->len);
	unsigned long long playerid = ntohl(header->playerid);
	unsigned int serverid = ntohl(header->serverid);
	NTOHL_PID_AND_SID(playerid, serverid);

	const char * msg = ((const char*)header)
		+ sizeof(struct translate_header);
	size_t msg_len = len - sizeof(struct translate_header);

	unsigned int flag = ntohl(header->flag);
	unsigned int cmd  = ntohl(header->cmd);

	client * c = client_get_by_playerid(playerid);
	if (c == 0 || c->conn == INVALID_ID) {
		WRITE_WARNING_LOG("send %lu byte(s) to closed player %u",
			msg_len, (unsigned int)playerid);
		return;
	}

	struct client_header h;
	h.len =  htonl(msg_len + sizeof(h));
	h.flag = ntohl(flag);
	h.cmd = header->cmd;

	if(cmd!=C_LOGIN_RESPOND) {
		struct iovec iov[2];
		iov[0].iov_base = &h;
		iov[0].iov_len  = sizeof(h);

		iov[1].iov_base = (char*)msg;
		iov[1].iov_len  = msg_len;

		agN_writev(c->conn, iov, 2);
	}

	if (cmd == C_LOGIN_RESPOND || cmd == C_CREATE_PLAYER_RESPOND) {
		// 读取返回result
		size_t sz = 0;
		size_t offset = 0;
		offset += amf_decode_array(msg + offset, msg_len - offset, &sz);
		assert(sz >= 2);
		
		uint32_t sn = 0;
		offset += amf_decode_integer(msg + offset, msg_len - offset, &sn);

		uint32_t result = 0;
		offset += amf_decode_integer(msg + offset, msg_len - offset, &result);

		if(cmd == C_LOGIN_RESPOND){
			//// prepare buff
			char buff[1024] = {0};
			offset = 0;
			offset += amf_encode_array(buff + offset, sizeof(buff) - offset, 4);

			// sn
			offset += amf_encode_integer(buff + offset, sizeof(buff) - offset, sn);

			// result
			offset += amf_encode_integer(buff + offset, sizeof(buff) - offset, result);

			// playerid

			offset += amf_encode_double(buff + offset, sizeof(buff) - offset, playerid);

			// account
			if(result == RET_SUCCESS || result==RET_CHARACTER_NOT_EXIST){
				account* acc =account_get_by_pid(playerid);
				if(acc){
					offset += amf_encode_string(buff + offset, sizeof(buff) - offset, acc->name, 0);
				}
				else{
					offset += amf_encode_string(buff + offset, sizeof(buff) - offset, "", 0);
				}
			}

			h.len = htonl(sizeof(h) + offset);

			//// send
			struct iovec iov[2];
			iov[0].iov_base = &h;
			iov[0].iov_len  = sizeof(h);

			iov[1].iov_base = (char*)buff;
			iov[1].iov_len  = offset;

			agN_writev(c->conn, iov, 2);
		}
		if (result == 0) {
			// 登录成功，或者创建角色成功，通知其他服务器
			char buff[1024] = {0};
			offset = 0;
			offset += amf_encode_array(buff + offset, sizeof(buff) - offset, 5);

			// sn
			offset += amf_encode_integer(buff + offset, sizeof(buff) - offset, 0);

			// account
			offset += amf_encode_string(buff + offset, sizeof(buff) - offset, "", 0);

			// token
			offset += amf_encode_string(buff + offset, sizeof(buff) - offset, "", 0);

			// vip
			offset += amf_encode_integer(buff + offset, sizeof(buff) - offset, c->vip);

			// vip2
			offset += amf_encode_integer(buff + offset, sizeof(buff) - offset, c->vip2);

			backend_broadcast(c->playerid, C_LOGIN_REQUEST, 1, buff, offset);
		}
		else{
			if(cmd == C_LOGIN_RESPOND){
				if(result != RET_CHARACTER_NOT_EXIST){
					// 登录失败，且不是未创建角色
					start_auth(c->conn);
					return;
				}
			}
		}

		if (cmd == C_LOGIN_RESPOND && result == RET_CHARACTER_NOT_EXIST) {
			// add to creating list
		}

		if (cmd == C_CREATE_PLAYER_RESPOND && result == RET_SUCCESS) {
			//  remove from creating list
		}
	}

	//玩家登出了, 
	if (cmd == C_LOGOUT_RESPOND) {
		WRITE_DEBUG_LOG("recv LOGOUT respond of player %llu from server, send to conn %u", playerid, c->conn);
		// start_auth(c->conn);
		agN_close(c->conn);
        send_logout_to_backend(c->playerid);
		client_free(c);
	}
}
