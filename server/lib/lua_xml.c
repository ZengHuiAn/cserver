#include <assert.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int luaopen_xml(lua_State *L);

#ifdef __cplusplus
}
#endif

#include "../framework/xmlHelper.h"

static int pushNode(lua_State * L, xml_node_t * node)
{
	lua_newtable(L);
	xml_node_t * ite = 0;

	int i = 0;

	for(ite = xmlGetFirstChild(node); ite; ite = xmlGetNextSibling(ite)) {
		pushNode(L, ite);
		lua_setfield(L, -2, xmlGetName(ite));

		lua_pushinteger(L, ++i);
		lua_getfield(L, -2, xmlGetName(ite));
		lua_settable(L, -3);
	}

	int n = xmlGetAttributeCount(node); 
	for(i = 0; i < n; i++) {
		const char * key = 0;
		const char * value = xmlGetAttributeN(node, i, &key);
		lua_pushstring(L, value);
		char rkey[256];
		sprintf(rkey, "@%s", key);
		lua_setfield(L, -2, rkey);
	}

	const char * text = xmlGetValue(node, "");
	if (text && text[0] != 0) {
		lua_pushstring(L, xmlGetValue(node, ""));
		lua_setfield(L, -2, "@text");
	}

	lua_pushstring(L, xmlGetName(node));
	lua_setfield(L, -2, "@");

	return 1;
}

static int l_xml_open(lua_State * L)
{
	const char * path = luaL_checkstring(L, 1);
	if (path == 0) {
		return 0;
	}

	xml_doc_t * doc = xmlOpen(path);
	if (doc == 0) {
		return 0;
	}

	xml_node_t * root = xmlDocGetRoot(doc);
	if (root) {
		pushNode(L, root);
		xmlClose(doc);
		return 1;
	} else {
		xmlClose(doc);
		return 0;
	}
}

int luaopen_xml(lua_State *L)
{
	luaL_Reg reg[] = {
		{"open", l_xml_open},
		{0,	0},
	};
	luaL_register(L,"xml", reg);
	return 0;
}
