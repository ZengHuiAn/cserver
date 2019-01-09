PROTOBUF=$(wildcard com/netease/protobuf/*/*.as com/netease/protobuf/*.as)

all : agame.pb fight.pb battlefield.pb config.pb

%.pb  : %.proto
	#protoc --cpp_out=./ $<
	protoc $< -o $@


clean:
	rm -vf *.pb
