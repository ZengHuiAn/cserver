#ifndef _A_GAME_COMM_AMF_H_
#define _A_GAME_COMM_AMF_H_

#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif
//using  namespace std;


struct amf_slice {
	void * buffer;
	size_t len;
};

#define AMF_INTEGER_MAX 0x1FFFFFFF

enum amf_type {
	amf_undefine = 0x00,
	amf_null = 0x01,
	amf_false = 0x02,
	amf_true = 0x03,
	amf_integer = 0x04,
	amf_double = 0x05,
	amf_string = 0x06,
	amf_xml_doc = 0x07,
	amf_date = 0x08,
	amf_array = 0x09,
	amf_object = 0x0A,
	amf_xml = 0x0B,
	amf_byte_array = 0x0C,
	amf_sinteger = 0x0D,
	// amf_int64 = 0x0E,
};


typedef  enum amf_type  AMF_TYPE ;


enum amf_type amf_next_type(const char * data, size_t len);

// encode
size_t amf_encode_undefine(char * data, size_t len);
size_t amf_encode_null(char * data, size_t len);
size_t amf_encode_false(char * data, size_t len);
size_t amf_encode_true(char * data, size_t len);
size_t amf_encode_integer(char * data, size_t len, uint32_t integer);
size_t amf_encode_sinteger(char * data, size_t len, int32_t integer);
size_t amf_encode_double(char * data, size_t len, double d);
size_t amf_encode_string(char * data, size_t len, const char * string, size_t sz);
size_t amf_encode_array(char * data, size_t len, size_t size);
size_t amf_encode_byte_array(char * data, size_t len, const char * ptr, size_t sz);
size_t amf_encode_i64(char * data, size_t len, int64_t i64);

// decode
size_t amf_decode_double(const char * data, size_t len, double * d);
size_t amf_decode_integer(const char * data, size_t len, uint32_t * v);
size_t amf_decode_sinteger(const char * data, size_t len, int32_t * v);
size_t amf_decode_string(const char * data, size_t len, struct amf_slice * slice);
size_t amf_decode_undefine(const char * data, size_t dlen);
size_t amf_decode_null(const char * data, size_t dlen);
size_t amf_decode_false(const char * data, size_t dlen);
size_t amf_decode_true(const char * data, size_t dlen);
size_t amf_decode_array(const char * data, size_t len, size_t * sz);
size_t amf_decode_byte_array(const char * data, size_t len, struct amf_slice * slice);
size_t amf_decode_i64(char * data, size_t len, int64_t * i64);

size_t amf_skip(const char * data, size_t len);

// debug
void amf_dump(const char * data, size_t len);

////////////////////////////////////////////////////////////////////////////////
// entitys
typedef struct amf_value amf_value;

// malloc
amf_value * amf_new();
amf_value * amf_new_null();
amf_value * amf_new_false();
amf_value * amf_new_true();
amf_value * amf_new_integer(uint32_t integer);
amf_value * amf_new_sinteger(int32_t integer);
amf_value * amf_new_double(double d);
amf_value * amf_new_string(const char * string, size_t len);
amf_value * amf_new_array(size_t size);
amf_value * amf_new_byte_array(const char * string, size_t size);
amf_value * amf_new_i64(int64_t i64);

// free
void amf_free(amf_value * v);

// type
enum amf_type amf_type(amf_value * v);



// get
amf_value *   amf_get(amf_value * v, size_t pos);
size_t        amf_size(amf_value * v);
uint32_t      amf_get_integer(amf_value * v);
int32_t       amf_get_sinteger(amf_value * v);
const char *  amf_get_string(amf_value * v);
double        amf_get_double(amf_value * v);
const char *  amf_get_byte_array(amf_value * v, size_t * len);
int64_t       amf_get_i64(amf_value * v);

// set
amf_value *   amf_set(amf_value * a, size_t pos, amf_value * v);
void          amf_set_integer(amf_value * v, uint32_t integer);
void          amf_set_sinteger(amf_value * v, int32_t integer);
void          amf_set_string(amf_value * v, const char * str, size_t len);
void          amf_set_double(amf_value * v, double d);
void          amf_set_byte_array(amf_value * v, const char * ptr, size_t len);
void          amf_set_i64(amf_value * v, int64_t i64);

void          amf_push(amf_value * a, amf_value * v);

// encode/decode
size_t        amf_encode(char * data, size_t dlen, amf_value * v);
size_t        amf_get_encode_length(amf_value * v);
amf_value *   amf_read(const char * data, size_t len, size_t * read_len);

#ifdef __cplusplus
}
#endif

    
#endif
