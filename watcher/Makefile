BIN=../bin/watcher

all : $(BIN)

$(BIN) : ../bin/% : %.o
	cc -o $@ $^

clean :
	@rm -vf *.o

distclean: clean
	@rm -vf ../bin/watcher
	
	

