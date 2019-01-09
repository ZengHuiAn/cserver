#ifndef _SGK_CONFIG_COMMON_H_
#define _SGK_CONFIG_COMMON_H_

#include "config_type.h"

#define STAGE_UP_BEGIN 100	
#define START_UP_BEGIN 150

typedef struct CommonCfg 
{
	int id;
	int para1;
	int para2;
} CommonCfg;

typedef struct ConsumeCfg 
{
	int id;
	int item_type;
	int item_id;
	int item_value;
} ConsumeCfg;

struct CommonCfg * get_common_config(int id);

struct ConsumeCfg * get_consume_config(int id);

int load_common_config();

#endif // _SGK_CONFIG_COMMON_H_
