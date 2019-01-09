#include <errno.h>
#include <assert.h>
#include <stdarg.h>
#include <stdint.h>

#include <list>
#include <vector>

using namespace std;

#include "code_generate.h"

extern "C" {
#include "memory.h"
#include "proto.h"
}

static char * struper(char * dst, const char * src)
{
	int i = 0;
	for(i = 0; src[i]; i++) {
		if (src[i] >= 'a' && src[i] <= 'z') {
			dst[i] = src[i] + ('Z' - 'z');
		} else {
			dst[i] = src[i];
		}
	}
	dst[i] = 0;
	return dst;
}

static char * strlower(char * dst, const char * src)
{
	int i = 0;
	for(i = 0; src[i]; i++) {
		if (src[i] >= 'A' && src[i] <= 'Z') {
			dst[i] = src[i] + ('z' - 'Z');
		} else {
			dst[i] = src[i];
		}
	}
	dst[i] = 0;
	return dst;
}

static char * dot2underline(char * dst, const char * src)
{
	int i = 0;
	for(i = 0; src[i]; i++) {
		if (src[i] == '.') {
			dst[i] = '_';
		} else {
			dst[i] = src[i];
		}
	}
	dst[i] = 0;
	return dst;
}

static char * strcat_n(char * dst, const char * str, ...)
{
	dst[0] = 0;

	va_list args;
	va_start(args, str);
	while(str) {
		strcat(dst, str);
		str = va_arg(args, const char *);
	}
	va_end(args);
	return dst;
}

#define PTYPE_DOUBLE   1
#define PTYPE_FLOAT    2
#define PTYPE_INT64    3   // Not ZigZag encoded.  Negative numbers take 10 bytes.  Use TYPE_SINT64 if negative values are likely.
#define PTYPE_UINT64   4
#define PTYPE_INT32    5   // Not ZigZag encoded.  Negative numbers take 10 bytes.  Use TYPE_SINT32 if negative values are likely.
#define PTYPE_FIXED64  6
#define PTYPE_FIXED32  7
#define PTYPE_BOOL     8
#define PTYPE_STRING   9
#define PTYPE_GROUP    10  // Tag-delimited aggregate.
#define PTYPE_MESSAGE  11  // Length-delimited aggregate.
#define PTYPE_BYTES    12
#define PTYPE_UINT32   13
#define PTYPE_ENUM     14
#define PTYPE_SFIXED32 15
#define PTYPE_SFIXED64 16
#define PTYPE_SINT32   17  // Uses ZigZag encoding.
#define PTYPE_SINT64   18  // Uses ZigZag encoding.

static const char * getFieldStringType(struct _field * field)
{
	static char buffer[256];
	switch(field->type) {
		case PTYPE_DOUBLE:	return "double";
		case PTYPE_FLOAT:	return "float";
		case PTYPE_INT64:
		case PTYPE_SFIXED64:
		case PTYPE_SINT64:
							return "long long";
		case PTYPE_FIXED64:
		case PTYPE_UINT64:
							return "unsigned long long";
		case PTYPE_BOOL:
		case PTYPE_INT32:
		case PTYPE_SFIXED32:
		case PTYPE_SINT32:
							return "int";
		case PTYPE_FIXED32:
							return "time_t";
		case PTYPE_UINT32:
							return "unsigned int";
		case PTYPE_STRING:
							return "const char *";
		case PTYPE_ENUM:
							sprintf(buffer, "enum %s", field->type_name.e->key);
							return buffer;
		case PTYPE_MESSAGE:
					if (field->label == LABEL_REPEATED) {
						//sprintf(buffer, "struct %s *", field->type_name.m->key);
						sprintf(buffer, "struct map *");;
					} else { 
						char tmp[256];
						sprintf(buffer, "struct %s ", dot2underline(tmp, field->type_name.m->key));
					}
					return buffer;
		case PTYPE_BYTES:
		default:
							return NULL;
	}
}

static const char * getFieldSQLType(struct _field * field)
{
	switch(field->type) {
		case PTYPE_DOUBLE:	return "DOUBLE";
		case PTYPE_FLOAT:	return "FLOAT";
		case PTYPE_INT64:
		case PTYPE_SFIXED64:
		case PTYPE_SINT64:
							return "BIGINT";
		case PTYPE_FIXED64:
		case PTYPE_UINT64:
							return "BIGINT UNSIGNED";
		case PTYPE_BOOL:
		case PTYPE_INT32:
		case PTYPE_SFIXED32:
		case PTYPE_SINT32:
							return "INTEGER";
		case PTYPE_FIXED32:
							return "TIMESTAMP";
		case PTYPE_UINT32:
							return "INTEGER UNSIGNED";
		case PTYPE_STRING:
							return "TEXT";
		case PTYPE_ENUM:
							return "TINYINT";
		case PTYPE_MESSAGE:
		case PTYPE_BYTES:
		default:
							return NULL;
	}
}

static const char * getFieldFormatString(struct _field * field)
{
	switch(field->type) {
		case PTYPE_DOUBLE:
		case PTYPE_FLOAT:	return "%f";
		case PTYPE_INT64:
		case PTYPE_SFIXED64:
		case PTYPE_SINT64:
							return "%lld";
		case PTYPE_FIXED64:
		case PTYPE_UINT64:
							return "%llu";
		case PTYPE_BOOL:
		case PTYPE_INT32:
		case PTYPE_SFIXED32:
		case PTYPE_SINT32:
							return "%d";
		case PTYPE_FIXED32:
							return "from_unixtime_s(%lu)";
		case PTYPE_UINT32:
							return "%u";
		case PTYPE_STRING:
							return "%s";
		case PTYPE_ENUM:
							return "%d";
		case PTYPE_MESSAGE:
		case PTYPE_BYTES:
		default:
							return NULL;
	}
}

#define UNUSED(x) ((void)x)

#define CREATE_NAMES(pmsg) \
	char sname[256] = {0}; \
    char vname[256] = {0}; \
    dot2underline(sname, pmsg->key); \
	strlower(vname, sname); \
	char * tname = vname;  \
	UNUSED(sname); \
	UNUSED(vname); \
	UNUSED(tname); 


bool check_struct_have_pid(list<struct _field *> & l)
{
	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;
		if (strcmp(field->name, "pid") == 0)
		{
			return true;
		}
	}
	return false;
}

static void writeNewFunction(list<struct _field *> & l, struct _message * pmsg, FILE * file)
{
	CREATE_NAMES(pmsg);

	fprintf(file, "int DATA_%s_new(struct %s * %s)\n", sname, sname, vname);
	fprintf(file, "{\n");

	if (check_struct_have_pid(l))
	{
		fprintf(file, "\n");
		fprintf(file, "\tunsigned int sid = 0;\n");
		fprintf(file, "\tTRANSFORM_PLAYERID(%s->pid, 1, sid);\n", vname);
		fprintf(file, "\ts_db = get_db_by_sid(sid);\n");
		fprintf(file, "\n");
	}

	int stringField = 0;
	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;
		if (field->type == PTYPE_STRING) {
			stringField ++;
		}
	}

	if (stringField > 0) {
		fprintf(file, "\tsize_t len;\n");
		for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
			struct _field * field = *ite;
			if (field->type == PTYPE_STRING) {
				fprintf(file, "\tlen = strlen(%s->%s);\n", vname, field->name);
				fprintf(file, "\tchar escape_%s[2 * len + 1];\n", field->name);
				fprintf(file, "\tdatabase_escape_string(s_db, escape_%s, %s->%s, len);\n",
						field->name, vname, field->name);
				fprintf(file, "\n");
			}
		}
	}

	fprintf(file, "\tint ret = database_update(s_db, \"insert into `%s` (", vname);

	int have_uuid = 0;
	int comma = 0;

	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;

		if (field->type == PTYPE_MESSAGE) {
			continue;
		}

		if (strcmp(field->name, "uuid") == 0) {
			have_uuid = 1;
			continue;
		}

		comma ? fprintf(file, ", ") : (comma = 1);

		fprintf(file, "`%s`", field->name);
	}
	fprintf(file, ") values (");

	comma = 0;
	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;

		if (field->type == PTYPE_MESSAGE) {
			continue;
		}

		if (strcmp(field->name, "uuid") == 0) {
			continue;
		}

		comma ? fprintf(file, ", ") : (comma = 1);

		if (field->type == PTYPE_STRING) {
			stringField ++;
			fprintf(file, "'%s'", getFieldFormatString(field));
		} else {
			fprintf(file, "%s", getFieldFormatString(field));
		}
	}
	fprintf(file, ")\"");

	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;

		if (field->type == PTYPE_MESSAGE) {
			continue;
		}

		if (strcmp(field->name, "uuid") == 0) {
			continue;
		}

		if (field->type == PTYPE_STRING) {
			fprintf(file, ", escape_%s", field->name);
		} else {
			fprintf(file, ", %s->%s", vname, field->name);
		}
	}

	fprintf(file, ");\n");

	fprintf(file, "\tif (ret == 0) {\n");
	fprintf(file, "\t\t%s->dirty = 0;\n", vname);
	fprintf(file, "\t\t%s->dirty_time = 0;\n", vname);
	fprintf(file, "\t\t%s->last_change_time = 0;\n", vname);
	fprintf(file, "\t\t%s->data_flag = 0;\n", vname);

	if (have_uuid) {
		fprintf(file, "\t\t%s->uuid = database_last_id(s_db);\n", vname);
	}
	fprintf(file, "\t}\n");
	fprintf(file, "\treturn ret;\n");
	fprintf(file, "}\n");
	fprintf(file, "\n");
}

static void writeDeleteFunction(list<struct _field *> & l, struct _message * pmsg, FILE * file)
{
	CREATE_NAMES(pmsg);

	fprintf(file, "int DATA_%s_delete(struct %s * %s)\n", sname, sname, vname);
	fprintf(file, "{\n");

	if (check_struct_have_pid(l))
	{
		fprintf(file, "\n");
		fprintf(file, "\tunsigned int sid = 0;\n");
		fprintf(file, "\tTRANSFORM_PLAYERID(%s->pid, 1, sid);\n", vname);
		fprintf(file, "\ts_db = get_db_by_sid(sid);\n");
		fprintf(file, "\n");
	}

	fprintf(file, "\tif(database_update(s_db, \"delete from `%s` where ", vname);

	int have_uuid = 0;
	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;
		if (strcmp(field->name, "uuid") == 0) {
			have_uuid = 1;
			break;
		}
	}


	int comma = 0;
	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;

		if (field->type == PTYPE_MESSAGE) {
			continue;
		}

		if (field->label != LABEL_REQUIRED) {
			continue;
		}

		if (have_uuid && strcmp(field->name, "uuid") != 0) {
			continue;
		}

		comma ? fprintf(file, " and") : (comma = 1);
		fprintf(file, " `%s` = %s", field->name, getFieldFormatString(field));
	}
	fprintf(file, "\"");

	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;

		if (field->type == PTYPE_MESSAGE) {
			continue;
		}

		if (field->label != LABEL_REQUIRED) {
			continue;
		}

		if (have_uuid && strcmp(field->name, "uuid") != 0) {
			continue;
		}

		fprintf(file, ", %s->%s", vname, field->name);
	}
	fprintf(file, ") != 0) {\n");

	fprintf(file, "\t\treturn -1;\n");
	fprintf(file, "\t}\n");
	fprintf(file, "\t%s->dirty = 0;\n", vname);
	fprintf(file, "\t%s->dirty_time = 0;\n", vname);
	fprintf(file, "\t%s->last_change_time = 0;\n", vname);
	fprintf(file, "\t%s->data_flag = DATA_FLAG_DELETE; \n", vname);
	fprintf(file, "\t%s_add_to_update_list(%s);\n", sname, vname);
	fprintf(file, "\treturn 0;\n");
	fprintf(file, "}\n");
	fprintf(file, "\n");
}

static void writeReleaseFunction(list<struct _field *> & l, struct _message * pmsg, FILE * file)
{
	CREATE_NAMES(pmsg);

	fprintf(file, "int DATA_%s_release(struct %s * %s)\n", sname, sname, vname);
	fprintf(file, "{\n");
	fprintf(file, "\t%s->data_flag = DATA_FLAG_RELEASE; \n", vname);
	fprintf(file, "\t%s_add_to_update_list(%s);\n", sname, vname);
	fprintf(file, "\treturn 0;\n");
	fprintf(file, "}\n");
	fprintf(file, "\n");
}

static void writeUpdateFunction(list<struct _field *> & l, struct _message * pmsg, struct _field * field, FILE * file)
{
	CREATE_NAMES(pmsg);

	fprintf(file, "int DATA_%s_update_%s(struct %s * %s, %s %s)\n",
			sname, field->name, sname, vname,
			getFieldStringType(field), field->name);
	fprintf(file, "{\n");
	if (field->type == PTYPE_STRING) {
		fprintf(file, "\tif (strcmp(%s->%s, %s) == 0) return 0;\n", vname, field->name, field->name);
	} else {
		fprintf(file, "\tif (%s->%s == %s) return 0;\n", vname, field->name, field->name);
	}
	fprintf(file, "\n");

	if (field->type == PTYPE_STRING) {
		fprintf(file, "\t%s->%s = agSC_get(%s, 0);\n", vname, field->name, field->name);
	} else {
		fprintf(file, "\t%s->%s = %s;\n", vname, field->name, field->name);
	}
	fprintf(file, "\tif (%s->dirty_time == 0) {\n", vname);
	fprintf(file, "\t\t%s->dirty_time = agT_current();\n", vname);
	fprintf(file, "\t}\n");
	fprintf(file, "\t%s->last_change_time = agT_current();\n", vname);
	fprintf(file, "\n");
	fprintf(file, "\t%s->dirty |= (((uint64_t)1)<<((uint64_t)%d));\n", vname, field->id);
	fprintf(file, "\t%s_add_to_update_list(%s);\n", sname, vname);
	fprintf(file, "\treturn 0;\n");
	fprintf(file, "}\n");
	fprintf(file, "\n");
}


static void writeSaveFunction(list<struct _field *> & l, struct _message * pmsg, FILE * file)
{
	CREATE_NAMES(pmsg);

	fprintf(file, "int DATA_%s_save(struct %s * %s)\n", sname, sname, vname);
	fprintf(file, "{\n");
	fprintf(file, "\tif (%s->dirty == 0) {\n", vname);
	fprintf(file, "\t\treturn 0;\n");
	fprintf(file, "\t}\n");

	fprintf(file, "\tchar sql[4096];\n");
	fprintf(file, "\tsize_t offset = snprintf(sql, sizeof(sql), \"update `%s` set\");", tname);
	fprintf(file, "\n");

	fprintf(file, "\tint n = 0;\n");
	fprintf(file, "\t((void)n);\n");

	int have_uuid = 0;
	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;

		if (strcmp(field->name, "uuid") == 0) {
			have_uuid = 1;
		}

		if (field->type == PTYPE_MESSAGE) { continue; }

		fprintf(file, "\tif (%s->dirty & (((uint64_t)1) << ((uint64_t)%d))) {\n", vname, field->id);
		//offset += snprintf(sql + offset, sizeof(sql) - offset, "`name` = '%s',", player->name);
		fprintf(file, "\t\tif(n++ != 0) offset += snprintf(sql + offset, sizeof(sql) - offset, \",\");\n");

		if (field->type == PTYPE_STRING) {
			fprintf(file, "\t\toffset += snprintf(sql + offset, sizeof(sql) - offset, \" `%s` = '%s'\", %s->%s);\n",
					field->name, getFieldFormatString(field), vname, field->name);
		} else {
				fprintf(file, "\t\toffset += snprintf(sql + offset, sizeof(sql) - offset, \" `%s` = %s\", %s->%s);\n",
						field->name, getFieldFormatString(field), vname, field->name);
		}
		fprintf(file, "\t}\n");
		fprintf(file, "\n");
	}

	fprintf(file, "\toffset += snprintf(sql + offset, sizeof(sql) - offset, \" where");

	int comma = 0;
	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;

		if (field->type == PTYPE_MESSAGE) {
			continue;
		}

		if (field->label != LABEL_REQUIRED) {
			continue;
		}

		if (have_uuid && strcmp(field->name, "uuid") != 0) {
			continue;
		}

		comma ? fprintf(file, " and") : (comma = 1);
		fprintf(file, " %s = %s", field->name, getFieldFormatString(field));
	}
	fprintf(file, "\"");

	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;

		if (field->type == PTYPE_MESSAGE) {
			continue;
		}

		if (field->label != LABEL_REQUIRED) {
			continue;
		}

		if (have_uuid && strcmp(field->name, "uuid") != 0) {
			continue;
		}

		fprintf(file, ", %s->%s", vname, field->name);
	}
	fprintf(file, ");");

	if (check_struct_have_pid(l))
	{
		fprintf(file, "\n");
		fprintf(file, "\tunsigned int sid = 0;\n");
		fprintf(file, "\tTRANSFORM_PLAYERID(%s->pid, 1, sid);\n", vname);
		fprintf(file, "\ts_db = get_db_by_sid(sid);\n");
		fprintf(file, "\n");
	}

	fprintf(file, "\n");
	fprintf(file, "\tif (database_update(s_db, \"%%s\", sql) != 0) {;\n");
	fprintf(file, "\t\treturn -1;\n");
	fprintf(file, "\t}\n");
	fprintf(file, "\t%s->dirty = 0;\n", vname);
	fprintf(file, "\t%s->dirty_time = 0;\n", vname);
	fprintf(file, "\t%s->last_change_time = 0;\n", vname);
	fprintf(file, "\treturn 0;\n");
	fprintf(file, "}\n");

}

static void writeFlushFunction(struct _message * pmsg, FILE * file)
{
	CREATE_NAMES(pmsg);

	fprintf(file, "static struct %s void%s;\n", sname, sname);
	fprintf(file, "static struct %s * %s_update_list = &void%s;\n", sname, vname, sname);
	fprintf(file, "\n");
	fprintf(file, "int DATA_%s_flush ()\n", sname);
	fprintf(file, "{\n");
	fprintf(file, "\tstruct %s * nosaved = &void%s;\n", sname, sname);
	fprintf(file, "\ttime_t now = agT_current();\n");
	fprintf(file, "\twhile(%s_update_list != &void%s) {\n", vname, sname);
	fprintf(file, "\t\tstruct %s * %s = %s_update_list;\n", sname, vname, vname);
	fprintf(file, "\t\t%s_update_list = %s->update_next;\n", vname, vname);
	fprintf(file, "\t\t%s->update_next = 0;\n", vname);
	fprintf(file, "\t\tif (%s->data_flag == DATA_FLAG_RELEASE) {\n", vname);
	fprintf(file, "\t\t\tDATA_%s_save(%s);\n", sname, vname);
	fprintf(file, "\t\t\tfree(%s);\n", vname);
	fprintf(file, "\t\t} else if (%s->data_flag == DATA_FLAG_DELETE) {\n", vname);
	fprintf(file, "\t\t\tfree(%s);\n", vname);
	fprintf(file, "\t\t} else if ( ((now - %s->dirty_time) >= 30) || ((now - %s->last_change_time)>=5) ) {\n", vname, vname);
	fprintf(file, "\t\t\tDATA_%s_save(%s);\n", sname, vname);
	fprintf(file, "\t\t} else {\n");
	fprintf(file, "\t\t\t%s->update_next = nosaved;\n", vname);
	fprintf(file, "\t\t\tnosaved = %s;\n", vname);
	fprintf(file, "\t\t}\n");
	fprintf(file, "\t}\n");
	fprintf(file, "\t%s_update_list = nosaved;\n", vname);
	fprintf(file, "\treturn 0;\n");
	fprintf(file, "}\n");
	fprintf(file, "\n");
	fprintf(file, "static void %s_add_to_update_list(struct %s * %s)\n", sname, sname, vname);
	fprintf(file, "{\n");
	fprintf(file, "\tif (%s->update_next == 0) {\n", vname);
	fprintf(file, "\t\t%s->update_next = %s_update_list;\n", vname, vname);
	fprintf(file, "\t\t%s_update_list = %s;\n", vname, vname);
	fprintf(file, "\t}\n");
	fprintf(file, "}\n");
	fprintf(file, "\n");
}

static void writeLoadFunction(list<struct _field *> & l, struct _message * pmsg, struct _field * qfield, FILE * file)
{
	CREATE_NAMES(pmsg);

	fprintf(file, "struct parse_%s_Param {\n", qfield->name);
	fprintf(file, "\t%s %s;\n", getFieldStringType(qfield), qfield->name);
	fprintf(file, "\tstruct %s * list;\n", sname);
	fprintf(file, "};\n");
	fprintf(file, "\n");

	fprintf(file, "static int parse_%s_by_%s(struct slice * fields, void * ctx)\n", sname, qfield->name);
	fprintf(file, "{\n");
	fprintf(file, "\tstruct parse_%s_Param * param = (struct parse_%s_Param*)ctx;\n", qfield->name, qfield->name);
	fprintf(file, "\tstruct %s * %s = (struct %s*)malloc(sizeof(struct %s));\n",
			sname, vname, sname, sname);

	fprintf(file, "\tmemset(%s, 0, sizeof(struct %s));\n", vname, sname);
	fprintf(file, "\t%s->%s = param->%s;\n", vname, qfield->name, qfield->name);
	fprintf(file, "\t%s->next = param->list;\n", vname);
	fprintf(file, "\tparam->list = %s;\n", vname);
	fprintf(file, "\n");


	int i = 0;
	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;

		if (field->type == PTYPE_MESSAGE) { continue; };
		if (field->id == qfield->id) { continue; }

		if (field->type == PTYPE_STRING) {
			fprintf(file, "\t%s->%s = agSC_get((char *)fields[%d].ptr, fields[%d].len);\n", vname, field->name, i + 1, i + 1);
		} else {
			fprintf(file, "\t%s->%s = atoll((char *)fields[%d].ptr);\n", vname, field->name, i + 1);
		}

		i++;
	}
	fprintf(file, "\n");

	fprintf(file, "\treturn 0;\n");
	fprintf(file, "}\n");

	fprintf(file, "\n");

	//fprintf(file, "int agData_%s_load(struct %s ** %ss, unsigned int pid)\n", sname, sname, msg->lname);
	fprintf(file, "int DATA_%s_load_by_%s(struct %s ** %s, %s %s)\n",
			sname, qfield->name, sname, vname, getFieldStringType(qfield), qfield->name);
	fprintf(file, "{\n");
	fprintf(file, "\tstruct parse_%s_Param param;\n", qfield->name);
	fprintf(file, "\tparam.%s = %s;\n", qfield->name, qfield->name);
	fprintf(file, "\tparam.list = 0;\n");

	if (strcmp(qfield->name, "pid") == 0)
	{
		fprintf(file, "\n");
		fprintf(file, "\tunsigned int sid = 0;\n");
		fprintf(file, "\tTRANSFORM_PLAYERID(pid, 1, sid);\n");
		fprintf(file, "\ts_db = get_db_by_sid(sid);\n");
		fprintf(file, "\n");
	}

	fprintf(file, "\tif (database_query(s_db, parse_%s_by_%s, &param, \"select 0", sname, qfield->name);

	int comma = 1;
	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;

		if (field->type == PTYPE_MESSAGE) { continue; };
		if (field->id == qfield->id) { continue; }

		comma ? fprintf(file, ",") : (comma = 1);

		if (field->type == PTYPE_FIXED32) {
			fprintf(file, " unix_timestamp(`%s`)", field->name);
		} else {
			fprintf(file, " `%s`", field->name);
		}
	}

	if (qfield->type == PTYPE_STRING) {
		fprintf(file, " from `%s` where `%s` = '%s'\", %s) != 0) {\n", tname, qfield->name, getFieldFormatString(qfield), qfield->name);
	} else {
		fprintf(file, " from `%s` where `%s` = %s\", %s) != 0) {\n", tname, qfield->name, getFieldFormatString(qfield), qfield->name);
	}
	fprintf(file, "\t\treturn -1;\n");
	fprintf(file, "\t}\n");

	fprintf(file, "\t*%s = param.list;\n", vname);

	fprintf(file, "\treturn 0;\n");
	fprintf(file, "}\n");
}

#if 0
static void writeDumpFunction(struct Message * msg, FILE * out)
{
	fprintf(out, "void agData_%s_dump(struct %s * %s)\n", msg->name, msg->name, msg->lname);
	fprintf(out, "{\n");
	fprintf(out, "\tprintf(\"%s = {\\n\");\n", msg->name);
	if (msg->key) {
		fprintf(out, "\tprintf(\"\\t%s = %s\\n\", %s->%s);\n", msg->key->name, getFieldFormatString(msg->key), msg->lname, msg->key->name);
	}

	size_t i;
	for(i = 0; i < 32 && msg->fields[i]; i++) {
		struct _field * field = msg->fields[i];

		if (field->type == PTYPE_FIXED32) {
			fprintf(out, "\tprintf(\"\\t%s = %%lu\\n\", %s->%s);\n", field->name, msg->lname, field->name);
		} else {
			fprintf(out, "\tprintf(\"\\t%s = %s\\n\", %s->%s);\n", field->name, getFieldFormatString(field), msg->lname, field->name);
		}
	}
	fprintf(out, "\tprintf(\"}\\n\");\n");
	fprintf(out, "}\n");
}
#endif


bool compare_field(struct _field * f1, struct _field * f2) 
{
	return f1->id < f2->id;
}

static void sort_fields(list<struct _field*> & l, struct _message * pmsg)
{
	struct _field * field = 0;
	const char * key = 0;
	while((field = (struct _field*)_pbcM_sp_next(pmsg->name, &key)) != 0) {
		l.push_back(field);
	}

	l.sort(compare_field);
}

static int _sql_generate(struct pbc_env * env, struct _message * pmsg)
{
	UNUSED(getFieldStringType);
	UNUSED(getFieldFormatString);
	UNUSED(struper);

	list<struct _field*> l;

	sort_fields(l, pmsg);

	FILE * file = fopen("out.sql", "a");

	if (file == 0) {
		fprintf(stderr, "open file %s failed: %s", "out.sql", strerror(errno));
		return -1;
	}

	char sname[256] = {0};
	char tname[256] = {0};
	dot2underline(sname, pmsg->key);
	strlower(tname, sname);

	fprintf(file, "DROP TABLE IF EXISTS `%s`;\n", tname);
	fprintf(file, "CREATE TABLE `%s` (\n",  tname);

	int have_uuid = 0;
	int have_required = 0;
	int comma = 0;

	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;
		const char * key = field->name;

		if (field->type == PTYPE_MESSAGE) {
			continue;
		}

		comma ? fprintf(file, ",\n") : (comma = 1);

		if (strcmp(key, "uuid") == 0) {
			fprintf(file, "\t`uuid` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT");
			have_uuid = 1;
			continue;
		}

		if (field->label == LABEL_REQUIRED) {
			have_required = 1;
		}

		if (field->type == PTYPE_FIXED32) {
			fprintf(file, "\t`%s` %s NOT NULL DEFAULT '0000-00-00 00:00:00'", key, getFieldSQLType(field));
		} else {
			fprintf(file, "\t`%s` %s NOT NULL", key, getFieldSQLType(field));
		}
	}

	if (have_uuid) {
		comma ? fprintf(file, ",\n") : (comma = 1);
		fprintf(file, "\tPRIMARY KEY (`uuid`)");
		comma = 1;
	} 

	if (have_required) {
		comma ? fprintf(file, ",\n") : (comma = 1);

		if (have_uuid) {
			fprintf(file, "\tINDEX (");
		} else {
			fprintf(file, "\tPRIMARY KEY (");
		}

		comma = 0;

		for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
			struct _field * field = *ite;
			const char * key = field->name;

			if (field->type == PTYPE_MESSAGE) {
				continue;
			}

			if (field->label != LABEL_REQUIRED || strcmp(key, "uuid") == 0) {
				continue;
			}

			comma ? fprintf(file, ",") : (comma = 1);
			fprintf(file, "`%s`", field->name);
		}
		fprintf(file, ")");
	}

	fprintf(file, "\n) DEFAULT CHARSET=utf8;\n");

	if (file != stdout) {
		fclose(file);
	}
	return 0;
}

static FILE * flush_file = 0;

static int _h_generate(struct pbc_env * env, struct _message * pmsg)
{
	list<struct _field*> l;
	sort_fields(l, pmsg);

	CREATE_NAMES(pmsg);

	char fname[256] = {0};

	FILE * file = fopen(strcat_n(fname, "data/", sname, ".h", 0), "w");
	if (file == 0) {
		fprintf(stderr, "open file %s failed: %s", fname, strerror(errno));
		return -1;
	}

	char tmp[256] = {0};
	struper(tmp, sname);

	fprintf(file, "#ifndef _CODE_GENERATE_DATABASE_%s_H_\n", tmp);
	fprintf(file, "#define _CODE_GENERATE_DATABASE_%s_H_\n", tmp);

	fprintf(file, "\n");
	fprintf(file, "#include <time.h>\n");
	fprintf(file, "\n");

	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;
		char tmp[256] = {0};

		if (field->type == PTYPE_MESSAGE) { 
			fprintf(file, "#include \"%s.h\"\n", dot2underline(tmp, field->type_name.m->key));
		}
	}
	fprintf(file, "\n");
	fprintf(file, "#include \"database.h\"\n");
	fprintf(file, "\n");

	fprintf(file, "struct %s {\n", sname);
	fprintf(file, "\tstruct %s * prev;\n", sname);
	fprintf(file, "\tstruct %s * next;\n", sname);
	fprintf(file, "\n");
	fprintf(file, "\tstruct %s * update_next;\n", sname);
	fprintf(file, "\n");
	fprintf(file, "\tuint64_t dirty;\n");
	fprintf(file, "\ttime_t   dirty_time;\n");
	fprintf(file, "\ttime_t   last_change_time;\n");
	fprintf(file, "\tuint32_t data_flag;\n");
	fprintf(file, "\n");

	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;
		//const char * key = field->name;

		if (field->type == PTYPE_MESSAGE) { continue; }

		fprintf(file, "\t%-12s %s;\n", getFieldStringType(field), field->name);

		if (strcmp(field->name, "exp") == 0) {
			fprintf(file, "\tunsigned int level;\n");
		} else {
			size_t len = strlen(field->name);
			if (len >= 4 && strcmp(field->name + len - 4, "_exp") == 0) {
				char levelName[256];
				strncpy(levelName, field->name, len - 4);
				levelName[len - 4] = 0;
				strcat(levelName, "_level");

				bool have_level = false;
				for(list<struct _field*>::const_iterator ite2 = l.begin(); ite2 != l.end(); ite2++) {
					if (strcmp(((struct _field *)*ite2)->name , levelName) == 0) {
						have_level = true;
						break;
					}
				}

				if (!have_level) {
					fprintf(file, "\t%-12s %s;\n", "int", levelName);
				}
			}
		}

	}
	fprintf(file, "};\n");

	fprintf(file, "\n");

	fprintf(file, "void DATA_%s_set_db(struct DBHandler * db);\n", sname);
	fprintf(file, "int DATA_%s_new(struct %s * %s);\n", sname, sname, vname);
	fprintf(file, "int DATA_%s_save(struct %s * %s);\n", sname, sname, vname);
	fprintf(file, "int DATA_%s_delete(struct %s * %s);\n", sname, sname, vname);
	fprintf(file, "int DATA_%s_release(struct %s * %s);\n", sname, sname, vname);
	fprintf(file, "int DATA_%s_flush ();\n", sname);

	if (flush_file) {
		fprintf(flush_file, "\t\tDATA_%s_flush(); \\\n", sname);
	}

	fprintf(file, "\n");

	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;

		if (field->type == PTYPE_MESSAGE) { continue; }

		if (field->label == LABEL_REQUIRED) {
			fprintf(file, "int DATA_%s_load_by_%s(struct %s ** %s, %s %s);\n",
					sname, field->name, sname, vname, getFieldStringType(field), field->name);
		} 
	}

	fprintf(file, "\n");

	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;

		if (field->type == PTYPE_MESSAGE) { continue; }
		if (field->label == LABEL_REQUIRED) { continue; }

		fprintf(file, "int DATA_%s_update_%s(struct %s * %s, %s %s);\n",
				sname, field->name, sname, vname, getFieldStringType(field), field->name);
	}

	fprintf(file, "\n");
	fprintf(file, "#endif\n");
	if (file != stdout) {
		fclose(file);
	}
	return 0;
}

static int _c_generate(struct pbc_env * env, struct _message * pmsg)
{
	list<struct _field*> l;
	sort_fields(l, pmsg);

	char sname[256] = {0};
	char vname[256] = {0};
	char fname[256] = {0};
	dot2underline(sname, pmsg->key);
	strlower(vname, sname);
	strcat_n(fname, "data/", sname, ".c", 0);

	FILE * file = fopen(fname, "w");
	if (file == 0) {
		fprintf(stderr, "open file %s failed: %s", fname, strerror(errno));
		return -1;
	}

	fprintf(file, "#include <stdio.h>\n");
	fprintf(file, "#include <string.h>\n");
	fprintf(file, "#include <stdlib.h>\n");
	fprintf(file, "\n");

	fprintf(file, "#include \"DataFlush.h\"\n");
	fprintf(file, "#include \"database.h\"\n");
	fprintf(file, "#include \"stringCache.h\"\n");
	fprintf(file, "#include \"mtime.h\"\n");
	fprintf(file, "\n");
	fprintf(file, "#include \"%s.h\"\n", sname);
	fprintf(file, "\n");

	fprintf(file, "static struct DBHandler * s_db = 0;\n");
	fprintf(file, "\n");
	fprintf(file, "void DATA_%s_set_db(struct DBHandler * db)\n", sname);
	fprintf(file, "{\n");
	fprintf(file, "\ts_db = db;\n");
	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;

		if (field->type == PTYPE_MESSAGE) {
			char ssname[256];
			dot2underline(ssname, field->type_name.m->key);
			fprintf(file, "\tDATA_%s_set_db(db);\n", ssname);
			continue;
		}
	}
	fprintf(file, "}\n");
	fprintf(file, "\n");
	

	writeNewFunction(l, pmsg, file);
	writeFlushFunction(pmsg, file);
	writeDeleteFunction(l, pmsg, file);
	writeReleaseFunction(l, pmsg, file);
	writeSaveFunction(l, pmsg, file);
	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;

		if (field->type == PTYPE_MESSAGE) {
			continue;
		}

		if (field->label == LABEL_REQUIRED) {
			writeLoadFunction(l, pmsg, field, file);
		} 
	}

	fprintf(file, "\n");

	for(list<struct _field*>::const_iterator ite = l.begin(); ite != l.end(); ite++) {
		struct _field * field = *ite;
		if (field->type == PTYPE_MESSAGE) {
			continue;
		}

		if (field->label == LABEL_REQUIRED) {
			continue;
		}

		writeUpdateFunction(l, pmsg, field, file);
	}

	if (file != stdout) {
		fclose(file);
	}
	return 0;
}

static int _code_generate(struct pbc_env * env, struct _message * pmsg)
{
	struct _field * field = 0;
	const char * key = 0;
	while((field = (struct _field*)_pbcM_sp_next(pmsg->name, &key)) != 0) {
		if (field->type == PTYPE_MESSAGE) {
			_code_generate(env, field->type_name.m);
		} else if (field->id >= 64) {
			fprintf(stderr, "message %s field %s with id >=64", pmsg->key, field->name);
			return -1;
		}
	}

	int ret = _sql_generate(env, pmsg);
	if (ret != 0) return ret;

	ret = _h_generate(env, pmsg);
	if (ret != 0) return ret;

	ret = _c_generate(env, pmsg);
	if (ret != 0) return ret;

	return 0;
}

static int clean_out_sql = 1;

//int agCG_generate(struct pbc_env * env, struct _message * pmsg)
int agCG_generate(struct pbc_env * env, const char * name)
{
	if (clean_out_sql == 1) {
		fclose(fopen("out.sql", "w"));
		clean_out_sql = 0;
	}

	if (env == 0 || name == 0) {
		fprintf(stderr, "param error\n");
		return -1;
	}

	struct _message * pmsg = _pbcP_get_message(env, name);
	if (pmsg == 0) {
		fprintf(stderr, "get message %s failed\n", name);
		return -1;
	}

	if (flush_file == 0) {
		flush_file = fopen("./data/DataFlush.h", "w");
	}

	fprintf(flush_file, "#define DATA_FLAG_DELETE	1\n");
	fprintf(flush_file, "#define DATA_FLAG_RELEASE	2\n");

	fprintf(flush_file, "#include \"package.h\"\n");
	fprintf(flush_file, "#include \"config.h\"\n");

	fprintf(flush_file, "\n");

	char sname[256] = {0};
	dot2underline(sname, name);

	fprintf(flush_file, "#ifndef DATA_FLUSH_%s\n", sname);
	fprintf(flush_file, "#define DATA_FLUSH_%s() \\\n", sname);
	fprintf(flush_file, "\tdo { \\\n");

	int ret = _code_generate(env, pmsg);

	fprintf(flush_file, "\t} while(0);\n");
	fprintf(flush_file, "#endif\n\n");

	//fclose(flush_file);

	return ret;
}
