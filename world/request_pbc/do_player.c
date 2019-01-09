#include <assert.h>
#include <string.h>

#include "network.h"
#include "log.h"
#include "message.h"
#include "player.h"
#include "package.h"
#include "mtime.h"
#include "build_message.h"
#include "dlist.h"

#include "logic/aL.h"
#include "protocol.h"
#include "do.h"
#include "config.h"
#include "modules/hero.h"
#include "modules/equip.h"
#include "modules/reward.h"
#include "modules/hero_item.h"
#include "config/hero.h"
#include "config/equip.h"
#include "config/fight.h"
#include "calc/calc.h"
#include "aifightdata.h"
#include "config/openlv.h"
#include "config/fashion.h"
/*
static void pbc_wmessage_int64(struct pbc_wmessage * msg, const char * key, int64_t value)
{
	uint32_t low = 0, hi = 0;
    uint64_t u = (uint64_t)value;
    hi = u >> 32;
    low = u & 0xffffffff;
    pbc_wmessage_integer(msg, key, low, hi);
}
*/


/*
static int64_t pbc_rmessage_int64(struct pbc_rmessage * msg, const char * key, int idx)
{
	uint32_t low, hi;
	int64_t value;
    low = pbc_rmessage_integer(msg, key, idx, &hi);
 
    value = (((uint64_t)hi&0x7fffffff)<<32)|low;
    if (hi&0x80000000) {
        value = -value;
    }
    return value;
}
*/

struct HeroList {
	unsigned long long role_id;
	int role_type;
	int role_lv;
};


static void build_player_pbc_message(Player * player, struct pbc_wmessage * respond)
{
	Property * property = player_get_property(player);
    pbc_wmessage_int64  (respond, "pid",     property->pid);
    pbc_wmessage_string (respond, "name",    property->name, 0);
    pbc_wmessage_integer(respond, "create",  property->create, 0);
}


void do_pbc_query_player(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("QueryPlayerRequest", "QueryPlayerRespond");

	unsigned long long id = (unsigned long long)pbc_rmessage_real(request, "id", 0);

	if (id == 0) id = channel;

	CHECK_PID_AND_TRANSFORM(id);

	WRITE_INFO_LOG("player %llu query player %llu", channel, id);

	struct Player * player = player_get(id);

	if (player == 0) {
		result = RET_CHARACTER_NOT_EXIST;
	} else {
		result = RET_SUCCESS;
		build_player_pbc_message(player, respond);
	}

	FINI_REQUET_RESPOND(C_QUERY_PLAYER_RESPOND, result);
}


/*
void do_pbc_create_player(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("CreatePlayerRequest", "aGameRespond");

	READ_STR(name);

	int head = LEADING_ROLE;

	WRITE_INFO_LOG("create player %llu %s", channel, name);

	struct Player * player = player_get(channel);
	if (player) {
		result = RET_CHARACTER_EXIST;
		WRITE_WARNING_LOG("    failed: exist");
	} else {
		if (name == 0 || name[0] == 0) {
			result = RET_ERROR;
		} else {
			result = aL_create_player(channel, name, head);
			if (result == RET_SUCCESS) {
				player = player_get(channel);
				build_player_pbc_message(player, respond);
			}
		}
	}
	FINI_REQUET_RESPOND(C_CREATE_PLAYER_RESPOND, result);
	return;
}

void do_pbc_set_country(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("UnloadPlayerRequest", "aGameRespond");
	unsigned long long playerid = (unsigned long long)pbc_rmessage_real(request, "playerid", 0);
	WRITE_INFO_LOG("unload player %llu", (unsigned long long)playerid);
	struct Player * player = player_get(playerid);
	if (player) {
		player_unload(player);
	}
	result =RET_SUCCESS;
	FINI_REQUET_RESPOND(S_UNLOAD_PLAYER_RESPOND, result);
}
*/


static void fill_player_role_fight_data(struct pbc_wmessage * role, int pos, struct Player * player, struct Hero * hero, struct HeroConfig * cfg, int ref)
{
	pbc_wmessage_integer(role, "refid", ref,     0);

	pbc_wmessage_integer(role, "id",    hero->gid,   0);
	pbc_wmessage_integer(role, "mode",  cfg->mode,   0);
	/* 先穿一个默认的 */
	Fashion * cfgs = get_fashion_cfgs(hero->gid);
	while (cfgs) {
		if (cfgs->item == 0) {
			pbc_wmessage_integer(role, "mode", cfgs->fashion_id, 0);
		}
		cfgs = cfgs->next;
	}

	/* 如果英雄穿戴了时装，则替换mode为fashion_id */
	struct HeroItem * hero_item = NULL;
	while ( (hero_item = hero_item_next(player, hero_item)) != NULL ) {
		if (hero->uuid == hero_item->uid && hero_item->status == 1) {				
			Fashion * f = get_fashion_by_item(hero->gid, hero_item->id);
			if (f) {
				pbc_wmessage_integer(role, "mode", f->fashion_id, 0);	
				break;
			}
		}
	}

	pbc_wmessage_integer(role, "level", hero->level, 0);

/*
    int level = pbc_rmessage_integer(rrole, "level", 0, 0);
    if (id == 11000) {
        pbc_wmessage_integer(role, "level", player_get_level(player);, 0);
    } else {
        pbc_wmessage_integer(role, "level", level, 0);
    }
*/

	pbc_wmessage_integer(role, "pos",   pos,         0);
	pbc_wmessage_integer(role, "wave",  1,           0);

	pbc_wmessage_int64  (role, "uuid",  hero->uuid);

	struct CommonProperty * property = calc_hero_property(hero, 0);
	struct CommonProperty * ite;
	for (ite = property; ite; ite = ite->next) {
		struct pbc_wmessage * p = pbc_wmessage_message(role, "propertys");
		pbc_wmessage_integer(p, "type", ite->type, 0);
		pbc_wmessage_integer(p, "value", ite->value, 0);
	}
	release_hero_property(property);

	int j;
	struct WeaponConfig * wcfg = get_weapon_config(cfg->weapon);
	if (wcfg) {

		struct HeroSkill * skill = hero_get_selected_skill(player, hero->uuid);
		if(skill) {
			// use select skill instead weapon skill
			pbc_wmessage_integer(role, "skills", skill->skill1, 0);
			pbc_wmessage_integer(role, "skills", skill->skill2, 0);
			pbc_wmessage_integer(role, "skills", skill->skill3, 0);
			pbc_wmessage_integer(role, "skills", skill->skill4, 0);
			pbc_wmessage_integer(role, "skills", skill->skill5, 0);
			pbc_wmessage_integer(role, "skills", skill->skill6, 0);
		} else {
			for (j = 0; j < HERO_WEAPON_SKILL_COUNT; j++) {
				pbc_wmessage_integer(role, "skills", wcfg->skills[j], 0);
			}
		}

		for (j = 0; j < HERO_WEAPON_ASSIST_SKILL_COUNT; j++) {
			struct pbc_wmessage * asset_skills = pbc_wmessage_message(role, "assist_skills");
			pbc_wmessage_integer(asset_skills, "id", wcfg->assist_skills[j].id, 0);
			pbc_wmessage_integer(asset_skills, "weight", wcfg->assist_skills[j].weight, 0);
		}

		pbc_wmessage_integer(role, "assist_cd", wcfg->assist_cd, 0);
	}

	for (j = 0; j < EQUIP_INTO_BATTLE_MAX; j++) {
		struct Equip * equip = equip_get_by_hero(player, hero->uuid, j);
		pbc_wmessage_integer(role, "equips", equip ? equip->gid : 0, 0);
	}

	pbc_wmessage_integer(role, "grow_stage", hero->stage, 0);
	pbc_wmessage_integer(role, "grow_star",  hero->star,  0);
}

static void fill_ai_role_fight_data(struct pbc_wmessage * role, int pos, struct Player * player, struct Hero * hero, struct HeroConfig * cfg, int ref, struct pbc_rmessage * rrole)
{
	pbc_wmessage_integer(role, "refid", ref,     0);

	pbc_wmessage_integer(role, "id",    hero->gid,   0);
	pbc_wmessage_integer(role, "mode",  cfg->mode,   0);	
	/* 先穿一个默认的 */
	Fashion * cfgs = get_fashion_cfgs(hero->gid);
	while (cfgs) {
		if (cfgs->item == 0) {
			pbc_wmessage_integer(role, "mode", cfgs->fashion_id, 0);
		}
		cfgs = cfgs->next;
	}

	/* 如果英雄穿戴了时装，则替换mode为fashion_id */
	struct HeroItem * hero_item = NULL;
	while ( (hero_item = hero_item_next(player, hero_item)) != NULL ) {
		if (hero->uuid == hero_item->uid && hero_item->status == 1) {				
			Fashion * f = get_fashion_by_item(hero->gid, hero_item->id);
			if (f) {
				pbc_wmessage_integer(role, "mode", f->fashion_id, 0);
				break;	
			}
		}
	}

	pbc_wmessage_integer(role, "level", hero->level, 0);

    if (hero->gid == LEADING_ROLE) {
        pbc_wmessage_integer(role, "level", player_get_level(player), 0);
	}

	pbc_wmessage_integer(role, "pos",   pos,         0);
	pbc_wmessage_integer(role, "wave",  1,           0);
	pbc_wmessage_int64  (role, "uuid",  hero->uuid);

	// property
	int i;
	for (i = 0; i < pbc_rmessage_size(rrole, "propertys"); i++) {
		struct pbc_wmessage * p = pbc_wmessage_message(role, "propertys");
    	struct pbc_rmessage * rp = pbc_rmessage_message(rrole, "propertys", i);
		int type = pbc_rmessage_integer(rp, "type", 0, 0);
		int value = pbc_rmessage_integer(rp, "value", 0, 0);
		pbc_wmessage_integer(p, "type", type, 0);
		pbc_wmessage_integer(p, "value", value, 0);

	}

	//weapon
	for (i = 0; i < pbc_rmessage_size(rrole, "skills"); i++) {
		int skills = pbc_rmessage_integer(rrole, "skills", i, 0);
		pbc_wmessage_integer(role, "skills", skills, 0);
	}

	//equip
	for (i = 0; i < pbc_rmessage_size(rrole, "equipss"); i++) {
	    int equips = pbc_rmessage_integer(rrole, "equips", i, 0);
		pbc_wmessage_integer(role, "equips", equips, 0);
	}
	

	pbc_wmessage_integer(role, "grow_stage", hero->stage, 0);
	pbc_wmessage_integer(role, "grow_star",  hero->star,  0);
}


static void fill_recommend_fight_data(struct pbc_wmessage * msg, struct Player * player, int ref, struct HeroList * heros, unsigned long long * assists, int nassists)
{
	pbc_wmessage_int64(msg, "pid", player_get_id(player));
	pbc_wmessage_string(msg, "name", player_get_name(player), 0);
	pbc_wmessage_integer(msg, "npc", 0, 0);
	pbc_wmessage_integer(msg, "level", player_get_level(player), 0);

	int i;
	for (i = 0; i < HERO_INTO_BATTLE_MAX; i++) {
		if (heros[i].role_type == 2) {
			struct Hero * hero = 0;
			if (heros) {
				hero = hero_get(player, 0, heros[i].role_id);
			} else {
				hero = hero_get_by_pos(player, i+1);
			}

			if (hero == 0) {
				continue;
			}

			struct HeroConfig * cfg = get_hero_config(hero->gid);
			if (cfg == 0) {
				continue;
			}

			struct pbc_wmessage * role = pbc_wmessage_message(msg, "roles");
			fill_player_role_fight_data(role, i + 1, player, hero, cfg, ref + i + 1);
		} else if (heros[i].role_type == 1) {
				struct NpcConfig * npc = get_npc_config(heros[i].role_id);
				if (npc == 0) {
					continue;
				}

				struct HeroProperty propertys[NPC_PROPERTY_COUNT*2];
				if (get_npc_property_config(npc->property_id, heros[i].role_lv, propertys) != 0) {
					continue;
				}

				struct pbc_wmessage * role = pbc_wmessage_message(msg, "roles");
				pbc_wmessage_integer(role, "refid", ref + i + 1,     0);

				pbc_wmessage_integer(role, "id",    npc->id,   0);
				pbc_wmessage_integer(role, "mode",  npc->mode,   0);		
				/* 先穿一个默认的 */
				Fashion * cfgs = get_fashion_cfgs(heros[i].role_id);
				while (cfgs) {
					if (cfgs->item == 0) {
						pbc_wmessage_integer(role, "mode", cfgs->fashion_id, 0);
					}
					cfgs = cfgs->next;
				}

				pbc_wmessage_integer(role, "level", heros[i].role_lv ? heros[i].role_lv : 0, 0);


				pbc_wmessage_integer(role, "pos",   i + 1,         0);
				pbc_wmessage_integer(role, "wave",  1,             0);

				int i;
				for (i = 0; i < NPC_SKILL_COUNT; i++) {
					pbc_wmessage_integer(role, "skills", npc->skills[i], 0);
				}

				for (i = NPC_SKILL_COUNT; i < 4; i++) {
					pbc_wmessage_integer(role, "skills", 0, 0);
				}

				pbc_wmessage_integer(role, "skills", npc->enter_script, 0); // enter script

				for (i = 0; i < NPC_PROPERTY_COUNT*2; i++) {
					if (propertys[i].type != 0 && propertys[i].value != 0) {
						struct pbc_wmessage * p = pbc_wmessage_message(role, "propertys");
						pbc_wmessage_integer(p, "type", propertys[i].type, 0);
						pbc_wmessage_integer(p, "value", propertys[i].value, 0);
					}
				}
		} else if (heros[i].role_type == 0) {
			struct Hero * hero = 0;
			if (heros) {
				hero = hero_get(player, 0, heros[i].role_id);
			} else {
				hero = hero_get_by_pos(player, i+1);
			}

			if (hero == 0) {
				continue;
			}

			struct HeroConfig * cfg = get_hero_config(hero->gid);
			if (cfg == 0) {
				continue;
			}

			struct pbc_wmessage * role = pbc_wmessage_message(msg, "roles");
			fill_player_role_fight_data(role, i + 1, player, hero, cfg, ref + i + 1);
		} else {
			continue;
		}
	}


	for (i = 0; i < nassists; i++) {
		struct Hero * hero = hero_get(player, 0, assists[i]);
		if (hero == 0) {
			continue;
		}

		struct HeroConfig * cfg = get_hero_config(hero->gid);
		if (cfg == 0) {
			continue;
		}

		struct pbc_wmessage * role = pbc_wmessage_message(msg, "assists");
		fill_player_role_fight_data(role, i + 101, player, hero, cfg, ref + HERO_INTO_BATTLE_MAX + i + 1);
	}
}

static int build_hero_list(Player * player, unsigned long long * target_heros, int nheros, struct HeroList * heros, struct PVE_FightRecommendConfig * cfg) {
	int success = 1;
	int i;	
	int j = 0;

	for (i = 0; i < HERO_INTO_BATTLE_MAX; i++) {
		if (cfg->roles[i].role_type == 1) {
			heros[i].role_type = cfg->roles[i].role_type;
			heros[i].role_id = cfg->roles[i].role_id;
			heros[i].role_lv = cfg->roles[i].role_lv;
		} else if (cfg->roles[i].role_type == 2) {
			heros[i].role_type = cfg->roles[i].role_type;
			if (nheros == 0) {
				struct Hero * hero = 0;
				hero = hero_get(player, cfg->roles[i].role_id, 0);
				if (!hero) {
					WRITE_DEBUG_LOG(" donnt has hero gid:%d", cfg->roles[i].role_id);
					success = 0;
					break;
				}
				heros[i].role_id = hero->uuid;
			} else {
				unsigned long long target_hero_id = 0;
				int idx = 0;
				for (idx = j; idx < HERO_INTO_BATTLE_MAX; idx++) {
					if (target_heros[idx] != 0) {
						target_hero_id = target_heros[idx];
						j = idx + 1;
						break;
					}	
				}
				if (target_hero_id == 0) {
					WRITE_DEBUG_LOG("target hero not enough");
					success = 1;
					break;
				}
				
				struct Hero * hero = 0;
				hero = hero_get(player, 0, target_hero_id);
				if (!hero) {
					WRITE_DEBUG_LOG("donnt has hero uuid:%llu", target_hero_id);
					success = 1;
					break;
				}
				if (hero->gid != (unsigned int)cfg->roles[i].role_id) {
					WRITE_DEBUG_LOG("not the right hero");
					success = 1;
					break;
				}
				heros[i].role_id = target_hero_id;	
			}
		} else if (cfg->roles[i].role_type == 0){
			heros[i].role_type = cfg->roles[i].role_type;
			if (nheros == 0) {
				WRITE_DEBUG_LOG(" client donnt send target hero");
				struct Hero * hero = hero_get_by_pos(player, i+1);
                if (hero) {
                    heros[i].role_id = hero->uuid;
                }
				continue;
				/*success = 0;
				break;*/
			}
			unsigned long long target_hero_id = 0;
			int idx = 0;
			for (idx = j; idx < HERO_INTO_BATTLE_MAX; idx++) {
				if (target_heros[idx] != 0) {
					target_hero_id = target_heros[idx];
					j = idx + 1;
					break;
				}	
			}
			if (target_hero_id == 0) {
				WRITE_DEBUG_LOG("target hero not enough");
				continue;
				/*success = 0;
				break;*/
			} else {
				heros[i].role_id = target_hero_id;
			}
		} else {
			continue;
		}
	} 
	
	return success;
}


void fill_player_fight_data(struct pbc_wmessage * msg, struct Player * player, int ref, unsigned long long * heros, unsigned long long * assists, int nassists)
{
	pbc_wmessage_int64(msg, "pid", player_get_id(player));
	pbc_wmessage_string(msg, "name", player_get_name(player), 0);
	pbc_wmessage_integer(msg, "npc", 0, 0);
	pbc_wmessage_integer(msg, "level", player_get_level(player), 0);

	// AI:
  	 
	if (player_get_id(player) <= AI_MAX_ID)
    {
        struct pbc_rmessage * ai_data = getAIFightData(player);//player->check.fight_data;
		
		if (!ai_data) {
			WRITE_DEBUG_LOG("cannt get ai fight_data");
			struct Hero * hero = 0;
			hero = hero_get(player, LEADING_ROLE, 0);
			struct HeroConfig * cfg = get_hero_config(LEADING_ROLE);
			if (hero && cfg) {
				struct pbc_wmessage * role = pbc_wmessage_message(msg, "roles");
				fill_player_role_fight_data(role, 1, player, hero, cfg, ref + 1);
			}
			return;
		}

		int i;
        for (i = 0; i < pbc_rmessage_size(ai_data, "roles"); i++) {
			//TODO
            struct pbc_rmessage * rrole = pbc_rmessage_message(ai_data, "roles", i);
			
			struct Hero hero = {0};
			hero.pid = pbc_rmessage_integer(rrole, "pid", 0 ,0);
			hero.gid = pbc_rmessage_integer(rrole, "id", 0 ,0);
			hero.uuid = i + 1;//pbc_rmessage_int64(rrole, "uuid", 0);
			hero.level = pbc_rmessage_integer(rrole, "level", 0 ,0);
			hero.stage = pbc_rmessage_integer(rrole, "stage", 0 ,0);
			hero.star = pbc_rmessage_integer(rrole, "star", 0 ,0);
			
			struct HeroConfig * cfg = get_hero_config(hero.gid);
			if (cfg == 0) {
				continue;
			}

			struct pbc_wmessage * role = pbc_wmessage_message(msg, "roles");
            fill_ai_role_fight_data(role, i + 1, player, &hero, cfg, ref + i + 1, rrole);

        }

        return;
    }
    


	int i;
	for (i = 0; i < HERO_INTO_BATTLE_MAX; i++) {
		struct Hero * hero = 0;
		if (heros) {
			hero = hero_get(player, 0, heros[i]);
		} else {
			hero = hero_get_by_pos(player, i+1);
		}

		if (hero == 0) {
			continue;
		}

		struct HeroConfig * cfg = get_hero_config(hero->gid);
		if (cfg == 0) {
			continue;
		}

		struct pbc_wmessage * role = pbc_wmessage_message(msg, "roles");
		fill_player_role_fight_data(role, i + 1, player, hero, cfg, ref + i + 1);
	}


	for (i = 0; i < nassists; i++) {
		struct Hero * hero = hero_get(player, 0, assists[i]);
		if (hero == 0) {
			continue;
		}

		struct HeroConfig * cfg = get_hero_config(hero->gid);
		if (cfg == 0) {
			continue;
		}

		struct pbc_wmessage * role = pbc_wmessage_message(msg, "assists");
		fill_player_role_fight_data(role, i + 101, player, hero, cfg, ref + HERO_INTO_BATTLE_MAX + i + 1);
	}
}


static void fill_npc_fight_data(struct pbc_wmessage * msg, struct WaveConfig * head, int ref, int player_level)
{
	pbc_wmessage_int64(msg, "pid", head->gid);

	char name[64];
	sprintf(name, "npc_%d", head->gid);
	pbc_wmessage_string(msg, "name", name, 0);

	pbc_wmessage_integer(msg, "npc", 1, 0);

	int lev = 0;

	int ref_base = 0;
	struct WaveConfig * wave = 0;
	while((wave = dlist_next(head, wave)) != 0) {
		ref_base ++;
		struct NpcConfig * npc = get_npc_config(wave->role_id);
		if (npc == 0) {
			continue;
		}

		int role_level = wave->role_lev ? wave->role_lev : player_level;
		if (lev < role_level) {
			lev = role_level;
		}

		struct HeroProperty propertys[NPC_PROPERTY_COUNT*2];
		if (get_npc_property_config(npc->property_id, role_level, propertys) != 0) {
			continue;
		}

		struct pbc_wmessage * role = pbc_wmessage_message(msg, "roles");
		pbc_wmessage_integer(role, "refid", ref+ref_base,     0);

		pbc_wmessage_integer(role, "id",    npc->id,   0);
		pbc_wmessage_integer(role, "level", role_level, 0);


		pbc_wmessage_integer(role, "pos",   wave->role_pos,         0);
		pbc_wmessage_integer(role, "wave",  wave->wave,             0);

		if (wave->x != 0) pbc_wmessage_real(role,    "x",     wave->x);
		if (wave->y != 0) pbc_wmessage_real(role,    "y",     wave->y);
		if (wave->z != 0) pbc_wmessage_real(role,    "z",     wave->z);

		pbc_wmessage_integer(role, "mode",  npc->mode,   0);
		/* 先穿一个默认的 */
		Fashion * cfgs = get_fashion_cfgs(wave->role_id);
		while (cfgs) {
			if (cfgs->item == 0) {
				pbc_wmessage_integer(role, "mode", cfgs->fashion_id, 0);
			}
			cfgs = cfgs->next;
		}

		pbc_wmessage_integer(role, "share_mode",  wave->share_mode,   0);
		pbc_wmessage_integer(role, "share_count",  wave->share_count,   0);

		int i;
		for (i = 0; i < NPC_SKILL_COUNT; i++) {
			pbc_wmessage_integer(role, "skills", npc->skills[i], 0);
		}

		for (i = NPC_SKILL_COUNT; i < 4; i++) {
			pbc_wmessage_integer(role, "skills", 0, 0);
		}

		pbc_wmessage_integer(role, "skills", npc->enter_script, 0); // enter script

		for (i = 0; i < NPC_PROPERTY_COUNT*2; i++) {
			if (propertys[i].type != 0 && propertys[i].value != 0) {
				struct pbc_wmessage * p = pbc_wmessage_message(role, "propertys");
				pbc_wmessage_integer(p, "type", propertys[i].type, 0);
				pbc_wmessage_integer(p, "value", propertys[i].value, 0);
			}
		}
	}

	pbc_wmessage_integer(msg, "level", lev, 0);
}

static int read_heros_and_assists(unsigned long long pid, struct pbc_rmessage * msg, unsigned long long heros[HERO_INTO_BATTLE_MAX], int * nheros, unsigned long long assists[], int * nassists)
{
	*nheros = pbc_rmessage_size(msg, "heros");
	int i;
	for (i = 0; i < *nheros && i < HERO_INTO_BATTLE_MAX; i++) {
		heros[i] = pbc_rmessage_int64(msg, "heros", i);
	}

	int assists_count = 0;

	assists_count = pbc_rmessage_size(msg, "assists");
	if (assists_count > *nassists) { assists_count = *nassists; }
	
	/* 获得可援助的位置 */	
	OpenLevCofig * config1 = get_openlev_config(ROLE_ASSIST_INDEX + 0);
	int open_lv1 = config1 ? config1->open_lev : 0;

	OpenLevCofig * config2 = get_openlev_config(ROLE_ASSIST_INDEX + 1);
	int open_lv2 = config2 ? config2->open_lev : 0;

	OpenLevCofig * config3 = get_openlev_config(ROLE_ASSIST_INDEX + 2);
	int open_lv3 = config3 ? config3->open_lev : 0;

	OpenLevCofig * config4 = get_openlev_config(ROLE_ASSIST_INDEX + 3);
	int open_lv4 = config4 ? config4->open_lev : 0;

	OpenLevCofig * config5 = get_openlev_config(ROLE_ASSIST_INDEX + 4);
	int open_lv5 = config5 ? config5->open_lev : 0;
	
	Player *player = player_get(pid);		
	int level = player_get_level(player);
	if (level < open_lv1 && assists_count > 0) {
		assists_count = 0;	
	} else if (level < open_lv2 && assists_count > 1) {
		assists_count = 1;
	} else if (level < open_lv3 && assists_count > 2) {
		assists_count = 2;
	} else if (level < open_lv4 && assists_count > 3) {
		assists_count = 3;
	} else if (level < open_lv5 && assists_count > 4) {
		assists_count = 4;
	} else if (assists_count > 5) {	
		assists_count = 5;
	}
	
	for (i = 0; i < assists_count; i++) {
		assists[i] = pbc_rmessage_int64(msg, "assists", i);
	}

	*nassists = assists_count;

	int j;
	for (i = 0; i < HERO_INTO_BATTLE_MAX + assists_count; i++) {
		for (j = i + 1; j < HERO_INTO_BATTLE_MAX + assists_count; j++) {
			unsigned long long u1 = (i < HERO_INTO_BATTLE_MAX) ? heros[i] : assists[i-HERO_INTO_BATTLE_MAX];
			unsigned long long u2 = (j < HERO_INTO_BATTLE_MAX) ? heros[j] : assists[j-HERO_INTO_BATTLE_MAX];
			if (u1 && u2 && u1 == u2) {
				WRITE_DEBUG_LOG("  read_heros_and_assists failed, duplicate hero %llu", u1);
				return -1;
			}
		}
	}

	return 0;
}


void do_pbc_query_player_fight_info(resid_t conn, unsigned long long channel, const char * data, size_t len) {
	INIT_REQUET_RESPOND("QueryPlayerFightInfoRequest", "QueryPlayerFightInfoRespond");


	READ_INT64(pid);
	READ_INT(npc);
	READ_INT(ref);
	READ_INT(level);
	READ_INT(target_fight);

	WRITE_DEBUG_LOG("query %s fight data %llu, level %d, target_fight %d", npc ? "npc" : "player", pid, level, target_fight)

	do {
		if (npc) {
			READ_INT64(check_player_id);
			if (check_player_id > 0) {
				struct Player * player = player_get(check_player_id);
				if (player == 0) {
					WRITE_DEBUG_LOG("  check player %llu not exists", check_player_id);
					result = RET_ERROR;
					break;
				}

				if (aL_pve_fight_is_open(player, check_player_id) != RET_SUCCESS) {
					result = RET_PREMISSIONS;
					WRITE_DEBUG_LOG("  fight %llu of player %llu not open", pid, check_player_id);
					break;
				}
			}


			struct WaveConfig * head = get_wave_config(pid);
			if (head == 0) {
				result = RET_NOT_EXIST;
				WRITE_DEBUG_LOG("  wave config %llu not open", pid);
				break;
			}

			result = RET_SUCCESS;

			if (level < 0) {
				level = 1;
			}

/*
			if (level < 0) {
				WRITE_DEBUG_LOG("level < 0");
				result = RET_ERROR;
				break;
			}
		
			if (level == 0) {
				struct Player * player = player_get(pid);
				if (player == 0) {
					result = RET_NOT_EXIST;	
					break;
				}

				level = player_get_level(player);
			}
*/

			struct pbc_wmessage * msg = pbc_wmessage_message(respond, "player");
			fill_npc_fight_data(msg, head, ref, level); // player_get_level(player));

		} else {
			struct Player * player = player_get(pid);
			if (player == 0) {
				result = RET_NOT_EXIST;
				break;
			} 

			result = RET_SUCCESS;
			struct pbc_wmessage * msg = pbc_wmessage_message(respond, "player");

			unsigned long long heros[HERO_INTO_BATTLE_MAX] = {0};
			int nheros = 0;

			unsigned long long assists[64] = {0};
			int nassists = 64;

			if (read_heros_and_assists(pid, request, heros, &nheros, assists, &nassists) != 0) {
				result = RET_ERROR;
				break;
			}

			struct PVE_FightRecommendConfig * rcfg = target_fight ? get_pve_fight_recommend_config(target_fight) : 0;
			if (rcfg) {
				WRITE_DEBUG_LOG("  fight %d is recommend fight", target_fight);

				struct HeroList herolist[HERO_INTO_BATTLE_MAX];
				memset(herolist, 0, sizeof(herolist));
				if (!build_hero_list(player, heros, nheros, herolist, rcfg)) {
					result = RET_ERROR;
					break;
				}
				fill_recommend_fight_data(msg, player, ref, herolist, assists, nassists);
			} else {
				fill_player_fight_data(msg, player, ref, nheros ? heros : 0, assists, nassists);
			}
		}
	} while(0);

	FINI_REQUET_RESPOND(S_QUERY_PLAYER_FIGHT_INFO_RESPOND, result);
}

void do_pbc_player_fight_prepare(resid_t conn, unsigned long long channel, const char * data, size_t len) 
{
	INIT_REQUET_RESPOND("PlayerFightPrepareRequest", "PlayerFightPrepareRespond");

	READ_INT64(pid);
	READ_INT(fightid);

	WRITE_DEBUG_LOG("player %lld prepare fight data %d", pid, fightid)

	do {
		struct Player * player = player_get(pid);
		if (player == 0) {
			WRITE_DEBUG_LOG("  check player %llu not exists", pid);
			result = RET_ERROR;
			break;
		}

		struct PVE_FightConfig * pCfg = get_pve_fight_config(fightid);
		result = pCfg ? aL_pve_fight_prepare(player, fightid, 0, 0, 0) : RET_SUCCESS; // check depend only pve fight config exists

		if (result != RET_SUCCESS) {
			WRITE_DEBUG_LOG("  prepare failed");
			break;
		}

		struct pbc_wmessage * fight_data = pbc_wmessage_message(respond, "fight_data");

		unsigned long long heros[HERO_INTO_BATTLE_MAX] = {0};
		int nheros = 0;

		unsigned long long assists[64] = {0};
		int nassists = 64;

		if (read_heros_and_assists(pid, request, heros, &nheros, assists, &nassists) != 0) {
			result = RET_ERROR;
			break;
		}
			
		checkAndAddAIFightData(player);

		struct PVE_FightRecommendConfig * rcfg = get_pve_fight_recommend_config(fightid);
		if (rcfg) {
			WRITE_DEBUG_LOG("this fight %d is recommend fight", fightid);

			struct HeroList herolist[HERO_INTO_BATTLE_MAX];
			memset(herolist, 0, sizeof(herolist));
			if (!build_hero_list(player, heros, nheros, herolist, rcfg)) {
				result = RET_ERROR;
				break;
			}
			fill_recommend_fight_data(pbc_wmessage_message(fight_data, "attacker"), player, 0, herolist, assists, nassists);
		} else {
			fill_player_fight_data(pbc_wmessage_message(fight_data, "attacker"), player, 0, nheros ? heros : 0, assists, nassists);
		}

		struct WaveConfig * head = get_wave_config(fightid);
		if (head == 0) {
			WRITE_ERROR_LOG("fight wave config %d not exists", fightid);
			result = RET_ERROR;
			break;
		}
		fill_npc_fight_data(pbc_wmessage_message(fight_data, "defender"), head, 100, player_get_level(player));

		struct PVE_FightConfig * fight = get_pve_fight_config(fightid);
		if (fight) {
			pbc_wmessage_string(fight_data, "scene", fight->scene, 0);
			pbc_wmessage_integer(fight_data, "fight_type", fight->fight_type, 0);
			pbc_wmessage_integer(fight_data, "win_type", fight->win_type, 0);
			pbc_wmessage_integer(fight_data, "win_para", fight->win_para, 0);
			pbc_wmessage_integer(fight_data, "duration", fight->duration, 0);

			for (int i = 0; i < PVE_STAR_LIMIT_COUNT; i++) {
				if (fight->star[i].type != 0) {
					struct pbc_wmessage * star = pbc_wmessage_message(fight_data, "star");
					pbc_wmessage_integer(star, "type", fight->star[i].type, 0);
					pbc_wmessage_integer(star, "v1", fight->star[i].v1, 0);
					pbc_wmessage_integer(star, "v2", fight->star[i].v2, 0);
				}
			}
		}
	} while (0);

	FINI_REQUET_RESPOND(S_PLAYER_FIGHT_PREPARE_RESPOND, result);
}
					
void do_pbc_player_fight_confirm(resid_t conn, unsigned long long channel, const char * data, size_t len) 
{
	INIT_REQUET_RESPOND("PlayerFightConfirmRequest", "PlayerFightConfirmRespond");

	READ_INT64(pid);
	READ_INT(fightid);
	READ_INT(star);

	WRITE_DEBUG_LOG("player %lld confirm fight data %d", pid, fightid)

	do {
		if (channel != 0 ) {
			WRITE_DEBUG_LOG("  channel(%llu) ~= 0", channel);
			result = RET_PREMISSIONS;
			break;
		}

		struct Player * player = player_get(pid);
		if (player == 0) {
			WRITE_DEBUG_LOG("  check player %llu not exists", pid);
			result = RET_ERROR;
			break;
		}

		struct RewardItem rewards [20];
		memset(rewards, 0, sizeof(rewards));

		unsigned long long heros[HERO_INTO_BATTLE_MAX] = {0};

		int i, nhero = pbc_rmessage_size(request, "heros");
		if (nhero > HERO_INTO_BATTLE_MAX) {
			nhero = HERO_INTO_BATTLE_MAX;
		}

		for (i = 0; i < nhero; i++) {
			heros[i] = pbc_rmessage_int64(request, "heros", i);	
		}

		result = aL_pve_fight_confirm(player, fightid, star, heros, nhero, rewards, 20);
		if (result == RET_SUCCESS) {
			for (i = 0; i < 20; i++) {
				if (rewards[i].type != 0) {
					struct pbc_wmessage * r = pbc_wmessage_message(respond, "rewards");
					pbc_wmessage_integer(r, "type",  rewards[i].type, 0);
					pbc_wmessage_integer(r, "id",    rewards[i].id, 0);
					pbc_wmessage_integer(r, "value", rewards[i].value, 0);
					pbc_wmessage_integer(r, "uuid",  rewards[i].uuid, 0);
				}
			} 
		}
	} while (0);
	FINI_REQUET_RESPOND(S_PLAYER_FIGHT_CONFIRM_RESPOND, result);
}


void do_pbc_query_recommend_fight_info(resid_t conn, unsigned long long channel, const char * data, size_t len) {
	INIT_REQUET_RESPOND("QueryRecommendFightInfoRequest", "QueryPlayerFightInfoRespond");

	READ_INT64(pid);
	READ_INT(fight_id);
	READ_INT(ref);

	WRITE_DEBUG_LOG("query recommend fight data %d of player %llu", fight_id, pid)
	struct Player * player = player_get(pid);

	do {
		if (!player) {
			result = RET_ERROR;
			WRITE_DEBUG_LOG(" player not exist");
			break;
		}

		/*if (aL_pve_fight_is_open(player, fight_id) != RET_SUCCESS) {
			result = RET_PREMISSIONS;
			WRITE_DEBUG_LOG(" fight %llu of player %llu not open", fight_id, pid);
			break;	
		}*/

		struct PVE_FightRecommendConfig * cfg = get_pve_fight_recommend_config(fight_id);
		if (!cfg) {
			WRITE_DEBUG_LOG(" recommend config of fight %d is nil", fight_id);
			result = RET_ERROR;
			break;
		}

		unsigned long long target_heros[HERO_INTO_BATTLE_MAX] = {0};
		int nheros = 0;

		unsigned long long assists[64]; 
		memset(assists, 0, sizeof(assists));
		int nassists = 64;

		if (read_heros_and_assists(pid, request, target_heros, &nheros, assists, &nassists) != 0) {
			result = RET_ERROR;
			break;
		}

		struct HeroList heros[HERO_INTO_BATTLE_MAX];
		memset(heros, 0, sizeof(heros));
		int success = build_hero_list(player, target_heros, nheros, heros, cfg);
		/*int i;	
		int j = 0;
		struct HeroList heros[HERO_INTO_BATTLE_MAX];
		memset(heros, 0, sizeof(heros));
		int success = 1;
		for (i = 0; i < HERO_INTO_BATTLE_MAX; i++) {
			if (cfg->roles[i].role_type == 1) {
				heros[i].role_type = cfg->roles[i].role_type;
				heros[i].role_id = cfg->roles[i].role_id;
				heros[i].role_lv = cfg->roles[i].role_lv;
			} else if (cfg->roles[i].role_type == 2) {
				heros[i].role_type = cfg->roles[i].role_type;
				if (nheros == 0) {
					struct Hero * hero = 0;
					hero = hero_get(player, cfg->roles[i].role_id, 0);
					if (!hero) {
						WRITE_DEBUG_LOG(" donnt has hero gid:%d", cfg->roles[i].role_id);
						success = 0;
						break;
					}
					heros[i].role_id = hero->uuid;
				} else {
					unsigned long long target_hero_id = 0;
					int idx = 0;
					for (idx = j; idx < HERO_INTO_BATTLE_MAX; idx++) {
						if (target_heros[idx] != 0) {
							target_hero_id = target_heros[idx];
							j = idx + 1;
							break;
						}	
					}
					if (target_hero_id == 0) {
						WRITE_DEBUG_LOG("target hero not enough");
						success = 1;
						break;
					}
					
					struct Hero * hero = 0;
					hero = hero_get(player, 0, target_hero_id);
					if (!hero) {
						WRITE_DEBUG_LOG("donnt has hero uuid:%llu", target_hero_id);
						success = 1;
						break;
					}
					if (hero->gid != (unsigned int)cfg->roles[i].role_id) {
						WRITE_DEBUG_LOG("not the right hero");
						success = 1;
						break;
					}
					heros[i].role_id = target_hero_id;	
				}
			} else if (cfg->roles[i].role_type == 3){
				heros[i].role_type = cfg->roles[i].role_type;
				if (nheros == 0) {
					WRITE_DEBUG_LOG(" client donnt send target hero");
					success = 0;
					break;
				}
				unsigned long long target_hero_id = 0;
				int idx = 0;
				for (idx = j; idx < HERO_INTO_BATTLE_MAX; idx++) {
					if (target_heros[idx] != 0) {
						target_hero_id = target_heros[idx];
						j = idx + 1;
						break;
					}	
				}
				if (target_hero_id == 0) {
					WRITE_DEBUG_LOG("target hero not enough");
					success = 1;
					break;
				}
				heros[i].role_id = target_hero_id;
			} else {
				continue;
			}
		}*/ 

		if (!success) {
		 	result = RET_ERROR;
			break;
		}

		result = RET_SUCCESS;

		struct pbc_wmessage * msg = pbc_wmessage_message(respond, "player");
		fill_recommend_fight_data(msg, player, ref, heros, assists, nassists); // player_get_level(player));

	} while(0);

	FINI_REQUET_RESPOND(S_QUERY_RECOMMEND_FIGHT_INFO_RESPOND, result);
}

void do_pbc_unload_player(resid_t conn, uint32_t channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("UnloadPlayerRequest", "aGameRespond");
	READ_INT64(playerid);

	WRITE_INFO_LOG("unload player %llu", playerid);
	struct Player * player = player_get(playerid);
	if (player) {
		player_unload(player);
	}
	result =RET_SUCCESS;
	FINI_REQUET_RESPOND(S_UNLOAD_PLAYER_RESPOND, result);
}

