#include <stdlib.h>

#include "general.h"
#include "xmlHelper.h"
#include "logic_config.h"

#include "config_type.h"

#include "db_config/TABLE_born_item.h"
#include "db_config/TABLE_born_item.LOADER.h"

#define READ1(A) \
	generalConfig.A = atoll(xmlGetValue(xmlGetChild(root, #A, 0), "0"));

#define READ1F(A) \
	generalConfig.A = atof(xmlGetValue(xmlGetChild(root, #A, 0), "0"));

#define READ2(A,B) \
	generalConfig.A.B = atoll(xmlGetValue(xmlGetChild(root, #A, #B, 0), "0"));

#define READ2F(A,B) \
	generalConfig.A.B = atof(xmlGetValue(xmlGetChild(root, #A, #B, 0), "0"));

#define READ3(A,B,C) \
	generalConfig.A.B.C = atoll(xmlGetValue(xmlGetChild(root, #A, #B, #C, 0), "0"));

#define READ3F(A,B,C) \
	generalConfig.A.B.C = atof(xmlGetValue(xmlGetChild(root, #A, #B, #C, 0), "0"));

#define READ4(A,B,C,D) \
	generalConfig.A.B.C.D = atoll(xmlGetValue(xmlGetChild(root, #A, #B, #C, #D, 0), "0"));


#define READ4F(A,B,C,D) \
	generalConfig.A.B.C.D = atof(xmlGetValue(xmlGetChild(root, #A, #B, #C, #D, 0), "0"));

#define _GET_U32(node, name) atoll(xmlGetValue(xmlGetChild(node, name, 0), "0"))



struct CreatePlayerItem * create_player_item_head = 0;

static int parse_born_item(struct born_item * row)
{
	struct CreatePlayerItem * item = LOGIC_CONFIG_ALLOC(CreatePlayerItem, 1);
	item->next = create_player_item_head;
	create_player_item_head = item;
	
	item->type  = row->type;
	item->id    = row->id;
	item->value = row->value;
	item->pos   = row->position;

	return 0;
}

struct GeneralConfig generalConfig;
int load_general_config()
{
	memset(&generalConfig, 0, sizeof(generalConfig));
	const char * filename = "../etc/config/general.xml";
	xml_doc_t * doc; /* the resulting document tree */
	doc = xmlOpen(filename);

	if (doc == 0) {
		return -1;
	}

	xml_node_t * root = xmlDocGetRoot(doc);
	READ1(enable_reward_from_client);

	xmlClose(doc);

	create_player_item_head = 0;
	foreach_row_of_born_item(parse_born_item, 0);


	FILE * f = fopen("../log/enable_reward_from_client", "r");
	if (f != 0) {
		generalConfig.enable_reward_from_client = 1;
		fclose(f);
	}

	return 0;
}

struct GeneralConfig *  get_general_config()
{
	return &generalConfig;
}


struct CreatePlayerItem * get_create_player_item()
{
	return create_player_item_head;
}


