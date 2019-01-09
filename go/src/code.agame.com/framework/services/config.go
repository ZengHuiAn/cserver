package services

import (
	"os"
	"io/ioutil"
	"log"
	"encoding/xml"
)

// type
type XMLConfig struct {
	Servers []string   `xml:"Servers"`
	ServerMap map[string]bool
}

// global var
var Config XMLConfig

// load
func LoadConfig(path string) {
	log.Printf("cfg path %s\n", path)
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

	/* process */
	Config.ServerMap =make(map[string]bool)
	for i:=0; i<len(Config.Servers); i++ {
		Config.ServerMap[Config.Servers[i]] =true
	}

	/* log */
	log.Printf("services config:\n%+v\n", Config)
}
