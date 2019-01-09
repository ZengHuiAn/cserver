package config

import (
	"os"
	"io/ioutil"
	"math/rand"
	"log"
	"encoding/json"
)

/*
var g_name_list []string =[]string{
	"fool",
	"winne",
	"rex",
	"c",
	"c++",
	"c#",
	"java",
	"lua",
	"python",
	"haskell",
}
*/

// global var
var g_ai_name_pool []string

func GenAIName()string{
	if n := len(g_ai_name_pool); n>0 {
		return g_ai_name_pool[ rand.Int() % n ]
	} else {
		return "unnamed"
	}
}


func LoadAINamePool(path string){
	g_ai_name_pool =make([]string, 0)
	log.Printf("ai name pool cfg path %s", path)
	file, err := os.Open(path);
	if err != nil {
		log.Fatal(err);
	}

	bs, err := ioutil.ReadAll(file);
	if err!=nil {
		log.Fatal(err);
	}

	err = json.Unmarshal(bs, &g_ai_name_pool);
	if err != nil {
		log.Printf("for debug\n")
		log.Fatal(err);
	}
	log.Printf("ai name pool count %d", len(g_ai_name_pool))
	log.Printf("ai name pool first 10 %+v", g_ai_name_pool[0:10])
	// log.Printf("%+v\n", g_ai_name_pool)
}
