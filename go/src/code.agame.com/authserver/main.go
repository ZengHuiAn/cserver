package main

import (
	"os"
	"flag"
	"path"
	"os/signal"
	"code.agame.com/authserver/log"
	"code.agame.com/authserver/network"
	"code.agame.com/authserver/config"
)

func main() {
	// flag
	var cfg_path             = flag.String("c",   "../etc/authserver.xml", "config file");
	var daemon               = flag.Bool("d",   false, "daemon");
	flag.Parse()

	// load config
	config.LoadConfig(*cfg_path)

	// set log output
	if *daemon {
		prefix := path.Join(config.Config.LogDir, path.Base(os.Args[0]))
		log.SetOutputFile(prefix)
	}

	// listener
	listener := network.NewListener("", "")
	if listener != nil {
		s := wait(os.Interrupt, os.Kill);
		log.Warn("Got signal `%v`", s);
	}
}

func must(i interface{}, err error) interface{} {
	if err != nil {
		log.Error("must occurs error `%v`", err);
	}
	return i;
}

func wait(signals ... os.Signal) os.Signal {
    c := make(chan os.Signal, 1)
    signal.Notify(c, signals ...);
    s := <-c;
    return s;
}
