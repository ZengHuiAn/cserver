#include <assert.h>
#include <string.h>

#include "log.h"
#include "auth.h"
#include "network.h"

#include "dispatch.h"

static struct network_handler auth_handler = {0};

#if 0
#pragma pack(push, 1)

struct package_header {
	uint32_t len;
	uint32_t conn;

	uint32_t len;
	uint32_t sn;
	uint32_t command;
};

struct c2g_login_request {
	struct package_header header;
	char account[32];
	char auth[128];
};

struct c2g_login_respond {
	struct package_header header;
	int32_t result;
	uint32_t playerid;
};

#pragma pack(pop)

#endif
#define TYPE_CAST(type, req, data) \
	struct type  * req = (struct type*)data

static size_t process_message(struct network * net, resid_t conn,
		const char * data, size_t len,
		void * ctx)
{
/*
	WRITE_WARNING_LOG("client %u echo %lu", conn, len);
	conn_send(conn, data, len);
*/
	start_dispatch(conn);
	return 0;
}

static void on_closed(struct network * net, resid_t conn, int error, void * ctx)
{
}

void start_auth(resid_t conn)
{
	auth_handler.on_message = process_message;
	auth_handler.on_closed = on_closed;
	agN_set_handler(conn, &auth_handler, 0);
}
