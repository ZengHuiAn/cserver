package config

import (
	"os"
	"io/ioutil"
	"log"
	"encoding/xml"
)

type Test_Config struct {
	Enable bool `xml:"Enable"`
}

type ANY_Config struct {
	Enable   bool   `xml:"Enable"`
    ApiKey   string `xml:"ApiKey"`
    TTL      int64 `xml:"TTL"`
}

type AuthConfig struct {
	Protocol  string   `xml:"Protocol"`;
	Address	  string   `xml:"Addr"`;
	LogDir    string   `xml:"LogDir"`;

	Test Test_Config `xml:Test`
    ANY ANY_Config  `xml:"ANY"`
}


// global var
var Config AuthConfig

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
