#include <math.h>
#include "player.h"
#include "aifightdata.h"
#include "database.h"
#include "base64.h"
#include "protocol.h"
#include "map.h"
#include "log.h"
#include "request_pbc/do.h"
#include "modules/hero.h"
#include "mtime.h"
#include "timeline.h"
#include "logic/aL.h"
#include "config/openlv.h"
#include "config/hero.h"
#include "package.h"
#include "aiLevel.h"
#include "config/aiExp.h"
#include "data/Property.h"
#include "modules/property.h"

static int LoadAIInfo();
static int CreateAI(int birth_level);
static int UpdateAIFightData(unsigned long long pid, int fight_data_id);
static int AddAIExp(Player * player, int exp);
static int UpgradeAI(Player * player, int level);
static int UpdateAIModePid(unsigned long long pid, unsigned long long mode_pid);

int ai_fight_data_count[AI_MAX_LEVEL] = {0};
int has_load = 0;
int has_data = 1;
static struct map * already_insert_map = NULL;
static struct map * fight_data_from = NULL;

/*#define GET_DAY_BEGIN_TIME(x) \
    (x - (x + 8 * 3600) % 86400)*/

#define DAY_AFTER_OPEN_SERVERDAY \
	(int)(ceil(((float)(agT_current()) - (float)GET_DAY_BEGIN_TIME(get_open_server_time())) / 86400))

#define MIN(a,b) a < b ? a : b
#define MAX(a,b) a > b ? a : b
static int onQuery(struct slice * fields, void * ctx)
{
	int id = atoll((const char*)fields[0].ptr);
	int64_t pid = atoll((const char*)fields[1].ptr);
	int level = atoll((const char*)fields[3].ptr);
	if (level <= AI_MAX_LEVEL) ai_fight_data_count[level - 1] += 1;

	if (!already_insert_map) {
		already_insert_map = _agMap_new(0);	
	}

	if (!fight_data_from) {
		fight_data_from = _agMap_new(0);
	}

	int64_t * from = (int64_t *)malloc(sizeof(int64_t));
	*from = pid;

	_agMap_ip_set(already_insert_map, (pid * 1000 + level), &has_data);
	_agMap_ip_set(fight_data_from, id, from);
	return 0;
}

static int LoadAIFightData()
{
	if (!fight_data_from) fight_data_from = _agMap_new(0);

	if (!has_load) {
		extern struct DBHandler * role_db;
		if (database_query(role_db, onQuery, 0, "select id, `from`, fight_data, level from ai_fight_data") < 0) {
			has_load = 1;
			return -1;
		}
		has_load = 1;
		return 0;
	} 

	return 0;
}

int getAIFightDataCount(int level)
{
	/*if (!has_load) {
		extern struct DBHandler * role_db;
		if (database_query(role_db, onQuery, 0, "select id, `from`, fight_data, level from ai_fight_data") < 0) {
			has_load = 1;
			return -1;
		}
		has_load = 1;
	}*/
	if (LoadAIFightData() != 0) return -1;

	if (level > AI_MAX_LEVEL) {
		return -1;
	}

	return ai_fight_data_count[level - 1];
}

int64_t * GetFightDataFrom(int id)
{
	/*if (!has_load) {
		extern struct DBHandler * role_db;
		if (database_query(role_db, onQuery, 0, "select id, `from`, fight_data, level from ai_fight_data") < 0) {
			has_load = 1;
			return 0;
		}
		has_load = 1;
	}*/	
	if (LoadAIFightData() != 0) return 0;

	return (int64_t *)_agMap_ip_get(fight_data_from, id);
}

static int alreadyHasAIFightData(int level, int64_t pid)
{
	/*if (!has_load) {
		extern struct DBHandler * role_db;
		if (database_query(role_db, onQuery, 0, "select id, `from`, fight_data, level from ai_fight_data") < 0) {
			has_load = 1;
		}
		has_load = 1;
	}*/
	LoadAIFightData();	
	
	if (!already_insert_map || !_agMap_ip_get(already_insert_map, (pid * 1000 + level))) {
		return 0;
	}
	
	return 1;
}


static void addAIFightDataCount(int level, int64_t * pid, int id)
{
	if (level > AI_MAX_LEVEL) return;

	/*if (!has_load) {
		extern struct DBHandler * role_db;
		if (database_query(role_db, onQuery, 0, "select id, `from`, fight_data, level from ai_fight_data") < 0) {
			has_load = 1;
		}
		has_load = 1;
	}*/ 
	LoadAIFightData();

	ai_fight_data_count[level] += 1;

	if (!already_insert_map) already_insert_map = _agMap_new(0);	
	_agMap_ip_set(already_insert_map, ((*pid) * 1000 + level), &has_data);

	_agMap_ip_set(fight_data_from, id, pid);
}


#define FIGHT_DATA_SIZE  64 * 1024
//save ai fight data
void checkAndAddAIFightData(Player * player)
{
	unsigned long long pid = player_get_id(player);
	struct pbc_wmessage * ai_msg = protocol_new_w("FightPlayer");
	fill_player_fight_data(ai_msg, player, 1000, 0, 0, 0);

	struct pbc_slice slice;
	pbc_wmessage_buffer(ai_msg, &slice);

	char *bs = (char *)malloc(FIGHT_DATA_SIZE);
	if (base64_encode((char *)slice.buffer, slice.len, bs) == 0) { 
		pbc_wmessage_delete(ai_msg);
	
		unsigned int id = 0;
		int player_level = player_get_level(player);
		int fight_data_count = getAIFightDataCount(player_level);
		id = (fight_data_count + 1) * 1000 + player_level;

		if (!alreadyHasAIFightData(player_level, pid)) {
			int64_t * from = (int64_t *)malloc(sizeof(int64_t));
			*from = pid;
			extern struct DBHandler * role_db;
			database_update(role_db, "insert into ai_fight_data(id, `from`, level, fight_data) values(%d, %llu, %d, '%s')", id, (long long)*from, player_level, bs);
			addAIFightDataCount(player_level, from, id);
		} else {
			WRITE_DEBUG_LOG("already insert ai fight data from player %llu, level %d", pid, player_level);
		}
	}
	free(bs);
}

static int max_player_level = -1;
static time_t update_time = 0;

static int queryMaxLevel(struct slice * fields, void * ctx)
{
	if (fields[0].ptr)  {
		int exp = atoll((const char*)fields[0].ptr);
		max_player_level =  transfrom_exp_to_level(exp, 1, LEADING_ROLE);
	} else  {
		WRITE_WARNING_LOG("TABLE hero is empty");
		max_player_level = 0;
	}

	return 0;
}

int getMaxPlayerLevel()
{
	if (max_player_level < 0 ) {//|| (agT_current() - update_time) > 5 * 60) {
		extern struct DBHandler * role_db;
		database_query(role_db, queryMaxLevel, 0, "select max(exp) from hero where gid = %d limit 1", LEADING_ROLE);
		update_time = agT_current();
	}
	return max_player_level;
}

int updateMaxLevel(int exp)
{
	getMaxPlayerLevel();
	int level = transfrom_exp_to_level(exp, 1, LEADING_ROLE);
	if (level > max_player_level) max_player_level = level;
	return 0;
}

long long min_ai_id = -1;
long long max_ai_id = -1;
static struct map * ai_map = NULL;
struct ai_info load = {0};

#define RAND_RANGE(a, b) \
	( (a) == (b) ? (a) : ((a) + rand() % ((b)-(a)+1)))
int BalanceAIStar(unsigned long long ai_pid)
{
	WRITE_DEBUG_LOG("Player %llu begin to balance star", ai_pid);
	if (ai_pid > AI_MAX_ID) {
		WRITE_DEBUG_LOG("fail to balance ai star num, player %llu is not ai", ai_pid);
		return 1;
	}
	
	struct Player * ai = player_get(ai_pid);
	if (!ai) {
		WRITE_DEBUG_LOG("fail to balance ai star num, cannt get ai");
		return 1;
	}

	int ai_level = player_get_level(ai);
	if (ai_level <= 0) {
		WRITE_DEBUG_LOG("fail to balance ai star num, cannt get ai level");
		return 1;
	}

	struct AIExpConfig * cfg = get_ai_exp_config(ai_level);
	if (!cfg) {
		WRITE_DEBUG_LOG("fail to balance ai star num, cannt get cfg");
		return 1;
	}

	unsigned int star_num = RAND_RANGE(cfg->min_star, cfg->max_star);
	Property * property = player_get_property(ai);
	WRITE_DEBUG_LOG("ai star num %d", star_num);
	if (property && star_num > property->total_star) {
		WRITE_DEBUG_LOG("ai %llu success balance star num %d", ai_pid, star_num);
		property_change_total_star(ai, star_num);
		return 0;
	}

	return 1;
}

static int BalanceLevel(unsigned long long ai_pid, int ai_level, unsigned long long pid, int * final_level)
{
	WRITE_DEBUG_LOG("AI %llu begin to balance level, now level:%d, mode_pid:%llu", ai_pid, ai_level, pid);
	struct Player * ai = player_get(ai_pid);
	if (!ai) {
		WRITE_DEBUG_LOG("%s fail, cannt get ai:%llu", __FUNCTION__, ai_pid);
		return 1;
	}

	struct AILevelLimitConfig * lcfg = get_ai_level_limit_config(DAY_AFTER_OPEN_SERVERDAY);
	if (!lcfg) {
		WRITE_DEBUG_LOG("%s fail, cannt get ai level limit config", __FUNCTION__);
		return 1;
	}

	if (pid == 0) {
		struct AIExpConfig * cfg = get_ai_exp_config(ai_level);
		if (cfg) { 
			int limit_level = lcfg->limit_level;
			int today_max_exp = get_exp_by_level(limit_level, 1, LEADING_ROLE);
			int ai_exp = get_exp_by_level(player_get_level(ai), 1, LEADING_ROLE);
			if (ai_exp >= today_max_exp) {
				WRITE_DEBUG_LOG("AI %llu already reach max level", ai_pid);
				*final_level = player_get_level(ai);
				BalanceAIStar(ai_pid);
				return 0;
			} 			
			
			int max_increase_exp = today_max_exp - ai_exp;	
			int min = 0;
			int max = 0;
			if (cfg->min_exp > max_increase_exp) {
				min = max = max_increase_exp;
			} else {
				min = cfg->min_exp;
				max = MIN(cfg->max_exp, max_increase_exp);
			}
			
			AddAIExp(ai, RAND_RANGE(min, max));
		}
		*final_level = player_get_level(ai);
		BalanceAIStar(ai_pid);
		return 0;
	}

	struct Player * player = player_get(pid);
	if (!player) {
		WRITE_DEBUG_LOG("%s fail, cannt get player:%llu", __FUNCTION__, pid);
		BalanceAIStar(ai_pid);
		return 1;
	}
	int mode_level = player_get_level(player);

	if (ai_level < mode_level) {
		if (mode_level - ai_level > 5) {
			int limit_level = lcfg->limit_level;
			int rand_level = 0;
			if ((limit_level - ai_level) >= 3) {
				rand_level = RAND_RANGE(1, 3);
			} else if ((limit_level - ai_level) > 0) {
				rand_level = RAND_RANGE(1, (limit_level - ai_level));
			} else {
				rand_level = 0;
			}

			UpgradeAI(ai, ai_level + rand_level);
			*final_level = player_get_level(ai);
			BalanceAIStar(ai_pid);

			return 0;
		} else {
			int limit_level = lcfg->limit_level;
			int new_level = 0;
			if (limit_level < mode_level) {
				new_level = limit_level;
			} else {
				new_level = mode_level;
			} 
			UpgradeAI(ai, new_level);
			*final_level = player_get_level(ai);
			BalanceAIStar(ai_pid);

			return 0;
		}
	} else {
		if (ai_level - mode_level >= 10) {
			struct AIExpConfig * cfg = get_ai_exp_config(ai_level);
			if (cfg) { 
				int limit_level = lcfg->limit_level;
				int today_max_exp = get_exp_by_level(limit_level, 1, LEADING_ROLE);
				int ai_exp = get_exp_by_level(player_get_level(ai), 1, LEADING_ROLE);
				if (ai_exp >= today_max_exp) {
					WRITE_DEBUG_LOG("AI %llu already reach max level", ai_pid);
					return 0;
				} 			
				
				int max_increase_exp = today_max_exp - ai_exp;	
				int min = 0;
				int max = 0;
				if (cfg->min_exp > max_increase_exp) {
					min = max = max_increase_exp;
				} else {
					min = cfg->min_exp;
					max = MIN(cfg->max_exp, max_increase_exp);
				}

				AddAIExp(ai, RAND_RANGE(min, max));
			}
			*final_level = player_get_level(ai);
			BalanceAIStar(ai_pid);
			
			return 0;
		} 

		*final_level = player_get_level(ai);
		BalanceAIStar(ai_pid);
		return 0;
	}	
}

int newbie_ai_day_limit = 0;
static int get_newbie_ai_day_limit()
{
	if (newbie_ai_day_limit == 0) {
		FILE * fp = fopen("../log/newbie_ai_day_limit.txt","rb");
		newbie_ai_day_limit = 1;

		if (fp) {
			newbie_ai_day_limit = 30;
			fclose(fp);
		}

	}

	return newbie_ai_day_limit;
}

static void change_ai_login(unsigned long long pid)
{
	struct Player * ai = player_get(pid);
	if (!ai) return;

	Property * property = player_get_property(ai);
	if (!property) return;

	DATA_Property_update_login(property, agT_current());
}

unsigned long long QueryUnactiveAI(int ref_level, int * ai_level)
{
	if (!ai_map) {
		LoadAIInfo();
	}

	if (ref_level <= 28) {
		WRITE_DEBUG_LOG("day after open serverday %d", DAY_AFTER_OPEN_SERVERDAY);
		if (DAY_AFTER_OPEN_SERVERDAY > get_newbie_ai_day_limit()) {
			return 0;
		}

		if (CreateAI(1) == 0) {
			*ai_level = 1;
			change_ai_login(max_ai_id);
			return max_ai_id;
		}
		else {
			return 0;
		}
	} 

	int i;
	int begin = (ref_level - 5) > 0 ? ref_level - 5 : 1;
	int end = (ref_level + 5) < AI_MAX_LEVEL ? ref_level + 5 : AI_MAX_LEVEL;	
	int rand_num = RAND_RANGE(begin, end);
	WRITE_DEBUG_LOG("begin %d  end %d", begin, end);
	for (i = rand_num; i >= begin; i--) {
		AILevel * iter = 0;	
		while ((iter = aiLevel_next(iter, i)) != 0) {
			//WRITE_DEBUG_LOG("search for ai whose level is %d", i);
			struct ai_info * aiinfo = GetAIInfo(iter->pid);
			if (!aiinfo) continue;
			
			if (aiinfo && (timeline_get_day(agT_current()) != timeline_get_day(aiinfo->active_time))) {
				UpdateAIActiveTime(aiinfo->pid, agT_current());
				UpdateAIFightData(aiinfo->pid, 0);
				//*ai_level = i;

				//寻找模板
				WRITE_DEBUG_LOG("AI %llu mode_pid %llu", aiinfo->pid, aiinfo->mode_pid);
				if (aiinfo->mode_pid == 0) {
					WRITE_DEBUG_LOG("AI %llu begin to find mode", aiinfo->pid);
					unsigned long long mode_pid = GetAIModePID(i);
					if (mode_pid) {
						UpdateAIModePid(aiinfo->pid, mode_pid);
					}
				}

				//同步等级
				BalanceLevel(aiinfo->pid, i, aiinfo->mode_pid, ai_level);
				
				//WRITE_DEBUG_LOG("Get AI %llu whose level is %d", aiinfo->pid, i)
				change_ai_login(aiinfo->pid);
				return aiinfo->pid;
			}
		}
	}

	for (i = rand_num + 1; i <= end; i++) {
		AILevel * iter = 0;	
		while ((iter = aiLevel_next(iter, i)) != 0) {
			//WRITE_DEBUG_LOG("search for ai whose level is %d", i);
			struct ai_info * aiinfo = GetAIInfo(iter->pid);
			if (!aiinfo) continue;
			
			if (aiinfo && (timeline_get_day(agT_current()) != timeline_get_day(aiinfo->active_time))) {
				UpdateAIActiveTime(aiinfo->pid, agT_current());
				UpdateAIFightData(aiinfo->pid, 0);
				//*ai_level = i;

				//寻找模板
				WRITE_DEBUG_LOG("AI %llu mode_pid %llu", aiinfo->pid, aiinfo->mode_pid);
				if (aiinfo->mode_pid == 0) {
					WRITE_DEBUG_LOG("AI %llu begin to find mode", aiinfo->pid);
					unsigned long long mode_pid = GetAIModePID(i);
					if (mode_pid) {
						UpdateAIModePid(aiinfo->pid, mode_pid);
					}
				}

				//同步等级
				BalanceLevel(aiinfo->pid, i, aiinfo->mode_pid, ai_level);
				
				//WRITE_DEBUG_LOG("Get AI %llu whose level is %d", aiinfo->pid, i)
				change_ai_login(aiinfo->pid);
				return aiinfo->pid;
			}
		}
	}

	if (CreateAI(ref_level) == 0) {
		*ai_level = ref_level;
		change_ai_login(max_ai_id);
		return max_ai_id;
	}
	else {
		return 0;
	};
	
}

static int onQueryAIInfo(struct slice * fields, void * ctx)
{
	int64_t pid = atoll((const char*)fields[0].ptr);
	int64_t mode_pid = atoll((const char*)fields[1].ptr);
	int level_percent = atoll((const char*)fields[2].ptr);
	int fight_data_id = atoll((const char*)fields[3].ptr);
	int active_time = atoll((const char*)fields[4].ptr);

	if (pid < min_ai_id || min_ai_id == -1) {
		min_ai_id = pid;
	}

	if (pid > max_ai_id || max_ai_id == -1) {
		max_ai_id = pid;
	}

	struct ai_info * aiinfo = (struct ai_info *)malloc(sizeof(ai_info));
	memset(aiinfo, 0, sizeof(struct ai_info));

	aiinfo->pid = pid;
	aiinfo->mode_pid = mode_pid;
	aiinfo->level_percent = level_percent;
	aiinfo->fight_data_id = fight_data_id;
	aiinfo->active_time = active_time;

	_agMap_ip_set(ai_map, pid, aiinfo);
	return 0;
}

static int LoadAIInfo()
{
	if (ai_map) {
		WRITE_DEBUG_LOG("Load AI Info fail, already load");
		return 1;
	}
	if (!ai_map) {
		ai_map = _agMap_new(0);
	}

	extern struct DBHandler * role_db;
	if (database_query(role_db, onQueryAIInfo, 0, "select pid, mode_pid, level_percent, fight_data_id, unix_timestamp(active_time) from ai_info ORDER BY pid") < 0) {
		WRITE_DEBUG_LOG("Load AI Info fail, database error");
		return 1;
		//_agMap_ip_set(ai_map, pid, &load);
	}

	return 0;
}

static int UpgradeAI(Player * player, int level)
{
	WRITE_DEBUG_LOG("Upgrade AI to level %d", level)
	struct Hero * pHero = hero_get(player, LEADING_ROLE, 0);
	if (pHero == NULL) {
		WRITE_WARNING_LOG("  hero not exists");
		return RET_ERROR;
	}
	
	/* 升级功能开启判断 */
    int olevel = player_get_level(player);
	OpenLevCofig *cfg = get_openlev_config(ROLE_LEVEL_UP);
	int open_level = cfg ? cfg->open_lev : 0;
	if (olevel < open_level) {
		WRITE_WARNING_LOG("%s: add exp failed, level is not enough, level is %d, open level is %d.", __FUNCTION__, olevel, open_level);
		return RET_PERMISSION;
	}

	/* 升级等级上限判断 */
	struct HeroStageConfig *hcfg = get_hero_stage_config(LEADING_ROLE, pHero->stage);
	int max_level = hcfg ? hcfg->max_level : 9999;
	if (pHero->level >= (unsigned int)max_level) {
		WRITE_WARNING_LOG("%s: hero %d level is %d, max level is %d.", __FUNCTION__, LEADING_ROLE, pHero->level, max_level);
		return RET_FULL;
	}	
	
	if (level <= olevel) {
		WRITE_WARNING_LOG("%s: upgrade level %d smaller than old level %d", __FUNCTION__, level, pHero->level)
		return RET_ERROR;
	}
	int oexp = get_exp_by_level(pHero->level, 1, LEADING_ROLE);
	int nexp = get_exp_by_level(level, 1, LEADING_ROLE);
	
	return hero_add_normal_exp(pHero, nexp - oexp);//hero_add_exp(player, pHero, nexp - oexp, 0);
}

static int AddAIExp(Player * player, int exp)
{
	WRITE_DEBUG_LOG("Add AI exp %d", exp)
	struct Hero * pHero = hero_get(player, LEADING_ROLE, 0);
	if (pHero == NULL) {
		WRITE_WARNING_LOG("  hero not exists");
		return RET_ERROR;
	}
	
	/* 升级功能开启判断 */
    int olevel = player_get_level(player);
	OpenLevCofig *cfg = get_openlev_config(ROLE_LEVEL_UP);
	int open_level = cfg ? cfg->open_lev : 0;
	if (olevel < open_level) {
		WRITE_WARNING_LOG("%s: add exp failed, level is not enough, level is %d, open level is %d.", __FUNCTION__, olevel, open_level);
		return RET_PERMISSION;
	}

	/* 升级等级上限判断 */
	struct HeroStageConfig *hcfg = get_hero_stage_config(LEADING_ROLE, pHero->stage);
	int max_level = hcfg ? hcfg->max_level : 9999;
	if (pHero->level >= (unsigned int)max_level) {
		WRITE_WARNING_LOG("%s: hero %d level is %d, max level is %d.", __FUNCTION__, LEADING_ROLE, pHero->level, max_level);
		return RET_FULL;
	}	
	
	return hero_add_normal_exp(pHero, exp); //hero_add_exp(player, pHero, exp, 0);
}

static int CreateAI(int birth_level)
{
	if (!ai_map) {
		LoadAIInfo();
	}

	unsigned long long ai_id = 0;
	/*ai_id = playerid & 0x00000000ffffffff - 100000;
	if (ai_id > 100000) { 
		break;
	}*/

	if (max_ai_id == 99999) {
		WRITE_DEBUG_LOG("AI already max");
		return 1;
	}

	if (max_ai_id == -1) {
		ai_id = 1;
	} else {
		ai_id = max_ai_id + 1;
	}
	
	max_ai_id = ai_id;

	if (min_ai_id == -1) {
		min_ai_id = 1;
	}

	char ai_name[100];
	sprintf(ai_name, "<SGK>%llu</SGK>", ai_id);
	//strncpy(ai->name, "AI", sizeof(ai->name));
	WRITE_DEBUG_LOG("create ai %llu name %s", ai_id, ai_name);

	struct Player * ai = player_get(ai_id);
	if (ai) {
		WRITE_DEBUG_LOG("ai	exist");
		return 1;
	}

	if (!player_is_not_exist(ai_id)) {
		WRITE_WARNING_LOG("create ai database error");
		return 1;
	}

	if (player_get_id_by_name(ai_name) > 0) {
		WRITE_DEBUG_LOG("ai	name exist");
		return 1;
	}

	ai = player_create(ai_id, ai_name, 0);
	if (ai == 0) {
		WRITE_WARNING_LOG("create ai database error");
		return 1;
	} 

	hero_check_leading(ai);

	int level_percent = 60 + rand() % 41; 
	AddAIInfo(ai_id, 0, level_percent, 0, agT_current());
	if (birth_level > 1) {
		UpgradeAI(ai, birth_level);
	}

	return 0;
}

struct ai_info * GetAIInfo(unsigned long long pid)
{
	if (!ai_map) {
		LoadAIInfo();
	}

	return (struct ai_info *)_agMap_ip_get(ai_map, pid);
}

int AddAIInfo(unsigned long long pid, unsigned long long mode_pid, unsigned int level_percent, unsigned int fight_data_id, unsigned int active_time)
{
	if (!ai_map) {
		LoadAIInfo();
	}

	if (_agMap_ip_get(ai_map, pid) != 0) {
		WRITE_DEBUG_LOG("already has ai info for pid %llu",pid);
		return 1;
	}

	struct ai_info * aiinfo = (struct ai_info *)malloc(sizeof(ai_info));
	memset(aiinfo, 0, sizeof(struct ai_info));

	aiinfo->pid = pid;
	aiinfo->mode_pid = mode_pid;
	aiinfo->level_percent = level_percent;
	aiinfo->fight_data_id = fight_data_id;
	aiinfo->active_time = active_time;

	extern struct DBHandler * role_db;
	if (database_update(role_db, "insert into ai_info(pid, mode_pid, level_percent, fight_data_id, active_time) values(%llu, %llu, %d, %d, from_unixtime_s(%d))", pid, mode_pid, level_percent, fight_data_id, active_time) < 0) {
		return 1;
	}

	_agMap_ip_set(ai_map, pid, aiinfo);
	return 0;
}

static int UpdateAIFightData(unsigned long long pid, int fight_data_id)
{
	struct ai_info * ai_info = GetAIInfo(pid);
	if (ai_info)
	{
		ai_info->fight_data_id = fight_data_id;
		database_update(role_db, "update ai_info set fight_data_id = %d where pid = %llu", fight_data_id, pid); 

		// free 
		if (fight_data_id == 0) {
			Player * player = player_get(pid);	
			if (!player) {
				return 0;
			}
			struct CheckData * check_data = player_get_check_data(player);
			if (check_data->fight_data) {
				pbc_rmessage_delete(check_data->fight_data);			
				check_data->fight_data = 0;
			}

			if (check_data->fight_data_src) {
				free(check_data->fight_data_src);
				check_data->fight_data_src = 0;
			}
		}
		return 0;
	}

	return 1;
}

int UpdateAIActiveTime(unsigned long long pid, unsigned int active_time)
{
	struct ai_info * ai_info = GetAIInfo(pid);
	if (ai_info)
	{
		ai_info->active_time = active_time;
		database_update(role_db, "update ai_info set active_time = from_unixtime_s(%d) where pid = %llu", active_time, pid); 
		return 1;
	}

	return -1;
}

static int UpdateAIModePid(unsigned long long pid, unsigned long long mode_pid)
{
	struct ai_info * ai_info = GetAIInfo(pid);
	if (ai_info)
	{
		ai_info->mode_pid = mode_pid;
		database_update(role_db, "update ai_info set mode_pid = %llu where pid = %llu", mode_pid, pid); 
		return 1;
	}

	return -1;
}


struct FightDataWrap {
	char * fight_data_src;
	pbc_rmessage * fight_data;
};

static int queryFightData(struct slice * fields, void * ctx)
{
	struct FightDataWrap * wrap = (struct FightDataWrap *)ctx;
	char * fightdata = (char*)fields[0].ptr;
	char * output = (char *)malloc(FIGHT_DATA_SIZE);
	int len = base64_decode(fightdata, output);
	output = (char *)realloc(output, len);
	wrap->fight_data_src = output;
    wrap->fight_data = protocol_new_r("FightPlayer", output, len);

	return 0;
}

int FreshAIFightDataID(Player * player)
{
	struct ai_info * aiinfo = GetAIInfo(player_get_id(player));
	int i;
	int id = 0;
	int ai_level;
	if (aiinfo) {
		// ai_level = ((aiinfo->level_percent * getMaxPlayerLevel() / 100) > 0) ? (aiinfo->level_percent * getMaxPlayerLevel() / 100) : 1;
		ai_level = player_get_level(player);
		if (aiinfo->fight_data_id == 0) {
			WRITE_DEBUG_LOG("reload ai fight data for pid %llu", player_get_id(player));
			for (i = ai_level; i >= 1; i--) {
				int count = getAIFightDataCount(i);	
				if (count > 1) {
					int rand_v = 1 + rand() % (count - 1);
					id = rand_v * 1000 + i;
					break;
				} else if (count == 1) {
					id = 1000 + i;
					break;
				}
			}
			
			//set head
		    UpdateAIFightData(player_get_id(player), id);
			int64_t * pPid = GetFightDataFrom(id);
			
			if (pPid == 0) {
				return 0;
			}
			
			Player * real_player = player_get(*pPid);
			if (!real_player) {
				return 0;
			}
			//Property * property = player_get_property(real_player);

			/*if (property && property->head)	{
				aL_change_nick_name(player, 0, property->head, 0);
			}*/
		}
	}

	return 0;
}

struct pbc_rmessage * getAIFightData(Player * player)
{
	struct CheckData * check_data = player_get_check_data(player);
	if (check_data && check_data->fight_data) {
		return check_data->fight_data;
	}
	
	WRITE_DEBUG_LOG("begin get ai fight_data from database");

	FreshAIFightDataID(player);
	struct ai_info * aiinfo = GetAIInfo(player_get_id(player));

	//struct pbc_rmessage * fight_data = 0; 
	if (aiinfo && aiinfo->fight_data_id > 0) { 
		struct FightDataWrap fight_data_wrap = {0};	
		extern struct DBHandler * role_db;
		if (database_query(role_db, queryFightData, &fight_data_wrap, "select fight_data from ai_fight_data where id = %d", aiinfo->fight_data_id) < 0) {
			WRITE_DEBUG_LOG("select ai fight_data fail");
			return 0;
		}

		check_data->fight_data_src = fight_data_wrap.fight_data_src;	
		check_data->fight_data = fight_data_wrap.fight_data;	
		return check_data->fight_data;
	}

	return 0;
}


