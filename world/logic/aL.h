#ifndef _A_GAME_WORLD_LOGIC_H_
#define _A_GAME_WORLD_LOGIC_H_

#include "player.h"

const char * aL_lasterror();
int aL_login(unsigned long long playerid, const char * token, const char * account);
int aL_logout(unsigned long long playerid);

int aL_create_player(unsigned long long playerid, const char * name, int head);

unsigned int aL_receive_reward(Player * player, unsigned int from, struct RewardContent * content, size_t n);
int sendReward(Player * player, unsigned long long hero_uuid, const char* name, int32_t manual, int32_t limit, int32_t reason, int32_t cnt, ...);
int CheckAndConsume(Player * player, unsigned int type, unsigned int id, unsigned long long uuid, unsigned int value, unsigned int reason);
int CheckForConsume(Player * player, unsigned int type, unsigned int id, unsigned long long uuid, unsigned int value);

struct Hero * aL_hero_add(Player * player, unsigned int gid, int reason);
int aL_hero_level_up(Player * player, unsigned gid, int count, unsigned long long uuid);
int aL_hero_add_exp(Player * player, unsigned int gid, int exp, int reson, int type, unsigned long long uuid);
int aL_hero_star_up(Player * player, unsigned int gid, int type, unsigned long long uuid, int * old_star);
int aL_hero_stage_up(Player * player, unsigned int gid, int type, unsigned long long uuid, int * old_stage);
int aL_hero_stage_slot_unlock(Player * player, unsigned int gid, int index, int type, unsigned long long uuid);
int aL_hero_update_fight_formation(Player * player, unsigned int gid, int new_place, unsigned long long uuid);
int aL_hero_select_skill(Player * player, unsigned long long uuid, int group, int skill1, int skill2, int skill3, int skill4, int skill5, int skill6);
int aL_hero_add_exp_by_item(Player * player, unsigned long long uuid, int type, int cfg_id);

int aL_hero_item_set(Player *player, unsigned long long uuid, unsigned id, int status);
int aL_hero_get_fashion_id(unsigned long long pid, unsigned long long uuid, int * fashion_id);

int aL_check_openlev_config(Player * player, int id);

const char * aL_talent_get_data(Player * player, int type, unsigned long long id, int refid, unsigned long long * uuid, int * real_type);
int aL_talent_reset(Player * player, int type, unsigned long long id, int refid);
int aL_talent_update(Player * player, int type, unsigned long long id, int refid, const char * data);

long long aL_get_player_power(Player * player);


int aL_equip_add(Player * player, int gid, int * id, int * quality, unsigned long long * uuid);
int aL_equip_delete(Player * player, unsigned long long uuid, int reason, int payback_flag, struct RewardItem * items, int nitem);
int aL_equip_level_up(Player * player, unsigned long long uuid, int level, int exp);
int aL_equip_stage_up(Player * player, unsigned long long uuid);
int aL_equip_eat(Player * player, unsigned long long dest, unsigned long long src);
int aL_equip_replace_property(Player * player, unsigned long long uuid, int index, int property_item_id);
int aL_equip_refresh_property(Player * player, unsigned long long uuid, int index, int confirm, int * out_scrollid, int * out_value);
int aL_equip_update_fight_formation(Player * player, unsigned long long uuid, int heroid, int new_place, unsigned long long hero_uuid);
int aL_equip_affix_grow(Player * player, unsigned long long uuid, int count);
int aL_equip_decompose(Player * player, unsigned long long uuid, struct RewardItem * items, int nitem);

int aL_quest_accept(Player * player, int id, int from_client);
int aL_quest_cancel(Player * player, int id, int from_client);
int aL_quest_submit(Player * player, int id, int rich_reward, int from_client, int selected_next_quest_id);
int aL_quest_on_event(Player * player, int type, int id, int count);
int aL_update_quest_status(struct Quest * quest, struct QuestConfig * cfg);
//gm
int aL_quest_gm_force_submit(Player * player, int id);

/* open item_package */
int32_t aL_open_item_package(Player* player, int32_t id, int32_t reason, int32_t* depth, struct RewardItem * record, int nitem);

int aL_pve_fight_is_open(Player * player, int gid);
int aL_pve_fight_prepare(Player * player, int gid, int auto_fight, int yjdq, char * buffer);
int aL_pve_fight_confirm(Player * player, int gid, int star, unsigned long long * heros, int nhero, struct RewardItem *items, int nitem);
int aL_pve_fight_fast_pass(Player * player, unsigned int id, int count, struct RewardItem * items, int nitem);

int aL_pve_fight_reset_count(Player * player, int gid, int battle, int chapter);

int aL_change_nick_name(Player * player, const char * nick, int head, int title);

int aL_tick(Player * player);


int aL_recv_one_time_reward(Player * player, unsigned int id);

struct DropInfo {
	int id;
	int level;
};

int aL_send_drop_reward(Player * player, DropInfo * drops, int ndrop, struct RewardItem * items,  int nitem, unsigned long long * heros, int nhero, uint32_t first_time, uint32_t send_reward, unsigned int reason); 

int aL_add_buff(unsigned long long playerid, unsigned int buff_id, int buff_value);
int aL_remove_buff(unsigned long long playerid, unsigned int buff_id, int buff_value);

int aL_draw_compen_item(Player *player, time_t time, struct RewardItem *rewards, int size);

void aL_save_hero_capacity_to_check_data(Player * player, struct HeroCapacity * hero_list, int nheros);

int get_total_talent_count(Player * player, int type, unsigned long long id);

int aL_equip_sell_to_system(Player * buyer, int equip_gid, unsigned long long equip_uuid, struct RewardItem * consume, int n, unsigned int reason);
int aL_equip_buy_from_system(Player * buyer, int equip_gid, unsigned long long equip_uuid, struct RewardItem * consume, int n, unsigned int reason);
#endif
