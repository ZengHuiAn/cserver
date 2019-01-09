#ifndef _A_GAME_WORLD_MODULES_DATABASE_H_
#define _A_GAME_WORLD_MODULES_DATABASE_H_
#include <mysql.h>
#include "module.h"
#include "amf.h"

//MODULE_BEGIN(database)
DECLARE_MODULE(database)

struct slice {
	void * ptr;
	size_t len;
};

struct DBHandler {
	char name[32];
	char host[256];
	int  port;
	char user[64];
	char passwd[64];
	char db[64];
	char socket[256];
	MYSQL * mysql;
	unsigned int lasterror;
};

extern struct DBHandler * role_db;
// extern struct DBHandler * log_db;
extern struct DBHandler * account_db;

int database_query(struct DBHandler * handler, int(*cb)(struct slice * fields, void * ctx), void * ctx, const char * fmt, ...)
	__attribute__((format(printf, 4, 5)));
int database_update(struct DBHandler * handler, const char * fmt, ...)
	__attribute__((format(printf, 2, 3)));
unsigned long long database_last_id(struct DBHandler * handler);
const char * database_error(struct DBHandler * handler);
unsigned long database_escape_string(struct DBHandler * handler, char *to, const char *from, unsigned long length);

unsigned int database_insert_blob(struct DBHandler * handler, char * fmt, void * ptr, size_t len, ...)
	__attribute__((format(printf, 2, 5)));

struct DBHandler * get_db_by_sid(int sid);

#define agDB_query(...)  database_query(__VA_ARGS__)
#define agDB_update(...) database_update(__VA_ARGS__)
#define agDB_last_id()   database_last_id()

#endif
