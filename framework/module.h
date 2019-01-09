#ifndef _A_GAME_COMM_MODULE_H_
#define _A_GAME_COMM_MODULE_H_

#include <sys/time.h>

struct module {
	const char * name;
	int  (*on_load)(int argc, char * argv[]);
	int  (*on_reload)();
	void (*on_update)(time_t now);
	void (*on_unload)();
};

extern struct module modules[];

#define DECLARE_MODULE(m) \
	int  module_##m##_load(int argc, char * argv[]); \
	int  module_##m##_reload(); \
	void module_##m##_update(time_t now); \
	void module_##m##_unload(); 

#define IMPORT_MODULE(m) \
	{ #m, module_##m##_load, module_##m##_reload, module_##m##_update, module_##m##_unload}

#endif
