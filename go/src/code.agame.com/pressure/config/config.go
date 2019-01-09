package config

import (
	"os"
	"io/ioutil"
	"log"
	"encoding/xml"
)

// type
type XMLConfig struct {
	ServerProtocol    string   `xml:"ServerProtocol"`;
	ServerAddr        string   `xml:"ServerAddr"`;
	LogDir            string   `xml:"LogDir"`;
	LoginCryptoString string   `xml:"LoginCryptoString"`;
	LoginCount        uint32   `xml:"LoginCount"`;
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
	log.Printf("%+v\n", Config)
}
