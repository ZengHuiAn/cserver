#include <string.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdint.h>
#include <libgen.h>

#include "config.h"
#include "xmlHelper.h"

char cfile[256] = {0};
static xml_doc_t * _doc = 0;

int agC_open(const char * file)
{
	if (_doc) {
		xmlClose(_doc);
	}

	if (file) {
		strcpy(cfile, file);
		_doc = xmlOpen(cfile);
		return _doc ? 0 : -1;
	} else {
		cfile[0] = 0;
	}
	return 0;
}

void agC_close()
{
	if (_doc) {
		xmlClose(_doc);
	}
}

xml_node_t * agC_vget(const char * key, va_list args)
{
	xml_node_t * node = xmlDocGetRoot(_doc);
	while(key && node) {
		node = xmlGetChild(node, key, 0);

		key = va_arg(args, const char *);
	}
	return node;
}

int32_t agC_get_server_id()
{
	xml_node_t * node = xmlDocGetRoot(_doc);
	if(node){
		int32_t server_id =atol(xmlGetAttribute(node, "id", "0"));
		return server_id;
	}
	return 0;
}

int32_t agC_get_version()
{
	xml_node_t * node = xmlDocGetRoot(_doc);
	if(node){
		int32_t version =atol(xmlGetAttribute(node, "version", "2"));
		return version;
	}
	return 2;
}
xml_node_t * agC_get_l(const char * key, ...)
{

	va_list args;
	va_start(args, key);
	
	xml_node_t * node = agC_vget(key, args);

	va_end(args);
	return node;
}

int agC_get_integer(const char * key, ...)
{
	va_list args;
	va_start(args, key);
	
	xml_node_t * node = agC_vget(key, args);

	va_end(args);


	if (node) {
		return atoi(xmlGetValue(node, 0));
	}
	return 0;
}

const char * agC_get_string(const char * key, ...)
{
	va_list args;
	va_start(args, key);
	
	xml_node_t * node = agC_vget(key, args);

	va_end(args);


	if (node) {
		return xmlGetValue(node, 0);
	}
	return 0;
}
