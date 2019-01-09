#ifndef _A_GAME_COMM_NETWORK_H_
#define _A_GAME_COMM_NETWORK_H_

#include <stdlib.h>
#include <sys/uio.h>
#include <time.h>
#include <sys/uio.h>

#ifdef __cplusplus
extern "C" {
#else

# ifndef HAVE_BOOL
# define HAVE_BOOL
typedef int bool;
# endif 

#endif

#ifndef HAVE_RESID_T
#define HAVE_RESID_T

typedef unsigned int resid_t; 
# define INVALID_ID	((resid_t)-1)

#endif 

struct network;

typedef struct network_handler {
	void   (*on_connected)(struct network * net, resid_t c, void * ctx);
	void   (*on_accept)   (struct network * net, resid_t l, resid_t c, void * ctx);
	void   (*on_closed)   (struct network * net, resid_t c, int error, void * ctx);
	size_t (*on_message)  (struct network * net, resid_t c, const char * msg, size_t len, void * ctx);
} network_handler;

struct network * _agN_new (size_t max);
void    _agN_free(struct network * net);

int     _agN_tick(struct network * net, int timeout);
int     _agN_loop(struct network * net);
void    _agN_stop(struct network * net);

resid_t _agN_connect(struct network * net, const char * host, short port, int timeout, network_handler * handler, void * ctx);
resid_t _agN_listen (struct network * net, const char * host, short port, int backlog, network_handler * handler, void * ctx);
resid_t _agN_attach (struct network * net, int fd, network_handler * handler, void * ctx);
int     _agN_detach (struct network * net, resid_t id);
void    _agN_close  (struct network * net, resid_t conn);

int     _agN_send   (struct network * net, resid_t conn, const void * buff, size_t len);
void *  _agN_buffer (struct network * net, resid_t conn, size_t len);
int     _agN_writev (struct network * net, resid_t conn, struct iovec *iov, int iovcnt);

int     _agN_set_handler(struct network * net, resid_t conn, network_handler * handler, void * ctx);
void    _agN_set_timer(struct network * net, void (*cb)(time_t now, void *), void * ctx);
void    _agN_set_tick(struct network * net, void (*cb)(void *), void * ctx);

int     _agN_get_fd(struct network * net, resid_t conn);

////////////////////////////////////////////////////////////////////////////////
// helper
int     agN_init(size_t max);
int     agN_loop();
void    agN_stop();
void    agN_free();

resid_t agN_connect(const char * host, short port, int timeout, network_handler * handler, void * ctx);
resid_t agN_listen (const char * host, short port, int backlog, network_handler * handler, void * ctx);
resid_t agN_attach(int fd, network_handler * handler, void * ctx);
int     agN_detach (struct network * net, resid_t conn);
int     agN_send   (resid_t conn, const void * buff, int len);
int     agN_writev (resid_t conn, struct iovec *iov, int iovcnt);
void    agN_close  (resid_t conn);

int     agN_set_handler(resid_t conn, network_handler * handler, void * ctx);
void    agN_set_timer(void (*cb)(time_t now, void *), void * ctx);
void    agN_set_tick(void (*cb)(void *), void * ctx);

int     agN_get_fd(resid_t conn);

#ifdef __cplusplus
}
#endif

#endif
