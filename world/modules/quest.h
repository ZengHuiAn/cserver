#ifndef _SGK_MODULE_QUEST_H_
#define _SGK_MODULE_QUEST_H_ 

#include "player.h"
#include "data/Quest.h"

DECLARE_PLAYER_MODULE(quest);

#define QUEST_STATUS_INIT     0
#define QUEST_STATUS_FINISH   1
#define QUEST_STATUS_CANCEL   2
#define QUEST_STATUS_INIT_WITH_OUT_SAVE 0x100

struct Quest * quest_next(struct Player * player, struct Quest * quest);

struct Quest * quest_add(struct Player * player, int id, int status, time_t accept_time);
struct Quest * quest_get(struct Player * player, int id);
int quest_remove(struct Player * player, int id);

void quest_update_status(struct Quest * quest, int status, int record_1, int record_2, int count, int consume_item_save_1, int consume_item_save_2, time_t accept_time, time_t submit_time);

struct amf_value * quest_encode_amf(struct Quest * quest);

#endif
