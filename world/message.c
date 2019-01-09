#include <string.h>
#include <arpa/inet.h>

#include "message.h"
#include "package.h"
#include "amf.h"
#include "player.h"
#include "log.h"

int send_message(resid_t conn, unsigned long long playerid, uint32_t cmd, uint32_t flag, const char * data, size_t len)
{
	//char buff[4096] = {0};

	struct translate_header h;

	size_t total_len = sizeof(struct translate_header) + len;

	unsigned int serverid = 0;
	TRANSFORM_PLAYERID(playerid, 1, serverid);
	h.serverid = htonl(serverid);
	h.len = htonl(total_len);
	h.cmd = htonl(cmd);
	h.flag = htonl(flag);
	h.playerid = htonl(playerid);
	h.sn = 0;

	struct iovec iov[2];
	iov[0].iov_base = &h;
	iov[0].iov_len  = sizeof(h);

	iov[1].iov_base = (char*)data;
	iov[1].iov_len  = len;

	// WRITE_DEBUG_LOG("send %lu bytes to conn %u", total_len, conn);

	return agN_writev(conn, iov, 2);
}

int send_message_to(unsigned long long playerid, uint32_t cmd, uint32_t flag, const char * data, size_t len)
{
	resid_t conn = player_get_conn(playerid);
	return send_message(conn, playerid, cmd, flag,  data, len);
}

int send_amf_message(resid_t conn, unsigned long long playerid, uint32_t cmd, amf_value * v)
{
	size_t len = amf_get_encode_length(v);

	/*
	if (len < 4096) {
		len = 4096;
	}
	*/

	if (len > 4096) {
		WRITE_WARNING_LOG("message length > 4096, pid %llu, cmd %u", playerid, cmd);
	}

	char message[len];
	size_t offset = 0;
	offset += amf_encode(message + offset, sizeof(message) - offset, v);
	return send_message(conn, playerid, cmd, 1, message, offset);
}

int send_amf_message_to(unsigned long long playerid, uint32_t cmd, amf_value * v)
{
	resid_t conn = player_get_conn(playerid);
	return send_amf_message(conn, playerid, cmd, v);
}

/*
int send_amf_message_v(resid_t conn, uint32_t playerid, uint32_t cmd, uint32_t sn, uint32_t result, ...)
{
	va_list args;
	va_start(args, result);

	amf_value * v = amf_new_array(0);

	amf_push(v, amf_new_integer(sn));
	amf_push(v, amf_new_integer(result));

	struct amf_value * c = 0;

	while(1) {
		c = va_arg(args, struct amf_value*);
		if (c == 0) {
			break;
		}
		amf_push(v, c);
	}
	va_end(args);

	int ret = send_amf_message(conn, playerid, cmd, v);
	amf_free(v);
	return ret;
}
*/

int send_pbc_message(resid_t conn, unsigned long long playerid, uint32_t cmd, struct pbc_wmessage * msg)
{
	struct pbc_slice slice;
	pbc_wmessage_buffer(msg, &slice);

	return send_message(conn, playerid, cmd, 2, (const char*)slice.buffer, slice.len);
}

int send_pbc_message_to(unsigned long long playerid, uint32_t cmd, struct pbc_wmessage * msg)
{
	resid_t conn = player_get_conn(playerid);
	return send_pbc_message(conn, playerid, cmd, msg);
}
