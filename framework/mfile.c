#include <time.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <assert.h>
#include <stdint.h>

struct MFileHeader 
{
	uint32_t tag;	
	char  revert[12];
};

struct MFileIndex 
{
	uint32_t offset;
	uint32_t size;
	uint32_t time;
	uint32_t revert;
};

static const unsigned int max_record = 0x1 << 20;
static const unsigned int mfile_tag = 0x6164662e;

static const char * last_error = "";

static FILE * build_file(const char * fname)
{
	FILE * file = fopen(fname, "w+");
	if (file == 0) {
		last_error = strerror(errno);
		return 0;
	}

	struct MFileHeader head;
	memset(&head, 0, sizeof(head));
	head.tag = mfile_tag;
	
	// head.next   = 0;
	// head.offset = sizeof(head) + sizeof(struct MFileIndex) * max_record;

	if (fseek(file, 0, SEEK_SET) == -1) {
		last_error = strerror(errno);
		fclose(file);
		return 0;
	}

	if (fwrite(&head, sizeof(head), 1, file) != 1) {
		last_error = strerror(errno);
		fclose(file);	
		return 0;
	}

	if (fseek(file, sizeof(head) + sizeof(struct MFileIndex) * max_record, SEEK_SET) == -1) {
		last_error = strerror(errno);
		fclose(file);	
		return 0;
	}

	if (fwrite("\0", 1, 1, file) != 1) {
		last_error = strerror(errno);
		fclose(file);	
		return 0;
	}

	if (fseek(file, 0, SEEK_SET) == -1) {
		last_error = strerror(errno);
		fclose(file);
		return 0;
	}

	return file;
}

unsigned int mfile_write(unsigned int ref, const char * buff, size_t len, const char * prefix)
{
	unsigned int file_index = ref >> 20;
	unsigned int real_ref = ref & 0xfffff;
	if (prefix == 0) prefix = "./mfile";

	char fname[256] = {0};
	sprintf(fname, "%s_%u.data", prefix, file_index);

	FILE * file = 0;
	file = fopen(fname, "r+");

	if (file == 0) {
		file = build_file(fname);	
		if (file == 0) {
			last_error = strerror(errno);
			return -1;
		}
	}

	struct MFileHeader head;
	if (fread(&head, sizeof(head), 1, file) != 1) {
		last_error = strerror(errno);
		fclose(file);
		return -1;
	}

	if (head.tag != mfile_tag) {
		last_error = "tag error";
		fclose(file);
		return -1;
	}

	// write content
	if (fseek(file, 0, SEEK_END) != 0) {
		last_error = strerror(errno);
		fclose(file);
		return -1;
	}

	struct MFileIndex index;
	index.size   = len;
	index.offset = ftell(file);
	index.time   = time(0);
	index.revert = 0;

	if (fwrite(buff, 1, len, file) != len) {
		last_error = strerror(errno);
		fclose(file);
		return -1;
	}

	// write index
	if (fseek(file, sizeof(head) + sizeof(struct MFileIndex) * real_ref, SEEK_SET) == -1) {
		last_error = strerror(errno);
		fclose(file);
		return -1;
	}

	if (fwrite(&index, sizeof(index), 1, file) != 1) {
		last_error = strerror(errno);
		fclose(file);
		return -1;
	}
	fclose(file);

	return ref;
}

int mfile_read (unsigned int ref, char * buff, size_t len, const char * prefix)
{
	unsigned int file_index = ref >> 20;
	unsigned int real_ref = ref & 0xfffff;
	if (prefix == 0) prefix = "./mfile";

	if (real_ref >= max_record) {
		last_error = "invalid ref";
		return -1;	
	}

	char fname[256] = {0};
	sprintf(fname, "%s_%u.data", prefix ? prefix : "./mfile", file_index);

	FILE * file = fopen(fname, "rb");
	if (file == 0) {
		last_error = strerror(errno);
		return -1;
	}

	// read head
	struct MFileHeader head;
	fread(&head, sizeof(head), 1, file);
	if (head.tag != mfile_tag) {
		last_error = "tag error";
		fclose(file);
		return -1;
	}

	// read index
	struct MFileIndex index;
	fseek(file, sizeof(head) + sizeof(index) * real_ref, SEEK_SET);
	fread(&index, sizeof(index), 1, file);
	unsigned int offset = index.offset;
	size_t       size   = index.size;

	if (buff) {
		// read content only buff exists
		fseek(file, offset, SEEK_SET);
		if (len < size) {
			fread(buff, 1, len, file);
		} else {
			fread(buff, 1, size, file);
		}
	}

	fclose(file);
	return size;
}

const char * mfile_lasterror()
{
	return last_error;
}

#if 0
int main(int argc, char * argv[])
{
	char msg[256];
	unsigned int i;

	for (i = 0; i < 0xffffff; i++) {
		size_t l = sprintf(msg, "this is message %d", i);
		unsigned int ref = mfile_write(i, msg, l, 0);
		if (ref == -1) {
			printf("write %d failed: %s\n", i, mfile_lasterror());
			break;
		} else {
			if (i % 1000 == 0) {
				printf("%d, %u\n", i, ref);
			}
		}
	}

	for(i = 0; 1; i++) {
		int len = mfile_read(i, msg, sizeof(msg), 0);
		if (len == -1) {
			printf("read %d failed: %s\n", i, mfile_lasterror());
			break;
		}

		msg[len] = 0;
		if (i % 1000 == 0) {
			printf("%d: %s\n", i, msg);
		}
	}
	return 0;
}
#endif
