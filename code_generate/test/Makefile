OBJ=$(patsubst %.c, %.o, $(wildcard *.c))
OBJ_DATA=$(patsubst ../data/%.c, %.o, $(wildcard ../data/*.c))

CFLAGS += -g -Wall -D_DEBUG  -I../data -I./
LDLIBS += -L../../lib -lhiredis -lmysqlclient -lpbc

COMPILE=$(CC) -g -Wall -c
LINK=$(CC)

BIN=./player

all : $(BIN) 

$(BIN) : $(OBJ) $(OBJ_DATA)
	$(LINK) -o $@ $^ $(LDLIBS)

$(OBJ) : %.o : %.c
	$(COMPILE) -o $@ $< $(CFLAGS)

$(OBJ_DATA) : %.o : ../data/%.c
	$(COMPILE) -o $@ $< $(CFLAGS)

.PHONY : clean tag distclean

clean :
	@rm -vf $(OBJ) $(OBJ_DATA)

distclean : clean
	@rm -vf $(BIN)
