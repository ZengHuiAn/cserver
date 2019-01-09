#include <unistd.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <errno.h>
#include <string.h>

#include "shm.h"
#include "log.h"

void * shm_create(const char * name, int id, size_t size)
{
	key_t key = ftok(name, id);
	if (key < 0) {
		return 0;
	}

	int shmid = shmget(key, size, IPC_CREAT|IPC_EXCL|0666 );
	if (shmid < 0) {
		if (errno != EEXIST) {
			return 0;
		}

		WRITE_WARNING_LOG("Same shm seg (key=%08X) exist, now try to attach it...", key);
		shmid = shmget(key, size, 0666 );
		if(shmid < 0 ) {
			WRITE_WARNING_LOG("Attach to share memory %d failed, %s. Now try to touch it", shmid, strerror(errno));
			shmid = shmget(key, 0, 0666 );
			if (shmid < 0) {
				return 0;
			} else {
				WRITE_WARNING_LOG("First remove the exist share memory %d", shmid);
				if( shmctl(shmid, IPC_RMID, NULL) ) {
					WRITE_ERROR_LOG("Remove share memory failed, %s", strerror(errno));
					return 0;
				}

				shmid = shmget(key, size, IPC_CREAT|IPC_EXCL|0666 );
				if (shmid < 0 ) {
					WRITE_ERROR_LOG("Fatal error, alloc share memory failed, %s", strerror(errno));
					return 0;
				} 
			}
		}
	}
	WRITE_INFO_LOG("Successfully alloced share memory block, key = %08X, id = %d, size = %zu", key, shmid, size);
	return shmat(shmid, NULL, 0);
}

void * shm_attach(const char * name, int id)
{
	key_t key = ftok(name, id);
	if (key < 0) {
		return 0;
	}

	int shmid = shmget(key, 0, 0666 );
	if (shmid < 0) {
		WRITE_WARNING_LOG("Attach to share memory %d failed, %s.", key, strerror(errno));
		return 0;
	}
	return shmat(shmid, NULL, 0);
}


void   shm_destory(const char * name, int id)
{
	key_t key = ftok(name, id);
	if (key < 0) {
		return;
	}

	WRITE_DEBUG_LOG("Touch to share memory key = 0X%08X...", key);

	int shmid = shmget(key, 0, 0666 );
	if (shmid < 0 ) {
		WRITE_WARNING_LOG("Error, touch to shm failed, %s.", strerror(errno));
		return;
	} else {
		WRITE_DEBUG_LOG("Now remove the exist share memory %d", shmid);
		if (shmctl(shmid, IPC_RMID, NULL) ) {
			WRITE_ERROR_LOG("Remove share memory failed, %s", strerror(errno));
			return;
		}
		WRITE_INFO_LOG("Remove shared memory(id = %d, key = 0X%08X) successed.", shmid, key);
	}
}
