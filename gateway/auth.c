#include <assert.h>
#include <errno.h>
#include <ctype.h>
#include <string.h>
#include <arpa/inet.h>

#include "log.h"
#include "auth.h"
#include "account.h"
#include "translate.h"
#include "package.h"
#include "protocol.h"
#include "mtime.h"
#include "dlist.h"
#include "map.h"

#include "pbc.h"

#include "amf.h"
#include "md5.h"
#include "authserver.h"

#include "config.h"

static struct network_handler auth_handler;
#define TYPE_CAST(type, req, data) \
	struct type  * req = (struct type*)(data)

int doAuth = -1;

struct waiting_client {
	struct waiting_client * next;
	struct waiting_client * prev;

	resid_t conn;
	time_t start_time;
};

static struct waiting_client * wqueue = 0;
static struct map * wmap = 0;

static void clean_waiting_client()
{
	time_t now = agT_current();
	while(wqueue && now - wqueue->start_time > 10) {
		struct waiting_client * wc =  wqueue;
		dlist_remove(wqueue, wc);
		_agMap_ip_set(wmap, wc->conn, 0);
		agN_close(wc->conn);
		free(wc);
	}
}

static void new_waiting_client(resid_t conn)
{
	clean_waiting_client();

	if (wmap == 0) {
		wmap = _agMap_new(0);
	}

	struct waiting_client * wc = (struct waiting_client*)malloc(sizeof(struct waiting_client));
	wc->next = wc->prev = 0;
	wc->conn = conn;
	wc->start_time = agT_current();

	dlist_insert_tail(wqueue, wc);
	_agMap_ip_set(wmap, conn, wc);
}

void remove_waiting(resid_t conn)
{
	struct waiting_client * wc = (struct waiting_client *)_agMap_ip_get(wmap, conn);
	if (wc) {
		dlist_remove(wqueue, wc);
		_agMap_ip_set(wmap, conn, 0);
		free(wc);
	}
}
/*
static unsigned int authPlayer(const char * token, int * pisAdult, unsigned int * pvip, unsigned int * pvip2) 
{
	if (doAuth == -1) {
		xml_node_t * node =  agC_get("Gateway", "Auth");
		if (node == 0) {
			doAuth = 1;
		} else {
			doAuth = atoi(xmlGetValue(node, "1"));
		}
		WRITE_DEBUG_LOG("doAuth = %d", doAuth);
	}

	unsigned int playerid = 0;
	int isAdult = 0;
	unsigned int vip = 0;
	unsigned int vip2 = 0;

	{
		unsigned int t;
		char adult[32];
		char sign[64];

		char copyToken[1024] = {0};

		if (token) {
			int i;
			for(i = 0; token[i]; i++) {
				if (token[i] == ':') {
					copyToken[i] = '\n';
				} else {
					copyToken[i] = token[i];
				}
			}
		}

		sscanf(copyToken, "%u%s%u%u%s", &t, adult, &vip, &vip2, sign);

		if (doAuth) {
			// TODO: check sign
			char checkinfo[256] = {0};
			size_t l = sprintf(checkinfo, "%u:%s:%u:%u:123456789", t, adult, vip, vip2);
			char md5[64] = {0};
			md5sum(checkinfo, l, md5);

			printf("%s, %s, %s", checkinfo, md5, sign);

			if (strcmp(md5, sign) != 0) {
				return 0;
			}
		}

		isAdult = atoi(adult);
		playerid = t;
	}

	if (pisAdult) *pisAdult = isAdult;
	if (pvip) *pvip = vip;
	if (pvip2) *pvip2 = vip2;
	return playerid;
}
*/
void do_amf_auth(resid_t conn, 
		const char * data, size_t len, struct network* net, const char* package_data, size_t package_len)
{
	size_t read_len = 0;
	amf_value * v = amf_read(data, len, &read_len);
	if (v == 0) {
		WRITE_ERROR_LOG("read amf failed");
		agN_close(conn);
		return;
	} 

	if (read_len != len ) {
		WRITE_ERROR_LOG("client %u amf array decode error", conn);
		agN_close(conn);
		amf_free(v);
		return;
	}

	assert(read_len == len);
	if (amf_type(v) != amf_array ||  amf_size(v) < 3) {
		WRITE_ERROR_LOG("client %u amf array size error", conn);
		agN_close(conn);
		amf_free(v);
		return;
	}

	unsigned int sn = amf_get_integer(amf_get(v, 0));
	const char * account_name = amf_get_string(amf_get(v, 1));
	const char * token = amf_get_string(amf_get(v, 2));
	int32_t version = 0;
	if (amf_size(v) > 3) {
		version = amf_get_integer(amf_get(v, 3));
	}

	// check version
	if(agC_get_version() != version){
		respond_auth_fail_and_close(conn, sn, RET_VERSION_MISSMATCH);
		amf_free(v);
		return;
	}

        int serverid = 0;
        if (amf_size(v) >= 4)
        {
                const char * str_sid = amf_get_string(amf_get(v, 4));
                if (str_sid != NULL)
                        serverid = atoi(str_sid);
        }

        serverid = (serverid != agC_get_server_id()) ? agC_get_server_id() : serverid;//不相同就使用服务器配置

	// parse account(to lower)
	char account_name_lower[128] ={0};
	strncpy(account_name_lower, account_name, 127);
	const int account_len =strlen(account_name_lower);
	int i=0;
	for(i=0; i<account_len; i++){
		const char ch =account_name_lower[i];
		if(isupper(ch)){
			account_name_lower[i] =tolower(ch);
		}
	}

	// auth
	if(authserver_auth(conn, account_name_lower, token, net, package_data, package_len, sn, serverid) != 0){
		WRITE_ERROR_LOG("auth fail account =`%s`, token =`%s`", account_name_lower, token);
		respond_auth_fail_and_close(conn, sn, RET_PERMISSION);
	}
	amf_free(v);
}

void respond_auth_fail_and_close(resid_t conn, unsigned int sn, unsigned int result){
	//respond_auth(conn, sn, RET_PREMISSIONS);
	respond_auth(conn, sn, result);
	agN_close(conn);
}
void respond_auth(resid_t conn, unsigned int sn, unsigned int result){
	char res_buf[1024] = {0};
	TYPE_CAST(client_header, res_header, res_buf);
	res_header->flag = htonl(1);
	res_header->cmd = htonl(C_LOGIN_RESPOND);
	size_t offset = sizeof(struct client_header);
	size_t tlen = sizeof(res_buf);
	offset += amf_encode_array(res_buf + offset, tlen - offset, 2);
	offset += amf_encode_integer(res_buf + offset, tlen - offset, sn);
	offset += amf_encode_integer(res_buf + offset, tlen - offset, result);
	res_header->len = htonl(offset);
	agN_send(conn, res_buf, offset);
}
static size_t process_message(struct network * net,
		resid_t conn,
		const char * data, size_t len,
		void * ctx)
{
	assert(len > 0);

 	if (len >= 23 && 
		memcmp(data, "<policy-file-request/>\0", 23) == 0) {
		static const char * policy_file = 
		"<?xml version=\"1.0\"?>"
		"<cross-domain-policy>"
		  "<site-control permitted-cross-domain-policies=\"all\"/>"
		  "<allow-access-from domain=\"*\" to-ports=\"*\"/>"
		"</cross-domain-policy>\0";
		WRITE_DEBUG_LOG("send policy_file:\n%s", policy_file);
		agN_send(conn, policy_file, strlen(policy_file) + 1);
		return 23;
	}

#define TWS_HEAD "tgw_"
	if (len >= strlen(TWS_HEAD) && memcmp(data, TWS_HEAD, strlen(TWS_HEAD)) == 0) {
		int i, j = 0;
		for (i = 0; i < (int)len; i++) {
			if (data[i] == '\n') {
				j++;
				if (j == 3) {
					return i + 1;
				}
			}
		}
		return 0;
	}

	if (len < sizeof(struct client_header)) {
		return 0;
	}

	struct client_header * c_header = (struct client_header*)data;

	uint32_t package_len = ntohl(c_header->len);
	printf("package_len %u / %zu\n", package_len, len);
	if (package_len > len) {
		return 0;
	}

	uint32_t flag = ntohl(c_header->flag);
	uint32_t cmd = ntohl(c_header->cmd);
	printf("cmd = %u\n", cmd);

	if (cmd != C_LOGIN_REQUEST) {
		WRITE_DEBUG_LOG("%s cmt != C_LOGIN_REQUEST", __FUNCTION__);
		agN_close(conn);
		return 0;
	}

	if(flag == 1){
		//char buff[1024] = {0};
		// 转换失败
		WRITE_DEBUG_LOG("%s amf", __FUNCTION__);
		do_amf_auth(conn, data + sizeof(struct client_header), package_len - sizeof(struct client_header), net, data, package_len);
	} else {
		WRITE_DEBUG_LOG("%s unknown flag", __FUNCTION__);
		agN_close(conn);
	}
	return package_len;
}

static void on_closed(struct network * net, resid_t conn, int reason, void * ctx)
{
	assert(ctx == 0);
	if (reason > 0) {
		WRITE_INFO_LOG("* auth * client %u closed: too long message", conn);
	} else if (reason == 0) {
		WRITE_INFO_LOG("* auth * client %u closed: closed by peer", conn);
	} else {
		WRITE_INFO_LOG("* auth * client %u closed: %s", conn, strerror(errno));
	}
}


void start_auth(resid_t conn)
{
	new_waiting_client(conn);

	auth_handler.on_message = process_message;
	auth_handler.on_closed = on_closed;
	agN_set_handler(conn, &auth_handler, 0);
}
