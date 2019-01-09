#ifndef _A_GAME_WORLD_CONFIG_ITEM_PACKAGE_H_
#define _A_GAME_WORLD_CONFIG_ITEM_PACKAGE_H_

#include <stdint.h>
//#include "../fight_type.h"
#include "pbc_int64.h"
#include "amf.h"

/* macro */

/* type */
typedef struct tagITEM{
	struct tagITEM* next;
	int64_t type;
	int64_t id;
	int64_t value;
}ITEM, *PITEM;

typedef struct tagCITEM{
	struct tagCITEM* next;
	int64_t type;
	int64_t id;
	int64_t value;
	int priority;
}CITEM, *PCITEM;

typedef struct tagITEM_PACKAGE{
	int64_t package_id;
	PITEM item_list;
}ITEM_PACKAGE, *PITEM_PACKAGE;

typedef struct tagCITEM_PACKAGE{
	int64_t package_id;
	PCITEM item_list;
}CITEM_PACKAGE, *PCITEM_PACKAGE;


/* loader */
int load_item_package_config();
	
/* query */
int load_item_package_config();
PITEM_PACKAGE get_item_package_config(int64_t package_id);
void set_item_package(struct pbc_rmessage* desc);
void del_item_package(const int64_t package_id);
void item_package_foreach(void (*func)(uint64_t key, void *p, void * ctx), void* ctx);
amf_value* item_tuple_to_amf(const int64_t type, const int64_t id, const int64_t value);

PCITEM_PACKAGE get_consume_item_package_config(int package_id);

#endif
