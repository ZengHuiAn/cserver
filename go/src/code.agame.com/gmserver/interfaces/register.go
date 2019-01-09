package interfaces

import (
	log "code.agame.com/logger"
)

type NetInterface interface {
	Name()   string;
	Startup() error;
};

var ins = make(map[string]NetInterface);

func Init() {
/*/
}

func init() {
/**/
	for _, in := range ins {
		log.Println(in.Name(), "Startup");
		err := in.Startup();
		if err != nil {
			log.Fatal(in.Name(), "Startup failed:", err);
		}
	}
}

func register(in NetInterface) {
	ins[in.Name()] = in;
}
