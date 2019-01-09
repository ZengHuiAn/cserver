#ifndef _A_GAME_WORLD_RANKREWARD_H_
#define _A_GAME_WORLD_RANKREWARD_H_

#include "network.h"
#include "module.h"
#include "pbc.h"
#include "amf.h"
#include "map.h"
#include "dispatch.h"
#include "backend.h"

DECLARE_MODULE(rankreward)

/*enum{
  GET_KING_RANK=1,
  GET_STAR_RANK=2,
  GET_KING_RANK_REWARD=3,
  GET_STAR_RANK_REWARD=4,
};*/
//uint32_t rank_flag=0;   //是否是新手

#define RANK_COUNT 100
#define RANK_TYPE_EXP 1
#define RANK_TYPE_STAR 2
#define RANK_TYPE_TOWER 4 
#define RANK_PERIOD 86400 
#define BEGIN_HOUR 0 

unsigned long long rank_exp_get(unsigned int index, unsigned int *value);
unsigned int rank_exp_set(unsigned long long pid, unsigned int exp);

unsigned long long rank_star_get(unsigned int index, unsigned int *value);
unsigned int rank_star_set(unsigned long long pid, unsigned int count);

unsigned long long rank_tower_get(unsigned int index, unsigned int *value);
unsigned int rank_tower_set(unsigned long long pid, unsigned int floor);

unsigned int get_rank_reward_begin();
unsigned int get_rank_reward_end();

int32_t get_flag_of_rank();
uint32_t get_first_begin_time();

#endif
