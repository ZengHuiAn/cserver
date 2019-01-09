package main

import(
	"flag"
	"code.agame.com/framework/common"
	"code.agame.com/framework/services"
)

func main(){
	// flag
	var cfg_path             = flag.String("c",   "../etc/framework.xml", "config file");
	flag.Parse()

	// init framework
	common.InitFramework(*cfg_path)

	// register service
	services.Register(*cfg_path)

	// run
	common.Framework.Run()
}
