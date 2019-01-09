#ifndef _COMPENSATE_H
#define _COMPENSATE_H

#include "array.h"

typedef struct CompensateCfg {
	int id;
	int num;
	
	int min_level;
	int max_level;

	int drop1;
	int drop2;
	int drop3;

	struct CompensateCfg *next;
} CompensateCfg;

int load_compensate_config();

CompensateCfg * get_compensate_cfg(int id, int level);

CompensateCfg * compensate_next(CompensateCfg *cfg);

#endif /* _COMPENSATE_H */
