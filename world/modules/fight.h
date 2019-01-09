#ifndef _SGK_MODULES_FIGHT_H_
#define _SGK_MODULES_FIGHT_H_

#include "data/Fight.h"
#include "player.h"


DECLARE_PLAYER_MODULE(fight);

int fight_add(Player * player, unsigned int gid, int flag, int star, int count, int fight_time);

int fight_update_player_data(Player * player, struct Fight * fight, int flag, int star, int count);

struct Fight * fight_get(Player * player, int gid);
struct Fight * fight_next(Player * player, struct Fight * ite);

int fight_current_id(Player * player);

int fight_prepare(Player * player, int gid, int limit, int yjdq);
int fight_check(Player * player, int gid, int star);

int fight_result(Player * player, int gid);

void fight_set_daily_count(struct Fight * fight, int count);

// int fight_add_notify(struct Fight * fight);

#endif
