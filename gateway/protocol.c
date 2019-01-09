
#include <assert.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <libgen.h>

#include "protocol.h"
#include "log.h"

struct pbc_env * env = 0;

static void read_file (const char *filename , struct pbc_slice *slice) {
	FILE *f = fopen(filename, "rb");
	if (f == NULL) {
		slice->buffer = NULL;
		slice->len = 0;
		return;
	}
	fseek(f,0,SEEK_END);
	slice->len = ftell(f);
	fseek(f,0,SEEK_SET);
	slice->buffer = malloc(slice->len + 1);
	((char*)slice->buffer)[slice->len] = 0;
	fread(slice->buffer, 1 , slice->len , f);
	fclose(f);
}

int module_protocol_load(int argc, char * argv[]) 
{
	return module_protocol_reload();
}

int module_protocol_reload()
{
	struct pbc_slice slice;
	read_file("../protocol/agame.pb", &slice);
	if (slice.buffer == 0) {
		WRITE_DEBUG_LOG("read agame.pb failed");
		return -1;
	}

	env = pbc_new();
	pbc_register(env, &slice);
	free(slice.buffer);
	return 0;
}

void module_protocol_update(time_t now)
{
}

void module_protocol_unload()
{
	pbc_delete(env);
}


const char * rname(const char * name, char * buffer, size_t len)
{
	static char rname[256] = {0};
	if (buffer == 0) {
		buffer = rname;
		len = sizeof(rname);
	}

	snprintf(buffer, len, "com.agame.protocol.%s", name);
	return buffer;
}

struct pbc_wmessage * protocol_new_w(const char * name)
{
	if (name == 0 || name[0] == 0) { return 0; }

	char buffer[256];
	return pbc_wmessage_new(env, rname(name, buffer, sizeof(buffer)));
}

struct pbc_rmessage * protocol_new_r(const char * name, const char * ptr, size_t len)
{
	struct pbc_slice slice;
	slice.buffer = (void*)ptr;
	slice.len = len;

	char buffer[256];
	return pbc_rmessage_new(env, rname(name, buffer, sizeof(buffer)), &slice);
}
