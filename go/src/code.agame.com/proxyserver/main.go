package main

import (
	"log"
	server "code.agame.com/proxyserver/server"
	"os"
	"os/signal"
)

func main() {
	logfile, err := os.OpenFile("/opt/log/proxy.log", os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666);
	if err == nil {
		log.Println("write log to /opt/log/proxy.log");
		log.SetOutput(logfile);
	} else {
		log.Println(err);
    }

	if server.ParseConfig() != nil {
		log.Println("fail to ParseConfig, exit")
		return
	}

	go server.UpdateServerList()
	go server.StartTransfer();

	s := wait(os.Interrupt, os.Kill)
	log.Println("Got signal:", s)
}

func wait(signals ...os.Signal) os.Signal {
	c := make(chan os.Signal, 1)
	signal.Notify(c, signals...)
	s := <-c
	return s
}
