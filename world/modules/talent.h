#ifndef _SGK_TALENT_H_
#define _SGK_TALENT_H_

#include "player.h"
#include "data/Talent.h"

enum TalentNotifyType
{
	Talent_Add = 0,
	Talent_Reset = 1,
	Talent_Update = 2,
	Talent_AddPoint = 3,
};

typedef struct TalentPointData {
        int id;
        int value;
} TalentData;

DECLARE_PLAYER_MODULE(talent);

// int talent_add_notify(struct Talent *pTalent, int type);
// int talent_add(Player * player, int id, int type, int level);
// int talent_get_surplus_point(Player * player, int id);
// int talent_get_using_point(Player * player, int id);
// int talent_reset_data(Player * player, struct Talent * pTalent);
//int talent_update_data(Player * player, struct Talent * pTalent, int index);
// int talent_update_data(Player * player, struct Talent * pTalent, TalentData * pData, int size);
// int talent_add_point(Player * player, int type, int point);
// int talent_check(Player * player, struct map * talent_map);

// int talent_update_sum(Player * player, int id, int level);


const char* talent_empty();
struct Talent * talent_get(Player * player, int type, unsigned long long id);
int talent_set(Player * player, int type, unsigned long long id, int refid, const char * data);

Talent * talent_next(Player * player, Talent * ite);


#endif
