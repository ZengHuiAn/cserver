package config

import (
	"os"
	"io/ioutil"
	"log"
	"encoding/xml"
)

// type
type DispatchTarget struct{
	Cmd         int64          `xml:"Cmd"`
	Protocol    string         `xml:"Protocol"`
	Addr        string         `xml:"Addr"`
	IsPost      bool           `xml:"IsPost"`
}
type FightServer struct{
	Addr        string         `xml:"Addr"`
}
type XMLConfig struct {
	ServerProtocol    string            `xml:"ServerProtocol"`;
	ServerAddr        string            `xml:"ServerAddr"`;
	LogDir            string            `xml:"LogDir"`;
	MaxCacheSize      int64             `xml:"MaxCacheSize"`
	TargetList        []DispatchTarget  `xml:"TargetList>Target"`
	TargetMap         map[int64]DispatchTarget
	FightServerList   []FightServer     `xml:"FightServerList>FightServer"`
}

// global var
var Config XMLConfig

// load
func LoadConfig(path string) {
	log.Printf("cfg path %s", path)
	file, err := os.Open(path);
	if err != nil {
		log.Fatal(err);
	}

	bs, err := ioutil.ReadAll(file);
	if err != nil {
		log.Fatal(err);
	}

	err = xml.Unmarshal(bs, &Config);
	if err != nil {
		log.Fatal(err);
	}
	Config.TargetMap =make(map[int64]DispatchTarget)
	for i:=0; i<len(Config.TargetList); i++ {
		target := Config.TargetList[i]
		Config.TargetMap[target.Cmd] =target
	}
	log.Printf("%+v\n", Config)
}
