package network

import (
	"net"
	// "time"
	"io"
	"sync"
	"encoding/binary"
	"code.agame.com/authserver/log"
	"code.agame.com/authserver/logic"
	"code.agame.com/authserver/common"
)

// Client
type Client struct {
	conn     net.Conn
	send_buffer  *common.SendBuffer
	is_stop      bool
	local_addr   string
	remote_addr  string
	locker       sync.Mutex
}

// new
func NewClient(conn net.Conn)*Client{
	// prepare
	local_addr  :=conn.LocalAddr().String()
	remote_addr :=conn.RemoteAddr().String()
	send_buffer :=common.NewSendBuffer()

	// new
	client := &Client{
		conn        : conn,
		send_buffer : send_buffer,
		is_stop     : false,
		local_addr  : local_addr,
		remote_addr : remote_addr,
	}

	// startup
	go client.recv(conn);
	go client.send(conn);

	// log
	log.Info("NewClient(%s, %s)", client.local_addr, client.remote_addr)
	return client
}

// stop
func (this *Client)Stop(){
	this.locker.Lock()
	need_log := !this.is_stop
	this.is_stop =true
	this.locker.Unlock()
	this.disconnect()

	if need_log {
		log.Info("Client [local `%s`, remote `%s`] stopped", this.local_addr, this.remote_addr)
	}
}
func (this *Client)IsStop()bool{
	this.locker.Lock()
	defer this.locker.Unlock()
	return this.is_stop
}

// disconnect
func (this *Client)disconnect(){
	this.locker.Lock()
	conn := this.conn
	this.conn =nil
	this.locker.Unlock()
	if conn != nil {
		conn.Close()
		this.send_buffer.Clear();
	}
}

// recv & send
func (this *Client)recv(conn net.Conn){
	send_buffer := this.send_buffer
	local_addr  := this.local_addr
	remote_addr := this.remote_addr
	context := common.NewContext(send_buffer, local_addr, remote_addr)

	for {
		if this.IsStop() {
			return
		}
		var err error
		// read header
		var header common.ServerPacketHeader
		if err = binary.Read(conn, binary.BigEndian, &header); err != nil {
			log.Error("`%s` read header from `%s` error, %s", local_addr, remote_addr, err.Error())
			this.Stop();
			break
		}

		// read body
		bs := make([]byte, header.Length - uint32(binary.Size(header)))
		if _, err = io.ReadFull(conn, bs); err != nil {
			log.Error("`%s` read body from `%s` error, %s", local_addr, remote_addr, err.Error())
			this.Stop();
			break
		}

		// log
		log.Info("`%s` read from `%s`", local_addr, remote_addr)

		// dispatch
		go logic.ProcessMsg(header, bs, context)
	}
}

func (this *Client)send(conn net.Conn){
	for {
		if this.IsStop() {
			return
		}
		bs := this.send_buffer.PopSendBuffer();
		if bs == nil {
			break;
		}
		if _, err := conn.Write(bs); err != nil {
			log.Error("client `%s` write error, %s", this.local_addr, err.Error())
			this.Stop()
			return
		}
		log.Debug("Client[local addr : %s, remote addr : %s] success send data", this.local_addr, this.remote_addr)
	}
}
