#include <assert.h>
#include <stdint.h>
#include <string.h>

#include "amf.h"

#define DATA_POP(l, c) do { if(len < l) return 0; data += (l); (c) += (l), len -= (l); } while(0)

enum amf_type amf_next_type(const char * data, size_t len)
{
	if (len == 0) {return amf_undefine;}

	return (enum amf_type)data[0];
}


// signed int -> uint29
uint32_t S2UInt29(int32_t i) 
{
	uint32_t ui = i;

 	if (i > 0xFFFFFFF || i < -0x10000000) {
		assert(0 && "out of range");
	}

	ui = (ui&0xFFFFFFF) | (ui & 0x80000000 >> 3);
	return ui;
}

// uint29 -> signed int
int32_t U2SInt29(uint32_t i) 
{
	if (i > 0x1FFFFFFF) {
		assert(0 && "out of range");
	}
	if ((i&0x10000000) != 0) {
		return (int32_t)(i|0xFF000000);
	}
	return (int32_t)i;
}

static size_t amf_encode_u29(char * data, size_t len, uint32_t val)
{
	if (val <= 0x0000007F) {
		if (len < 1) return 0;
		data[0] = val & 0x7F;;
		return 1;
	} else if (val <= 0x00003FFF) {
		if (len < 2) return 0;
		data[0] = (val >>7)|0x80;
		data[1] = (val & 0x7F);
		return 2;
	} else if (val <= 0x001FFFFF) {
		if (len < 3) return 0;
		data[0] = (val>>14 | 0x80);
		data[1] = (((val>>7)&0x7F)|0x80);
		data[2] = (val&0x7F);
		return 3;
	} else if (val <= 0x1FFFFFFF) {
		if (len < 4) return 0;
		data[0] = ((val>>22)|0x80);
		data[1] = (((val>>15)&0x7F)|0x80);
		data[2] = (((val>>8)&0x7F)|0x80);
		data[3] = val & 0xFF;
		return 4;
	} else {
		assert(0 && "out of range");
		return 0;
	}
}

static size_t amf_encode_i29(char * data, size_t len, int32_t val)
{
	uint32_t un;
	if (val >= AMF_INTEGER_MAX || val <= -AMF_INTEGER_MAX) {
		return amf_encode_double(data, len, val);
	}

	un = S2UInt29(val);
	un = (un&0xFFFFFFF) | ((un&0x80000000) >> 3);
	return amf_encode_u29(data, len, un);
}

#define log(...) //printf

size_t amf_encode_array(char * data, size_t len, size_t size)
{
	size_t write_bytes = 0;
	size_t offset;

	log("amf_encode_array %zu\n", size);

	//type
	if (len < 1) { return 0; };
	data[0] = amf_array;
	DATA_POP(1, write_bytes);

	//size
	size <<= 1;
	size |= 1;
	offset = amf_encode_u29(data, len, size);
	if (offset == 0) return 0; 
	DATA_POP(offset, write_bytes);

	//name
	if (len < 1) return 0;
	data[0] = 0x01;
	DATA_POP(1, write_bytes);
	return write_bytes;
}

size_t amf_encode_integer_with_type(char * data, size_t len, uint32_t integer, enum amf_type type)
{
	size_t write_bytes = 0, offset;
	assert(type == amf_integer || type == amf_sinteger);

	if (integer > AMF_INTEGER_MAX) {
		return amf_encode_double(data, len, integer);
	}

	log("amf_encode_integer %d\n", integer);

	//type
	if (len < 1) { return 0; }
	data[0] = type;
	DATA_POP(1, write_bytes);

	//size
	offset = 0;
	offset = amf_encode_u29(data, len, integer);

	if (offset == 0) { return 0; }
	DATA_POP(offset, write_bytes);
	return write_bytes;
}

size_t amf_encode_integer(char * data, size_t len, uint32_t integer)
{
	return amf_encode_integer_with_type(data, len, integer, amf_integer);
}

size_t amf_encode_sinteger(char * data, size_t len, int32_t integer)
{
	uint32_t u = S2UInt29(integer);

	((void)amf_encode_i29);
	return amf_encode_integer_with_type(data, len, u, amf_sinteger);
}

size_t amf_encode_double(char * data, size_t len, double d)
{
	size_t write_bytes = 0;
	char * ptr = (char*)&d;

	log("amf_encode_double %f\n", d);

	//type
	if (len < 1) { return 0; }
	data[0] = amf_double;
	DATA_POP(1, write_bytes);

	data[7] = ptr[0];
	data[6] = ptr[1];
	data[5] = ptr[2];
	data[4] = ptr[3];
	data[3] = ptr[4];
	data[2] = ptr[5];
	data[1] = ptr[6];
	data[0] = ptr[7];
	DATA_POP(8, write_bytes);

	return write_bytes;
}

size_t amf_encode_string(char * data, size_t len,
		const char * string, size_t str_len)
{
	size_t write_bytes = 0;
	size_t e_len, offset;

	if (str_len == 0) str_len = strlen(string);

	log("amf_encode_stirng %zu\n", str_len);

	//type
	if (len < 1) { return 0; }
	data[0] = amf_string;
	DATA_POP(1, write_bytes);

	//size
	e_len = (str_len << 1) | 1;
	offset = amf_encode_u29(data, len, e_len);
	if (offset == 0) { return 0; }
	DATA_POP(offset, write_bytes);

	//string
	if (len < str_len) {
		return 0;
	}
	memcpy(data, string, str_len);
	DATA_POP(str_len, write_bytes);
	return write_bytes;
}

size_t amf_encode_byte_array(char * data, size_t len, const char * ptr, size_t sz)
{
	size_t write_bytes = 0;
	size_t e_len, offset;

	log("amf_encode_byte_array %zu\n", sz);

	//type
	if (len < 1) { return 0; }
	data[0] = amf_byte_array;
	DATA_POP(1, write_bytes);

	//size
	e_len = (sz << 1) | 1;
	offset = amf_encode_u29(data, len, e_len);
	if (offset == 0) { return 0; }
	DATA_POP(offset, write_bytes);

	// data
	if (len < sz) {
		return 0;
	}
	memcpy(data, ptr, sz);
	DATA_POP(sz, write_bytes);
	return write_bytes;
}


size_t amf_encode_undefine(char * data, size_t dlen)
{
	log("amf_encode_undefine\n");

	if (dlen < 1) return 0;
	data[0] = amf_undefine;
	return 1;
}

size_t amf_encode_null(char * data, size_t dlen)
{
	log("amf_encode_null\n");

	if (dlen < 1) return 0;
	data[0] = amf_null;
	return 1;
}

size_t amf_encode_false(char * data, size_t dlen)
{
	log("amf_encode_false\n");

	if (dlen < 1) return 0;
	data[0] = amf_false;
	return 1;
}

size_t amf_encode_true(char * data, size_t dlen)
{
	log("amf_encode_true\n");

	if (dlen < 1) return 0;
	data[0] = amf_true;
	return 1;
}



static struct {
	const char * ptr;
	size_t len;
} string_ref[1024];

static unsigned int cur_ref = 0;

#if 0
static size_t amf_decode_u29(const char * data, size_t dlen, uint32_t * value)
{

	if (dlen == 0) return 0;

	size_t count;
	unsigned char c = data[0];
	data ++;
	dlen --;

	size_t result = 0;

	for(count = 0; ((c & 0x80) != 0) && count < 3; count++) {
		if (dlen == 0) return 0;

		result <<= 7;
		result |= (c & 0x7f);

		c = data[0];
		data ++;
		dlen --;
	}

	if (count < 3) {
		result <<= 7;
		result  |= c;
		count++;
	} else {
		// Use all 8 bits from the 4th byte
		result <<= 8;
		result  |= c;
		count++;

		// Check if the integer should be negative
		//if (($result & 0x10000000) != 0) {
		//and extend the sign bit
		//	$result |= ~0xFFFFFFF;
		//}
	}
	if (value) *value = result;
	return count;
}
#endif

size_t amf_decode_u29(const char * data, size_t len, uint32_t * v)
{
	size_t skip = 0;
	uint32_t n = 0;

	size_t i = 0;
	while(1) {
		unsigned char c;

		if (len < 1) return 0;

		c = (unsigned char)data[0];
		DATA_POP(1, skip);

		if (i != 3) {
			n |= (uint32_t)(c&0x7F);
			if((c&0x80) != 0) {
				if (i != 2) {
					n <<= 7;
				} else {
					n <<= 8;
				}
			} else {
				break;
			}
		} else {
			n |= (uint32_t)(c);
			break;
		}
		i++;
	}
	if (v) *v = n;
	return skip;
}

size_t amf_decode_i29(const char * data, size_t len, int32_t * v)
{
	uint32_t u = 0;
	size_t s = amf_decode_u29(data, len, &u);
	if (v) *v = U2SInt29(u);
	return s;
}

size_t amf_decode_double(const char * data, size_t len, double * d)
{
	union {
		double d;
		char c[8];
	} v;

	log("amf_decode_double\n");

	if (len < 9) return 0;

	data += 1;

	v.c[0] = data[7];
	v.c[1] = data[6];
	v.c[2] = data[5];
	v.c[3] = data[4];
	v.c[4] = data[3];
	v.c[5] = data[2];
	v.c[6] = data[1];
	v.c[7] = data[0];

	if (d) *d = v.d;

	return 9;
}

size_t amf_decode_integer(const char * data, size_t len, uint32_t * v)
{
	size_t skip = 0;
	size_t cur_len;

	log("amf_decode_integer\n");


	//type
	if (len == 1) { return 0; }
	//assert(data[0] == amf_integer);
	DATA_POP(1, skip);

	//value
	cur_len = amf_decode_u29(data,len, v);
	if (cur_len == 0) {
		return 0;
	}
	DATA_POP(cur_len, skip);

	return skip;
}

size_t amf_decode_sinteger(const char * data, size_t len, int32_t * v)
{
	uint32_t u = 0;
	size_t s = amf_decode_integer(data, len, &u);
	if (v) *v = U2SInt29(u);
	return s;
}

size_t amf_decode_string(const char * data, size_t len, struct amf_slice * slice)
{
	size_t skip = 0;
	uint32_t string_size;
	size_t cur_len;

	log("amf_decode_string\n");

	//type
	if (len == 0)  {
		slice->buffer = (char*)"";
		slice->len    = 0;
		return 0; 
	}

	assert(data[0] == amf_string);
	DATA_POP(1, skip);

	//size
	string_size = 0;
	cur_len = amf_decode_u29(data, len, &string_size);
	if (cur_len == 0) {
		slice->buffer = (char*)"";
		slice->len    = 0;
		return 0;
	}
	DATA_POP(cur_len, skip);

	if ((string_size & 1) == 0) {
		//load ref
		unsigned int ref = string_size >> 1;
		if (ref >= cur_ref) {
			slice->buffer = (char*)"";
			slice->len    = 0;
			return 0;  
		}

		if (slice) {
			slice->buffer = (void*)string_ref[ref].ptr;
			slice->len    = string_ref[ref].len;
		}
	} else {
		string_size >>= 1;

		//create
		if (len < string_size)  return 0;

		if (slice) {
			slice->buffer = (void*)data;
			slice->len = string_size;
		}

		string_ref[cur_ref].ptr = data;
		string_ref[cur_ref].len = string_size;

		//assert(cur_ref < 1024);
		cur_ref ++;

		DATA_POP(string_size, skip);
	}

	return skip;
}

size_t amf_decode_byte_array(const char * data, size_t len, struct amf_slice * slice)
{
	size_t skip = 0;
	uint32_t string_size;
	size_t cur_len;
	log("amf_decode_byte_array\n");


	//type
	if (len == 0)  {
		slice->buffer = (char*)"";
		slice->len    = 0;
		return 0; 
	}

	assert(data[0] == amf_byte_array);
	DATA_POP(1, skip);

	//size
	string_size = 0;
	cur_len = amf_decode_u29(data, len, &string_size);
	if (cur_len == 0) {
		slice->buffer = (char*)"";
		slice->len    = 0;
		return 0;
	}
	DATA_POP(cur_len, skip);

	string_size >>= 1;

	//create
	if (len < string_size)  return 0;

	if (slice) {
		slice->buffer = (void*)data;
		slice->len = string_size;
	}

	DATA_POP(string_size, skip);

	return skip;
}

size_t amf_decode_undefine(const char * data, size_t dlen)
{
	log("amf_decode_undefine\n");

	if (dlen == 0) { return 0; }
	//assert(data[0] == amf_undefine);

	return 1;
}

size_t amf_decode_null(const char * data, size_t dlen)
{
	log("amf_decode_null\n");

	if (dlen < 1) { return 0; }
	//assert(data[0] == amf_null);

	return 1;
}

size_t amf_decode_false(const char * data, size_t dlen)
{
	log("amf_decode_false\n");

	if (dlen < 1) { return 0; }
	//assert(data[0] == amf_false);

	return 1;
}

size_t amf_decode_true(const char * data, size_t dlen)
{
	log("amf_decode_true\n");

	if (dlen < 1) { return 0; }
	//assert(data[0] == amf_true);

	return 1;
}

#define ASSERT_RETURN(cond, v) do { if (!(cond)) return v; } while(0)

size_t amf_decode_array(const char * data, size_t len, size_t * sz)
{
	size_t skip = 0;
	uint32_t array_size;
	size_t cur_len;

	log("amf_decode_array\n");

	// type
	if (len == 0) return 0;
	assert(data[0] == amf_array);
	DATA_POP(1, skip);

	//size
	array_size = 0;
	cur_len = amf_decode_u29(data, len, &array_size);
	if (cur_len == 0) { return 0; }
	DATA_POP(cur_len, skip);

	// assert(array_size & 1);
	ASSERT_RETURN(array_size & 1, 0);

	array_size >>= 1;

	//name
	if (len == 0) return 0;
	// assert(data[0] == 1);
	ASSERT_RETURN(data[0] == 1, 0);

	DATA_POP(1, skip);

	if (sz) *sz = array_size;

	return skip;
}

size_t amf_skip(const char * data, size_t len)
{
	switch(amf_next_type(data, len)) {
		case amf_undefine:
			return amf_decode_undefine(data, len);
		case amf_null:
			return amf_decode_null(data, len);
		case amf_false:
			return amf_decode_false(data, len);
		case amf_true:
			return amf_decode_true(data, len);
		case amf_integer:
			return amf_decode_integer(data, len, 0);
		case amf_sinteger:
			return amf_decode_sinteger(data, len, 0);
		case amf_double:
			return amf_decode_double(data, len, 0);
		case amf_string:
			return amf_decode_string(data, len, 0);
		case amf_byte_array:
			return amf_decode_string(data, len, 0);
		case amf_array:
			{
				size_t i, sz = 0;
				size_t offset = 0;
				size_t c = amf_decode_array(data, len, &sz);
				DATA_POP(offset, offset);
				for(i = 0; i < sz; i++) {
					c = amf_skip(data, len);
					if (c == 0) return 0;
					DATA_POP(c, offset);
				}
				return offset;
			}
		case amf_xml_doc:
		case amf_date:
		case amf_object:
		case amf_xml:
			return 0;
	}
	return 0;
}

static size_t amf_dump_double(const char * data, size_t len, int deep)
{
	double d;
	size_t s = amf_decode_double(data, len, &d);
	printf("%f", d);
	return s;
}

static size_t amf_dump_integer(const char * data, size_t len, int deep)
{
	uint32_t v;
	size_t s = amf_decode_integer(data, len, &v);
	printf("%u", (unsigned int)v);
	return s;
}

static size_t amf_dump_sinteger(const char * data, size_t len, int deep)
{
	int32_t v;
	size_t s = amf_decode_sinteger(data, len, &v);
	printf("%d", (int)v);
	return s;
}

static size_t amf_dump_string(const char * data, size_t len, int deep)
{
	struct amf_slice slice;
	size_t s = amf_decode_string(data, len, &slice);
	char str[1024] = {0};
	memcpy(str, slice.buffer, slice.len);
	printf("\"%s\"", str);
	return s;
}

static size_t amf_dump_undefine(const char * data, size_t len, int deep)
{
	printf("undefine");
	return amf_decode_undefine(data, len);
}

static size_t amf_dump_null(const char * data, size_t len, int deep)
{
	printf("null");
	return amf_decode_null(data, len);
}

static size_t amf_dump_false(const char * data, size_t len, int deep)
{
	printf("false");
	return amf_decode_false(data, len);
}

static size_t amf_dump_true(const char * data, size_t len, int deep)
{
	printf("true");
	return amf_decode_true(data, len);
}

static size_t amf_dump_r(const char * data, size_t len, int deep);
size_t amf_dump_array(const char * data, size_t len, int deep)
{
	size_t i, n = 0;
	size_t s = amf_decode_array(data, len, &n);
	printf("[");
	for (i = 0; i < n; i++) {
		if (i > 0) {
			printf(",");
		}
		s += amf_dump_r(data + s, len - s, deep);
	}
	printf("]");
	return s;
}

static size_t amf_dump_r(const char * data, size_t len, int deep)
{
	switch(amf_next_type(data, len)) {
		case amf_undefine:
			return amf_dump_undefine(data, len, deep);
		case amf_null:
			return amf_dump_null(data, len, deep);
		case amf_false:
			return amf_dump_false(data, len, deep);
		case amf_true:
			return amf_dump_true(data, len, deep);
		case amf_integer:
			return amf_dump_integer(data, len, deep);
		case amf_sinteger:
			return amf_dump_sinteger(data, len, deep);
		case amf_double:
			return amf_dump_double(data, len, deep);
		case amf_string:
			return amf_dump_string(data, len, deep);
		case amf_byte_array:
			return amf_dump_string(data, len, deep);
		case amf_array:
			return amf_dump_array(data, len, deep);
		case amf_xml_doc:
		case amf_date:
		case amf_object:
		case amf_xml:
			return 0;
	}
	return 0;
}

void amf_dump(const char * data, size_t len)
{
	amf_dump_r(data, len, 0);
	printf("\n");
}


////////////////////////////////////////////////////////////////////////////////
// entity
struct amf_value {
	enum amf_type type;
	size_t size;

	union {
		struct amf_value * next;
		uint32_t integer;
		int32_t  sinteger;
		double d;
		char * string;
		struct {
			amf_value ** child;
			size_t alloc_size;
		};
	};
};

static amf_value * _read_integer(const char * data, size_t len, size_t * plen)
{
	uint32_t u;
	size_t s = amf_decode_integer(data, len, &u);

	//create
	amf_value * v = amf_new_integer(u);

	if (plen) *plen = s;
	return v;
}

static amf_value * _read_sinteger(const char * data, size_t len, size_t * plen)
{
	int32_t i;
	size_t s = amf_decode_sinteger(data, len, &i);

	//create
	amf_value * v = amf_new_sinteger(i);

	if (plen) *plen = s;
	return v;
}

static amf_value * _read_string(const char * data, size_t len, size_t * plen)
{
	struct amf_slice slice = {(char*)"", 0};
	amf_value * v;

	size_t s = amf_decode_string(data, len, &slice);
	if (slice.len == 0) {
		slice.buffer = (char*)"";
	}


	v = amf_new_string((const char*)slice.buffer, slice.len);
	if (plen) *plen = s;

	return v;
}

static amf_value * _read_byte_array(const char * data, size_t len, size_t * plen)
{
	struct amf_slice slice = {(char*)"", 0};
	amf_value * v ;
	size_t s;

	s = amf_decode_byte_array(data, len, &slice);
	if (slice.len == 0) {
		slice.buffer = (char*)"";
	}

	v = amf_new_byte_array((const char *)slice.buffer, slice.len);
	if (plen) *plen = s;

	return v;
}


static amf_value * _read_double(const char * data, size_t len, size_t * plen)
{
	double d;
	size_t s = amf_decode_double(data, len, &d);

	//create
	amf_value * v = amf_new_double(d);

	if (plen) *plen = s;
	return v;
}

static amf_value * _read_undefine(const char * data, size_t len, size_t * plen)
{
	size_t s = amf_decode_undefine(data, len);
	if (plen) *plen = s;

	return amf_new();
}

static amf_value * _read_null(const char * data, size_t len, size_t * plen)
{
	size_t s = amf_decode_null(data, len);

	if (plen) *plen = s;

	return amf_new_null();
}

static amf_value * _read_false(const char * data, size_t len, size_t * plen)
{
	size_t s = amf_decode_false(data, len);
	if (plen) *plen = s;

	return amf_new_false();
}

static amf_value * _read_true(const char * data, size_t len, size_t * plen)
{
	size_t s = amf_decode_true(data, len);
	if (plen) *plen = s;

	return amf_new_true();
}

static amf_value * _read_amf(const char * data, size_t dlen, size_t * plen);
static amf_value * _read_array(const char * data, size_t len, size_t * plen)
{
	amf_value * v;
	size_t i;
	size_t skip = 0;
	size_t sz = 0;

	// read size
	size_t r = amf_decode_array(data, len, &sz);
	if (r == 0) return 0;
	DATA_POP(r, skip);

	v = amf_new_array(sz);

	//child
	for(i = 0; i < v->size; i++) {
		amf_value * c = _read_amf(data, len, &r);
		if (c == 0) {
			amf_free(v);
			return 0;
		}
		amf_set(v, i, c);

		DATA_POP(r, skip);
	}

	((void)_read_sinteger);

	if (plen) *plen = skip;
	return v;
}


static amf_value * _read_amf(const char * data, size_t dlen, size_t * plen)
{
	char type = data[0];
	switch(type) {
		case amf_undefine:
			return _read_undefine(data, dlen, plen);
		case amf_null:
			return _read_null(data, dlen, plen);
		case amf_false:
			return _read_false(data, dlen, plen);
		case amf_true:
			return _read_true(data, dlen, plen);
		case amf_array:
			return _read_array(data, dlen, plen);
		case amf_integer:
			return _read_integer(data, dlen, plen);
		case amf_sinteger:
			return _read_sinteger(data, dlen, plen);
		case amf_string:
			return _read_string(data, dlen, plen);
		case amf_double:
			return _read_double(data, dlen, plen);
		case amf_byte_array:
			return _read_byte_array(data, dlen, plen);
		default:
			return 0;
	}
}


amf_value * amf_read(const char * data, size_t dlen, size_t * plen)
{
	cur_ref = 0;
	return _read_amf(data, dlen, plen);
}


//#define  AMF_USE_PER_ALLOC

#ifdef AMF_USE_PER_ALLOC
static amf_value * amf_value_list = 0;
#endif


amf_value * amf_new()
{
#ifdef AMF_USE_PER_ALLOC
	if (amf_value_list == 0) {
		amf_value * v = (amf_value*)malloc(sizeof(amf_value) * 256);
		if (v) {
			int i;
			for(i = 0; i < 256; i++, v++) {
				v->next = amf_value_list;
				amf_value_list = v;
			}
		}
	}

	if (amf_value_list) {
		amf_value * v = amf_value_list;
		amf_value_list = (amf_value*)(v->string);
		v->type = amf_undefine;
		v->size = 0;
		v->next = 0;
		return v;
	}
#endif
	amf_value * v = (amf_value*)malloc(sizeof(amf_value));
	v->type = amf_undefine;
	v->size = 0;
	v->next = 0;
	return v;
}

void amf_free(amf_value * v)
{
	//assert(v);
	if (v->type == amf_string || v->type == amf_byte_array) {
		if (v->string) free(v->string);
	} else if (v->type == amf_array) {
		size_t i;
		for(i = 0; i < v->size; i++) {
			if (v->child[i])
				amf_free(v->child[i]);
		}
		free(v->child);
	}

#ifdef AMF_USE_PER_ALLOC
	v->next = amf_value_list;
	amf_value_list = v;
#else
	free(v);
#endif
}


amf_value * amf_new_integer(uint32_t integer)
{
	amf_value * v = amf_new();
	if (v) {
		v->type = amf_integer;
		v->integer = integer;
		v->size = 1;
	}
	return v;
}

amf_value * amf_new_sinteger(int32_t integer)
{
	amf_value * v = amf_new();
	if (v) {
		v->type = amf_sinteger;
		v->sinteger = integer;
		v->size = 1;
	}
	return v;
}

amf_value * amf_new_string(const char * string, size_t size)
{
	amf_value * v = amf_new();
	if (v) {
		v->type = amf_string;
		if (size == 0) {
			size = strlen(string);
		}
		v->string = (char*)malloc(size+1);
		v->string[size] = 0; 
		memcpy(v->string, string, size);
		v->size = size;
	}
	return v;
}

amf_value * amf_new_byte_array(const char * ptr, size_t size)
{
	amf_value * v = amf_new();
	if (v) {
		v->type = amf_byte_array;
		v->string = (char*)malloc(size);
		memcpy(v->string, ptr, size);
		v->size = size;
	}
	return v;
}

amf_value * amf_new_array(size_t size)
{
	amf_value * v = amf_new();
	if (v) {
		size_t mem_size ;

		v->type = amf_array;
		v->size = size;
		if (size == 0)  { 
			size = 32;
		}
		mem_size = sizeof(amf_value*) * size;
		v->child = (amf_value**)malloc(mem_size);
		memset(v->child, 0, mem_size);
		v->alloc_size = size;
	}
	return v;
}

amf_value * amf_new_double(double d)
{
	amf_value * v = amf_new();
	if (v) {
		v->type = amf_double;
		v->size = 1;
		v->d = d;
	}
	return v;
}

amf_value * amf_new_null()
{
	amf_value * v = amf_new();
	if (v) {
		v->type = amf_null;
		v->size = 1;
	}
	return v;
}

amf_value * amf_new_true()
{
	amf_value * v = amf_new();
	if (v) {
		v->type = amf_true;
		v->size = 1;
	}
	return v;
}

amf_value * amf_new_false()
{
	amf_value * v = amf_new();
	if (v) {
		v->type = amf_false;
		v->size = 1;
	}
	return v;
}

size_t amf_size(amf_value * v)
{
	if (v) {
		return v->size;
	} else {
		return 0;
	}
}

enum amf_type amf_type(amf_value * v)
{
	if (v) {
		return v->type;
	} else {
		return amf_undefine;
	}
}

amf_value *  amf_get(amf_value * v, size_t pos)
{
	//assert(v->type == amf_array && pos < v->size);	
	if(v && v->type == amf_array && pos < v->size) {
		return v->child[pos];
	} else {
		return 0;
	}
}

static void amf_resize(amf_value * a, size_t size)
{
	size_t i;

	//assert(a->type == amf_array);
	//assert(size > a->alloc_size);

	a->child = (amf_value**)realloc(a->child, sizeof(amf_value*) * size);
	a->alloc_size = size;
	for(i = a->size; i < a->alloc_size; i++) {
		a->child[i] = 0;
	}
}

amf_value * amf_set(amf_value * a, size_t pos, amf_value * v)
{
	//assert(a->type == amf_array && pos < a->alloc_size);

	if(a->type == amf_array && pos < a->alloc_size) {
		amf_value * old = a->child[pos];
		a->child[pos] = v;
		if (a->size < pos + 1) {
			a->size = pos + 1;
		}
		return old;
	} else {
		return 0;
	}
}

void amf_push(amf_value * a, amf_value * v)
{
	//assert(a->type == amf_array);
	void * p;

	if (a->size == a->alloc_size) {
		if (a->alloc_size == 0) {
			amf_resize(a, 8);
		} else {
			amf_resize(a, a->alloc_size * 2);
		}
	}

	p = amf_set(a, a->size++, v);
	((void)p);
	//assert(p == 0);
}


uint32_t amf_get_integer(amf_value * v)
{
	if (v == 0) return 0;

	//assert(v->type == amf_integer || v->type == amf_double);
	switch(v->type) {
		case amf_integer:
			return v->integer;
		case amf_sinteger:
			return (uint32_t)v->sinteger;
		case amf_double:
			return v->d;
		case amf_true:
			return 1;
		case amf_false:
			return 0;
		default:
			return 0;
	}
}

int32_t amf_get_sinteger(amf_value * v)
{
	if (v == 0) return 0;

	switch(v->type) {
		case amf_integer:
			return (int32_t)v->integer;
		case amf_sinteger:
			return v->sinteger;
		case amf_double:
			return v->d;
		case amf_true:
			return 1;
		case amf_false:
			return 0;
		default:
			return 0;
	}
}

const char * amf_get_string(amf_value * v)
{
	//assert(v->type == amf_string);
	if (v && (v->type == amf_string || v->type == amf_byte_array) ) {
		return v->string;
	} else {
		return 0;
	}
}

const char *  amf_get_byte_array(amf_value * v, size_t * len)
{
	if (v && (v->type == amf_byte_array || v->type == amf_string) ) {
		if (len) *len = v->size;
		return v->string;
	} else {
		return 0;
	}
}

double amf_get_double(amf_value * v)
{
	if (v == 0) return 0;

	//assert(v->type == amf_integer || v->type == amf_double);
	switch(v->type) {
		case amf_integer:
			return v->integer;
		case amf_sinteger:
			return v->sinteger;
		case amf_double:
			return v->d;
		case amf_true:
			return 1;
		case amf_false:
			return 0;
		default:
			return 0;
	}
}

size_t amf_encode(char * data, size_t dlen, amf_value * v)
{
	//assert(v);

	if (v == 0) {
		return amf_encode_null(data, dlen);
	}

	switch(v->type) {
		case amf_undefine:
			return amf_encode_undefine(data, dlen);
		case amf_null:
			return amf_encode_null(data, dlen);
		case amf_false:
			return amf_encode_false(data, dlen);
		case amf_true:
			return amf_encode_true(data, dlen);
		case amf_integer:
			return amf_encode_integer(data, dlen, v->integer);
		case amf_sinteger:
			return amf_encode_sinteger(data, dlen, v->sinteger);
		case amf_string:
			return amf_encode_string(data, dlen, v->string, v->size);
		case amf_double:
			return amf_encode_double(data, dlen, v->d);
		case amf_byte_array:
			return amf_encode_byte_array(data, dlen, v->string, v->size);
		case amf_array:
		{
			size_t i;
			size_t wlen = 0;
			wlen += amf_encode_array(data, dlen, v->size);
			for(i = 0; i < v->size; i++) {
				wlen += amf_encode(data + wlen, dlen,
						v->child[i]);
			}
			return wlen;
		}
		default:
			return 0;
	}
}

static void dump_amf_x(amf_value * v, int deep, FILE * out)
{
	int i;
	for(i = 0; i < deep; i++) {
		fprintf(out, "\t");
	}
	if (amf_type(v) == amf_integer) {
		fprintf(out, "%u\n", (unsigned int)amf_get_integer(v));
	} else if (amf_type(v) == amf_sinteger) {
		fprintf(out, "%d\n", (int)amf_get_sinteger(v));
	} else if (amf_type(v) == amf_string) {
		fprintf(out, "\"%s\"\n", amf_get_string(v));
	} else if (amf_type(v) == amf_double) {
		fprintf(out, "%f\n", amf_get_double(v));
	} else if (amf_type(v) == amf_array) {
		size_t j;
		fprintf(out, "[\n");
		for(j = 0; j < amf_size(v); j++) {
			dump_amf_x(amf_get(v, j), deep+1, out);
		}
		fprintf(out, "]\n");
	}
}

void dump_amf(amf_value * v, FILE  * out)
{
	if (out == 0) {
		out = stdout;
	}
	dump_amf_x(v, 0, out);
}


void amf_set_null(amf_value * v)
{
	if (v->type == amf_string) {
		free(v->string);
	} else if (v->type == amf_array) {
		size_t i;
		for(i = 0; i < v->size; i++) {
			if (v->child[i])
				amf_free(v->child[i]);
		}
		free(v->child);
	}
	v->type = amf_null;
}

void amf_set_integer(amf_value * v, uint32_t integer)
{
	amf_set_null(v);
	v->type = amf_integer;
	v->integer = integer;
}

void amf_set_sinteger(amf_value * v, int32_t integer)
{
	amf_set_null(v);
	v->type = amf_sinteger;
	v->sinteger = integer;
}

void amf_set_double(amf_value * v, double d)
{
	amf_set_null(v);
	v->type = amf_double;
	v->d = d;
}

static size_t amf_get_length_u29(uint32_t val)
{
	if (val <= 0x0000007F) {
		return 1;
	} else if (val <= 0x00003FFF) {
		return 2;
	} else if (val <= 0x001FFFFF) {
		return 3;
	} else if (val <= 0x1FFFFFFF) {
		return 4;
	} else {
		assert(0 && "out of range");
		return 0;
	}
}

static size_t amf_get_length_i29(int32_t val)
{
	uint32_t un = S2UInt29(val);
	un = (un&0xFFFFFFF) | ((un&0x80000000) >> 3);
	return amf_get_length_u29(un);
}

static size_t amf_get_length_array(size_t size)
{
	size <<= 1;
	size |= 1;
	//type + size + name
	return 1 + amf_get_length_u29(size) + 1;
}

static size_t amf_get_length_double()
{
	return 9;
}

static size_t amf_get_length_integer(uint32_t integer)
{
	if (integer > 0x1FFFFFFF) {
		return amf_get_length_double();
	}
	// type + value
	return 1 + amf_get_length_u29(integer);
}

static size_t amf_get_length_sinteger(int32_t integer)
{
	uint32_t u = S2UInt29(integer);

	((void)amf_get_length_i29);

	return amf_get_length_integer(u);
}

static size_t amf_get_length_string(size_t str_len)
{
	size_t e_len = (str_len << 1) | 1;
	return 1 + amf_get_length_u29(e_len) + str_len;;
}

static size_t amf_get_length_byte_array(size_t str_len)
{
	size_t e_len = (str_len << 1) | 1;
	return 1 + amf_get_length_u29(e_len) + str_len;;
}

static size_t amf_get_length_undefine()
{
	return 1;
}

static size_t amf_get_length_null()
{
	return 1;
}

static size_t amf_get_length_false()
{
	return 1;
}

static size_t amf_get_length_true()
{
	return 1;
}


size_t amf_get_encode_length(amf_value * v)
{
	if (v == 0) {
		return amf_get_length_null();
	}

	((void)amf_get_length_sinteger);

	switch(v->type) {
		case amf_undefine:
			return amf_get_length_undefine();
		case amf_null:
			return amf_get_length_null();
		case amf_false:
			return amf_get_length_false();
		case amf_true:
			return amf_get_length_true();
		case amf_integer:
			return amf_get_length_integer(v->integer);
		case amf_sinteger:
			return amf_get_length_sinteger(v->sinteger);
		case amf_string:
			return amf_get_length_string(v->size);
		case amf_double:
			return amf_get_length_double();
		case amf_byte_array:
			return amf_get_length_byte_array(v->size);
		case amf_array:
		{
			size_t i;
			size_t wlen = 0;
			wlen += amf_get_length_array(v->size);
			for(i = 0; i < v->size; i++) {
				wlen += amf_get_encode_length(v->child[i]);
			}
			return wlen;
		}
		default:
			return 0;
	}
}
