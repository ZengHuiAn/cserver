package server

import (
	//"encoding/binary"
	"log"
	"time"
)

var g_last_update_server_time = int64(0);
func UpdateServerList() {
	for {
		//N秒向host请求ip
		if time.Now().Unix()-g_last_update_server_time > GetPullDelta() {
			log.Println("[UpdateServerList] begin pull ip ")
			ok := doPullIp()
			log.Printf("[UpdateServerList] end pull ip, result=%v", ok)
			g_last_update_server_time = time.Now().Unix()
		} else {
			time.Sleep(1 * time.Second)
		}
	}
}

func ForceUpdateServerList() {
	g_last_update_server_time = 0
}
