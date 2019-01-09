#include <time.h>

#include "map.h"
#include "local.h"
#include "dlist.h"
#include "memory.h"
#include "aiLevel.h"
#include "database.h"
#include "modules/hero.h"
#include "log.h"
#include "mtime.h"
#include "array.h"

#define MAX_PLAYER_COUNT  100
AILevel * ai_level_array[AI_MAX_LEVEL] = {0};
struct array * player_level_array[AI_MAX_LEVEL] = {0};
static struct map * ai_level_map = NULL;
static struct map * player_level_map = NULL;

static void push_ai_level(unsigned long long pid, int level)
{
	if (level <= 0 || level > AI_MAX_LEVEL) {
		return;
	}

	AILevel * ailv = (AILevel *)malloc(sizeof(AILevel));
	memset(ailv, 0, sizeof(AILevel));
	ailv->pid = pid;
	ailv->level = level;

	AILevel * head = ai_level_array[level - 1];
	dlist_insert_tail(head, ailv);
	ai_level_array[level-1] = head;

	_agMap_ip_set(ai_level_map, pid, ailv);
}

static struct array * get_player_level_array(int level)
{
	struct array * arr = (struct array*)player_level_array[level-1];
	if (!arr) {
		arr = array_new(MAX_PLAYER_COUNT);
		player_level_array[level-1] = arr;
	}
	return arr;
}

static void push_player_level(unsigned long long pid, int level)
{
	struct array * arr = get_player_level_array(level);

	if (array_full(arr) || level <= 0 || level > AI_MAX_LEVEL) {
		return;
	}

	PlayerLevel * plv = (PlayerLevel *)malloc(sizeof(PlayerLevel));
	memset(plv, 0, sizeof(PlayerLevel));
	plv->pid = pid;
	plv->level = level;

	int count = array_count(arr);
	array_set(arr, count, plv);
	plv->idx = count;

	_agMap_ip_set(player_level_map, pid, plv);
}

static void pop_player_level( PlayerLevel * plv)
{
	struct array * arr = get_player_level_array(plv->level);

	int count = array_count(arr);
	assert(count > plv->idx && array_get(arr, plv->idx) == plv);

	if (plv->idx == count - 1) {
		array_set(arr, plv->idx, 0);
	} else {
        PlayerLevel * last = (PlayerLevel*)array_get(arr, count - 1);
		array_set(arr, plv->idx, last);
        last->idx = plv->idx;
		array_set(arr, count - 1, 0);
	}
}

static int onQueryPlayerLevel(struct slice * fields, void * ctx)
{
	unsigned long long pid = atoll((const char*)fields[0].ptr);
	int exp = atoll((const char*)fields[1].ptr);
	int level = transfrom_exp_to_level(exp, 1, LEADING_ROLE);

	if (pid <= AI_MAX_ID) {
		if (level) {
			//WRITE_DEBUG_LOG("AI %llu level %d", pid, level)
			push_ai_level(pid, level);
		} 
		return 0;
	}

	if (pid > 100000) {
		if (level) {
			//WRITE_DEBUG_LOG("Player %llu level %d", pid, level);
			push_player_level(pid, level);
		}
		return 0;
	}

	return -1;
}

AILevel * aiLevel_next(AILevel * iter, int level)
{
	
	AILevel * head = ai_level_array[level - 1];
	iter = dlist_next(head, iter);

	return iter;
}

#define RAND_RANGE(a, b) \
	( (a) == (b) ? (a) : ((a) + rand() % ((b)-(a)+1)))
unsigned long long GetAIModePID(int level) {
	int end = level + 5 > AI_MAX_LEVEL ? AI_MAX_LEVEL : level + 5;
	int i = 0;
	for (i = level; i <= end; i ++) {
		struct array * arr = player_level_array[level - 1];
		if (arr) {
			int count = array_count(arr);
			PlayerLevel * plv = (PlayerLevel *)array_get(arr, RAND_RANGE(1, count));
			return plv ? plv->pid : 0;
		}
	}

	return 0;
}

static void aiLevel_change(unsigned long long pid, int new_level)
{
	AILevel * ailv = (AILevel *)_agMap_ip_get(ai_level_map, pid);
	if (!ailv) {
		WRITE_DEBUG_LOG("%s:add ai %llu to level info", __FUNCTION__, pid);

		if (new_level) {
			push_ai_level(pid, new_level);
		}
		return;
	}

	if (new_level == ailv->level) {
		return;
	}
	
	int level = ailv->level;
	if (level) {
		AILevel * head = ai_level_array[level -1];
		if (!head) return;

		dlist_remove(head, ailv);
		ai_level_array[level-1] = head;

		if (new_level > AI_MAX_LEVEL || new_level <= 0) {
			_agMap_ip_set(ai_level_map, pid, 0);
			free(ailv);
			return;
		}

		ailv->level = new_level;
		head = ai_level_array[new_level-1];
		dlist_insert_tail(head, ailv);
		ai_level_array[new_level-1] = head;
		return;
	} 

	return;
}

static void playerLevel_change(unsigned long long pid, int new_level)
{
	PlayerLevel * plv = (PlayerLevel *)_agMap_ip_get(player_level_map, pid);
	if (!plv) {
		WRITE_DEBUG_LOG("%s:add player %llu to level info", __FUNCTION__, pid);
		push_player_level(pid, new_level);
		return;
	}

	if (new_level == plv->level) {
		return;
	}

	pop_player_level(plv);

	if (new_level > AI_MAX_LEVEL || new_level <= 0) {
		_agMap_ip_set(player_level_map, pid, 0);
		free(plv);
		return;
	}
	
	plv->level = new_level;

	struct array * arr = get_player_level_array(new_level);

	if (array_full(arr)) {
		_agMap_ip_set(player_level_map, pid, 0);
		free(plv);
		return;
	}

	int count = array_count(arr);
	array_set(arr, count, plv);
	plv->idx = count;
}

void onLevelChange(unsigned long long pid, int new_level) 
{
	if (pid <= AI_MAX_ID) {
		aiLevel_change(pid, new_level);
	} else {
		playerLevel_change(pid, new_level);
	}
}


int module_aiLevel_load(int argc, char * argv[]) 
{
	ai_level_map = _agMap_new(0);
	player_level_map = _agMap_new(0);	

	if (database_query(role_db, onQueryPlayerLevel, 0, "select pid, exp from hero where gid = %d", LEADING_ROLE) < 0) {
		WRITE_DEBUG_LOG("Load AI Level fail, database error");
		return 1;
	}

	return 0;
}

int module_aiLevel_reload()
{
	return 0;
}

void module_aiLevel_update(time_t now)
{
}

void module_aiLevel_unload()
{
	int i;
	int j;
	for (i = 0; i < AI_MAX_LEVEL; i++) {
		AILevel * ailv = ai_level_array[i];
		while(ailv) {
			AILevel * al = ailv;
			dlist_remove(ailv, al);
			free(al);
		}

	}

	for (i= 0; i < AI_MAX_LEVEL; i++) {
		struct array * arr = player_level_array[i];
		if (arr) {
			int size = array_size(arr);
			for (j = 0; j < size; j++) {
				PlayerLevel * plv = (PlayerLevel *)array_get(arr, j);
				if (plv) {
					free(plv);
				}
			}
			array_free(arr);
		}
	}

	_agMap_delete(ai_level_map);
	_agMap_delete(player_level_map);
}

