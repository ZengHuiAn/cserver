package common

import (
	"log"
	"net"
	"os"
	"sync"
)

/*
	Network
*/
type Network struct {
	Protocol        string
	Addr            string
	listener        net.Listener
	transceiver_map map[int64]*Transceiver
	mutex           sync.Mutex
	id_counter      int64
	logger          *Logger
}

func NewNetwork(protocol, addr string) *Network {
	network := &Network{
		Protocol:        protocol,
		Addr:            addr,
		transceiver_map: make(map[int64]*Transceiver),
	}
	network.logger = NewLogger()
	network.logger.SetOutputFile(Framework.LoggerPrefix)
	return network
}

func (this *Network) Startup() {
	logger := this.logger
	// listen
	listener, err := net.Listen(this.Protocol, this.Addr)
	if err == nil {
		logger.Info("success to start authserver %s", this.Addr)
		this.listener = listener
	} else {
		log.Printf("fail to authserver %s, %s\n", this.Addr, err.Error())
		os.Exit(1)
	}

	// accept
	for {
		conn, err := this.listener.Accept()
		if err != nil {
			logger.Error("%s listener fail to accpet %s, %s", this.Addr, conn.LocalAddr().String(), err.Error())
			this.Startup()
		}
		logger.Info("%s listener accpet %s", this.Addr, conn.RemoteAddr().String())
		transceiver := NewTransceiver(this.id_counter, conn)
		this.AddTransceiver(transceiver)
		this.id_counter += 1
	}
}
func (this *Network) AddTransceiver(transceiver *Transceiver) {
	this.mutex.Lock()
	this.transceiver_map[transceiver.GetId()] = transceiver
	this.mutex.Unlock()
}
func (this *Network) GetTransceiver(id int64) *Transceiver {
	this.mutex.Lock()
	transceiver := this.transceiver_map[id]
	this.mutex.Unlock()
	return transceiver
}
func (this *Network) RemoveTransceiver(id int64) {
	this.mutex.Lock()
	this.transceiver_map[id] = nil
	this.mutex.Unlock()
}
func (this *Network) Broadcast(bs []byte) {
	if bs == nil {
		return
	}
	this.mutex.Lock()
	ls := make([]*Transceiver, 0, len(this.transceiver_map))
	for _, v := range this.transceiver_map {
		ls = append(ls, v)
	}
	this.mutex.Unlock()
	for i := 0; i < len(ls); i++ {
		transceiver := ls[i]
		transceiver.Send(bs)
	}
}
