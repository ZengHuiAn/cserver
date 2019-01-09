#ifndef _A_GAME_WORLD_PLAYER_HELPER_H_
#define _A_GAME_WORLD_PLAYER_HELPER_H_


#define player_get_property(player) \
	((struct Property*)player_get_module((player), PLAYER_MODULE_PROPERTY))

#define player_get_resources(player) \
	((struct ResourcesData*)player_get_module((player), PLAYER_MODULE_RESOURCES))

#endif
