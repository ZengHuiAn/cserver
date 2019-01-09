package common

import (
	"os"
	"io/ioutil"
	"log"
	"encoding/xml"
)

// type
type XMLConfig struct {
	Version   int64 `xml:"Version,attr"`;
	Protocol  string   `xml:"Protocol"`;
	Address	  string   `xml:"Addr"`;
	LogDir    string   `xml:"LogDir"`;
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
	log.Printf("framework config:\n%+v\n", Config)
}
