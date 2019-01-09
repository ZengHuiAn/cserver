
#include <assert.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <libgen.h>

#include "memory.h"
#include "config.h"
#include "logic_config.h"
#include "log.h"

#include "config/general.h"
#include "config/hero.h"
#include "config/talent.h"
#include "config/item.h"
#include "config/equip.h"
#include "config/item_package.h"
#include "config/fight.h"
#include "config/quest.h"
#include "config/title.h"
#include "config/common.h"
#include "config/openlv.h"
#include "config/buff.h"
#include "config/aiExp.h"
#include "config/compensate.h"
#include "config/fashion.h"
#include "config/rankreward.h"

#define CHECK_CALL(func) \
	do { \
		WRITE_DEBUG_LOG(#func); \
		if(func() != 0) { \
			WRITE_ERROR_LOG("call " #func " failed"); \
			return -1; \
		} \
	} while(0)


static struct heap * _heap = 0;

struct heap * logic_config_get_heap()
{
	if (_heap == 0) {
		_heap = _agMH_new(4096);
	}
	return _heap;
}

int reload_config = 0;

int module_logic_config_load(int argc, char * argv[])
{
	srand(time(0));
	return module_logic_config_reload();
}

int module_logic_config_reload()
{
	if (_heap) {
		_agMH_delete(_heap);
		_heap = 0;
	}

	srand(time(0));

#define LOAD_CONFIG(name) CHECK_CALL(load_##name##_config)

	// load game logic config
	LOAD_CONFIG(general);
	LOAD_CONFIG(item);
	LOAD_CONFIG(hero);
	LOAD_CONFIG(talent);
	LOAD_CONFIG(equip);
	LOAD_CONFIG(fight);
	LOAD_CONFIG(quest);
	LOAD_CONFIG(title);
	LOAD_CONFIG(common);
	LOAD_CONFIG(openlev);
	LOAD_CONFIG(buff);
	LOAD_CONFIG(ai_exp);
	LOAD_CONFIG(compensate);
	LOAD_CONFIG(fashion);
	LOAD_CONFIG(rankreward);
	return 0;
}

void module_logic_config_update(time_t now)
{
	if (reload_config == 1) {
		reload_config = 0;
		module_logic_config_load(0, 0);
	}
}

static struct pbc_env * g_env = NULL;
void module_logic_config_unload()
{
	if (g_env) {
		pbc_delete(g_env);
		g_env = NULL;
	}



	if (_heap) {
		_agMH_delete(_heap);
	}
}


struct pbc_env * getConfigEnv()
{
    if (g_env == NULL)
    {
        struct pbc_slice slice;
        g_env = pbc_new();

        FILE * file   = fopen("../protocol/config.pb", "rb");
        if (file == NULL)
        {
            return NULL;
        }

        fseek(file, 0, SEEK_END);
        int size = ftell(file);
        fseek(file, 0, SEEK_SET);
        char * buffer = (char*)malloc(size);
        if ((int)fread(buffer, 1, size, file) != size)
        {
            free(buffer);
            fclose(file);
            return NULL;
        }

        fclose(file);
        slice.buffer = buffer;
        slice.len = size;
        pbc_register(g_env, &slice);
        free(slice.buffer);
    }
    return g_env;
}
