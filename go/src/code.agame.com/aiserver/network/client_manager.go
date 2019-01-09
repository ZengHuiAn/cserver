package network

import(
	"sync"
	"code.agame.com/aiserver/log"
)

var g_client_table map[int64]map[uint32]*Client =make(map[int64]map[uint32]*Client)
var g_locker sync.Mutex
func RemoveClient(srv_id int64, client_id uint32){
	// get client
	var client *Client
	g_locker.Lock()
	if g_client_table[srv_id] != nil {
		client =g_client_table[srv_id][client_id]
		delete(g_client_table[srv_id], client_id)
	}
	g_locker.Unlock()

	// stop & log
	if client!=nil && !client.IsStop() {
		client.Stop()
	}
	if client != nil {
		log.Debug("remove client `%d` @ `%d`", client_id, srv_id)
	}
}

func GetClient(to_srv_protocol, to_srv_address string, to_pid uint32, to_srv_id int64, from_pid uint32, from_srv_id int64)*Client{
	// try get client
	g_locker.Lock()
	if g_client_table[to_srv_id] == nil {
		g_client_table[to_srv_id] =make(map[uint32]*Client)
	}
	client :=g_client_table[to_srv_id][to_pid]
	g_locker.Unlock()

	// try new
	if client==nil || client.IsStop() {
		client =NewClient(to_srv_protocol, to_srv_address, to_pid, to_srv_id, from_pid, from_srv_id)
		if client == nil {
			log.Warn("Fail to GetClient(%s, %s, %d, %d, %d, %d)", to_srv_protocol, to_srv_address, to_pid, to_srv_id, from_pid, from_srv_id)
			return nil
		}
		g_locker.Lock()
		g_client_table[to_srv_id][to_pid] =client
		g_locker.Unlock()
	}
	return client
}

func ClearZombie(){
	g_locker.Lock()
	defer g_locker.Unlock()
	client_count := 0
	for _, v := range(g_client_table) {
		ls := make([]uint32, 0)
		for id, client := range(v) {
			if client.IsStop() {
				ls =append(ls, id)
				log.Debug("delete zombie client `%d` @ `%s[%d]`", client.pid, client.Addr, client.server_id)
			} else if client.IsIdle() {
				client.Stop()
				ls =append(ls, id)
				log.Debug("delete idle client `%d` @ `%s[%d]`", client.pid, client.Addr, client.server_id)
			}
		}
		for i:=0; i<len(ls); i++ {
			delete(v, ls[i])
		}
		client_count +=len(v)
	}
	log.Debug("Remain client count is %d", client_count)
}
