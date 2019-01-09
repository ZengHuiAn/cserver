package common

import (
	"path"
	"os"
	"time"
	"math/rand"
);

// Framework
type FrameworkType struct {
	LoggerPrefix   string
	Network        *Network
	ServiceManager *ServiceManager
}

var Framework *FrameworkType

func InitFramework(cfg_path string) {
	// try new framework
	if Framework != nil {
		panic("framework can't init twice")
	}
	Framework =&FrameworkType{}

	// init rand seed
	rand.Seed(time.Now().Unix())

	// load config
	LoadConfig(cfg_path)

	// make logger prefix
	Framework.LoggerPrefix =path.Join(Config.LogDir, path.Base(os.Args[0]))

	// network
	Framework.Network =NewNetwork(Config.Protocol, Config.Address)

	// service manager
	Framework.ServiceManager = NewServiceManager()
}

func (this *FrameworkType)Run(){
	this.Network.Startup();
}

