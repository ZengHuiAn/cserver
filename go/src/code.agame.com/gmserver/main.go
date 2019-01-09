package main

import (
	log "code.agame.com/logger"
	"os"
	"os/signal"

	_ "code.agame.com/config"
	_ "code.agame.com/remote"
	_ "code.agame.com/service"
	_ "code.agame.com/database"
	_ "code.agame.com/logger"

	"code.agame.com/gmserver/interfaces"
)

func main() {
	interfaces.Init();

	s := wait(os.Interrupt, os.Kill);
    log.Println("Got signal:", s);
}

func must(i interface{}, err error) interface{} {
	if err != nil {
		log.Fatal(err);
	}
	return i;
}

func wait(signals ... os.Signal) os.Signal {
    c := make(chan os.Signal, 1)
    signal.Notify(c, signals ...);
    s := <-c;
    return s;
}
