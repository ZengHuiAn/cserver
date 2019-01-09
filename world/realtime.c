#include <assert.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <libgen.h>

#include "realtime.h"
#include "log.h"
#include "config.h"
#include "map.h"
#include "player.h"

static struct map * online_map = 0;

static unsigned int server_id = 0;
// static unsigned int server_type = 0;
static unsigned int interval = 60;

int module_realtime_load(int argc, char * argv[]) 
{
	xml_node_t * node = agC_get(0);

	server_id = atoi(xmlGetAttribute(node, "id", "0"));
	interval = atoi(xmlGetValue(xmlGetChild(node, "Log", "Realtime", "Interval", 0), "60"));

	online_map = _agMap_new(0);	
	return 0;
}

int module_realtime_reload()
{
	xml_node_t * node = agC_get(0);
	server_id = atoi(xmlGetAttribute(node, "id", "0"));
	interval = atoi(xmlGetValue(xmlGetChild(node, "Log", "Realtime", "Interval", 0), "60"));
	if (interval <= 10) {
		interval = 10;
	}

	return 0;
}

void module_realtime_update(time_t now)
{
	if (now % interval == 0) {
		agL_write_user_logger(ONLINE_LOGGER, LOG_FLAT, "%d,%d", (int)now, (int)_agMap_size(online_map));
	}
}

void module_realtime_unload()
{
	_agMap_delete(online_map);
}

void realtime_online_add(unsigned long long id)
{
	if (id > AI_MAX_ID) {
		_agMap_ip_set(online_map, id, (void*)1);
	}
}

void realtime_online_remove(unsigned long long id)
{
	_agMap_ip_set(online_map, id, 0);
}


void realtime_online_clean()
{
	_agMap_delete(online_map);
	online_map = _agMap_new(0);	
}

unsigned int realtime_online_count()
{
	return _agMap_size(online_map);
}
