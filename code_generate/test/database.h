#ifndef _A_GAME_DATABASE_H_
#define _A_GAME_DATABASE_H_

#include <stdlib.h>

struct slice {
	const char * ptr;
	size_t len;
};

int agDB_load();
void agDB_unload();


int agDB_query(int(*cb)(struct slice * fields, void * ctx), void * ctx, const char * fmt, ...)
	__attribute__((format(printf, 3, 4)));
int agDB_update(const char * fmt, ...)
	__attribute__((format(printf, 1, 2)));

unsigned long long agDB_last_id();

#endif
