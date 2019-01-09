#include "record.h"
#include "config.h"
#include "hash.h"
#include "mtime.h"
#include <stdio.h>

static hash * id_hash = 0;

typedef struct RecordInfo {
	struct RecordInfo * next;

	unsigned int id;
	FILE * file;
} RecordInfo;

static RecordInfo * l = 0;

RecordInfo * mallocStruct()
{
	RecordInfo * info = (RecordInfo*)malloc(sizeof(RecordInfo));
	info->next = l;
	l = info;
	return info;
}

void cleanStruct()
{
	while(l) {
		RecordInfo * c = l;
		l = c->next;

		fclose(c->file);
		free(c);
	}
}

DECLARE_GET_KEY_FUNC(RecordInfo, id);

int parseID(xml_node_t * node ,void * data)
{
	unsigned int id = atoll(xmlGetValue(node, 0));
	char fname[256] = {0};
	sprintf(fname, "./%u.rec", id);
	FILE * file = fopen(fname, "a");
	if (file == 0) {
		return -1;
	}

	RecordInfo * info = mallocStruct();

	info->id = id;
	info->file = file;

	void * p = hash_insert(id_hash, info);
	assert(p == 0);
	return 0;
}

int module_record_load(int argc, char * argv[])
{
	id_hash = hash_create_with_number_key(KEY_FUNC(RecordInfo, id));
	xml_node_t * node = agC_get("Record", 0);

	return foreachChildNodeWithName(node, "ID", parseID, 0);
}


int module_record_reload()
{
	module_record_unload();
	return module_record_load(0, 0);
}

void module_record_update(time_t now)
{
}

void module_record_unload()
{
	cleanStruct();
	if (id_hash) hash_destory(id_hash);
}

void record(unsigned int id, const char * msg, size_t len)
{
	if (id_hash == 0 || hash_size(id_hash) == 0) return;
	RecordInfo * info = (RecordInfo*)hash_get(id_hash, &id, sizeof(id));

	if (info) {
		assert(info->file);
		time_t now = agT_current();
		fwrite(&now, 1, sizeof(now), info->file);
		fwrite(msg, 1, len, info->file);
		fflush(info->file);
	}
}
