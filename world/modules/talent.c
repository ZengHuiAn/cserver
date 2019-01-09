#include <assert.h>
#include <string.h>
#include "property.h"
#include "database.h"
#include "log.h"
#include "package.h"
#include "notify.h"
#include "mtime.h"
#include "map.h"
#include "stringCache.h"
#include "event_manager.h"
#include "backend.h"
#include "protocol.h"
#include <stdint.h>
#include "dlist.h"
#include "logic/aL.h"
#include "talent.h"
#include "data/Talent.h"
#include "config/talent.h"
#include "data/Hero.h"
#include "hero.h"
#include "config/hero.h"
#include "modules/equip.h"

typedef struct tagTalentSet {
	struct Talent * list;

	struct map * talents[TalentType_MAX];
} TalentSet;


static char emptyTalent[TALENT_MAXIMUM_DATA_SIZE + 1];
void talent_init()
{
	int i;
	for (i = 0; i < TALENT_MAXIMUM_DATA_SIZE; i++) {
		emptyTalent[i] = '0';
	}
}

void * talent_new(Player * player)
{
	TalentSet * set = (TalentSet *)malloc(sizeof(TalentSet));
	memset(set, 0, sizeof(TalentSet));
	int i;
	for (i = 1; i < TalentType_MAX; i++) {
		set->talents[i] = _agMap_new(0);
	}
	set->list = NULL;

	return (void *)set;
}

static struct map * talent_get_map(TalentSet * set, int type)
{
	if (type > 0 && type < TalentType_MAX) {
		return set->talents[type];
	}
	return 0;
}


void * talent_load(Player * player)
{
	unsigned long long pid = player_get_id(player);
	struct Talent * list = NULL;
	if (DATA_Talent_load_by_pid(&list, pid) != 0) {
		return NULL;
	}

	TalentSet * set = (TalentSet *)malloc(sizeof(TalentSet));
	memset(set, 0, sizeof(TalentSet));

	int i;
	for (i = 1; i < TalentType_MAX; i++) {
		set->talents[i] = _agMap_new(0);
	}

	while (list) {
		struct Talent * cur = list;
		list= list->next;
		dlist_init(cur);

		struct map * m = talent_get_map(set, cur->talent_type);
		if (m) {
			_agMap_ip_set(m, cur->id, cur);
			dlist_insert_tail(set->list, cur);
		} else {
			free(cur);
		}
	}

	return set;
}

int talent_update(Player * player, void * data, time_t now)
{
	return 0;
}

int talent_save(Player * player, void * data, const char * sql, ...)
{
	return 0;
}

int talent_release(Player * player, void * data)
{
	TalentSet * set = (TalentSet *)data;
	if (set != NULL)
	{
		while (set->list)
		{
			struct Talent * node = set->list;
			dlist_remove(set->list, node);
			DATA_Talent_release(node);
		}

		int i;
		for (i = 1; i < TalentType_MAX; i++) {
			_agMap_delete(set->talents[i]);
		}
		free(set);
	}
	return 0;
}

static int talent_add_notify(struct Talent *pTalent)
{
	if (pTalent != NULL)
	{
		Player * player = player_get(pTalent->pid);
		if (player == NULL)
		{
			return RET_ERROR;
		}
		amf_value * c = amf_new_array(6);
		amf_set(c, 0, amf_new_integer(pTalent->refid));
		amf_set(c, 1, amf_new_double (pTalent->id)); // talent_get_surplus_point(player, pTalent->id)));
		amf_set(c, 2, amf_new_integer(pTalent->talent_type)); // talent_get_using_point(player, pTalent->id)));
		amf_set(c, 3, amf_new_string(pTalent->data, 0));
		return notification_set(pTalent->pid, NOTIFY_TALENT_INFO, pTalent->id, c);
	}
	return 1;
}


const char* talent_empty()
{
	return emptyTalent;
}

Talent * talent_next(Player * player, Talent * ite)
{
	TalentSet * set = (TalentSet*)player_get_module(player, PLAYER_MODULE_TALENT);
	return dlist_next(set->list, ite);
}

Talent * talent_get(Player * player, int type, unsigned long long id)
{
	TalentSet * set = (TalentSet*)player_get_module(player, PLAYER_MODULE_TALENT);
	Talent * talent = 0;

	if (type > 0 && type < TalentType_MAX) {
		talent = (Talent*)_agMap_ip_get(set->talents[type], id);
	}

	return talent;
}

int talent_set(Player * player, int type, unsigned long long id, int refid, const char * data)
{
	data = data ? data : emptyTalent;

	TalentSet * set = (TalentSet*)player_get_module(player, PLAYER_MODULE_TALENT);
	struct map * m = talent_get_map(set, type);
	if (m == 0) {
		return -1;
	}

	Talent * talent = (Talent*) _agMap_ip_get(m, id);
	if (talent == 0) {
		talent = (struct Talent *)malloc(sizeof(struct Talent));
		memset(talent, 0, sizeof(struct Talent));

		talent->pid = player_get_id(player);
		talent->data = agSC_get(emptyTalent, 0);
		talent->talent_type = type;
		talent->id = id;
		talent->refid = refid;

		DATA_Talent_new(talent);

		dlist_init(talent);
		dlist_insert_tail(set->list, talent);

		_agMap_ip_set(m, id, talent);
	}


	DATA_Talent_update_data(talent, data);
	DATA_Talent_update_refid(talent, refid);

	talent_add_notify(talent);

	return 0;
}
