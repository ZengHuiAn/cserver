#include "hash.h"

#include <assert.h>
#include <string.h>
#include <stdio.h>

typedef struct element {
	void * data;

	struct element * next;
	unsigned int hash_val;
} element;

struct hash
{
	key_func  get_key;
	hash_func hash_key;
	cmp_func  cmp_key;

	unsigned int item_count;
	unsigned int buckets_size;
	element ** buckets;
};

static int default_cmp_key(void *key1, size_t len1, void * key2, size_t len2)
{
	if (len1 < len2) { return -1;}
	if (len1 > len2) { return 1; }
	return memcmp(key1, key2, len1);
}

static unsigned int default_hash_key(void *key , size_t len)
{
	unsigned int nhash = 0;
	const char * end = ((const char *)key) + len;
	const char * p = (const char*)key;
	while (p < end) {
		nhash += (nhash<<5) + nhash + *p++;
	}
	return nhash;
}

//#define ALLOC_TYPE_N(T, N) ((struct T*)malloc(sizeof(struct T) * (N)))
//#define ALLOC_TYPE(T) ALLOC_TYPE_N(T, 1)


static struct element * find_element(struct hash * h, int index,
		void * key, size_t key_len,
		struct element ** pprev)
{
	struct element * prev = 0;
	struct element * p = 0;

	if(pprev) *pprev = 0;
	p = h->buckets[index];
	while (p) {
		size_t len2;
		void * key2 = h->get_key(p->data, &len2);
		int cmp = h->cmp_key(key, key_len, key2, len2);
		if (cmp == 0) {
			if (pprev) *pprev = prev;
			return p;
		} else if (cmp > 0) {
			prev = p;
			p = p->next;
		} else {
			break;
		}
	}

	if (pprev) *pprev = prev;
	return 0;
}

static void hash_insert_element(struct hash * h, struct element * e)
{
	size_t key_len = 0;
	void * key = h->get_key(e->data, &key_len);
	unsigned int hash_val = e->hash_val;
	unsigned int index = hash_val % h->buckets_size;

	struct element * prev = 0;
	struct element * old_e = find_element(h, index, key, key_len, &prev);

	assert(old_e == 0);

	if (prev) {
		e->next = prev->next;
		prev->next = e;
	} else {
		e->next = h->buckets[index];
		h->buckets[index] = e;
	}
}

static void hash_resize(struct hash * h, unsigned int new_size)
{
	//if (new_size < h->buckets_size) return;

	struct element ** new_buckets = (struct element**)malloc(sizeof(element*) * new_size);
	if (new_buckets == 0) {
		return ;
	}

	unsigned int old_buckets_size = h->buckets_size;
	struct element ** old_buckets = h->buckets;

	memset(new_buckets, 0, sizeof(element*) * new_size);
	h->buckets =  new_buckets;
	h->buckets_size = new_size;

	unsigned int i = 0;
	for(i  = 0; i < old_buckets_size; i++) {
		struct element * e = old_buckets[i];
		while(e) {
			struct element * next = e->next;
			hash_insert_element(h, e);
			e = next;
		}
	}
	if (old_buckets) free(old_buckets);
	return;
}

//#define HASH_USE_PER_ALLOC 

#ifdef HASH_USE_PER_ALLOC
static element * free_element_list = 0;
//static void * * mem_alloc  = 0;
//static size_t mem_count = 0;
#endif

static struct element * alloc_element()
{
#ifdef HASH_USE_PER_ALLOC
	if (free_element_list == 0) {
		element * e = ALLOC_TYPE_N(element, 256);
		if (e) {
			//mem_alloc = (void**)realloc(mem_alloc, mem_count+1);
			//mem_alloc[mem_count++] = e;

			int i;
			for(i = 0; i < 256; i++, e++) {
				e->next = free_element_list;
				free_element_list = e;
			}
		}
	}

	if (free_element_list) {
		element * e = free_element_list;
		free_element_list = e->next;
		return e;
	}
#endif
	return (element*)malloc(sizeof(element));
}

static void free_element(struct element * e)
{
#ifdef HASH_USE_PER_ALLOC
	e->next = free_element_list;
	free_element_list = e;
	e->data = 0;
#else
	free(e);
#endif
}

////////////////////////////////////////////////////////////////////////////////


#ifdef __cplusplus
extern "C" {
#endif

struct hash * hash_create(key_func get_key,
		hash_func hash_key,
		cmp_func cmp_key)
{
	struct hash * h = (struct hash*)malloc(sizeof(hash));
	if (h == 0) return 0;
	h->get_key = get_key;

	h->hash_key = hash_key ? hash_key : default_hash_key;
	h->cmp_key = cmp_key ? cmp_key : default_cmp_key;

	h->item_count = 0;
	h->buckets_size = 0;
	h->buckets = 0;
	hash_resize(h, 128);
	return h;
}

void hash_destory(hash * h)
{
	assert(h);

	size_t i;
	for(i = 0; i < h->buckets_size; i++) {
		struct element * e = h->buckets[i];
		while(e) {
			struct element * next_e = e->next;
			free_element(e);
			e = next_e;
		}
	}
	free(h->buckets);
	free(h);
}

size_t hash_size(struct hash * h)
{
	return h->item_count;
}

void * hash_insert(struct hash * h, void * data)
{
	size_t key_len = 0;
	void * key = h->get_key(data, &key_len);
	unsigned int hash_val = h->hash_key(key, key_len);
	unsigned int index = hash_val % h->buckets_size;

	struct element * prev = 0;
	struct element * e = find_element(h, index, key, key_len, &prev);
	if (e) {
		void * old_data = e->data;
		e->data = data;
		e->hash_val = hash_val;
		return old_data;
	}

	e = alloc_element();
	e->data = data;
	e->hash_val = hash_val;

	if (prev) {
		e->next = prev->next;
		prev->next = e;
	} else {
		e->next = h->buckets[index];
		h->buckets[index] = e;
	}
	h->item_count++;

	if (h->item_count >= h->buckets_size) {
		hash_resize(h, h->buckets_size * 2);
	}
	return 0;
}

void * hash_remove(struct hash * h, void * key, size_t key_len)
{
	unsigned int hash_val = h->hash_key(key, key_len);
	unsigned int index = hash_val % h->buckets_size;

	struct element * prev = 0;
	struct element * e = find_element(h, index, key, key_len, &prev);
	if (e == 0) return 0;

	if (prev) {
		prev->next = e->next;
	} else {
		h->buckets[index] = e->next;
	}
	h->item_count--;
	void * data = e->data;
	free_element(e);
	return data;
}

void * hash_get(struct hash * h, void * key, size_t key_len)
{
	unsigned int index = h->hash_key(key, key_len) % h->buckets_size;

	struct element * e = find_element(h, index, key, key_len, 0);
	return e ? e->data : 0;
}

struct hash_iterator * hash_next(struct hash * h, struct hash_iterator * ite)
{
	size_t next_index = 0;
	if (ite) {
		struct element * e = (struct element*)ite;
		if (e->next) {
			return (struct hash_iterator*)e->next;
		} else {
			next_index = (e->hash_val % h->buckets_size) + 1;
		}
	}

	while(next_index < h->buckets_size) {
		if (h->buckets[next_index]) {
			struct element * e = h->buckets[next_index];
			return (struct hash_iterator*)e;
		}
		next_index ++;
	}
	return 0;
}

void dump_hash(struct hash * h, dump_val dv)
{
	unsigned int i;
	printf("hash : buckets size %u, item_count %u\n",
			h->buckets_size, h->item_count);
	for(i = 0; i < h->buckets_size; i++) {
		struct element * e = h->buckets[i];
		if (e == 0) continue;
			printf("|-[%d]\n", i);
		while(e) {
			if (e->next) {
				printf("|  |- %p/%u", e, e->hash_val);
			} else {
				printf("|  `- %p/%u", e, e->hash_val);
			}
			if (dv) {
				printf("(");
				dv(e->data);
				printf(")");
			}
			printf("\n");
			e = e->next;
		};
	}
}

struct hash * hash_create_with_string_key(key_func get_key)
{
	return hash_create(get_key, 0, 0);
}

unsigned int hash_number_key(void  * key, size_t len)
{
	static int little = -1;
	if (little == -1) {
		int i = 1;			
		char * c = (char*)&i;
		little = ((*c==1) ? 1 : 0);
	}

	unsigned int v = 0;
	const char * t = (const char*)key;
	size_t i;
	if (little) {
		for(i = len; i > 0; i--) {
			v = (v << 8) + t[i-1];
		}
	} else {
		for(i  = 0; i < len; i++) {
			v = v * 256 + t[i];
		}
	}
	return v;
}

struct hash * hash_create_with_number_key(key_func get_key)
{
	return hash_create(get_key, hash_number_key, 0);
}


#ifdef __cplusplus
}
#endif
