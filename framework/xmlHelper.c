#include <assert.h>
#include <string.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#include "xmlHelper.h"
//#include <libxml/parser.h>
//#include <libxml/tree.h>
//

#include "mxml.h"

#define MALLOC(s) ((s*)malloc(sizeof(s)))

struct xml_node_t {
	xml_node_t * next;

	mxml_node_t * node;

	xml_node_t * child;
};

static int isComment(mxml_node_t * node) 
{
	const char * name = mxmlGetElement(node);
	if (strncmp(name, "!--", 3) == 0) {
		return 1;
	}
	return 0;
}

static xml_node_t * newNode(mxml_node_t * node)
{
	xml_node_t * n = MALLOC(xml_node_t);
	n->next = 0;
	n->child = 0;
	n->node = node;

	xml_node_t * tail = 0;

	mxml_node_t * child = mxmlGetFirstChild(node);
	for(;child; child = mxmlGetNextSibling(child)) {
		mxml_type_t type = mxmlGetType (child);
		if (type != MXML_ELEMENT) { continue; }
		if (isComment(child)) { continue; }

		xml_node_t * nc = newNode(child);
		if (tail == 0) {
			n->child = nc;
			tail = nc;
		} else {
			tail->next = nc;
			tail = nc;
		}
	}
	return n;
}

static void freeNode(xml_node_t * node)
{
	while(node->child) {
		xml_node_t * c = node->child;
		node->child = c->next;
		freeNode(c);
	}
	free(node);
}


struct xml_doc_t {
	FILE * fp;
	mxml_node_t * tree;
	xml_node_t * root;
};


xml_doc_t  * xmlOpen(const char * file)
{
	FILE * fp = fopen(file, "rb");
	if (fp == 0) {
		return 0;
	}

	xml_doc_t * doc = MALLOC(xml_doc_t);
	doc->fp = fp;
	doc->tree = mxmlLoadFile(NULL, fp, MXML_TEXT_CALLBACK);
	doc->root = newNode(doc->tree);
	return doc;
}

void xmlClose(xml_doc_t * doc)
{
	if (doc) {
		if (doc->fp) fclose(doc->fp);
		if (doc->tree) mxmlDelete(doc->root->node);
		if (doc->root) freeNode(doc->root);
		free(doc);
	}
}

xml_node_t * xmlDocGetRoot(xml_doc_t * doc)
{
	if (doc == 0) return 0;

	return doc->root;
}

const char * xmlGetName(xml_node_t * node)
{
	if (node == 0) return 0;
	return mxmlGetElement(node->node);
}

static const char * translateEnv(const char * text)
{
    static char output[1024];
    int find = 0;
    if (text) {
        int i = 0, j = 0;
        for (i = 0; text[i]; i++, j++) {
            if (text[i] == '$') {
                find = 1;
                char name[256];
                int x =  i + ( (text[i+1] == '{') ? 2 : 1 );
                int y = 0;
                for (;(isalnum(text[x]) || text[x] == '_') && y < 255; x++, y++) {
                    name[y] = text[x];
                }
                name[y] = 0;

				if (text[x] == '}' && text[i+1] == '{') {
					x += 1;
				}
                i = x - 1;

                const char * value = getenv(name);
                if (value) {
                    strcpy(output + j, value);
                    j += strlen(value) - 1;
                } else {
					--j;
				}
            } else {
                output[j]  = text[i];
            }
        }
        output[j] = 0;
    }

    return find ? output: text;
}

const char * xmlGetAttribute(xml_node_t * node, const char * attribute, const char * def)
{
	if (node == 0) return def;
	const char * ptr = mxmlElementGetAttr(node->node, attribute);
	return ptr ? translateEnv(ptr) : def;
}

const char * xmlGetValue(xml_node_t * node, const char * def)
{
	if (node == 0) return def;
	const char * text = mxmlGetText(node->node, 0);
	return text ? translateEnv(text) : def;
}

xml_node_t * xmlGetFirstChild(xml_node_t * node)
{
	return node ? node->child : 0;
}

xml_node_t * xmlGetNextSibling(xml_node_t * node)
{
	return node->next;
}

static xml_node_t * _xmlGetChild(xml_node_t * node, const char * name) 
{
	xml_node_t * child = xmlGetFirstChild(node);
	for(child = xmlGetFirstChild(node); child; child = xmlGetNextSibling(child)) {
		const char * cname = xmlGetName(child);
		if (strcmp(cname, name) == 0) {
			return child;
		}
	}
	return 0;
}

xml_node_t * xmlGetChild_(xml_node_t * node, ...)
{
	va_list args;
	va_start(args, node);

	while(node) {
		const char * name = va_arg(args, const char *);
		if (name == 0) { break; }

		node = _xmlGetChild(node, name);
	}
	va_end(args);
	return node;
}

#define xmlGetChild(...) xmlGetChild_(__VA_ARGS__, 0)

int foreachChildNodeWithName(xml_node_t * node, const char * name, int (*cb)(xml_node_t *, void *), void *data)
{
	xml_node_t * child = xmlGetFirstChild(node);
	for(child = xmlGetFirstChild(node); child; child = xmlGetNextSibling(child)) {
		const char * cname = xmlGetName(child);
		if (name == 0 || strcmp(cname, name) == 0) {
			if(cb(child, data) != 0) {
				return -1;
			}
		}
	}
	return 0;
}

unsigned int xmlGetAttributeCount(xml_node_t * node)
{
	return node->node->value.element.num_attrs;
}

const char * xmlGetAttributeN(xml_node_t * node, unsigned int n, const char ** key)
{
	if (n >= (unsigned int)node->node->value.element.num_attrs) {
		return 0;
	}

	if (key) *key = node->node->value.element.attrs[n].name;
	return translateEnv(node->node->value.element.attrs[n].value);
}
