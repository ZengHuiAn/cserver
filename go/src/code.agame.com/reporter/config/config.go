package config

import (
	"os"
	"io/ioutil"
	"log"
	"encoding/xml"
)

// type
type XMLConfig struct {
	Url string `xml:"Url"`;
	Dir string `xml:"String"`;
	FileTTL int64 `xml:"FileTTL"`;
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
	log.Printf("Config >>>>>")
	log.Printf("%+v\n", Config)
}
