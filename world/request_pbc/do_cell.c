#include <assert.h>
#include <string.h>
#include "log.h"
#include "dlist.h"
#include "message.h"
#include "player.h"
#include "package.h"
#include "amf.h"
#include "build_message.h"
#include "logic/aL.h"
#include "notify.h"
#include "modules/item.h"
#include "modules/reward.h"
#include "modules/equip.h"
#include "config/reward.h"
#include "dispatch.h"
#include "addicted.h"
#include "protocol.h"
#include "do.h"
#include "pbc_int64.h"
#include "config/item_package.h"
#include "modules/hero.h"
#include "modules/hero_item.h"
#include "aifightdata.h"

#define YQ_SORT_MILITARY_POWER_MAX_COUNT 100
#define YQ_GET_MILITARY_POWER_MAX_COUNT 100

//extern struct pbc_env * env;
void do_pbc_add_player_notification(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PAddPlayerNotificationRequest", "PAddPlayerNotificationRespond");

	// 读取参数
	unsigned long long playerid = (unsigned long long)pbc_rmessage_int64(request, "playerid", 0);

	CHECK_PID_AND_TRANSFORM(playerid);

	READ_INT(type);

	int sz;
	const char * ptr = pbc_rmessage_string(request, "data", 0, &sz);

	WRITE_DEBUG_LOG("service add player %llu notification", playerid);

	// 权限验证
	if (channel != 0 ) {
		result = RET_PREMISSIONS;
	} else {
		size_t rlen = 0;
		amf_value * v = amf_read(ptr, sz, &rlen);
		assert(rlen == (unsigned int)sz);

		int ret = notification_add(playerid, type, v);
		
		WRITE_DEBUG_LOG("cell type: %d", type);

		result = ((ret == 0) ? RET_SUCCESS : RET_ERROR);
	}

	FINI_REQUET_RESPOND(S_ADD_PLAYER_NOTIFICATION_RESPOND, result);
}

void do_pbc_get_player_info(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PGetPlayerInfoRequest", "PGetPlayerInfoRespond");

	unsigned long long target = (unsigned long long)pbc_rmessage_int64(request, "playerid", 0);

	//CHECK_PID_AND_TRANSFORM(target);

	WRITE_DEBUG_LOG("service get player %llu info %s", target, __FUNCTION__);

	// 权限验证
	if (channel != 0 ) {
		result = RET_PREMISSIONS;
	} else {
		if (target == 0) {
			const char * name = pbc_rmessage_string(request, "name", 0, 0);
			if (name) {
				target = player_get_id_by_name(name);
			}
		}
		struct Player * player = player_get(target);
		if (player == 0) {
			result = RET_CHARACTER_NOT_EXIST;
		} else {
			result = RET_SUCCESS;

			Property * property = player_get_property(player);
			struct pbc_wmessage * xplayer = pbc_wmessage_message(respond, "player");
			//struct Hero * leading_actor = hero_get(player, LEADING_ROLE, 0);
			//unsigned int level = leading_actor ? leading_actor->level : 1;
			int level = player_get_level(player);
			pbc_wmessage_int64(xplayer, "id",      target);
			pbc_wmessage_string (xplayer, "name",    player_get_name(player), 0);
			pbc_wmessage_integer(xplayer, "level", level, 0);
			pbc_wmessage_integer(xplayer, "vip", 0, 0);
			pbc_wmessage_integer(xplayer, "login",   property->login, 0);
			pbc_wmessage_integer(xplayer, "logout",  property->logout, 0);
			pbc_wmessage_integer(xplayer, "status",	 property->status, 0);
			pbc_wmessage_string(xplayer, "ip", property->ip, 0);
			pbc_wmessage_integer(xplayer, "create", property->create, 0);
			Item *item = item_get(player, 90006);
			int count = item ? item->limit : 0;
			pbc_wmessage_integer(xplayer, "money", count, 0);
		}
	}

	FINI_REQUET_RESPOND(S_GET_PLAYER_INFO_RESPOND, result);
}

void do_pbc_get_player_hero_info(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PGetPlayerHeroInfoRequest", "PGetPlayerHeroInfoRespond");

	assert(channel == 0);

	unsigned long long target = (unsigned long long)pbc_rmessage_int64(request, "playerid", 0);

	CHECK_PID_AND_TRANSFORM(target);

	WRITE_DEBUG_LOG("service get player %llu hero info %s", target, __FUNCTION__);

	// 权限验证
	if (channel != 0 ) {
		result = RET_PREMISSIONS;
	} else {
		if (target == 0) {
			const char * name = pbc_rmessage_string(request, "name", 0, 0);
			if (name) {
				target = player_get_id_by_name(name);
			}
		}
		struct Player * player = player_get(target);
		if (player == 0) {
			result = RET_CHARACTER_NOT_EXIST;
		} else {
			unsigned int gid = pbc_rmessage_integer(request, "gid", 0, 0);
			unsigned long long uuid = pbc_rmessage_int64(request, "uuid", 0);
			if (gid || uuid) {
				struct Hero * hero = hero_get(player, gid, uuid);
				/********
				int exp;
				unsigned int level;
				int stage;
				int star;
				int stage_slot;
				int weapon_stage;
				int weapon_star;
				int weapon_level;
				int weapon_stage_slot;
				int weapon_exp;
				int placeholder;
				**********/
				if (hero) {
					struct pbc_wmessage * xhero = pbc_wmessage_message(respond, "hero");
					pbc_wmessage_integer(xhero, "gid",               hero->gid,               0);
					pbc_wmessage_int64(xhero, "uuid",                hero->uuid);
					pbc_wmessage_integer(xhero, "exp",               hero->exp,               0);
					pbc_wmessage_integer(xhero, "level",             hero->level,             0);
					pbc_wmessage_integer(xhero, "stage",             hero->stage,             0);	
					pbc_wmessage_integer(xhero, "star",              hero->star,              0);	
					pbc_wmessage_integer(xhero, "stage_slot",        hero->stage_slot,        0);	
					pbc_wmessage_integer(xhero, "weapon_stage",      hero->weapon_stage,      0);	
					pbc_wmessage_integer(xhero, "weapon_star",       hero->weapon_star,       0);	
					pbc_wmessage_integer(xhero, "weapon_level",      hero->weapon_level,      0);
					pbc_wmessage_integer(xhero, "weapon_stage_slot", hero->weapon_stage_slot, 0);	
					pbc_wmessage_integer(xhero, "weapon_exp",        hero->weapon_exp,        0);	
					pbc_wmessage_integer(xhero, "placeholder",       hero->placeholder,       0);	
					WRITE_DEBUG_LOG("hero  exp:%d  level:%d  stage:%d", hero->exp, hero->level, hero->stage);
					result = RET_SUCCESS;
				} else {
					result = RET_ERROR;
				}
			} else {
				struct Hero * it = NULL;
				while((it = hero_next(player, it)) != 0)
				{
					struct pbc_wmessage* hero = pbc_wmessage_message(respond, "heros");
					pbc_wmessage_integer(hero, "gid",               it->gid,               0);
					pbc_wmessage_int64(hero, "uuid",                it->uuid);
					pbc_wmessage_integer(hero, "exp",               it->exp,               0);
					pbc_wmessage_integer(hero, "level",             it->level,             0);
					pbc_wmessage_integer(hero, "stage",             it->stage,             0);	
					pbc_wmessage_integer(hero, "star",              it->star,              0);	
					pbc_wmessage_integer(hero, "stage_slot",        it->stage_slot,        0);	
					pbc_wmessage_integer(hero, "weapon_stage",      it->weapon_stage,      0);	
					pbc_wmessage_integer(hero, "weapon_star",       it->weapon_star,       0);	
					pbc_wmessage_integer(hero, "weapon_level",      it->weapon_level,      0);
					pbc_wmessage_integer(hero, "weapon_stage_slot", it->weapon_stage_slot, 0);	
					pbc_wmessage_integer(hero, "weapon_exp",        it->weapon_exp,        0);	
					pbc_wmessage_integer(hero, "placeholder",       it->placeholder,       0);
				}
				result = RET_SUCCESS;
			}	
		}
	}

	WRITE_DEBUG_LOG("Finish get player hero info result:%d", result);
	FINI_REQUET_RESPOND(S_GET_PLAYER_HERO_INFO_RESPOND, result);
}

void do_pbc_get_player_return_info(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PGetPlayerReturnInfoRequest", "PGetPlayerReturnInfoRespond");

	unsigned long long target = (unsigned long long)pbc_rmessage_int64(request, "playerid", 0);

	CHECK_PID_AND_TRANSFORM(target);

	WRITE_DEBUG_LOG("service get player %llu info %s", target, __FUNCTION__);

	// 权限验证
	if (channel != 0 ) {
		result = RET_PREMISSIONS;
	} else {
		if (target == 0) {
			const char * name = pbc_rmessage_string(request, "name", 0, 0);
			if (name) {
				target = player_get_id_by_name(name);
			}
		}
		struct Player * player = player_get(target);
		if (player == 0) {
			result = RET_CHARACTER_NOT_EXIST;
		} else {
			result = RET_SUCCESS;
			pbc_wmessage_integer(respond, "return_7_time", 0, 0);
		}
	}

	FINI_REQUET_RESPOND(S_GET_PLAYER_RETURN_INFO_RESPOND, result);
}

static int check_condition(Player * player, struct pbc_rmessage* request)
{
	int n = pbc_rmessage_size(request, "consume");
	int i;

	unsigned long long equip_uuid [64] = {0};

	for(i = 0; i < n; i++) {
		struct pbc_rmessage * reward = pbc_rmessage_message(request, "consume", i);
		unsigned int type  = pbc_rmessage_integer(reward, "type",  0, 0);
		unsigned int id    = pbc_rmessage_integer(reward, "id",    0, 0);
		unsigned int value = pbc_rmessage_integer(reward, "value", 0, 0);
		unsigned int empty = pbc_rmessage_integer(reward, "empty", 0, 0);
		WRITE_DEBUG_LOG("player %llu check_condition %u %u %u", player_get_id(player), type, id, value);
		if (type == REWARD_TYPE_ITEM) {
			Item * item = item_get(player, id);
			if (empty != 1 && (item == 0 || item->limit < value || item->limit == 0)) {
				return 0;
			}
		} else if (type == REWARD_TYPE_ITEM_PACKAGE) {
			PITEM_PACKAGE pkg_cfg =get_item_package_config(id);
            if(!pkg_cfg){
                WRITE_INFO_LOG("player %llu  check_condition %u %u %u fail,cfg not exist", player_get_id(player), type, id, value);
                return 0;
            }

            PITEM item =pkg_cfg->item_list;
            int has_enough_resource = 1;
            while(item){
                /*if (item->type == REWARD_TYPE_RESOURCE) {
                    Resource * res = resources_get(player, item->id);
                    if(!(res && res->value >= item->value*value)){
                        has_enough_resource = 0;
                        break;
                    }
                } else*/ if (item->type == REWARD_TYPE_ITEM) {
                    Item * it = item_get(player, item->id);
                    if(!(it && it->limit >= item->value*value)){
                        has_enough_resource = 0;
                    }
                }
                // next
                item =item->next;
            }
            return has_enough_resource;
		} else if (type == REWARD_TYPE_EQUIP || type == REWARD_TYPE_INSCRIPTION) {
			unsigned int j, k, n = pbc_rmessage_size(reward, "uuid");
			if (n < value) {
				WRITE_DEBUG_LOG(" size of uuid = 0");
				return 0;
			}

			for (j = 0; j < value; j++) {
				uint64_t uuid = pbc_rmessage_int64(reward, "uuid", j);
				for (k = 0; k < 64; k++) {
					if (equip_uuid[k] == 0) {
						break;
					}

					if (equip_uuid[k] == uuid) {
						WRITE_DEBUG_LOG(" duplicate uuid %llu", (unsigned long long)uuid);
						return 0;
					}
				}

				if (k >= 64) {
					WRITE_DEBUG_LOG(" too much equip");
					return 0;
				}

				equip_uuid[k] = uuid;

				if (equip_get(player, uuid) == 0) {
					WRITE_DEBUG_LOG(" equip %llu not exists", (unsigned long long)uuid);
					return 0;
				}
			}
		} else if (type == REWARD_TYPE_HEROITEM) {
			unsigned int i, n = pbc_rmessage_size(reward, "uuid");
			for (i = 0; i < n; i++) {
				uint64_t uuid = pbc_rmessage_int64(reward, "uuid", i);
				if ((unsigned int)hero_item_count(player, uuid, id) < value) {
					return 0;
				}
			}
		} else if (type == REWARD_TYPE_OPEN_CHECK) {
			if (aL_check_openlev_config(player, id) != RET_SUCCESS) {
				return 0;
			}
		} else if (type == 0) {
			continue; // return 1;
		} else if (REWARD_TYPE_PERMIT == type) {
			Item * item = item_get(player, id);
			if (item == 0 || item->limit < value || item->limit == 0) {
				return 0;
			}
		} else {
			return 0;
		}
	}
	return 1;
}

static int do_item_package_consume(Player *player, unsigned int package_id, unsigned int value, unsigned int reason)
{
    PITEM_PACKAGE pkg_cfg =get_item_package_config(package_id);
    if(!pkg_cfg){
        WRITE_INFO_LOG("playe %u fail to do_item_package_consume %d, not exist", (unsigned int)player_get_id(player), package_id);
        return -1;
    }

    PITEM item =pkg_cfg->item_list;

    //check
    int has_enough_resource = 1;
    while(item){
        /*if (item->type == REWARD_TYPE_RESOURCE) {
            Resource * res = resources_get(player, item->id);
            if(!(res && res->value >= item->value*value)){
                has_enough_resource = 0;
                break;
            }
        } else*/ if (item->type == REWARD_TYPE_ITEM) {
            Item * it = item_get(player, item->id);
            if(!(it && it->limit >= item->value*value)){
                has_enough_resource = 0;
            }
        }

        // next
        item =item->next;
    }

    //do consume
    item =pkg_cfg->item_list;
    if (has_enough_resource) {
        while(item){
            /*if (item->type == REWARD_TYPE_RESOURCE) {
                Resource * res = resources_get(player, item->id);
                assert(res && res->value >= item->value*value);
                resources_reduce(res, item->value*value, reason);
            } else*/ if (item->type == REWARD_TYPE_ITEM) {
                Item * it = item_get(player, item->id);
                assert(it && it->limit >= item->value*value);
                item_set(player, item->id, it->limit - item->value*value, reason);
            }

            // next
            item =item->next;
        }
    } else {
        return -1;
    }
    return 0;
}

static int do_consume(Player * player, struct pbc_rmessage * request, unsigned int reason)
{
	int n = pbc_rmessage_size(request, "consume");
	int i;
	for(i = 0; i < n; i++) {
		struct pbc_rmessage * reward = pbc_rmessage_message(request, "consume", i);
		unsigned int type  = pbc_rmessage_integer(reward, "type",  0, 0);
		unsigned int id    = pbc_rmessage_integer(reward, "id",    0, 0);
		unsigned int value = pbc_rmessage_integer(reward, "value", 0, 0);
		unsigned int empty = pbc_rmessage_integer(reward, "empty", 0, 0);

		if (value == 0) { continue; }

		WRITE_DEBUG_LOG("player %llu do_consume %u %u %u", player_get_id(player), type, id, value);
		if (type == REWARD_TYPE_ITEM) {
			Item * item = item_get(player, id);
			if (empty != 1) assert(item && item->limit >= value);
			if (empty == 1 || empty == 2) {
				item_set(player, id, 0, reason);
			} else {
				item_set(player, id, item->limit - value, reason);
			}
		} else if (type == REWARD_TYPE_ITEM_PACKAGE) {
			if (do_item_package_consume(player,id,value,reason) != 0) return -1;
		} else if (type == REWARD_TYPE_EQUIP || type == REWARD_TYPE_INSCRIPTION) {
			unsigned int i, n = pbc_rmessage_size(reward, "uuid");
			if (n < value) {
				return 0;
			}

			for (i = 0; i < value; i++) {
				uint64_t uuid = pbc_rmessage_int64(reward, "uuid", i);
				// Equip * equip = equip_get(player, uuid);
				if (aL_equip_delete(player, uuid, reason, 0, 0, 0) != 0) {
					return -1;
				}
			}
		} else if (type == REWARD_TYPE_HEROITEM) {
			unsigned int i, n = pbc_rmessage_size(reward, "uuid");
			for (i = 0; i < n; i++) {
				uint64_t uuid = pbc_rmessage_int64(reward, "uuid", i);
				if (hero_item_remove(player, uuid, id, value, reason) != 0) {
					return -1;
				}
			}
		}

	}
	return 0;
}

static unsigned int do_reward(unsigned long long pid, struct pbc_rmessage * request, unsigned int reason)
{
	unsigned int limit = pbc_rmessage_integer(request, "limit", 0, 0);
	// unsigned int reason = pbc_rmessage_integer(request, "reason", 0, 0);
	unsigned int manual = pbc_rmessage_integer(request, "manual", 0, 0);

	const char * name  = pbc_rmessage_string(request, "name", 0, 0);

	int n = pbc_rmessage_size(request, "reward");
	if (n == 0) {
		return 0;
	}

	Reward * reward = reward_create(reason, limit, manual, name);
	if (reward == 0) {
		return RET_ERROR;
	}

#define SET_UP_CONDITION(N) do { if (cond) reward->N = pbc_rmessage_integer(cond, #N, 0, 0); } while(0)
	//SET_UP_CONDITION(level);
	//SET_UP_CONDITION(vip);
	//SET_UP_CONDITION(item);
	//SET_UP_CONDITION(armament);
	//SET_UP_CONDITION(fire);
	//SET_UP_CONDITION(star);
	//SET_UP_CONDITION(power);

	//SET_UP_CONDITION(level_max);
	//SET_UP_CONDITION(vip_max);
	//SET_UP_CONDITION(fire_max);
	//SET_UP_CONDITION(star_max);
	//SET_UP_CONDITION(power_max);
	//SET_UP_CONDITION(relationship);
#undef SET_UP_CONDITION

	int i;
	for(i = 0; i < n; i++) {
		struct pbc_rmessage * re = pbc_rmessage_message(request, "reward", i);

		uint32_t type  = pbc_rmessage_integer(re, "type",  0, 0);
		uint32_t value = pbc_rmessage_integer(re, "value", 0, 0);
		uint32_t id    = pbc_rmessage_integer(re, "id",   0, 0);
		unsigned long long uuid = pbc_rmessage_int64(re, "uuid", 0);

		WRITE_DEBUG_LOG("%u, %u, %u", type, value, id);

		int nhero = pbc_rmessage_size(re, "uuids");
		if (nhero > 0 && type == 90) {
			int j;
			for (j = 0 ; j < nhero; j++) {
				int uuid = pbc_rmessage_int64(re, "uuids", j);
				if (reward_add_content(reward, uuid, type, id, value) == 0) {
					goto failed;
				}
			}
		} else if (reward_add_content(reward, uuid, type, id, value) == 0) {
			goto failed;
		}
	}

	if (reward_commit(reward, pid, 0, 0) != 0) {
		return RET_ERROR;
	}
	return 0;
failed:
	reward_rollback(reward);
	return RET_ERROR;
}

void do_pbc_admin_reward(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PAdminRewardRequest", "PAdminRewardRespond");

	if (channel != 0 ) {
		result = RET_PREMISSIONS;
	} else {
		unsigned long long target = (unsigned long long)pbc_rmessage_int64(request, "playerid", 0);
		uint32_t reason = pbc_rmessage_integer(request, "reason", 0, 0);

		CHECK_PID_AND_TRANSFORM(target);

		int ndrops = pbc_rmessage_size(request, "drops");
		if (ndrops > 0) {
			WRITE_DEBUG_LOG("service give player %llu drops, reason %d", target, reason);

			uint32_t first_time = pbc_rmessage_integer(request, "first_time", 0, 0); 
			uint32_t send_reward = pbc_rmessage_integer(request, "send_reward", 0, 0); 

			Player * player = send_reward ? player_get(target) : 0;
			if (send_reward && player == 0) {
				WRITE_WARNING_LOG("send reward to not exist player %llu", target);
				return;
			}

			struct RewardItem rewards [20];
			memset(rewards, 0, sizeof(rewards));

			unsigned long long heros[HERO_INTO_BATTLE_MAX] = {0};
			struct DropInfo drops[20] = {{0, 0}};

			int i, nhero = pbc_rmessage_size(request, "heros");
			if (nhero > HERO_INTO_BATTLE_MAX) {
				nhero = HERO_INTO_BATTLE_MAX;
			}

			for (i = 0; i < nhero; i++) {
				heros[i] = pbc_rmessage_int64(request, "heros", i);	
			}

			for (i = 0; i < ndrops; i++) {
				struct pbc_rmessage * drop = pbc_rmessage_message(request, "drops", i);
				drops[i].id = pbc_rmessage_integer(drop, "id", 0, 0);
				drops[i].level = pbc_rmessage_integer(drop, "level", 0, 0);
			}

			WRITE_DEBUG_LOG("send_reward  %d", send_reward);
			if (send_reward) {
				if (!check_condition(player, request)) {
					WRITE_DEBUG_LOG("`%llu` fail to %s, resource NOT_ENOUGH", channel, __FUNCTION__);
					result = RET_NOT_ENOUGH;
				} else {
					aL_send_drop_reward(player, drops, ndrops, rewards,  20, heros, nhero, first_time, send_reward, reason);
					do_consume(player, request, reason);

					for (i = 0; i< 20; i++) {
						if (rewards[i].type != 0 && rewards[i].id != 0) {
							struct pbc_wmessage* reward =pbc_wmessage_message(respond, "rewards");
							pbc_wmessage_int64(reward, "type", rewards[i].type);
							pbc_wmessage_int64(reward, "id", rewards[i].id);
							pbc_wmessage_int64(reward, "value", rewards[i].value);
						}
					}	
					result = RET_SUCCESS;
				}
			} else {
				aL_send_drop_reward(player, drops, ndrops, rewards,  20, heros, nhero, first_time, send_reward, reason);
				for (i = 0; i< 20; i++) {
					if (rewards[i].type != 0 && rewards[i].id != 0) {
						struct pbc_wmessage* reward =pbc_wmessage_message(respond, "rewards");
						pbc_wmessage_int64(reward, "type", rewards[i].type);
						pbc_wmessage_int64(reward, "id", rewards[i].id);
						pbc_wmessage_int64(reward, "value", rewards[i].value);
					}
				}	
				result = RET_SUCCESS;
			}

		} else {

			//uint32_t reason = pbc_rmessage_integer(request, "reason", 0, 0);

			WRITE_DEBUG_LOG("service add player %llu reward, reason %d", target, reason);
			Player * player = player_get(target);
			if (player==0) {
				WRITE_DEBUG_LOG("`%llu` fail to %s, CHARACTER_NOT_EXIST", channel, __FUNCTION__);
				result = RET_CHARACTER_NOT_EXIST;
			}
			else
			{
				if (!check_condition(player, request)) {
					WRITE_DEBUG_LOG("`%llu` fail to %s, resource NOT_ENOUGH", channel, __FUNCTION__);
					result = RET_NOT_ENOUGH;
				} else {
					result = RET_SUCCESS;

					do_consume(player, request, reason);
					do_reward(target, request, reason);
				}
			}
		}
	}
	FINI_REQUET_RESPOND(S_ADMIN_REWARD_RESPOND, result);
}

void do_pbc_set_player_status(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PSetPlayerStatusRequest", "PSetPlayerStatusRespond"); 

	// 读取参数
	unsigned long long target = (unsigned long long)pbc_rmessage_int64(request, "playerid", 0);

	CHECK_PID_AND_TRANSFORM(target);

	unsigned int status = pbc_rmessage_integer(request, "status", 0, 0);

	WRITE_DEBUG_LOG("service set player %llu status %u", target, status);

	// 权限验证
	if (channel != 0 ) {
		result = RET_PREMISSIONS;
	} else {
		// 获取目标玩家
		struct Player * player = player_get(target);
		if (player == 0) {
			result = RET_CHARACTER_NOT_EXIST;
		} else {
			struct Property * property = player_get_property(player);
			DATA_Property_update_status(property, status);
			result = RET_SUCCESS;
			if (status & PLAYER_STATUS_BAN) {
				kickPlayer(target, LOGOUT_ADMIN_BAN);
			}
		}
	}
	FINI_REQUET_RESPOND(S_SET_PLAYER_STATUS_RESPOND, result);
}

void do_pbc_admin_player_kick(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PAdminPlayerKickRequest", "PAdminPlayerKickRespond"); 

	// 读取参数
	unsigned long long target = (unsigned long long)pbc_rmessage_int64(request, "playerid", 0);

	CHECK_PID_AND_TRANSFORM(target);

	WRITE_DEBUG_LOG("service kick player %llu", target);

	// 权限验证
	if (channel != 0 ) {
		result = RET_PREMISSIONS;
	} else {
		// 获取目标玩家
		struct Player * player = player_get(target);
		if (player == 0) {
			result = RET_CHARACTER_NOT_EXIST;
		} else {
			result = RET_SUCCESS;
			kickPlayer(target, LOGOUT_ADMIN_KICK);
		}
	}
	FINI_REQUET_RESPOND(S_ADMIN_PLAYER_KICK_RESPOND, result);
}

void do_pbc_set_adult(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PAdminSetAdultRequest", "aGameRespond");


	// 读取参数
	unsigned long long pid = (unsigned long long)pbc_rmessage_int64(request, "pid", 0);

	CHECK_PID_AND_TRANSFORM(pid);

	unsigned int isAdult = pbc_rmessage_integer(request, "adult", 0, 0);

	WRITE_DEBUG_LOG("service set player %llu adult %u", pid, isAdult);

	// 权限验证
	if (channel != 0 ) {
		result = RET_PREMISSIONS;
	} else {
		// 获取目标玩家
		result = RET_SUCCESS;
		if (isAdult) {
			addicted_set_adult(pid);
		} else {
			addicted_set_minority(pid);
		}
	}
	FINI_REQUET_RESPOND(S_ADMIN_SET_ADULT_RESPOND, result);
}

static void on_query_item_package(uint64_t key, void *p, void * ctx){
    const int64_t package_id =key;
    PITEM_PACKAGE pkg =(PITEM_PACKAGE)p;
    struct pbc_wmessage* respond =(struct pbc_wmessage*)ctx;

    struct pbc_wmessage* package =pbc_wmessage_message(respond, "package");
    pbc_wmessage_int64(package, "package_id", package_id);

    PITEM node =pkg->item_list;
    while(node){
        struct pbc_wmessage* item =pbc_wmessage_message(package, "item");
        pbc_wmessage_int64(item, "type", node->type);
        pbc_wmessage_int64(item, "id", node->id);
        pbc_wmessage_int64(item, "value", node->value);
        node =node->next;
    }
}

void do_pbc_query_item_package(resid_t conn, uint32_t channel, const char * data, size_t len)
{
    const int res_cmd =S_QUERY_ITEM_PACKAGE_RESPOND;
    INIT_REQUET_RESPOND("QueryItemPackageRequest", "QueryItemPackageRespond");

	do {
		if(channel != 0){
			result = RET_PERMISSION;
			break;
		}

		/// respond
		item_package_foreach(on_query_item_package, respond);
		result =RET_SUCCESS;
	} while (0);

    FINI_REQUET_RESPOND(res_cmd, result);
}

void do_pbc_set_item_package(resid_t conn, uint32_t channel, const char * data, size_t len)
{
    const int res_cmd =S_SET_ITEM_PACKAGE_RESPOND;
    INIT_REQUET_RESPOND("SetItemPackageRequest", "aGameRespond");

	do {
		if(channel != 0){
			result = RET_PERMISSION;
			break;
		}

		/// respond
		set_item_package(request);
		result =RET_SUCCESS;
	} while(0);

    FINI_REQUET_RESPOND(res_cmd, result);
}

void do_pbc_del_item_package(resid_t conn, uint32_t channel, const char * data, size_t len)
{
    const int res_cmd =S_DEL_ITEM_PACKAGE_RESPOND;
    INIT_REQUET_RESPOND("DelItemPackageRequest", "aGameRespond");

	do {
		if(channel != 0){
			result = RET_PERMISSION;
			break;
		}

		/// respond
		const int64_t package_id =pbc_rmessage_int64(request, "package_id", 0);
		del_item_package(package_id);
		result =RET_SUCCESS;
	} while(0);

    FINI_REQUET_RESPOND(res_cmd, result);
}

void do_pbc_query_unactive_ai(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PQueryUnactiveAIRequest", "PQueryUnactiveAIRespond");

	//unsigned long long target = (unsigned long long)pbc_rmessage_int64(request, "playerid", 0);

	WRITE_DEBUG_LOG("service query unactive ai");

	// 权限验证
	if (channel != 0 ) {
		result = RET_PREMISSIONS;
	} else {
		int ref_level = pbc_rmessage_integer(request, "ref_level", 0, 0);
		int ai_level = 0;
		unsigned long long ai_id = QueryUnactiveAI(ref_level, &ai_level);
		if (ai_id > 0) {
			pbc_wmessage_int64(respond, "pid",      ai_id);
			pbc_wmessage_int64(respond, "level",    ai_level);
			result = RET_SUCCESS;
		}
		else {
			result = RET_ERROR;
		}
	}

	FINI_REQUET_RESPOND(S_QUERY_UNACTIVE_AI_RESPOND, result);
}

void do_pbc_update_ai_active_time(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PUpdateAIActiveTimeRequest", "aGameRespond");

	//unsigned long long target = (unsigned long long)pbc_rmessage_int64(request, "playerid", 0);

	WRITE_DEBUG_LOG("service update ai active time");

	// 权限验证
	const int64_t ai = pbc_rmessage_int64(request, "pid", 0);
	unsigned int time = pbc_rmessage_integer(request, "time", 0, 0);
	if (channel != 0 ) {
		result = RET_PREMISSIONS;
	} else {
		int success = UpdateAIActiveTime(ai, time);
		if (success) {
			result = RET_SUCCESS;
		}
		else {
			result = RET_ERROR;
		}
	}

	FINI_REQUET_RESPOND(S_UPDATE_AI_ACTIVE_TIME_RESPOND, result);
}

void do_pbc_change_ai_nick_name(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PChangeAINickNameRequest", "aGameRespond");
	WRITE_DEBUG_LOG("service change ai nick name");

	// 权限验证
	const int64_t ai = pbc_rmessage_int64(request, "pid", 0);
	const char * name = pbc_rmessage_string(request, "name", 0, 0);
	int head = pbc_rmessage_integer(request, "head", 0, 0);
	if (channel != 0 ) {
		result = RET_PREMISSIONS;
	} else {
		struct Player * player = player_get(ai);
		if (player) {
			int ret = aL_change_nick_name(player, name, head, 0);
			if (ret == RET_SUCCESS) {
				result = RET_SUCCESS;
			}
			else {
				result = RET_ERROR;
			}
		} else {
			result = RET_ERROR;
		}
	}

	FINI_REQUET_RESPOND(S_CHANGE_AI_NICK_NAME_RESPOND, result);	
}

void do_pbc_change_buff(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PChangeBuffRequest", "aGameRespond");

	if (channel != 0 ) {
		result = RET_PREMISSIONS;
	} else {
		unsigned long long target = (unsigned long long)pbc_rmessage_int64(request, "pid", 0);
		CHECK_PID_AND_TRANSFORM(target);

		unsigned int add = pbc_rmessage_integer(request, "add", 0, 0);
		unsigned int buff_id = pbc_rmessage_integer(request, "buff_id", 0, 0);
		unsigned int buff_value = pbc_rmessage_integer(request, "buff_value", 0, 0);
		WRITE_DEBUG_LOG("service %s player %llu buff", (add == 1) ? "add" : "remove", target);
		if (add) {
			if (aL_add_buff(target, buff_id, buff_value) != RET_SUCCESS) {
				result = RET_ERROR;
			} else {
				result = RET_SUCCESS;
			}
		} else {
			if (aL_remove_buff(target, buff_id, buff_value) != RET_SUCCESS) {
				result = RET_ERROR;
			} else {
				result = RET_SUCCESS;
			}
		}
	}
	FINI_REQUET_RESPOND(S_CHANGE_BUFF_RESPOND, result);
}

void do_pbc_save_hero_capacity(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PSaveHeroCapacityRequest", "aGameRespond");
	if (channel != 0 ) {
		result = RET_PREMISSIONS;
	} else {
		do {
			unsigned long long target = (unsigned long long)pbc_rmessage_int64(request, "playerid", 0);
			CHECK_PID_AND_TRANSFORM(target);

			struct Player * player = player_get(target);
			int n = pbc_rmessage_size(request, "heros");

			if (!player || n == 0) {
				result = RET_ERROR;
				break;
			}

			struct HeroCapacity list[32];
			memset(list, 0, sizeof(list));
		
			for (int i = 0; i < n; i++) {
				struct pbc_rmessage * hero_cap = pbc_rmessage_message(request, "heros", i);
				unsigned long long hero_uuid = (unsigned long long)pbc_rmessage_int64(hero_cap, "hero_uuid", 0);
				int cap  = pbc_rmessage_integer(hero_cap, "capacity",  0, 0);
				list[i].hero_uuid = hero_uuid;
				list[i].capacity = cap;
			}

			aL_save_hero_capacity_to_check_data(player, list, n);
			result = RET_SUCCESS;			
		} while(0);
		
	}
	FINI_REQUET_RESPOND(S_SAVE_HERO_CAPACITY_RESPOND, result);
}

void do_pbc_query_server_info(resid_t conn, unsigned long long channel, const char * data, size_t len) 
{
	INIT_REQUET_RESPOND("ServerInfoRequest", "ServerInfoRespond");
	if (channel != 0) {
		result = RET_PERMISSION;
	} else {
		result = RET_SUCCESS;	
		int level = getMaxPlayerLevel();
		pbc_wmessage_int64(respond, "max_level", level);
	}

	FINI_REQUET_RESPOND(S_GET_SERVER_INFO_RESPOND, result);
}

void do_pbc_trade_with_system(resid_t conn, unsigned long long channel, const char * data, size_t len) 
{
	INIT_REQUET_RESPOND("TradeWithSystemRequest", "TradeWithSystemRespond");
	unsigned long long pid = (unsigned long long)pbc_rmessage_int64(request, "pid", 0);
	unsigned long long sell = pbc_rmessage_integer(request, "sell", 0, 0);
	unsigned long long equip_uuid = (unsigned long long)pbc_rmessage_int64(request, "equip_uuid", 0);
	unsigned int equip_gid = pbc_rmessage_integer(request, "equip_gid", 0, 0);
	do {
		if (channel != 0) {
			result = RET_PERMISSION;
			break;
		} 

		Player * trader = player_get(pid);
		if (!trader) {
			result = RET_ERROR;	
			break;
		}

		struct RewardItem consume [20];
		memset(consume, 0, sizeof(consume));

		int n = pbc_rmessage_size(request, "consume") > 20 ? 20 : pbc_rmessage_size(request, "consume");
		for(int i = 0; i < n; i++) {
			struct pbc_rmessage * cost = pbc_rmessage_message(request, "consume", i);
			unsigned int type  = pbc_rmessage_integer(cost, "type",  0, 0);
			unsigned int id    = pbc_rmessage_integer(cost, "id",    0, 0);
			unsigned int value = pbc_rmessage_integer(cost, "value", 0, 0);
			consume[i].type = type;
			consume[i].id = id;
			consume[i].value = value;
		}

		int level = 0;
		int quality = 0;
		int uuid = 0;
		if (sell) {
			Player * player = player_get(pid);
			if (player) {
				Equip * equip = equip_get(player, equip_uuid);
				if (equip == 0) {
					WRITE_DEBUG_LOG(" equip %llu not exist", equip_uuid);
					result = RET_NOT_EXIST;
					break;
				}

				level = equip->level;
				uuid = equip->uuid;
				EquipConfig * cfg = get_equip_config(equip->gid);
				if (cfg) {
					quality = cfg->quality;
				}
			}
		}

		if (sell) {
			result = aL_equip_sell_to_system(trader, equip_gid, equip_uuid, consume, n, REASON_TRADE);
		} else {
			result = aL_equip_buy_from_system(trader, equip_gid, equip_uuid, consume, n, REASON_TRADE);
		}

		if (result == RET_SUCCESS) {
			pbc_wmessage_integer(respond, "level", level, 0);
			pbc_wmessage_integer(respond, "quality", quality, 0);
			pbc_wmessage_integer(respond, "uuid", uuid, 0);
		}
	} while(0);

	FINI_REQUET_RESPOND(S_TRADE_WITH_SYSTEM_RESPOND, result);
}
