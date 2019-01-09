#ifndef _FASHION_H
#define _FASHION_H

typedef struct Fashion {
	int role_id;
	int fashion_id;
	int effect_type;
	int effect_value;
	int item;

	struct Fashion *next;
} Fashion;

Fashion * get_fashion_cfgs(int role_id);

Fashion * get_fashion_cfg(int role_id, int fashion_id);

Fashion * get_fashion_by_item(int role_id, int item_id);

int load_fashion_config();

#endif	/* _FASHION_H */
