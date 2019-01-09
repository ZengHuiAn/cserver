#include <arpa/inet.h>
#include <assert.h>

#include "authserver.h"

#include "network.h"
#include "log.h"
#include "dlist.h"
#include "package.h"
#include "memory.h"
#include "client.h"
#include "config.h"
#include "protocol.h"
#include "map.h"
#include "pbc.h"
#include "amf.h"
#include "md5.h"
#include "mtime.h"
#include "auth.h"
#include "translate.h"

#define AUTH_SERVER_RPC_TIMEOUT 5 // 300秒

#define TYPE_CAST(type, req, data) \
	struct type  * req = (struct type*)(data)

typedef struct tagRPC_DATA{
	struct tagRPC_DATA *prev;
	struct tagRPC_DATA *next;
	unsigned int sn;
	int64_t create_time;
	resid_t conn;
	struct network* net;
	void* package_data;
	size_t package_len;
	unsigned int client_sn;

	char account[128];
	char token[128];
	unsigned long long pid;
	unsigned int serverid;
}RPC_DATA, *PRPC_DATA;

struct AuthServer
{
	char name[256];
	char host[256];
	int  port;
	int  timeout;
	resid_t conn;
};

#define UNUSED(x) ((void)(x))
#define ATOI(x, def) ( (x) ? atoi(x) : (def))

static struct AuthServer g_authserver;
static struct network_handler g_authserver_handler;
static unsigned int g_port_base = 9810;
static struct map * g_rpc_data_table = 0;
static PRPC_DATA g_rpc_data_list;

static void   on_connected(struct network * net, resid_t c, void * ctx);
static void   on_closed(struct network * net, resid_t c, int error, void * ctx);
static size_t on_message(struct network * net, resid_t c, const char * msg, size_t len, void * ctx);

static int32_t authserver_pass(PRPC_DATA rpc);
static int32_t authserver_fail(PRPC_DATA rpc);
static void after_auth(PRPC_DATA rpc);
static unsigned int next_sn();

// module //
int module_authserver_load(int argc, char * argv[])
{
	g_rpc_data_list =0;
	g_rpc_data_table = _agMap_new(0);

	// load config
	g_port_base = ATOI(xmlGetValue(agC_get("PortBase"), 0), 9810);
	memset(&g_authserver, 0, sizeof(g_authserver));
	xml_node_t * node = agC_get("GlobalService", "AuthServer");
	if(!node){
		WRITE_DEBUG_LOG("config missing AuthServer node");
		return -1;
	}

	int id = ATOI(xmlGetAttribute(node, "id", 0), 100);

	strcpy(g_authserver.name, "AuthServer");
	strcpy(g_authserver.host, xmlGetValue(xmlGetChild(node, "host", 0), "localhost"));
	g_authserver.port    = ATOI(xmlGetValue(xmlGetChild(node, "port", 0), 0), g_port_base + id);
	g_authserver.timeout = ATOI(xmlGetValue(xmlGetChild(node, "timeout", 0), 0), 60);
	g_authserver.conn    = INVALID_ID;

	// setup handler
	g_authserver_handler.on_connected = on_connected;
	g_authserver_handler.on_accept = 0;
	g_authserver_handler.on_closed = on_closed;
	g_authserver_handler.on_message = on_message;

	// connect
	WRITE_DEBUG_LOG("authserver %s %s:%u connecting", g_authserver.name, g_authserver.host, g_authserver.port);	
	g_authserver.conn = agN_connect(g_authserver.host, g_authserver.port, g_authserver.timeout, &g_authserver_handler, &g_authserver);
	return 0;
}

int module_authserver_reload()
{
	module_authserver_unload();
	return module_authserver_load(0, 0);
}
void module_authserver_update(time_t now)
{
	if (g_authserver.conn == INVALID_ID) {
		WRITE_INFO_LOG("authserver %s %s:%u reconnecting", g_authserver.name, g_authserver.host, g_authserver.port);	
		g_authserver.conn = agN_connect(g_authserver.host, g_authserver.port, g_authserver.timeout, &g_authserver_handler, &g_authserver);
	}
	while(g_rpc_data_list) {
		if(((int64_t)now - g_rpc_data_list->create_time) >= AUTH_SERVER_RPC_TIMEOUT){
			PRPC_DATA node =g_rpc_data_list;
			WRITE_DEBUG_LOG("authserver auth fail:account =`%s`, token =`%s`", node->account, node->token);	
			dlist_remove(g_rpc_data_list, node);
			_agMap_ip_set(g_rpc_data_table, node->sn, 0);
			respond_auth_fail_and_close(node->conn, node->client_sn, RET_PERMISSION);
			free(node->package_data);
			free(node);
		}
		else{
			break;
		}
	}
}

void module_authserver_unload()
{
	agN_close(g_authserver.conn);

	// clean rpc data
	while(g_rpc_data_list) {
		PRPC_DATA node =g_rpc_data_list;
		dlist_remove(g_rpc_data_list, node);
		free(node->package_data);
		free(node);
	}
	_agMap_delete(g_rpc_data_table);
	g_rpc_data_table =0;
}

static void on_connected(struct network * net, resid_t c, void * ctx)
{
	struct AuthServer* authserver =(struct AuthServer*)ctx;
	WRITE_INFO_LOG("authserver %s connected, register service", authserver->name);	
}

static void on_closed(struct network * net, resid_t c, int error, void * ctx)
{
	struct AuthServer* authserver =(struct AuthServer*)ctx;
	assert(c == authserver->conn);
	authserver->conn =INVALID_ID;
	WRITE_INFO_LOG("authserver %s disconnected, register service", authserver->name);	
}

static size_t on_message(struct network * net, resid_t conn, const char * data, size_t len, void * ctx)
{
	// check & prepare header, body
	if (len < sizeof(struct translate_header)) {
		return 0;
	}

	struct translate_header * tran_info = (struct translate_header*)data;
	size_t package_len = ntohl(tran_info->len);
	if (len < package_len) {
		return 0;
	}

	//uint32_t flag = ntohl(tran_info->flag);
	uint32_t command = ntohl(tran_info->cmd);
	unsigned int serverid = ntohl(tran_info->serverid);
	unsigned long long playerid = ntohl(tran_info->playerid);
	NTOHL_PID_AND_SID(playerid, serverid);

	size_t data_len = package_len;
	data += sizeof(struct translate_header);
	data_len -= sizeof(struct translate_header);

	if (command == S_AUTH_RESPOND) {
		WRITE_DEBUG_LOG("authserver %s auth respond", g_authserver.name);
		if (playerid != 0) {
			// failed
			WRITE_DEBUG_LOG("        channel != 0, drop");
			return package_len;
		}
		// read sn & result
		struct pbc_rmessage * respond = protocol_new_r("AuthRespond", data, data_len);
		const unsigned int sn = pbc_rmessage_integer(respond, "sn", 0, 0);
		const unsigned int result = pbc_rmessage_integer(respond, "result", 0, 0);
		int sz =0;
		const char* account = pbc_rmessage_string(respond, "account", 0, &sz);

		// process
		PRPC_DATA rpc = (PRPC_DATA)_agMap_ip_get(g_rpc_data_table, sn);
		if(rpc){
			if(result == RET_SUCCESS){
				memset(rpc->account, 0, sizeof(rpc->account));
				strncpy(rpc->account, account, 127);
				authserver_pass(rpc);
			}
			else{
				authserver_fail(rpc);
			}
			dlist_remove(g_rpc_data_list, rpc);
			_agMap_ip_set(g_rpc_data_table, rpc->sn, 0);
			free(rpc->package_data);
			free(rpc);
			rpc =0;
		}
		else{
			WRITE_DEBUG_LOG("authserver %s auth fail, rpc `%u` not found", g_authserver.name, sn);
		}
		pbc_rmessage_delete(respond);
	}

	return package_len;
}

int authserver_send(unsigned long long channel,
		unsigned int cmd,
		unsigned int flag, const void * msg, size_t len, unsigned int serverid) 
{
	WRITE_DEBUG_LOG("player(%llu) -> authserver(%s)  command %u, len %zu",
			channel, g_authserver.name, cmd, len);

	struct translate_header theader;
	theader.len = htonl(sizeof(theader) + len);
	theader.playerid = htonl(channel);
	theader.flag = htonl(flag);
	theader.cmd  = htonl(cmd);
	theader.serverid = htonl(serverid);

	WRITE_DEBUG_LOG("len =%u/%u, playerid =%llu, flag =%u, cmd =%u", (unsigned int)len, (unsigned int)(sizeof(theader)+len), channel, flag, cmd);

	struct iovec iov[2];
	iov[0].iov_base = &theader;
	iov[0].iov_len  = sizeof(theader);

	iov[1].iov_base = (char*)msg;
	iov[1].iov_len  = len;

	return agN_writev(g_authserver.conn, iov, 2);
}

int32_t authserver_auth(resid_t conn, const char* account, const char* token, struct network* net, const char* package_data, size_t package_len, unsigned int client_sn, unsigned int serverid) 
{
	// prepare pbc slice
	unsigned int sn =next_sn();
	const char* req_name ="AuthRequest";
	struct pbc_wmessage * request= protocol_new_w(req_name);
	if (request == 0) { 
		WRITE_DEBUG_LOG("build respond message %s failed", req_name); 
		return -1; 
	}
	pbc_wmessage_string(request, "account", account, strlen(account));
	pbc_wmessage_string(request, "token", token, strlen(token));
	pbc_wmessage_integer(request, "sn", sn, 0);

	struct pbc_slice slice;
	pbc_wmessage_buffer(request, &slice);

	WRITE_DEBUG_LOG("authserver start auth: account =`%s`, token =`%s`", account, token);

	// save
	PRPC_DATA rpc =(PRPC_DATA)malloc(sizeof(RPC_DATA));
	memset(rpc, 0, sizeof(RPC_DATA));
	strncpy(rpc->account, account, 127);
	strncpy(rpc->token,   token, 127);
	rpc->conn  =conn;
	rpc->sn    =sn;
	rpc->create_time  =agT_current();
	rpc->net          =net;
	rpc->package_data =malloc(package_len);
	rpc->package_len  =package_len;
	rpc->client_sn    =client_sn;
	rpc->serverid     = serverid;
	memcpy(rpc->package_data, package_data, package_len);

	PRPC_DATA old = (PRPC_DATA)_agMap_ip_set(g_rpc_data_table, sn, rpc);
	if(old){
		free(old->package_data);
		free(old);
		WRITE_ERROR_LOG("wrap round");
	}
	dlist_insert_tail(g_rpc_data_list, rpc);
	start_authserver(conn, rpc);
	int32_t ret =authserver_send(0, S_AUTH_REQUEST, 2, (const char*)slice.buffer, slice.len, serverid);
	pbc_wmessage_delete(request); 
	return ret;
}

static size_t on_message_client(struct network * net, resid_t c, const char * msg, size_t len, void * ctx)
{
	return 0;
}

static void   on_closed_client(struct network * net, resid_t c, int error, void * ctx)
{
	// TODO: remove client
	PRPC_DATA prpc = (PRPC_DATA)ctx;
	prpc->conn = INVALID_ID;
}

void start_authserver(resid_t conn, void* ctx)
{
	static struct network_handler handler;
	handler.on_message = on_message_client;
	handler.on_closed  = on_closed_client;
	agN_set_handler(conn, &handler, ctx);
}

static int32_t authserver_pass(PRPC_DATA rpc){
	after_auth(rpc);
	return 0;
}
static int32_t authserver_fail(PRPC_DATA rpc){
	WRITE_DEBUG_LOG("auth fail, call %s, account =`%s`, token =`%s`", __FUNCTION__, rpc->account, rpc->token);
	respond_auth_fail_and_close(rpc->conn, rpc->client_sn, RET_PERMISSION);
	return 0;
}
static void after_auth(PRPC_DATA rpc){
	resid_t conn     =rpc->conn;
	if(conn == INVALID_ID){
		return;	
	}
	// get pid
	unsigned long long pid =0;
	if(0 != account_parse_pid_by_name(conn, rpc->net, rpc->account, &pid, (char *)rpc->package_data, rpc->package_len, rpc->serverid)){
		WRITE_DEBUG_LOG("auth fail, call account_parse_pid_by_name, account =`%s`, token =`%s`", rpc->account, rpc->token);
		respond_auth_fail_and_close(conn, rpc->client_sn, RET_PERMISSION);
		return;
	}
	rpc->pid =pid;

	// auth last 
	client * c = client_get_by_playerid(pid);
	if (c == 0) {
		c = client_new(conn, -1, pid);
	}
	if (c->conn != conn && c->conn != INVALID_ID) {
		WRITE_DEBUG_LOG("client %u player %llu reconnected,"
				        " old connection %u",
				        conn, c->playerid, c->conn);
		WRITE_DEBUG_LOG("send LOGOUT respond to player %llu on conn %u", c->playerid, c->conn);
		char res_buf[1024] = {0};
		TYPE_CAST(client_header, res_header, res_buf);
		res_header->flag = htonl(1);
		res_header->cmd = htonl(C_LOGOUT_RESPOND);
		size_t offset = sizeof(struct client_header);
		size_t tlen = sizeof(res_buf);
		offset += amf_encode_array(res_buf + offset, tlen - offset, 2);
		offset += amf_encode_integer(res_buf + offset, tlen - offset, 0);
		offset += amf_encode_integer(res_buf + offset, tlen - offset, LOGOUT_ANOTHER_LOGIN);
		res_header->len = htonl(offset);
		agN_send(c->conn, res_buf, offset);
		
		// 该连接重新进入验证状态
		start_auth(c->conn);
	}

	c->conn = conn;
	remove_waiting(conn);
	start_translate(conn, c, rpc->net, rpc->package_data, rpc->package_len);
	WRITE_DEBUG_LOG("auth ok, call %s, account =`%s`, token =`%s`", __FUNCTION__, rpc->account, rpc->token);
}
static unsigned int next_sn(){
	static unsigned int sn =0;
	sn +=1;
	return sn;
}
