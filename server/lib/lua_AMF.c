#include <assert.h>

#include "amf.h"

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int luaopen_AMF(lua_State *L);

#ifdef __cplusplus
}
#endif

static int pushAMF(lua_State * L, amf_value * value)
{
	int i;
	switch(amf_type(value)) {
		case amf_undefine:
		case amf_null:
			lua_pushnil(L);
			break;
		case amf_false:
			lua_pushboolean(L, 0);
			break;
		case amf_true:
			lua_pushboolean(L, 1);
			break;
		case amf_integer:
			lua_pushinteger(L, amf_get_integer(value));
			break;
		case amf_sinteger:
			lua_pushinteger(L, amf_get_sinteger(value));
			break;
		case amf_double:
			lua_pushnumber(L, amf_get_double(value));
			break;
		case amf_string:
			lua_pushlstring(L, amf_get_string(value), amf_size(value));
			break;
		case amf_xml_doc:
			lua_pushnil(L);
			break;
		case amf_date:
			lua_pushlstring(L, amf_get_string(value), amf_size(value));
			break;
		case amf_array:
			lua_newtable(L);
			for(i = 0; i < amf_size(value); i++) {
				lua_pushinteger(L, i+1);
				pushAMF(L, amf_get(value, i));
				lua_settable(L, -3);
			}
			break;
		case amf_byte_array:
			lua_pushlstring(L, amf_get_byte_array(value, 0), amf_size(value));
			break;
		case amf_object:
		case amf_xml:
		default:
			assert(0);
	}
	return 0;
}

static int l_amf_decode(lua_State * L)
{
	size_t len = 0;
	const char * data = luaL_checklstring(L, 1, &len);

	size_t read_len = 0;
	amf_value * v = amf_read(data, len, &read_len);
	assert(read_len == len);

	pushAMF(L, v);
	amf_free(v);
	return 1;
}


static size_t encodeValue(lua_State * L, int index, char * buff, size_t len)
{
	lua_pushvalue(L, index); //value
	int ret = 0;
	switch(lua_type(L, -1)) {
		case LUA_TNIL:
			ret = amf_encode_null(buff, len);
			break;
		case LUA_TBOOLEAN:
			{
				int v = lua_toboolean(L, -1);
				if (v == 0) {
					ret = amf_encode_false(buff, len);
				} else {
					ret = amf_encode_true(buff, len);
				}
			}
			break;
		case LUA_TNUMBER:
			{
				double v = lua_tonumber(L, -1);
				if (v >= 0 && ((v - (int)v) < 0.000001) && (v <= AMF_INTEGER_MAX)) {
					ret = amf_encode_integer(buff, len, (uint32_t)v);
				} else {
					ret = amf_encode_double(buff, len, v);
				}
			}
			break;
		case LUA_TSTRING:
			{
				size_t str_len = 0;
				const char * str = lua_tolstring(L, -1, &str_len);
				ret = amf_encode_string(buff, len, str, str_len);
			}
			break;
		case LUA_TTABLE:
			{
				int i, count = 0; // 最多100项
				for (i = 0; i < 100; i++) {
					lua_pushinteger(L, i + 1);
					lua_gettable(L, -2);
					if (lua_isnil(L, -1)) {
						lua_pop(L, 1);
						break;
					} else {
						lua_pop(L, 1);
						count ++;
					}
				}
				size_t l = amf_encode_array(buff, len, count);
				len  -= l;
				ret  += l;
				buff += l;
				for (i = 0; i < count; i++) {
					lua_pushinteger(L, i + 1);
					lua_gettable(L, -2);
					l = encodeValue(L, -1, buff, len);
					len  -= l;
					ret  += l;
					buff += l;
					lua_pop(L, 1);
				}
	
			}
			break;
		case LUA_TLIGHTUSERDATA:
		case LUA_TFUNCTION:
		case LUA_TUSERDATA:
		case LUA_TTHREAD:
		default:
			assert(0);
	}
	lua_pop(L, 1);
	return ret;


}

static amf_value * encodeValueToAMF(lua_State * L, int index)
{
	lua_pushvalue(L, index); //value

	int ret = 0;
	amf_value * v = 0;
	switch(lua_type(L, -1)) {
		case LUA_TNIL:
			v = amf_new_null();
			break;
		case LUA_TBOOLEAN:
			{
				int b = lua_toboolean(L, -1);
				if (b == 0) {
					v = amf_new_false();
				} else {
					v = amf_new_true();
				}
			}
			break;
		case LUA_TNUMBER:
			{
				double d = lua_tonumber(L, -1);
				if (d >= 0 && ((d - (int)d) < 0.000001) && (d < 0x20000000)) {
					v = amf_new_integer(d);
				} else {
					v = amf_new_double(d);
				}
			}
			break;
		case LUA_TSTRING:
			{
				size_t str_len = 0;
				const char * str = lua_tolstring(L, -1, &str_len);
				v = amf_new_string(str, str_len);
			}
			break;
		case LUA_TTABLE:
			{
				v = amf_new_array(0);
				int i = 0;
				for(i = 0; 1; i++) {
					lua_pushinteger(L, i + 1);
					lua_gettable(L, -2);
					if (lua_isnil(L, -1)) {
						lua_pop(L, 1);
						break;
					} else {
						amf_value * child = encodeValueToAMF(L, -1);
						amf_push(v, child);
						lua_pop(L, 1);
					}
				}
			}
			break;
		case LUA_TLIGHTUSERDATA:
		case LUA_TFUNCTION:
		case LUA_TUSERDATA:
		case LUA_TTHREAD:
		default:
			assert(0);
	}
	lua_pop(L, 1);
	return v;
}

static int l_amf_encode(lua_State * L)
{
	// char buff[4096] = {0};;
	amf_value * v = encodeValueToAMF(L, 1);
	size_t len = amf_get_encode_length(v);

	char message[len];
	size_t offset = 0;
	offset += amf_encode(message + offset, sizeof(message) - offset, v);

	lua_pushlstring(L, message, offset);

	amf_free(v);

	return 1;
}
	
int luaopen_AMF(lua_State *L)
{
	luaL_Reg reg[] = {
		{"decode", l_amf_decode},
		{"encode", l_amf_encode},
		{0,         0},
	};

	luaL_register(L,"AMF", reg);
	return 0;
}
