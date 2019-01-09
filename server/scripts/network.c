#include <arpa/inet.h>
#include <string.h>

#include "network.h"
#include "log.h"
#include "package.h"
#include "assert.h"
#include "base.h"

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int luaopen_network(lua_State *L);

#ifdef __cplusplus
}
#endif

#define LUA_CONNECTIONS "___connections___"

#define LUA_GET_GLOBAL(name) \
	do { \
		lua_getglobal(L, name); \
		if (lua_isnil(L, -1)) { \
			lua_pop(L, 1); \
			lua_newtable(L); \
			lua_setglobal(L, name); \
			lua_getglobal(L, name); \
		} \
	} while(0)

# define INIT_STACK_CHECK(L)  int xtop = lua_gettop(L)
# define DO_STACK_CHECK(L, n) assert(lua_gettop(L) == (xtop + (n)))

static void record_lua_connection(lua_State * L, int index, resid_t conn)
{
	INIT_STACK_CHECK(L);

	lua_pushvalue(L, index);
	LUA_GET_GLOBAL(LUA_CONNECTIONS);
	lua_pushinteger(L, conn);
	lua_pushvalue(L, -3);
	lua_settable(L, -3);
	lua_pop(L, 2);

	DO_STACK_CHECK(L, 0);
}

static void get_lua_connection(lua_State * L, resid_t conn)
{
	INIT_STACK_CHECK(L);

	LUA_GET_GLOBAL(LUA_CONNECTIONS);
	lua_pushinteger(L, conn);
	lua_gettable(L, -2);
	lua_remove(L, -2);

	DO_STACK_CHECK(L, 1);
}

static void remove_lua_connection(lua_State * L, resid_t conn)
{
	INIT_STACK_CHECK(L);

	LUA_GET_GLOBAL(LUA_CONNECTIONS);
	lua_pushinteger(L, conn);
	lua_pushnil(L);
	lua_settable(L, -3);
	lua_pop(L, 1);

	DO_STACK_CHECK(L, 0);
}

static void get_lua_connection_handler(lua_State * L, resid_t conn, const char * name)
{
	INIT_STACK_CHECK(L);

	get_lua_connection(L, conn);       // conn 
	if (lua_isnil(L, -1)) { 
		DO_STACK_CHECK(L, 1);
		return; 
	}

	lua_getfield(L, -1, "handler");    // conn, handler
	lua_remove(L, -2);                 // handler
	if (lua_isnil(L, -1)) { 
		DO_STACK_CHECK(L, 1);
		return; 
	}

	lua_getfield(L, -1, name); 	   // handler callback
	lua_remove(L, -2);		   // callback

	DO_STACK_CHECK(L, 1);

	return;
}

static struct network_handler listen_handler = {0};
static struct network_handler conn_handler = {0};

static int l_new_connection(lua_State * L);
static int l_listen(lua_State * L);
static int l_connect(lua_State * L);
static int l_send(lua_State * L);
static int l_sends(lua_State * L);
static int l_sendc(lua_State * L);
static int l_close(lua_State * L);

#define lua_setfield_cfunction(L, index, field, func) \
	do { \
		int i = (index); \
		lua_pushcfunction((L), (func)); \
		if (i < 0)  i --; \
		lua_setfield((L), i, (field)); \
	} while(0)

#define lua_setfield_function(L, index, name) \
	lua_setfield_cfunction(L, index, #name, l_##name)


static void l_push_socket_metatable(lua_State * L)
{
	INIT_STACK_CHECK(L);

	if (luaL_newmetatable(L, "__socket_metatable__") == 1) {
		lua_newtable(L);

		lua_setfield_function(L, -1, listen);
		lua_setfield_function(L, -1, connect);
		lua_setfield_function(L, -1, send);
		lua_setfield_function(L, -1, sends);
		lua_setfield_function(L, -1, sendc);
		lua_setfield_function(L, -1, close);

		lua_setfield(L, -2, "__index");
	}

	DO_STACK_CHECK(L, 1);
}

static int l_new_connection(lua_State * L)
{
	INIT_STACK_CHECK(L);

	lua_newtable(L);

	l_push_socket_metatable(L);
	lua_setmetatable(L, -2);

	DO_STACK_CHECK(L, 1);
	return 1;
}

static void on_accept(struct network * net, resid_t l, resid_t c, void * ctx)
{
	lua_State * L = (lua_State*)ctx;


	INIT_STACK_CHECK(L);

	get_lua_connection_handler(L, l, "onAccept"); // callback
	if (lua_isnil(L, -1)) {
		lua_pop(L, 1);
		agN_close(c);

		DO_STACK_CHECK(L, 0);
		return;
	}

	l_new_connection(L);    	// callback conn

	// set cid field
	lua_pushinteger(L, c);		// callback conn id
	lua_setfield(L, -2, "cid");     	// callback conn

	lua_pushinteger(L, _agN_get_fd(net, c)); // callback conn fd
	lua_setfield(L, -2, "fd");     	// callback conn

	record_lua_connection(L, -1, c);

	DO_STACK_CHECK(L, 2);

	if (lua_pcall(L, 1, 0, 0) != 0) {
		WRITE_ERROR_LOG("%s", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
	agN_set_handler(c, &conn_handler, L);

	DO_STACK_CHECK(L, 0);
}

static const char * luaT[] = {
	"LUA_TNIL",
	"LUA_TBOOLEAN",
	"LUA_TLIGHTUSERDATA",
	"LUA_TNUMBER",
	"LUA_TSTRING",
	"LUA_TTABLE",
	"LUA_TFUNCTION",
	"LUA_TUSERDATA",
	"LUA_TTHREAD",
};



static void dumpLuaStack(lua_State * L, const char * info)
{
	if (info) {
		printf("%s\n", info);
	}

	int i = lua_gettop(L);
	while(i > 0) {
		printf("\t%2d. %s %s\n", i, luaT[lua_type(L,i)], lua_tostring(L, i));
		i--;
	}
}

static void on_connected(struct network * net, resid_t c, void * ctx)
{
	((void)dumpLuaStack);

	lua_State * L = (lua_State*)ctx;
#if 0
	get_lua_connection(L, c);		// callback, conn
	lua_resume(L, 1);
#else
	INIT_STACK_CHECK(L);
	get_lua_connection_handler(L, c, "onConnected"); // callback

	if (lua_isnil(L, -1)) {
		lua_pop(L, 1);
		DO_STACK_CHECK(L, 0);
		return;
	}

	if (!lua_isfunction(L, -1)) {
		lua_pop(L, 1);
		DO_STACK_CHECK(L, 0);
		return;	
	}

	get_lua_connection(L, c);		// callback, conn

	if (lua_pcall(L, 1, 0, 0) != 0) {
		WRITE_ERROR_LOG("%s", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
	DO_STACK_CHECK(L, 0);
#endif
}

static void on_closed(struct network * net, resid_t c, int error, void * ctx)
{
	lua_State * L = (lua_State*)ctx;

	INIT_STACK_CHECK(L);

	get_lua_connection_handler(L, c, "onClosed"); // callback

	if (!lua_isfunction(L, -1)) {
		lua_pop(L, 1);
		DO_STACK_CHECK(L, 0);
		return;	
	}

	get_lua_connection(L, c);		// callback conn
	lua_pushinteger(L, error);		// callback conn error

	if (lua_pcall(L, 2, 0, 0) != 0) {
		WRITE_ERROR_LOG("%s", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
	remove_lua_connection(L, c);

	DO_STACK_CHECK(L, 0);
}

static size_t on_message_s(struct network * net, resid_t c,
		const char * msg, size_t len,
		void * ctx)
{
	lua_State * L = (lua_State*)ctx;

	if (len < sizeof(struct translate_header)) {
		lua_pop(L, 1);
		return 0;
	}

	struct translate_header * tran_info = (struct translate_header*)msg;
	size_t package_len = ntohl(tran_info->len);
	if (len < package_len) {
		lua_pop(L, 1);
		return 0;
	}

	uint32_t flag = ntohl(tran_info->flag);
	uint32_t command = ntohl(tran_info->cmd);
	uint32_t playerid = ntohl(tran_info->playerid);
        uint32_t sid = ntohl(tran_info->serverid);
	size_t data_len = package_len;
	const char * data = msg + sizeof(struct translate_header);
	data_len -= sizeof(struct translate_header);

	assert(lua_isfunction(L, -1));

	get_lua_connection(L, c);			// callback conn
	lua_pushinteger(L, flag);			// callback conn flag
	lua_pushinteger(L, command);			// callback conn flag command
	lua_pushinteger(L, playerid);			// callback conn flag command playerid
        lua_pushinteger(L, sid);
	lua_pushlstring(L, data, data_len);		// callback conn flag command playerid msg

	if (lua_pcall(L, 6, 0, 0) != 0) {
		WRITE_ERROR_LOG("%s", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
	return package_len;
}

static size_t on_message_c(struct network * net, resid_t c,
		const char * msg, size_t len,
		void * ctx)
{
	lua_State * L = (lua_State*)ctx;

	if (len < sizeof(struct translate_header)) {
		lua_pop(L, 1);
		return 0;
	}

	struct client_header * tran_info = (struct client_header*)msg;
	size_t package_len = ntohl(tran_info->len);
	if (len < package_len) {
		lua_pop(L, 1);
		return 0;
	}

	uint32_t flag = ntohl(tran_info->flag);
	uint32_t command = ntohl(tran_info->cmd);

	size_t data_len = package_len;
	const char * data = msg + sizeof(struct client_header);
	data_len -= sizeof(struct client_header);


	assert(lua_isfunction(L, -1));

	get_lua_connection(L, c);			// callback conn
	lua_pushinteger(L, flag);			// callback conn flag
	lua_pushinteger(L, command);			// callback conn flag command
	lua_pushlstring(L, data, data_len);		// callback conn flag command msg

	if (lua_pcall(L, 4, 0, 0) != 0) {
		WRITE_ERROR_LOG("%s", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
	return package_len;
}

static size_t on_message(struct network * net, resid_t c,
			const char * msg, size_t len,
			void * ctx)
{
 	if (len >= 23 && 
		memcmp(msg, "<policy-file-request/>\0", 23) == 0) {
		static const char * policy_file = 
		"<?xml version=\"1.0\"?>"
		"<cross-domain-policy>"
		  "<site-control permitted-cross-domain-policies=\"all\"/>"
		  "<allow-access-from domain=\"*\" to-ports=\"*\"/>"
		"</cross-domain-policy>\0";
		WRITE_DEBUG_LOG("send policy_file:\n%s", policy_file);
		_agN_send(net, c, policy_file, strlen(policy_file) + 1);
		return 23;
	}

	lua_State * L = (lua_State*)ctx;

	INIT_STACK_CHECK(L);

	get_lua_connection_handler(L, c, "onMessage");	// callback
	if (lua_isfunction(L, -1)) {
		int ret = on_message_s(net, c, msg, len, ctx);
		DO_STACK_CHECK(L, 0);
		return ret;
	} else {
		lua_pop(L, 1);
	}

	get_lua_connection_handler(L, c, "onClientMessage");	// callback
	if (lua_isfunction(L, -1)) {
		int ret = on_message_c(net, c, msg, len, ctx);
		DO_STACK_CHECK(L, 0);
		return ret;
	} else {
		lua_pop(L, 1);
	}

	DO_STACK_CHECK(L, 0);

	// discard
	return len;
}

static int l_listen(lua_State * L)
{
	//self, host, port
	const char * host = luaL_checkstring(L, 2);
	int          port = luaL_checkinteger(L, 3);

	INIT_STACK_CHECK(L);

	// 使用主进程注册
	lua_getglobal(L, "c_main_state");
	lua_State * mL = (lua_State*)lua_touserdata(L, -1);
	lua_pop(L, 1);

	resid_t conn = agN_listen(host, port, 100, &listen_handler, mL);
	if (conn == INVALID_ID) {
		lua_pushboolean(L, 0);
		DO_STACK_CHECK(L, 1);
		return 1;
	}

	// set cid field
	lua_pushstring(L, "cid");
	lua_pushinteger(L, conn);
	lua_settable(L, 1);

	lua_pushinteger(L, agN_get_fd(conn)); 
	lua_setfield(L, 1, "fd"); 

	// record
	record_lua_connection(L, 1, conn);

	lua_pushboolean(L, 1);

	DO_STACK_CHECK(L, 1);

	return 1;
}

static int l_connect(lua_State * L)
{
	//self, host, port
	const char * host = luaL_checkstring(L, 2);
	int          port = luaL_checkinteger(L, 3);
	int          timeout = luaL_optinteger(L, 4, 60);


	INIT_STACK_CHECK(L);

	lua_getglobal(L, "c_main_state");
	lua_State * mL = (lua_State*)lua_touserdata(L, -1);
	lua_pop(L, 1);

	resid_t conn = agN_connect(host, port, timeout, &conn_handler, mL);
	if (conn == INVALID_ID) {
		lua_pushboolean(L, 0);

		DO_STACK_CHECK(L, 1);
		return 1;
	}

	// set cid field
	lua_pushstring(L, "cid");
	lua_pushinteger(L, conn);
	lua_settable(L, 1);

	lua_pushinteger(L, agN_get_fd(conn)); 
	lua_setfield(L, 1, "fd"); 

	// record
	record_lua_connection(L, 1, conn);

	lua_pushboolean(L, 1);

	DO_STACK_CHECK(L, 1);

	return 1;
}

static int l_send(lua_State * L)
{
	INIT_STACK_CHECK(L);

	if(lua_gettop(L) != 2) {
		lua_pushinteger(L, 0);
		DO_STACK_CHECK(L, 1);
		return 1;
	}

	lua_getfield (L, 1, "cid");
	resid_t conn = luaL_checkinteger(L, -1); 	// conn
	lua_pop(L, 1);

	size_t len = 0;
	const char * ptr = luaL_checklstring (L, 2, &len); 
	if (ptr == 0 || len == 0) {
		lua_pushinteger(L, 0);
		DO_STACK_CHECK(L, 1);
		return 1;
	}

	len = agN_send(conn, ptr, len);

	lua_pushinteger(L, 0);
	DO_STACK_CHECK(L, 1);
	return 1;
}

static int l_sends(lua_State * L)
{
	INIT_STACK_CHECK(L);
	if(lua_gettop(L) != 6) {
		lua_pushinteger(L, 0);
		DO_STACK_CHECK(L, 1);
		return 1;
	}

	lua_getfield (L, 1, "cid");
	resid_t conn = luaL_checkinteger(L, -1); 	// conn
	lua_pop(L, 1);

	unsigned int flag = luaL_checkinteger(L, 2);
	unsigned int command = luaL_checkinteger(L, 3);
	unsigned int playerid = luaL_checkinteger(L, 4); 
	unsigned int sid = luaL_checkinteger(L, 5);

	size_t len = 0;
	const char * ptr = luaL_checklstring (L, 6, &len); 
	if (ptr == 0 || len == 0) {
		lua_pushinteger(L, 0);
		DO_STACK_CHECK(L, 1);
		return 1;
	}


	struct translate_header tran_info;
	size_t package_len = sizeof(tran_info) + len;

	tran_info.len = htonl(package_len);
	tran_info.flag = htonl(flag);
	tran_info.cmd = htonl(command);
	tran_info.playerid = htonl(playerid);
        tran_info.serverid = htonl(sid);
	//agN_send(conn, (const char*)&tran_info, sizeof(tran_info));
	//agN_send(conn, ptr, len);

	struct iovec iov[2];
	iov[0].iov_base = &tran_info;
	iov[0].iov_len  = sizeof(tran_info);

	iov[1].iov_base = (char *) ptr;
	iov[1].iov_len  = len;
	
	agN_writev(conn, iov, 2);

	lua_pushinteger(L, 0);

	DO_STACK_CHECK(L, 1);

	return 1;
}

static int l_sendc(lua_State * L)
{
	INIT_STACK_CHECK(L);

	if(lua_gettop(L) != 4) {
		lua_pushinteger(L, 0);
		DO_STACK_CHECK(L, 1);
		return 1;
	}

	lua_getfield (L, 1, "cid");
	resid_t conn = luaL_checkinteger(L, -1); 	// conn
	lua_pop(L, 1);

	unsigned int flag = luaL_checkinteger(L, 2);
	unsigned int command = luaL_checkinteger(L, 3);

	size_t len = 0;
	const char * ptr = luaL_checklstring (L, 4, &len); 
	if (ptr == 0 || len == 0) {
		lua_pushinteger(L, 0);

		DO_STACK_CHECK(L, 1);
		return 1;
	}

	struct client_header tran_info;
	size_t package_len = sizeof(tran_info) + len;

	tran_info.len = htonl(package_len);
	tran_info.flag = htonl(flag);
	tran_info.cmd = htonl(command);

	agN_send(conn, (const char*)&tran_info, sizeof(tran_info));
	agN_send(conn, ptr, len);

	lua_pushinteger(L, 0);

	DO_STACK_CHECK(L, 1);

	return 1;
}

static int l_close(lua_State * L)
{
	INIT_STACK_CHECK(L);
	lua_getfield (L, 1, "cid");
	resid_t conn = luaL_checkinteger(L, -1);
	lua_pop(L, 1);

	lua_pushnil(L);
	lua_setfield(L, 1, "fd");

	agN_close(conn);

	remove_lua_connection(L, conn);

	lua_pushboolean(L, 1);
	DO_STACK_CHECK(L, 1);
	return 1;
}

int luaopen_network(lua_State *L)
{
	listen_handler.on_accept = on_accept;
	listen_handler.on_closed = on_closed;

	conn_handler.on_connected  = on_connected;
	conn_handler.on_closed = on_closed;
	conn_handler.on_message = on_message;

	luaL_Reg reg[] = {
		{"new" ,	l_new_connection},
		{0,         0},
	};

	luaL_register(L,"network", reg);

	return 0;
}
