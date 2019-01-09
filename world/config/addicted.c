#include <stdlib.h>
#include <string.h>

#include "xmlHelper.h"

#include "logic_config.h"
#include "addicted.h"

static AddictedConfig addictedConfig;
static int loadAddictedConfig();

int load_addicted_config()
{
	if (loadAddictedConfig() != 0 ) {
		return -1;
	}
	return 0;
}

AddictedConfig * get_addicted_config()
{
	return &addictedConfig;
}


#define ATOLL(x) ((x) ? atoll(x) : 0)

static int loadAddictedConfig()
{
	xml_doc_t * doc; /* the resulting document tree */

	doc = xmlOpen("../log/addicted.xml");
	if (doc == 0) {
		doc = xmlOpen("../etc/config/addicted.xml");
	}
	if (doc == 0){
		memset(&addictedConfig, 0, sizeof(addictedConfig));
		return 0;
	}

	xml_node_t * root = xmlDocGetRoot(doc);

	memset(&addictedConfig, 0, sizeof(addictedConfig));
	addictedConfig.enable     = atoi(xmlGetValue(xmlGetChild(root, "Enable", 0), "0"));
	addictedConfig.kickTime   = 3600 * atof(xmlGetValue(xmlGetChild(root, "KickTime", 0), "3")); 
	addictedConfig.notifyTime = 3600 * atof(xmlGetValue(xmlGetChild(root, "NotifyTime", 0), "1")); 
	addictedConfig.restTime   = 3600 * atof(xmlGetValue(xmlGetChild(root, "RestTime", 0), "5")); 
	strncpy(addictedConfig.notifyMessage, xmlGetValue(xmlGetChild(root, "NotifyMessage", 0), ""), sizeof(addictedConfig.notifyMessage) - 1);

	// printf("%d, %d, %d, %s\n", addictedConfig.enable, addictedConfig.kickTime, addictedConfig.notifyTime, addictedConfig.notifyMessage);

	xmlClose(doc);

	return 0;
}

