#ifndef _SGK_MODULES_EQUIP_H_
#define _SGK_MODULES_EQUIP_H_

#include "player.h"
#include "data/Equip.h"
#include "data/EquipValue.h"
#include "config/equip.h"

DECLARE_PLAYER_MODULE(equip);

#define EQUIP_INTO_BATTLE_MAX 12

struct EquipAffixInfo {
	int id;
	int value;
	int grow;
};

amf_value * build_equip_message(struct Equip * equip);

struct Equip * equip_get(Player * player,  unsigned long long uuid);
struct Equip * equip_next(Player * player,  struct Equip * ite);
struct Equip * equip_get_by_hero(Player * player, unsigned long long hero_uuid, int pos);


struct Equip * equip_add(Player * player, int gid, struct EquipAffixInfo affix[EQUIP_PROPERTY_POOL_MAX], int exp);
int            equip_change_exp(struct Equip * equip, int exp);
int            equip_change_gid(struct Equip * equip, int gid);
int            equip_delete(Player * player, struct Equip * equip, int reason);


int  equip_change_pos(struct Player * player, struct Equip * equip, int heroid, unsigned long long bag, int pos);

int equip_get_affix(struct Equip * equip, int index, int * id, int * value, int * addon);
int equip_update_affix(struct Equip * equip, int index, int id, int value, int addon);


struct EquipValue * equip_get_values(struct Player * player, struct Equip * equip);
int equip_add_value(struct Player * player, struct Equip * equip, int type, int id, int value);
int equip_trade(Player * seller, Player * buyer, struct Equip * equip);

#endif
