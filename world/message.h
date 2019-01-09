#ifndef _A_GAME_WORLD_MESSAGE_H_
#define _A_GAME_WORLD_MESSAGE_H_

#include <stdint.h>

#include "network.h"
#include "player.h"
#include "amf.h"
#include "protocol.h"

int send_message(resid_t conn, unsigned long long playerid, uint32_t cmd, uint32_t flag, const char * data, size_t len);
int send_message_to(unsigned long long playerid, uint32_t cmd, uint32_t flag, const char * data, size_t len);

int send_amf_message(resid_t conn, unsigned long long playerid, uint32_t cmd, amf_value * v);
int send_amf_message_to(unsigned long long playerid, uint32_t cmd, amf_value * v);
//int send_amf_message_v(resid_t conn, unsigned long long playerid, uint32_t cmd, uint32_t sn, uint32_t result, ...);

int send_pbc_message(resid_t conn, unsigned long long playerid, uint32_t cmd, struct pbc_wmessage * msg);
int send_pbc_message_to(unsigned long long playerid, uint32_t cmd, struct pbc_wmessage * msg);

#endif
