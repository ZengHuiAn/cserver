#ifndef _A_GAME_COMM_LRM_H_
#define _A_GAME_COMM_LRM_H_

#include <stdlib.h>

#ifndef HAVE_RESID_T
#define HAVE_RESID_T

typedef unsigned int resid_t; 
# define INVALID_ID	((resid_t)-1)

#endif 

struct lrm;

struct lrm * _agRM_new (int max, size_t objsize);
void         _agRM_free(struct lrm * lrm);

resid_t _agR_new (struct lrm * lrm);
void *  _agR_get (struct lrm * lrm, resid_t id);
void    _agR_free(struct lrm * lrm, resid_t id);

resid_t _agR_next(struct lrm * lrm, resid_t ite);

void    _agR_statistic();

#endif
