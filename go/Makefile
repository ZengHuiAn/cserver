-include local.mk

all : build

proto : src/code.agame.com/com_agame_protocol/agame.pb.go 

%.pb.go : %.proto  bin/protoc-gen-go
	PATH=$(PATH):`pwd`/bin protoc --go_out=. $<

bin/protoc-gen-go : src/code.google.com/p/goprotobuf/protoc-gen-go/main.go
	GOPATH=`pwd` go install code.google.com/p/goprotobuf/protoc-gen-go

gmserver : src/code.agame.com/gmserver/main.go
	GOPATH=`pwd` go run $<  $(RUN_PARAM)

authserver : src/code.agame.com/authserver/main.go
	GOPATH=`pwd` go run $<  $(RUN_PARAM)

% : src/code.agame.com/%/main.go
	GOPATH=`pwd` go run $<  $(RUN_PARAM)

install: proto
	GOPATH=`pwd` go install code.agame.com/gmserver
	@cp -vf bin/gmserver ../bin/gmserver
	GOPATH=`pwd` go install code.agame.com/authserver
	@cp -vf bin/authserver ../bin/authserver

build: proto
	GOPATH=`pwd` go build code.agame.com/gmserver
	GOPATH=`pwd` go build code.agame.com/authserver

run : proto
	# GOPATH=`pwd` go run code.agame.com/gmserver
	GOPATH=`pwd` go run code.agame.com/authserver
