
#include "database.h"

#include "log.h"

#include <assert.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <stdarg.h>

#include "config.h"

#include "database.h"
#include "log.h"

#include <assert.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <mysql.h>
#include "config.h"


/*
static const char * _mysql_host   = "127.0.0.1";
static int          _mysql_port   = 3306;
static const char * _mysql_user   = "root";
static const char * _mysql_passwd = 0;
static const char * _mysql_db     = "aGame";
static MYSQL *      _mysql        = 0;
static const char * _mysql_socket = 0;
*/

struct DBHandler * role_db;
// struct DBHandler * log_db;
struct DBHandler * account_db;


struct DBHandler _role_db = {
	"role",
	"localhost",
	3306,
	"agame",
	"agame@123",
	"aGame",
	"",
	0,
	0
};

/*
struct DBHandler _log_db = {
	"role",
	"localhost",
	3306,
	"agame",
	"agame@123",
	"aGameLog",
	"",
	0,
	0
};
*/

struct DBHandler _account_db = {
	"role",
	"localhost",
	3306,
	"agame",
	"agame@123",
	"aGameAccount",
	"",
	0,
	0
};

#define ATOI(x, def) ( (x) ? atoi(x) : (def))

static int DBHandlerInit(struct DBHandler * handler, xml_node_t * node)
{
	if (node == 0) return -1;

	strncpy(handler->name, xmlGetName(node), sizeof(handler->name));
	strncpy(handler->host, xmlGetValue(xmlGetChild(node, "host", 0), "localhost"), sizeof(handler->host));
	handler->port = ATOI(xmlGetValue(xmlGetChild(node, "port", 0), 0), 3306); 
	strncpy(handler->user, xmlGetValue(xmlGetChild(node, "user", 0), "root"), sizeof(handler->user));
	strncpy(handler->passwd, xmlGetValue(xmlGetChild(node, "passwd", 0), ""), sizeof(handler->passwd));
	strncpy(handler->db, xmlGetValue(xmlGetChild(node, "db", 0), ""), sizeof(handler->db));
	strncpy(handler->socket, xmlGetValue(xmlGetChild(node, "socket", 0), ""), sizeof(handler->socket));
	handler->lasterror = 0;
	return 0;
}

static int DBHandlerConnect(struct DBHandler * handler)
{
	if (handler == 0) {
		WRITE_ERROR_LOG("DBHandlerConnect failed: handler = NULL");
		return -1;
	}
	
	if (handler->mysql) {
		mysql_close(handler->mysql);
	}

	handler->mysql = mysql_init(0);

	const char * host   = handler->host[0] ? handler->host : "localhost";
	const char * user   = handler->user[0] ? handler->user : "root";
	const char * passwd = handler->passwd[0] ? handler->passwd : 0;
	const char * db     = handler->db[0] ? handler->db : 0;
	int          port   = handler->port ? handler->port : 3306;
	const char * socket = handler->socket[0] ? handler->socket : 0;

	if (mysql_real_connect(handler->mysql, host, user, passwd, db, port, socket, 0) == 0) {
		WRITE_ERROR_LOG("mysql_real_connect %s failed: %s", handler->name, mysql_error(handler->mysql));
		handler->lasterror = mysql_errno(handler->mysql);
		mysql_close(handler->mysql);
		handler->mysql = 0;
		return -1;
	}
	WRITE_INFO_LOG("mysql_real_connect %s %s:%d success", handler->name, host, port);

	const char * u = "set names utf8";
	mysql_real_query(handler->mysql, u, strlen(u));

	return 0;
}

static void DBHandlerRelease(struct DBHandler* handler)
{
	if (handler && handler->mysql) {
		mysql_close(handler->mysql);
		handler->mysql = 0;
	}
}

static void DBHandlerPing(struct DBHandler * handler)
{
	if (handler) {
		if (handler->mysql) {
			if (mysql_ping(handler->mysql) != 0) {
				WRITE_ERROR_LOG("mysql %s ping failed: %s", handler->name, mysql_error(handler->mysql));
				handler->lasterror = mysql_errno(handler->mysql);
				DBHandlerRelease(handler);
			}
		} else {
			DBHandlerConnect(handler);
		}
	}
}

int module_database_load(int argc, char * argv[])
{
	role_db = &_role_db;
	// log_db  = &_log_db;
	account_db = &_account_db;

	return module_database_reload();
}

int module_database_reload()
{
	DBHandlerRelease(role_db);
	// DBHandlerRelease(log_db);
	DBHandlerRelease(account_db);

	// Role
	xml_node_t * node = agC_get("Database", "Game", 0);
	if (node) {
		DBHandlerInit(role_db, node);
		if (DBHandlerConnect(role_db) != 0) {
			return -1;
		}
	}

/*
	// Log
	node = agC_get("Database", "Log", 0);
	if (node) {
		DBHandlerInit(log_db, node);
		if (DBHandlerConnect(log_db) != 0) {
			return -1;
		}
	}
*/
	// Account
	node = agC_get("Database", "Account", 0);
	if (node) {
		DBHandlerInit(account_db, node);
		if (DBHandlerConnect(account_db) != 0) {
			return -1;
		}
	}
	return 0;
}

void module_database_unload()
{
	DBHandlerRelease(role_db);
	// DBHandlerRelease(log_db);
	DBHandlerRelease(account_db);

	mysql_library_end();
	
}

void module_database_update(time_t now)
{
	DBHandlerPing(role_db);
	// DBHandlerPing(log_db);
	DBHandlerPing(account_db);
}

#if 0
amf_value * mysql_to_amf(int type, const char * ptr, int len)
{
	switch(type) {
		case MYSQL_TYPE_TINY:
		case MYSQL_TYPE_SHORT:
		case MYSQL_TYPE_LONG:
		case MYSQL_TYPE_INT24:
			return amf_new_integer(atoll(ptr));
		case MYSQL_TYPE_FLOAT:
		case MYSQL_TYPE_DOUBLE:
		case MYSQL_TYPE_DECIMAL:
		case MYSQL_TYPE_TIMESTAMP:
		case MYSQL_TYPE_LONGLONG:
			return amf_new_double(atof(ptr));
		case MYSQL_TYPE_NULL:
		case MYSQL_TYPE_DATE:
		case MYSQL_TYPE_TIME:
		case MYSQL_TYPE_DATETIME:
		case MYSQL_TYPE_YEAR:
		case MYSQL_TYPE_NEWDATE:
		case MYSQL_TYPE_VARCHAR:
		case MYSQL_TYPE_BIT:
		case MYSQL_TYPE_NEWDECIMAL:
		case MYSQL_TYPE_ENUM:
		case MYSQL_TYPE_SET:
		case MYSQL_TYPE_TINY_BLOB:
		case MYSQL_TYPE_MEDIUM_BLOB:
		case MYSQL_TYPE_LONG_BLOB:
		case MYSQL_TYPE_BLOB:
		case MYSQL_TYPE_VAR_STRING:
		case MYSQL_TYPE_STRING:
		case MYSQL_TYPE_GEOMETRY:
		default:
			return amf_new_string(ptr, len);
	}
	return 0;
}
#endif

int database_query(struct DBHandler * handler, int(*cb)(struct slice * fields, void * ctx), void * ctx, const char * fmt, ...)
{
	if (handler == 0 || handler->mysql == 0) {
		WRITE_ERROR_LOG("mysql connection is gone");
		return -1;
	}

	char sql[4096];

	va_list args;
	va_start(args, fmt);
	size_t len = vsnprintf(sql, sizeof(sql), fmt, args);
	va_end(args);

	WRITE_DEBUG_LOG("%s", sql);

	if (len >= sizeof(sql)) {
		WRITE_ERROR_LOG("sql is too long");
		return 0;
	}

	if (mysql_real_query(handler->mysql, sql, len) != 0) {
		WRITE_ERROR_LOG("mysql %s run sql [%s] failed: %s", handler->name, sql, mysql_error(handler->mysql));
		handler->lasterror = mysql_errno(handler->mysql);
		//assert(0);
		return -1;
	}

	MYSQL_RES * result = mysql_store_result(handler->mysql);
	if (result) {
		unsigned int num_fields = mysql_num_fields(result);

		struct slice * values = (struct slice*)malloc(sizeof(struct slice) * num_fields);

		//MYSQL_FIELD * fields = mysql_fetch_fields(result);
		MYSQL_ROW row; 
		while ((row = mysql_fetch_row(result)))
		{
			unsigned long *lengths;
			lengths = mysql_fetch_lengths(result);

			unsigned int i;
			for(i = 0; i < num_fields; i++)
			{
				values[i].ptr = row[i];
				values[i].len = lengths[i];
			}
			cb(values, ctx);
		}

		mysql_free_result(result);
		free(values);
	} else  {
		if(mysql_field_count(handler->mysql) == 0) {
			 return 0;
		} else {
			WRITE_ERROR_LOG("mysql %s run sql [%s] failed: %s", handler->name, sql, mysql_error(handler->mysql));
			return -1;
		}
	}
	return 0;
}

int database_update(struct DBHandler * handler, const char * fmt, ...)
{
	if (handler == 0 || handler->mysql == 0) {
		WRITE_ERROR_LOG("mysql connection is gone");
		return -1;
	}

	char sql[4096];
	va_list args;
	va_start(args, fmt);
	size_t len = vsprintf(sql, fmt, args);
	va_end(args);

	WRITE_DEBUG_LOG("%s", sql);

	if (len >= sizeof(sql)) {
		WRITE_ERROR_LOG("sql is too long");
		return -1;
	}

	if (mysql_real_query(handler->mysql, sql, len) != 0) {
		WRITE_ERROR_LOG("mysql %s run sql [%s] failed: %s", handler->name, sql, mysql_error(handler->mysql));
		handler->lasterror = mysql_errno(handler->mysql);
		return -1;
	}
	return 0;
}

unsigned long long database_last_id(struct DBHandler * handler)
{
	return mysql_insert_id(handler->mysql);
}

const char * database_error(struct DBHandler * handler)
{
	return mysql_error(handler->mysql);
}

unsigned long database_escape_string(struct DBHandler * handler, char *to, const char *from, unsigned long length)
{
	return mysql_real_escape_string(handler->mysql, to, from, length);
}


unsigned int database_insert_blob(struct DBHandler * handler, char * fmt, void * ptr, size_t len, ...)
{
	char sql[4096];
	va_list args;
	va_start(args, len);
	size_t sql_len = vsprintf(sql, fmt, args);
	va_end(args);

	WRITE_DEBUG_LOG("%s", sql);

	MYSQL_BIND bind[1];

	MYSQL_STMT *stmt = mysql_stmt_init(handler->mysql);
	if (!stmt) {
		WRITE_ERROR_LOG("mysql_stmt_init(), out of memoryn");
		return -1;
	}

	if (mysql_stmt_prepare(stmt, sql, sql_len)) {
		WRITE_ERROR_LOG("mysql_stmt_prepare failed: %s", mysql_stmt_error(stmt));
		mysql_stmt_close(stmt);
		return -1;
	}

	memset(bind, 0, sizeof(bind));
	bind[0].buffer = ptr;
	bind[0].buffer_type = MYSQL_TYPE_BLOB;
	bind[0].length= &len;
	bind[0].is_null= 0;
	if (mysql_stmt_bind_param(stmt, bind)) {
		WRITE_ERROR_LOG("mysql_stmt_bind_param failed: %s", mysql_stmt_error(stmt));
		mysql_stmt_close(stmt);
		return -1;
	}

	/* Supply data in chunks to server */
	if (mysql_stmt_send_long_data(stmt,0, (const char*)ptr, len)) {
		WRITE_ERROR_LOG("mysql_stmt_send_long_data failed: %s", mysql_stmt_error(stmt));
		mysql_stmt_close(stmt);
		return -1;
	}

	/* Now, execute the query */
	if (mysql_stmt_execute(stmt)) {
		WRITE_ERROR_LOG("mysql_stmt_execute failed: %s", mysql_stmt_error(stmt));
		mysql_stmt_close(stmt);
		return -1;
	}
	mysql_stmt_close(stmt);
	return 0;
}

struct DBHandler * get_db_by_sid(int sid)
{
	return role_db;
}
