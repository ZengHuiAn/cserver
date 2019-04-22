OBJ_MAIN=$(patsubst %.c, %.o, $(wildcard *.c))
OBJ_COMM=$(patsubst ../framework/%.c, %.o, $(wildcard ../framework/*.c))
OBJ_MODULE=$(patsubst %.c, %.o, $(wildcard ./modules/*.c))


MYSQL_CFLAG=-I/usr/include/mysql/
MYSQL_LFLAG=-L/usr/lib/mysql/

-include local.mk

CFLAGS += -g -Wall -D_DEBUG -I./ -I../framework -I../include -I../thirdpart $(MYSQL_CFLAG)
LDLIBS += -L../lib -lrt -lpbc -lmxml -lpthread -ldl $(MYSQL_LFLAG) -lmysqlclient

CC=g++

COMPILE=$(CC) -c
LINK=$(CC)

BIN=../bin/gateway

OBJ=$(OBJ_MAIN) $(OBJ_MODULE)

all : $(BIN)

$(BIN) : $(OBJ) $(OBJ_COMM)
	$(LINK) -o $@ $^ $(LDLIBS) 

$(OBJ_COMM) : %.o : ../framework/%.c
	$(COMPILE) -o $@ $< $(CFLAGS)

$(OBJ) : %.o : %.c
	$(COMPILE) -o $@ $< $(CFLAGS)

.PHONY : clean tag distclean

clean :
	@rm -vf $(OBJ) $(OBJ_COMM)

distclean : clean
	@rm -vf $(BIN)
