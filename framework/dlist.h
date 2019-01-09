#ifndef _COMM_DLIST_H_
#define _COMM_DLIST_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <assert.h>

typedef struct dlist_node{
    struct dlist_node * prev;
    struct dlist_node * next;
    void * data;
} dlist_node;

#define dlist_insert_before_x(l, n, prev, next) \
do { \
	assert((n)->next == 0 && (n)->prev == 0); \
	(n)->next = (l); \
	(n)->prev = (l)->prev; \
	(l)->prev->next = (n); \
	(l)->prev = (n); \
} while (0)

#define dlist_insert_after_x(l, n, prev, next) \
do { \
	assert((n)->next == 0 && (n)->prev == 0); \
	(n)->prev = (l); \
	(n)->next = (l)->next; \
	(l)->next->prev = (n); \
	(l)->next = (n); \
} while (0)

//make sure l is not n
#define dlist_insert_head_x(l, n, prev, next) \
do { \
	assert((n)->next == 0 && (n)->prev == 0); \
	if( (l) == 0 ) {  \
		(l) = (n)->next = (n)->prev = (n); \
	} else { \
		dlist_insert_before_x((l), (n), prev, next); \
		(l) = (n); \
	} \
} while(0)

//make sure l is not n
#define dlist_insert_tail_x(l, n, prev, next) \
do { \
	assert((n)->next == 0 && (n)->prev == 0); \
	if( (l) == 0 ) {  \
		(l) = (n)->next = (n)->prev = (n); \
	} else { \
		dlist_insert_before_x((l),(n), prev, next); \
	} \
} while (0)

#define dlist_remove_x(l, n, prev, next) \
do { \
	if( (n)->next == (n) ) { \
		(l) = 0;  \
		n->next = n->prev = 0; \
		break;\
	} \
	if( (n)->next == 0 || (n)->prev == 0 ) { \
		n->next = n->prev = 0; \
		break; \
	} \
	(n)->next->prev = (n)->prev; \
	(n)->prev->next = (n)->next; \
	if( (l) == (n) ) { \
		(l) = (n)->next; \
	} \
	(n)->next = (n)->prev = 0; \
} while(0)

#define dlist_next_x(head, cur, prev, next) \
	((head)==0||(cur)==0)?(head):(((cur)->next!=(head))?(cur)->next:0)

#define dlist_prev_x(head, cur, prev, next) \
	((head)==0||((cur)==(head)))?0:(((cur)==0)?(head)->prev:(cur)->prev)

#define dlist_init_x(n, prev, next) ((n)->prev = (n)->next = 0)

#define dlist_init(n)		  dlist_init_x(n, prev, next)
#define dlist_insert_before(l, n) dlist_insert_before_x(l, n, prev, next)
#define dlist_insert_after(l, n)  dlist_insert_after_x(l, n, prev, next)
#define dlist_insert_head(l, n)   dlist_insert_head_x(l, n, prev, next)
#define dlist_insert_tail(l, n)	  dlist_insert_tail_x(l, n, prev, next)
#define dlist_remove(l, n)	  dlist_remove_x(l, n, prev, next)
#define dlist_next(head, cur)	  dlist_next_x(head, cur, prev, next)
#define dlist_prev(head, cur)	  dlist_prev_x(head, cur, prev, next)

#define dlist_init_with(n, field)	 	\
	dlist_init_x(n, field.prev, field.next)

#define dlist_insert_before_with(l, n, field)  \
	dlist_insert_before_x(l, n, prev, next)

#define dlist_insert_after_with(l, n, field)  	\
	dlist_insert_after_x(l, n, field.prev, field.next)

#define dlist_insert_head_with(l, n, field)   	\
	dlist_insert_head_x(l, n, field.prev, field.next)

#define dlist_insert_tail_with(l, n, field)	\
	dlist_insert_tail_x(l, n, field.prev, field.next)

#define dlist_remove_with(l, n, field)	  	\
	dlist_remove_x(l, n, field.prev, field.next)

#define dlist_next_with(head, cur, field)	\
	dlist_next_x(head, cur, field.prev, field.next)

#define dlist_prev_with(head, cur, field)	\
	dlist_prev_x(head, cur, field.prev, field.next)


#ifdef __cplusplus
}
#endif

#endif  // _COMM_DLIST_H_
