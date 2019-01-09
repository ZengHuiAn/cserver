#include <assert.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>

#include "code_generate.h"

extern "C" {
#include "pbc.h"
}

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

struct pbc_env * load_protocol(const char * file)
{
	struct pbc_slice slice;
	read_file(file, &slice);
	if (slice.buffer == 0) {
		fprintf(stderr, "read file %s failed: %s\n", file, strerror(errno));
		return 0;
	}

	struct pbc_env * env = pbc_new();
	if (env == 0) {
		return 0;
	}
	pbc_register(env, &slice);
	free(slice.buffer);
	return env;
}


int main(int argc, char * argv[])
{

	struct pbc_env * env = load_protocol("./player.pb");
	agCG_generate(env, "PlayerData");

	//agCG_generate(env, "aGame.Hero");
	//agCG_generate(env, "aGame.Equip");
	agCG_generate(env, "LogData");

	return 0;
}
