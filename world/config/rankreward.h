#ifndef _SGK_RANK_REWARD_CONFIG_H_
#define _SGK_RANK_REWARD_CONFIG_H_


#define MAX_RANK_REWARD 30
#define MAX_RANK_TYPE 5
int load_rankreward_config();

struct RankRewardConfig {
	struct RankRewardConfig * prev;
	struct RankRewardConfig * next;
	int rank_type;
	int rank_lower;
	int rank_upper;
	int first_week_reward;
	int week_reward;
	int type;
	int id;
	int value;
};

struct RankRewardConfig * get_rank_reward_config(int rank_type, int rank, int first_week, int weekly);

#endif
