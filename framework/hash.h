#ifndef _A_GAME_COMM_HASH_H_
#define _A_GAME_COMM_HASH_H_

#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct hash hash;

typedef void * (*key_func)(void * data, size_t * len);
typedef unsigned int (*hash_func)(void * key, size_t len);
typedef int (*cmp_func)(void * key1, size_t len1, void * key2, size_t len2);

struct hash * hash_create(key_func get_key,
		hash_func hash_key,
		cmp_func cmp_key);

void hash_destory(hash * h);


struct hash * hash_create_with_string_key(key_func get_key);
struct hash * hash_create_with_number_key(key_func get_key);

void * hash_insert(struct hash * h, void * data);
void * hash_remove(struct hash * h, void * key, size_t key_len);
void * hash_get(struct hash * h, void * key, size_t key_len);

size_t hash_size(struct hash * h);

typedef void (*dump_val)(void * data);
void dump_hash(struct hash * h, dump_val dv);

struct hash_iterator {
	void * data;
};

struct hash_iterator * hash_next(struct hash * h, struct hash_iterator * ite);

#define DECLARE_GET_KEY_FUNC(type, field) \
	static void * get_##field##_of_##type(void * data, size_t * len)  \
	{\
		struct type * v = (struct type*)data; \
		*len = sizeof(v->field);\
		return &(v->field);\
	}

#define KEY_FUNC(type, field) get_##field##_of_##type



#ifdef __cplusplus
}
#endif

#endif
