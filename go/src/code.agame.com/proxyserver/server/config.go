package server

import (
	"log"
	"os"
	"net"
)

var g_listen_addr = ":10000"
var g_config_server_url = "http://127.0.0.1/tools/api/server.php";
var g_update_server_list_delta = int64(60);

func ParseConfig() error {
	if _, err := net.ResolveTCPAddr("tcp", os.Getenv("AGAME_PROXY_ADDR")); err != nil {
		g_listen_addr = os.Getenv("AGAME_PROXY_ADDR");
	}

	if os.Getenv("AGAME_CONFIG_URL") != "" {
		g_config_server_url = os.Getenv("AGAME_CONFIG_URL");
	}

	log.Println("g_listen_addr", g_listen_addr);
	log.Println("g_config_server_url", g_config_server_url);
	log.Println("g_update_server_list_delta", g_update_server_list_delta);

	return nil
}

func GetServeAddr() string {
	return g_listen_addr;
}

func GetConfigServerURL() string {
	return g_config_server_url;
}

func GetPullDelta() int64 {
	return g_update_server_list_delta;
}
