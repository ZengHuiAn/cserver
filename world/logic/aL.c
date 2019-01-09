#include <assert.h>
#include <string.h>
#include <errno.h>
#include <math.h>
#include <stdarg.h>

#include "aL.h"

#include "package.h"
#include "log.h"
#include "dlist.h"

#include "modules/property.h"
#include "modules/reward.h"
#include "modules/item.h"
#include "addicted.h"
#include "timeline.h"
#include "database.h"
#include "notify.h"

#include "mtime.h"
#include "timer.h"

//#include "game_config.h"
#include "config.h"
#include "config/general.h"
#include "config/reward.h"
#include "xmlHelper.h"
#include "mfile.h"

#include "event_manager.h"
#include "data/LogData.h"
#include "realtime.h"
#include "addicted.h"
#include "config/str.h"
#include "channel.h"

#include "map.h"
#include "array.h"

#include "data/Hero.h"
#include "modules/hero.h"
#include "modules/hero_item.h"
#include "config/hero.h"

#include "data/Talent.h"
#include "modules/talent.h"
#include "config/talent.h"

#include "data/Equip.h"
#include "config/equip.h"
#include "modules/equip.h"
#include "config/item_package.h"
#include "config/item.h"

#include "config/fight.h"
#include "modules/fight.h"
#include "modules/daily.h"
#include "calc/calc.h"

#include "config/quest.h"
#include "modules/quest.h"
#include "modules/reward_flag.h"
#include "config/common.h"

#include "logic/title.h"
#include "config/quest.h"

#include "aifightdata.h"

#include "config/openlv.h"
#include "modules/buff.h"
#include "config/buff.h"
#include "config/compensate.h"
#include "config/fashion.h"
#include "modules/fire.h"

#define RAND_RANGE(a, b) \
	( (a) == (b) ? (a) : ((a) + rand() % ((b)-(a)+1)))

static int is_quest_in_time(struct QuestConfig * cfg, Player * player);
static void get_quest_period_time(Player * player, struct QuestConfig * cfg, time_t * begin, time_t * end);
static int is_quest_in_time_to_submit(struct QuestConfig * cfg, Player * player, int * manual);
static int check_for_consume_item_package(Player * player, int package_id, int value);
static int consume_for_consume_item_package(Player * player, int package_id, int value, unsigned int reason);

static int calc_star_count(int star)
{
	int count = 0;
	for (int i = 0; i < 15; i++) {
		if ((star & (1<<(i*2))) != 0) {
			count ++;
		}
	}

	return count ;
}

int aL_login(unsigned long long playerid, const char * token, const char * account)	// 登陆
{
	int isAdult = 0;
	char ip[64] = {0};
	if (token) {
		unsigned long long t;
		char adult[32] = {'0', 0};

		char copyToken[1024] = {0};

		int i;
		for(i = 0; token[i]; i++) {
			if (token[i] == ':') {
				copyToken[i] = '\n';
			} else {
				copyToken[i] = token[i];
			}
		}

		sscanf(copyToken, "%llu%s%s", &t, adult, ip);

		TRANSFORM_PLAYERID_TO_64(t, AG_SERVER_ID, t);

		// assert(playerid == t);
		if (playerid != t) {
			return RET_ERROR;
		}


		if (adult[0] != '0' ) {
			isAdult = 1;
		}


	} else {
		// 无token，默认未成年
	}

	isAdult = !addicted_is_young_player(playerid);

	// 检查防沉迷状态
	if (isAdult) {
		addicted_set_adult(playerid);
	} else {
		// 检查现有状态是否允许登录
		if (!addicted_can_login(playerid)) {
			struct Player * player = player_get_online(playerid);
			if (player){
				player_unload(player);
			}
			return RET_CHARACTER_STATUS_ADDICTED;
		}

		// 更新为未成年，再检查一下，case : 成年变->未成年
		// 理论上不应该这样
		addicted_set_minority(playerid);
		if (!addicted_can_login(playerid)) {
			struct Player * player = player_get_online(playerid);
			if (player){
				player_unload(player);
			}
			return RET_CHARACTER_STATUS_ADDICTED;
		}
	}

	struct Player * player = player_get(playerid);
	if (player == 0) {
		if (player_is_not_exist(playerid)) {
			channel_record(playerid, account, ip);
			return RET_CHARACTER_NOT_EXIST;
		} else {
			WRITE_WARNING_LOG("	database error");
			return RET_ERROR;
		} 
	} 

	if (account) {
		player_set_account(player, account);
	}

	struct Property * property = player_get_property(player);
	if (property->status & PLAYER_STATUS_BAN) {
		WRITE_DEBUG_LOG(" ban");
		player_unload(player);
		return RET_CHARACTER_STATUS_BAN;
	}
	struct CheckData * check = player_get_check_data(player);
	if(check && check->login_order_flag == 0){
		check->login_order_flag = 1;
	}
	struct EventLogin event;
	event.pid = playerid;
	agEvent_dispatch(EVENT_LOGIN, &event, sizeof(event));

	time_t now = agT_current();
	DATA_Property_update_login(property, now);

	// 无ip则用上次地址
	if (ip[0]) DATA_Property_update_ip(property, ip);

	if (playerid > AI_MAX_ID) {
		agL_write_user_logger(LOGIN_LOGOUT_LOGGER, LOG_FLAT, "%d,%lld,0,%d,0,0", (int)now, playerid, player_get_level(player));
	}

	if (player_get_check_data(player)->auto_accept_quest_is_done ) {
		return RET_SUCCESS;
	}

	// 自动接任务
	struct QuestConfig * it = 0;
	int manual = 1;
	while ((it = auto_accept_quest_next(it)) != 0) {
		if (!is_quest_in_time_to_submit(it, player, &manual)) continue;

		struct Quest * quest = quest_get(player, it->id);

		time_t begin = 0;
		time_t end = 0;
		get_quest_period_time(player, it, &begin, &end);

		if (begin == 0 || end == 0) {
			WRITE_ERROR_LOG("cannt get begin and end time for quest %d", it->id);
			continue;
		}

		Property * property = player_get_property(player);
		if (property->create > end) {
			continue;
		}

		time_t accept_time = begin;
		if (property->create > accept_time) {
			accept_time = property->create;
		}

		int same_group_quest_exist = 0;
		if (it->group > 0) {
			struct QuestConfig * ite = get_quest_list_of_group(it->group);
			for(;ite; ite = ite->group_next) {
				if (ite->id == it->id) {
					continue;
				}

				struct Quest * _quest = quest_get(player, ite->id);
				if (_quest == NULL) {
					continue;
				}

				aL_update_quest_status(_quest, ite);
				if (_quest->status == QUEST_STATUS_INIT) {
					WRITE_DEBUG_LOG(" quest in group %d already exists, current quest id %d", ite->group, ite->id);	
					same_group_quest_exist = 1;
					break;
				}
			}
		}
		if (!same_group_quest_exist) {
			if (quest) {
				aL_update_quest_status(quest, it);

				if (quest->status == QUEST_STATUS_INIT) {
					continue;
				} else if (it->count_limit > 0 && (int)quest->count >= it->count_limit) {
					continue;
				}

				quest_update_status(quest, QUEST_STATUS_INIT, 0, 0, -1, 0, 0, accept_time, 0);
			} else {
				quest = quest_add(player, it->id, QUEST_STATUS_INIT_WITH_OUT_SAVE, accept_time);
			}
		}
	}

	player_get_check_data(player)->auto_accept_quest_is_done = 1;

	return RET_SUCCESS;
}

int aL_logout(unsigned long long playerid)	// 登出
{
	addicted_logout(playerid);

	Player * player = player_get_online(playerid);
	if (player) {
		struct CheckData * check = player_get_check_data(player);
		if(check){
			check->login_order_flag = 0;
		}
		time_t now = agT_current();
		struct Property * property = player_get_property(player);
		if (property) {
			DATA_Property_update_logout(property, now);
		}

		// event
		struct EventLogout event;
		event.pid = playerid;
		agEvent_dispatch(EVENT_LOGOUT, &event, sizeof(event));

		// conn
		player_set_conn(playerid, INVALID_ID);
		if(!(SUPPORT_ZOMBIE_LIST)){
			player_unload(player);
		}

		if (playerid > AI_MAX_ID) {
			agL_write_user_logger(LOGIN_LOGOUT_LOGGER, LOG_FLAT, "%d,%lld,1,%d,%d,%d", (int)now, playerid, player_get_level(player), (int)property->login, (int)(property->logout - property->login));
		}

		//quest
		aL_quest_on_event(player, QuestEventType_ONLINE_TIME, 1, 0);

	}

	channel_release(playerid);
	realtime_online_remove(playerid);

	return RET_SUCCESS; 
}

int aL_create_player(unsigned long long playerid, const char * name, int head)	// 创建角色
{
	if (name == 0) { return RET_PARAM_ERROR; }
	WRITE_DEBUG_LOG("player %llu create character", playerid);

	struct Player * player = player_get(playerid);
	if (player) {
		WRITE_DEBUG_LOG("	exist");
		return RET_CHARACTER_EXIST;
	}

	if (!player_is_not_exist(playerid)) {
		WRITE_WARNING_LOG("	database error");
		return RET_ERROR;
	}

	if (player_get_id_by_name(name) > 0) {
		WRITE_DEBUG_LOG("	name exist");
		return RET_CHARACTER_NAME_EXIST;
	}

	player = player_create(playerid, name, head);
	if (player == 0) {
		WRITE_WARNING_LOG("	database error");
		return RET_ERROR;
	} 


	hero_check_leading(player);

	struct EventCreatePlayer event;
	event.pid = playerid;
	agEvent_dispatch(EVENT_CREATE_PLAYER, &event, sizeof(event));

	char ip[256] = {0};

	const char * account = (const char*)channel_read(playerid, ip);
	if (ip[0]) {
		struct Property * property = player_get_property(player);
		DATA_Property_update_ip(property, ip);
	}

	struct CreatePlayerItem * item = get_create_player_item();
	while(item) {
		if (item->type == REWARD_TYPE_ITEM) {
			item_add(player, item->id, item->value, REASON_CREATE_PLAYER);
		} else if (item->type == REWARD_TYPE_HERO) {
			struct Hero * hero = aL_hero_add(player, item->id,	REASON_CREATE_PLAYER);
			if (hero) {
				hero_update_fight_formation(player, hero, item->pos);
			}
		}
		item = item->next;
	}

	player_set_account(player, account);

	time_t now = agT_current();
	if (playerid > AI_MAX_ID) {
		agL_write_user_logger(CREATE_PLAYER_LOGGER, LOG_FLAT, "%d,%lld,%s", (int)now, playerid, account ? account : "");
		agL_write_user_logger(LOGIN_LOGOUT_LOGGER, LOG_FLAT, "%d,%lld,0,%d,0,0", (int)now, playerid, player_get_level(player));
	}

	// 自动接任务
	struct QuestConfig * it = 0;
	int manual = 1;
	while ((it = auto_accept_quest_next(it)) != 0) {
		if (!is_quest_in_time_to_submit(it, player, &manual)) continue;

		struct Quest * quest = quest_get(player, it->id);

		time_t begin = 0;
		time_t end = 0;
		get_quest_period_time(player, it, &begin, &end);

		if (begin == 0 || end == 0) {
			WRITE_ERROR_LOG("cannt get begin and end time for quest %d", it->id);
			continue;
		}
	
		Property * property = player_get_property(player);
		if (property->create > end) {
			continue;
		}

		time_t accept_time = begin;
		if (property->create > accept_time) {
			accept_time = property->create;
		}
				
		int same_group_quest_exist = 0;
		if (it->group > 0) {
			struct QuestConfig * ite = get_quest_list_of_group(it->group);
			for(;ite; ite = ite->group_next) {
				if (ite->id == it->id) {
					continue;
				}

				struct Quest * _quest = quest_get(player, ite->id);
				if (_quest == NULL) {
					continue;
				}

				aL_update_quest_status(_quest, ite);
				if (_quest->status == QUEST_STATUS_INIT) {
					WRITE_DEBUG_LOG(" quest in group %d already exists, current quest id %d", ite->group, ite->id);	
					same_group_quest_exist = 1;
					break;
				}
			}
		}
		if (!same_group_quest_exist) {
			if (quest) {
				aL_update_quest_status(quest, it);

				if (quest->status == QUEST_STATUS_INIT) {
					continue;
				} else if (it->count_limit > 0 && (int)quest->count >= it->count_limit) {
					continue;
				}

				quest_update_status(quest, QUEST_STATUS_INIT, 0, 0, -1, 0, 0, accept_time, 0);
			} else {
				quest = quest_add(player, it->id, QUEST_STATUS_INIT_WITH_OUT_SAVE, accept_time);
			}
		}
	}

	player_get_check_data(player)->auto_accept_quest_is_done = 1;

	channel_release(playerid);

	return RET_SUCCESS;
}

unsigned int aL_receive_reward(Player * player, unsigned int from, struct RewardContent * content, size_t n)
{
	struct Reward * reward = reward_get(player, from);
	if (reward == 0) {
		return RET_REWARD_NOT_EXIST;
	}

	if (reward_receive(reward, player, content, n) != 0) {
		return RET_ERROR;
	}
	return RET_SUCCESS;
}

int CheckForConsume(Player * player, unsigned int type, unsigned int id, unsigned long long uuid, unsigned int value)
{
	if (type == 0 || id == 0) {
		return RET_SUCCESS;
	}

	Item * item = NULL;
	if (type == REWARD_TYPE_ITEM) {
		item = item_get(player, id);
		if (item == 0 || item->limit < value || item->limit == 0) {
			WRITE_DEBUG_LOG("\titem %u not enough, %u/%u", id, item ? item->limit : 0, value);
			return RET_ITEM_NOT_ENOUGH;
		}
	} else if (type == REWARD_TYPE_HEROITEM && value > 0) {
		unsigned int have = hero_item_count(player, uuid, id);
		if (have < value) {
			WRITE_DEBUG_LOG("\thero %llu item %u not enough, %u/%u", uuid, id, have, value);
			return RET_ITEM_NOT_ENOUGH;
		}
	} else if (type == REWARD_TYPE_HERO && value > 0) {
		struct Hero * pHero = hero_get(player, id, 0);
		if (!pHero) {
			WRITE_DEBUG_LOG("\tplayer %llu dont have hero %u ", player_get_id(player), id);
			return RET_NOT_ENOUGH;
		}
	} else if (type != 0) {
		WRITE_DEBUG_LOG("\tunknown consume type %u", type);
		return RET_ERROR;
	}
	return RET_SUCCESS;
}

int sendReward(Player * player, unsigned long long hero_uuid, const char* name, int32_t manual, int32_t limit, int32_t reason, int32_t cnt, ...)
{
	unsigned long long pid = player_get_id(player);
	Reward* reward =reward_create(reason, limit, manual, name);
	if(!reward) return -1;

	va_list vl;
	va_start(vl, cnt);
	int i = 0;
	for(; i < cnt; ++i)
	{
		const int32_t type  = va_arg(vl, int32_t);
		const int32_t id    = va_arg(vl, int32_t);
		const int32_t value = va_arg(vl, int32_t);

		if(value == 0)
			continue;

		if(!reward_add_content(reward, hero_uuid, type, id, value))
		{
			reward_rollback(reward);
			return -1;
		}
	}
	va_end(vl);
	reward_commit(reward, pid, 0, 0);

	return 0;
}

int CheckAndConsume(Player * player, unsigned int type, unsigned int id, unsigned long long uuid, unsigned int value, unsigned int reason)
{
	if (type == 0 || id == 0) {
		return RET_SUCCESS;
	}

	Item * item = NULL;
	unsigned long long pid = player_get_id(player);
	if (pid <= AI_MAX_ID) {
		return RET_SUCCESS;
	}

	if (type == REWARD_TYPE_ITEM) {
		item = item_get(player, id);
		if (item == 0 || item->limit < value || item->limit == 0) {
			WRITE_DEBUG_LOG("\titem %u not enough, %u/%u", id, item ? item->limit : 0, value);
			return RET_ITEM_NOT_ENOUGH;
		}

		if (item_remove(item, value, reason) != 0) {
			WRITE_DEBUG_LOG("\tconsume item %d, value %u failed", id, value);
			return RET_ERROR;
		}
	} else if (type == REWARD_TYPE_HEROITEM && value > 0) {
		if (hero_item_remove(player, uuid, id, value, reason) != 0) {
			WRITE_DEBUG_LOG("\tconsume hero %llu item %u value %u failed", uuid, id ,value);
			return RET_ERROR;
		}
	} else if (type == CONSUME_ITEM_PACKAGE && value > 0) {
		if (check_for_consume_item_package(player, id, value) < 0) {
			WRITE_DEBUG_LOG("\tconsume for consume_item_package %u value %u, failed", id ,value);
			return RET_ERROR;
		}

		if (!consume_for_consume_item_package(player, id, value, reason)) {
			WRITE_DEBUG_LOG("\tconsume for consume_item_package %u value %u, failed", id ,value);
			return RET_ERROR;
		}
	}

	return RET_SUCCESS;
}


int TryConsumeAll(Player * player, unsigned int type, unsigned int id, unsigned long long uuid, unsigned int reason)
{
	Item * item = NULL;
	if (type == REWARD_TYPE_ITEM) {
		item = item_get(player, id);
		if (item != 0) {
			item_remove(item, item->limit, reason);
		}
	} else if (type == REWARD_TYPE_HEROITEM) {
		hero_item_remove(player, uuid, id, hero_item_count(player, uuid, id), reason);
	}

	return RET_SUCCESS;
}


/*
   int aL_hero_level_up(Player * player, unsigned int gid, int count, unsigned long long uuid)
   {
   if (player == NULL)
   {
   return RET_ERROR;
   }


   struct Hero * pHero = hero_get(player, gid, uuid);
   if (pHero == NULL) {
   return RET_ERROR;
   }


   int r = RET_SUCCESS;
   for (int index = 0; index < count; ++index)
   {
   r = hero_level_up(player, pHero);
   if (r != RET_SUCCESS)
   {
   return r;
   }
   }
   return RET_SUCCESS;
   }
   */


struct Hero * aL_hero_add(Player * player, unsigned int gid, int reason)
{
	WRITE_INFO_LOG("player %llu add hero %d", player_get_id(player), gid);
	struct HeroConfig * cfg = get_hero_config(gid);
	if (cfg == 0) {
		WRITE_DEBUG_LOG(" hero config %d not exists", gid);
		return 0;
	}
	if (!cfg->multiple) {
		struct Hero * hero = hero_get(player, gid, 0);
		if (hero != 0) {
			struct ItemConfig * pItemCfg = get_item_base_config(PIECE_ID_RANGE(gid));
			if (pItemCfg->compose_num > 0) {
				item_add(player, pItemCfg->id, pItemCfg->compose_num, reason);
			}
			return hero;
		}
	}

	struct Hero * hero = hero_add(player, gid, 1, 0, 0, 0);

	struct HeroSkillGroupConfig * skill_group = get_hero_skill_group_config(gid);
	if (skill_group && skill_group->init_skill) {
		hero_set_selected_skill(player, hero->uuid, 
				skill_group->skill[0], 
				skill_group->skill[1], 
				skill_group->skill[2], 
				skill_group->skill[3], 
				skill_group->skill[4], 
				skill_group->skill[5], 
				skill_group->property_type, skill_group->property_value);
	}

	return hero;
}


static int check_openlev_config(Player * player, int id)
{
	/* 升级功能开启判断 */
	int level = player_get_level(player);
	OpenLevCofig *cfg = get_openlev_config(ROLE_LEVEL_UP);

	if (!cfg) {
		return 1;
	}

	int open_level = cfg ? cfg->open_lev : 0;
	if (level < open_level) {
		WRITE_WARNING_LOG(" openlev_config check level failed %d/%d", level, open_level);
		return 0;
	}

	if (cfg->condition.type == 1) {
		if (cfg->condition.id != 0) {
			struct Quest * quest = quest_get(player, cfg->condition.id);
			if (quest == 0 || quest->count == 0) {
				WRITE_WARNING_LOG(" openlev_config check quest failed, %d", cfg->condition.id);
				return 0;
			}
		}
	} else if (cfg->condition.type == 2) {
		struct Property * property = player_get_property(player);
		if ((int)property->total_star < cfg->condition.count) {
			WRITE_WARNING_LOG(" openlev_config check star failed %d/%d", property->total_star, cfg->condition.count);
			return 0;
		}
	}

	return 1;
}

int aL_check_openlev_config(Player * player, int id) 
{
	if (!check_openlev_config(player, id)) {
		return RET_PREMISSIONS;
	}
	return RET_SUCCESS;
}


int aL_hero_add_exp(Player * player, unsigned int gid, int exp, int reson, int type, unsigned long long uuid)
{
	if (player == NULL) {
		return RET_ERROR;
	}

	WRITE_INFO_LOG("player %llu hero %u(%llu) add exp %d, type %d", player_get_id(player), gid, uuid, exp, type);
	struct Hero * pHero = hero_get(player, gid, uuid);
	if (pHero == NULL) {
		WRITE_WARNING_LOG("  hero not exists");
		return RET_ERROR;
	}
	
	/* 升级功能开启判断 */
	if (!check_openlev_config(player, ROLE_LEVEL_UP)) {
		return RET_PERMISSION;
	}

	/* 升级等级上限判断 */
	struct HeroStageConfig *hcfg = get_hero_stage_config(gid, pHero->stage);
	int max_level = hcfg ? hcfg->max_level : 9999;
	if (pHero->level >= (unsigned int)max_level) {
		WRITE_WARNING_LOG("  hero reach max level %d of stage %d", max_level, pHero->stage);
		return RET_FULL;
	}	

	if (type == 0) {
		struct UpgradeConfig * pCfg = get_upgrade_config(1, UpGrade_Hero);
		if (pCfg == NULL) {
			WRITE_WARNING_LOG(" hero level up config not exists");
			return RET_NOT_EXIST;
		}

		if (CheckAndConsume(player, pCfg->consume_type, pCfg->consume_id, pHero->uuid, exp, RewardAndConsumeReason_Hero_Level_Up) != 0) {
			return RET_NOT_ENOUGH;
		}
		return hero_add_normal_exp(pHero, exp);	
	} else {
		struct UpgradeConfig * pCfg = get_upgrade_config(pHero->weapon_level, UpGrade_Weapon);
		if (pCfg == NULL) {
			WRITE_WARNING_LOG(" weapon level up config not exists");
			return RET_NOT_EXIST;
		}

		if (CheckAndConsume(player, pCfg->consume_type, pCfg->consume_id, pHero->uuid, exp, RewardAndConsumeReason_Hero_Weapon_Level_Up) != 0) {
			return RET_NOT_ENOUGH;
		}
		return hero_add_weapon_exp(pHero, exp);
	}
}

int aL_hero_add_exp_by_item(Player * player, unsigned long long uuid, int type, int cfg_id)
{
	if (player == NULL) {
		return RET_ERROR;
	}

	WRITE_INFO_LOG("%s:player %llu hero %llu add exp, type %d cfg_id %d", __FUNCTION__, player_get_id(player), uuid, type, cfg_id);
	struct Hero * pHero = hero_get(player, 0, uuid);
	if (pHero == NULL) {
		WRITE_WARNING_LOG("  hero not exists");
		return RET_ERROR;
	}

	struct ExpConfig * eCfg = get_exp_config_by_item(cfg_id);
	if (!eCfg) {
		WRITE_DEBUG_LOG("cant get add_exp_config_by_item");
		return RET_ERROR;
	}

	if (pHero->gid != (unsigned int)eCfg->hero_gid) {
		WRITE_DEBUG_LOG("hero gid not fit with cfg %d != %d", pHero->gid, eCfg->hero_gid);
		return RET_ERROR;
	}
	
	/* 升级功能开启判断 */
	if (!check_openlev_config(player, ROLE_LEVEL_UP)) {
		return RET_PERMISSION;
	}

	/* 升级等级上限判断 */
	struct HeroStageConfig *hcfg = get_hero_stage_config(pHero->gid, pHero->stage);
	int max_level = hcfg ? hcfg->max_level : 9999;
	if (pHero->level >= (unsigned int)max_level) {
		WRITE_WARNING_LOG("  hero reach max level %d of stage %d", max_level, pHero->stage);
		return RET_FULL;
	}	

	if (type == 0) {
		int exp = 0;
		int next_lv_exp = get_exp_by_level(pHero->level + 1, UpGrade_Hero, pHero->gid);
		int current_lv_exp = get_exp_by_level(pHero->level, UpGrade_Hero, pHero->gid);
		if (next_lv_exp > 0 && current_lv_exp > 0) {
			exp = next_lv_exp - current_lv_exp;
		}

        if (exp <=  0) {
            WRITE_WARNING_LOG(" already max level");
            return RET_ERROR;
        }

        if (CheckAndConsume(player, eCfg->consume_type, eCfg->consume_id, pHero->uuid, eCfg->consume_value, RewardAndConsumeReason_Hero_Level_Up) != 0) {
            return RET_NOT_ENOUGH;
        }

        if (pHero->level >= (unsigned int)eCfg->limit_lv) {
            exp = eCfg->fixed_exp;
        }

        if (eCfg->quest_id > 0) {
            struct Quest * quest = quest_get(player, eCfg->quest_id);
            if (quest != NULL) {
                aL_update_quest_status(quest, 0);
                if (quest->status == QUEST_STATUS_FINISH) {
                    exp = exp + eCfg->quest_exp;
                }
            }
        }

		WRITE_DEBUG_LOG("add normal exp xiayazhixin>>>>>>>>>>>>>>>>>>>>>>>>  %d", exp)
		return hero_add_normal_exp(pHero, exp);	
	} else {
		int exp = get_exp_by_level(pHero->level, UpGrade_Weapon, pHero->gid);
        if (exp < 0) {
            WRITE_WARNING_LOG(" weapon level up config not exists");
            return RET_NOT_EXIST;
        }

        if (CheckAndConsume(player, eCfg->consume_type, eCfg->consume_id, pHero->uuid, eCfg->consume_value, RewardAndConsumeReason_Hero_Weapon_Level_Up) != 0) {
            return RET_NOT_ENOUGH;
        }

        if (pHero->level >= (unsigned int)eCfg->limit_lv) {
            exp = eCfg->fixed_exp;
        }

        if (eCfg->quest_id > 0) {
            struct Quest * quest = quest_get(player, eCfg->quest_id);
            if (quest != NULL) {
                aL_update_quest_status(quest, 0);
                if (quest->status == QUEST_STATUS_FINISH) {
                    exp = exp + eCfg->quest_exp;
                }
            }
        }

		return hero_add_weapon_exp(pHero, exp);
	}
}

int aL_hero_star_up(Player * player, unsigned int gid, int type, unsigned long long uuid, int * old_star)
{
	if (player == NULL) {
		return RET_ERROR;
	}
	WRITE_INFO_LOG("player %llu hero %u(%llu) star up type %d", player_get_id(player), gid, uuid, type);

	struct Hero * pHero = hero_get(player, gid, uuid);
	if (pHero == NULL) {
		WRITE_DEBUG_LOG("  hero not exists");
		return RET_NOT_EXIST;
	}

	struct HeroConfig * pHeroCfg = get_hero_config(pHero->gid);
	if (pHeroCfg == NULL) {
		WRITE_ERROR_LOG("  hero config %d not exists", pHero->gid);
		return RET_NOT_EXIST;
	}

	/* 升星功能开启判断 */
	if (type == 0) {
		if (!check_openlev_config(player, ROLE_STAR_UP)) {
			return RET_PERMISSION;
		}
	} else if (type == 1) {
		if (!check_openlev_config(player, ROLE_STAR_UP2)) {
			return RET_PERMISSION;
		}
	}

	int up_type = type;

	int star = 0;
	int consume_id = 0;
	int reason = 0;
	int star_id = 0;

	switch (up_type) {
		case 0: // Up_Hero: 
			reason = RewardAndConsumeReason_Hero_Star_Up;
			consume_id = PIECE_ID_RANGE(pHero->gid);
			star = pHero->star;
			star_id = pHeroCfg->id;
			break;
		case 1: //Up_Weapon:
			reason = RewardAndConsumeReason_Hero_Weapon_Star_Up;
			consume_id = PIECE_ID_RANGE(pHeroCfg->weapon);
			star = pHero->weapon_star;
			star_id = pHeroCfg->weapon;
			break;
		default:
			WRITE_DEBUG_LOG("  param error, unknown up_type : %d", up_type);
			return RET_PARAM_ERROR;
	}

	if (star >= MAXIMUM_STAR) {
		return RET_FULL;
	}

	/* 升星等级判断 */
	struct CommonCfg * commonCfg = get_common_config(START_UP_BEGIN + star + 1);			
	if (NULL == commonCfg) {
		WRITE_ERROR_LOG(" conmmon config %d not exists", START_UP_BEGIN + star + 1);
		return RET_NOT_EXIST;
	}

	if (pHero->level < (unsigned int)commonCfg->para2) {
		WRITE_DEBUG_LOG(" hero level limit %d/%d", pHero->level, commonCfg->para2);
		return RET_PERMISSION;	 
	}	

	/* check star limit and consume */
	struct StarConfig * nextStarConfig = get_star_config(star_id, star + 1);
	if (!nextStarConfig) {
		WRITE_DEBUG_LOG("  next star (%d,%d) config not exists", star_id, star + 1);
		return RET_FULL;
	}

	struct {
		int type;
		int id;
		int value;
	} consumes[STAR_UP_CONSUME_COUNT];
	memset(consumes, 0, sizeof(consumes));

	int have_sep_consume = 0;
	for (int i = 0; i < STAR_UP_CONSUME_COUNT; i++) {
		if (nextStarConfig->consume[i].type != 0) {
			consumes[i].type  = nextStarConfig->consume[i].type;
			consumes[i].id    = nextStarConfig->consume[i].id;
			consumes[i].value = nextStarConfig->consume[i].value;
			have_sep_consume = have_sep_consume + 1;
		}
	}

	if (!have_sep_consume) {
		struct StarUpConfig * pCfg = get_starup_config(star + 1);
		if (pCfg == NULL) {
			WRITE_DEBUG_LOG(" star id %d limit %d", star_id, star);
			return RET_FULL;
		}

		consumes[0].type = REWARD_TYPE_ITEM; consumes[0].id = consume_id; consumes[0].value = pCfg->piece;
		consumes[1].type = REWARD_TYPE_ITEM; consumes[1].id = COIN_ID;    consumes[1].value = pCfg->coin;
	}

	for (int i = 0; i < STAR_UP_CONSUME_COUNT; i++) {
		if (consumes[i].type &&  CheckForConsume(player, consumes[i].type, consumes[i].id, pHero->uuid, consumes[i].value) != 0) {
			return RET_NOT_ENOUGH;
		}
	}

	for (int i = 0; i < STAR_UP_CONSUME_COUNT; i++) {
		if (consumes[i].type && CheckAndConsume(player, consumes[i].type, consumes[i].id, pHero->uuid, consumes[i].value, reason) != 0) {
			return RET_NOT_ENOUGH;
		}
	}

	// 升星暴击
	int add_star = 1;
	struct StarConfig * starConfig = get_star_config(star_id, star);
	if (!starConfig) {
		WRITE_DEBUG_LOG(" crit config for star (%d,%d) not exists", star_id, star);
		// return RET_NOT_EXIST;
	}

	if (starConfig && starConfig->promote) {
		if ((rand() % 10000 + 1) <= starConfig->promote->chance_1) {
			add_star = starConfig->promote->rate_1;
		} else if ((rand() % 10000 + 1) <= starConfig->promote->chance_2) {
			add_star = starConfig->promote->rate_2;
		}
	}

	for (; add_star > 1; add_star --) {
		if (get_star_config(star_id, star + add_star)) {
			break;	
		}
	}

	if (add_star > 1) {
		WRITE_INFO_LOG("  star up crit %d -> %d", star, star + add_star);
	}

	if (up_type == 0 /*Up_Hero*/) {
		hero_add_normal_star(pHero, add_star);
		aL_quest_on_event(player, QuestEventType_HERO_STAR_UP, pHero->star, 1);
	} else if (up_type == 1 /*Up_Weapon*/) {
		hero_add_weapon_star(pHero, add_star);
		aL_quest_on_event(player, QuestEventType_WEAPON_STAR_UP, pHero->star, 1);
	}

	if (old_star) {
		*old_star = star;
	}

	return RET_SUCCESS;
}

int aL_hero_stage_up(Player * player, unsigned int gid, int type, unsigned long long uuid, int * old_stage)
{
	if (player == NULL) {
		return RET_ERROR;
	}

	WRITE_INFO_LOG("player %llu hero %u(%llu) stage up type %d", player_get_id(player), gid, uuid, type);

	struct Hero * pHero = hero_get(player, gid, uuid);
	if (pHero == NULL) {
		WRITE_WARNING_LOG("  hero not exists");
		return RET_NOT_EXIST;
	}
	
	/* 进阶功能开启判断 */	
	if (!check_openlev_config(player, ROLE_STAGE_UP)) {
		return RET_PERMISSION;
	}

	/* 进阶最小等级判断 */
	struct HeroStageConfig *hcfg = get_hero_stage_config(gid, pHero->stage);
	int min_level = hcfg ? hcfg->min_level : 0;
	if (pHero->level < (unsigned int)min_level) {
		WRITE_WARNING_LOG("%s: hero %d level is %d, min level is %d.", __FUNCTION__, gid, pHero->level, min_level)
		return RET_NOT_ENOUGH;
	}		
	
	return hero_stage_up(player, pHero, type, old_stage);
}

int aL_hero_stage_slot_unlock(Player * player, unsigned int gid, int index, int type, unsigned long long uuid)
{
	if (player == NULL) {
		return RET_ERROR;
	}

	WRITE_INFO_LOG("player %llu hero %u(%llu) unlock slot %d, type %d", player_get_id(player), gid, uuid, index, type);
	struct Hero * pHero = hero_get(player, gid, uuid);
	if (pHero == NULL) {
		WRITE_WARNING_LOG("  hero not exists");
		return RET_NOT_EXIST;
	}
	return hero_stage_slot_unlock(player, pHero, index, type);
}

int aL_hero_update_fight_formation(Player * player, unsigned int gid, int new_place, unsigned long long uuid)
{
	if (player == NULL) {
		return RET_ERROR;
	}

	WRITE_INFO_LOG("player %llu hero %u(%llu) update placeholder %d", player_get_id(player), gid, uuid, new_place);
	struct Hero * pHero = hero_get(player, gid, uuid);
	if(pHero == NULL) {
		WRITE_WARNING_LOG("  hero not exists");
		return RET_NOT_EXIST;
	}

	/* 上阵位置判断 */
	if (new_place > 0) {	// 上阵
		if (!check_openlev_config(player, ROLE_ONLINE + new_place - 2)) {
			return RET_PERMISSION;
		}
	}	
	
	return hero_update_fight_formation(player, pHero, new_place);
}

int aL_hero_item_set(Player *player, unsigned long long uuid, unsigned id, int status)
{
	WRITE_DEBUG_LOG("%s: player %lld set hero %lld item id %d status %d.", __FUNCTION__, player_get_id(player), uuid, id, status);

#define SET_HERO_ITEM(player, uid, id, value, reason, status) \
	if (hero_item_set(player, uid, id, value, reason, status) != 0) {\
		WRITE_WARNING_LOG("%s: set hero item error, pid is %lld, uid is %lld, id is %d.", __FUNCTION__, player_get_id(player), uid, id);\
		return RET_ERROR;\
	}
	
	struct HeroItem * hero_item = hero_item_get(player, uuid, id);
	if (NULL == hero_item) {
		WRITE_WARNING_LOG("%s: hero item is not exist.", __FUNCTION__);
		return RET_NOT_EXIST;
	}

	switch (status) {
		case 1: {	
			// take off all cloth
			struct HeroItem * item = NULL;
			while ( (item = hero_item_next(player, item)) ) {
				if (item->status == 1 && item->uid == uuid && item->id != id) {
					SET_HERO_ITEM(player, item->uid, item->id, item->value, 0, 0);	
				}
			}
			SET_HERO_ITEM(player, uuid, id, hero_item->value, 0, 1);	
			break;
		}
		case 0: {
			SET_HERO_ITEM(player, uuid, id, hero_item->value, 0, 0);
			break;
		}
		default:
			WRITE_WARNING_LOG("%s: set hero item error, invalid status %d.", __FUNCTION__, status);
			return RET_ERROR;
	}

	return RET_SUCCESS;
}

int aL_hero_get_fashion_id(unsigned long long pid, unsigned long long uuid, int * fashion_id)
{
	Player * player = player_get(pid);
	if (NULL == player) {
		WRITE_DEBUG_LOG("%s: player %lld is not exist.", __FUNCTION__, pid);
		return RET_NOT_EXIST;
	}

	struct Hero * hero = hero_get(player, 0, uuid);
	if (NULL == hero) {
		WRITE_DEBUG_LOG("%s: player %lld hero %lld is not exist.", __FUNCTION__, pid, uuid);
		return RET_NOT_EXIST;
	}

	struct HeroItem * item = NULL;	
	while ((item = hero_item_next(player, item))) {
		if (item->status == 1 && item->uid == hero->uuid) {
			struct Fashion * cfg = get_fashion_by_item(hero->gid, item->id);
			if (cfg && fashion_id) {
				*fashion_id = cfg->fashion_id;
				return RET_SUCCESS;
			}
		}
	}

	Fashion * cfgs = get_fashion_cfgs(hero->gid);
	while (cfgs) {
		if (cfgs->item == 0 && fashion_id) {
			*fashion_id = cfgs->fashion_id;
			return RET_SUCCESS;
		}
		cfgs = cfgs->next;
	}

	return RET_NOT_EXIST;
}

// for old code, client send no talent type
static int talent_real_type(int type, unsigned long long id, int refid)
{
	if ( (type == 0 || type == TalentType_Hero  ) && get_hero_config(refid)) { return TalentType_Hero; }
	if ( (type == 0 || type == TalentType_Weapon) && get_weapon_config(refid)) { return TalentType_Weapon; }

	if (type > 0 && type < TalentType_MAX) {
		return type;
	}

	return 0;
}

static HeroConfig * talent_hero_info(struct Player * player, int type, unsigned long long id, int refid, int * real_type, unsigned long long * real_id, int * real_refid, int * talentid, int * star, int * level)
{
	struct Hero * hero = hero_get(player, refid, id);
	if (!hero) {
		WRITE_DEBUG_LOG(" hero %llu(%d) not exist", id, refid);
		return 0;
	}
	id = hero->uuid;

	struct HeroConfig * cfg = get_hero_config(hero->gid);
	if (!cfg) {
		WRITE_DEBUG_LOG(" hero config %d not exist", hero->gid);
		return 0;
	}

	if (real_id)    *real_id    = hero->uuid;
	if (real_refid) *real_refid = hero->gid;
	if (level)      *level      = hero->level;
	if (star)       *star       = cfg->star;
	if (real_type)  *real_type  = type;

	return cfg;
}

static WeaponConfig * talent_weapon_info(struct Player * player, int type, unsigned long long id, int refid, int * real_type, unsigned long long * real_id, int * real_refid, int * talentid, int * star, int * level)
{
	struct Hero * hero = 0;
	HeroConfig * cfg = 0;
	if (id) {
		hero = hero_get(player, refid, id);
		cfg = hero ? get_hero_config(hero->gid) : 0;
	} else {
		cfg = get_hero_config_by_weapon(refid);	
		hero = cfg ? hero_get(player, cfg->id, id) : 0;
	}

	if (hero == 0) {
		WRITE_DEBUG_LOG(" hero %llu(%d) not exist", id, refid);
		return 0;
	}

	if (cfg == 0) {
		WRITE_DEBUG_LOG(" hero config %d not exist", hero->gid);
		return 0;
	}

	struct WeaponConfig * weaponCfg = get_weapon_config(cfg->weapon);
	if (!weaponCfg) {
		WRITE_DEBUG_LOG(" weapon config %d not exist", cfg->weapon);
		return 0;
	}

	if (real_type)  *real_type  = type;
	if (real_id)    *real_id    = hero->uuid;
	if (real_refid) *real_refid = cfg->weapon;
	if (level)      *level      = hero->weapon_level;
	if (star)       *star       = hero->weapon_star;

	return weaponCfg;
}

static int talent_info(struct Player * player, int type, unsigned long long id, int refid, int * real_type, unsigned long long * real_id, int * real_refid, int * talentid, int * star, int * level)
{
	if (type == 0) {
		type = talent_real_type(type, id, refid);
	}

	if (type == TalentType_Hero) {
		struct HeroConfig * cfg = talent_hero_info(player, type, id, refid, real_type, real_id, real_refid, talentid, star, level);
		if (!cfg) return -1;
		if (talentid) *talentid = cfg->talent_id;
	} else if (type == TalentType_Hero_fight) {
		struct HeroConfig * cfg = talent_hero_info(player, type, id, refid, real_type, real_id, real_refid, talentid, star, level);
		if (!cfg) return -1;
		if (talentid) *talentid = cfg->fight_talent_id;
	} else if (type == TalentType_Hero_work) {
		struct HeroConfig * cfg = talent_hero_info(player, type, id, refid, real_type, real_id, real_refid, talentid, star, level);
		if (!cfg) return -1;
		if (talentid) *talentid = cfg->work_talent_id;
	} else if (type >= TalentType_HeroSkill_min && type <= TalentType_HeroSkill_max) {
		struct WeaponConfig * weaponCfg = talent_weapon_info(player, type, id, refid, real_type, real_id, real_refid, talentid, star, level);
		if (!weaponCfg) return -1;

		struct HeroConfig * cfg = get_hero_config_by_weapon(weaponCfg->id);	

		struct HeroSkillGroupConfig * skill_group = get_hero_skill_group_config(cfg->id);
		for (; skill_group; skill_group = skill_group->next) {
			if (skill_group->talent_type == type) {
				break;
			}
		}

		if (skill_group == 0) {
			WRITE_DEBUG_LOG("  skill group with talent type %d of hero %d not exists", type, cfg->id);
			return -1;
		}

		if (talentid) *talentid = skill_group->talent_id;
	} else if (type == TalentType_Weapon) {
		struct WeaponConfig * weaponCfg = talent_weapon_info(player, type, id, refid, real_type, real_id, real_refid, talentid, star, level);
		if (!weaponCfg) return -1;
		if (talentid) *talentid = weaponCfg->talent_id;
	} else if (type == TalentType_Equip) {
		Equip * equip = equip_get(player, id);
		if (!equip) {
			WRITE_DEBUG_LOG(" equip %llu not exist", id);
			return -1;
		}

		EquipConfig * cfg = get_equip_config(equip->gid);
		if (!cfg) {
			WRITE_DEBUG_LOG(" equip config %d not exist", equip->gid);
			return -1;
		}

		if (real_type)  *real_type  = type;
		if (real_id)    *real_id    = equip->uuid;
		if (real_refid) *real_refid = equip->gid;
		if (talentid)   *talentid   = equip->gid;
		if (level)      *level      = equip->level;
		if (star)       *star       = 0;
	} else {
		WRITE_DEBUG_LOG("  unknown type");
		return -1;
	}

	return 0;
}

const char * aL_talent_get_data(Player * player, int type, unsigned long long id, int refid, unsigned long long * uuid, int * real_type)
{
	// WRITE_DEBUG_LOG("get talent data type %d, id %lld, refid %d", type, id, refid);

	int talentid = -1;
	if (talent_info(player, type, id, refid, &type, &id, &refid, &talentid, 0, 0) != 0) {
		return 0;
	}

	// WRITE_DEBUG_LOG("   type %d, id %lld, refid %d, talentid %d", type, id, refid, talentid);

	struct TalentSkillConfig * cfg = get_talent_skill_config(talentid, 1);
	if (!cfg) {
		WRITE_DEBUG_LOG(" talent config %d not exist", talentid);
		return 0;
	}

	Talent * talent = talent_get(player, type, id);
	if (uuid)      *uuid      = id;
	if (real_type) *real_type = type;
	return talent ? talent->data : talent_empty();
}

int aL_talent_reset(Player * player, int type, unsigned long long id, int refid)
{
	return aL_talent_update(player, type, id, refid, 0);
}


int aL_talent_update(Player * player, int type, unsigned long long id, int refid, const char * data)
{
	unsigned long long pid = player_get_id(player);
	WRITE_INFO_LOG("player %llu update talent %d:%llu(%d) %s", pid, type, id, refid, data ? data : "-");

	int talentid = 0;

	// int total_point = 0;
	int star = 0, level = 0;

	if (talent_info(player, type, id, refid, &type, &id, &refid, &talentid, &star, &level) != 0) {
		return -1;
	}
	WRITE_INFO_LOG("   talent %llu(%d)", id, talentid);

	struct TalentSkillConfig * cfg = get_talent_skill_config(talentid, 1);
	if (!cfg) {
		WRITE_DEBUG_LOG("  talent %d not exists", talentid );
		return -1;
	}

	Talent * talent = talent_get(player, type, id);
	const char * old_data = talent ? talent->data : talent_empty();
	char new_data[TALENT_MAXIMUM_DATA_SIZE+1] = {0};

	if (data) {
		strncpy(new_data, data, TALENT_MAXIMUM_DATA_SIZE);
	}

	for (int i = 0;  i < TALENT_MAXIMUM_DATA_SIZE; i++) {
		if (new_data[i] < '0') {
			new_data[i] = '0';
		}
	}

	struct {
		int type;
		int id;
		int value;
	} consume_item_list[TALENT_MAXIMUM_DATA_SIZE * TALENT_CONSUME_COUNT];

	memset(consume_item_list, 0, sizeof(consume_item_list));

#define INCR_VALUE(BASE, INCR, T) ((BASE) * (T) + (INCR) * (((T) * ((T) - 1)) / 2))

#define TALENT_VALUE(data, idx) (data[idx-1]-'0')

	int consume_91[2] = {0}; // 根据星级，等级计算的点数

	int is_equal = 1;

	int is_reset = 0;

	for (int i = 0; i < TALENT_MAXIMUM_DATA_SIZE; i++) {
		int idx = i + 1;
		struct TalentSkillConfig * cfg = get_talent_skill_config(talentid, idx);

		int o = TALENT_VALUE(old_data, idx);
		int n = TALENT_VALUE(new_data, idx);

		if (cfg == 0) {
			if (n != 0) {
				WRITE_INFO_LOG("  talent %d index %d config not exists", talentid, idx);
				return -1;
			} else {
				continue;
			}
		}

		if (n > 0 && cfg->depend_level > level) {
			WRITE_INFO_LOG("  talent %d index %d level not enough %d/%d", talentid, idx, level, cfg->depend_level);
			return -1;
		}

		if (o != n) { is_equal = 0; }
		if (n <  o) { is_reset = 1; }

		// point = point + n;

		int j;
		for (j = 0; j < TALENT_CONSUME_COUNT; j++) {
			if (cfg->consume[j].type == 91) {
				if (n > 0) {
					if (cfg->consume[j].id == 1) {
						consume_91[0] += INCR_VALUE(cfg->consume[j].value, cfg->consume[j].incr, n);
					} else if (cfg->consume[j].id == 2) {
						consume_91[1] += INCR_VALUE(cfg->consume[j].value, cfg->consume[j].incr, n);
					} else {
						WRITE_WARNING_LOG("  unknown consume type %d,%d", cfg->consume[j].type, cfg->consume[j].id);
						return -1;
					}	
				}
				continue;
			}

			int old_value = 0;
			if (o > 0) {
				old_value = INCR_VALUE(cfg->consume[j].value, cfg->consume[j].incr, o);
			}

			int new_value = 0;
			if (n > 0) {
				new_value = INCR_VALUE(cfg->consume[j].value, cfg->consume[j].incr, n);
			}

			int change = old_value - new_value;
			if (change > 0) {
				change = change * cfg->consume[j].payback / 100; // 返还计算打折
			}

			int k;
			for (k = 0; k < TALENT_MAXIMUM_DATA_SIZE * TALENT_CONSUME_COUNT; k++) {
				if ((consume_item_list[k].type == cfg->consume[j].type && consume_item_list[k].id == cfg->consume[j].id) || consume_item_list[k].type == 0) {
					consume_item_list[k].type = cfg->consume[j].type;
					consume_item_list[k].id   = cfg->consume[j].id;
					consume_item_list[k].value += change;
					break;
				}
			}
		}

		if (n > cfg->point_limit) {
			WRITE_INFO_LOG("  talent %d index %d, value %d > point_limit % d", talentid, idx, n, cfg->point_limit);
			return -1;
		}

		if (n > 0) {
			if (cfg->mutex_id1 != 0 && TALENT_VALUE(new_data, cfg->mutex_id1) != 0) {
				WRITE_INFO_LOG("  talent %d index %d mutex with index %d", talentid, idx, cfg->mutex_id1);
				return -1;
			}

			if (cfg->mutex_id2 != 0 && TALENT_VALUE(new_data, cfg->mutex_id2) != 0) {
				WRITE_INFO_LOG("  talent %d index %d mutex with index %d", talentid, idx, cfg->mutex_id2);
				return -1;
			}

			int depend_pass = 0;
			if (cfg->depend_id1 == 0 && cfg->depend_id2 == 0 && cfg->depend_id3 == 0) {
				depend_pass = 1;
			} else {
				if (!depend_pass && cfg->depend_id1 != 0 && TALENT_VALUE(new_data, cfg->depend_id1) >= cfg->depend_point) { depend_pass = 1; } 
				if (!depend_pass && cfg->depend_id2 != 0 && TALENT_VALUE(new_data, cfg->depend_id2) >= cfg->depend_point) { depend_pass = 1; } 
				if (!depend_pass && cfg->depend_id3 != 0 && TALENT_VALUE(new_data, cfg->depend_id3) >= cfg->depend_point) { depend_pass = 1; } 
			}

			if (!depend_pass) {
				WRITE_INFO_LOG("  talent %d index %d depend error, id(%d,%d, %d,%d, %d,%d), point %d", talentid, idx, 
						cfg->depend_id1, TALENT_VALUE(new_data, cfg->depend_id1),
						cfg->depend_id2, TALENT_VALUE(new_data, cfg->depend_id2),
						cfg->depend_id3, TALENT_VALUE(new_data, cfg->depend_id3),
						cfg->depend_point);
				return -1;
			}
		}
	}

	if (is_equal) {
		WRITE_INFO_LOG("  talent %d have no change, skip", talentid);
		return 0;
	}

	// 重置
	if (is_reset && (type == TalentType_Hero_fight || type == TalentType_Hero_work)) {
		struct ConsumeCfg * cfg = get_consume_config(1);
		if (cfg) {
			if (CheckAndConsume(player, cfg->item_type, cfg->item_id, id, cfg->item_value, REASON_TALENT) != 0) {
				WRITE_INFO_LOG("  item %d/%d not enough, need %d", cfg->item_type, cfg->item_id, cfg->item_value);
				return RET_NOT_ENOUGH;
			}
		}	
	}

	if (consume_91[0] > level) {
		WRITE_INFO_LOG("  level %d not enough, need %d", level, consume_91[0]);
		return -1;
	}

	if (consume_91[1] > star) {
		WRITE_INFO_LOG("  star %d not enough, need %d", star , consume_91[1]);
		return -1;
	}

	unsigned long long consume_hero_uuid = id;

	int k;
	// check consume
	for (k = 0; k < TALENT_MAXIMUM_DATA_SIZE * TALENT_CONSUME_COUNT; k++) {
		if (consume_item_list[k].type != 0 && consume_item_list[k].value < 0) {
			if (CheckForConsume(player, consume_item_list[k].type, consume_item_list[k].id, consume_hero_uuid, -consume_item_list[k].value) != 0) {
				WRITE_INFO_LOG("  item %d/%d not enough, need %d", consume_item_list[k].type, consume_item_list[k].id, -consume_item_list[k].value);
				return -1;
			}
		}
	}

	// do consume
	for (k = 0; k < TALENT_MAXIMUM_DATA_SIZE * TALENT_CONSUME_COUNT; k++) {
		if (consume_item_list[k].type != 0 && consume_item_list[k].value < 0) {
			if (CheckAndConsume(player, consume_item_list[k].type, consume_item_list[k].id, consume_hero_uuid, -consume_item_list[k].value, REASON_TALENT) != 0) {
				WRITE_INFO_LOG("  item %d/%d not enough, need %d", consume_item_list[k].type, consume_item_list[k].id, -consume_item_list[k].value);
				return -1;
			}
		}
	}

	// pay back
	for (k = 0; k < TALENT_MAXIMUM_DATA_SIZE * TALENT_CONSUME_COUNT; k++) {
		if (consume_item_list[k].type != 0 && consume_item_list[k].value > 0) {
			if (sendReward(player, consume_hero_uuid, 0, 0, 0, REASON_TALENT, 1, consume_item_list[k].type, consume_item_list[k].id, consume_item_list[k].value) != 0) {
				WRITE_WARNING_LOG("  add reward %d,%d,%d to player failed", consume_item_list[k].type, consume_item_list[k].id, consume_item_list[k].value);
			}
		}
	}

	talent_set(player, type, id, refid, data);

	return 0;
}

long long aL_get_player_power(Player * player)
{
	if (player == NULL) {
		return 0;
	}

	return 0;
}

static struct EquipAffixConfig * affix_pool_choose(int pool_id, int * value, int exclude[EQUIP_PROPERTY_POOL_MAX]) 
{
	struct EquipAffixPoolConfig * cfg = get_equip_affix_pool_config(pool_id);
	if (!cfg) {
		WRITE_WARNING_LOG("  equip affix pool %d not exists", pool_id);
		return 0;
	}

	int weight = 0;
	struct EquipAffixPoolItem * ite;
	for (ite = cfg->items; ite; ite = ite->next) {
		int i;
		for(i = 0; i < EQUIP_PROPERTY_POOL_MAX; i++) {
			if (exclude[i] && ite->cfg->property.type == exclude[i]) {
				break;
			}
		}

		if (i < EQUIP_PROPERTY_POOL_MAX) {
			continue;
		}

		weight += ite->weight;
	}

	if (weight <= 0) {
		WRITE_WARNING_LOG("  weight of affix pool %d is %d", pool_id, cfg->weight);
		return 0;
	}

	int r = rand() % weight + 1;

	WRITE_DEBUG_LOG(" POOL %d/%d", r, cfg->weight);

	for (ite = cfg->items; ite; ite = ite->next) {
		int i;
		for(i = 0; i < EQUIP_PROPERTY_POOL_MAX; i++) {
			if (exclude[i] && ite->cfg->property.type == exclude[i]) {
				break;
			}			
		}

		if (i < EQUIP_PROPERTY_POOL_MAX) {
			continue;
		}


		r = r - ite->weight;
		if (r <= 0) {
			break;
		}
	}

	if (!ite || !ite->cfg) {
		WRITE_WARNING_LOG("  pick from affix pool %d failed", pool_id);
		return 0;
	}

	int min = ite->cfg->property.min;
	int max = ite->cfg->property.max;

	*value = RAND_RANGE(min, max);

	return ite->cfg;
}

int aL_equip_add(Player * player, int gid, int * id, int * quality, unsigned long long * uuid)
{
	unsigned long long pid = player_get_id(player);
	WRITE_INFO_LOG("player %llu add equip %d", pid, gid);

	struct EquipConfig * cfg = 0;
	int level = 0;
	struct EquipWithLevelConfig * ew = get_equip_with_level_config(gid);
	if (ew != 0) {
		gid = ew->equip_id;
		level = RAND_RANGE(ew->min_level, ew->max_level);
		WRITE_DEBUG_LOG("  real info quip %d level %d (%d - %d)", gid, level, ew->min_level, ew->max_level);
	}

	int * affix_pool = 0;
	struct EquipWithAffixConfig * ewa = get_equip_with_affix_config(gid);
	if (ewa != 0) {
		gid = ewa->equip_id;
		affix_pool = ewa->ability_pool;
		WRITE_DEBUG_LOG("  real info quip %d ability_pool %d", gid, ewa->id);
	}

	cfg = get_equip_config(gid);
	if (cfg == 0) {
		WRITE_DEBUG_LOG("  equip config of %d not exist", gid);
		return -1;
	}

	if (id) {
		if (IS_EQUIP_TYPE_1(cfg->type)) {
			*id = 12;
		}	
		else if (IS_EQUIP_TYPE_2(cfg->type)) {
			*id = 11;	
		}
	}	
	if (quality) {
		*quality = cfg->quality;	
	}

	// random property
	struct EquipAffixInfo affix[EQUIP_PROPERTY_POOL_MAX];
	memset(affix, 0, sizeof(affix));

	int exclude[EQUIP_PROPERTY_POOL_MAX] = {0};
	int i;
	for (i = 0; i < EQUIP_PROPERTY_POOL_MAX; i++) {
		int pool_id = affix_pool ? affix_pool[i] : cfg->ability_pool[i];

		if (pool_id == 0) {
			continue;
		}

		struct EquipAffixConfig * acfg = affix_pool_choose(pool_id, &(affix[i].value), exclude);
		if (acfg == 0) {
			WRITE_WARNING_LOG("equip %d ability_pool %d not exists", cfg->gid, cfg->ability_pool[i]);
			continue;
		}

		affix[i].id   = acfg->id;
		affix[i].grow = 0;

		WRITE_DEBUG_LOG(" choose %d affix %d:(%d+%d) from pool %d", i + 1, affix[i].id, affix[i].value, affix[i].grow, pool_id);

		exclude[i] = acfg->property.type;
	}

	if (level == 0) {
		if (cfg->init.min_level > 0 || cfg->init.max_level > 0) {
			level = RAND_RANGE(cfg->init.min_level, cfg->init.max_level);
		}
	}

	int exp = 0;
	if (level > 0) {
		struct UpgradeConfig * upgradeCfg = get_upgrade_config(level, cfg->level_up_type);
		if (upgradeCfg != 0) {
			exp = upgradeCfg->consume_value;
		} else {
			WRITE_WARNING_LOG(" equip %d level config %d not exists", cfg->gid, level);
		}
	}

	struct Equip * equip = equip_add(player, gid, affix, exp);
	if (equip) {
		if (IS_EQUIP_TYPE_1(cfg->type)) {
			aL_quest_on_event(player, QuestEventType_EQUIP_ADD_WITHOUT_TRADE, 1, 1);
		} else if (IS_EQUIP_TYPE_2(cfg->type)) {
			aL_quest_on_event(player, QuestEventType_EQUIP_ADD_WITHOUT_TRADE, 2, 1);
		}

		if (uuid) *uuid = equip->uuid;
	} 
	
	time_t now = agT_current();
	
	if (pid > AI_MAX_ID) {
		agL_write_user_logger(ARMAMENT_LOGGER, LOG_FLAT, "%d,%lld,%lld,%d,1", (int)now, pid, equip->uuid, gid);
	}

	return 0;
}

static void append_rewards_(struct RewardItem * rewards, int nitem, int type, int id, int value)
{
	int j;
	for (j = 0; j < nitem; j++) {
		if ((rewards[j].type == type && rewards[j].id == id) || rewards[j].type == 0) {
			rewards[j].type   = type;
			rewards[j].id     = id;
			rewards[j].value += value;
			rewards[j].uuid   = 0;
			return;
		}
	}
}

int aL_equip_delete(Player * player, unsigned long long uuid, int reason, int payback_flag, struct RewardItem * items, int nitem)
{
	unsigned long long pid = player_get_id(player);

	struct Equip * equip = equip_get(player, uuid);
	if (equip == 0) {
		WRITE_DEBUG_LOG("  equip not exist");
		return RET_NOT_EXIST;
	}

	WRITE_INFO_LOG("player %llu decompose equip %llu(%d), reason %d", pid, uuid, equip->gid, reason);

	struct EquipConfig * cfg = get_equip_config(equip->gid);
	if (cfg == 0) {
		WRITE_DEBUG_LOG("  equip config not exist");
		return RET_NOT_EXIST;
	}

	struct Reward * reward = reward_create(reason, 0, 0, 0);

	// level up resources
	struct CommonCfg * commonCfg = get_common_config(9);
	if (commonCfg && commonCfg->para1 > 0) {
		struct UpgradeConfig * upgradeConfig = get_upgrade_config(equip->level, cfg->level_up_type);
		if (upgradeConfig == 0) {
			WRITE_DEBUG_LOG("  upgrade config %d not exist", equip->gid)
		} else {
			int value = equip->exp * commonCfg->para1 / 10000;
			reward_add_content(reward, 0, upgradeConfig->consume_type, upgradeConfig->consume_id, value);
		}
	}

	if (payback_flag & 1) {
		int i;
		for (i = 0; i < EQUIP_DECOMPOSE_COUNT; i++) {
			reward_add_content(reward, 0, cfg->decompose[i].type, cfg->decompose[i].id, cfg->decompose[i].value + (equip->level - 1) * cfg->decompose[i].increase_value);
		}
	}

	// grow or refresh resources
	if (payback_flag & 2) {
		struct EquipValue * values = equip_get_values(player, equip);
		struct EquipValue * ite = 0;
		while((ite = dlist_next(values, ite)) != 0) {
			reward_add_content(reward, 0, ite->type, ite->id, ite->value);
		}

		// affix
		int i;
		for (i = 0; i < EQUIP_PROPERTY_POOL_MAX; i++) {
			int id = 0, value, grow;
			equip_get_affix(equip, i+1, &id, &value, &grow);
			if (id > 0) {
				struct EquipAffixConfig * acfg = get_equip_affix_config(id);
				if (acfg != 0) {
					reward_add_content(reward, 0, acfg->decompose.type, acfg->decompose.id, acfg->decompose.value);
				}
			}
		}

	}

	if (reward_commit(reward, pid, 0, 0) != 0) {
		return RET_ERROR;
	}

	equip_delete(player, equip, reason);
	
	if (pid > AI_MAX_ID) {
		time_t now = agT_current();
		agL_write_user_logger(ARMAMENT_LOGGER, LOG_FLAT, "%d,%lld,%lld,%d,0,%d", (int)now, pid, uuid, equip->gid, payback_flag);
	}

	return RET_SUCCESS;
}

int aL_equip_decompose(Player * player, unsigned long long uuid, struct RewardItem * items, int nitem)
{
	return aL_equip_delete(player, uuid, REASON_EQUIP_DECOMPOSE, 0xffffff, items, nitem);
}

// 升级  消耗 资源 => 增加自身属性（升级表） (随机属性1-n) * level 不超过主角等级   
int aL_equip_level_up(Player * player, unsigned long long uuid, int level, int exp)
{
	WRITE_INFO_LOG("player %llu level up equip %llu, level +%d exp +%d", player_get_id(player), uuid, level, exp);
	struct Equip * equip = equip_get(player, uuid);
	if (equip == NULL) {
		WRITE_WARNING_LOG("  equip not exists");
		return RET_NOT_EXIST;
	}

	struct EquipConfig * cfg = get_equip_config(equip->gid);
	if (cfg == 0) {
		WRITE_WARNING_LOG("  equip config of %d not exists", equip->gid);
		return RET_NOT_EXIST;
	}
	
	/* 装备升级功能开启判断 */	
	if (IS_EQUIP_TYPE_1(cfg->type)) {	
		if (!check_openlev_config(player, ROLE_EQUIP_LEVEL_UP)) {
			return RET_PERMISSION;
		}
	} else if (IS_EQUIP_TYPE_2(cfg->type)) {					
		if (!check_openlev_config(player, ROLE_EQUIP_LEVEL_UP2)) {
			return RET_PERMISSION;
		}
	}

	/* 装备升级上限判断 */
	if (equip->level >= (unsigned int)cfg->max_level) {
		WRITE_WARNING_LOG("%s: equip level %d is beyond max_level %d.", __FUNCTION__, equip->level, cfg->max_level);
		return RET_FULL;
	}
	
	struct UpgradeConfig * upgradeCfg1 = get_upgrade_config(equip->level, cfg->level_up_type);
	if (upgradeCfg1 == 0) {
		WRITE_WARNING_LOG("  level config %d of equip %d upgrade type %d not exists", equip->level, equip->gid, cfg->level_up_type);
		return RET_FULL;
	}

	int dist_level = equip->level;
	int dist_exp   = equip->exp;

	struct UpgradeConfig * upgradeCfg2 = upgradeCfg1;
	if (level > 0) {
		dist_level += level;

		upgradeCfg2 = get_upgrade_config(dist_level, cfg->level_up_type);
		if (upgradeCfg2 == 0) {
			WRITE_WARNING_LOG("  dest level config %d of equip %d upgrade type %d not exists", dist_level, equip->gid, cfg->level_up_type);
			return RET_FULL;
		}

		dist_exp = upgradeCfg2->consume_value;
	}

	if (exp > 0) {
		dist_exp += exp;

		dist_level = calc_level_by_exp(dist_exp, cfg->level_up_type);
		upgradeCfg2 = get_upgrade_config(dist_level, cfg->level_up_type);
		if (upgradeCfg2 == 0) {
			WRITE_WARNING_LOG("  dest level config %d of equip %d upgrade type %d not exists", dist_level, equip->gid, cfg->level_up_type);
			return RET_FULL;
		}
	}

	if (upgradeCfg1->consume_type != upgradeCfg2->consume_type 
			|| upgradeCfg1->consume_id != upgradeCfg2->consume_id ) {
		WRITE_WARNING_LOG("  consume type %d/%d or id %d/%d not same", 
				upgradeCfg1->consume_type, upgradeCfg2->consume_type,
				upgradeCfg1->consume_id, upgradeCfg2->consume_id);
		return RET_ERROR;
	}

	if (dist_exp == equip->exp) {
		return RET_SUCCESS;
	}


	if (dist_exp < equip->exp) {
		WRITE_WARNING_LOG("  equip can't downgrade");
		return RET_PARAM_ERROR;
	}

	CommonCfg *ccfg = get_common_config(16);
	int factor = ccfg ? ccfg->para1 : 1;
	if (dist_level > player_get_level(player) * factor) {
		WRITE_DEBUG_LOG(" level limit %d/%d", dist_level, player_get_level(player));
		return RET_MAX_LEVEL;
	}
	
	CommonCfg *ccfg2 = get_common_config(17);
	struct Hero *hero = hero_get(player, 0, uuid);
	if (ccfg2 && hero && (unsigned) dist_level > hero->level * ccfg2->para1) {
		WRITE_DEBUG_LOG("%s: dist_level was in max %d", __FUNCTION__, hero->level);
		return RET_MAX_LEVEL;	
	}

	int ret = CheckAndConsume(player, upgradeCfg2->consume_type, upgradeCfg2->consume_id, 0, dist_exp - equip->exp, REASON_EQUIP_LEVEL_UP);
	if (ret != RET_SUCCESS) {
		return ret;
	}

	equip_change_exp(equip, dist_exp);
	
	unsigned long long pid = player_get_id(player);
	if (pid > AI_MAX_ID) {
		time_t now = agT_current();
		agL_write_user_logger(ARMAMENT_LOGGER, LOG_FLAT, "%d,%lld,%lld,%d,2,%d,%d", (int)now, pid, uuid, equip->gid, level, exp);
	}

	//quest
	if ( IS_EQUIP_TYPE_1(cfg->type) ) {
		aL_quest_on_event(player, QuestEventType_EQUIP_LEVEL_UP, 1, 1);
	}

	if ( IS_EQUIP_TYPE_2(cfg->type) ) {
		aL_quest_on_event(player, QuestEventType_EQUIP_LEVEL_UP, 2, 1);
	}

	return RET_SUCCESS;
}

//进阶 
int aL_equip_stage_up(Player * player, unsigned long long uuid)
{
	unsigned long long pid = player_get_id(player);

	WRITE_INFO_LOG("player %llu equip %llu stage up", pid, uuid);
	
	/* 装备进阶功能开启等级判断 */	
	if (!check_openlev_config(player, ROLE_EQUIP_STAGE_UP)) {
		return RET_PERMISSION;
	}

	struct Equip * equip = equip_get(player, uuid);
	if (!uuid) {
		WRITE_WARNING_LOG(" equip not exist");
		return RET_NOT_EXIST;
	}
	
	struct EquipConfig * cfg = get_equip_config(equip->gid);
	if (cfg == 0) {
		WRITE_WARNING_LOG("  equip config %d not exist", equip->gid);
		return RET_ERROR;
	}

	if (cfg->next_stage_id == 0 || cfg->next_stage_id == cfg->gid) {
		WRITE_DEBUG_LOG("  equip %d can't stage up", equip->gid);
		return RET_ERROR;
	}

	/* 装备进阶需要的最小等级判断 */
	if (equip->level < (unsigned int)cfg->min_level) {
		WRITE_WARNING_LOG("%s: equip stage up level %d not enough, need min level is %d.", __FUNCTION__, equip->level, cfg->min_level);
		return RET_NOT_ENOUGH;
	}	

	int i;
	WRITE_DEBUG_LOG("equip gid:%d uuid:%llu level:%d", equip->gid, equip->uuid, equip->level);
	for (i = 0; i < EQUIP_STAGE_UP_CONSUME_COUNT; i++) {
		if (CheckForConsume(player, cfg->stage_consume[i].type, cfg->stage_consume[i].id, equip->hero_uuid, cfg->stage_consume[i].value + cfg->stage_consume[i].increase_value * (equip->level - 1)) != 0) {
			return RET_NOT_ENOUGH;
		}
	}

	for (i = 0; i < EQUIP_STAGE_UP_CONSUME_COUNT; i++) {
		if (CheckAndConsume(player, cfg->stage_consume[i].type, cfg->stage_consume[i].id, equip->hero_uuid, cfg->stage_consume[i].value + cfg->stage_consume[i].increase_value * (equip->level - 1), REASON_EQUIP_STAGE_UP) != 0) {
			return RET_ERROR;	
		}
	}

	int old_gid = equip->gid;

	equip_change_gid(equip, cfg->next_stage_id);

	//quest
	if ( IS_EQUIP_TYPE_1(cfg->type) ) {
		aL_quest_on_event(player, QuestEventType_EQUIP_STAGE_UP, 1, 1);
	}

	if ( IS_EQUIP_TYPE_2(cfg->type) ) {
		aL_quest_on_event(player, QuestEventType_EQUIP_STAGE_UP, 2, 1);
	}
	
	if (pid > AI_MAX_ID) {
		time_t now = agT_current();
		agL_write_user_logger(ARMAMENT_LOGGER, LOG_FLAT, "%d,%lld,%lld,%d,3,%d", (int)now, pid, uuid, equip->gid,old_gid);
	}

	return RET_SUCCESS;
}

// 吞噬  消耗 相同sub_type铭文  => 随机属性取两者最大值
int aL_equip_eat(Player * player, unsigned long long dest, unsigned long long src)
{
	WRITE_INFO_LOG("player %llu equip %llu eat %llu", player_get_id(player), dest, src);

	struct Equip * destEquip = equip_get(player, dest);
	if (!destEquip) {
		WRITE_WARNING_LOG("  dest equip not exist");
		return RET_NOT_EXIST;
	}

	struct EquipConfig * destCfg = get_equip_config(destEquip->gid);
	if (!destCfg) {
		WRITE_WARNING_LOG("  dest equip config %d not exist", destEquip->gid);
		return RET_ERROR;
	}

	struct Equip * srcEquip = equip_get(player, src);
	if (!srcEquip) {
		WRITE_WARNING_LOG("  src equip not exist");
		return RET_NOT_EXIST;
	}

	struct EquipConfig * srcCfg = get_equip_config(srcEquip->gid);
	if (!srcCfg) {
		WRITE_WARNING_LOG("  src equip config %d not exist", srcEquip->gid);
		return RET_ERROR;
	}

	if (destCfg->eat_group == 0) {
		WRITE_WARNING_LOG("  dest equip %d can't eat", destEquip->gid);
		return RET_ERROR;
	}

	if (srcCfg->eat_group == 0) {
		WRITE_WARNING_LOG("  src equip %d can't be eat", srcEquip->gid);
		return RET_ERROR;
	}

	if (destCfg->eat_group != srcCfg->eat_group) {
		WRITE_WARNING_LOG("  eat_group of equip %d & %d not same", destCfg->eat_group,srcCfg->eat_group);
		return RET_ERROR;
	}

	struct EquipAffixInfo dstAffixInfo[EQUIP_PROPERTY_POOL_MAX];
	struct EquipAffixInfo srcAffixInfo[EQUIP_PROPERTY_POOL_MAX];

	struct EquipAffixConfig * srcConfig[EQUIP_PROPERTY_POOL_MAX] = {0};

	int i, j;
	for (i = 0; i < EQUIP_PROPERTY_POOL_MAX; i++) {
		equip_get_affix(destEquip, i + 1, &(dstAffixInfo[i].id), &(dstAffixInfo[i].value), &(dstAffixInfo[i].grow));
	}

	for (i = 0; i < EQUIP_PROPERTY_POOL_MAX; i++) {
		equip_get_affix(srcEquip, i + 1, &(srcAffixInfo[i].id), &(srcAffixInfo[i].value), &(srcAffixInfo[i].grow));
	}

	int srcUsed[EQUIP_PROPERTY_POOL_MAX] = {0};

	int merged = 0;

	for (i = 0; i < EQUIP_PROPERTY_POOL_MAX; i++) {
		int dst_affix_id = dstAffixInfo[i].id;
		if (dst_affix_id == 0) continue;

		struct EquipAffixConfig * dstAffixCfg = get_equip_affix_config(dst_affix_id);
		if (dstAffixCfg == 0) continue;

		int dst_affix_value = calc_affix_value(dstAffixInfo[i].id, dstAffixInfo[i].value, dstAffixInfo[i].grow, dstAffixCfg, destEquip->level);

		for (j = 0; j < EQUIP_PROPERTY_POOL_MAX; j++) {
			if (srcUsed[j]) continue;

			int src_affix_id = srcAffixInfo[j].id;
			if (src_affix_id == 0) continue;

			struct EquipAffixConfig * srcAffixCfg = srcConfig[j] ? srcConfig[j] : get_equip_affix_config(src_affix_id);
			if (srcAffixCfg == 0) continue;

			int src_affix_value = calc_affix_value(srcAffixInfo[i].id, srcAffixInfo[i].value, srcAffixInfo[i].grow, srcAffixCfg, destEquip->level);

			if (srcAffixCfg->property.type == dstAffixCfg->property.type && src_affix_value > dst_affix_value) {
				srcUsed[j] = 1;

				dstAffixInfo[i].id    = srcAffixInfo[i].id;
				dstAffixInfo[i].value = srcAffixInfo[i].value;
				dstAffixInfo[i].grow  = srcAffixInfo[i].grow;

				merged++;

				break;
			}
		}
	}

	if (!merged) {
		WRITE_DEBUG_LOG(" no property to merge");
		return RET_ERROR;
	}

	if (equip_delete(player, srcEquip, REASON_EQUIP_EAT) != 0) {
		return RET_ERROR;
	}
	
	for (i = 0; i < EQUIP_PROPERTY_POOL_MAX; i++) {
		equip_update_affix(destEquip, i + 1, dstAffixInfo[i].id, dstAffixInfo[i].value, dstAffixInfo[i].grow);
	}

	//quest
	aL_quest_on_event(player, QuestEventType_EQUIP_EAT, 1, 1);
	
	unsigned long long pid = player_get_id(player);
	if (pid > AI_MAX_ID) {
		time_t now = agT_current();
		agL_write_user_logger(ARMAMENT_LOGGER, LOG_FLAT, "%d,%lld,%lld,%d,4,%lld,%d", (int)now, pid, dest, destCfg->gid, src,  srcCfg->gid);
	}

	return RET_SUCCESS;
}

// 替换属性
int aL_equip_replace_property(Player * player, unsigned long long uuid, int index, int property_item_id)
{
	WRITE_INFO_LOG("player %llu change property %d of equip %llu with item %d", player_get_id(player), index, uuid, property_item_id);

	if (player == NULL) {
		return RET_ERROR;
	}

	struct Equip * equip = equip_get(player, uuid);
	if (!equip) {
		WRITE_WARNING_LOG("   equip not exist");
		return RET_NOT_EXIST;
	}

	int cur_scroll_id    = 0;
	int cur_scroll_value = 0;
	int cur_scroll_grow  = 0;

	if (equip_get_affix(equip, index, &cur_scroll_id, &cur_scroll_value, &cur_scroll_grow) != 0) {
		WRITE_WARNING_LOG("  unknown scroll index");
		return RET_PARAM_ERROR;
	}

	struct EquipConfig * equipCfg = get_equip_config(equip->gid);
	if (equipCfg == 0) {
		WRITE_DEBUG_LOG(" equip config %d not exists", equip->gid);
		return RET_ERROR;
	}

	struct EquipAffixConfig * cfg = get_equip_affix_config(property_item_id);
	if (cfg == 0) {
		WRITE_DEBUG_LOG(" property item config %d not exists", property_item_id);
		return RET_ERROR;
	}

	if ( (equipCfg->type & cfg->equip_type) == 0) {
		WRITE_DEBUG_LOG(" equip type mismatch 0x%x 0x%x", equipCfg->type, cfg->equip_type);
		return RET_PERMISSION;
	}

	if ( (cfg->slots & (1 << (index - 1))) == 0) {
		WRITE_DEBUG_LOG(" slot mismatch 0x%x 0x%x", cfg->slots, (1<<(index-1)));
		return RET_PERMISSION;
	}

	if (CheckAndConsume(player, 41, property_item_id, 0, 1, REASON_EQUIP_REPLACE_PROPERTY) != RET_SUCCESS) {
		return RET_NOT_ENOUGH;
	}

	int value = RAND_RANGE(cfg->property.min, cfg->property.max);

	equip_update_affix(equip, index, property_item_id, value, 0);

	if (cur_scroll_id > 0 && cfg->keep_origin_on_attach) {
		item_add(player, cur_scroll_id, 1, REASON_EQUIP_REPLACE_PROPERTY);
	}

	unsigned long long pid = player_get_id(player);
	if (pid > AI_MAX_ID) {
		time_t now = agT_current();
		agL_write_user_logger(ARMAMENT_LOGGER, LOG_FLAT, "%d,%lld,%lld,%d,5,%d,%d", (int)now, pid, uuid, equip->gid, index, property_item_id);
	}

	return RET_SUCCESS;
}

// 刷新属性
int aL_equip_refresh_property(Player * player, unsigned long long uuid, int index, int confirm, int * out_affix_id, int * out_affix_value) 
{
	WRITE_INFO_LOG("player %llu refresh equip %llu affix %d, confirm %d", player_get_id(player), uuid, index, confirm);

	struct Equip * equip = equip_get(player, uuid);
	if (equip == 0) {
		WRITE_DEBUG_LOG("  equip not exists");
		return RET_NOT_EXIST;
	}

	int affix_id = 0;
	int affix_value = 0;
	int affix_grow = 0;

	if (equip_get_affix(equip, index, &affix_id, &affix_value, &affix_grow) != 0) {
		WRITE_DEBUG_LOG("  index error");
		return RET_PARAM_ERROR;
	}

	if (affix_id == 0) {
		WRITE_DEBUG_LOG("  affix not exists");
		return RET_PARAM_ERROR;
	}

	struct EquipAffixConfig * cfg = get_equip_affix_config(affix_id);
	if (cfg == 0) {
		WRITE_DEBUG_LOG("  affix config of %d not exists", affix_id);
		return RET_ERROR;
	}

	if (cfg->refresh.pool == 0) {
		WRITE_DEBUG_LOG("  affix of %d can't refresh", affix_id);
		return RET_ERROR;
	}

	struct CheckData * cache = player_get_check_data(player);

	if (confirm & 1) {
		int exclude [EQUIP_PROPERTY_POOL_MAX] = {0};

		int i = 0;
		for (i = 1; i <= EQUIP_PROPERTY_POOL_MAX; i++) {
			if (i == index) continue;

			int id, value, grow;
			equip_get_affix(equip, i, &id, &value, &grow);

			if (id == 0) continue;
	
			struct EquipAffixConfig * e_cfg = get_equip_affix_config(id);
			if (e_cfg) {
				exclude[i-1] = e_cfg->property.type;
			}
		}
		

		int value = 0;
		struct EquipAffixConfig * new_cfg = affix_pool_choose(cfg->refresh.pool, &value, exclude);
		if (new_cfg == 0) {
			return RET_ERROR;
		}

		if (CheckAndConsume(player, cfg->refresh.cost.type, cfg->refresh.cost.id, 0, cfg->refresh.cost.value, REASON_EQUIP_REFRESH_PROPERTY) != 0) {
			WRITE_DEBUG_LOG(" consume error");
			return RET_NOT_EXIST;
		}

		struct CommonCfg * commonCfg = get_common_config(14);
		if (commonCfg && commonCfg->para1 > 0) {
			equip_add_value(player, equip, cfg->refresh.cost.type, cfg->refresh.cost.id, cfg->refresh.cost.value * commonCfg->para1 / 10000);
		}

		cache->affix_refresh_info.uuid  = uuid;
		cache->affix_refresh_info.index = index;
		cache->affix_refresh_info.gid   = new_cfg->id;
		cache->affix_refresh_info.value = value;

		if (out_affix_id)    *out_affix_id     = new_cfg->id;
		if (out_affix_value) *out_affix_value = value;

		aL_quest_on_event(player, QuestEventType_EQUIP_PROPERTY_REFRESH, 1, 1);
	}  

	if (confirm & 2) {
		if (cache->affix_refresh_info.uuid != uuid) {
			WRITE_DEBUG_LOG("  uuid %lld != %lld", cache->affix_refresh_info.uuid, uuid);
			return RET_PARAM_ERROR;
		}

		equip_update_affix(equip, cache->affix_refresh_info.index, cache->affix_refresh_info.gid, cache->affix_refresh_info.value, affix_grow);

		if (out_affix_id)    *out_affix_id    = cache->affix_refresh_info.gid;
		if (out_affix_value) *out_affix_value = cache->affix_refresh_info.value;

		cache->affix_refresh_info.uuid  = 0;
		cache->affix_refresh_info.index = 0;
		cache->affix_refresh_info.gid   = 0;
		cache->affix_refresh_info.value = 0;
	}
	
	unsigned long long pid = player_get_id(player);
	if (pid > AI_MAX_ID) {
		time_t now = agT_current();
		agL_write_user_logger(ARMAMENT_LOGGER, LOG_FLAT, "%d,%lld,%lld,%d,6,%d,%d", (int)now, pid, uuid, equip->gid, index, confirm);
	}

	return RET_SUCCESS;
}

// 属性洗练
int aL_equip_affix_grow(Player * player, unsigned long long uuid, int count)
{
	WRITE_INFO_LOG("player %llu equip %llu affix grow %d", player_get_id(player), uuid, count);
	if (count <= 0) {
		WRITE_DEBUG_LOG("  count == 0");
		return RET_ERROR;
	}

	struct Equip * equip = equip_get(player, uuid);
	if (equip == 0) {
		WRITE_DEBUG_LOG("  equip not exists");
		return RET_NOT_EXIST;
	}

	struct EquipAffixInfo affix[EQUIP_PROPERTY_POOL_MAX];

	struct {
		int type;
		int id;
		int value;
	} cost[EQUIP_PROPERTY_POOL_MAX * EQUIP_AFFIX_GROW_COST_COUNT];

	memset(cost, 0, sizeof(cost));

	int i, j, k, n = 0;
	for (i = 0; i < EQUIP_PROPERTY_POOL_MAX; i++) {
		equip_get_affix(equip, i + 1, &(affix[i].id), &(affix[i].value), &(affix[i].grow));
		if (affix[i].id == 0) {
			continue;
		}


		struct EquipAffixConfig * cfg = get_equip_affix_config(affix[i].id);
		if (cfg == 0) {
			WRITE_DEBUG_LOG("  affix config of %d not exists", affix[i].id);
			return RET_ERROR;
		}

		if (cfg->grow.range.min == cfg->grow.range.max && cfg->grow.range.min == 0) {
			WRITE_DEBUG_LOG(" affix %d can't grow", affix[i].id);
			continue;
		}

		int max_value = calc_affix_grow_max_value(cfg, equip->level);

		if (calc_affix_value(affix[i].id, affix[i].value, affix[i].grow, cfg, equip->level) >= max_value) {
			continue;
		}

		for (k = 0; k < EQUIP_AFFIX_GROW_COST_COUNT; k++) {
			if (cfg->grow.cost[k].value == 0) {
				continue;
			}

			for (j = 0; j < EQUIP_PROPERTY_POOL_MAX * EQUIP_AFFIX_GROW_COST_COUNT; j++) {
				if ( (cost[j].type == cfg->grow.cost[k].type && cost[j].id == cfg->grow.cost[k].id) || cost[j].type == 0) {
					cost[j].type   = cfg->grow.cost[k].type;
					cost[j].id     = cfg->grow.cost[k].id;
					cost[j].value += cfg->grow.cost[k].value * count;
					break;
				}
			}
		}


		if (count < 10) {
			int c = 0;
			for (c = 0; c < count; c++) {
				affix[i].grow += RAND_RANGE(cfg->grow.range.min, cfg->grow.range.max);
			}
		} else {
			int average = (cfg->grow.range.min + cfg->grow.range.max) / 2;
			affix[i].grow += count * average + RAND_RANGE(-count * average / 5, count * average / 5);
		}

		if (affix[i].grow < 0) {
			affix[i].grow = 0;
		}

		int next_value = calc_affix_value(affix[i].id, affix[i].value, affix[i].grow, cfg, equip->level);
		if (next_value > max_value) {
			affix[i].grow -= next_value - max_value;
		}

		n++;
	}

	if (n == 0) {
		WRITE_DEBUG_LOG("  not affix to grow");
		return RET_ERROR;
	}

	for (i = 0; i < EQUIP_PROPERTY_POOL_MAX * EQUIP_AFFIX_GROW_COST_COUNT; i++) {
		if (CheckForConsume(player, cost[i].type, cost[i].id, 0, cost[i].value) != 0) {
			return RET_NOT_ENOUGH;
		}
	}

	struct CommonCfg * commonCfg = get_common_config(15);
	for (i = 0; i < EQUIP_PROPERTY_POOL_MAX * EQUIP_AFFIX_GROW_COST_COUNT; i++) {
		if (CheckAndConsume(player, cost[i].type, cost[i].id, 0, cost[i].value, REASON_EQUIP_AFFIX_GROW) != 0) {
			return RET_NOT_ENOUGH;
		}

		if (commonCfg && commonCfg->para1 > 0) {
			equip_add_value(player, equip, cost[i].type, cost[i].id, cost[i].value * commonCfg->para1 / 10000);
		}
	}

	for (i = 0; i < EQUIP_PROPERTY_POOL_MAX; i++) {
		equip_update_affix(equip, i+1, affix[i].id, affix[i].value, affix[i].grow);
	}

	//quest
	struct EquipConfig * cfg = get_equip_config(equip->gid);
	if (cfg) {
		if ( IS_EQUIP_TYPE_1(cfg->type) ) {
			aL_quest_on_event(player, QuestEventType_AFFIX_GROW, 1, count);
		}

		if ( IS_EQUIP_TYPE_2(cfg->type) ) {
			aL_quest_on_event(player, QuestEventType_AFFIX_GROW, 2, count);
		}
	}
	
	unsigned long long pid = player_get_id(player);
	if (pid > AI_MAX_ID) {
		time_t now = agT_current();
		agL_write_user_logger(ARMAMENT_LOGGER, LOG_FLAT, "%d,%lld,%lld,%d,7,%d", (int)now, pid, uuid, equip->gid, count);
	}

	return RET_SUCCESS;
}

static int check_equip_placeholder(struct Hero * hero, struct Equip * equip, struct EquipConfig * cfg, int placeholder)
{
	/* 角色穿戴等级限制 */
	struct CommonCfg * commonCfg = get_common_config(17);
	if ( commonCfg && hero && (hero->level < equip->level * commonCfg->para1) ) {
		WRITE_WARNING_LOG(" hero %lld(%d) level limit(17) %d/%d.", hero->uuid, hero->gid, hero->level, equip->level * commonCfg->para1);
		return 0;
	}

	if (hero && cfg->equip_level > (int)hero->level) {
		WRITE_WARNING_LOG(" hero %lld(%d) level limit(equip_level) %d/%d.", hero->uuid, hero->gid, hero->level, cfg->equip_level);
		return 0;
	}

	int pos   =  (placeholder & 0xff);
	int group = ((placeholder & 0xff00) >> 8);

	if (pos == 0) {
		return 1;
	}

	if (pos < 0 || pos > EQUIP_INTO_BATTLE_MAX) {
		WRITE_DEBUG_LOG("  place error");
		return 0;
	}

	if (cfg == 0) {
		WRITE_DEBUG_LOG("  equipment config error");
	}

	if ( (cfg->type & (1<<(pos-1))) == 0) {
		WRITE_DEBUG_LOG("  place error %d", cfg->type);
		return 0;
	}

	int max_equip_group_count = 1;

	if (IS_EQUIP_TYPE_1(cfg->type)) {
		struct CommonCfg * commonCfg = get_common_config(12);
		max_equip_group_count += (commonCfg ? commonCfg->para2 : 0);
	} else if (IS_EQUIP_TYPE_2(cfg->type)) {
		struct CommonCfg * commonCfg = get_common_config(13);
		max_equip_group_count += (commonCfg ? commonCfg->para2 : 0);
	}

	if (group >= max_equip_group_count) {
		// WRITE_DEBUG_LOG(" group %d > max_equip_group_count(%d)", group, max_equip_group_count);
		// return 0;
	}

	return 1;
}


static struct ConsumeCfg * GetEquipChangeCostConfig(struct EquipConfig * cfg) 
{
	struct ConsumeCfg * consumeConfig = 0;
	if ( IS_EQUIP_TYPE_1(cfg->type) ) {
		consumeConfig = get_consume_config(cfg->quality + 10);
	} else if ( IS_EQUIP_TYPE_2(cfg->type) ) {
		consumeConfig = get_consume_config(cfg->quality + 20);
	}

	if (consumeConfig && consumeConfig->item_value > 0) {
		return consumeConfig;
	}
	return 0;
}

static int EquipChangeCost(struct Player * player, struct EquipConfig * cfg)
{
	if (cfg == 0) return 0;
	
	struct ConsumeCfg * consumeConfig = GetEquipChangeCostConfig(cfg);

	if (consumeConfig && consumeConfig->item_value > 0) {
		return CheckAndConsume(player, consumeConfig->item_type, consumeConfig->item_id, 0, consumeConfig->item_value, REASON_EQUIP_CHANGE_POSITION);
	}
	return 0;
}


static int EquipChangeCost2(struct Player * player, struct EquipConfig * cfg1, struct EquipConfig * cfg2)
{
	struct ConsumeCfg * consumeConfig1 = GetEquipChangeCostConfig(cfg1);
	struct ConsumeCfg * consumeConfig2 = GetEquipChangeCostConfig(cfg2);

	if (consumeConfig1 == 0 && consumeConfig2 == 0) {
		return 0;
	} else if (consumeConfig1 != 0 && consumeConfig2 == 0) {
		return CheckAndConsume(player, consumeConfig1->item_type, consumeConfig1->item_id, 0, consumeConfig1->item_value, REASON_EQUIP_CHANGE_POSITION);
	} else if (consumeConfig1 == 0 && consumeConfig2 != 0) {
		return CheckAndConsume(player, consumeConfig2->item_type, consumeConfig2->item_id, 0, consumeConfig2->item_value, REASON_EQUIP_CHANGE_POSITION);
	} else if (consumeConfig1->item_type == consumeConfig2->item_type || consumeConfig1->item_id == consumeConfig2->item_id) {
		return CheckAndConsume(player, consumeConfig1->item_type, consumeConfig1->item_id, 0, consumeConfig1->item_value + consumeConfig2->item_value, REASON_EQUIP_CHANGE_POSITION);
	}

	if (CheckForConsume(player, consumeConfig1->item_type, consumeConfig1->item_id, 0, consumeConfig1->item_value) != 0) {
		return -1;
	}

	if (CheckForConsume(player, consumeConfig2->item_type, consumeConfig2->item_id, 0, consumeConfig2->item_value) != 0) {
		return -1;
	}


	CheckAndConsume(player, consumeConfig2->item_type, consumeConfig2->item_id, 0, consumeConfig2->item_value, REASON_EQUIP_CHANGE_POSITION);
	CheckAndConsume(player, consumeConfig2->item_type, consumeConfig2->item_id, 0, consumeConfig2->item_value, REASON_EQUIP_CHANGE_POSITION);

	return 0;
}


int aL_equip_update_fight_formation(Player * player, unsigned long long uuid, int heroid, int new_place, unsigned long long hero_uuid)
{
	WRITE_INFO_LOG("player %llu change equip %llu placeholder to %d(%llu) pos %d", player_get_id(player), uuid, heroid, hero_uuid, new_place);
	
	/* 装备和铭文位置功能开启判断 */
	int group = ( new_place & 0xff00 ) >> 8;
	int pos = new_place & 0xff;
	// int level = player_get_level(player);
	// int group_open_level = 0;
	// int slot_open_level = 0;
	// OpenLevCofig *config = NULL;

	const static int slot_open_level_cfg_id[] = {
		0,

		ROLE_EQUIP_INDEX2 + 0,
		ROLE_EQUIP_INDEX2 + 1,
		ROLE_EQUIP_INDEX2 + 2,
		ROLE_EQUIP_INDEX2 + 3,
		ROLE_EQUIP_INDEX2 + 4,
		ROLE_EQUIP_INDEX2 + 5,

		ROLE_EQUIP_INDEX + 0,
		ROLE_EQUIP_INDEX + 1,
		ROLE_EQUIP_INDEX + 2,
		ROLE_EQUIP_INDEX + 3,
		ROLE_EQUIP_INDEX + 4,
		ROLE_EQUIP_INDEX + 5,
	};

	const static int nslot = sizeof(slot_open_level_cfg_id) / sizeof(slot_open_level_cfg_id[0]);

	if (pos > 0 && pos < nslot) {
		// group_open_level
		if (!check_openlev_config(player, ((pos <= 6) ? ROLE_EQUIP_GROUP2 : ROLE_EQUIP_GROUP) + group)) {
			return RET_PERMISSION;	
		}

		// slot_open_level
		if (!check_openlev_config(player, slot_open_level_cfg_id[pos])) {
			return RET_PERMISSION;	
		}
	} else if (pos != 0) {
		WRITE_WARNING_LOG(" equip update fight failed, slot error");
		return RET_PERMISSION;
	}

/*
	if (level < group_open_level || level < slot_open_level ) {
		WRITE_WARNING_LOG(" equip update fight failed, level is not enough, level is %d, group open level is %d, slot open level is %d.", level, group_open_level, slot_open_level);
		return RET_PERMISSION;
	}
*/

	struct Equip * equip = equip_get(player, uuid);
	if (equip == NULL) {
		WRITE_DEBUG_LOG("  equip not exist");
		return RET_NOT_EXIST;
	}

	struct Hero * cur_hero = equip->hero_uuid ? hero_get(player, equip->hero_uuid, 0) : 0;

	struct Hero * hero = 0;
	if (heroid != 0 || hero_uuid != 0) {
		hero = hero_get(player, heroid, hero_uuid);
		if (hero == 0) {
			WRITE_DEBUG_LOG("  hero not exists");
			return RET_ERROR;
		}
		hero_uuid = hero->uuid;
	}

	if (equip->hero_uuid == hero_uuid && 
			equip->placeholder == new_place) {
		WRITE_DEBUG_LOG("  equip no change");
		return RET_SUCCESS;
	}

	struct EquipConfig * cfg = get_equip_config(equip->gid);
	if (cfg == 0) {
		WRITE_DEBUG_LOG(" equip config %d not exist", equip->gid);
		return RET_ERROR;
	}

	if ( hero_uuid == 0 || (new_place & 0xff) == 0) {
		if (equip->hero_uuid != 0) { // move equipment to bag
			if (EquipChangeCost(player, cfg) != 0) {
				return RET_RESOURCES;
			}
			equip_change_pos(player, equip, 0, 0, 0);
		}
		return RET_SUCCESS;
	}

	if (!check_equip_placeholder(hero, equip, cfg, new_place)) {
		return RET_ERROR;
	}

	unsigned long long old_equip_move_to_uuid  = 0;
	unsigned int old_equip_move_to_id          = 0;
	unsigned int old_equip_move_to_placeholder = 0;

	struct Equip * old_equip = equip_get_by_hero(player, hero->uuid, new_place);
	struct EquipConfig * old_cfg = old_equip ? get_equip_config(old_equip->gid) : 0;
	if (old_cfg == 0) {
		if (old_equip) {
			equip_change_pos(player, old_equip, 0, 0, 0);
			old_equip = 0;
		}
	}

	if (equip->hero_uuid == 0) { // not equiped
		if (old_equip) { // move old equipment to bag
			struct EquipConfig * old_cfg = get_equip_config(old_equip->gid);
			if  (EquipChangeCost(player, old_cfg) != 0) {
				return RET_RESOURCES;
			}
		} else { // target is empty, no cost

		}
	} else {
		if (equip->hero_uuid == hero_uuid) { // exchange between one hero, no cost
	
		} else {
			if (old_equip) { // exchange between two hero, cost * 2
				if (EquipChangeCost2(player, cfg, old_cfg) != 0) {
					return RET_RESOURCES; 
				}
			} else { // move from one hero to another
				if (EquipChangeCost(player, cfg) != 0) {
					return RET_RESOURCES;
				}
			}
		}
	}


	if (old_equip && check_equip_placeholder(cur_hero, old_equip, get_equip_config(old_equip->gid), equip->placeholder)) {
		old_equip_move_to_uuid        = equip->hero_uuid;
		old_equip_move_to_id          = equip->heroid;
		old_equip_move_to_placeholder = equip->placeholder;
	}

	if (old_equip) equip_change_pos(player, old_equip, 0, 0, 0);
	equip_change_pos(player, equip, hero->gid, hero->uuid, new_place);
	if (old_equip) equip_change_pos(player, old_equip, old_equip_move_to_id, old_equip_move_to_uuid, old_equip_move_to_placeholder);
	
	// time_t now = agT_current();
	// agL_write_user_logger(ARMAMENT_LOGGER, LOG_FLAT, "%d,%d,%lld,%lld,%d,%d,%d,", now, 8, player_get_id(player), uuid, heroid, new_place, hero_uuid);

	return RET_SUCCESS;
}

int32_t aL_open_item_package(Player* player, int32_t id, int32_t reason, int32_t* depth, struct RewardItem * record, int nitem){
	if(*depth >= 1) return 0;
	*depth +=1;
	PITEM_PACKAGE pkg_cfg =get_item_package_config(id);
	if(pkg_cfg == 0){
		WRITE_DEBUG_LOG("fail to `%s`, item package %d is not exist", __FUNCTION__, id);
		return -1;
	}
	WRITE_DEBUG_LOG("`%llu` open item package %d", player_get_id(player), id);
	struct RewardContent content;
	PITEM item =pkg_cfg->item_list;
	while(item){
		memset(&content, 0, sizeof(content));
		content.type   =item->type;
		content.key    =item->id;
		content.value  =item->value;

		reward_add_one(player, &content, reason, record, nitem);

		// next
		item =item->next;
	}
	return 0;
}

static int check_for_consume_item_package(Player * player, int package_id, int value)
{
	PCITEM_PACKAGE pkg_cfg =get_consume_item_package_config(package_id);
	if(pkg_cfg == 0){
		WRITE_DEBUG_LOG("fail to `%s`, consume item package %d is not exist", __FUNCTION__, package_id);
		return -1;
	}
	WRITE_DEBUG_LOG("`%llu` check for consume item package %d", player_get_id(player), package_id);
	PCITEM item =pkg_cfg->item_list;
	int item_enough = 0;
	while(item){
		
		int type = item->type;	
		int id = item->id;
		int item_value = item->value;
		if (type == REWARD_TYPE_ITEM) {
			Item * ite = item_get(player, id);
			if (ite == 0 || ite->limit < (unsigned int)(item_value * value)|| ite->limit == 0) {
				//WRITE_DEBUG_LOG("\titem %u not enough, %u/%u", id, item ? item->limit : 0, value);
				item =item->next;
				continue;
			} else {
				item_enough = 1;
				break;
			}
		}

		// next
		item =item->next;
	}

	if (!item_enough) return -1;

	return 1;
}

static int consume_for_consume_item_package(Player * player, int package_id, int value, unsigned int reason)
{
	PCITEM_PACKAGE pkg_cfg =get_consume_item_package_config(package_id);
	if(pkg_cfg == 0){
		WRITE_DEBUG_LOG("fail to `%s`, consume item package %d is not exist", __FUNCTION__, package_id);
		return -1;
	}
	WRITE_DEBUG_LOG("`%llu` consume for consume item package %d", player_get_id(player), package_id);
	PCITEM item =pkg_cfg->item_list;
	while(item){
		
		int type = item->type;	
		int id = item->id;
		int item_value = item->value;
		if (type == REWARD_TYPE_ITEM) {
			Item * ite = item_get(player, id);
			if (ite == 0 || ite->limit < (unsigned int)(item_value * value) || ite->limit == 0) {
				//WRITE_DEBUG_LOG("\titem %u not enough, %u/%u", id, item ? item->limit : 0, value);
				item =item->next;
				continue;
			} else {
				item_remove(ite, item_value * value, reason);
				return 1;
			}
		}

		// next
		item =item->next;
	}

	return -1;	
}

//检查依赖的副本是否通关
static int check_depend_fight(Player * player, int fight_id)
{
	if (player == NULL)
	{
		return RET_ERROR;
	}

	if (fight_id == 0)
	{
		return RET_SUCCESS;
	}

	struct PVE_FightConfig * pCfg = get_pve_fight_config(fight_id);
	if (pCfg == NULL)
	{
		WRITE_DEBUG_LOG("%s player %llu not found pve fight config %d", __FUNCTION__, player_get_id(player), fight_id);
		return RET_NOT_EXIST;
	}

	if (fight_result(player, fight_id) != PVE_FIGHT_SUCCESS)
	{
		WRITE_DEBUG_LOG("%s player %llu depend fight %d is lock", __FUNCTION__, player_get_id(player), fight_id);
		return RET_FIGHT_CHECK_DEPEND_FAIL;
	}

	return RET_SUCCESS;
}

//检查依赖的battle是否通关
static int check_battle_fight(Player * player, int fightid)
{
	if (player == NULL)
	{
		return RET_ERROR;
	}

	struct BattleConfig * pBattle = get_pve_fight_battle_config(fightid);//找到当前副本从属的battle
	if (pBattle == NULL)
	{
		return RET_SUCCESS;
		/*
		   WRITE_DEBUG_LOG("%s player %llu get battle by pve fight %d fail", __FUNCTION__, player_get_id(player), gid);
		   return RET_NOT_EXIST;
		   */
	}

	if (pBattle->rely_battle == 0)//没有依赖关系
	{
		return RET_SUCCESS;
	}

	struct BattleConfig * pRelyBattle = get_battle_config(pBattle->rely_battle);//找到当前battle所依赖的battle
	if (pRelyBattle == NULL)
	{
		WRITE_DEBUG_LOG("%s player %llu get rely battle %d fail", __FUNCTION__, player_get_id(player), pBattle->rely_battle);
		return RET_NOT_EXIST;
	}

	struct PVE_FightConfig * pPve = get_pve_fight_config(pRelyBattle->finish_id);//找到依赖battle的通关副本
	if (pPve == NULL)
	{
		WRITE_DEBUG_LOG("%s player %llu get rely battle %d finish id %d fail", __FUNCTION__, player_get_id(player), pBattle->battle_id, pRelyBattle->finish_id);
		return RET_NOT_EXIST;
	}

	if (fight_result(player, pPve->gid) != PVE_FIGHT_SUCCESS)
	{
		WRITE_DEBUG_LOG("%s player %llu fight %d is lock", __FUNCTION__, player_get_id(player), pPve->gid);
		return RET_FIGHT_CHECK_BATTLE_FAIL;
	}

	if (pBattle->quest_id > 0) {
		struct Quest * quest = quest_get(player, pBattle->quest_id);
		if (quest == 0 || quest->count == 0)
		{
			WRITE_DEBUG_LOG("%s player %llu , rely quest %d not finish", __FUNCTION__, player_get_id(player), pBattle->quest_id);
			return RET_FIGHT_CHECK_BATTLE_FAIL;
		}
	}

	return RET_SUCCESS;
}

//检查依赖的chapter是否通关
static int check_chapter_fight(Player * player, int fightid)
{
	if (player == NULL)
	{
		return RET_ERROR;
	}

	struct ChapterConifg * pChapter = get_pve_fight_chapter_config(fightid);//获取当前副本从属的chapter
	if (pChapter == NULL)
	{
		return RET_SUCCESS;
		/*
		   WRITE_DEBUG_LOG("%s player %llu get chapter by pve fight %d fail", __FUNCTION__, player_get_id(player), gid);
		   return RET_NOT_EXIST;
		   */
	}

	if (pChapter->rely_chapter == 0)//没有依赖chapter
	{
		return RET_SUCCESS;
	}

	struct ChapterConifg * pRelyChapter = get_chapter_config(pChapter->rely_chapter);//获取依赖的chapter
	if (pRelyChapter == NULL)
	{
		WRITE_DEBUG_LOG("%s player %llu get chapter %d rely chapter %d fail", __FUNCTION__, player_get_id(player), pChapter->chapter_id, pChapter->rely_chapter);
		return RET_NOT_EXIST;
	}

	struct BattleConfig * pBattle = get_battle_config(pRelyChapter->finish_id);//获取该依赖chapter的通关battle
	if (pBattle == NULL)
	{
		WRITE_DEBUG_LOG("%s player %llu get chapter %d finish battle %d fail", __FUNCTION__, player_get_id(player), pRelyChapter->chapter_id, pRelyChapter->finish_id);
		return RET_NOT_EXIST;
	}

	struct PVE_FightConfig * pPve = get_pve_fight_config(pBattle->finish_id);//获取battle的通关副本
	if (pPve == NULL)
	{
		WRITE_DEBUG_LOG("%s player %llu get battle %d finish fight %d fail", __FUNCTION__, player_get_id(player), pBattle->battle_id, pBattle->finish_id);
		return RET_NOT_EXIST;
	}

	if (fight_result(player, pPve->gid) != PVE_FIGHT_SUCCESS)
	{
		WRITE_DEBUG_LOG("%s player %llu fight %d is lock", __FUNCTION__, player_get_id(player), pPve->gid);
		return RET_NOT_ENOUGH;
	}

	return RET_SUCCESS;
}

int aL_pve_fight_is_open(Player * player, int gid)
{
	return check_depend_fight(player, gid);
}


static int pve_fight_consume(struct Player * player, struct PVE_FightConfig * pCfg, int consume) 
{
	struct BattleConfig * pBattle = get_pve_fight_battle_config(pCfg->gid);//找到当前副本从属的battle

	if (pBattle && pBattle->fight_cost.type != 0 && CheckForConsume(player, pBattle->fight_cost.type, pBattle->fight_cost.id, 0, pBattle->fight_cost.value) != 0) {
		return RET_NOT_ENOUGH;
	}

	if (pCfg->check.type != 0 && CheckForConsume(player, pCfg->check.type, pCfg->check.id, 0, pCfg->check.value) != 0) {
		return RET_NOT_ENOUGH;
	}
	
	if (pCfg->cost.type != 0 && CheckForConsume(player, pCfg->cost.type, pCfg->cost.id, 0, pCfg->cost.value) != 0) {
		return RET_NOT_ENOUGH;
	}

	if (!consume) {
		return RET_SUCCESS;
	}

	if (pBattle && pBattle->fight_cost.type != 0 && CheckAndConsume(player, pBattle->fight_cost.type, pBattle->fight_cost.id, 0, pBattle->fight_cost.value, RewardAndConsumeReason_PVE_Fight_Cost) != 0) {
		return RET_NOT_ENOUGH;
	}
	
	if (pCfg->cost.type != 0 && CheckAndConsume(player, pCfg->cost.type, pCfg->cost.id, 0, pCfg->cost.value, RewardAndConsumeReason_PVE_Fight_Cost) != 0) {
		return RET_NOT_ENOUGH;
	}

	return RET_SUCCESS;
}


int aL_pve_fight_prepare(Player * player, int gid, int auto_fight, int yjdq, char * buffer)
{
	WRITE_DEBUG_LOG("player %llu prepare fight %d", player_get_id(player), gid);
	if (player == NULL)
	{
		WRITE_DEBUG_LOG(" player == null");
		return RET_ERROR;
	}

	struct PVE_FightConfig * pCfg = get_pve_fight_config(gid);
	if (pCfg == NULL)
	{
		WRITE_DEBUG_LOG("%s player %llu not found config %d", __FUNCTION__, player_get_id(player), gid);
		return RET_NOT_EXIST;
	}

	if ((auto_fight != 0) && pCfg->support_god_hand == 0)//玩家要求自动战斗但该关卡不能自动战斗
	{
		WRITE_DEBUG_LOG(" can't auto fight");
		return RET_FIGHT_CHECK_AUTO_FAIL;
	}

	if ((yjdq != 0) && pCfg->can_yjdq == 0)//玩家要求扫荡但该关卡不能扫荡
	{
		WRITE_DEBUG_LOG(" can't fast pass");
		return RET_FIGHT_CHECK_YJDQ_FAIL;
	}

	if (pCfg->depend_level_id > player_get_level(player)) {
		WRITE_DEBUG_LOG(" level %d/%d", player_get_level(player), pCfg->depend_level_id);
		return RET_FIGHT_CHECK_LEVEL_FAIL;
	}

	// 检查星星数依赖
	Property * property = player_get_property(player);
	if ((int)property->total_star < pCfg->depend_star_count) {
		WRITE_DEBUG_LOG(" star %d/%d", property->total_star, pCfg->depend_star_count);
		return RET_FIGHT_CHECK_STAR_FAIL;
	}

	//检查副本依赖
	if (RET_SUCCESS != check_depend_fight(player, pCfg->depend_fight0_id)
			|| RET_SUCCESS != check_depend_fight(player, pCfg->depend_fight1_id))
	{
		WRITE_DEBUG_LOG(" fight depend error");
		return RET_FIGHT_CHECK_DEPEND_FAIL;
	}

	//检查battle依赖
	if (RET_SUCCESS != check_battle_fight(player, gid))
	{
		WRITE_DEBUG_LOG(" battle depend error");
		return RET_FIGHT_CHECK_BATTLE_FAIL;
	}

	//检查chapter依赖
	if (RET_SUCCESS != check_chapter_fight(player, gid))
	{
		WRITE_DEBUG_LOG(" chapter depend error");
		return RET_FIGHT_CHECK_CHAPTER_FAIL;
	}

	if (pve_fight_consume(player, pCfg, 0) != RET_SUCCESS) {
		return RET_NOT_ENOUGH;
	}

	int cur_id = fight_current_id(player);
	if (cur_id != 0)//当前在副本中
	{
		struct Fight * cur = fight_get(player, cur_id);
		if ((time(NULL) - cur->update_time) <= FIGHT_SPACE_TIME)//小于战斗间隔
		{
			return RET_FIGHT_CHECK_SPACE_FAIL;
		}
	}

	int r = fight_prepare(player, gid, pCfg->count_per_day, yjdq);
	if (r != RET_SUCCESS) {
		return r;
	}

	return RET_SUCCESS;
}

static void reset_fight(struct Fight * fight)
{
	if (fight) {
		fight_set_daily_count(fight, 0);
	}
}

static void reset_battle(struct Player * player, struct BattleConfig * battle)
{
	struct PVE_FightConfig * fight = 0;
	while ((fight = dlist_next(battle->fights, fight)) != 0) {
		reset_fight(fight_get(player, fight->gid));
	}
}

static void reset_chapter(struct Player * player, struct ChapterConifg * chapter)
{
	struct BattleConfig * battle = 0;
	while ((battle = dlist_next(chapter->battles, battle)) != 0) {
		reset_battle(player, battle);
	}
}

int aL_pve_fight_reset_count(Player * player, int gid, int battle, int chapter)
{
	WRITE_INFO_LOG("player %lld reset fight %d, battle %d, chapter %d", player_get_id(player), gid, battle, chapter);
	
	if (chapter != 0) {
		struct ChapterConifg * cfg = get_chapter_config(chapter);
		if (cfg == 0) {
			WRITE_DEBUG_LOG("  chapter not exists");
			return RET_ERROR;
		}

		if (cfg->reset_cost.type == 0) {
			WRITE_DEBUG_LOG(" chapter cant reset");
			return RET_ERROR;
		}

		if (CheckAndConsume(player, cfg->reset_cost.type, cfg->reset_cost.id, 0, cfg->reset_cost.value, REASON_FIGHT_RESET) != 0) {
			return RET_NOT_ENOUGH;
		}

		reset_chapter(player, cfg);
	} else if (battle != 0) {
		struct BattleConfig * cfg = get_battle_config(battle);
		if (cfg == 0) {
			WRITE_DEBUG_LOG(" battle not exists");
			return RET_ERROR;
		}


		if (cfg->reset_cost.type == 0) {
			WRITE_DEBUG_LOG(" battle cant reset");
			return RET_ERROR;
		}

		if (CheckAndConsume(player, cfg->reset_cost.type, cfg->reset_cost.id, 0, cfg->reset_cost.value, REASON_FIGHT_RESET) != 0) {
			return RET_NOT_ENOUGH;
		}

		reset_battle(player, cfg);
	} else if (gid != 0) {
		struct PVE_FightConfig * pCfg = get_pve_fight_config(gid);
		if (pCfg == NULL) {
			WRITE_DEBUG_LOG(" fight not exists");
			return RET_ERROR;
		}

		if (pCfg->reset_consume_id == 0) {
			WRITE_DEBUG_LOG(" fight can't reset");
			return RET_ERROR;
		}

		/* 当前挑战次数是否为0 */		
		struct Fight * fight = fight_get(player, gid);
		if (fight == 0 || fight->flag == 0) {
			WRITE_ERROR_LOG(" fight not pass");
			return RET_ERROR;
		}

		if (fight->today_count == 0) {
			WRITE_DEBUG_LOG("  fight no need reset");
			return RET_ERROR;	
		}

		/* 消耗道具 */
		if (CheckAndConsume(player, 41, pCfg->reset_consume_id, 0, 1, REASON_FIGHT_RESET) != RET_SUCCESS) {
			return RET_NOT_ENOUGH;
		}

		reset_fight(fight);
	} else {
		WRITE_DEBUG_LOG("  all params is 0");
		return RET_ERROR;
	}
	return RET_SUCCESS;	
}

static int pve_fight_drop(Player * player, int gid, int first_time, unsigned long long * heros, int nhero, struct RewardItem * items,  int nitem)
{
	unsigned long long pid = player_get_id(player);

	WRITE_DEBUG_LOG("player %llu get fight %d reward%s", pid, gid, first_time ? ", first time" : "");

	struct PVE_FightConfig * fight = get_pve_fight_config(gid);
	struct WaveConfig * wave = get_wave_config(gid);
	if (wave == 0) {
		WRITE_DEBUG_LOG("fight %d wave not exists", gid);
		return 0;
	}

	int player_level = player_get_level(player);
	struct DropInfo drops[64] = {{0,0}};
	int ndrop = 0;

#define RECORD_DROP(drop, LEV) \
	do { \
		if (drop > 0) { \
			drops[ndrop].id = (drop); \
			if (fight && (fight->reward_type & PVE_REARD_TYPE_LEVEL_BY_PLAYER)) { \
				drops[ndrop].level = player_level; \
			} else { \
				drops[ndrop].level = (LEV); \
			} \
			ndrop ++; \
		} \
	} while (0)

	RECORD_DROP(fight->drop[0], player_level);
	RECORD_DROP(fight->drop[1], player_level);
	RECORD_DROP(fight->drop[2], player_level);
	
	struct WaveConfig * waveIte = 0;
	while ((waveIte = dlist_next(wave, waveIte)) != 0) {
		for (int x = 0; x < FIGHT_DROP_COUNT; x++) {
			RECORD_DROP(waveIte->drop[x], waveIte->role_lev);
		}
	}

#undef RECORD_DROP

	return aL_send_drop_reward(player, drops, ndrop, items, nitem, heros, nhero, first_time, 1, REASON_PVE_FIGHT);
}

int aL_pve_fight_confirm(Player * player, int gid, int star, unsigned long long * heros, int nhero, struct RewardItem *items, int nitem)
{
	WRITE_DEBUG_LOG("player %llu confirm pve fight %d, star %d----------------------------------------------", player_get_id(player), gid, star);

	struct PVE_FightConfig * pCfg = get_pve_fight_config(gid);
	if (!pCfg) {
		WRITE_DEBUG_LOG(" fight config %d not exists", gid);
		return RET_ERROR;
	}

	struct Fight * fight = fight_get(player, gid);
	if (fight == NULL) {
		WRITE_DEBUG_LOG(" player fight info not exists");
		return RET_NOT_EXIST;
	}

	int first_time = (fight && fight->flag > 0) ? 0 : 1;


	if (fight && fight->today_count >= pCfg->count_per_day) {
		WRITE_DEBUG_LOG(" reach daily count %d/%d", fight->today_count, pCfg->count_per_day);
		return RET_FIGHT_CHECK_COUNT_FAIL;
	}

	int r = fight_check(player, gid, star);
	if (r != RET_SUCCESS) {
		WRITE_DEBUG_LOG(" check failed");
		return r;
	}

	if (pve_fight_consume(player, pCfg, 1) != RET_SUCCESS) {
		return RET_NOT_ENOUGH;
	}
	
	fight_update_player_data(player, fight, 1, star, fight->today_count+1);

	pve_fight_drop(player, gid, first_time, heros, nhero, items, nitem);

	aL_quest_on_event(player, QuestEventType_FIGHT, pCfg->gid, 1);
	aL_quest_on_event(player, QuestEventType_TEAM_FIGHT_ID, pCfg->gid, 1);

	if (pCfg->battle_id > 0) {
		//挑战回忆录
		aL_quest_on_event(player, 4, 20, 1);
		struct BattleConfig * bcfg  = get_battle_config(pCfg->battle_id);
		if (bcfg && bcfg->chapter_id > 0) {
			aL_quest_on_event(player, QuestEventType_CHAPTER, bcfg->chapter_id, 1);
		}
	}

	if (pCfg->battle_id) {
		aL_quest_on_event(player, QuestEventType_BATTLE, pCfg->battle_id, 1);
	}

	if (pCfg->rank == FIGHT_TYPE_FIRE && first_time) {
		struct Fire * fire = player_get_fire(player);	
		if (fire) {
			fire_set_max(player, fire->max + 1);
			fire_set_cur(player, fire->cur + 1);
		}

		property_change_max_floor(player, (pCfg->gid) % 1000);
	}

	return RET_SUCCESS;
}


int aL_change_nick_name(Player * player, const char * nick, int head, int title)
{
	unsigned long long pid = player_get_id(player);

	WRITE_INFO_LOG("player %llu change nick %s, head %d", pid, nick, head);
	char oldnick[256];
	strcpy(oldnick, player_get_name(player));
	if ( nick != 0 && nick[0] != 0 &&  strcmp(oldnick, nick) != 0 ) {
		if(player_get_id_by_name(nick)){
			WRITE_DEBUG_LOG("fail to `%s`, name exists", __FUNCTION__);
			return RET_EXIST;
		}

		struct ConsumeCfg *cfg = get_consume_config(2);
		if (cfg) {	
			if (pid > AI_MAX_ID) {
				if (CheckAndConsume(player, cfg->item_type, cfg->item_id, 0, cfg->item_value, REASON_NICK_NAME) != 0) {
					WRITE_INFO_LOG("  item %d/%d not enough, need %d", cfg->item_type, cfg->item_id, cfg->item_value);
					return RET_NOT_ENOUGH;
				}
				property_change_nick(player, nick);		
			} else {
				property_change_nick(player, nick);		
			}

			player_update_name_record(oldnick);
		}
	}

	if (head != 0) {
		property_change_head(player, head);
	}

	Property * property = player_get_property(player);
	if (property) {
		int old_title = property->title;
		if (title >= 0 && old_title != title) {
			if (!check_player_title(player, title)) {
				WRITE_DEBUG_LOG("fail to set title, no permission");
				return RET_ERROR;
			} else {
				property_set_title(player, title);
			}
		}
	}
		
    if (pid > AI_MAX_ID) {
		time_t now = agT_current();
		agL_write_user_logger(PLAYER_CHANGE_NAME_LOGGER, LOG_FLAT, "%d,%lld,%s,%s", (int)now, pid, oldnick, nick);
	}

	return RET_SUCCESS;
}


int aL_tick(Player * player)
{
	struct ItemConfig * ite = get_grow_item_config();
	for (; ite; ite=ite->grow_next) {
		item_get(player, ite->id); // item auto grow
	}
	return 0;
}

static void aL_send_reward_by_drop_config(Player * player, struct DropConfig * dropConfig, struct RewardItem * items, int nitem, unsigned long long * heros, int nhero, uint32_t send_reward, uint32_t first_time, int level, unsigned int reason)
{
	time_t now = agT_current();
	Reward *  reward = send_reward ? reward_create(reason, 0, 0, 0) : 0;
	struct {
		int id;
		int value;
	} hero_item[64] = { {0,0} }; 

	#define WRITE_DROP_LOG(...)   //WRITE_DEBUG_LOG(__VA_ARGS__)
	uint32_t reward_flag = 0;
	int group_value[32] = {0};

	struct DropConfig * ite = 0;
	while((ite = dlist_next(dropConfig, ite)) != 0) {
		//WRITE_DROP_LOG("check %d, %d, group %d", ite->type, ite->id, ite->group);
		if (ite->first_drop && !first_time) {
			WRITE_DROP_LOG("-- not first time");
			continue;		
		}

		if (reward_flag & (1 << ite->group)) {
			WRITE_DROP_LOG("----- pass by group");
			continue;
		}

		if (ite->group < 0 || ite->group >= 32) {
			continue;
		}

		int act_drop_rate = 0;
		float act_value_rate = 1;

		if (now >= ite->act_time && now <= ite->end_time) {
			act_drop_rate = ite->act_drop_rate;
			act_value_rate = ite->act_value_rate / 10000.0;
		}
		int drop_rate = ite->drop_rate + act_drop_rate;

		if (group_value[ite->group] == 0) {
			group_value[ite->group] = rand() % 10000 + 1;
			WRITE_DROP_LOG("-- pass group %d value %d", group_value[ite->group]);
		}

		if (drop_rate == 0) {
			WRITE_DROP_LOG("-- pass rate == 0");
			continue;
		} else if (drop_rate < 10000 && group_value[ite->group] > drop_rate) {
			group_value[ite->group] -= drop_rate;
			continue;
		}

		reward_flag |= (1 << ite->group);

		int min = (ite->min_value + ite->min_incr * level) * act_value_rate;
		int max = (ite->max_value + ite->max_incr * level) * act_value_rate;

		int value = RAND_RANGE(min, max);

		WRITE_DROP_LOG("+ %d", value);
#undef WRITE_DROP_LOG

		if (send_reward) {
			if (ite->type == 90 && ite->id != 90000) {
				if (ite->id == 0 || ite->id == 90001) {
					hero_item[0].value += value;
				} else {
					int y;
					for (y = 1; y < 64; y++) {
						if (hero_item[y].id == 0 || hero_item[y].id == ite->id) {
							hero_item[y].id = ite->id;
							hero_item[y].value += value;
							break;
						}
					}
				}
				append_rewards_(items, nitem, ite->type, ite->id, value);
			} else {
				reward_add_content(reward, 0, ite->type, ite->id, value);
			}
		}
	}

	if (send_reward) {
		// WRITE_DEBUG_LOG("  reward_commit");
		reward_commit(reward, player_get_id(player), items, nitem);

		int i,j;
		for (j = 0; j < 64; j++) {
			if (j == 0 && hero_item[j].value == 0) {
				continue;
			} else if (j != 0 && hero_item[j].value == 0) {
				break;
			}

			for (i = 0; i < nhero; i++) {
				if (heros[i] == 0) {
					continue;
				}

				Hero * hero = hero_get(player, 0, heros[i]);
				if (hero) {
					if (j == 0) {
						hero_add_normal_exp(hero, hero_item[j].value);
					} else if (hero_item[j].id != 90000 && hero_item[j].id != 90001) {
						hero_item_add(player, heros[i], hero_item[j].id, hero_item[j].value, REASON_PVE_FIGHT, 0);
					}
				}
			}

		}

	}
}

int aL_send_drop_reward(Player * player, struct DropInfo * drops, int ndrop, struct RewardItem * items,  int nitem, unsigned long long * heros, int nhero, uint32_t first_time, uint32_t send_reward, unsigned int reason) {
	unsigned long long pid = send_reward ? player_get_id(player) : 0;

	WRITE_DEBUG_LOG("player %llu send drop reward, send_reward:%d", pid, send_reward);

	time_t now = agT_current();

	int player_level = send_reward ? player_get_level(player) : 0;

	Reward *  reward = send_reward ? reward_create(reason, 0, 0, 0) : 0;

#define WRITE_DROP_LOG(...)   WRITE_DEBUG_LOG(__VA_ARGS__)

	struct {
		int id;
		int value;
	} hero_item[64] = { {0,0} }; 
	hero_item[0].id = 90000;
	hero_item[1].id = 90001;

	for (int x = 0; x < ndrop; x++) {
		int drop_id = drops[x].id;
		int level = drops[x].level;
		if (drops[x].level == 0 && send_reward) {
			level = player_level;
		}

		if (player_level == 0 && drops[x].level > 0) {
			player_level = drops[x].level;
		}

		WRITE_DROP_LOG("  send drop reward for drop_id:%d, level %d", drop_id, level);
		if (drop_id == 0) {
			WRITE_DROP_LOG("drop %d is 0", x + 1);
			continue;
		}

		struct DropConfig * dropConfig = 0; 

		struct DropWithItemConfig * di = get_drop_with_item_config(drop_id, -1);
		if (di == 0 || pid == 0 || send_reward == 0) {
			dropConfig = get_drop_config(drop_id);
		} else {
			//TODO
			int i = 0;
			for (i = 0; i < MAX_DROP_WITH_ITEM_GROUP; i++) {
				di = get_drop_with_item_config(drop_id, i);
				WRITE_DROP_LOG("drop %d   group %d", drop_id, i);
				if (!di) {
					continue;
				}

				struct DropWithItemConfig * dws[256] = {0};
				int n_drop_count  = 0;
				int drop_weight   = 0;
				int drop_priority = -1;

				for (; di; di = di->next) {
					if (drop_priority != -1 && di->priority > drop_priority) {
						break;
					}

					int drop_can_use = 1;
					if (di->item_id > 0) {
						struct Item * item = item_get(player, di->item_id);
						if (item == 0 || ((int)item->limit) < di->item_count) {
							drop_can_use = 0;
						}
					}

					if (drop_can_use) {
						drop_priority = di->priority;
						drop_weight   = di->weight;
						dws[n_drop_count++] = di;
					}

					if (n_drop_count >= 256) {
						break;
					}
				}

				if (n_drop_count <= 0) {
					WRITE_DEBUG_LOG(" drop consume item not exists");
					continue;
				} else if (n_drop_count == 1) {
					di = dws[0];
				} else {
					drop_weight = (drop_weight > 0) ? drop_weight : 1;

					int choose = rand() % drop_weight + 1;
					int i;
					di = 0;
					for (i = 0; i < n_drop_count; i++) { 
						choose = choose - dws[i]->weight;

						if (choose <= 0) {
							di = dws[i];
							break;
						}
					}
				}

				if (di && di->item_id > 0) {
					struct Item * item = item_get(player, di->item_id);
					if (item_remove(item, di->item_count, REASON_DROP_ITEM_CONSUME) != 0) {
						WRITE_DEBUG_LOG(" drop consume item failed");
						continue;
					}
				}

				dropConfig = di ? di->drop : 0;

				//WRITE_DROP_LOG(" change drop to %d by item %d", dropConfig ? dropConfig->drop_id : 0, di->item_id);

				aL_send_reward_by_drop_config(player, dropConfig, items, nitem, heros, nhero, send_reward, first_time, level, reason);
			}
			return 0;
		}

		if (dropConfig == 0) {
			WRITE_DEBUG_LOG("fight reward for drop %d not exists", drop_id);
			continue;
		}

		uint32_t reward_flag = 0;
		int group_value[32] = {0};

		struct DropConfig * ite = 0;
		while((ite = dlist_next(dropConfig, ite)) != 0) {
			WRITE_DROP_LOG("check %d, %d, group %d", ite->type, ite->id, ite->group);
			if (ite->first_drop && !first_time) {
				WRITE_DROP_LOG("-- not first time");
				continue;		
			}

			if (player_level < ite->level_limit_min || player_level > ite->level_limit_max) {
				WRITE_DROP_LOG("-- level_limit %d (%d->%d)", player_level, ite->level_limit_min, ite->level_limit_max);
				continue;
			}

			if (reward_flag & (1 << ite->group)) {
				WRITE_DROP_LOG("----- pass by group");
				continue;
			}

			if (ite->group < 0 || ite->group >= 32) {
				continue;
			}

			int act_drop_rate = 0;
			float act_value_rate = 1;

			if (now >= ite->act_time && now <= ite->end_time) {
				act_drop_rate = ite->act_drop_rate;
				act_value_rate = ite->act_value_rate / 10000.0;
			}
			int drop_rate = ite->drop_rate + act_drop_rate;

			if (group_value[ite->group] == 0) {
				group_value[ite->group] = rand() % 10000 + 1;
				WRITE_DROP_LOG("-- pass group %d value %d", ite->group, group_value[ite->group]);
			}

			if (drop_rate == 0) {
				WRITE_DROP_LOG("-- pass rate == 0");
				continue;
			} else if (drop_rate < 10000 && group_value[ite->group] > drop_rate) {
				group_value[ite->group] -= drop_rate;
				continue;
			}

			reward_flag |= (1 << ite->group);
			

			int min = (ite->min_value + ite->min_incr * level) * act_value_rate;
			int max = (ite->max_value + ite->max_incr * level) * act_value_rate;

			int value = RAND_RANGE(min, max);

			WRITE_DROP_LOG("+ %d", value);
#undef WRITE_DROP_LOG

			if (send_reward && value > 0) {
				if (ite->type == 90) {
					int y;
					for (y = 0; y < 64; y++) {
						if (hero_item[y].id == 0 || hero_item[y].id == ite->id) {
							hero_item[y].id = ite->id;
							hero_item[y].value += value;
							break;
						}
					}
					append_rewards_(items, nitem, ite->type, ite->id, value);
				} else {
					reward_add_content(reward, 0, ite->type, ite->id, value);
				}
			}
		}
	}

	if (send_reward) {
		// WRITE_DEBUG_LOG("  reward_commit");
		reward_commit(reward, player_get_id(player), items, nitem);

		int i,j;
		for (j = 0; j < 64; j++) {
			if (hero_item[j].id == 0) {
				break;
			}

			if (hero_item[j].value == 0) {
				continue;
			}

			for (i = 0; i < nhero; i++) {
				if (heros[i] == 0) {
					continue;
				}

				Hero * hero = hero_get(player, 0, heros[i]);
				if (hero) {
					if (hero_item[j].id == 90000) {
						if (hero->gid == LEADING_ROLE) { // 主角经验
							hero_add_normal_exp(hero, hero_item[j].value);
						}
	
					} else if (hero_item[j].id == 90001) {
						if (hero->gid != LEADING_ROLE) { // 伙伴经验, 不包括主角
							hero_add_normal_exp(hero, hero_item[j].value);
						}
					} else {
						hero_item_add(player, heros[i], hero_item[j].id, hero_item[j].value, REASON_PVE_FIGHT, 0);
					}
				}
			}

		}

	}

	return 0;
}

/*#define GET_DAY_BEGIN_TIME(x) \
    x - (x + 8 * 3600) % 86400*/
static int is_quest_in_time(struct QuestConfig * cfg, Player * player)
{
	time_t now = agT_current();

	time_t begin_time = cfg->time.begin;
	time_t end_time = cfg->time.end;

	if (cfg->relative_to_born) {
		struct Property * property = player_get_property(player);
		if (!property) {
			return 0;
		}
		time_t born_time = GET_DAY_BEGIN_TIME(property->create);
		begin_time = born_time + (cfg->time.begin - 1) * 86400;
	    end_time   = born_time + (cfg->time.end - 1) * 86400 - 1;
	}
		
	if (begin_time && now < begin_time) {
		return 0;
	}

	if (end_time && now > end_time) {
		return 0;
	}


	/*
	   if (cfg->time.period == 0) {
	   return 1;
	   }
	   */

	time_t period = cfg->time.period ? cfg->time.period : 0xffffffff;
	time_t duration = cfg->time.duration ? cfg->time.duration : period;

	time_t total_pass = now - begin_time;
	time_t period_pass = total_pass % period;

	if (period_pass > duration) {
		return 0;
	}

	return 1;
}

static int is_quest_in_time_to_submit(struct QuestConfig * cfg, Player * player, int * manual)
{
	time_t now = agT_current();

	time_t begin_time = cfg->time.begin;
	time_t end_time = cfg->time.end;

	if (cfg->relative_to_born) {
		struct Property * property = player_get_property(player);
		if (!property) {
			return 0;
		}
		time_t born_time = GET_DAY_BEGIN_TIME(property->create);
		begin_time = born_time + (cfg->time.begin - 1) * 86400;
	    end_time   = born_time + (cfg->time.end - 1) * 86400 - 1;
	}

	time_t delay_time = 0;
	struct QuestDelayConfig * dcfg = get_quest_delay(cfg->id);
	if (dcfg) delay_time += dcfg->delay;
		
	if (begin_time && now < begin_time) {
		return 0;
	}

	if (end_time && now > end_time + delay_time) {
		return 0;
	}

	time_t period = cfg->time.period ? cfg->time.period : 0xffffffff;
	time_t duration = cfg->time.duration ? cfg->time.duration : period;

	time_t total_pass = now - begin_time;
	time_t period_pass = total_pass % period;

	if (period_pass > duration + delay_time) {
		return 0;
	}

	if ((now > end_time && now <= end_time + delay_time) || (period_pass > duration && period <= duration + delay_time)) *manual = 1;

	return 1;
}


int aL_update_quest_status(struct Quest * quest, struct QuestConfig * cfg)
{
	if (quest->status == QUEST_STATUS_CANCEL) {
		return 0;
	}

	cfg = cfg ? cfg : get_quest_config(quest->id);
	if (!cfg) {
		return -1;
	}

	time_t now = agT_current();

	if (cfg->time.period == 0) {
		if (cfg->time_limit > 0 && quest->accept_time + cfg->time_limit < now) {
			WRITE_DEBUG_LOG("  quest %d status reset to cancel by time limit", quest->id);
			quest_update_status(quest, QUEST_STATUS_CANCEL, -1, -1, 0, -1, -1, 0, 0);
		}

		return 0;
	}

	struct Player * player = player_get(quest->pid);

	time_t begin_time = cfg->time.begin;
	//time_t end_time = cfg->time.end;
	if (cfg->relative_to_born) {
		if (!player) {
			return 1;
		}
		struct Property * property = player_get_property(player);
		if (!property) {
			return -1;
		}
		time_t born_time = GET_DAY_BEGIN_TIME(property->create);
		begin_time = born_time + (cfg->time.begin - 1) * 86400;
	    //end_time   = born_time + (cfg->time.end - 1) * 86400 - 1;
	}

	time_t period = cfg->time.period ? cfg->time.period : 0xffffffff;

	time_t total_pass = now - begin_time;
	time_t period_pass = total_pass % period;

	time_t period_begin = now - period_pass;

	if (quest->accept_time < period_begin) {
		WRITE_DEBUG_LOG("  quest %d status reset to cancel by period", quest->id);
		quest_update_status(quest, QUEST_STATUS_CANCEL, -1, -1, 0, -1, -1, 0, 0);

		if ((cfg->auto_accept & 0x01) && player) {
			WRITE_DEBUG_LOG("  try auto accept");
			aL_quest_accept(player, cfg->id, 1);
		}
	}

	if (cfg->time_limit > 0 && quest->accept_time + cfg->time_limit < now) {
        WRITE_DEBUG_LOG("  quest %d status reset to cancel by time limit", quest->id);
        quest_update_status(quest, QUEST_STATUS_CANCEL, -1, -1, 0, -1, -1, 0, 0);
    }

	return 0;
}

int aL_quest_accept(Player * player, int id, int from_client)
{
	int i;

	WRITE_INFO_LOG("player %llu accept quest %d, from %s", player_get_id(player), id, from_client ? "client" : "server");

	struct QuestConfig * cfg = get_quest_config(id);
	if (cfg == 0) {
		WRITE_DEBUG_LOG("  quest config not exists");
		return RET_ERROR;
	}

	if (cfg->only_accept_by_other_activity && from_client) {
		WRITE_DEBUG_LOG("  quest can't change by client");
		return RET_ERROR;
	}

	if (!is_quest_in_time(cfg, player)) {
		WRITE_DEBUG_LOG("begin time %zu  end time  %zu",   cfg->time.begin,  cfg->time.end)
			WRITE_DEBUG_LOG(" quest not in time");
		return RET_ERROR;
	}

	int level = player_get_level(player);
	if (level < cfg->depend.level) {
		WRITE_DEBUG_LOG("  level %d/%d is not enough", level, cfg->depend.level);
		return RET_ERROR;
	}

	if (cfg->depend.fight != 0) {
		struct Fight * fight = fight_get(player, cfg->depend.fight);
		if (fight == 0 || fight->flag == 0) {
			WRITE_DEBUG_LOG("  fight %d is not pass", cfg->depend.fight);
			return RET_ERROR;
		}
	}

	if (cfg->depend.quest != 0) {
		struct Quest * depend_quest = quest_get(player, cfg->depend.quest);
		if (depend_quest) {
			aL_update_quest_status(depend_quest, 0);
		}

		if (depend_quest == 0 || depend_quest->count == 0) {
			WRITE_DEBUG_LOG("  quest %d not finished", cfg->depend.quest);
			return RET_ERROR;
		}
	}

	if (cfg->depend.item != 0) {
		struct Item * item = item_get(player, cfg->depend.item);
		if (item == 0 || item->limit == 0) {
			WRITE_DEBUG_LOG("  item %d not exists", cfg->depend.item);
			return RET_ERROR;
		}
	}

	for (i = 0; i < QUEST_CONSUME_COUNT; i++) {
		if ( cfg->consume[i].type != 0 && (cfg->consume[i].need_reset & QUEST_CONSUME_ITEM_FLAG_CONSUME_ON_ACCEPT)) {
			if (CheckForConsume(player,  cfg->consume[i].type, cfg->consume[i].id, 0, cfg->consume[i].value) != RET_SUCCESS) {
				return RET_NOT_ENOUGH;
			}
		} else if (cfg->consume[i].type != 0 && (cfg->consume[i].need_reset & QUEST_CONSUME_ITEM_FLAG_CHECK_ON_ACCEPT)) {
			if (CheckForConsume(player,  cfg->consume[i].type, cfg->consume[i].id, 0, cfg->consume[i].value) != RET_SUCCESS) {
				return RET_NOT_ENOUGH;
			}
		}
	}


	if (cfg->group > 0) {
		struct QuestConfig * ite = get_quest_list_of_group(cfg->group);
		for(;ite; ite = ite->group_next) {
			if (ite->id == cfg->id) {
				continue;
			}

			struct Quest * _quest = quest_get(player, ite->id);
			if (_quest == NULL) {
				continue;
			}

			aL_update_quest_status(_quest, ite);
			if (_quest->status == QUEST_STATUS_INIT) {
				WRITE_DEBUG_LOG(" quest in group %d already exists, current quest id %d", ite->group, ite->id);	
				return RET_INPROGRESS;
			}
		}
	}

	struct Quest * quest = quest_get(player, id);
	if (quest) {
		aL_update_quest_status(quest, cfg);

		if (quest->status == QUEST_STATUS_INIT) {
			WRITE_DEBUG_LOG(" quest already exists");	
			return RET_SUCCESS;
		} else if (cfg->count_limit > 0 && (int)quest->count >= cfg->count_limit) {
			WRITE_DEBUG_LOG(" quest reach period count limit %d/%d", quest->count, cfg->count_limit);	
			return RET_FULL;
		}

		quest_update_status(quest, QUEST_STATUS_INIT, 0, 0, -1, 0, 0, agT_current(), 0);
	} else {
		quest = quest_add(player, id, QUEST_STATUS_INIT, agT_current());
	}


	for (i = 0; i < QUEST_CONSUME_COUNT; i++) {
		if ( cfg->consume[i].type != 0 ) {
			if (cfg->consume[i].need_reset & QUEST_CONSUME_ITEM_FLAG_CLEAN_ON_ACCEPT) {
				TryConsumeAll(player, cfg->consume[i].type, cfg->consume[i].id, 0, REASON_QUEST);
			} else if (cfg->consume[i].need_reset & QUEST_CONSUME_ITEM_FLAG_CONSUME_ON_ACCEPT) {
				CheckAndConsume(player,  cfg->consume[i].type, cfg->consume[i].id, 0, cfg->consume[i].value, REASON_QUEST);
			}
		}
	}

    unsigned long long pid = player_get_id(player);
    if (pid > AI_MAX_ID) {
		agL_write_user_logger(QUEST_LOGGER, LOG_FLAT, "%d,%lld,%d,1", (int)agT_current(), pid, id);
	}


	return RET_SUCCESS;
}

int aL_quest_cancel(Player * player, int id, int from_client)
{
	WRITE_INFO_LOG("player %llu cancel quest %d, from %s", player_get_id(player), id, from_client ? "client" : "server");

	struct QuestConfig * cfg = get_quest_config(id);
	if (cfg == 0) {
		WRITE_DEBUG_LOG("  quest config not exists");
		return RET_ERROR;
	}

	if (cfg->only_accept_by_other_activity && from_client) {
		WRITE_DEBUG_LOG("  quest can't change by client");
		return RET_ERROR;
	}

	if (!is_quest_in_time(cfg, player)) {
		WRITE_DEBUG_LOG(" quest not in time");
		return RET_ERROR;
	}

	struct Quest * quest = quest_get(player, id);
	if (quest == 0) {
		WRITE_DEBUG_LOG(" quest not exists");
		return RET_NOT_EXIST;
	}

	aL_update_quest_status(quest, cfg);

	if (quest->status != QUEST_STATUS_INIT) {
		WRITE_DEBUG_LOG(" quest status %d can't cancel", quest->status);
		return RET_ERROR;
	}

	quest_update_status(quest, QUEST_STATUS_CANCEL, -1, -1, -1, -1, -1, 0, 0);

	int i;
	for (i = 0; i < QUEST_CONSUME_COUNT; i++) {
		if ( cfg->consume[i].type != 0 ) {
			if (cfg->consume[i].need_reset & QUEST_CONSUME_ITEM_FLAG_CLEAN_ON_CANCEL) {
				TryConsumeAll(player, cfg->consume[i].type, cfg->consume[i].id, 0, REASON_QUEST);
			}
		}
	}

    unsigned long long pid = player_get_id(player);
    if (pid > AI_MAX_ID) {
		agL_write_user_logger(QUEST_LOGGER, LOG_FLAT, "%d,%lld,%d,3", (int)agT_current(), pid,id);
	}

	return RET_SUCCESS;
}

static void get_quest_period_time(Player * player, struct QuestConfig * cfg, time_t * begin, time_t * end)
{
	time_t now = agT_current();
	time_t begin_time = cfg->time.begin;
	time_t end_time = cfg->time.end;

	if (cfg->relative_to_born) {
		struct Property * property = player_get_property(player);
		if (!property) {
			return;
		}
		time_t born_time = GET_DAY_BEGIN_TIME(property->create);
		begin_time = born_time + (cfg->time.begin - 1) * 86400;
	    end_time   = born_time + (cfg->time.end - 1) * 86400 - 1;
	}

	time_t period = cfg->time.period ? cfg->time.period : 0xffffffff;
	time_t duration = cfg->time.duration ? cfg->time.duration : period;

	time_t total_pass = now - begin_time;
	time_t period_pass = total_pass % period;

	time_t period_begin = now - period_pass;
	time_t period_end = now - period_pass + duration;
	period_end = (period_end > end_time) ? end_time : period_end; 

	*begin = period_begin;
	*end = period_end;
}

struct SuitCount {
	int suit;
	int count;
	int types[6];
};

//获取玩家护符套装数量  num：几件套  
static int get_suit_equip_count(Player * player, int num)
{
	struct Hero * hero = NULL;
	int suit_count = 0;
	while((hero = hero_next(player, hero)) != 0)
	{
		int i = 0;
		int j = 0;
		int k = 0;
		struct SuitCount suits[6];
		memset(suits, 0, sizeof(suits));
		for (i = 7; i <= EQUIP_INTO_BATTLE_MAX; i++) {
			struct Equip * equip = equip_get_by_hero(player, hero->uuid, i);
			if (!equip) continue;

			struct EquipConfig * cfg = get_equip_config(equip->gid);
			if (!cfg) continue;

			for (j = 0; j < 6; j++) {
				struct SuitCount sc = suits[j];
				if (sc.suit == 0) {
					suits[j].suit = cfg->suit;		
					for (k = 0; k < 6; k++) {
						int type = sc.types[k];
						if (type == 0) {
							sc.types[k] = type;
							suits[j].count += 1;		
							break;
						}

						if (type == cfg->type) {
							break;
						} 
					}

					break;
				}

				if (sc.suit == cfg->suit) {
					for (k = 0; k < 6; k++) {
						int type = sc.types[k];
						if (type == 0) {
							sc.types[k] = type;
							suits[j].count += 1;		
							break;
						}

						if (type == cfg->type) {
							break;
						} 
					}

					break;	
				} 
			}
		}

		for (i = 0; i < 6; i++) {
			struct SuitCount sc = suits[i];
			WRITE_DEBUG_LOG("suit %d count %d", sc.suit, sc.count);
			if (sc.count != 0 && sc.count >= num) {
				suit_count += 1;
			}
		}
	}

	return suit_count;
}

int get_total_talent_count(Player * player, int type, unsigned long long id)
{
	int refid = 0;
	int real_type = 0;
	unsigned long long uuid = 0;
	const char * data = aL_talent_get_data(player, type, id, refid, &uuid, &real_type);
	if (!data) {
		return 0;
	}
	
	int total_talent_value = 0;
	for (int i = 0; i < TALENT_MAXIMUM_DATA_SIZE; i++) { 
		total_talent_value  += TALENT_VALUE(data, i+1);
	}

	return total_talent_value;
}

static int check_quest_event(Player * player, int record, int type, int id, int count, time_t accept_time, unsigned int * new_record, struct QuestConfig * cfg) 
{
	//特殊type 忽略record的大小
	if (type == QuestEventType_PLAYER) {
		if (id == 1) {
			if (player_get_level(player) < count) {
				WRITE_DEBUG_LOG("  player level not enough");
				return 0;
			}
			return 1;
		} 
	} 

	time_t now = agT_current();
	time_t begin_time = cfg->time.begin;
	time_t end_time = cfg->time.end;

	if (cfg->relative_to_born) {
		struct Property * property = player_get_property(player);
		if (!property) {
			return 0;
		}
		time_t born_time = GET_DAY_BEGIN_TIME(property->create);
		begin_time = born_time + (cfg->time.begin - 1) * 86400;
	    end_time   = born_time + (cfg->time.end - 1) * 86400 - 1;
	}

	time_t period = cfg->time.period ? cfg->time.period : 0xffffffff;
	time_t duration = cfg->time.duration ? cfg->time.duration : period;

	time_t total_pass = now - begin_time;
	time_t period_pass = total_pass % period;

	time_t period_end = now - period_pass + duration;
	period_end = (period_end > end_time) ? end_time : period_end; 

	if (type == QuestEventType_HERO) {
		if (id == 1) {
			int hero_count = 0;	
			struct Hero * it = NULL;
			while((it = hero_next(player, it)) != 0)
			{
				if (it->add_time < period_end) {
					hero_count += 1;
				}
			}
			if (hero_count < count) {
				WRITE_DEBUG_LOG("  player hero not enough");
				return 0;
			}
			return 1;
		}	
	}

	if (type == QuestEventType_HERO_LEVEL) {
		int hero_count = 0;	
		struct Hero * it = NULL;
		while((it = hero_next(player, it)) != 0)
		{
			if (it->add_time < period_end && it->level >= (unsigned int)id) {
				hero_count += 1;
			}
		}
		if (hero_count < count) {
			WRITE_DEBUG_LOG("  player hero for level %d not enough", id);
			return 0;
		}
		return 1;
	}
	
	if (type == QuestEventType_EQUIP) {
		// 护符
		if (id == 1) {
			int hufu_count = 0;
			struct Equip * iter = NULL;
			while ((iter = equip_next(player, iter)) != 0) {
				struct EquipConfig * cfg = get_equip_config(iter->gid);
				if (cfg && IS_EQUIP_TYPE_1(cfg->type) && (iter->add_time < period_end)) {
					hufu_count += 1;	
				}
			}
			if (hufu_count < count) {
				WRITE_DEBUG_LOG("hufu  not enough");
				return 0;
			}
			return 1;
		}
		// 铭文
		if (id == 2) {
			int mingwen_count = 0;
			struct Equip * iter = NULL;
			while ((iter = equip_next(player, iter)) != 0) {
				struct EquipConfig * cfg = get_equip_config(iter->gid);
				if (cfg && IS_EQUIP_TYPE_2(cfg->type) && (iter->add_time < period_end)) {
					mingwen_count += 1;	
				}
			}
			if (mingwen_count < count) {
				WRITE_DEBUG_LOG("mingwen  not enough   %d < %d", mingwen_count, count);
				return 0;
			}
			return 1;
		}
	}

	if (type == QuestEventType_HUFU_QUALITY) {
		// 护符
		if (id == 1) {
			int hufu_count = 0;
			struct Equip * iter = NULL;
			while ((iter = equip_next(player, iter)) != 0) {
				struct EquipConfig * cfg = get_equip_config(iter->gid);
				if (cfg && IS_EQUIP_TYPE_1(cfg->type) && (iter->add_time < period_end) && (cfg->quality == id)) {
					hufu_count += 1;	
				}
			}
			if (hufu_count < count) {
				WRITE_DEBUG_LOG("hufu for quality %d not enough %d < %d", id, hufu_count, count);
				return 0;
			}
			return 1;
		}
	}

	if (type == QuestEventType_MINGWEN_QUALITY) {
		// 铭文
		if (id == 2) {
			int mingwen_count = 0;
			struct Equip * iter = NULL;
			while ((iter = equip_next(player, iter)) != 0) {
				struct EquipConfig * cfg = get_equip_config(iter->gid);
				if (cfg && IS_EQUIP_TYPE_2(cfg->type) && (iter->add_time < period_end) && (cfg->quality == id)) {
					mingwen_count += 1;	
				}
			}
			if (mingwen_count < count) {
				WRITE_DEBUG_LOG("mingwen for quality %d not enough   %d < %d", id, mingwen_count, count);
				return 0;
			}
			return 1;
		}
	}

	if (type == QuestEventType_ONLINE_TIME) {
		Property * property = player_get_property(player);
		time_t online_time = 0;
		if (property->login < accept_time) {
			online_time = record + agT_current() - accept_time;
		} else {
			online_time = record + agT_current() - property->login;
		}
		
		if (online_time < count) {
			return 0;
		} else {
			*new_record = count;
			return 1;
		}
	}

	if (type == QuestEventType_LEADING_ROLE_WEAR_HUFU) {
		int cnt = 0;
		struct Hero * hero = hero_get(player, LEADING_ROLE, 0);
		if (!hero) return 0;

		int i = 0;
		for (i = 1; i <= EQUIP_INTO_BATTLE_MAX; i++) {
			struct Equip * equip = equip_get_by_hero(player, hero->uuid, i);
			if (!equip) continue;

			struct EquipConfig * cfg = get_equip_config(equip->gid);
			if (!cfg) return 0;

			if (IS_EQUIP_TYPE_1(cfg->type) && (equip->add_time < period_end) && (cfg->quality >= id)) {
				cnt += 1;	
			}

		}

		if (cnt < count) {
			WRITE_DEBUG_LOG("hufu for quality %d equiped on leading role is not enough   %d < %d", id, cnt, count);
			return 0;
		}
		return 1;
	}

	if (type == QuestEventType_LEADING_ROLE_WEAR_MINGWEN) {
		int cnt = 0;
		struct Hero * hero = hero_get(player, LEADING_ROLE, 0);
		if (!hero) return 0;

		int i = 0;
		for (i = 1; i <= EQUIP_INTO_BATTLE_MAX; i++) {
			struct Equip * equip = equip_get_by_hero(player, hero->uuid, i);
			if (!equip) continue;

			struct EquipConfig * cfg = get_equip_config(equip->gid);
			if (!cfg) return 0;

			if (IS_EQUIP_TYPE_2(cfg->type) && (equip->add_time < period_end) && (cfg->quality >= id)) {
				cnt += 1;	
			}

		}

		if (cnt < count) {
			WRITE_DEBUG_LOG("mingwen for quality %d equiped on leading role is not enough   %d < %d", id, cnt, count);
			return 0;
		}
		return 1;
	}

	if (type == QuestEventType_HERO_WEAR_SUIT_HUFU) {
		struct Hero * hero = hero_get(player, id, 0);
		if (!hero) return 0;

		int i = 0;
		int j = 0;
		int k = 0;
		struct SuitCount suits[6];
		memset(suits, 0, sizeof(suits));
		for (i = 7; i <= EQUIP_INTO_BATTLE_MAX; i++) {
			struct Equip * equip = equip_get_by_hero(player, hero->uuid, i);
			if (!equip) continue;

			struct EquipConfig * cfg = get_equip_config(equip->gid);
			if (!cfg) return 0;

			for (j = 0; j < 6; j++) {
				struct SuitCount sc = suits[j];
				if (sc.suit == 0) {
					suits[j].suit = cfg->suit;		
					for (k = 0; k < 6; k++) {
						int type = sc.types[k];
						if (type == 0) {
							sc.types[k] = type;
							suits[j].count += 1;		
							break;
						}

						if (type == cfg->type) {
							break;
						} 
					}

					break;
				}

				if (sc.suit == cfg->suit) {
					for (k = 0; k < 6; k++) {
						int type = sc.types[k];
						if (type == 0) {
							sc.types[k] = type;
							suits[j].count += 1;		
							break;
						}

						if (type == cfg->type) {
							break;
						} 
					}

					break;	
				} 
			}
		}

		for (i = 0; i < 6; i++) {
			struct SuitCount sc = suits[i];
			WRITE_DEBUG_LOG("suit %d count %d", sc.suit, sc.count);
			if (sc.count != 0 && sc.count >= count) {
				return 1;
			}
		}

		return 0;
	}

	if (type == QuestEventType_ITEM_VALUE) {
		Item * item = item_get(player, id);
		if (item && item->limit >= (unsigned int)count) {
			return 1;
		}	

		WRITE_DEBUG_LOG("item count not enough for quest %d < %d", item ? item->limit : 0, count);
		return 0;
	}

	if (type == QuestEventType_HERO_STAGE) {
		struct Hero * pHero = hero_get(player, id, 0);
		if (pHero && pHero->stage >= count) {
			return 1;
		}

		WRITE_DEBUG_LOG("hero quality not enough for quest %d < %d", pHero->stage, count);
		return 0;
	}

	if (type == QuestEventType_WEAPON_STAR) {
		struct Hero * pHero = hero_get(player, id, 0);
		if (pHero && pHero->weapon_star >= count) {
			return 1;
		}

		WRITE_DEBUG_LOG("weapon star not enough for quest %d < %d", pHero->weapon_star, count);
		return 0;
	}

	if (type == QuestEventType_WEAPON_TALENT) {
		struct Hero * it = NULL;
		int hero_count = 0;
		while((it = hero_next(player, it)) != 0)
		{
			int refid = 0;
			int real_type = 0;
			unsigned long long uuid = 0;
			const char * data = aL_talent_get_data(player, TalentType_Weapon, it->uuid, refid, &uuid, &real_type);
			if (!data) {
				continue;
			}
			
			//WRITE_DEBUG_LOG("talent for hero %llu data %s", uuid, data);
			int total_talent_value = 0;
			for (int i = 0; i < TALENT_MAXIMUM_DATA_SIZE; i++) { 
				total_talent_value  += TALENT_VALUE(data, i+1);
				//WRITE_DEBUG_LOG("talent value idx %d,  value %d, total %d,  condition %d", i + 1, TALENT_VALUE(data, i+1), total_talent_value, id);
				if (total_talent_value >= id) {
					hero_count += 1;
					break;
				} 
			}

			if (hero_count >= count) return 1;
		}

		WRITE_DEBUG_LOG("hero skill point not enough %d/%d", hero_count, count);
		return 0;
	}

	if (type == QuestEventType_HUFU_STAGE) {
		struct Equip * iter = NULL;
		int hufu_count = 0;
		while ((iter = equip_next(player, iter)) != 0) {
			struct EquipConfig * cfg = get_equip_config(iter->gid);
			if (cfg && IS_EQUIP_TYPE_1(cfg->type) && (iter->add_time < period_end) && (cfg->stage >= id)) {
				hufu_count += 1;	
			}
		}

		if (hufu_count < count) {
			WRITE_DEBUG_LOG("hufu for stage %d not enough", id);
			return 0;
		}

		return 1;
	}

	if (type == QuestEventType_HUFU_SUIT) {
		int suit_count = get_suit_equip_count(player, id);
		if (suit_count < count) {
			WRITE_DEBUG_LOG("hufu suit %d not enough %d/%d", id, suit_count, count);
			return 0;
		} 
	
		return 1;
	}

	if (type == QuestEventType_HERO_CAPACITY) {
		struct CheckData * check_data = player_get_check_data(player);
		int hero_count = 0;
		if (check_data && check_data->capacity_list) {
			struct HeroCapacity * node = NULL;
			while((node = dlist_next(check_data->capacity_list, node)) != 0) {
				if (node->capacity >= id) {
					hero_count += 1;
				}
			}
		}

		if (hero_count < count) {
			WRITE_DEBUG_LOG("hero capacity not enough %d/%d", hero_count, count);
			return 0;
		}

		return 1;
	}

	if (type == QuestEventType_ITEM_SUBTYPE) {
	    long cnt = get_item_count_by_sub_type(player, id);
    	if (cnt < count) {
		    WRITE_DEBUG_LOG("item not enough for sub_type %d %ld/%d", id, cnt, count);
		    return 0;
		}

		return 1;
   	}

	if (type == QuestEventType_FIGHT_STAR) {
		struct Fight * fight = fight_get(player, id);
		if (!fight) {
			WRITE_DEBUG_LOG("cant get fight for gid %d", id);
			return 0;
		}
		int star = calc_star_count(fight->star);
		if (star < count) {
			WRITE_DEBUG_LOG("fight star not enough %d/%d", star, count);
			return 0;	
		}

		return 1;
	}

	if (type == QuestEventType_FIGHT_FINISH) {
		if (fight_result(player, id) != PVE_FIGHT_SUCCESS) {
			WRITE_DEBUG_LOG("fight not success");
			return 0;
		}

		return 1;
	}

	if (type == QuestEventType_PLAYER_TOTAL_STAR) {
		struct Property * property = player_get_property(player);
		if (!property) {
			return 0;
		}

		if ((int)property->total_star < count) {
			WRITE_WARNING_LOG(" total start not enough %d/%d", property->total_star, count);
			return 0;
		}

		return 1;
	}

	if (type == QuestEventType_HUFU_LEVEL) {
		struct Equip * iter = NULL;
		int hufu_count = 0;
		while ((iter = equip_next(player, iter)) != 0) {
			struct EquipConfig * cfg = get_equip_config(iter->gid);
			if (cfg && IS_EQUIP_TYPE_1(cfg->type) && (iter->add_time < period_end) && (iter->level >= (unsigned int)id)) {
				hufu_count += 1;	
			}
		}

		if (hufu_count < count) {
			WRITE_DEBUG_LOG("hufu for level %d not enough", id);
			return 0;
		}

		return 1;
	}


	if (record < count) {
		WRITE_DEBUG_LOG("  event %d, %d not enough %d/%d", type, id, record, count);
		return 0;
	}
	return 1;
}

int aL_quest_gm_force_submit(Player * player, int id) 
{
	WRITE_INFO_LOG("player %llu force submit quest %d", player_get_id(player), id);
	
	struct QuestConfig * cfg = get_quest_config(id);
	if (cfg == 0) {
		WRITE_DEBUG_LOG("  quest config not exists");		
		return RET_ERROR;
	}

	unsigned long long pid = player_get_id(player);

	int depend_quest_id = id;
	int loop = 0;
	while(depend_quest_id != 0 && loop < 100) {
		struct QuestConfig * dcfg = get_quest_config(depend_quest_id);
		if (!dcfg) break;

		struct Quest * quest = quest_get(player, depend_quest_id);
		//accept
		if (!quest) {
			quest = quest_add(player, depend_quest_id, QUEST_STATUS_INIT, agT_current());
		}

		quest_update_status(quest, QUEST_STATUS_FINISH, -1, -1, quest->count + 1, -1, -1, 0, agT_current());

		struct RewardItem rewards[64];
		memset(rewards, 0, sizeof(struct RewardItem) * 64);
		int nitem = 64;

		struct Reward * reward = reward_create(REASON_QUEST, 0, 0, 0);

		int i = 0;
		for (i = 0; i < QUEST_REWARD_COUNT; i++) {
			if (dcfg->reward[i].type != 0) {
				reward_add_content(reward, 0, dcfg->reward[i].type, dcfg->reward[i].id, dcfg->reward[i].value);
			}
		}

		reward_commit(reward, pid, rewards, 64);

		if (dcfg->drop_id != 0) {
			struct DropInfo drops[1] = { {dcfg->drop_id, player_get_level(player) } };

			unsigned long long heros[HERO_INTO_BATTLE_MAX] = {0};
			int i;
			for (i = 0; i < HERO_INTO_BATTLE_MAX; i++) {
				struct Hero * hero = hero_get_by_pos(player, i+1);
				heros[i] = hero ? hero->uuid : 0;
			}

			aL_send_drop_reward(player, drops, 1, rewards, nitem, heros, HERO_INTO_BATTLE_MAX, 0, 1, REASON_QUEST);
		}

		if (rewards[0].type != 0) {
			struct amf_value * msg = amf_new_array(0);
			amf_push(msg, amf_new_integer(quest->id));

			for (i = 0; i < nitem; i++) {
				if (rewards[i].type == 0) {
					break;
				}

				struct amf_value * r = amf_new_array(3);
				amf_set(r, 0, amf_new_integer(rewards[i].type));
				amf_set(r, 1, amf_new_integer(rewards[i].id));
				amf_set(r, 2, amf_new_integer(rewards[i].value));

				amf_push(msg, r);
			}
			notification_add(quest->pid, NOTIFY_QUEST_REWARD, msg);
		}

		if (depend_quest_id == id && dcfg->next_quest != 0) {
			struct QuestConfig * next_cfg = get_quest_config(dcfg->next_quest);
			WRITE_DEBUG_LOG("  next quest config %p auto_accept %d", next_cfg, next_cfg ? next_cfg->auto_accept : 0);
			if (next_cfg && (next_cfg->auto_accept & 0x01)) {
				WRITE_DEBUG_LOG("  accept next quest %d", dcfg->next_quest);
				aL_quest_accept(player, dcfg->next_quest, 1);
			}
		}

		depend_quest_id = dcfg->depend.quest;
		loop += 1;
	}

	aL_quest_on_event(player, QuestEventType_TASK_SUBMIT, id, 1);
	aL_quest_on_event(player, QuestEventType_SOMETYPE_TASK_FINISH, cfg->type_flag, 1);

	return RET_SUCCESS;
}

int aL_quest_submit(Player * player, int id, int rich_reward, int from_client, int select_next_quest_id)
{
	WRITE_INFO_LOG("player %llu submit quest %d, from %s, %s reward", player_get_id(player), id, from_client ? "client" : "server", rich_reward ? "rich" : "normal");

	struct QuestConfig * cfg = get_quest_config(id);
	if (cfg == 0) {
		WRITE_DEBUG_LOG("  quest config not exists");
		return RET_ERROR;
	}

	if (cfg->only_accept_by_other_activity && from_client) {
		WRITE_DEBUG_LOG("  quest can't change by client");
		return RET_ERROR;
	}

	int manual = 0;
	if (!is_quest_in_time_to_submit(cfg, player, &manual)) {//is_quest_in_time(cfg, player)) {
		WRITE_DEBUG_LOG(" quest not in time");
		return RET_ERROR;
	}

	struct Quest * quest = quest_get(player, id);
	if (quest == 0) {
		WRITE_DEBUG_LOG(" quest not exists");
		return RET_NOT_EXIST;
	}

	aL_update_quest_status(quest, cfg);

	if (quest->status != QUEST_STATUS_INIT) {
		WRITE_DEBUG_LOG(" quest status %d can't submit", quest->status);
		return RET_ERROR;
	}


	if (cfg->next_quest_menu != 0) {
		if (get_quest_from_menu(cfg->next_quest_menu, player_get_level(player), select_next_quest_id) == 0) {
			WRITE_DEBUG_LOG(" select next quest id error %d", select_next_quest_id);
			return RET_PARAM_ERROR;
		}
	}

	// check event record
	unsigned int new_record1 = quest->record_1;
	unsigned int new_record2 = quest->record_2;
	if (!check_quest_event(player, quest->record_1, cfg->event[0].type, cfg->event[0].id, cfg->event[0].count, quest->accept_time, &new_record1, cfg)) {
		return RET_NOT_ENOUGH;
	}

	if (!check_quest_event(player, quest->record_2, cfg->event[1].type, cfg->event[1].id, cfg->event[1].count, quest->accept_time, &new_record2, cfg)) {
		return RET_NOT_ENOUGH;
	}


	struct RewardItem record[64];
	memset(record, 0, sizeof(struct RewardItem) * 64);
	int nitem = 64;


	int i;
	for (i = 0; i < QUEST_CONSUME_COUNT; i++) {
		if ( cfg->consume[i].type != 0 && (cfg->consume[i].need_reset & QUEST_CONSUME_ITEM_FLAG_CONSUME_ON_SUBMIT)) {
			if (CheckForConsume(player,  cfg->consume[i].type, cfg->consume[i].id, 0, cfg->consume[i].value) != RET_SUCCESS) {
				return RET_NOT_ENOUGH;
			}
		} else if ( cfg->consume[i].type != 0 && (cfg->consume[i].need_reset & QUEST_CONSUME_ITEM_FLAG_CHECK_ON_SUBMIT)) {
			if (CheckForConsume(player,  cfg->consume[i].type, cfg->consume[i].id, 0, cfg->consume[i].value) != RET_SUCCESS) {
				return RET_NOT_ENOUGH;
			}
		}
	}

	for (i = 0; i < QUEST_CONSUME_COUNT; i++) {
		if ( cfg->consume[i].type != 0 ) {
			if (cfg->consume[i].need_reset & QUEST_CONSUME_ITEM_FLAG_CLEAN_ON_SUBMIT) {
				TryConsumeAll(player, cfg->consume[i].type, cfg->consume[i].id, 0, REASON_QUEST);
			} else if (cfg->consume[i].need_reset & QUEST_CONSUME_ITEM_FLAG_CONSUME_ON_SUBMIT) {
				CheckAndConsume(player,  cfg->consume[i].type, cfg->consume[i].id, 0, cfg->consume[i].value, REASON_QUEST);
			}
		}
	}

	quest_update_status(quest, QUEST_STATUS_FINISH, (new_record1 != quest->record_1) ? new_record1 : -1, (new_record2 != quest->record_2) ? new_record2 : -1, quest->count + 1, -1, -1, 0, agT_current());


	if (cfg->drop_id != 0 && ( (cfg->drop_count == 0) || (cfg->drop_count >= (int)quest->count))) {
		struct DropInfo drops[1] = { {cfg->drop_id, player_get_level(player) } };

		unsigned long long heros[HERO_INTO_BATTLE_MAX] = {0};
		int i;
		for (i = 0; i < HERO_INTO_BATTLE_MAX; i++) {
			struct Hero * hero = hero_get_by_pos(player, i+1);
			heros[i] = hero ? hero->uuid : 0;
		}

		aL_send_drop_reward(player, drops, 1, record, nitem, heros, HERO_INTO_BATTLE_MAX, 0, 1, REASON_QUEST);
	}

	Reward* reward =reward_create(REASON_QUEST, 0, 0, 0);
	
	for (i = 0; i < QUEST_REWARD_COUNT; i++) {
		if (cfg->reward[i].type != 0 && ((cfg->reward[i].count == 0) || (cfg->reward[i].count >= (int)quest->count))) {
			reward_add_content(reward, 0,  cfg->reward[i].type, cfg->reward[i].id, rich_reward ? cfg->reward[i].richvalue : cfg->reward[i].value);
		}
	}

	//限时额外奖励
	if (cfg->extra_reward_time_limit > 0 && agT_current() <= quest->accept_time + cfg->extra_reward_time_limit) {
		reward_add_content(reward, 0,  cfg->extra_reward.type, cfg->extra_reward.id, cfg->extra_reward.value);
	}

	unsigned long long pid = player_get_id(player);
	reward_commit(reward, pid, record, nitem);

	if (record[0].type != 0) {
		struct amf_value * msg = amf_new_array(0);
		amf_push(msg, amf_new_integer(quest->id));

		for (i = 0; i < nitem; i++) {
			if (record[i].type == 0) {
				break;
			}

			struct amf_value * r = amf_new_array(record[i].uuid > 0 ? 4 : 3);
			amf_set(r, 0, amf_new_integer(record[i].type));
			amf_set(r, 1, amf_new_integer(record[i].id));
			amf_set(r, 2, amf_new_integer(record[i].value));
			if (record[i].uuid > 0) {
				amf_set(r, 3, amf_new_double(record[i].uuid));
			}
			
			amf_push(msg, r);
		}

		if (amf_size(msg) > 1) {
			notification_add(quest->pid, NOTIFY_QUEST_REWARD, msg);
		}
	}

    if (pid > AI_MAX_ID) {
		agL_write_user_logger(QUEST_LOGGER, LOG_FLAT, "%d,%lld,%d,2", (int)agT_current(), pid,id);
	}


	WRITE_DEBUG_LOG("  next quest id %d next quest group %d", cfg->next_quest, cfg->next_quest_group);
	if (cfg->next_quest != 0) {
		struct QuestConfig * next_cfg = get_quest_config(cfg->next_quest);
		WRITE_DEBUG_LOG("  next quest config %p auto_accept %d id %d", next_cfg, next_cfg ? next_cfg->auto_accept : 0, next_cfg ? next_cfg->id : 0);
		if (next_cfg && (next_cfg->auto_accept & 0x01)) {
			WRITE_DEBUG_LOG("  accept next quest %d", cfg->next_quest);
			aL_quest_accept(player, cfg->next_quest, 1);
		}
	}

	if (cfg->next_quest_group != 0) {
		struct QuestConfig * next_cfg = get_quest_from_pool(cfg->next_quest_group, player_get_level(player)); //get_quest_config(cfg->next_quest);
		WRITE_DEBUG_LOG("  next quest config(from group %d) %p auto_accept %d", cfg->next_quest_group, next_cfg, next_cfg ? next_cfg->auto_accept : 0);
		if (next_cfg && (next_cfg->auto_accept & 0x01)) {
			WRITE_DEBUG_LOG("  accept next quest %d", cfg->next_quest);
			aL_quest_accept(player, cfg->next_quest, 1);
		}
	}

	if (cfg->next_quest_menu != 0 && select_next_quest_id != 0) {
		aL_quest_accept(player, select_next_quest_id, 1);
	}

	aL_quest_on_event(player, QuestEventType_TASK_SUBMIT, id, 1);
	aL_quest_on_event(player, QuestEventType_SOMETYPE_TASK_FINISH, cfg->type_flag, 1);

	return RET_SUCCESS;
}

static void calc_record(int * record, int count, int type, int id, Player * player, time_t accept_time)
{
	int old_record = *record;
	if (quest_need_override_min(type, id)) {
		if (count < old_record) *record = count;
	} else if (quest_need_override_max(type, id)) {
		if (count > old_record) *record = count;
	} else {
		if (type == QuestEventType_ONLINE_TIME) {
			Property * property = player_get_property(player);
			if (property->login < accept_time) {
				*record += (agT_current() - accept_time);
			} else {
				*record += (agT_current() - property->login);
			}
		} else {
			*record += count;
		}
	} 
}

int aL_quest_on_event(Player * player, int type, int id, int count)
{
	WRITE_INFO_LOG("player %llu on quest event %d, id %d, count %d", player_get_id(player), type, id, count);

	struct Quest * quest = 0;

	while (( quest = quest_next(player, quest)) != 0) {
		struct QuestConfig * cfg = get_quest_config(quest->id);
		if (cfg == 0) {
			continue;
		}

		aL_update_quest_status(quest, cfg);

		if (!is_quest_in_time(cfg, player)) {
			continue;
		}

		if (quest->status != QUEST_STATUS_INIT) {
			continue;
		}

		int r1 = quest->record_1;
		int r2 = quest->record_2;

		if (cfg->event[0].type == type && cfg->event[0].id == id) {
			//r1 += count;
			calc_record(&r1, count, type, id, player, quest->accept_time);
			if (r1 > (int)cfg->event[0].count) {
				r1 = (int)cfg->event[0].count;
			}
		} else if (cfg->event[1].type == type && cfg->event[1].id == id) {
			//r2 += count;
			calc_record(&r2, count, type, id, player, quest->accept_time);
			if (r2 > (int)cfg->event[1].count) {
				r2 = (int)cfg->event[1].count;
			}
		} else {
			continue;
		}

		quest_update_status(quest, quest->status, r1, r2, -1, -1, -1, 0, 0);

		if ( ((cfg->auto_accept & 0x02) != 0) && r1 >= (int)cfg->event[0].count && r2 >= (int)cfg->event[1].count) {
			aL_quest_submit(player, quest->id, 0, 1, 0);
		}
	}

	return 0;
}

static int battle_star_count(struct Player * player, BattleConfig * battle) 
{
	int count = 0;

	int i;
	struct PVE_FightConfig * ite = 0;
	while( (ite = dlist_next(battle->fights, ite)) != 0) {
		struct Fight * fight = fight_get(player, ite->gid);
		for (i = 0; i < 15; i++) {
			if (fight && (fight->star & (1<<(i*2))) != 0) {
				count ++;
			}
		}
	}
	return count;
}

static int chapter_star_count(struct Player * player, ChapterConifg * chapter)
{
	int count = 0;
	struct BattleConfig * ite = 0;
	while ( (ite = dlist_next(chapter->battles, ite)) != 0) {
		count += battle_star_count(player, ite);
	}
	return count;
}


int aL_recv_one_time_reward(Player * player, unsigned int id)
{
	WRITE_INFO_LOG("player %llu receive one time reward %u", player_get_id(player), id);

	// get config
	struct OnetimeRewardConfig * cfg = get_one_time_reward_config(id);
	if (cfg == 0) {
		WRITE_WARNING_LOG(" config not exists, set flag");

		// set flag
		if (reward_flag_set(player, id) != 0) {
			WRITE_ERROR_LOG("  set flag failed");
			return RET_ERROR;
		}
		return RET_SUCCESS;
	}

	// check flag
	if (reward_flag_get(player, id) != 0) {
		WRITE_WARNING_LOG("  already received");
		return RET_ALREADYAT;
	}

	// check condition
	int reason = 0;
	if (cfg->condition.type == 1) { // chapter star
		ChapterConifg * chapter = get_chapter_config(cfg->condition.id);
		if (chapter == 0) {
			WRITE_WARNING_LOG("  chapter %d not exists", cfg->condition.id);
			return RET_ERROR;
		}

		int count = chapter_star_count(player, chapter);
		if (count < cfg->condition.value) {
			WRITE_INFO_LOG("  chapter %d start not enough %d/%d", cfg->condition.id, count, cfg->condition.value);
			return RET_DEPEND;
		}
		reason = REASON_ONE_TIME_REWARD_STAR;
	} else if (cfg->condition.type == 2) { // battle star
		BattleConfig * battle = get_battle_config(cfg->condition.id);
		if (battle == 0) {
			WRITE_WARNING_LOG("  battle %d not exists", cfg->condition.id);
			return RET_ERROR;
		}

		int count = battle_star_count(player, battle);
		if (count < cfg->condition.value) {
			WRITE_INFO_LOG("  battle %d start not enough %d/%d", cfg->condition.id, count, cfg->condition.value);
			return RET_DEPEND;
		}

		reason = REASON_ONE_TIME_REWARD_STAR;
	} else if (cfg->condition.type == 4) {
		// set flag
		WRITE_DEBUG_LOG(" conditon_type for beginner guidance");
		if (reward_flag_set(player, id) != 0) {
			WRITE_ERROR_LOG("  set flag failed");
			return RET_ERROR;
		}
		return RET_SUCCESS;

	} else {
		WRITE_WARNING_LOG("  unknown condition_type %d", cfg->condition.type);
		return RET_ERROR;
	}

	// consume
	if (cfg->consume.type > 0 && cfg->consume.id > 0 && CheckAndConsume(player, cfg->consume.type, cfg->consume.id, 0, cfg->consume.value, reason) != 0) {
		WRITE_INFO_LOG("  consume %d, %d, %d not enough", cfg->consume.type, cfg->consume.id, cfg->consume.value);
		return RET_NOT_ENOUGH;
	}

	// set flag
	if (reward_flag_set(player, id) != 0) {
		WRITE_ERROR_LOG("  set flag failed");
		return RET_ERROR;
	}

	// reward
	sendReward(player, 0, "", 0, 0, reason, ONE_TIME_REWARD_COUNT, 
			cfg->rewards[0].type, cfg->rewards[0].id, cfg->rewards[0].value,
			cfg->rewards[1].type, cfg->rewards[1].id, cfg->rewards[1].value,
			cfg->rewards[2].type, cfg->rewards[2].id, cfg->rewards[2].value,
			cfg->rewards[3].type, cfg->rewards[3].id, cfg->rewards[3].value);

	return RET_SUCCESS;
}


int aL_pve_fight_fast_pass(Player * player, unsigned int id, int count, struct RewardItem * items, int nitem)
{
	WRITE_INFO_LOG("player %llu fast fight fight %d, times %d", player_get_id(player), id, count);
	struct PVE_FightConfig * cfg = get_pve_fight_config(id);
	if (cfg == 0) {
		WRITE_INFO_LOG("  config not exists");
		return RET_ERROR;
	}

	Fight * fight = fight_get(player, id);
	if (fight == 0 || fight->flag == 0) {
		WRITE_INFO_LOG("  fight is not pass");		
		return RET_ERROR;
	}

	if (!cfg->can_yjdq) {
		WRITE_INFO_LOG(" can't fast fight");
		return RET_ERROR;
	}

	// check daily count
	if (cfg->count_per_day < (fight->today_count + count)) {
		WRITE_INFO_LOG("  count (%d+%d) > limit (%d)", fight->today_count, count, cfg->count_per_day);
		return RET_FIGHT_CHECK_COUNT_FAIL;
	}

	// consume
	if (pve_fight_consume(player, cfg, 1) != RET_SUCCESS) {
		return RET_NOT_ENOUGH;
	}

	// update count
	fight_update_player_data(player, fight, fight->flag, fight->star, fight->today_count + count);


	// reward
	unsigned long long heros[HERO_INTO_BATTLE_MAX] = {0};

	int i;
	for (i = 0; i < HERO_INTO_BATTLE_MAX; i++) {
		struct Hero * hero = hero_get_by_pos(player, i+1);
		heros[i] = hero ? hero->uuid : 0;
	}

	for (i = 0; i < count; i++) {
		pve_fight_drop(player, cfg->gid, 0, heros, HERO_INTO_BATTLE_MAX, items, nitem);
	}

	aL_quest_on_event(player, QuestEventType_FIGHT, cfg->gid, count);

	if (cfg->battle_id > 0) {
		//挑战回忆录
		aL_quest_on_event(player, 4, 20, 1);
		struct BattleConfig * bcfg  = get_battle_config(cfg->battle_id);
		if (bcfg && bcfg->chapter_id > 0) {
			aL_quest_on_event(player, QuestEventType_CHAPTER, bcfg->chapter_id, count);
		}
	}

	if (cfg->battle_id) {
		aL_quest_on_event(player, QuestEventType_BATTLE, cfg->battle_id, count);
	}

	return RET_SUCCESS;
}

int aL_hero_select_skill(Player * player, unsigned long long uuid, int group, int skill1, int skill2, int skill3, int skill4, int skill5, int skill6)
{
	WRITE_INFO_LOG("player %llu hero %llu select skill %d(%d, %d, %d, %d, %d, %d)", player_get_id(player), uuid, group, skill1, skill2, skill3, skill4, skill5, skill6);

	int i, j;
	int skills[] = { skill1, skill2, skill3, skill4, skill5, skill6 };
	for (i = 0; i < 6; i++) {
		if (skills[i]) {
			for (j = i + 1; j < 6; j++) {
				if (skills[i] == skills[j]) {
					WRITE_DEBUG_LOG("  duplicate skill id %d", skills[i]);
					return RET_PARAM_ERROR;
				}
			}
		}
	}

	struct Hero * hero = hero_get(player, 0, uuid);
	if (hero == 0) {
		WRITE_DEBUG_LOG(" hero not exists");
		return RET_ERROR;
	}

	struct HeroConfig * cfg = get_hero_config(hero->gid);
	if (cfg == 0) {
		WRITE_DEBUG_LOG(" hero config %d not exists", hero->gid);
		return RET_ERROR;
	}

	struct WeaponConfig * wcfg = get_weapon_config(cfg->weapon);
	if (wcfg == 0) {
		WRITE_DEBUG_LOG(" weapon config %d not exists", cfg->weapon);
		return RET_ERROR;
	}

	int property_type  = 0;
	int property_value = 0;

	if (group == 0) {
		for (i = 0; i < 6; i++) {
			if (skills[i] != 0) {
				for (j = 0; j < HERO_WEAPON_SKILL_COUNT; j++) {
					if (wcfg->skills[j] == skills[i]) {
						break;
					}
				}

				if (j >= HERO_WEAPON_SKILL_COUNT) {
					WRITE_DEBUG_LOG(" skill %d not in weapon config %d", skills[i], cfg->weapon);
					return RET_PARAM_ERROR;
				}
			}
		}
	} else {
		struct HeroSkillGroupConfig * skill_group = get_hero_skill_group_config(hero->gid);
		for (; skill_group; skill_group = skill_group->next) {
			if (skill_group->group == group) {
				break;
			}
		}

		if (skill_group == 0) {
			WRITE_DEBUG_LOG(" hero %d have not skill group %d", hero->gid, group);
			return RET_ERROR;
		}

		skills[0] = skill_group->skill[0];
		skills[1] = skill_group->skill[1];
		skills[2] = skill_group->skill[2];
		skills[3] = skill_group->skill[3];
		skills[4] = skill_group->skill[4];
		skills[5] = skill_group->skill[5];

		property_type = skill_group->property_type;
		property_value = skill_group->property_value;
	}

	hero_set_selected_skill(player, uuid, skills[0], skills[1], skills[2], skills[3], skills[4], skills[5], property_type, property_value);

	return RET_SUCCESS;
}

int aL_add_buff(unsigned long long playerid, unsigned int buff_id, int buff_value)
{
	WRITE_DEBUG_LOG("aL_add_buff  buff:%d", buff_id);
	BuffConfig * bcfg = get_buff_config(buff_id);	
	if (!bcfg) {
		WRITE_DEBUG_LOG("%s:donnt has config for buff %u", __FUNCTION__, buff_id);		
		return RET_ERROR;
	}

	time_t end_time = 0;			
	if (bcfg->duration != 0) {
		end_time = agT_current() + bcfg->duration;
	}

	if (bcfg->end_time != 0 && (end_time > bcfg->end_time || end_time == 0)) {
		end_time = bcfg->end_time;	
	}

	if (bcfg->duration == 0 && bcfg->end_time == 0) {
		end_time = 1893427200;  // 2030年1月1日00:00:00 
	}

	if (!buff_add(playerid, buff_id, buff_value, (time_t)end_time)) {
		return RET_ERROR;
	}

	return RET_SUCCESS;
}

int aL_remove_buff(unsigned long long playerid, unsigned int buff_id, int buff_value) 
{
	WRITE_DEBUG_LOG("aL_remove_buff  buff:%d", buff_id);
	BuffConfig * bcfg = get_buff_config(buff_id);	
	if (!bcfg) {
		WRITE_DEBUG_LOG("%s:donnt has config for buff %u", __FUNCTION__, buff_id);		
		return RET_ERROR;
	}

	if (buff_remove(playerid, buff_id, buff_value) != 0) {
		return RET_ERROR;
	}

	return RET_SUCCESS;
}

int aL_draw_compen_item(Player *player, time_t time, RewardItem *items, int size)
{
	WRITE_DEBUG_LOG("%s: draw compensate item, pid is %lld, time is %ld.", __FUNCTION__, player_get_id(player), time);

	struct DropInfo drops[1024];
	int real_size = 0;
	
	memset(drops, 0, sizeof(drops));
	if (0 == draw_item(player, time, drops, 1024, &real_size)) {	
		return aL_send_drop_reward(player, drops, real_size, items, size, 0, 0, 0, 1, REASON_COMPENSATE);
	}

	return RET_ERROR;
}

void aL_save_hero_capacity_to_check_data(Player * player, struct HeroCapacity * hero_list, int nheros)
{
	struct CheckData * check_data = player_get_check_data(player);
	if (check_data->capacity_list != 0) {
		//free check data
		while(check_data->capacity_list)
		{
			struct HeroCapacity * node = check_data->capacity_list;
			dlist_remove(check_data->capacity_list, node);
			free(node);
		}
	}

	for (int i = 0; i < nheros; i++) {
		struct HeroCapacity hc = hero_list[i];
		struct HeroCapacity * pNew = (struct HeroCapacity *)malloc(sizeof(struct HeroCapacity));
		memset(pNew, 0, sizeof(struct HeroCapacity));
		pNew->hero_uuid = hc.hero_uuid;
		pNew->capacity = hc.capacity;

		dlist_init(pNew);
		dlist_insert_tail(check_data->capacity_list, pNew);
	}

}

int aL_equip_sell_to_system(Player * seller, int equip_gid, unsigned long long equip_uuid, struct RewardItem * consume, int n, unsigned int reason)
{
	if (!seller) {
		return RET_ERROR;
	}

	Player * system = player_get(SYSTEM_PID);
	if (!system) {
		return RET_ERROR;
	}

	Equip * equip = equip_get(seller, equip_uuid);
	if (!equip) {
		WRITE_DEBUG_LOG("Player:%llu fail to sell equip to system, seller:%llu not own equip:%llu", player_get_id(seller), player_get_id(seller), equip_uuid);
		return RET_ERROR;
	}

	for (int i = 0; i < n; i++) {
		if (CheckAndConsume(seller, consume[i].type, consume[i].id, 0, consume[i].value, reason) != 0) {
			WRITE_DEBUG_LOG("Player:%llu fail to sell equip to system, consume fail", player_get_id(seller));
			return RET_ERROR;	
		}
	}

	if (equip_trade(seller, system, equip) != 0) {
		WRITE_DEBUG_LOG("Player:%llu fail to sell equip to system, trade fail", player_get_id(seller));
		return RET_ERROR;
	}
	
	return RET_SUCCESS;
}

int aL_equip_buy_from_system(Player * buyer, int equip_gid, unsigned long long equip_uuid, struct RewardItem * consume, int n, unsigned int reason)
{
	if (!buyer) {
		return RET_ERROR;
	}

	Player * system = player_get(SYSTEM_PID);
	if (!system) {
		return RET_ERROR;
	}

	Equip * equip = equip_get(system, equip_uuid);
	if (!equip) {
		WRITE_DEBUG_LOG("Player:%llu fail to buy equip from system, system not own equip:%llu", player_get_id(buyer), equip_uuid);
		return RET_ERROR;
	}

	if (equip->gid != equip_gid) {
		WRITE_DEBUG_LOG("Player:%llu fail to buy equip from system, equip:%llu real gid is %d not %d", player_get_id(buyer), equip_uuid, equip->gid, equip_gid);
		return RET_ERROR;
	}

	for (int i = 0; i < n; i++) {
		if (CheckAndConsume(buyer, consume[i].type, consume[i].id, 0, consume[i].value, reason) != 0) {
			WRITE_DEBUG_LOG("Player:%llu fail to buy equip from system, consume fail", player_get_id(buyer));
			return RET_ERROR;	
		}
	}

	if (equip_trade(system, buyer, equip) != 0) {
		WRITE_DEBUG_LOG("Player:%llu fail to buy equip from system, trade fail", player_get_id(buyer));
		return RET_ERROR;
	}
	
	return RET_SUCCESS;
}
