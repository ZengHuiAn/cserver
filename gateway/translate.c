#include <arpa/inet.h>

#include <assert.h>
#include <string.h>

#include "log.h"
#include "amf.h"
#include "package.h"

#include "client.h"
#include "translate.h"
#include "auth.h"

#include "world.h"
#include "backend.h"

#include "record.h"

#include "pbc.h"

static struct network_handler translate_handle = {0};

typedef struct translate_header translate_header;

static void send_logout(client * c)
{
	WRITE_DEBUG_LOG("send logout message of player %llu on conn %u to server", c->playerid, c->conn);

	char msg[4096] = {0};
	size_t offset = 0;

	//array
	offset += amf_encode_array(msg + offset, sizeof(msg) - offset, 2);

	//sn
	offset += amf_encode_integer(msg + offset, sizeof(msg) - offset, 0);

	// reason
	offset += amf_encode_integer(msg + offset, sizeof(msg) - offset, 1);

	unsigned int cmd  = C_LOGOUT_REQUEST;

	if (c->world == INVALID_WORLD_ID || !world_is_valid(c->world)) {
		c->world = world_get_idle_world(c->playerid);	
		WRITE_INFO_LOG("client %u player %llu change to new world %u",
			c->conn, c->playerid, c->world);
		world_increase_player(c->world);
	}

	if (c->world == INVALID_WORLD_ID) {
		WRITE_ERROR_LOG("client %u player %llu close:"
				" invalid world %d",
				c->conn, c->playerid, c->world);
		agN_close(c->conn);
		return;
	} 
	
	world_send_message(c->world, c->playerid, cmd, 1, msg, offset);

	// send logout to other system
	// arena_send_message(msg, offset);
	// guild_send_message(msg, offset);
	
	// 登出请求发给所有后端
	backend_broadcast(c->playerid, cmd, 1, msg, offset);

	start_auth(c->conn);

	client_free(c);
}

static int send_backend_message(struct client * c, unsigned int cmd, unsigned int flag, const char * msg, size_t msg_len)
{
	struct Backend * peer = backend_get(c->playerid, cmd);
	if (peer == 0) {
		return 0;
	}

	// send to normal backend
	if (backend_send(peer, c->playerid, cmd, flag, msg, msg_len) < 0) {
		size_t rlen = 0;
		amf_value *  req =  amf_read(msg, msg_len, &rlen);
		if (rlen != msg_len) {
			WRITE_DEBUG_LOG("decode message %u to backend %s failed", cmd, backend_get_name(peer));
			agN_close(c->conn);
			amf_free(req);
			return 1;
		}

		unsigned int sn = 0;
		if (amf_type(req) == amf_array && amf_size(req) >= 1) {
			sn = amf_get_integer(amf_get(req, 0));
		}
		amf_free(req);

		WRITE_DEBUG_LOG("send message %u to backend %s failed, sn = %u", cmd, backend_get_name(peer), sn);

		// 发送失败
		char respond_msg[4096] = {0};
		size_t offset = 0;

		//array
		offset += amf_encode_array(respond_msg + offset, sizeof(respond_msg) - offset, 3);
		//sn
		offset += amf_encode_integer(respond_msg + offset, sizeof(respond_msg) - offset, sn);
		// reason
		offset += amf_encode_integer(respond_msg + offset, sizeof(respond_msg) - offset, RET_SERVICE_STATUS_ERROR);
		// id
		offset += amf_encode_integer(respond_msg + offset, sizeof(respond_msg) - offset, backend_get_id(peer));

		client_send(c, cmd+1, 1, respond_msg, offset);
	}
	return 1;
}

static size_t process_message(struct network * net, 
		resid_t conn,
		const char * data, size_t len,
		void * ctx)
{
	client * c = (client*)ctx;

	// WRITE_DEBUG_LOG("player %u message", c->playerid);

	assert(c && c->conn == conn);

	if (len < sizeof(struct client_header)) {
		return 0;
	}

	struct client_header * h = (struct client_header*)data;
	uint32_t package_len = ntohl(h->len);

	if (len < package_len) {
		return 0;
	}

	uint32_t flag = ntohl(h->flag);
	uint32_t cmd  = ntohl(h->cmd);

	const char * msg = data + sizeof(struct client_header);
	size_t msg_len = package_len - sizeof(struct client_header);

	// 检查协议
	// amf_dump(data, data_len);
	size_t read_len = 0;
	amf_value * v = amf_read(msg, msg_len, &read_len);
	printf("%p  %lu, %lu\n", v, read_len, msg_len);
	if (v == 0 || (read_len != msg_len) || (amf_type(v) != amf_array) ) {
		WRITE_ERROR_LOG("player %u parse amf failed", conn);
		_agN_close(net, c->conn);
		client_free(c);
		if (v) amf_free(v);
		return 0;
	}

	// read ip from proxyserver
	char ip[256];
	ip[0] = 0;
	if (cmd == C_LOGIN_REQUEST && \
		amf_size(v) >= 5 && \
		amf_type(amf_get(v, 4)) == amf_string) {
		const char * str = amf_get_string(amf_get(v, 4));
		if (str && strncmp(str, "ip:", 3) == 0) {
			strncpy(ip, str+3, sizeof(ip));
		}
	}

	if (v) amf_free(v);

	char buff[4096] = {0};

	// 纪录客户端协议类型
	c->protocol_flag = flag;

	switch(flag) {
		case 1: 
			break;
		case 2:
			break;
		default:
			send_logout(c);
			agN_close(conn);
			return 0;
	}


	if (cmd == C_LOGIN_REQUEST) {
		if (ip[0]==0) {
			int fd = _agN_get_fd(net, conn);
			if (fd>=0) {
				// assert(fd >= 0);
				struct sockaddr_in addr;
				memset(&addr, 0, sizeof(addr));
				socklen_t addrlen = sizeof(addr);

				getpeername(fd, (struct sockaddr*)&addr, &addrlen);
				strncpy(ip, inet_ntoa(addr.sin_addr), sizeof(ip));
			}
		}

		// unsigned int port  = ntohs(addr.sin_port);
		unsigned int adult = c->adult;
		unsigned long long pid   = c->playerid;

		// change login message
		size_t offset = 0;
		offset += amf_encode_array(buff + offset, sizeof(buff) - offset, 5);
		// sn
		offset += amf_encode_integer(buff + offset, sizeof(buff) - offset, 0);

		struct account * acc = account_get_by_pid(pid);

		// account
		offset += amf_encode_string(buff + offset, sizeof(buff) - offset, acc ? acc->name : "",  0);

		char xtoken[128] = {0};
		snprintf(xtoken, 128, "%llu:%u:%s", pid, adult, ip);

		// token
		offset += amf_encode_string(buff + offset, sizeof(buff) - offset, xtoken, 0);

		// vip
		offset += amf_encode_integer(buff + offset, sizeof(buff) - offset, c->vip);

		// vip2
		offset += amf_encode_integer(buff + offset, sizeof(buff) - offset, c->vip2);

		msg = buff;
		msg_len = offset;
		flag = 1;
	}

	record(c->playerid, data, package_len);

	if (send_backend_message(c, cmd, flag, msg, msg_len)) {
		return package_len;
	}

	// send to world
	if (c->world == INVALID_WORLD_ID || !world_is_valid(c->world)) {
		c->world = world_get_idle_world(c->playerid);	
		WRITE_INFO_LOG("client %u player %llu change to new world %u",
			conn, c->playerid, c->world);

		world_increase_player(c->world);
	}

	if (c->world == INVALID_WORLD_ID) {
		WRITE_ERROR_LOG("client %u player %llu close:"
				" invalid world %d",
				conn, c->playerid, c->world);
		agN_close(conn);
		return 0;
	} 

	world_send_message(c->world, c->playerid, cmd, flag, msg, msg_len);

	if (cmd == C_LOGOUT_REQUEST) { // || cmd == C_LOGIN_REQUEST) {
		// 登入登出请求发给所有后端
		backend_broadcast(c->playerid, cmd, flag, msg, msg_len);
	}

	return package_len;
}


static void on_closed(struct network * net, resid_t conn, int error, void * ctx)
{
	client * c = (client*)ctx;
	assert(c);
	WRITE_INFO_LOG("* tran * client %u with player %llu(%u) closed",
			conn, c->playerid, c->conn);

	if (conn == c->conn) {
		// 还没有再次登陆上来
		world_reduce_player(c->world);
		send_logout(c);
		//client_free(c);
	} else {
		// 该用户已经登陆进来了
	}
}

void start_translate(resid_t conn, client* c, struct network* net, void* package_data, size_t package_len)
{
	WRITE_DEBUG_LOG("client %u start_translate as %llu to world %d",
			conn, c->playerid, c->world);

	translate_handle.on_message = process_message;
	translate_handle.on_closed = on_closed;
	agN_set_handler(conn, &translate_handle, c);

	// 伪造登陆消息
	process_message(net, conn, (const char*)package_data, package_len, c);
}

#if 0
void translate_to_client(struct translate_header * header)
{
	size_t len = ntohl(header->len);
	uint32_t playerid = ntohl(header->playerid);

	const char * msg = ((const char*)header)
		+ sizeof(struct translate_header);
	size_t msg_len = len - sizeof(translate_header);

	struct client_header h;
	h.len =  htonl(msg_len + sizeof(h));
	h.flag = header->flag;
	h.cmd = header->cmd;

	client * c = client_get_by_playerid(playerid);

	if (c == 0 || c->conn == INVALID_ID) {
		WRITE_WARNING_LOG("send %lu byte(s) to closed player %u",
			msg_len, (unsigned int)playerid);
	} else {
		struct iovec iov[2];
		iov[0].iov_base = &h;
		iov[0].iov_len  = sizeof(h);

		iov[1].iov_base = (char*)msg;
		iov[1].iov_len  = msg_len;

		agN_writev(c->conn, iov, 2);
	}

	unsigned int cmd = ntohl(header->cmd);
	if (cmd == C_LOGOUT_RESPOND) {
		WRITE_DEBUG_LOG("recv LOGOUT respond of player %u from server, send to conn %u", playerid, c->conn);
		start_auth(c->conn);
	}
}
#endif
