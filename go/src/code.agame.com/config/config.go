package config

import (
	"encoding/xml"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
)

type XMLDatabase struct {
	Host   string `xml:"host"`
	Port   uint   `xml:"port"`
	User   string `xml:"user"`
	Passwd string `xml:"passwd"`
	Db     string `xml:"db"`
	Socket string `xml:"socket"`
}

type Addr struct {
	Host string `xml:"host"`
	Port uint   `xml:"port"`
}

type Service struct {
	Addr

	Name string `xml:"name,attr"`

	Min uint `xml:"min,attr"`
	Max uint `xml:"max,attr"`
	ID  uint `xml:"id,attr"`
}

type XMLFile struct {
	Id       uint32 `xml:"id,attr"`
	Platform string `xml:"platform,attr"`

	HTMLBase string
	PortBase uint

	Database struct {
		Account XMLDatabase
		Game    XMLDatabase
	}

	GateWay struct {
		Addr
		Max  uint `xml:"max"`
		Auth uint `xml:"auth"`
		Key  string
	}

	GMServer struct {
		Addr
		Key string

		Http Addr `xml:"Http"`
	}

	Cells []struct {
		Addr
		Name xml.Name
	} `xml:"Cells>Cell"`

	Social []Service `xml:"Social>Service"`

	SocialName map[string]*Service

	Log struct {
		FileDir  string
		Realtime struct {
			Interval uint
		}
	}
}

var configFile XMLFile

func must(v interface{}, err error) interface{} {
	if err != nil {
		log.Fatal(err)
	}
	return v
}

var cfg = flag.String("c", "../etc/lksg.xml", "config file")
var sid = flag.Uint("sid", 10001, "server id")
var daemon = flag.Bool("d", false, "run as daemon")

func init() {
	flag.Parse()

	file, err := os.Open(*cfg)
	if err != nil {
		log.Fatal(err)
	}

	bs, err := ioutil.ReadAll(file)
	if err != nil {
		log.Fatal(err)
	}

	print("cccc1\n")
	err = xml.Unmarshal(bs, &configFile)
	if err != nil {
		log.Fatal(err)
	}

	print("cccc\n")

	/*
		if configFile.Id != uint32(*sid) {
			log.Fatal("sid error: ", configFile.Id, " != ", *sid);
		}
	*/
	configFile.SocialName = make(map[string]*Service)

	for i := 0; i < len(configFile.Social); i++ {
		service := &configFile.Social[i]
		configFile.SocialName[service.Name] = service
	}
}

func buildAddr(cfg *Addr, id uint) (pro, addr string) {
	host := cfg.Host
	port := cfg.Port

	if host == "" {
		host = "localhost"
	}

	if port == 0 {
		port = configFile.PortBase + id
	}

	if host[:7] == "unix://" {
		pro = "unix"
		addr = host[7:]
	} else {
		pro = "tcp"
		addr = fmt.Sprintf("%s:%v", host, port)
	}
	return

}

func GetServiceAddr(name string, hint uint32) (pro, addr string) {
	if name == "Gateway" || name == "GateWay" {
		return GetGatewayAddr(hint)
	} else if name == "World" {
		return GetWorldAddr(hint)
	} else if name == "GMServer" {
		return GetGMServerAddr(hint)
	} else if name == "GMServerHttp" {
		return GetGMServerHttpAddr(hint)
	} else {
		service := configFile.SocialName[name]
		if service != nil {
			return buildAddr(&service.Addr, service.ID)
		}
	}
	return "", ""
}

func GetWorldAddr(hint uint32) (pro, addr string) {
	pos := hint % uint32(len(configFile.Cells))
	return buildAddr(&configFile.Cells[pos].Addr, uint(pos+1))
}

func GetGMServerAddr(hint uint32) (pro string, addr string) {
	return buildAddr(&configFile.GMServer.Addr, 80)
}

func GetGMServerHttpAddr(hint uint32) (pro string, addr string) {
	return buildAddr(&configFile.GMServer.Http, 81)
}

func GetServerID() uint32 {
	return configFile.Id
}

func GetGMServerKey() string {
	key := configFile.GMServer.Key
	if key == "" {
		key = "123456789"
	}
	return key
}

func GetGatewayAddr(hint uint32) (pro string, addr string) {
	return buildAddr(&configFile.GateWay.Addr, 0)
}

func GetGateWayKey() string {
	key := configFile.GateWay.Key
	if key == "" {
		key = "123456789"
	}
	return key
}

func getDBAddr(db *XMLDatabase) string {
	if db.Socket != "" {
		return fmt.Sprintf("%s:%s@unix(%s)/%s?charset=utf8",
			db.User, db.Passwd, db.Socket, db.Db)

	} else {
		port := db.Port
		if port == 0 {
			port = 3306
		}

		host := db.Host
		if host == "" {
			host = "127.0.0.1"
		}

		return fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?charset=utf8",
			db.User, db.Passwd, host, port, db.Db)
	}
}

func GetDBAddr(name string) string {
	switch name {
	case "Account":
		return GetAccountDBAddr()
	case "Game", "Role":
		return GetRoleDBAddr()
	}
	return ""
}

func GetAccountDBAddr() string {
	return getDBAddr(&configFile.Database.Account)
}

func GetRoleDBAddr() string {
	return getDBAddr(&configFile.Database.Game)
}

func GetLogDir() string {
	return configFile.Log.FileDir
}

func IsDaemon() bool {
	return *daemon
}
