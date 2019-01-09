#ifndef _A_GAME_SHM_H_
#define _A_GAME_SHM_H_

#include <stdlib.h>

void * shm_create (const char * name, int id, size_t size);
void * shm_attach (const char * name, int id);
void   shm_destory(const char * name, int id);

#endif
