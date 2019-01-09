#ifndef _A_GAME_WORLD_REQUEST_AMF_DO_H_
#define _A_GAME_WORLD_REQUEST_AMF_DO_H_

#include <stdint.h>
#include "network.h"
#include "amf.h"

void do_login(resid_t conn, unsigned long long playerid, amf_value * v);
void do_logout(resid_t conn, unsigned long long playerid, amf_value * v);

void do_query_player(resid_t conn, unsigned long long playerid, amf_value * v);
void do_create_player(resid_t conn, unsigned long long playerid, amf_value * v);

//do_item
void do_query_item(resid_t conn, unsigned long long playerid, amf_value * v);

//do_reward
void do_query_reward(resid_t conn, unsigned long long playerid, amf_value * v);
void do_receive_reward(resid_t conn, unsigned long long playerid, amf_value * v);
void do_gm_send_reward(resid_t conn, unsigned long long playerid, amf_value * v);
void do_query_one_time_reward(resid_t conn, unsigned long long playerid, amf_value * v);
void do_recv_one_time_reward(resid_t conn, unsigned long long playerid, amf_value * v);

//do_hero
void do_query_hero(resid_t conn, unsigned long long playerid, amf_value * v);
void do_query_hero_item(resid_t conn, unsigned long long playerid, amf_value * v);
void do_gm_add_hero(resid_t conn, unsigned long long playerid, amf_value * v);
void do_hero_add_exp(resid_t conn, unsigned long long playerid, amf_value * v);
void do_hero_level_up(resid_t conn, unsigned long long playerid, amf_value * v);
void do_hero_star_up(resid_t conn, unsigned long long playerid, amf_value * v);
void do_hero_stage_up(resid_t conn, unsigned long long playerid, amf_value * v);
void do_hero_stage_slot_unlock(resid_t conn, unsigned long long playerid, amf_value * v);
void do_hero_update_fight_formation(resid_t conn, unsigned long long playerid, amf_value * v);
void do_hero_select_skill(resid_t conn, unsigned long long playerid, amf_value * v);
void do_hero_item_set(resid_t conn, unsigned long long playerid, amf_value * v);
void do_hero_add_exp_by_item(resid_t conn, unsigned long long playerid, amf_value *v);

//do_talent
void do_query_talent(resid_t conn, unsigned long long playerid, amf_value * v);
void do_reset_talent(resid_t conn, unsigned long long playerid, amf_value * v);
void do_update_talent(resid_t conn, unsigned long long playerid, amf_value * v);

//fightdata
void do_query_player_power(resid_t conn, unsigned long long playerid, amf_value * v);

//equip
void do_query_equip_info(resid_t conn, unsigned long long playerid, amf_value * v);
void do_equip_level_up(resid_t conn, unsigned long long playerid, amf_value * v);
void do_equip_stage_up(resid_t conn, unsigned long long playerid, amf_value * v);
void do_equip_replace_property(resid_t conn, unsigned long long playerid, amf_value * v);
void do_equip_refresh_property(resid_t conn, unsigned long long playerid, amf_value * v);
void do_equip_update_fight_formation(resid_t conn, unsigned long long playerid, amf_value * v);
void do_equip_eat(resid_t conn, unsigned long long playerid, amf_value * v);
void do_equip_decompose(resid_t conn, unsigned long long playerid, amf_value * v);
void do_equip_affix_grow(resid_t conn, unsigned long long playerid, amf_value * v);

//query otem package 
void do_query_item_package(resid_t conn, unsigned long long playerid, amf_value * v);
void do_query_consume_item_package(resid_t conn, unsigned long long playerid, amf_value * v);

void do_pve_query_fight(resid_t conn, unsigned long long playerid, amf_value * v);
void do_pve_fight_prepare(resid_t conn, unsigned long long playerid, amf_value * v);
void do_pve_fight_check(resid_t conn, unsigned long long playerid, amf_value * v);
void do_pve_fight_fast_pass(resid_t conn, unsigned long long playerid, amf_value * v);
void do_fight_count_reset(resid_t conn, unsigned long long playerid, amf_value *v);

void do_tick(resid_t conn, unsigned long long playerid, amf_value * v);
void do_change_nick_name(resid_t conn,  unsigned long long playerid, amf_value * v);

void do_quest_query_info(resid_t conn, unsigned long long playerid, amf_value * v);
void do_quest_set_status(resid_t conn, unsigned long long playerid, amf_value * v);
void do_quest_on_event(resid_t conn, unsigned long long playerid, amf_value * v);
//for gm
void do_quest_gm_force_set_status(resid_t conn, unsigned long long playerid, amf_value * v);

//title
void do_query_title(resid_t conn, unsigned long long playerid, amf_value * v);

//buff
void do_query_buff(resid_t conn, unsigned long long playerid, amf_value * v);

// compensate item
void do_query_compen_item(resid_t conn, unsigned long long playerid, amf_value * v);
void do_draw_compen_item(resid_t conn, unsigned long long playerid, amf_value * v);

//rank 
void do_query_rank(resid_t conn, unsigned long long playerid, amf_value * v);

//fire
void do_query_fire(resid_t conn, unsigned long long playerid, amf_value * v);

//test
void do_equip_sell_to_system(resid_t conn, unsigned long long playerid, amf_value * v);
void do_equip_buy_from_system(resid_t conn, unsigned long long playerid, amf_value * v);
void do_query_equip_info_by_uuid(resid_t conn, unsigned long long playerid, amf_value * v);

void do_hero_get_fashion(resid_t conn, unsigned long long playerid, amf_value * v);

#endif
