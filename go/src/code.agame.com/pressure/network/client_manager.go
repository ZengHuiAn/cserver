package network

import(
	"sync"
	"code.agame.com/pressure/log"
	"code.agame.com/pressure/config"
)

var g_client_table map[uint32]*Client =make(map[uint32]*Client)
var g_locker sync.Mutex
func RemoveClient(pid uint32){
	// get client
	var client *Client
	g_locker.Lock()
	if g_client_table[pid] != nil {
		client =g_client_table[pid]
		delete(g_client_table, pid)
	}
	g_locker.Unlock()

	// stop & log
	if client!=nil && !client.IsStop() {
		client.Stop()
	}
	if client != nil {
		log.Debug("remove client `%d`", pid)
	}
}

func GetClient(pid uint32)*Client{
	// try get client
	g_locker.Lock()
	client :=g_client_table[pid]
	g_locker.Unlock()

	// try new
	if client==nil || client.IsStop() {
		client =NewClient(config.Config.ServerProtocol, config.Config.ServerAddr, pid)
		if client == nil {
			log.Warn("Fail to GetClient(%d)", pid)
			return nil
		}
		g_locker.Lock()
		g_client_table[pid] =client
		g_locker.Unlock()
	}
	return client
}

func ClearZombie(){
	g_locker.Lock()
	defer g_locker.Unlock()
	ls := make([]uint32, 0)
	for _, client := range(g_client_table) {
		if client.IsStop() {
			ls =append(ls, client.pid)
			log.Debug("delete zombie client `%d`", client.pid)
		}
	}
	for i:=0; i<len(ls); i++ {
		delete(g_client_table, ls[i])
	}
}

func ClearClient(){
	log.Debug("clear client")
	g_locker.Lock()
	defer g_locker.Unlock()
	for _, client := range(g_client_table) {
		client.Stop()
	}
	g_client_table =make(map[uint32]*Client)
}

// Start //
func Startup(count uint32)bool{
	for i:=uint32(0); i<count; i++ {
		GetClient(1000000 + i)
	}
	return true
}
