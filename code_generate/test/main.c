#include <stdio.h>
#include <string.h>

#include "database.h"
#include "Player.h"

int test()
{
#if 0
	struct Player player;
	memset(&player, 0, sizeof(player));
	player.id = 6;
	//player.dirty = 1;
	
	player.property.pid = 6;
	
	if (agData_Property_load(&player.property) != 0) {
		printf("agData_Player_load failed\n");
		return -1;
	}

	if (player.property.dirty) {
		player.property.exp = 0;
		player.property.name = "rex";
		player.property.dirty = 0;
		if (agData_Property_new(&player.property) != 0) {
			printf("agData_Player_new failed\n");
			return -1;
		}
	} else {
		struct Equip * equips = 0;
		agData_Equip_load(&equips, player.id);
		while(equips) {
			agData_Equip_dump(equips);
			equips = equips->next;
		}

		struct Hero * heros = 0;
		agData_Hero_load(&heros, player.id);

		while(heros) {
			agData_Hero_dump(heros);
			agData_Hero_update_exp(heros, heros->exp + 1);
			heros = heros->next;
		}
	}

	//agData_Property_dump(&player);
	//agData_Equip_dump(&player);
	//agData__dump(&player);
	//printf("--------\n");

	agData_Property_update_exp(&player.property, 3);
	agData_Property_update_name(&player.property, "aaa");

	//agData_Player_dump(&player);
	//printf("--------\n");

	/*
	if (agData_Property_save(&player.property) != 0) {
		printf("agData_Player_save failed\n");
	}
	*/

	DATA_FLUSH_ALL();

	/*
	if (agData_Player_delete(&player) != 0) {
		printf("agData_Player_delete failed\n");
	}
	*/
#endif
	return 0;
}

int foo(size_t i) {
	return (2 * (i%2) - 1) * (((i+1)/2));
}

int bar(size_t pos, size_t s, size_t i) {
	return  (s + pos + foo(i)) % s;
}

int main(int argc, char * argv[])
{
	int i;
	for (i = 0; i < 20; i++) {
		printf("%d %d\n", i, bar(5, 20, i));
	}

	return 0;


	agDB_load();

	test();

	agDB_unload();

	return 0;
}
