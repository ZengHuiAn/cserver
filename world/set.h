#ifndef _A_GAME_SET_H_
#define _A_GAME_SET_H_

#include "map.h"
#include "dlist.h"

#define SET_DECLARE(TYPE)           struct map * m; TYPE * list
#define SET_INIT(SET)               SET->m = 0; SET->list = 0
#define SET_INSERT(SET, KEY, VALUE) dlist_init(VALUE); dlist_insert_tail(SET->list, VALUE); _agMap_ip_set(SET->m, KEY, VALUE)
#define SET_REMOVE(SET, KEY, VALUE) _agMap_ip_set(SET->m, KEY, (void*)0); dlist_remove(SET->list, VALUE)

#endif
