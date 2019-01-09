#include <string.h>

#include "map.h"
#include "channel.h"

static struct map * all_channels = 0;
 
#define CHANNEL_DATA_MAX	128

struct Channel {
	unsigned int channel;
	char account[CHANNEL_DATA_MAX];
	char ip[CHANNEL_DATA_MAX];
};

int module_channel_load(int argc, char * argv[])
{
	return 0;
}

int module_channel_reload()
{
	return 0;
}

void module_channel_update(time_t now)
{
}

static void unload_channel(const char * key, void *p, void * ctx)
{
	free(p);
}

void module_channel_unload()
{
	if (all_channels) {
		_agMap_sp_foreach(all_channels, unload_channel, 0);
		_agMap_delete(all_channels);
		all_channels = 0;
	}
}

static struct Channel * channel_get(unsigned int channel)
{
	if (all_channels) {
		return (struct Channel*)_agMap_ip_get(all_channels, channel);
	}
	return 0;
}

static struct Channel * channel_add(unsigned int channel)
{
	struct Channel * data = (struct Channel*)malloc(sizeof(struct Channel));
	_agMap_ip_set(all_channels, channel, data);
	return data;
}

int channel_record(unsigned int channel, const char * account, const char * ip)
{
	if (all_channels == 0) {
		all_channels = _agMap_new(0);
	}

	struct Channel * ch = channel_get(channel);
	if (_agMap_ip_get(all_channels, channel) == 0) {
		ch = channel_add(channel);
	}

	strncpy(ch->account, account, CHANNEL_DATA_MAX);
	strncpy(ch->ip, ip, CHANNEL_DATA_MAX);

	return 0;
}

void channel_release(unsigned int channel)
{
	if (all_channels) {
		struct Channel * old = (struct Channel*)_agMap_ip_set(all_channels, channel, 0);
		if (old) {
			free(old);
		}
	}
}

void * channel_read(unsigned int channel, char * ip)
{
	struct Channel * ch = channel_get(channel);
	if (ch) {
		if (ip) strcpy(ip, ch->ip);
		return ch->account;
	}
	return 0;
}
