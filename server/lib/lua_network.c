#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>
#include <assert.h>
#include <errno.h>
#include <time.h>
#include <sys/epoll.h>
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

static int epoll_fd = -1;

enum SocketType {
	st_unknown,
	st_listener,
	st_connection,
};

enum SocketStatus {
	ss_init,
	ss_listening,
	ss_connecting,
	ss_connected,
	ss_closing,
	ss_closed,
};

#define SOCKET_CALLBACK_ACCEPT		0
#define SOCKET_CALLBACK_CONNECTED 	1
#define SOCKET_CALLBACK_WRITE		2
#define SOCKET_CALLBACK_READ		3
#define SOCKET_CALLBACK_ERROR		4
#define SOCKET_CALLBACK_CLOSED		5
#define SOCKET_CALLBACK_MAX		6

struct Socket {
	struct Socket * next;
	//struct Socket * prev;

	enum SocketType type;
	enum SocketStatus status;

	int ref;

	int fd;

	int callback[SOCKET_CALLBACK_MAX];
};

struct Socket * closing_list = 0;

struct Socket * l_read_socket(lua_State * L, int index)
{
	luaL_checktype(L, index, LUA_TTABLE);

	lua_getfield(L, index, "ptr");
	luaL_checktype(L, -1, LUA_TLIGHTUSERDATA);
	struct Socket * socket = lua_touserdata (L, -1);
	lua_pop(L, 1);

	return socket;
}


static void l_push_socket_metatable(lua_State * L, struct Socket * socket);

static struct Socket * new_socket(lua_State * L)
{
	struct Socket * socket = (struct Socket*)malloc(sizeof(struct Socket));

	socket->next = 0;

	socket->fd = -1;
	socket->type = st_unknown;
	socket->status = ss_init;
	int i;
	for(i = 0; i < SOCKET_CALLBACK_MAX; i++) {
		socket->callback[i] = LUA_REFNIL;
	}

	lua_newtable(L);
	lua_pushlightuserdata(L, socket);
	lua_setfield(L, -2, "ptr");

	// set metatable
	l_push_socket_metatable(L, socket);
	lua_setmetatable(L, -2);

	socket->ref = luaL_ref(L, LUA_REGISTRYINDEX);

	return socket;
}

static void free_closing_list(lua_State * L)
{
	while(closing_list) {
		struct Socket * socket = closing_list;
		closing_list = socket->next;

		luaL_unref(L, LUA_REGISTRYINDEX, socket->ref);

		free(socket);
	}
}

static void free_socket(lua_State * L, struct Socket * socket)
{
	//socket->status = ss_closed;
	if (socket->next == 0) {
		socket->next = closing_list;
		closing_list = socket;
	}
	//free(socket);
}

static int close_socket(lua_State * L, struct Socket * socket)
{
	if (socket->status == ss_closed || socket->status == ss_closing) {
		return 0;
	}

	socket->status = ss_closing;
	if (socket->fd > 0) {
		epoll_ctl(epoll_fd, EPOLL_CTL_DEL, socket->fd, 0);
		close(socket->fd);
		socket->fd = -1;
	}

	int i;
	for(i = 0; i < SOCKET_CALLBACK_MAX; i++) {
		if (socket->callback[i] != LUA_REFNIL) {
			luaL_unref(L, LUA_REGISTRYINDEX, socket->callback[i]);
		}
	}

	free_socket(L, socket);
	return 0;
}

static int l_socket_close(lua_State * L)
{
	struct Socket * socket = l_read_socket(L, 1);
	close_socket(L, socket);
	return 0;
}

static int l_socket_on(lua_State * L)
{
	struct Socket * socket = l_read_socket(L, 1);
	const char * event = luaL_checkstring(L, 2);

	int * act = 0;
	if (strcmp(event, "connection") == 0) {
		act = socket->callback + SOCKET_CALLBACK_ACCEPT;
	} else if (strcmp(event, "connect") == 0) {
		act = socket->callback + SOCKET_CALLBACK_CONNECTED;
	} else if (strcmp(event, "data") == 0) {
		act = socket->callback + SOCKET_CALLBACK_READ;
	} else if (strcmp(event, "end") == 0) {
		act = socket->callback + SOCKET_CALLBACK_CLOSED;
	} else if (strcmp(event, "drain") == 0) {
		act = socket->callback + SOCKET_CALLBACK_WRITE;
	} else if (strcmp(event, "timeout") == 0) {
	} else if (strcmp(event, "error") == 0) {
		act = socket->callback + SOCKET_CALLBACK_ERROR;
	} else if (strcmp(event, "close") == 0) {
		act = socket->callback + SOCKET_CALLBACK_CLOSED;
	}

	if (act == 0) {
		return 0;
	}

	luaL_checktype(L, 3, LUA_TFUNCTION);

	if (*act != LUA_REFNIL) {
		luaL_unref(L, LUA_REGISTRYINDEX, *act);
	}
	lua_pushvalue(L, 3);
	*act = luaL_ref(L, LUA_REGISTRYINDEX);
	return 0;
}

static int l_socket_connect(lua_State * L);
static int l_socket_listen(lua_State * L);
static int l_socket_write(lua_State * L);
static int l_socket_on(lua_State * L);
static int l_socket_close(lua_State * L);


#define lua_setfield_cfunction(L, index, field, func) \
	do { \
		int i = (index); \
		lua_pushcfunction((L), (func)); \
		if (i < 0)  i --; \
		lua_setfield((L), i, (field)); \
	} while(0)

static void l_push_socket_metatable(lua_State * L, struct Socket * socket)
{
	if (socket->status == ss_closing || socket->status == ss_closed) {
		lua_pushnil(L);
		return;
	}

	switch(socket->type) {
		case st_unknown:
			if (luaL_newmetatable(L, "socket_unknown_metatable") == 1) {
				lua_newtable(L);

				lua_setfield_cfunction(L, -1, "on", l_socket_on);
				lua_setfield_cfunction(L, -1, "close", l_socket_close);
				lua_setfield_cfunction(L, -1, "connect", l_socket_connect);
				lua_setfield_cfunction(L, -1, "listen", l_socket_listen);

				lua_setfield(L, -2, "__index");
			}
			break;
		case st_listener:
			if (luaL_newmetatable(L, "socket_listener_metatable") == 1) {
				lua_newtable(L);

				lua_setfield_cfunction(L, -1, "on", l_socket_on);
				lua_setfield_cfunction(L, -1, "close", l_socket_close);

				lua_setfield(L, -2, "__index");
			}
			break;
		case st_connection:
			if (luaL_newmetatable(L, "socket_connection_metatable") == 1) {
				lua_newtable(L);

				lua_setfield_cfunction(L, -1, "on", l_socket_on);
				lua_setfield_cfunction(L, -1, "close", l_socket_close);
				lua_setfield_cfunction(L, -1, "write", l_socket_write);

				lua_setfield(L, -2, "__index");
			}
			break;
		default:
			lua_pushnil(L);
			break;
	}
}

static void l_socket_change_type(lua_State * L, struct Socket * socket, enum SocketType type, enum SocketStatus status)
{
	if (socket->type == socket->type && socket->status == status) {
		return;
	}

	socket->type = type;
	socket->status = status;

	lua_rawgeti(L, LUA_REGISTRYINDEX, socket->ref);
	l_push_socket_metatable(L, socket);
	lua_setmetatable (L, -2);
	lua_pop(L, 1);
}

static void l_push_socket(lua_State * L, struct Socket * socket)
{
	lua_rawgeti(L, LUA_REGISTRYINDEX, socket->ref);
}

static int l_socket_write(lua_State * L)
{
	struct Socket * socket = l_read_socket(L, 1);

	if (socket->type != st_connection || (socket->status != ss_connecting  && socket->status != ss_connected)) {
		return 0;
	}

	size_t len = 0;
	const char * data = luaL_checklstring(L, 2, &len);

	int ret = send(socket->fd, data, len, 0);

	struct epoll_event event;
	event.events = EPOLLIN|EPOLLOUT;
	event.data.ptr = socket;
	epoll_ctl(epoll_fd, EPOLL_CTL_MOD, socket->fd, &event);

	lua_pushinteger(L, ret);
	return 1;
}

static int l_socket_connect(lua_State * L)
{
	struct Socket * sock = l_read_socket(L, 1);	

	if (sock->type != st_unknown || sock->status != ss_init ) {
		luaL_error(L, "sock status error");
		return 0;
	}

	int port = luaL_checkinteger(L, 2);
	const char * host = luaL_optstring(L, 3, "127.0.0.1");

	int done = 0;
	int fd = connect_to(host, port, &done);
	if (fd < 0) {
		lua_pushboolean(L, 0);
		return 1;
	}

	sock->fd = fd;

	// epoll
	struct epoll_event event;
	if (done) {
		event.events = EPOLLIN|EPOLLOUT;
	} else {
		event.events = EPOLLOUT;
	}
	event.data.ptr = sock;
	if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, sock->fd, &event) != 0) {
		close(sock->fd);
		sock->fd = -1;
		lua_pushboolean(L, 0);
		return 1;
	}

	// change status
	sock->type == st_connection;
	if (done) {
		l_socket_change_type(L, sock, st_connection, ss_connected);
	} else {
		l_socket_change_type(L, sock, st_connection, ss_connecting);
	}

	// call back
	lua_rawgeti(L, LUA_REGISTRYINDEX, sock->callback[SOCKET_CALLBACK_CONNECTED]);
	if (lua_isfunction(L, -1)) {
		l_push_socket(L, sock);
		lua_pcall(L, 1, 0, 0);
	} else {
		lua_pop(L, 1);
	}

	lua_pushboolean(L, 1);
	return 1;
}

static int l_socket_listen(lua_State * L)
{
	struct Socket * sock = l_read_socket(L, 1);
	// check socket status
	if (sock->type != st_unknown || sock->status != ss_init ) {
		luaL_error(L, "sock status error");
		return 0;
	}

	// read param
	int port = luaL_checkinteger(L, 2);
	const char * host = "0.0.0.0";
	int backlog = 100;
	int func_index = 0;

	int next_index = 3;
	int top = lua_gettop(L);
	while(next_index <= top) {
		switch(lua_type(L, next_index)) {
			case LUA_TSTRING:
				host = lua_tostring(L, next_index); 
				break;
			case LUA_TNUMBER:
				backlog = lua_tointeger(L, next_index);
				break;
			case LUA_TFUNCTION:
				func_index = next_index;
				break;
			default:
				luaL_error(L, "unknown param type");
				break;
		}
		next_index ++;
	}

	int fd = listen_on(host, port, backlog);
	if (fd < 0) {
		lua_pushboolean(L, 0);
		return 1;
	}

	sock->fd = fd;

	 // epoll
	struct epoll_event event;
	event.events = EPOLLIN;
	event.data.ptr = sock;

	if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, sock->fd, &event) != 0) {
		printf("epoll_ctl failed");
		close(sock->fd);
		sock->fd = -1;
		lua_pushboolean(L, 0);
		return 1;
	}

	// change status
	l_socket_change_type(L, sock, st_listener, ss_listening);

	// register accept callback
	if (func_index > 0) {
		lua_pushvalue(L, func_index);
		sock->callback[SOCKET_CALLBACK_ACCEPT] = luaL_ref(L, LUA_REGISTRYINDEX);
	}

	lua_pushboolean(L, 1);
	return 1;
}

static int l_network_createSocket(lua_State * L)
{
	if (epoll_fd == -1) {
		epoll_fd = epoll_create(100);
	}

/*	
	int fd = socket(AF_INET, SOCK_STREAM, 0);
	if (fd == -1) {
		return 0;
	}
*/

	// make socket and ref
	struct Socket * sock = new_socket(L);

	l_socket_change_type(L, sock, st_unknown, ss_init);

	l_push_socket(L, sock);
	return 1;
}

static void accept_connection(lua_State * L, struct Socket * listener)
{
	assert(listener->type == st_listener);
	assert(listener->status == ss_listening);

	struct sockaddr_in addr;
	socklen_t addrlen = sizeof(struct sockaddr_in);

	while(1) {
		int fd = accept(listener->fd, (struct sockaddr*)&addr, &addrlen);
		if (fd < 0) {
			if (errno == EAGAIN || errno == EWOULDBLOCK) {
				// finished
				return;
			} else if (errno == EINTR) {
				// retry
				continue;
			} else {
				// accept failed
				return;
			}
		}

		if (setnblock(fd) != 0) {
			close(fd);
			continue;
		}

		// make listener and ref
		struct Socket * client = new_socket(L);

		client->fd = fd;
		l_socket_change_type(L, client, st_connection, ss_connected);

		// epoll
		struct epoll_event event;
		event.events = EPOLLIN | EPOLLOUT;
		event.data.ptr = client;
		if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, client->fd, &event) != 0) {
			printf("epoll_ctl failed");
			close_socket(L, client);
			continue;
		}

		// call onAccept
		lua_rawgeti(L, LUA_REGISTRYINDEX, listener->callback[SOCKET_CALLBACK_ACCEPT]);
		if (lua_isnil(L, -1)) {
			lua_pop(L, 1);
			continue;
		}

		l_push_socket(L, listener);
		l_push_socket(L, client);
		if (lua_pcall(L, 2, 0, 0) != 0) {
			printf("call onAccept faield %s", lua_tostring(L, -1));
			lua_pop(L, 1);
		}
	}
}

static void check_connecting(lua_State * L, struct Socket * socket)
{
	int error = 0;
	socklen_t len = sizeof(error);
	getsockopt(socket->fd, SOL_SOCKET, SO_ERROR, (char*)&error, &len);

	if (error != 0) {
		// failed, callback
		lua_rawgeti(L, LUA_REGISTRYINDEX, socket->callback[SOCKET_CALLBACK_ERROR]);
		if (lua_isfunction(L, -1)) {
			l_push_socket(L, socket);
			lua_pcall(L, 1, 0, 0);
		} else {
			lua_pop(L, 1);
		}
		close_socket(L, socket);
		return;
	} 

	// change status
	l_socket_change_type(L, socket, st_connection, ss_connected);

	//epoll
	struct epoll_event event;
	event.events = EPOLLIN | EPOLLOUT;
	event.data.ptr = socket;
	if (epoll_ctl(epoll_fd, EPOLL_CTL_MOD, socket->fd, &event) != 0) {
		printf("epoll_ctl failed\n");
		//socket->status == ss_closing;
		lua_rawgeti(L, LUA_REGISTRYINDEX, socket->callback[SOCKET_CALLBACK_ERROR]);
		if (lua_isfunction(L, -1)) {
			l_push_socket(L, socket);
			lua_pcall(L, 1, 0, 0);
		} else {
			lua_pop(L, 1);
		}
		close_socket(L, socket);
		return;
	} 

	// call back
	lua_rawgeti(L, LUA_REGISTRYINDEX, socket->callback[SOCKET_CALLBACK_CONNECTED]);
	if (lua_isfunction(L, -1)) {
		l_push_socket(L, socket);
		lua_pcall(L, 1, 0, 0);
	} else {
		lua_pop(L, 1);
	}
}

static void check_connection(lua_State * L, struct Socket * socket, int events)
{
	if (events & EPOLLERR) {
		lua_rawgeti(L, LUA_REGISTRYINDEX, socket->callback[SOCKET_CALLBACK_ERROR]);
		if (lua_isfunction(L, -1)) {
			l_push_socket(L, socket);
			lua_pcall(L, 1, 0, 0);
		} else {
			lua_pop(L, 1);
		}
		close_socket(L, socket);
		return;
	}

	if (events & EPOLLOUT) {
		//TODO: send buffer message
		struct epoll_event event;
		event.events = EPOLLIN;
		event.data.ptr = socket;
		epoll_ctl(epoll_fd, EPOLL_CTL_MOD, socket->fd, &event);

		lua_rawgeti(L, LUA_REGISTRYINDEX, socket->callback[SOCKET_CALLBACK_WRITE]);
		if (lua_isfunction(L, -1)) {
			l_push_socket(L, socket);
			lua_pcall(L, 1, 0, 0);
		} else {
			lua_pop(L, 1);
		}
	}

	if (socket->status != ss_connected) {
		// closed by callback
		return;
	}

	if (events & EPOLLIN) {
		char buff[4096];
		while(socket->status == ss_connected) {
			int ret = recv(socket->fd, buff, sizeof(buff), 0);
			if (ret == 0) {
				// closed by peer
				lua_rawgeti(L, LUA_REGISTRYINDEX, socket->callback[SOCKET_CALLBACK_CLOSED]);
				if (lua_isfunction(L, -1)) {
					l_push_socket(L, socket);
					lua_pcall(L, 1, 0, 0);
				} else {
					lua_pop(L, 1);
				}
				close_socket(L, socket);
				return;
			} 
			
			if (ret < 0) {
				if (errno == EWOULDBLOCK || errno == EAGAIN) {
					return;
				} else if (errno ==  EINTR) {
					continue;
				} else {
					// error
					lua_rawgeti(L, LUA_REGISTRYINDEX, socket->callback[SOCKET_CALLBACK_ERROR]);
					if (lua_isfunction(L, -1)) {
						l_push_socket(L, socket);
						lua_pcall(L, 1, 0, 0);
					} else {
						lua_pop(L, 1);
					}
					close_socket(L, socket);
					return;
				}
			} 

			// call back
			lua_rawgeti(L, LUA_REGISTRYINDEX, socket->callback[SOCKET_CALLBACK_READ]);
			if (lua_isfunction(L, -1)) {
				l_push_socket(L, socket);
				lua_pushlstring(L, buff, ret);
				lua_pcall(L, 2, 0, 0);
			} else {
				lua_pop(L, 1);
			}
		}
	}
}

int stop = 0;

static int l_network_stop(lua_State * L)
{
	stop = 1;
}

static int l_network_loop(lua_State * L)
{
	stop = 0;
	while(!stop) {
		struct epoll_event events[100];
		int ret = epoll_wait(epoll_fd, events, 100, 1000);

		int i;
		for(i = 0; i < ret; i++) {
			struct Socket * socket = (struct Socket*)events[i].data.ptr;

			if (socket->type == st_listener) {
				accept_connection(L, socket);
			} else if (socket->type == st_connection) {
				if (socket->status == ss_connecting) {
					check_connecting(L, socket);
				} else if (socket->status == ss_connected) {
					check_connection(L, socket, events[i].events);
				} else {
					// maybe closed by other socket
					//assert(0);
				}
			} else {
				// maybe closed by other socket
				//assert(0);
			}
		}
		free_closing_list(L);
	}
#ifdef _SYS_EPOLL_H
	close(epoll_fd);
#else
	epoll_close(epoll_fd);
#endif
	epoll_fd = -1;
}
			
int luaopen_network(lua_State *L)
{
	luaL_Reg reg[] = {
		//{"createServer",   	l_network_createServer},
		{"createSocket",    	l_network_createSocket},
		{"loop",    		l_network_loop},
		{"stop",    		l_network_stop},
		{0,         0},
	};
	luaL_register(L,"network", reg);
	return 0;
}
