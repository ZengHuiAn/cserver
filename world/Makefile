OBJ_COMM=$(patsubst ../framework/%.c, %.o, $(wildcard ../framework/*.c))
OBJ_MAIN=$(patsubst %.c, %.o, $(wildcard *.c))
OBJ_MODULE=$(patsubst %.c, %.o, $(wildcard ./modules/*.c))
OBJ_DATA=$(patsubst %.c, %.o, $(wildcard ./data/*.c))
OBJ_SCRIPT=$(patsubst %.c, %.o, $(wildcard ./scripts/*.c))
OBJ_LOGIC=$(patsubst %.c, %.o, $(wildcard ./logic/*.c))
OBJ_REQUEST_AMF=$(patsubst %.c, %.o, $(wildcard ./request_amf/*.c))
OBJ_REQUEST_PBC=$(patsubst %.c, %.o, $(wildcard ./request_pbc/*.c))
OBJ_CONFIG=$(patsubst %.c, %.o, $(wildcard ./config/*.c))
OBJ_CALC=$(patsubst %.c, %.o, $(wildcard ./calc/*.c))
OBJ_BATTLE=$(patsubst %.c, %.o, $(wildcard ./battlefield/*.c) $(wildcard ./battlefield/buffer_effect/*.c))

MYSQL_CFLAG=-I/usr/include/mysql/
MYSQL_LFLAG=-L/usr/lib/mysql/

-include local.mk

CFLAGS += -g -Wall -D_DEBUG -I./ -I../framework -I./request_amf -I../include  $(MYSQL_CFLAG)
LDLIBS +=-L../lib -lpbc -lluajit -lmysqlclient -lmxml $(MYSQL_LFLAG) 

CC=g++

COMPILE=$(CC) -c
LINK=$(CC)

BIN=../bin/world

OBJ=$(OBJ_MAIN) \
	$(OBJ_MODULE) \
	$(OBJ_DATA) \
	$(OBJ_REQUEST_AMF) \
	$(OBJ_SCRIPT) \
	$(OBJ_LOGIC) \
	$(OBJ_TEMPLATE) \
	$(OBJ_REQUEST_PBC) \
	$(OBJ_CONFIG) \
	$(OBJ_CALC) \
	$(OBJ_BATTLE) 

all : $(BIN)

$(BIN) : $(OBJ) $(OBJ_COMM)
	$(LINK) -o $@ $^ $(LDLIBS) 

$(OBJ_COMM) : %.o : ../framework/%.c version.h
	$(COMPILE) -fPIC -o $@ $< $(CFLAGS)

%.so : %.o memory.o
	$(CC) -g --shared -fPIC -o $@ $^

$(OBJ) : %.o : %.c 
	$(COMPILE) -fPIC -o $@ $< $(CFLAGS)

version.h:
	sh ../tools/version.sh

%.o : %.c
	$(COMPILE) -fPIC -o $@ $< $(CFLAGS)

.PHONY : clean tag distclean

clean :
	@rm -vf $(OBJ) $(OBJ_COMM)

distclean : clean
	@rm -vf $(BIN)
