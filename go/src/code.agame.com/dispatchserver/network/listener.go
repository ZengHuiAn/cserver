package network

import (
	"net"
	"time"
	"io"
	"encoding/binary"
	"code.agame.com/dispatchserver/log"
	"code.agame.com/dispatchserver/common"
	"code.agame.com/dispatchserver/config"
	"code.agame.com/dispatchserver/logic"
);

// Listener
type Listener struct {
	Protocol string
	Addr     string
	listener net.Listener
}

func NewListener(protocol, addr string) *Listener {
	if len(protocol) == 0 {
		protocol =config.Config.ServerProtocol
	}
	if len(addr) == 0 {
		addr =config.Config.ServerAddr
	}
	listener := &Listener{Protocol : protocol, Addr : addr}
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
				log.Info("success to start dispatchserver %s", this.Addr)
				this.listener = listener
				break
			} else {
				log.Warn("fail to dispatchserver %s, %s", this.Addr, err.Error())
			}
			time.Sleep(1 * time.Second)
		}

		// accept
		for {
			conn, err := this.listener.Accept();
			if err != nil {
				log.Error("%s listener fail to accpet %s, %s", this.Addr, conn.LocalAddr().String(), err.Error())
				this.Startup()
				return
			}
			log.Info("%s listener accpet %s", this.Addr, conn.RemoteAddr().String())
			go this.recv(conn);
		}
	}()
}

func (this *Listener)recv(conn net.Conn) {
	// prepare vars
	remote_addr := conn.RemoteAddr().String()

	// make context
	context := logic.NewContext(conn)
	defer func(){
		context.Release()
	}()

	// loop
	for {
		var err error
		// drain cache
		context.DrainCache()

		// read header
		var header common.ServerPacketHeader
		if err = binary.Read(conn, binary.BigEndian, &header); err != nil {
			log.Error("`%s` read header from `%s` error, %s", this.Addr, remote_addr, err.Error())
			break
		}

		// read body
		bs := make([]byte, header.Length - uint32(binary.Size(header)))
		if _, err = io.ReadFull(conn, bs); err != nil {
			log.Error("`%s` read body from `%s` error, %s", this.Addr, remote_addr, err.Error())
			break
		}

		// append to cache list
		context.AppendCache(&header, bs)

		// log
		log.Info("`%s` recv from `%s`:\n\theader = %+v\n", this.Addr, remote_addr, header)
	}
}
