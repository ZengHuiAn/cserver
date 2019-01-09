#ifndef _A_GAME_COMM_CONFIG_H_
#define _A_GAME_COMM_CONFIG_H_

#include <stdint.h>
#include "module.h"
#include "xmlHelper.h"

//DECLARE_MODULE(config);

//const char * agC_get(const char * key, ...);
//int agC_get_integer(const char * key, ...);
//
int agC_open(const char * file);
void agC_close();

xml_node_t * agC_get_l(const char * key, ...);

#define agC_get(...) agC_get_l(__VA_ARGS__, (void*)0)

int32_t agC_get_server_id();
int32_t agC_get_version();
int agC_get_integer(const char * key, ...);
const char * agC_get_string(const char * key, ...);

#endif
