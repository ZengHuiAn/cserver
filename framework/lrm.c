#include <string.h>
#include <stdio.h>

#include "lrm.h"
#include "memory.h"

struct lrm {
	int max;
	size_t objsize;
	struct lresource * idle;
	char * data; //[1];
};

struct lresource {
	resid_t id;
	struct lresource * next;	// next == 0 表示正在使用
	//char data[0];
};


unsigned int _g_malloc = 0;
unsigned int _g_free   = 0;

static struct lresource resource_list_end;

#define ALIGN(s) (((s) + 3 ) & ~3)

#define LRM_RESOURCES_AT(lrm, index) ((struct lresource*)((lrm)->data + (lrm)->objsize * (index)))

static void init_lrm_idle_list(struct lrm * lrm)
{
	lrm->idle = &resource_list_end;

	int i;
	for(i = lrm->max - 1; i >= 0; i--) {
		struct lresource * res = LRM_RESOURCES_AT(lrm, i);
		res->id = i;

		res->next = lrm->idle;
		lrm->idle = res;
	}
}

struct lrm * _agRM_new(int max, size_t objsize)
{
	objsize = ALIGN(objsize) + sizeof(struct lresource);

	size_t size = sizeof(struct lrm) + objsize * max;
	struct lrm * lrm = (struct lrm*)MALLOC(size);
	if (lrm) {
		++_g_malloc;
		memset(lrm, 0, size);
		lrm->max = max;
		lrm->objsize = objsize;
		lrm->data = (char*)(lrm + 1);

		init_lrm_idle_list(lrm);
	}
	return lrm;	
}

void _agRM_free(struct lrm * lrm)
{
	if (lrm) {
		++_g_free;
		FREE(lrm);
	}
}

static struct lresource * get_lresource_by_index(struct lrm * lrm, int index)
{
	if (index < 0 || index >= lrm->max) {
		return 0;
	}
	return LRM_RESOURCES_AT(lrm, index);
}

static struct lresource * get_lresource(struct lrm * lrm, resid_t id)
{
	int idx = id % lrm->max;
	struct lresource * res = get_lresource_by_index (lrm, idx);
	if (res->id != id) {
		return 0;
	}
	return res;
}

resid_t _agR_new(struct lrm * lrm)
{
	if (lrm->idle == &resource_list_end) {
		return INVALID_ID;
	}

	struct lresource * res = lrm->idle;
	lrm->idle = res->next;
	res->next = 0;
	return res->id;
}

void *  _agR_get(struct lrm * lrm, resid_t id)
{
	struct lresource * res = get_lresource(lrm, id);
	return res ? (res+1) : 0;
}

void _agR_free(struct lrm * lrm, resid_t id)
{
	struct lresource * res = get_lresource(lrm, id);
	if (res) {
		// new id
		res->id += lrm->max;
		if(res->id == INVALID_ID) {
			res->id += lrm->max;
		}

		res->next = lrm->idle;
		lrm->idle = res;
	}
}

resid_t _agR_next(struct lrm * lrm, resid_t ite)
{
	int index = 0;
	if (ite == INVALID_ID) {
		index = 0;
	} else {
		index = (ite % lrm->max) + 1;
	}
		
	for(;index < lrm->max; index++) {
		struct lresource * res = get_lresource_by_index(lrm, index);
		if ( res->next == 0) {
			return res->id;
		}
	}
	return INVALID_ID;
}


void    _agR_statistic()
{
	printf("STATISTIC [agR] malloc %u, free %u\n", _g_malloc, _g_free);
}
