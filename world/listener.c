
#include <assert.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <libgen.h>

#include "network.h"
#include "base.h"
#include "log.h"
#include "auth.h"
#include "module.h"
#include "mtime.h"
#include "dispatch.h"
#include "xmlHelper.h"
#include "config.h"
#include "protocol.h"

static int64_t g_system_startup_time =0;
static const char *  listen_host = "127.0.0.1";
static int listen_port = 9801;
static int listen_backlog = 100;

static struct network_handler handler = {0};

static void on_accept(struct network * net, resid_t l, resid_t c, void * ctx)
{
	WRITE_INFO_LOG("client %u connected", c);
	start_auth(c);
}

static void on_closed(struct network * net, resid_t c, int error, void * ctx)
{
	WRITE_INFO_LOG("listener %u closed!!!", c);
	if(c == get_gateway_conn()){
		reset_gateway_conn();
	}
}


static unsigned int port_base = 9810;

#define ATOI(x, def) ((x) ? atoi(x) : def)
static int parseListenConfig(xml_node_t * node, void * data)
{
	const char * host = xmlGetValue(xmlGetChild(node, "host", 0), "localhost");

	/*
	unsigned int idx = ATOI(xmlGetAttribute(node, "idx", 0), 0);
	if (idx == 0) {
		WRITE_ERROR_LOG("config idx is missing");
		return -1;
	}
	*/

	int * count = (int*)data;
	int idx = *count + 1;

	unsigned int port = ATOI(xmlGetValue(xmlGetChild(node, "port", 0), 0), port_base + idx);
	unsigned int backlog = ATOI(xmlGetValue(xmlGetChild(node, "backlog", 0), 0), 100);

	if (agN_listen(host, port, backlog, &handler, 0) == INVALID_ID) {
		WRITE_ERROR_LOG("listen_on %s:%d failed: %s",
				host, port, strerror(errno));
		return -1;
	}

	(*count)++;
	WRITE_INFO_LOG("listen_on %s:%d success", host, port);
	return 0;
}

static unsigned int g_wid = 0;

int module_listener_load(int argc, char * argv[])
{
	g_system_startup_time =agT_current();
	if (agN_init(2000) != 0) {
		WRITE_ERROR_LOG("agN_init failed");
		return -1;
	}

	port_base = ATOI(xmlGetValue(agC_get("PortBase"), 0), 9810);

	// start listen
	handler.on_accept = on_accept;
	handler.on_closed = on_closed;

	int i, isdaemon = 0;
	for(i = 1; i < argc; i++) {
		if (strcmp(argv[i], "-wid") == 0) {
			if (i != argc - 1) {
				g_wid = atoi(argv[++i]);
			}
		} else if (strcmp(argv[i], "-d") == 0) {
			isdaemon = 1;
		}
	}

	char wname[64] = {0};
	sprintf(wname, "Cell_%u", g_wid);
	if (g_wid && isdaemon) {
		char logfilename[256];
		sprintf(logfilename, "../log/%s_%u_%%T.log", basename(argv[0]), g_wid);
		agL_open(logfilename, LOG_DEBUG);
	}

	int count = 0;
	xml_node_t * node = agC_get("Cells");
	if (node) {
		const char * cell_name = g_wid ? wname : 0;

		int ret = foreachChildNodeWithName(node, cell_name, parseListenConfig, &count);
		if (ret != 0) {
			return -1;
		}

		if (count == 0) {
			WRITE_ERROR_LOG("not listener config");
			return -1;
		}

	} else {
		if (agN_listen(listen_host, listen_port, listen_backlog, &handler, 0) == INVALID_ID) {
			WRITE_ERROR_LOG("listen_on %s:%d failed: %s",
					listen_host, listen_port, strerror(errno));
			return -1;
		}
		WRITE_INFO_LOG("listen_on %s:%d success", listen_host, listen_port);
	}
	return 0;
}

int module_listener_reload()
{
	return 0;
}

void module_listener_update(time_t now)
{
}

void module_listener_unload()
{
}

int64_t get_system_startup_time(){
	return g_system_startup_time;	
}
