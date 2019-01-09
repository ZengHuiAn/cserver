package network

import (
	"net"
	"time"
	"code.agame.com/authserver/config"
	"code.agame.com/authserver/log"
)

// Listener
type Listener struct {
	Protocol     string
	Addr         string
	listener     net.Listener
	client_table map[uint32]*Client
}

func NewListener(protocol, addr string) *Listener {
	if len(protocol) == 0 {
		protocol = config.Config.Protocol
	}
	if len(addr) == 0 {
		addr = config.Config.Address
	}
	listener := &Listener{Protocol: protocol, Addr: addr, client_table: make(map[uint32]*Client)}
	listener.Startup()
	return listener
}

func (this *Listener) Startup() {
	if this.listener != nil {
		this.listener.Close()
	}
	go func() {
		// listen
		for {
			listener, err := net.Listen(this.Protocol, this.Addr)
			if err == nil {
				log.Info("authserver/listen.go success to start authserver %s", this.Addr)
				this.listener = listener
				break
			} else {
				log.Warn("fail to authserver %s, %s", this.Addr, err.Error())
			}
			time.Sleep(1 * time.Second)
		}

		// accept
		for {
			conn, err := this.listener.Accept()
			if err != nil {
				log.Error("%s listener fail to accpet %s, %s", this.Addr, conn.LocalAddr().String(), err.Error())
				this.Startup()
				return
			}
			log.Info("%s listener accpet %s", this.Addr, conn.RemoteAddr().String())
			NewClient(conn)
		}
	}()
}
