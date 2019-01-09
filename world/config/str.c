#include <stdlib.h>
#include <string.h>

#include "memory.h"
#include "xmlHelper.h"

#include "log.h"
#include "map.h"
#include "logic_config.h"

static struct map * str_map = 0;

static char * 
xml_get(xml_node_t * node, const char * k){
    const char * xml_char = xmlGetValue(xmlGetChild(node, k, 0), "");
    char * heap_char = (char*)malloc(sizeof(char) * (strlen(xml_char)+1));
    strcpy(heap_char, xml_char);
    return heap_char;
}

static int 
parseStrConfig(xml_node_t * node, void * ctx) {
	const char * k = (const char*)xml_get(node, "key");
	char * v = xml_get(node, "value");
	void * p = _agMap_sp_set(str_map, k, v);
	if (p) {
		WRITE_ERROR_LOG("%s same str %s %s", __FUNCTION__, k, v);
		return -1;
	}
    return 0;
}

static int 
loadStrConfig() {
	const char * filename = "../etc/config/str.xml";
	xml_doc_t * doc; /* the resulting document tree */

	doc = xmlOpen(filename);
	if (doc == 0) {
		return -1;
	}
	xml_node_t * root = xmlDocGetRoot(doc);
	int ret = foreachChildNodeWithName(root, "Item", parseStrConfig, 0);
	xmlClose(doc);
	return ret;
}

const char *
str_get(const char * k){
    const char * v = (const char*)_agMap_sp_get(str_map, k);
    return  v ? v : "";
}

int 
load_str_config() { 
    str_map =  LOGIC_CONFIG_NEW_MAP();
    return loadStrConfig();
}
