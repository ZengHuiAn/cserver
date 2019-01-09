#include <assert.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "database.h"
#include <mysql/mysql.h>

static MYSQL * _mysql = 0;

int agDB_query(int(*cb)(struct slice * fields, void * ctx), void * ctx, const char * fmt, ...)
{
	if (_mysql == 0) {
		return 0;
	}

	char sql[4096];

	va_list args;
	va_start(args, fmt);
	size_t len = vsnprintf(sql, sizeof(sql), fmt, args);
	va_end(args);

	printf("%s\n", sql);

	if (mysql_real_query(_mysql, sql, len) != 0) {
		printf("run sql [%s] failed: %s\n", sql, mysql_error(_mysql));
		//assert(0);
		return -1;
	}

	MYSQL_RES * result = mysql_store_result(_mysql);
	if (result) {
		unsigned int num_fields = mysql_num_fields(result);

		struct slice values[num_fields];
		//MYSQL_FIELD * fields = mysql_fetch_fields(result);
		MYSQL_ROW row; 
		while ((row = mysql_fetch_row(result)))
		{
			unsigned long *lengths;
			lengths = mysql_fetch_lengths(result);

			int i;
			for(i = 0; i < num_fields; i++)
			{
				values[i].ptr = row[i];
				values[i].len = lengths[i];
			}
			cb(values, ctx);
		}

		mysql_free_result(result);
	} else  {
		if(mysql_field_count(_mysql) == 0) {
			return 0;
		} else {
			printf("run sql [%s] failed: %s\n", sql, mysql_error(_mysql));
			//assert(0);
			return -1;
		}
	}
	return 0;
}

int agDB_update(const char * fmt, ...)
{
	if (_mysql == 0) {
		return 0;
	}

	char sql[4096];

	va_list args;
	va_start(args, fmt);
	size_t len = vsnprintf(sql, sizeof(sql), fmt, args);
	va_end(args);

	printf("%s\n", sql);

	if (mysql_real_query(_mysql, sql, len) != 0) {
		printf("run sql [%s] failed: %s\n", sql, mysql_error(_mysql));
		//assert(0);
		return -1;
	}
	return 0;
}

static const char * _mysql_host   = "192.168.1.230";
static int          _mysql_port   = 3306;
static const char * _mysql_user   = "rexzhao";
static const char * _mysql_passwd = "rexzhao";
static const char * _mysql_db     = "aGameX";

int agDB_load()
{
	_mysql = mysql_init(0);
	if (mysql_real_connect(_mysql, _mysql_host, _mysql_user, _mysql_passwd, _mysql_db, _mysql_port, 0, 0) == 0) {
		printf("mysql_real_connect failed: %s\n", mysql_error(_mysql));
		mysql_close(_mysql);
		_mysql = 0;
		return -1;
	}
	return 0;
}

void agDB_unload()
{
	mysql_close(_mysql);
	_mysql = 0;
}

unsigned long long agDB_last_id()
{
	return mysql_insert_id(_mysql);
}
