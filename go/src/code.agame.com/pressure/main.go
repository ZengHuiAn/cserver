package main

import (
	"os"
	"flag"
	"path"
	"time"
	"math/rand"
	"os/signal"
	"code.agame.com/pressure/log"
	"code.agame.com/pressure/network"
	"code.agame.com/pressure/config"
)

func main() {
	// flag
	var cfg_path             = flag.String("c",   "../etc/pressure.xml", "config file");
	var daemon               = flag.Bool("d",   false, "daemon");
	flag.Parse()

	// load config
	config.LoadConfig(*cfg_path)

	// set log output
	if *daemon {
		prefix := path.Join(config.Config.LogDir, path.Base(os.Args[0]))
		log.SetOutputFile(prefix)
	}

	// init rand seed
	rand.Seed(time.Now().Unix())

	// pressure start
	log.Debug("Count =%d", config.Config.LoginCount)
	//wait(os.Interrupt, os.Kill);
	if network.Startup(config.Config.LoginCount) {
		log.Debug("Start Success");
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
