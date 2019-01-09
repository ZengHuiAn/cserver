#include "player.h"

// #include "hash.h"
#include "map.h"
#include "dlist.h"
#include "log.h"
#include "database.h"
#include "mtime.h"
#include "memory.h"

#include "modules/property.h"
#include "modules/request_queue.h"
#include "modules/item.h"
#include "modules/bag.h"
#include "modules/reward.h"
#include "modules/hero.h"
#include "modules/talent.h"
#include "modules/equip.h"
#include "modules/fight.h"
#include "modules/daily.h"
#include "modules/hero_item.h"
#include "modules/quest.h"
#include "modules/reward_flag.h"
#include "modules/buff.h"
#include "modules/fire.h"

#include "config/general.h"

#include "data/PlayerData.h"
#include "data/DataFlush.h"
#include "data/LogData.h"

#include "package.h"
#include "amf.h"
#include "message.h"
#include "xmlHelper.h"
#include "config.h"
#include "backend.h"
#include "stringCache.h"

#include <assert.h>
#include <errno.h>
#include <string.h>

#include "aifightdata.h"
#include "config/hero.h"
#include "logic/aL.h"

#define RESERVED_ID		1
#define YQ_MAX_ZOMBIE_TIME (15*60)

static struct map * player_not_exist = 0;
static struct map * player_online = 0;
static struct map * player_offline = 0;
static struct map * player_name = 0;
static Player*      player_zombie_list = 0;
static struct map * player_zombie_table = 0;


typedef struct PlayerModule {
	unsigned int id;
	const char * name;
	void   (*_init)();
	void * (*_new)(Player * player);
	void * (*_load)(Player * player);
	int    (*_update)(Player * player, void * data, time_t now);
	int    (*_save)(Player * player, void * data, const char * sql, ...);
	int    (*_release)(Player * player, void * data);
} PlayerModule;


#define IMPORT_PLAYER_MODULE(ID, name) 	\
{ 					\
	PLAYER_MODULE_##ID, \
	#name, 				\
	name##_init,		\
	name##_new,			\
	name##_load,			\
	name##_update,			\
	name##_save,			\
	name##_release,			\
}

static PlayerModule player_modules[] = {
	IMPORT_PLAYER_MODULE(PROPERTY, property),
	IMPORT_PLAYER_MODULE(REQUEST_QUEUE, request_queue),
	IMPORT_PLAYER_MODULE(ITEM, item),
	IMPORT_PLAYER_MODULE(BAG, bag),
	IMPORT_PLAYER_MODULE(REWARD, reward),
	IMPORT_PLAYER_MODULE(HERO, hero),
	IMPORT_PLAYER_MODULE(TALENT, talent),
	IMPORT_PLAYER_MODULE(EQUIP, equip),
	IMPORT_PLAYER_MODULE(FIGHT, fight),
	IMPORT_PLAYER_MODULE(DAILY, daily),
	IMPORT_PLAYER_MODULE(HEROITEM, hero_item),
	IMPORT_PLAYER_MODULE(QUEST, quest),
	IMPORT_PLAYER_MODULE(REWARDFLAG, reward_flag),
	IMPORT_PLAYER_MODULE(BUFF, buff),
	IMPORT_PLAYER_MODULE(FIRE, fire),
	{0,0}
};

#define player_modules_count \
	(sizeof(player_modules) / sizeof(player_modules[0]) - 1)

struct Player
{
	struct Player * prev;
	struct Player * next;

	struct{
		struct Player * prev;
		struct Player * next;
	}zombie;
	time_t zombie_time; 				//成为僵尸时间

	resid_t conn;

	time_t update_time; 				//用户数据时间点

	time_t last_active_time;			//最后活跃时间

	unsigned long long id;
	int64_t last_tick_time; //最后tick时间

	char name[32];
	const char * account;

	int loading;

	//玩家数据
	struct {
		void * data;
		time_t update_time;
	} module[player_modules_count];

	struct CheckData check;
};


////////////////////////////////////////////////////////////////////////////////
// PlayerManager

static int MAX_ONLINE = 5000;

static int agPM_init(unsigned int max);
static int agPM_update(time_t now);
static int agPM_free();

static int agPM_SetOnline(struct Player * player, resid_t conn); // 设置用户在线
static int agPM_SetOffline(unsigned int id); 			 // 设置用户离线

static struct Player * agPM_Get(unsigned long long id);		 // 获取用户
static struct Player * agPM_Create(unsigned long long id, const char * name, int head);  // 创建用户
static struct Player * agPM_GetOnline(unsigned long long id);		 // 获取在线用户
static unsigned long long    agPM_GetIDByName(const char * name);	 // 按名称获取用户
static void agPM_ChangeNameRecord(const char * old_name);

static void agPM_Release(struct Player * player);	 // 释放用户
// PlayerManager
////////////////////////////////////////////////////////////////////////////////

#define DATA_VERSION	1

static int addMaxOnlineCount(xml_node_t * node, void * ctx)
{
	unsigned int count = atoi(xmlGetValue(xmlGetChild(node, "max", 0), "5000"));
	if (count == 0) count = 5000;
	MAX_ONLINE += count;

	return 0;
}

//角色模块加载
int module_player_load(int argc, char * argv[])
{
	unsigned int i;
	for(i = 0; player_modules[i].name; i++) {
		assert(player_modules[i].id == i);
	}

	DATA_PlayerData_set_db(role_db);
	// DATA_LogData_set_db(log_db);

	// static int MAX_ONLINE = 5000;
	xml_node_t * node = agC_get("Cells");
	if (node) {
		MAX_ONLINE = 0;
		int ret = foreachChildNodeWithName(node, 0, addMaxOnlineCount, 0);
		if (ret != 0) {
			return -1;
		}
	}

	if (MAX_ONLINE == 0) {
		MAX_ONLINE = 5000;
	}

	if (agPM_init(MAX_ONLINE) != 0) {
		return 0;
	}

	backend_connect("Guild");

	for(i = 0; i < player_modules_count; i++) {
		if (player_modules[i]._init) {
			player_modules[i]._init();
		}
	}

	_agMap_delete(player_zombie_table);
	player_zombie_table = 0;

	return 0;
}

int module_player_reload()
{
	module_player_unload();
	return module_player_load(0, 0);
}

void agSC_release();

static struct Player *  player_active_list = 0;
static struct Player * _update_player_active_list(struct Player * player)
{
	if (player) {
		if (player->next) {
			dlist_remove(player_active_list, player);
		}

		player->last_active_time = agT_current();
		dlist_insert_tail(player_active_list, player);	
	}
	return player;
}


void battlefield_cleanup();

//橘色模块释放
void module_player_unload()
{
	// TODO: do we need unload all player data?
	while(player_active_list) {
		// 卸载用户数据前给在线用户做一个logout的操作
		Property * property = player_get_property(player_active_list);
		if (property && property->login > property->logout) {
			aL_logout(player_get_id(player_active_list));
		}

		agPM_Release(player_active_list);
	}

	DATA_FLUSH_ALL();

	agPM_free();
	agSC_release();
}

void module_player_update(time_t now)
{
	agPM_update(now);
	DATA_FLUSH_ALL();
}

//保存角色数据, 只有在new之后执行
static int _player_save(struct Player * player)
{
	if (player == 0) {
		return -1;
	}

	// DATA_FLUSH_ALL();
	unsigned long long playerid = player->id; 

	//保存各模块数据
	size_t i;
	for(i = 0; i < player_modules_count; i++) {
		if(player_modules[i]._save) {
			player_modules[i]._save(player, player->module[i].data, 0);
		}
	}
	WRITE_DEBUG_LOG("player %llu save done", playerid);
	return 0;
}

//释放角色数据
static int _player_release(Player * player) 
{
	DATA_FLUSH_PlayerData();

	assert(player);

	unsigned long long playerid = player->id;

	WRITE_DEBUG_LOG("player %llu release",  playerid);

	//释放各模块数据
	size_t i;
	for(i = 0; i < player_modules_count; i++) {
		if (player_modules[i]._release) {
			if (player->module[i].data) {
				player_modules[i]._release(player, player->module[i].data);
			}
		}
	}


	// TODO:
	if (player->check.fight_data_src) {
		free(player->check.fight_data_src);
		player->check.fight_data_src = 0;
	}
	if (player->check.fight_data) {
		pbc_rmessage_delete(player->check.fight_data);
		player->check.fight_data = 0;
	}

	if (player->check.capacity_list != 0) {
		//free check data
		while(player->check.capacity_list)
		{
			struct HeroCapacity * node = player->check.capacity_list;
			dlist_remove(player->check.capacity_list, node);
			free(node);
		}
	}
	
	return 0;
}

static void * _player_load_module(Player * player, uint32_t m)
{
	unsigned long long playerid = player->id;
	WRITE_DEBUG_LOG("player %llu start load module %s", playerid, player_modules[m].name);

	player->loading = 1;

	//加载各模块数据
	if (player_modules[m]._load) {
		player->module[m].data = player_modules[m]._load(player);
		if (player->module[m].data == 0) {
			WRITE_DEBUG_LOG("player %llu module %s load failed",
					playerid, player_modules[m].name);
			return 0;
		}
		player->module[m].update_time = 0;
	}

	WRITE_DEBUG_LOG("player %llu load module %s success", playerid, player_modules[m].name);

	player->loading = 0;

	return player->module[m].data;
}


static void afterLoad(struct Player * player)
{
	struct Property * property = (struct Property*)player_get_module(player, PLAYER_MODULE_PROPERTY);

	// 更新主属性
	strncpy(player->name, property->name, sizeof(player->name));
	player->update_time = 0;
}

//加载角色
static struct Player * _player_load(struct Player * player)
{
	assert(player);

	unsigned long long pid = player->id;

	WRITE_DEBUG_LOG("player %llu start load", pid);

	player->loading = 1;

	//加载各模块数据
	size_t i;
	for(i = 0; i < player_modules_count; i++) {
		if (_player_load_module(player, i) == 0) {
			_player_release(player);
			return 0;
		}
		player->module[i].update_time = 0;
	}

	afterLoad(player);

	WRITE_DEBUG_LOG("player %llu load success", pid);

	player->loading = 0;

	return player;
};

static struct Player * _player_load_sample(struct Player * player) 
{
	unsigned long long pid = player->id;
	WRITE_DEBUG_LOG("player %llu start load sample", pid);
	player->loading = 1;

	struct Property * property = (struct Property*)_player_load_module(player, PLAYER_MODULE_PROPERTY);
	if (property == 0) {
		return 0;
	}

	afterLoad(player);

	player->loading = 0;

	return player;
}

static int _player_update_module(Player * player, int module, time_t now)
{
	assert(player->module[module].update_time <= now);

	if (player->module[module].update_time == now) {
		return 0;
	}

	//递归依赖问题?
	player->module[module].update_time = now;
	if (player_modules[module]._update) {
		player_modules[module]._update(player, player->module[module].data, now);
	}
	return 0;
}
	
static int _player_update_modules(Player * player, time_t now)
{
	player->update_time = now;

	unsigned long long playerid = player->id; 

	WRITE_DEBUG_LOG("player %llu update to %lu", playerid, now);

	size_t i;
	for(i = 0; i < player_modules_count; i++) {
		_player_update_module(player, i, now);
	}
	return 0;
}

//创建角色
static struct Player * _player_create(struct Player * player, int head)
{
	unsigned long long pid = player->id;
	WRITE_DEBUG_LOG("player %llu start create", pid);

	unsigned int tmppid = (unsigned int)pid;

	//角色id不能太大，amf限制
	if (tmppid > 0x1fffffff) {
		WRITE_DEBUG_LOG("playerid is too large %llu", pid);
		return 0;
	}

	time_t now = agT_current();

	//初始化
	player->loading = 1;

	//各个模块初始化
	size_t i;
	for(i = 0; i < player_modules_count; i++) {
		if (player_modules[i]._new) {
			player->module[i].data = player_modules[i]._new(player);
			if (player->module[i].data == 0) {
				WRITE_DEBUG_LOG("player %llu modules %s create failed",
						pid, player_modules[i].name);
				_player_release(player);
				return 0;
			}

			if (i == PLAYER_MODULE_PROPERTY) {
				Property * property = (Property*)player->module[i].data;
				property->head = head;
			}
		}
	}

	//更新
	_player_update_modules(player, now);

	//保存
	_player_save(player);

	player->loading = 0;

	return player;
}


//获取角色数据
struct Player * player_get(unsigned long long id)
{
	return agPM_Get(id);
}

unsigned long long player_get_id_by_name(const char * name)
{
	return agPM_GetIDByName(name);
}

void player_update_name_record(const char * old_name)
{
	agPM_ChangeNameRecord(old_name);
}

int player_is_loading(Player * player)
{
	return player->loading;
}

//创建角色
struct Player * player_create(unsigned long long id, const char * name, int head)
{
	Player * player = agPM_Get(id);
	if (player) { return 0; }

	return agPM_Create(id, name, head);
}

unsigned long long player_get_id(struct Player * player)
{
	assert(player);
	return player->id;
}

const char * player_get_name(Player * player)
{
	assert(player);
	if (player->loading) return player->name;

	Property * property = player_get_property(player);
	return property ? property->name : player->name;
}

const char * player_get_account(Player * player)
{
	return player->account;
}

void player_set_account(Player * player, const char * account)
{
	player->account = agSC_get(account, 0);
}

struct Hero * aL_hero_add(Player * player, unsigned int gid);
int player_get_level(Player * player)
{
	struct Hero * hero = hero_get(player, LEADING_ROLE, 0);
	if (hero == 0) {
		hero = aL_hero_add(player, LEADING_ROLE, REASON_CREATE_PLAYER);
	}

	if (0 == hero) {
		WRITE_WARNING_LOG("leading role is not exist, role id is %d, level is 0.", LEADING_ROLE);
		return 0;
	}

	/*if (hero->pid <= AI_MAX_ID) {
		FreshAIFightDataID(player);
		struct ai_info * aiinfo = GetAIInfo(player_get_id(player));
		if (aiinfo && aiinfo->fight_data_id != 0) {
			if (hero->level < aiinfo->fight_data_id % 1000) {
				int exp = get_exp_by_level(aiinfo->fight_data_id % 1000, 1);
				hero_add_normal_exp(hero, exp - hero->exp);
			}
		}
	}*/

	return hero->level;
}

int player_get_exp(Player * player)
{
	struct Hero * hero = hero_get(player, LEADING_ROLE, 0);
	if (hero == 0) {
		hero = aL_hero_add(player, LEADING_ROLE, REASON_CREATE_PLAYER);
	}
	
	if (0 == hero) {
		WRITE_WARNING_LOG("leading role is not exist, role id is %d, exp is 0.", LEADING_ROLE);
		return 0;
	}

	return hero->exp;
}

void * player_get_module(struct Player * player, int module)
{
	assert(player);
	assert(module < 0 || (size_t)module < player_modules_count);
	if (module < 0 || (size_t)module >= player_modules_count) {
		return 0;
	}

	void * data = player->module[module].data;
	if (data == 0) {
		data = _player_load_module(player, module);
	} 

	if (data) {
		// 用户数据需要更新到当前时间
		player->update_time = agT_current();
		_player_update_module(player, module, player->update_time);
	}
	return data;
}

Player * player_get_online(unsigned long long id)
{
	return agPM_GetOnline(id);
}

void player_set_conn(unsigned long long playerid, resid_t conn)
{
	if (conn == INVALID_ID) {
		agPM_SetOffline(playerid);
	} else {
		struct Player * player = player_get(playerid);
		if (player) {
			agPM_SetOnline(player, conn);
		}
	}
}
int64_t player_get_last_tick_time(Player* player){
	return player->last_tick_time;
}
void player_set_last_tick_time(Player* player, int64_t t){
	player->last_tick_time =t;
}
resid_t player_get_conn(unsigned long long playerid)
{
	Player * player = agPM_GetOnline(playerid);
	if (player == 0) {
		return INVALID_ID;
	}
	return player->conn;
}

void player_unload(Player * player)
{
	agPM_Release(player);
}

struct CheckData * player_get_check_data(Player * player)
{
	return player ? &(player->check) : 0;
}

////////////////////////////////////////////////////////////////////////////////
// PlayerManager
static int agPM_init(unsigned int max)
{
	player_not_exist = _agMap_new(0);
	player_online    = _agMap_new(0);
	player_offline   = _agMap_new(0);
	player_name      = _agMap_new(0);
	
	if (player_not_exist == 0 || player_online == 0 || player_offline == 0 || player_name == 0) {
		if (player_not_exist) { _agMap_delete(player_not_exist); player_not_exist = 0; }
		if (player_online) { _agMap_delete(player_online); player_online = 0; }
		if (player_offline) { _agMap_delete(player_offline); player_offline = 0; }
		if (player_name) { _agMap_delete(player_name); player_name = 0; }
		return -1;
	}
	return 0;
}

// 设置用户在线
static int agPM_SetOnline(struct Player * player, resid_t conn)
{
	if (player) {
		if (player->conn == INVALID_ID) {
			_agMap_ip_set(player_online, player->id, player);
			_agMap_ip_set(player_offline, player->id, 0);
		}

		player->conn = conn;
		try_remove_player_from_zombie_list(player);
	}
	return 0;
}

static int agPM_SetOffline(unsigned int id)
{
	struct Player * player = agPM_GetOnline(id);
	if (player) {
		assert(player->conn != INVALID_ID);
		_agMap_ip_set(player_offline, player->id, player);
		_agMap_ip_set(player_online, player->id, 0);
		player->conn = INVALID_ID;
		try_add_player_to_zombie_list(player);
	}
	return 0;
}


static struct Player * agPM_Create(unsigned long long id,		 // 创建用户
		const char * name,
		int head
		)
{
	if (id < RESERVED_ID) {
		return 0;
	}

	struct Player * player = (struct Player*)MALLOC(sizeof(struct Player));
	if (player == 0) {
		return 0;
	}
	memset(player, 0, sizeof(Player));

	player->id = id;
	strncpy(player->name, name, sizeof(player->name));

	if (_player_create(player, head) == 0) {
		FREE(player);
		return 0;
	}

	try_add_player_to_zombie_list(player);

	player->conn = INVALID_ID;
	_agMap_ip_set(player_offline, player->id, player);
	_agMap_sp_set(player_name, player->name, player);

	_agMap_ip_set(player_not_exist, player->id, 0);
	
	return _update_player_active_list(player);
}

// 获取
static struct Player * agPM_Get(unsigned long long id)
{
	if (id < RESERVED_ID) {
		return 0;
	}

	// 在线
	struct Player * player = (struct Player *)_agMap_ip_get(player_online, id);
	if (player) { 
		try_remove_player_from_zombie_list(player);
		return _update_player_active_list(player);
	}

	// 不在线，已经load
	player = (struct Player *)_agMap_ip_get(player_offline, id);
	if (player) {
		try_add_player_to_zombie_list(player);
		return _update_player_active_list(player);
	}

	// 5秒之内已知角色不存在
	time_t t = (time_t)_agMap_ip_get(player_not_exist, id);
	if (t + 5 >= agT_current()) {
		return 0;
	} else {
		_agMap_ip_set(player_not_exist, id, 0);
	}

	// load
	player = (struct Player*)MALLOC(sizeof(struct Player));
	printf("malloc %p\n", player);

	if (player == 0) {
		return 0;
	}

	memset(player, 0, sizeof(Player));
	player->id = id;
	((void)_player_load);

	if (_player_load_sample(player) == 0) {
		// TODO: 加载失败或者不存在
		FREE(player);

		WRITE_INFO_LOG("player %llu have no character", id);
		_agMap_ip_set(player_not_exist, id, (void*)(agT_current()));

		return 0;
	}

	try_add_player_to_zombie_list(player);
	
	player->conn = INVALID_ID;
	_agMap_ip_set(player_offline, player->id, player);
	_agMap_sp_set(player_name, player->name, player);

	return _update_player_active_list(player);
}

int      player_is_not_exist(unsigned long long id)
{
	void * p = _agMap_ip_get(player_not_exist, id);
	return p ? 1 : 0;
}


static int cbGetIDByName(struct slice * fields, void * ctx) 
{
	unsigned long long * pid = (unsigned long long *)ctx;

	if (pid && fields[0].ptr)
	{
		//unsigned int pid32 = atoll(fields[0].ptr);
		//TRANSFORM_PLAYERID_TO_64(*pid, AG_SERVER_ID, pid32);
		*pid = atoll((const char*)fields[0].ptr);
	}
	return 0;
}

// 获取
static unsigned long long agPM_GetIDByName(const char * name)
{
	struct Player * player = (struct Player*)_agMap_sp_get(player_name, name);
	if (player) {
		return player->id;
	}

	size_t len = strlen(name);
	char escape_name[2 * len + 1];
	database_escape_string(role_db, escape_name, name, len);

	unsigned long long pid = 0;
	if (database_query(role_db, cbGetIDByName, &pid, "select pid from property where name = '%s'", escape_name) != 0) {
		return 0;
	}
	return pid;
}

static void agPM_ChangeNameRecord(const char * old_name)
{
	struct Player * player = (struct Player*)_agMap_sp_get(player_name, old_name);
	if (player) {
		_agMap_sp_set(player_name, old_name, 0);

		const char * name = player_get_name(player);
		if (name != player->name) { strncpy(player->name, name, 32); }

		_agMap_sp_set(player_name, player->name, player);
	}
}

// 获取在线用户
static struct Player * agPM_GetOnline(unsigned long long id)
{
	struct Player * player = (struct Player *)_agMap_ip_get(player_online, id);

	try_remove_player_from_zombie_list(player);
	return _update_player_active_list(player);
}

// 释放用户
static void agPM_Release(struct Player * player)
{
	if (player->conn == INVALID_ID) {
		_agMap_ip_set(player_offline, player->id, 0);
	} else {
		_agMap_ip_set(player_online, player->id, 0);
	}
	_agMap_sp_set(player_name, player->name, 0);

	_player_release(player);


	assert(player->next);
	dlist_remove(player_active_list, player);
	try_remove_player_from_zombie_list(player);

	printf("free %p\n", player);
	FREE(player);
}

static int agPM_update(time_t now)
{
	return 0;	
}

static int agPM_free()
{
	while(player_active_list) {
		agPM_Release(player_active_list);
	}

	if (player_not_exist) { _agMap_delete(player_not_exist); player_not_exist = 0; }
	if (player_online) { _agMap_delete(player_online); player_online = 0; }
	if (player_offline) { _agMap_delete(player_offline); player_offline = 0; }
	if (player_name) { _agMap_delete(player_name); player_name = 0; }

	return 0;	
}

void try_add_player_to_zombie_list(Player* player){
	if(SUPPORT_ZOMBIE_LIST){
		if(!player) return;
		dlist_remove_with(player_zombie_list, player, zombie);
		dlist_init_with(player, zombie);
		dlist_insert_tail_with(player_zombie_list, player, zombie);
		player->zombie_time =agT_current();
		
		if(!player_zombie_table){
			player_zombie_table = _agMap_new(0);
		}
		_agMap_ip_set(player_zombie_table, player_get_id(player), player);		

		WRITE_DEBUG_LOG("add zombie `%llu`, time `%lld`", player_get_id(player), (long long)player->zombie_time);
	}
}
void try_remove_player_from_zombie_list(Player* player){
	if(SUPPORT_ZOMBIE_LIST){
		if(!player || !player_zombie_list) return;

		if(player_zombie_table){
			_agMap_ip_set(player_zombie_table, player_get_id(player), 0);		
		}
		dlist_remove_with(player_zombie_list, player, zombie);
		dlist_init_with(player, zombie);
	}
}
void try_unload_player_from_zombie_list(){
	if(SUPPORT_ZOMBIE_LIST){
		const time_t now =agT_current();
		while(player_zombie_list) {
			Player * cr =player_zombie_list;
			if((now - cr->zombie_time) <= YQ_MAX_ZOMBIE_TIME){
				break;
			}
			try_remove_player_from_zombie_list(cr);
			WRITE_DEBUG_LOG("remove zombie `%llu`, time `%lld`, elapse `%lld`", 
				player_get_id(cr), (long long)cr->zombie_time, (long long)(now - cr->zombie_time));
			player_unload(cr);
		}
	}
}
Player* get_player_from_zombie_list(unsigned long long pid){
	if(!SUPPORT_ZOMBIE_LIST) { return 0; }
	if(player_zombie_table == 0){ return 0; }
	Player* player =(Player*)_agMap_ip_get(player_zombie_table, pid);
	return player;
}

// PlayerManager
////////////////////////////////////////////////////////////////////////////////
