OBJ=$(patsubst %.cpp, %.o, $(wildcard *.cpp))

CFLAGS += -g -Wall -D_DEBUG -I../include -I../thirdpart/pbc/src/
LDLIBS += -L../lib -lpbc

COMPILE=g++ -g -Wall -c
LINK=g++

BIN=./code_generate
PROTOC=player.pb

all : $(BIN) $(PROTOC) FORCE
	./code_generate

$(BIN) : $(OBJ)
	$(LINK) -o $@ $^ $(LDLIBS)

$(OBJ) : %.o : %.cpp
	$(COMPILE) -o $@ $< $(CFLAGS)

$(PROTOC) : %.pb : %.proto
	protoc -o $@ $^

FORCE :
	./gen_config_protocol.lua

.PHONY : clean tag distclean

clean :
	@rm -vf $(OBJ) $(OBJ_COMM) $(PROTOC)

distclean : clean
	@rm -vf $(BIN)
