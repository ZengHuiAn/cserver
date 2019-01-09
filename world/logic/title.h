#ifndef _SGK_TITLE_H_
#define _SGK_TITLE_H_
	
#define TITLE_TYPE_NONE 0
#define TITLE_TYPE_PLAYER_LEVEL 1
#define TITLE_TYPE_PLAYER_ITEM 2 
#define TITLE_TYPE_ROLE_CAPACITY 3 
#define TITLE_TYPE_ROLE_STAGE 4 
#define TITLE_TYPE_ROLE_STAR 5
#define TITLE_TYPE_WEAPON_STAGE 6 
#define TITLE_TYPE_WEAPON_STAR 7 
#define TITLE_TYPE_FIGHT 8 
#define TITLE_TYPE_QUEST_FINISH 9 


int check_player_title(Player * player, int title);

#endif
