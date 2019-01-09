#ifndef _AI_FIGHT_DATA_H_
#define _AI_FIGHT_DATA_H_
//#include "player.h"

struct ai_info {
	unsigned long long pid;
	unsigned long long mode_pid;
	unsigned int level_percent;
	unsigned int fight_data_id;	
	unsigned int active_time;
};

void checkAndAddAIFightData(Player * player);
int getAIFightDataCount(int level);
struct pbc_rmessage * getAIFightData(Player * player);
int AddAIInfo(unsigned long long pid, unsigned long long mode_pid, unsigned int level_percent, unsigned int fight_data_id, unsigned int active_time);
int updateMaxLevel(int exp);
struct ai_info * GetAIInfo(unsigned long long pid);
unsigned long long QueryUnactiveAI(int ref_level, int * ai_level);
int UpdateAIActiveTime(unsigned long long pid, unsigned int active_time);
int FreshAIFightDataID(Player * player);
int BalanceAIStar(unsigned long long ai_pid);

int getMaxPlayerLevel();

#endif
