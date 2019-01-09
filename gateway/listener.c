
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

#if 0
#include "StrategyConfig.h"
#include "config/general.h"
#include "config/building.h"
#include "config/city.h"
#include "config/equip.h"
#include "config/hero.h"
#include "config/king.h"
#include "config/technology.h"
#include "config/soldier.h"
#include "config/story.h"
#include "config/quest.h"
#include "config/tax.h"
#include "config/farm.h"
#endif
#include "xmlHelper.h"
#include "config.h"

#ifdef __cplusplus
extern "C" {
#endif
#include "pbc.h"
#ifdef __cplusplus
}
#endif

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
}

#define ATOI(x, def) ((x) ? atoi(x) : def)
static int parseListenConfig(xml_node_t * node, void * data)
{
	unsigned int port_base = ATOI(xmlGetValue(agC_get("PortBase"), 0), 9810);
	const char * host = xmlGetValue(xmlGetChild(node, "host", 0), "0.0.0.0");
	unsigned int port = ATOI(xmlGetValue(xmlGetChild(node, "port", 0), 0), port_base);
	unsigned int backlog = ATOI(xmlGetValue(xmlGetChild(node, "backlog", 0), 0), 100);

	if (agN_listen(host, port, backlog, &handler, 0) == INVALID_ID) {
		WRITE_ERROR_LOG("listen_on %s:%d failed: %s",
				host, port, strerror(errno));
		return -1;
	}
	WRITE_INFO_LOG("listen_on %s:%d success", host, port);
	return 0;
}

int module_listener_load(int argc, char * argv[])
{
	int max = agC_get_integer("Gateway", "max", 0);
	if (max <= 0) max = 6000;

	WRITE_DEBUG_LOG("network init with %d", max);

	if (agN_init(max) != 0) {
		WRITE_ERROR_LOG("agN_init failed");
		return -1;
	}

	// start listen
	handler.on_accept = on_accept;
	handler.on_closed = on_closed;

	xml_node_t * node = agC_get(0);
	if (node) {
		int ret = foreachChildNodeWithName(node, "Gateway", parseListenConfig, 0);
		if (ret != 0) {
			return -1;
		}
	} else {
		WRITE_WARNING_LOG("listen on default address");
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
