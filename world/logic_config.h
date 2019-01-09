#ifndef _A_GAME_WORLD_logic_config_h_
#define _A_GAME_WORLD_logic_config_h_

#include "module.h"
#include "memory.h"
#include "log.h"
#include "pbc_int64.h"

DECLARE_MODULE(logic_config);

struct heap * logic_config_get_heap();

struct pbc_env * getConfigEnv();


#define LOGIC_CONFIG_ALLOC(T, N) ((struct T*)_agMH_alloc(logic_config_get_heap(), sizeof(struct T) * N))
#define LOGIC_CONFIG_NEW_MAP() (_agMap_new(logic_config_get_heap()))

#define LOAD_PROTOBUF_CONFIG_BEGIN(filename, proto)  \
	struct pbc_rmessage * msg = 0; \
	char * buf = 0; \
	do { \
		struct pbc_env * env = getConfigEnv();\
		if (env == NULL) {\
			WRITE_ERROR_LOG("load protobuf config fail, config euv is null.");\
			return -1;\
		}\
		FILE * file = fopen(filename, "rb");\
		if (file == NULL) {\
			WRITE_ERROR_LOG("open %s fail.", filename);\
			return -1;\
		}\
		fseek(file, 0, SEEK_END);\
		int len = ftell(file);\
		buf = (char *)malloc(sizeof(char) * len);\
		memset(buf, 0, sizeof(char) * len);\
		fseek(file, 0, SEEK_SET);\
		if ((int)fread(buf, 1, len, file) != len) {\
			fclose(file); \
			WRITE_ERROR_LOG("read %s fail , read size error.", filename);\
			return -1;\
		}\
		fclose(file); \
		struct pbc_slice slice = {buf, len};\
		msg = pbc_rmessage_new(env, proto, &slice);\
		if (msg == NULL) {\
			free(buf);\
			WRITE_DEBUG_LOG("decode msg %s %s failed", filename, proto);\
			return -1;\
		} \
	} while (0)

#define LOAD_PROTOBUF_CONFIG_END(buf, msg)  do { pbc_rmessage_delete(msg); free(buf); } while(0)


#endif
