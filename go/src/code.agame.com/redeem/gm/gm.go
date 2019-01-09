package gmserver

import (
	"crypto/md5"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
)

type sServerInfo struct {
	ID   int32  `json:"id"`
	GM   string `json:"gm"`
	Name string `json:"name"`
	// Flag    int32   `json:"flag"`
}

var lock sync.Mutex
var servers map[int32]string
var lastRequestTime = int64(0)

func doPullIp() bool {
	now := time.Now().Unix()
	if lastRequestTime >= now-int64(60) {
		return true
	}
	lastRequestTime = now

	addr := os.Getenv("AGAME_CONFIG_URL")
	if addr == "" {
		addr = "http://localhost/tools/api/server.php"
	}

	resp, err := http.Get(addr)
	if err != nil {
		log.Println("[doPullIp] http get error:", err)
		return false
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Println("[doPullIp] ioutil readall error:", err)
		return false
	}

	var serverList []sServerInfo
	err = json.Unmarshal(body, &serverList)
	if err != nil {
		log.Println("[doPullIp] Unmarshal error:", err)
		return false
	}

	lock.Lock()
	servers = make(map[int32]string)
	for _, s := range serverList {
		servers[s.ID] = s.GM
	}
	lock.Unlock()
	return true
}

const SrvKey = "123456789"

func Request(sid string, cmd string, request interface{}) ([]byte, error) {
	doPullIp()

	v, err := strconv.Atoi(sid)
	id := int32(v)
	lock.Lock()
	gm, ok := servers[id]
	lock.Unlock()

	if !ok {
		return nil, errors.New("unknown sid")
	}

	content, _ := json.Marshal(request)

	// make url
	t := strconv.Itoa(int(time.Now().Unix()))
	check_sum := md5.New()
	fmt.Fprintf(check_sum, "%s%s%s", content, t, SrvKey)
	s := fmt.Sprintf("%x", check_sum.Sum(nil))
	url := fmt.Sprintf("%s%s?s=%s&t=%s", gm, cmd, s, t)

	log.Printf(url)

	// make body
	body_reader := strings.NewReader(string(content))

	// post
	resp, err := http.Post(url, "text/plain; charset=utf-8", body_reader)
	if err != nil {
		log.Println(err)
		return nil, err
	}

	defer resp.Body.Close()
	bs, _ := ioutil.ReadAll(resp.Body)
	log.Println(string(bs))
	return bs, nil
}
