#ifndef _A_GAME_WORLD_PLAYER_H_
#define _A_GAME_WORLD_PLAYER_H_

#include "local.h"

#include "module.h"
#include "network.h"
#include "amf.h"
#include "player_helper.h"

#include "data/PlayerData.h"
#include "data/DataFlush.h"

#define DATA_FLUSH_ALL() DATA_FLUSH_PlayerData()
#define SUPPORT_ZOMBIE_LIST 1
#include <stdint.h>


#define REDEMPTION_MONEY 50
#define AI_MAX_ID  99999 
#define AI_MAX_LEVEL 200 
#define SYSTEM_PID 100000
//#define ALLOC(Type) (struct Type*)malloc(sizeof(struct Type));
//#define ALLOC_N(Type, N) (struct Type*)malloc(sizeof(struct Type) * (N));

struct HeroCapacity {
	struct HeroCapacity * prev;
	struct HeroCapacity * next;
	unsigned long long hero_uuid;
	int capacity;
};

struct CheckData {
	time_t story_time;
	time_t tick_time;
	time_t daily_online_record_time;
    int32_t login_order_flag;

	struct {
		unsigned long long uuid;
		int index;
		int gid;
		int value;
	} affix_refresh_info;

	struct pbc_rmessage * fight_data;
	char * fight_data_src;

	struct HeroCapacity * capacity_list;

	int auto_accept_quest_is_done;
};

#define DECLARE_PLAYER_MODULE(type) 					\
	void   type##_init(); 				                \
	void * type##_new(Player * player); 				\
	void * type##_load(Player * player); 				\
	int    type##_update(Player * player, void * data, time_t now); \
	int    type##_save(Player * player, void * data, 		\
			const char * sql, ...);				\
	int    type##_release(Player * player, void * data); 		

DECLARE_MODULE(player);

enum PLAYER_MODULE {
	PLAYER_MODULE_PROPERTY    = 0,
	PLAYER_MODULE_REQUEST_QUEUE,
	PLAYER_MODULE_ITEM,
	PLAYER_MODULE_BAG,
	PLAYER_MODULE_REWARD,
	PLAYER_MODULE_HERO,
	PLAYER_MODULE_TALENT,
	PLAYER_MODULE_EQUIP,
	PLAYER_MODULE_FIGHT,
	PLAYER_MODULE_DAILY,
	PLAYER_MODULE_HEROITEM,
	PLAYER_MODULE_QUEST,
	PLAYER_MODULE_REWARDFLAG,
	PLAYER_MODULE_BUFF,
	PLAYER_MODULE_FIRE,

	PLAYER_MODULE_COUNT,
};

typedef struct Player Player;

////////////////////////////////////////////////////////////////////////////////

Player * player_create(unsigned long long id, const char * name, int head);
Player * player_get(unsigned long long id);
int      player_is_not_exist(unsigned long long id);

Player * player_get_online(unsigned long long id);
void     player_unload(Player * player);

Player * player_next(Player * player);

unsigned long long player_get_id(Player * player);
unsigned long long player_get_id_by_name(const char * name);
void player_update_name_record(const char * old_name);

int          player_get_country(Player * player);
int          player_get_level(Player * player);
const char * player_get_account(Player * player);
void         player_set_account(Player * player, const char * account);
int          player_get_exp(Player * player);
const char * player_get_name(Player * player);
const char * player_get_bio(Player * player);
int          player_get_head(Player * player);
int          player_get_sex(Player * player);
unsigned long long player_get_guild(Player * player);
void player_set_guild(Player * player, unsigned long long guild);

int          player_change_bio(Player * player, const char * bio);
int          player_change_head(Player * player, unsigned int head);

int          player_set_country(Player * player, unsigned int country);
int64_t 	 player_get_last_tick_time(Player* player);
void 		 player_set_last_tick_time(Player* player, int64_t t);

struct CheckData * player_get_check_data(Player * player);

////////////////////////////////////////////////////////////////////////////////
// module data
void * player_get_module(Player * player, int module);

int player_is_loading(Player * player);

//void player_set_change(Player * player);
////////////////////////////////////////////////////////////////////////////////
// notification
//int player_add_notification(Player * player, Notification * notify);
//int clean_notification();


extern struct Player not_exist_player;

void player_set_conn(unsigned long long playerid, resid_t conn);
resid_t player_get_conn(unsigned long long playerid);
enum{
	ET_PLAYER_CHANGE_EXP 		=1 << 0,
	ET_PLAYER_CHANGE_VIP_EXP 	=1 << 1,
};

void try_add_player_to_zombie_list(Player* player);
void try_remove_player_from_zombie_list(Player* player);
void try_unload_player_from_zombie_list();
Player* get_player_from_zombie_list(unsigned long long pid);
void player_settle(Player* player);

struct reward;
void redemption_set(Player* player, struct reward* reward_list_head);
int32_t redemption_reward(Player* player);
int check_common_limit(Player* player, const int32_t id);


#endif
