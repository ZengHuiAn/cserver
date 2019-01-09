#OBJ_COMM=$(patsubst ../framework/%.c, %.o, $(wildcard ../framework/*.c))

OBJ_COMM=../framework/log.o \
	../framework/config.o  \
	../framework/xmlHelper.o \
	../framework/network.o \
	../framework/hash.o \
	../framework/base.o \
	../framework/main.o \
	../framework/service.o \
	../framework/lrm.o \
	../framework/buffer.o \
	../framework/memory.o \
	../framework/mtime.o 

OBJ_MAIN=$(patsubst %.c, %.o, $(wildcard *.c))
OBJ_MODULE=$(patsubst %.c, %.o, $(wildcard ./modules/*.c))
OBJ_SCRIPT=$(patsubst %.c, %.o, $(wildcard ./scripts/*.c))
C_BATTLEFIELD=$(wildcard ./lib/battlefield/*.c) $(wildcard ./lib/battlefield/buffer_effect/*.c) ../lib/libpbc.a

LUACFLAG=-I../include
LUALFLAG=-L../lib -lluajit

MYSQL_CFLAG=-I/usr/local/mysql/include
MYSQL_LFLAG=-L/usr/local/mysql/lib

-include local.mk

CFLAGS += -g -Wall  -D_DEBUG -I./  -I../framework -I./request_amf -I../include  -I../thirdpart -I./lib
LDLIBS += -L../lib -lmxml -lluajit -I../thirdpart -ldl -lm -lpthread

LUALIB=lib/AMF.so \
	   lib/protobuf.so \
	   lib/bit32.so \
	   lib/base64.so \
	   lib/mysql.so \
	   lib/dir.so \
	   lib/xml.so \
	   lib/mfile.so \
	   lib/log.so \
	   lib/report.so \
	   lib/WELLRNG512a.so \
	   lib/json.so 

#lib/network.so
#lib/regex.so \
#lib/sqlite.so \
#lib/pcre.so 

CC=gcc

COMPILE=$(CC) -c
LINK=$(CC)

BIN=./server

OBJ=$(OBJ_MAIN) \
	$(OBJ_MODULE) \
	$(OBJ_REQUEST_AMF) \
	$(OBJ_SCRIPT) \
	$(OBJ_LOGIC) \
	$(OBJ_TEMPLATE) \
	$(OBJ_REQUEST_PBC) \
	$(OBJ_CONFIG) \
	$(OBJ_CALC) 

all : $(BIN) $(PROTOCOL) $(LUALIB)

$(BIN) : $(OBJ) $(OBJ_COMM)
	$(LINK) -o $@ $^ $(LDLIBS)

$(OBJ_COMM) : %.o : ../framework/%.c version.h
	$(COMPILE) -o $@ $< $(CFLAGS)

version.h:
	sh ../tools/version.sh

$(OBJ) : %.o : %.c
	$(COMPILE) -o $@ $< $(CFLAGS)

lib/AMF.so : lib/lua_AMF.c ../framework/amf.c
	$(CC) -g -shared -fPIC -o $@ $^ -I./  -I../framework $(LUACFLAG) $(LUALFLAG) 

lib/redis.so : lib/lua_redis.c
	$(CC) -g -shared -fPIC -o $@ $^ -I../include -L../lib -lhiredis $(LUACFLAG) $(LUALFLAG)

lib/protobuf.so : lib/pbc-lua.c 
	cc -g -shared -fPIC -o $@ $^ -L../lib -lpbc -I../include $(LUACFLAG) $(LUALFLAG)

lib/regex.so: lib/lua_regex.c
	$(CC) -g -shared -fPIC -o $@ $^ -I../framework $(LUACFLAG) $(LUALFLAG)

lib/pcre.so: lib/lua_pcre.c
	$(CC) -g -shared -fPIC -o $@ $^ -I../framework $(LUACFLAG) $(LUALFLAG) -lpcre

lib/sqlite.so : lib/lua_sqlite.c lib/sqlite3.c lib/sqlite3.h
	$(CC) -g -shared -fPIC -o $@ $^ $(LUACFLAG) $(LUALFLAG) 

lib/mysql.so : lib/lua_mysql.c 
	$(CC) -g -shared -fPIC -o $@ $^ $(LUACFLAG) $(LUALFLAG) -lmysqlclient -I../thirdpart $(MYSQL_CFLAG) $(MYSQL_LFLAG)

lib/bit32.so : lib/lua_bit32.c 
	$(CC) -g -shared -fPIC -o $@ $^ $(LUACFLAG) $(LUALFLAG) 

lib/log.so : lib/lua_log.c 
	$(CC) -g -shared -fPIC -o $@ $^ $(LUACFLAG) $(LUALFLAG)

lib/network.so : lib/lua_network.c 
	$(CC) -g -shared -fPIC -o $@ $^ $(LUACFLAG) $(LUALFLAG) 

lib/dir.so : lib/lua_dir.c 
	$(CC) -g -shared -fPIC -o $@ $^ $(LUACFLAG) $(LUALFLAG)

lib/xml.so : lib/lua_xml.c  lib/xmlHelper.c
	$(CC) -g -shared -fPIC -o $@ $^ $(LUACFLAG) $(LUALFLAG) -lmxml

lib/mfile.so : lib/lua_mfile.c  lib/mfile.c
	$(CC) -g -shared -fPIC -o $@ $^ $(LUACFLAG) $(LUALFLAG) -lmxml

lib/report.so : lib/lua_report.c ../framework/log.c ../framework/memory.c
	$(CC) -g -shared -fPIC -o $@ $^ $(LUACFLAG) $(LUALFLAG) -I ../framework

lib/json.so : lib/lua_json.c ../framework/cJSON.c
	$(CC) -g -shared -fPIC -o $@ $^ $(LUACFLAG) $(LUALFLAG) -I ../framework

lib/%.so : lib/lua_%.c 
	$(CC) -g -shared -fPIC -o $@ $^ $(LUACFLAG) $(LUALFLAG) -I ../framework

.PHONY : clean tag distclean

install:
	@cp -vf server ../bin/
	@cp -vf $(LUALIB) ../lib/
	@mkdir -pv ../lib/protobuf/
	@mv -vf ../lib/protobuf.so ../lib/protobuf/c.so

clean :
	@rm -vf $(OBJ) $(OBJ_COMM) $(LUALIB)

distclean : clean
	@rm -vf $(BIN)
