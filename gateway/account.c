#include <assert.h>
#include <string.h>
#include <arpa/inet.h>

#include "account.h"
#include "mtime.h"
#include "hash.h"
#include "log.h"
#include "map.h"
#include "database.h"
#include "package.h"
#include "config.h"

hash * account_hash = 0;
struct map* g_account_table =0;

//DECLARE_GET_KEY_FUNC(account, name)

static int32_t load_int64(const char* query_str, int64_t* v){
	// load data
	if(mysql_real_query(account_db->mysql, query_str, strlen(query_str)) != 0){
		WRITE_ERROR_LOG("mysql %s run sql [%s] failed: %s", account_db->name, query_str, mysql_error(account_db->mysql));
		account_db->lasterror = mysql_errno(account_db->mysql);
		return -1;
	}

	int32_t exist =0;
	// process data
	MYSQL_RES * result = mysql_store_result(account_db->mysql);
	if(result){
		MYSQL_ROW row; 
		while((row = mysql_fetch_row(result))){
			*v =atoll(row[0]);
			exist =1;
			break;
		}
		mysql_free_result(result);
	}
	return exist ? 0 : -1;
}

static void * get_name_of_account(void * data, size_t * len)  
{
	assert(len && data);
	account * acc = (account*)data;
	if(len) *len = strlen(acc->name);
	return acc->name;
}

static int DISABLE_NEW_ACCOUNT = -1;
int module_account_load(int argc, char * argv[])
{
	account_hash = hash_create_with_string_key(get_name_of_account);
	if (account_hash == 0) {
		return -1;
	}
	g_account_table =_agMap_new(0);
	return 0;
}

int module_account_reload()
{
	return 0;
}

void module_account_update(time_t now)
{
	if ( (DISABLE_NEW_ACCOUNT != -1) && ((now%5) != 0) ) {
		return;
	}

	int old_DISABLE_NEW_ACCOUNT = DISABLE_NEW_ACCOUNT;

	const char * sql = "SELECT `id` FROM `account` WHERE `account`='DISABLE_NEW_ACCOUNT'";
	int64_t pid = 0;
	if (load_int64(sql, &pid) == 0) {
		DISABLE_NEW_ACCOUNT = 1;
	} else {
		DISABLE_NEW_ACCOUNT = 0;
	}

	if (old_DISABLE_NEW_ACCOUNT != DISABLE_NEW_ACCOUNT) {
		WRITE_INFO_LOG("DISABLE_NEW_ACCOUNT set to %d", DISABLE_NEW_ACCOUNT);
	}
}

void module_account_unload()
{
	if (account_hash) {
		hash_destory(account_hash);
		account_hash =0;
	}
	if(g_account_table){
		_agMap_delete(g_account_table);
		g_account_table =0;
	}
}

account * account_new(const char * name, unsigned long long playerid)
{
	account * acc = (account*)malloc(sizeof(account));
	if (acc) {
		memset(acc, 0, sizeof(account));
		strncpy(acc->name, name, sizeof(acc->name) - 1);
		acc->playerid = playerid;
		acc->last_world = -1;
		hash_insert(account_hash, acc);
		account * tmp =(account*)_agMap_ip_set(g_account_table, playerid, acc);
		if (tmp) {
			acc->last_world = tmp->last_world;
			WRITE_INFO_LOG("player %llu account change %s -> %s", playerid, tmp->name, acc->name);
			free(tmp);
		}
	}
	return acc;
}

account * account_get(const char * name)
{
	account * acc = (account*)hash_get(account_hash,
			(void*)name, strlen(name));
	return acc;
}
account * account_get_by_pid(unsigned long long pid){
	account* acc =(account*)_agMap_ip_get(g_account_table, pid);
	return acc;
}

static void 
_do_write_account_log(resid_t conn, struct network *net, const char *name, unsigned long long pid, const char * data, size_t len){
    char ip[256];
    ip[0] = 0;
    do{
        if (len < sizeof(struct client_header)) {
            break;
        }
        struct client_header * h = (struct client_header*)data; 
        uint32_t package_len = ntohl(h->len);
        if (len < package_len) {
            break;
        }
        uint32_t cmd  = ntohl(h->cmd);
        if (cmd != C_LOGIN_REQUEST) {
            break;
        }
        const char * msg = data + sizeof(struct client_header);
        size_t msg_len = package_len - sizeof(struct client_header);
        size_t read_len = 0;
        amf_value * v = amf_read(msg, msg_len, &read_len);

        if (v == 0 || (read_len != msg_len) || (amf_type(v) != amf_array) ) {
            if(v) amf_free(v);
            break;
        }
        if (amf_size(v) >= 5 && amf_type(amf_get(v, 4)) == amf_string) {
            const char * str = amf_get_string(amf_get(v, 4));
            if (str && strncmp(str, "ip:", 3) == 0) {
                strncpy(ip, str+3, sizeof(ip));
            }
        }
        if (ip[0]==0) {
            int fd = _agN_get_fd(net, conn);
            if (fd>=0) {
                struct sockaddr_in addr;
                memset(&addr, 0, sizeof(addr));
                socklen_t addrlen = sizeof(addr);
                getpeername(fd, (struct sockaddr*)&addr, &addrlen);
                strncpy(ip, inet_ntoa(addr.sin_addr), sizeof(ip));
            } 
        }
        if (v) {
            amf_free(v);
        }
    }while(0);

    if(ip[0] == 0){
        strcpy(ip, "unknown");
    }

    agL_write_user_logger(CREATE_ACCOUNT_LOGGER, LOG_FLAT, "%d,%llu,%s,%s", (int)agT_current(), pid, name, ip); 
}

int32_t account_parse_pid_by_name(resid_t conn, struct network *net, const char* name, unsigned long long* ppid, const char * data, size_t len, unsigned int serverid){
	// parse name
	char real_name[128] ={0};
	strncpy(real_name, name, 96);
	
	// try parse as ai
	char* pos =strstr(real_name, "@ai");
	if(pos){
		*pos =0;
		if(1 == sscanf(real_name, "%llu", ppid)){
			WRITE_DEBUG_LOG("parse ai pid is %llu", *ppid);
			return 0;
		}
		else{
			WRITE_DEBUG_LOG("fail to parse ai account %s", real_name);
			return -1;
		}
	}

	// parse as player
	account* a =account_get(real_name);
	if(a){
		*ppid =a->playerid;
		return 0;
	}
	else{
		char query_sql[256] ={0};
		sprintf(query_sql, "SELECT `id` FROM `account` WHERE `account`=\"%s\"", real_name);
		int64_t pid =0;
		if(0 == load_int64(query_sql, &pid)){
			NTOHL_PID_AND_SID(pid, serverid);
			account_new(real_name, pid);
			*ppid =pid;
			return 0;
		}
		else{
			if (DISABLE_NEW_ACCOUNT == 1) {
				return -1;
			}

			if(0 != database_update(account_db, "INSERT INTO `account`(`account`, `from`, `game`)VALUES(\"%s\", 0, 0)", real_name)){
				account_db->lasterror = mysql_errno(account_db->mysql);
				WRITE_ERROR_LOG("fail to call %s, mysql error %s", __FUNCTION__, mysql_error(account_db->mysql));
				return -1;
			}
			pid =database_last_id(account_db);
			NTOHL_PID_AND_SID(pid, serverid);
			account_new(real_name, pid);
			*ppid =pid;
            _do_write_account_log(conn, net, real_name, pid, data, len);
			return 0;
		}
	}
}
int account_change(unsigned long long pid, const char* new_name){
	account* acc =account_get_by_pid(pid);
	if(!acc){
		WRITE_ERROR_LOG("%llu fail to change account to %s, account is not exist", pid, new_name);
		return -1;
	}
	// set db
	if(0 != database_update(account_db, "UPDATE `account` SET `account`=%s WHERE `id`=%llu", new_name, pid)){
		account_db->lasterror = mysql_errno(account_db->mysql);
		WRITE_ERROR_LOG("%llu fail to change account to %s, %s", pid, new_name, mysql_error(account_db->mysql));
		return -1;
	}
	// prepare old name
	char old_name[sizeof(acc->name)] ={0};
	strcpy(old_name, acc->name);

	// set new name
	memset(acc->name, 0, sizeof(acc->name));
	strncpy(acc->name, new_name, sizeof(acc->name) - 1);
	
	// add new to hash
	hash_insert(account_hash, acc);

	// delete old from account hash
	hash_remove(account_hash, (void*)(old_name), strlen(old_name));
	return 0;
}
