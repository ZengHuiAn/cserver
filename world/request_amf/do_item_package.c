#include <assert.h>
#include <string.h>

#include "network.h"
#include "log.h"
#include "message.h"
#include "player.h"
#include "package.h"
#include "amf.h"
#include "mtime.h"
#include "build_message.h"
#include "config/item_package.h"

#include "logic/aL.h"
#define _GET_I32(node, name) ATOLL(xmlGetValue(xmlGetChild(node, name, 0), "0"))

void do_query_item_package(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_PARAM(conn, playerid, v, 2, C_QUERY_ITEM_PACKAGE_RESPOND);
	const int32_t package_id = amf_get_integer(amf_get(v, 1));
	WRITE_INFO_LOG("playe %llu query item package %d", playerid, package_id);
	
	PITEM_PACKAGE pkg_cfg =get_item_package_config(package_id);
	if(!pkg_cfg){
		WRITE_INFO_LOG("playe %llu fail to query item package %d, not exist", playerid, package_id);
		SEND_RESPOND(conn, playerid, cmd, sn, RET_NOT_EXIST, 0);
		return;
	}
	amf_value* respond =amf_new_array(3);
	amf_set(respond, 0, amf_new_integer(sn));
	amf_set(respond, 1, amf_new_integer(RET_SUCCESS));
	amf_value* item_list =amf_new_array(0);
	amf_set(respond, 2, item_list);

	PITEM item =pkg_cfg->item_list;
	while(item){
		amf_value* v =amf_new_array(3);
		amf_set(v, 0, amf_new_integer(item->type));
		amf_set(v, 1, amf_new_integer(item->id));
		amf_set(v, 2, amf_new_integer(item->value));
		amf_push(item_list, v);
			
		// next
		item =item->next;
	}
	
	send_amf_message(conn, playerid, cmd, respond);
	amf_free(respond); 
}

void do_query_consume_item_package(resid_t conn, unsigned long long playerid, amf_value * v)
{
	CHECK_PARAM(conn, playerid, v, 2, C_QUERY_CONSUME_ITEM_PACKAGE_RESPOND);
	const int32_t package_id = amf_get_integer(amf_get(v, 1));
	WRITE_INFO_LOG("player %llu query consume item package %d", playerid, package_id);
	
	PCITEM_PACKAGE pkg_cfg =get_consume_item_package_config(package_id);
	if(!pkg_cfg){
		WRITE_INFO_LOG("player %llu fail to query consume item package %d, not exist", playerid, package_id);
		SEND_RESPOND(conn, playerid, cmd, sn, RET_NOT_EXIST, 0);
		return;
	}
	amf_value* respond =amf_new_array(3);
	amf_set(respond, 0, amf_new_integer(sn));
	amf_set(respond, 1, amf_new_integer(RET_SUCCESS));
	amf_value* item_list =amf_new_array(0);
	amf_set(respond, 2, item_list);

	PCITEM item =pkg_cfg->item_list;
	while(item){
		amf_value* v =amf_new_array(4);
		amf_set(v, 0, amf_new_integer(item->type));
		amf_set(v, 1, amf_new_integer(item->id));
		amf_set(v, 2, amf_new_integer(item->value));
		amf_set(v, 3, amf_new_integer(item->priority));
		amf_push(item_list, v);
			
		// next
		item =item->next;
	}
	
	send_amf_message(conn, playerid, cmd, respond);
	amf_free(respond); 
}
