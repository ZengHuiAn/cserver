#include <assert.h>
#include <string.h>
#include "dlist.h"
#include "reward.h"
#include "database.h"
#include "log.h"
#include "mtime.h"
#include "notify.h"
#include "stringCache.h"
#include "config/reward.h"
#include "player.h"
#include "modules/property.h"
#include "modules/item.h"
#include "logic/aL.h"
#include "timeline.h"
#include "map.h"
#include "config/item.h"
#include "modules/hero.h"
#include "modules/hero_item.h"
#include "modules/equip.h"
#include "logic/aL.h"
#include "dispatch.h"

struct RewardWarper {
	struct RewardWarper * prev;
	struct RewardWarper * next;

	Reward * reward;
	RewardContent * content;

	unsigned int commit;
};

struct RewardCollection {
	struct RewardCollection * prev;
	struct RewardCollection * next;

	unsigned int from;

	struct RewardWarper * list;
};

typedef struct RewardData {
	struct RewardCollection * list;
	struct map * m;
	struct RewardWarper * autolist;
} RewardData;

//事件角色数据接口
void reward_init()
{
}

void * reward_new(Player * player)
{
	RewardData * set = (RewardData*)malloc(sizeof(RewardData));
	set->list = 0;
	set->m = _agMap_new(0);
	set->autolist = 0;

	return set;
}

static struct RewardCollection * getCollection(RewardData * set, unsigned int from, int create)
{
	if (set == 0) return 0;

	struct RewardCollection * collection = (struct RewardCollection*)_agMap_ip_get(set->m, from);
	if (collection == 0 && create ) {
		collection = (struct RewardCollection*)MALLOC(sizeof(struct RewardCollection));
		dlist_init(collection);
		collection->from = from;
		collection->list = 0;

		dlist_insert_tail(set->list, collection);
		_agMap_ip_set(set->m, from, collection);
	}	
	return collection;
}


static void addContentToWarper(struct RewardWarper * rw, struct RewardContent * content)
{
	dlist_insert_tail(rw->content, content);
}


static void addWarperToSet(struct RewardData * set, struct RewardWarper * rw)
{
	if (rw->reward->autorecv) {
		dlist_insert_tail(set->autolist, rw);
	} else {
		struct RewardCollection * collection = getCollection(set, rw->reward->reason, 1);
		dlist_insert_tail(collection->list, rw);
	}
}

static void removeWarperFromSet(struct RewardData * set, struct RewardWarper * rw)
{
	if (rw->reward->autorecv) {
		dlist_remove(set->autolist, rw);
	} else {
		struct RewardCollection * collection = getCollection(set, rw->reward->reason, 0);
		assert(collection);
		dlist_remove(collection->list, rw);
	}
}

static void freeWarper(struct RewardData * set, struct RewardWarper * rw, int dele);
static void freeCollection(RewardData * set, struct RewardCollection * collection)
{
	while(collection->list) {
		freeWarper(set, collection->list, 0);
	}

	_agMap_ip_set(set->m, collection->from, 0);
	dlist_remove(set->list, collection);

	FREE(collection);
}

static struct RewardWarper * newWarper(RewardData * set, struct Reward * reward, struct RewardContent * content)
{
	struct RewardWarper * rw = (struct RewardWarper *)MALLOC(sizeof(struct RewardWarper));
	dlist_init(rw);

	rw->reward  = reward;
	rw->content = content;
	rw->commit  = 1;

	// hack
	reward->prev = reward->next = (struct Reward*)rw;

	if (set) {
		addWarperToSet(set, rw);
	}
	return rw;
}


static void freeWarper(struct RewardData * set, struct RewardWarper * rw, int dele)
{
	if (rw == 0) {
		return;
	}

	if (set) {
		removeWarperFromSet(set, rw);
	}

	while(rw->content) {
		struct RewardContent * content = rw->content;
		dlist_remove(rw->content, content);

		if (dele && rw->commit) {
			DATA_RewardContent_delete(content);
		} else {
			DATA_RewardContent_release(content);
		}
	}

	if (dele && rw->commit) {
		DATA_Reward_delete(rw->reward);
	} else {
		DATA_Reward_release(rw->reward);
	}
	FREE(rw);
}

void * reward_load(Player * player)
{
	// load rewards
	struct Reward * rewards = 0;
	unsigned long long playerid = player_get_id(player);

	if (DATA_Reward_load_by_pid(&rewards, playerid) != 0) {
		return 0;
	}

	// load contents
	struct RewardContent  * contents = 0;
	if (DATA_RewardContent_load_by_pid(&contents, playerid) != 0) {
		while(rewards) {
			struct Reward * cur = rewards;
			rewards = cur->next;
			free(cur);
		}
		return 0;
	}

	// bulild set
	RewardData * set = (RewardData*)malloc(sizeof(RewardData));
	set->list = 0;
	set->m = _agMap_new(0);
	set->autolist = 0;

	// all rewardwarpers
	struct map * warpers = _agMap_new(0);

	while(rewards) {
		struct Reward * cur = rewards;
		rewards = cur->next;
		dlist_init(cur);

		if (cur->limit == 0) {
			cur->limit = agT_current() + 3600 * 24 * 365;
		}
	
		if (cur->limit <= agT_current()) {
			// 过期了 删除
			DATA_Reward_delete(cur);
			continue;
		}

		if (cur->get != 0) {
			// 领取过了 删除
			DATA_Reward_delete(cur);
			continue;
		}

		struct RewardWarper * rw = newWarper(set, cur, 0);

		_agMap_ip_set(warpers, cur->uuid, rw);
	}

	while(contents) {
		struct RewardContent * cur = contents;
		contents = cur->next;
		dlist_init(cur);

		struct RewardWarper * rw = (struct RewardWarper*)_agMap_ip_get(warpers, cur->id);
		if (rw == 0) {
			// 奖励记录不存在 删除
			DATA_RewardContent_delete(cur);
			continue;
		}

		addContentToWarper(rw, cur);
	}

	_agMap_delete(warpers);

	return set; 
}

int reward_update(Player * player, void * data, time_t now)
{
	// TODO: check timeout
	// TODO: autorecv
	struct RewardData * set = (struct RewardData*)data;
	struct RewardWarper * failed = 0;

	// auto recv
	while(set->autolist) {
		struct RewardWarper * rw = set->autolist;
		if (reward_receive(rw->reward, player, 0, 0) != 0) {
			dlist_remove(set->autolist, rw);
			dlist_insert_tail(failed, rw);
		}
	}
	set->autolist = failed;

	return 0;
}



int reward_save(Player * player, void * data, const char * sql, ... )
{
	unsigned long long pid = player_get_id(player);
	//unsigned int pid32 = 0;
	//TRANSFORM_PLAYERID(pid, 0, pid32);
	database_update(role_db, "delete from reward where pid = %llu", pid);
	database_update(role_db, "delete from rewardcontent where pid = %llu", pid);

	return 0;
}


void _free_reward_to_all();

int reward_release(Player * player, void * data)
{
	RewardData  * set = (RewardData*)data;

	while(set->list) {
		freeCollection(set, set->list);
	}

	_agMap_delete(set->m);
	free(set);

	return 0;
}

static int add_notify(struct Player * player)
{
	unsigned long long pid = player_get_id(player);
	amf_value * v = amf_new_array(0);

	struct Reward * reward = 0;
	while( (reward = reward_next(player, reward)) != 0) {
		amf_value * r = amf_new_array(2);
		amf_set(r, 0, amf_new_integer(reward->reason));
		amf_set(r, 1, amf_new_string(reward->name, 0));
		amf_push(v, r);
	}
	notification_set(pid, NOTIFY_REWARD_CHANGE, 0, v);
	return 0;
}

#define player_get_reward(player) (struct RewardData*)player_get_module(player, PLAYER_MODULE_REWARD)

int reward_remove(Reward * reward, Player * player)
{
	if (player == 0) {
		player = player_get(reward->pid);
	}

	struct RewardWarper * rw = (struct RewardWarper*)reward->next;
	RewardData * set         = player_get_reward(player);

	freeWarper(set, rw, 1);

	add_notify(player);

	return 0;
}

static struct RewardWarper * _reward_to_all = 0;


// 暂时不调用这个
void _free_reward_to_all()
{
	if (_reward_to_all) {
		freeWarper(0, _reward_to_all, 0);
		_reward_to_all = 0;
	}
}

// normal reward
Reward * reward_get(Player * player, unsigned int from)
{
	struct RewardData * set = player_get_reward(player);
	struct RewardCollection * collection = getCollection(set, from, 0);
	if (collection == 0) {
		return 0;
	} else {
		return collection->list ?  collection->list->reward : 0;
	}
}

Reward * reward_next(Player * player, Reward * reward)
{
	struct RewardData * set = player_get_reward(player);
	struct RewardCollection * curCollection = reward ? getCollection(set, reward->reason, 0) : 0;

	while( (curCollection = dlist_next(set->list, curCollection)) != 0) {
		if (curCollection->list == 0) {
			continue;
		}
		return curCollection->list->reward;
	}

	return NULL;
}

Reward * reward_create(unsigned int reason, unsigned int limit, unsigned int manual, const char * name)
{
	// 分配一个奖励数据，未实际加入，必须调用commit或者rollback
	WRITE_DEBUG_LOG("create reward, reason %u, limit %u, %s", reason, limit, manual ? "manual" : "auto");

	Reward * reward = (Reward*)malloc(sizeof(Reward));
	memset(reward, 0, sizeof(Reward));

	if (limit == 0) {
		// 无期限的奖励保存一年
		limit = agT_current() + 365 * 24 * 3600;
	}

	reward->reason = reason;
	reward->limit  = limit;
	reward->autorecv = !manual;
	reward->name = name ? agSC_get(name, 0) : "";

	struct RewardWarper * rw = newWarper(0, reward, 0);
	rw->commit = 0;
	return reward;
}

RewardContent * reward_add_content(Reward * reward, unsigned long long hero_uuid, unsigned int type, unsigned int key, unsigned int value)
{
	if (type == 0 || key == 0 || value == 0) {
		return 0;
	}

	struct RewardWarper * rw = (struct RewardWarper*)reward->next;
	RewardContent * content = (RewardContent*)malloc(sizeof(RewardContent));
	memset(content, 0, sizeof(RewardContent));

	content->id  = reward->uuid;
	content->pid = reward->pid;

	content->type  = type;
	content->key   = key;
	content->value = value;
	content->uid   = hero_uuid;

	if ((rw->commit) && DATA_RewardContent_new(content) != 0) {
		free(content);
		return 0;
	}

	dlist_init(content);
	dlist_insert_tail(rw->content, content);
	return content;
}

int reward_commit(Reward * reward, unsigned long long pid, struct RewardItem * record, int nitem)
{
	struct RewardWarper * rw = (struct RewardWarper*)reward->next;
	if (rw->commit) { return 0; }
	assert(reward->uuid == 0);
	assert(reward->pid  == 0);

	reward->pid = pid;

	struct Player * player = 0;
	if (pid > 0) {
		player = player_get_online(pid);
		if(!player){
			player =get_player_from_zombie_list(pid);
			if(player){
				WRITE_DEBUG_LOG("call get_player_from_zombie_list(%llu)", pid);
			}
		}
		if (player) {
			// load reward before commit, must do it
			((void)player_get_reward(player));
		}
	}

	// try to recv
	if (reward->autorecv && player) {
		struct RewardContent * failed = 0;
		while(rw->content) {
			struct RewardContent * content = rw->content;
			dlist_remove(rw->content, content);

			if (reward_add_one(player, content, reward->reason, record, nitem) != 0) {
				dlist_insert_tail(failed, content);
			} else {
				// 还未操作数据库
				free(content);
			}
		}

		if (failed == 0) {
			freeWarper(0, rw, 0);
			return 0;
		}
		rw->content = failed;
	}

	struct RewardContent * done = 0;

	// write reward to db, get uuid
	if (DATA_Reward_new(reward) != 0) {
		goto failed;
	}
	
	// write content to db
	while(rw->content) {
		struct RewardContent * content = rw->content;
		dlist_remove(rw->content, content);

		content->id = reward->uuid;
		content->pid = pid;

		if (DATA_RewardContent_new(content) != 0) {
			dlist_insert_tail(rw->content, content);
			DATA_Reward_delete(reward);
			goto failed;
		}
		dlist_insert_tail(done, content);
	}
	rw->content = done;
	rw->commit  = 1;

	if (player) {
		struct RewardData * set = player_get_reward(player);
		addWarperToSet(set, rw);
		if (rw->next == rw) {
			add_notify(player);
		}
	} else if (pid == 0) {
		// 全体奖励  加入列表
		dlist_insert_tail(_reward_to_all, rw);
	} else {
		freeWarper(0, rw, 0);
	}
	return 0;
failed:
	// delete data which saved
	while(done) {
		struct RewardContent * content = done;
		dlist_remove(done, content);
		DATA_RewardContent_delete(content);
	}

	// delete other data
	reward_rollback(reward);
	return -1;
}


int reward_rollback(Reward * reward)
{
	struct RewardWarper * rw = (struct RewardWarper*)reward->next;
	if (rw->commit) { return 0; }
	// assert(reward->uuid == 0);

	freeWarper(0, rw, 0);
	return 0;
}

static void append_reward_record(struct RewardItem * record, int nitem, int type, int id, int value, unsigned long long uuid)
{
	int i;
	for (i = 0; i < nitem; i++) {
		if ( (record[i].type == type && record[i].id  == id && uuid == 0) || record[i].type == 0) {
			record[i].value = record[i].value + value;
			record[i].uuid  = uuid;
			return;
		}
	}
}

int reward_add_one(struct Player * player, struct RewardContent * content, int reason, struct RewardItem * record, int nitem)
{
	if(content->value <= 0){
		WRITE_WARNING_LOG("%s content value is %d", __FUNCTION__, (int)content->value);
		return 0;
	}
	int result =0;
	switch(content->type) {
		case REWARD_TYPE_ITEM: 
			result =item_add(player, content->key, content->value, reason) ? 0 : -1;
			append_reward_record(record, nitem, content->type, content->key, content->value, 0);
			break;
		case REWARD_TYPE_HERO:
			{
				struct Hero * hero = aL_hero_add(player, content->key, reason);
				result = hero ? RET_SUCCESS : RET_ERROR;
				if (hero) {
					append_reward_record(record, nitem, content->type, content->key, content->value, hero->uuid);
				}
			}
			break;
		case REWARD_TYPE_EQUIP:
		case REWARD_TYPE_INSCRIPTION:
			{
				unsigned int index = 0;
				for (; index < content->value; ++index)
				{
					int id = 0, quality = 0;	// id 用来记录到底是守护还是芯片
					unsigned long long uuid = 0;
					if (0 != aL_equip_add(player, content->key, &id, &quality, &uuid)) {
						break;
					}
					append_reward_record(record, nitem, content->type, content->key, 1, uuid);

					if (quality >= 3) {		// 紫色品质以上
						amf_value * v = amf_new_array(4);
						amf_push(v, amf_new_integer(id));
						amf_push(v, amf_new_string(player_get_name(player), 0));
						amf_push(v, amf_new_integer(content->key));
						amf_push(v, amf_new_integer(quality));

						char msg[1024] = { 0 };
						int32_t size = 0;
						size = amf_encode(msg, sizeof(msg), v);
						/* 增加全服公告 */	
						broadcast_to_client(C_PLAYER_DATA_CHANGE, 1, msg, size, 0, NULL);
						amf_free(v);	
					}
				}
			}
			break;
		case REWARD_TYPE_ITEM_PACKAGE:
			{
				result =0;
				unsigned int j =0;
				for(j =0; j<content->value; j++){
					int32_t depth =0;
					if(0 != aL_open_item_package(player, content->key, reason, &depth, record, nitem)){
						result =-1;
						break;
					}
				}
			}
			break;
		case REWARD_TYPE_HEROITEM:
			if (content->key != 0) {
				if (content->key == 90000) {
					struct Hero * hero = hero_get(player, LEADING_ROLE, 0);
					result = hero_add_normal_exp(hero, content->value);
				} else {
					result = hero_item_add(player, content->uid, content->key, content->value, reason, 0);
				}
			} else {
				struct Hero * hero = hero_get(player, 0, content->uid);
				if (hero) {
					result = hero_add_normal_exp(hero, content->value);
				} else {
					WRITE_WARNING_LOG(" hero %llu not exists", content->uid);
					result = -1;
				}
			}
			append_reward_record(record, nitem, content->type, content->key, content->value, 0);
			break;
		case REWARD_TYPE_BUFF:
			if (content->key != 0) {
				unsigned long long playerid = player_get_id(player);
				aL_add_buff(playerid, content->key, content->value);
				append_reward_record(record, nitem, content->type, content->key, content->value, 0);
				result = RET_SUCCESS;
			}
			break;
		case REWARD_TYPE_DROP:
			if (content->key != 0) {
				struct DropInfo info[1];
				info[0].id = content->key;
				info[0].level = 0;
				unsigned int j;
				for(j =0; j<content->value; j++){
					aL_send_drop_reward(player, info, 1, record, nitem, 0, 0, 0, 1, reason);
				}
				result = RET_SUCCESS;
			}
			break;

		default:
			WRITE_WARNING_LOG("unknown content type %u, id %u, value %u", content->type, content->key, content->value);
			result =-1;
			break;
	}
	return result;
}

int reward_receive(Reward * reward, Player * player, struct RewardContent * rcontent, size_t n)
{
	if (player == 0 || reward == 0) {
		return -1;
	}

	struct RewardWarper * rw = (struct RewardWarper*)reward->next;
	RewardData * set = player_get_reward(player);

	int done = 0;
	int ret = 0;

	struct RewardContent * failed = 0;
	while(rw->content) {
		struct RewardContent * content = rw->content;
		dlist_remove(rw->content, content); 

		if ((rcontent && (size_t)done >= n) ||
				reward_add_one(player, content, reward->reason, 0, 0) != 0) {
			dlist_insert_tail(failed, content);
			ret =-1;
			continue;
		} else {
			if(rcontent){
				rcontent[done].type  = content->type;
				rcontent[done].key   = content->key;
				rcontent[done].value = content->value;
				done ++;
			}

			if (reward->pid > 0) {
				DATA_RewardContent_delete(content);
			} else {
				dlist_insert_tail(failed, content);
			}
		}
	}

	if (reward->pid > 0 && failed) {
		// 部分奖励未发送
		rw->content = failed;
		return ret;
	} 

	if (reward->pid == 0) {
		// 全员礼包，直接返回
		rw->content = failed;
	} else {
		unsigned int autorecv = rw->reward->autorecv;

		freeWarper(set, rw, 1);

		if (!autorecv) {
			struct RewardCollection * collection = getCollection(set, reward->reason, 0);
			// no reward of this type any more
			if (collection && collection->list == 0) {
				add_notify(player);
			}
		}
	}
	return 0;
}
