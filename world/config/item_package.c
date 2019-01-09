#include <stdlib.h>

#include <string.h>

#include "xmlHelper.h"
#include "logic_config.h"
#include "config/item_package.h"
#include "config/reward.h"
#include "dlist.h"
#include "database.h"
#include "map.h"

#include "config_type.h"
#include "../db_config/TABLE_consume_package.h"
#include "../db_config/TABLE_consume_package.LOADER.h"


#define ATOLL(x) ((x) ? atoll(x) : 0)
#define _GET_I32(node, name) ATOLL(xmlGetValue(xmlGetChild(node, name, 0), "0"))
#define _GET_I64(node, name) ATOLL(xmlGetValue(xmlGetChild(node, name, 0), "0"))
#define _GET_STR(node, name) xmlGetValue(xmlGetChild(node, name, 0), "")

/* load */
static struct map * item_package_map = 0;
static struct map * consume_item_package_map = 0;
static int _add_item_to_package(const int64_t package_id, const int64_t type, const int64_t id, int64_t value){
	/* try new item package */
	PITEM_PACKAGE cfg = (PITEM_PACKAGE)_agMap_ip_get(item_package_map, package_id);
	if(0 == cfg){
		cfg =(PITEM_PACKAGE)malloc(sizeof(ITEM_PACKAGE));
		memset(cfg, 0, sizeof(ITEM_PACKAGE));
		cfg->package_id =package_id;
		_agMap_ip_set(item_package_map, package_id, cfg);
	}

	// new item
	PITEM item =(PITEM)malloc(sizeof(ITEM));
	memset(item, 0, sizeof(ITEM));
	item->type  = type;
	item->id    = id;
	item->value = value;

	// push front
	item->next =cfg->item_list;
	cfg->item_list =item;

	return 0;
}
static int _parse_item_package(struct slice * fields, void * ctx){
	const int64_t package_id    = atoll((const char*)fields[0].ptr);
	const int64_t type          = atoll((const char*)fields[1].ptr);
	const int64_t id            = atoll((const char*)fields[2].ptr);
	const int64_t value         = atoll((const char*)fields[3].ptr);
	return _add_item_to_package(package_id, type, id, value);
}
int load_item_package_config(){
	// prepare
	item_package_map = LOGIC_CONFIG_NEW_MAP();
	if(database_query(role_db, _parse_item_package, 0, "select `package_id`, `item_type`, `item_id`, `item_value` from `item_package_config`") != 0){
		return -1;
	}
	return 0;
}

static int _add_item_to_consume_package(const int64_t package_id, const int64_t type, const int64_t id, int64_t value, int priority){
	/* try new item package */
	PCITEM_PACKAGE cfg = (PCITEM_PACKAGE)_agMap_ip_get(consume_item_package_map, package_id);
	if(0 == cfg){
		cfg =(PCITEM_PACKAGE)malloc(sizeof(CITEM_PACKAGE));
		memset(cfg, 0, sizeof(CITEM_PACKAGE));
		cfg->package_id =package_id;
		_agMap_ip_set(consume_item_package_map, package_id, cfg);
	}

	// new item
	PCITEM item =(PCITEM)malloc(sizeof(CITEM));
	memset(item, 0, sizeof(CITEM));
	item->type  = type;
	item->id    = id;
	item->value = value;
	item->priority = priority;

	if (cfg->item_list == 0 || priority <= cfg->item_list->priority) {
		WRITE_DEBUG_LOG("bbbbbbbbbb");
		item->next = cfg->item_list;
		cfg->item_list = item;		
	} else {
		WRITE_DEBUG_LOG("ccccccc");
		PCITEM ite = cfg->item_list;
		while(ite->next && ite->next->priority <= priority) {
			ite = ite->next;
		}

		item->next = ite->next;
		ite->next = item;
	}

	return 0;
}

static int _parse_consume_item_package(struct consume_package * row){
	const int package_id    = row->package_id;
	const int type          = row->item_type;
	const int id            = row->item_id;
	const int value         = row->item_value;
	const int priority          = row->priority;
	return _add_item_to_consume_package(package_id, type, id, value, priority);
}

int load_consume_item_package_config(){
	// prepare
	consume_item_package_map = LOGIC_CONFIG_NEW_MAP();
		
	if (foreach_row_of_consume_package(_parse_consume_item_package, 0) != 0) {
		return -1;	
	}

	return 0;
}

/* query */
PITEM_PACKAGE get_item_package_config(int64_t package_id){
	if(!package_id) return 0;

	if (item_package_map == 0) { load_item_package_config(); }

	PITEM_PACKAGE pkg_cfg = (PITEM_PACKAGE)_agMap_ip_get(item_package_map, package_id);
	return pkg_cfg;
}
void set_item_package(struct pbc_rmessage* desc){
	const int64_t package_id =pbc_rmessage_int64(desc, "package_id", 0);

	// del old
	del_item_package(package_id);

	// add new
	const int64_t item_cnt = pbc_rmessage_size(desc, "item");
	int64_t i=0;
	for(i=0; i<item_cnt; i++){
		struct pbc_rmessage* item =pbc_rmessage_message(desc, "item", i);
		if(!item){
			WRITE_WARNING_LOG("%s: pbc_rmessage_message return 0", __FUNCTION__);
			continue;
		}
		const int64_t type  =pbc_rmessage_int64(item, "type", 0);
		const int64_t id    =pbc_rmessage_int64(item, "id", 0);
		const int64_t value =pbc_rmessage_int64(item, "value", 0);
		if(0 == _add_item_to_package(package_id, type, id, value)){
			database_update(role_db, "INSERT INTO `item_package_config`(`package_id`, `item_type`, `item_id`, `item_value`)VALUES(%lld, %lld, %lld, %lld)"
					, (long long)package_id, (long long)type, (long long)id, (long long)value);
		}
	}
}
void del_item_package(const int64_t package_id){
	if (item_package_map == 0) { load_item_package_config(); }

	PITEM_PACKAGE cfg = (PITEM_PACKAGE)_agMap_ip_get(item_package_map, package_id);
	if(!cfg) return;
	
	PITEM node =cfg->item_list;
	while(node){
		PITEM next =node->next;
		free(node);
		node =next;
	}
	free(cfg);
	_agMap_ip_set(item_package_map, package_id, 0);
	database_update(role_db, "DELETE FROM `item_package_config` WHERE `package_id`=%lld", (long long)package_id);
}
void item_package_foreach(void (*func)(uint64_t key, void *p, void * ctx), void* ctx){
	if (item_package_map == 0) { load_item_package_config(); }

	_agMap_ip_foreach(item_package_map, func, ctx);
}
amf_value* item_tuple_to_amf(const int64_t type, const int64_t id, const int64_t value){
	if (item_package_map == 0) { load_item_package_config(); }

	if(type == REWARD_TYPE_ITEM_PACKAGE){
		amf_value* ret =amf_new_array(0);
		PITEM_PACKAGE cfg = (PITEM_PACKAGE)_agMap_ip_get(item_package_map, id);
		if(!cfg){
			WRITE_ERROR_LOG("fail to call %s, item package `%lld` not exist", __FUNCTION__, (long long)id);
			return ret;
		}

		PITEM node =cfg->item_list;
		while(node){
			PITEM next =node->next;

			amf_value* item =amf_new_array(3);
			amf_set(item, 0, amf_new_integer(node->type));
			amf_set(item, 1, amf_new_integer(node->id));
			amf_set(item, 2, amf_new_integer(node->value));
			amf_push(ret, item);

			node =next;
		}
		return ret;	
	}
	else{
		amf_value* item =amf_new_array(3);
		amf_set(item, 0, amf_new_integer(type));
		amf_set(item, 1, amf_new_integer(id));
		amf_set(item, 2, amf_new_integer(value));

		amf_value* ret =amf_new_array(1);
		amf_set(ret, 0, item);
		return ret;
	}
}

PCITEM_PACKAGE get_consume_item_package_config(int package_id){
	if(!package_id) return 0;

	if (consume_item_package_map == 0) { load_consume_item_package_config(); }

	PCITEM_PACKAGE pkg_cfg = (PCITEM_PACKAGE)_agMap_ip_get(consume_item_package_map, package_id);
	return pkg_cfg;
}

