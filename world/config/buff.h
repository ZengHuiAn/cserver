#ifndef _SGK_BUFF_CONFIG_H_
#define _SGK_BUFF_CONFIG_H_

int load_buff_config();
struct BuffConfig * get_buff_config(int buff_id);

#define HERO_PROPERTY_COUNT_BASE  8
struct BuffConfig {
	int buff_id;
	int group;
	int type;
	int value;
	int duration;
	int hero_id;
	time_t end_time;
};

#endif
