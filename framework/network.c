#include <assert.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#include <arpa/inet.h>
#include <sys/time.h>
#include <sys/epoll.h>
#include <stdio.h>

#include <signal.h>

#include "base.h"
#include "network.h"
#include "memory.h"
#include "buffer.h"
#include "lrm.h"

#include "log.h"

struct conn;

struct network
{
	struct lrm * lrm;
	int efd;
	int stop;

	struct conn * closing_list;
	struct conn * active_list;

	struct {
		void (*cb)(time_t, void *);
		void * ctx;
		time_t last;
	} timer;

	struct {
		void (*cb)(void *);
		void * ctx;
	} tick;
};

enum conn_status {
	cs_closed = 0,
	cs_listening = 1,
	cs_connecting = 2,
	cs_connected  = 3,
	cs_closing = 4,
	cs_connected_wait_cb = 5,
};

struct conn 
{
	struct conn * next;
	int in_active_list;

	resid_t id;
	enum conn_status status;

	int fd;
	unsigned int events;
	struct buffer * rbuf;
	struct buffer * wbuf;

	struct network_handler handler;
	void * ctx;
};


static int conn_set_event(struct network * net, struct conn * c, unsigned int events)
{
	if (events == c->events) {
		return 0;
	}

	int opt = 0;
	if (c->events == 0) {
		opt = EPOLL_CTL_ADD;
	} else if (events == 0) {
		opt = EPOLL_CTL_DEL;
	} else {
		opt = EPOLL_CTL_MOD;
	}

	struct epoll_event event;
	event.events = events;
	event.data.ptr = c;
	int ret = epoll_ctl(net->efd, opt, c->fd, &event);
	if (ret == 0) {
		c->events = events;
	}
	return ret;
}

#define DEFAULT_BUFFER_SIZE	1024

struct network * _agN_new (size_t max)
{
	struct network * net = (struct network*)MALLOC(sizeof(struct network));
	net->lrm = _agRM_new(max, sizeof(struct conn));
	net->efd = epoll_create(64);
	net->closing_list = 0;
	net->active_list = 0;

	net->timer.cb   = 0;
	net->timer.ctx  = 0;
	net->timer.last = 0;

	net->tick.cb   = 0;
	net->tick.ctx  = 0;

	if (net->efd < 0) {
		_agRM_free(net->lrm);
		FREE(net);
		return 0;
	}
	return net;
}

void _agN_close(struct network * net, resid_t conn)
{
	struct conn * c = (struct conn*)_agR_get(net->lrm, conn);
	if (c && c->status != cs_closing) {
		c->status = cs_closing;

		conn_set_event(net, c, 0);

		c->next = net->closing_list;
		net->closing_list = c;
	}
}

static void do_close(struct network * net, struct conn * c)
{
	if (c->fd >= 0) close(c->fd);
	_agB_free(c->rbuf);
	_agB_free(c->wbuf);
	c->status = cs_closed;
	_agR_free(net->lrm, c->id);
}

void _agN_free(struct network * net)
{
	if (net) {
#ifdef _SYS_EPOLL_H
		close(net->efd);
#else
		epoll_close(net->efd);
#endif
		resid_t id = INVALID_ID;

		while((id = _agR_next(net->lrm, id)) != INVALID_ID) {
			// TODO: close
			_agN_close(net, id);
		}
		
		while(net->closing_list) {
			struct conn * c = net->closing_list; 
			net->closing_list = c->next;
			do_close(net, c);
		}
		_agRM_free(net->lrm);
		FREE(net);
	}
}

static int accept_once(struct network * net, struct conn * c)
{
	struct sockaddr_in addr;
	memset(&addr, 0, sizeof(addr));
	socklen_t addrlen = sizeof(struct sockaddr_in);
	int fd;
retry:
	fd = accept(c->fd, (struct sockaddr*)&addr, &addrlen);
	if (fd < 0) {
		if (errno == EAGAIN || errno == EWOULDBLOCK) {
			return 0;
		} else if (errno == EINTR) {
			goto retry;
		} else {
			// TODO: accept failed
			WRITE_DEBUG_LOG("accept failed: %s", strerror(errno));
			return 0;
		}
	} 

	WRITE_DEBUG_LOG("%s:%d connected", inet_ntoa(addr.sin_addr), (int)ntohs(addr.sin_port));

	if (setnblock(fd) != 0) {
		close(fd);
		return 1;
	}

	resid_t id = _agR_new(net->lrm);
	if (id == INVALID_ID) {
		// max
		close(fd);
		return 1;
	}

	struct conn * nc = (struct conn*)_agR_get(net->lrm, id);
	memset(nc, 0, sizeof(struct conn));
	nc->id = id;
	nc->fd = fd;
	nc->status = cs_connected;

	if(c->handler.on_accept) {
		c->handler.on_accept(net, c->id, nc->id, c->ctx);
	}
	return 1;
}

static void finish_connecting(struct network * net, struct conn * c) 
{
		c->status = cs_connected;

		int flag = EPOLLIN;
		if (c->wbuf && _agB_size(c->wbuf) > 0) {
				flag |= EPOLLOUT;	
		}
		conn_set_event(net, c, flag);

		if (c->handler.on_connected) {
				c->handler.on_connected(net, c->id, c->ctx);
		}
}
	
static void check_connecting(struct network * net , struct conn * c)
{
	int error = 0;
	socklen_t len = sizeof(error);
	getsockopt(c->fd, SOL_SOCKET, SO_ERROR, (char*)&error, &len);

	if (error != 0) {
		if (c->handler.on_closed) {
			c->handler.on_closed(net, c->id, error, c->ctx);
		}
		_agN_close(net, c->id);
	} else {
		finish_connecting(net, c);
	}
}

static void do_conn_error(struct network * net, struct conn * c)
{
	if (c->handler.on_closed) {
		c->handler.on_closed(net, c->id, -1000, c->ctx);
	}
	_agN_close(net, c->id);
}

static size_t process_conn_message(struct network * net, struct conn * c, char * data, size_t len)
{
	if (c->handler.on_message == 0) {
		return len;
	}

	size_t tsize = 0;
	while(len > 0) {
		size_t s = c->handler.on_message(net, c->id, data, len, c->ctx);
		if (s == 0 || s > len || c->status != cs_connected) {
			break;
		}

		tsize += s;
		data  += s;
		len   -= s;
	}
	return tsize;
}

static void do_conn_read(struct network * net, struct conn * c)
{
	if (c->status != cs_connected) {
		return;
	}

	char buff[DEFAULT_BUFFER_SIZE] = {0};
	int ret;

	int bits = 0;
	while(bits < 1024 * 10) {
		ret = recv(c->fd, buff, sizeof(buff), 0);
		// WRITE_DEBUG_LOG("###debug recv data fd =%d, return =%d, errno =%d, errmsg =%s", c->fd, ret, errno, strerror(errno));
		int error = errno;
		errno = error;
		if (ret == 0) {
			// closed by peer
			if (c->handler.on_closed) {
				c->handler.on_closed(net, c->id, 0, c->ctx);
			}
			_agN_close(net, c->id);
			return;
		} else if (ret < 0) {
			if (errno == EINTR) {
				continue;
			} else if (errno == EWOULDBLOCK || errno == EAGAIN) {
				if (c->rbuf && _agB_size(c->rbuf) > 0) {
					size_t size = _agB_size(c->rbuf);
					char * ptr = (char*)_agB_peek(c->rbuf, size);
					size_t s = process_conn_message(net, c, ptr, size);
					assert(s <= size);

					// check closed
					if (c->status != cs_connected) { return; }
					_agB_read(c->rbuf, s);
				}
				return;
			} else {
				// close by error
				if (c->handler.on_closed) {
					c->handler.on_closed(net, c->id, errno, c->ctx);
				}
				_agN_close(net, c->id);
				return;
			}
		} else {
			bits += ret;
			if (c->handler.on_message == 0) {
				// do nothing, drop message;
				continue;
			}

			if (c->rbuf == 0 || _agB_size(c->rbuf) == 0) {
				size_t s = process_conn_message(net, c, buff, ret);
				assert(s <= (size_t)ret);

				// check closed
				if (c->status != cs_connected) { return; }

				if (s < (size_t)ret) {
					if (c->rbuf == 0) {
						c->rbuf = _agB_new(DEFAULT_BUFFER_SIZE);
					}
					_agB_write(c->rbuf, buff + s, ret - s);
				}
			} else {
				if (c->rbuf == 0) {
					c->rbuf = _agB_new(DEFAULT_BUFFER_SIZE);
				}

				_agB_write(c->rbuf, buff, ret);

				size_t size = _agB_size(c->rbuf);
				char * ptr = (char*)_agB_peek(c->rbuf, size);
				size_t s = process_conn_message(net, c, ptr, size);
				assert(s <= size);

				// check closed
				if (c->status != cs_connected) { return; }
				_agB_read(c->rbuf, s);
			}
		}
	}
}

static void do_conn_write(struct network * net, struct conn * c) 
{
	if (c->status != cs_connected) {
		return;
	}

	if (c->wbuf && _agB_size(c->wbuf) > 0) {
		size_t s = _agB_size(c->wbuf);
		char * ptr = (char*)_agB_peek(c->wbuf, s);

		int ret = send(c->fd, ptr, s, 0);
		if (ret > 0) {
			_agB_read(c->wbuf, ret);
		}
	}

	if (c->wbuf == 0 || _agB_size(c->wbuf) == 0) {
		conn_set_event(net, c, EPOLLIN);
	}
}

static void do_conn_event(struct network * net, struct conn * c, uint32_t event)
{
	if (event & EPOLLERR) {
		do_conn_error(net, c);
		return;
	}

	if (event & EPOLLIN) {
		do_conn_read(net, c);
	}

	if (event & EPOLLOUT) {
		do_conn_write(net, c);
	}
}

static int timesub(struct timeval * t1, struct timeval * t2)
{
	int sec = t1->tv_sec - t2->tv_sec;
	int usec = t1->tv_usec - t2->tv_usec;
	if (usec < 0) {
		sec  --;
		usec += 1000 * 1000;
	}
	return sec * 1000 + usec / 1000;
}


static void cleanClient(struct network * net)
{
	// clean up closing conn
	while(net->closing_list) {
		struct conn * c = net->closing_list;
		net->closing_list = c->next;
		do_close(net, c);
	}
	net->closing_list = 0;
}

int _agN_tick(struct network * net, int timeout)
{
	struct epoll_event events[100];

	if (net->active_list) {
		while(net->active_list) {
			struct conn * c = net->active_list;
			net->active_list = c->next;
			c->next =0;
			c->in_active_list =0;
			if (c->status == cs_listening) {
				while(accept_once(net, c)) {
					// do nothing;
				}
			} else if (c->status == cs_connecting) {
				check_connecting(net, c);
			} else if (c->status == cs_connected) {
				do_conn_event(net, c, EPOLLIN|EPOLLOUT);
			} else if (c->status == cs_connected_wait_cb) {
				finish_connecting(net, c);
			}
		}
		return 0;
	}

	int ret = epoll_wait(net->efd, events, 100, timeout);
	if (net->stop) {
		return 0;
	}

	if (net->tick.cb) {
		net->tick.cb(net->tick.ctx);
	}

	//check timeout
	struct timeval tv;
	if (gettimeofday(&tv, 0) == 0) {
		if (net->timer.last < tv.tv_sec) {
			net->timer.last = tv.tv_sec;
			if (net->timer.cb) {
				net->timer.cb(net->timer.last, net->timer.ctx);
			}
		}
	}

	int i;
	for (i = 0; i < ret; i++) {
		struct conn * c = (struct conn*)(events[i].data.ptr);
		uint32_t e = events[i].events;
		if (c->status == cs_listening) {
			if (e & EPOLLIN) {
				while(accept_once(net, c)) {
					// do nothing;
				}
			} 
		} else if (c->status == cs_connecting) {
			check_connecting(net, c);
		} else if (c->status == cs_connected) {
			do_conn_event(net, c, e);
		} else {
			// maybe closed by tick.cb
			//assert(0 && "error conn status");
		}
	}

	cleanClient(net);
	return ret;
}

int _agN_loop(struct network * net)
{
	net->stop = 0;
	while(!net->stop) {
		struct timeval now;
		gettimeofday(&now, 0);

		struct timeval next;
		next.tv_sec = now.tv_sec + 1;
		next.tv_usec = 0;

		int timeout = timesub(&next, &now);

/*
		WRITE_DEBUG_LOG("next(%d,%d) - now(%d,%d) = %d",
				next.tv_sec, next.tv_usec,
				now.tv_sec, now.tv_usec,
				timeout);
*/
		if (timeout < 1000) {
			timeout = 1000;
		}
		_agN_tick(net, timeout);

	}
	return 0;
}

void _agN_stop(struct network * net)
{
	net->stop = 1;
}

static void _network_active(struct network * net, struct conn * c);
resid_t _agN_connect(struct network * net, 
	const char * host, short port, int timeout,
	network_handler * handler, void * ctx)
{
	resid_t id = _agR_new(net->lrm);
	if (id == INVALID_ID) {
		return INVALID_ID;
	}

	struct conn * c = (struct conn*)_agR_get(net->lrm, id);
	memset(c, 0, sizeof(struct conn));
	c->id   = id;

	memcpy(&c->handler, handler, sizeof(c->handler));
	c->ctx = ctx;

	int done = 0;
	c->fd = connect_to(host, port, &done);
	if (c->fd == -1) {
		_agR_free(net->lrm, id);
		return -1;
	}

	if (done)  {
		c->status = cs_connected_wait_cb;
		_network_active(net, c);
	} else {
		c->status = cs_connecting;
		conn_set_event(net, c, EPOLLOUT);
	}
	return id;
}

resid_t _agN_listen (struct network * net,
        const char * host, short port, int backlog,
	network_handler * handler, void * ctx)
{
	resid_t id = _agR_new(net->lrm);
	if (id == INVALID_ID) {
		return INVALID_ID;
	}

	struct conn * c = (struct conn*)_agR_get(net->lrm, id);
	memset(c, 0, sizeof(struct conn));
	c->id   = id;

	memcpy(&c->handler, handler, sizeof(c->handler));
	c->ctx = ctx;

	c->fd = listen_on(host, port, backlog);
	if (c->fd == -1) {
		_agR_free(net->lrm, id);
		return -1;
	}

	c->status = cs_listening;
	conn_set_event(net, c, EPOLLIN);
	return id;
}

resid_t _agN_attach(struct network * net, int fd, network_handler * handler, void * ctx)
{
	resid_t id = _agR_new(net->lrm);
	if (id == INVALID_ID) {
		return INVALID_ID;
	}

	struct conn * c = (struct conn*)_agR_get(net->lrm, id);
	memset(c, 0, sizeof(struct conn));
	c->id   = id;

	memcpy(&c->handler, handler, sizeof(struct network_handler));
	c->ctx = ctx;
	c->fd = fd;

	c->status = cs_connected;
	conn_set_event(net, c, EPOLLIN);
	return id;
}

int _agN_detach (struct network * net, resid_t conn)
{
	struct conn * c = (struct conn*)_agR_get(net->lrm, conn);
	if (c == 0 || c->status == cs_closed || c->status == cs_closing) {
		return -1;
	}

	int fd = c->fd;

	c->fd = -1;
	_agN_close(net, conn);

	return fd;
}

int _agN_send(struct network * net, resid_t conn, const void * buff, size_t len)
{
	struct conn * c = (struct conn*)_agR_get(net->lrm, conn);
	// if (c == 0 || (c->status != cs_connecting && c->status != cs_connected) ) {
	if (c == 0 || (c->status != cs_connected) ) {
		return -1;
	}

	if (len == 0) {
		// set event and exit
		return conn_set_event(net, c, EPOLLIN|EPOLLOUT);
	}

#if 1
	if (c->status == cs_connected && (c->wbuf == 0 || _agB_size(c->wbuf) == 0) && len > 0) {
		//TODO: send immediately
		int ret = send(c->fd, buff, len, 0);
		if (ret > 0) {
			buff = ((char*)buff) + ret;
			len  -= ret;
		}
	}
#endif

	if (len > 0) {
		if (c->wbuf == 0) {
			c->wbuf = _agB_new(DEFAULT_BUFFER_SIZE);
			if (c->wbuf == 0) {
				return -1;
			}
		}

		void * ptr = _agB_buffer(c->wbuf, len);
		if (ptr == 0) {
			return -1;
		}

		memcpy(ptr, buff, len);

		conn_set_event(net, c, EPOLLIN|EPOLLOUT);
	}
	return 0;
}

int _agN_writev (struct network * net, resid_t conn, struct iovec *iov, int iovcnt)
{
	struct conn * c = (struct conn*)_agR_get(net->lrm, conn);
	// if (c == 0 || (c->status != cs_connecting && c->status != cs_connected) ) {
	if (c == 0 || (c->status != cs_connected) ) {
		return -1;
	}

	if (c->status == cs_connected && (c->wbuf == 0 || _agB_size(c->wbuf) == 0)) {
		//TODO: send immediately
		ssize_t ret = writev(c->fd, iov, iovcnt);
		int i;
		for(i = 0; i < iovcnt && ret > 0; i++) {
			if ((size_t)ret > iov[i].iov_len) {
				ret -= iov[i].iov_len;
				iov[i].iov_len = 0;
			} else {
				iov[i].iov_base = ((char*)iov[i].iov_base) + ret;
				iov[i].iov_len -= ret;
				break;
			}
		}
	}

	int i;
	for(i = 0; i < iovcnt; i++) {
		if (iov[i].iov_len > 0) {
			if (c->wbuf == 0) {
				c->wbuf = _agB_new(DEFAULT_BUFFER_SIZE);
				if (c->wbuf == 0) {
					return -1;
				}
			}
			_agB_write(c->wbuf, iov[i].iov_base, iov[i].iov_len);
		}
	}

	if (c->wbuf && _agB_size(c->wbuf) > 0) {
		conn_set_event(net, c, EPOLLIN|EPOLLOUT);
	}
	return 0;
}


void * _agN_buffer(struct network * net, resid_t conn, size_t len)
{
	struct conn * c = (struct conn*)_agR_get(net->lrm, conn);
	if (c == 0 || (c->status != cs_connecting && c->status != cs_connected) ) {
		return 0;
	}
	if (c->wbuf == 0) {
		c->wbuf = _agB_new(DEFAULT_BUFFER_SIZE);
	}

	void * ptr = _agB_buffer(c->wbuf, len);

	conn_set_event(net, c, EPOLLIN|EPOLLOUT);
	return ptr;
}

static void _network_active(struct network * net, struct conn * c)
{
	if (c->next == 0 && c->in_active_list == 0) {
		c->next = net->active_list;
		net->active_list = c;
		c->in_active_list =1;
	}

	// just for debug
	struct conn* head =net->active_list;
	struct conn* n =head;
	while(n){
		n =n->next;
		assert(n != head);
	}
}

int _agN_set_handler(struct network * net, resid_t conn, network_handler * handler, void * ctx)
{
	struct conn * c = (struct conn*)_agR_get(net->lrm, conn);
	if (c) {
		memcpy(&c->handler, handler, sizeof(struct network_handler));
		c->ctx = ctx;

		_network_active(net, c);

		if (c->wbuf == 0 || _agB_size(c->wbuf) == 0) {
			return conn_set_event(net, c, EPOLLIN);
		} else {
			return conn_set_event(net, c, EPOLLIN|EPOLLOUT);
		}
		return 0;
	}
	return -1;
}


void _agN_set_timer(struct network * net, void (*cb)(time_t now, void *), void * ctx)
{
	net->timer.cb = cb;
	net->timer.ctx = ctx;
}

void _agN_set_tick(struct network * net, void (*cb)(void *), void * ctx)
{
	net->tick.cb = cb;
	net->tick.ctx = ctx;
}


int _agN_get_fd(struct network * net, resid_t conn)
{
	struct conn * c = (struct conn*)_agR_get(net->lrm, conn);
	if (c) {
		return c->fd;
	} 
	return -1;
}

#if 0
int _agN_push(struct network * net, int id, resid_t conn, const void * buf, size_t len)
{
	return -1;
}
#endif

////////////////////////////////////////////////////////////////////////////////
//  helper

static struct network * _net_instance = 0;

int agN_init(size_t max)
{
	if (_net_instance) { return -1; }

	signal(SIGPIPE, SIG_IGN);
	_net_instance = _agN_new(max);

	return _net_instance ? 0 : -1;
}

int agN_loop()
{
	if (_net_instance) {
		return _agN_loop(_net_instance);
	}
	return -1;
}

void agN_stop()
{
	if (_net_instance) {
		_agN_stop(_net_instance);
	}
}

void agN_free()
{
	if (_net_instance) {
		_agN_free(_net_instance);
		_net_instance = 0;
	}
}

resid_t agN_connect(const char * host, short port, int timeout, network_handler * handler, void * ctx)
{
	if (_net_instance) {
		return _agN_connect(_net_instance, host, port, timeout, handler, ctx);
	} else {
		return INVALID_ID;
	}
}

resid_t agN_listen (const char * host, short port, int backlog, network_handler * handler, void * ctx)
{
	if (_net_instance) {
		return _agN_listen(_net_instance, host, port, backlog, handler, ctx);
	} else {
		return INVALID_ID;
	}
}

resid_t agN_attach(int fd, network_handler * handler, void * ctx)
{
	if (_net_instance) {
		return _agN_attach(_net_instance, fd, handler, ctx);
	} else {
		return INVALID_ID;
	}
}

int agN_detach (struct network * net, resid_t conn)
{
	if (_net_instance) {
		return _agN_detach(_net_instance, conn);
	} else {
		return -1;
	}
}

int agN_send(resid_t conn, const void * buff, int len)
{
	if (_net_instance) {
		return _agN_send(_net_instance, conn, buff, len);
	} else {
		return -1;
	}
}

int agN_writev (resid_t conn, struct iovec *iov, int iovcnt)
{
	if (_net_instance) {
		return _agN_writev(_net_instance, conn, iov, iovcnt);
	} else {
		return -1;
	}
}

void agN_close(resid_t conn)
{
	if (_net_instance) {
		return _agN_close(_net_instance, conn);
	}
}

int agN_set_handler(resid_t conn, network_handler * handler, void * ctx)
{
	if (_net_instance) {
		return _agN_set_handler(_net_instance, conn, handler, ctx);
	} else {
		return -1;
	}
}

void agN_set_timer(void (*cb)(time_t now, void *), void * ctx)
{
	if (_net_instance) {
		_agN_set_timer(_net_instance, cb, ctx);
	}
}

#if 0
int agN_push(int id, resid_t conn, const void * buf, size_t len)
{
	if (_net_instance) {
		return _agN_push(_net_instance, id, conn, buf, len);
	}
	return -1;
}
#endif

void    agN_set_tick(void (*cb)(void *), void * ctx)
{
	if (_net_instance) {
		_agN_set_tick(_net_instance, cb, ctx);
	}
}


int agN_get_fd(resid_t conn)
{
	if (_net_instance) {
		return _agN_get_fd(_net_instance, conn);
	} else {
		return -1;
	}
}
