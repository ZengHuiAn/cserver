#ifndef _A_GAME_COMM_XML_HELPER_H_
#define _A_GAME_COMM_XML_HELPER_H_

#include <assert.h>
#include <string.h>

typedef struct xml_node_t xml_node_t;
typedef struct xml_doc_t  xml_doc_t;

xml_doc_t  * xmlOpen(const char * file);
void         xmlClose(xml_doc_t * doc);

xml_node_t * xmlDocGetRoot(xml_doc_t * doc);

const char * xmlGetName(xml_node_t * node);
const char * xmlGetAttribute(xml_node_t * node, const char * attribute, const char * def);
const char * xmlGetValue(xml_node_t * node, const char * def);

unsigned int xmlGetAttributeCount(xml_node_t * node);
const char * xmlGetAttributeN(xml_node_t * node, unsigned int n, const char ** key);

xml_node_t * xmlGetFirstChild(xml_node_t * node);
xml_node_t * xmlGetNextSibling(xml_node_t * node);

xml_node_t * xmlGetChild_(xml_node_t * node, ...);
#define xmlGetChild(...) xmlGetChild_(__VA_ARGS__, 0)
int foreachChildNodeWithName(xml_node_t * node, const char * name, int (*cb)(xml_node_t *, void *), void *data);

#endif 
