package network

import (
	"net"
	"time"
	"bytes"
	"io"
	"sync"
	"encoding/binary"
	"code.agame.com/pressure/log"
	"code.agame.com/pressure/logic"
	"code.agame.com/pressure/amf"
	"code.agame.com/pressure/common"
)

// Client
type Client struct {
	Protocol string
	Addr     string
	pid      uint32
	conn     net.Conn
	send_buffer  *common.SendBuffer
	ai           *common.AIObject
	is_stop      bool
	locker       sync.Mutex
}

// new
func NewClient(protocol, addr string, pid uint32)*Client{
	log.Info("NewClient(%s, %s, %d)", protocol, addr, pid)
	send_buffer :=common.NewSendBuffer()
	ai :=common.NewAIObject(pid, send_buffer)
	if ai == nil || send_buffer == nil {
		return nil
	}
	ai.Login()

	client := &Client{
		Protocol : protocol,
		Addr : addr,
		pid  : pid,
		send_buffer : send_buffer,
		ai : ai,
	}
	go client.Startup()
	return client
}

// startup & stop
func (this *Client)Startup(){
	this.connect()
}
func (this *Client)Stop(){
	this.locker.Lock()
	is_log := !this.is_stop
	this.is_stop =true
	this.locker.Unlock()
	this.disconnect()

	if is_log {
		log.Info("Client `%d` @ `%s` stopped", this.pid, this.Addr)
	}
}
func (this *Client)IsStop()bool{
	this.locker.Lock()
	defer this.locker.Unlock()
	return this.is_stop
}

// connect & disconnect
func (this *Client)connect(){
	for {
		conn, err := net.Dial(this.Protocol, this.Addr)
		if err == nil {
			this.conn = conn
			go this.send(conn)
			go this.recv(conn)
			log.Info("AI `%d` success to connect `%s`", this.pid, this.Addr)
			break
		}
		log.Printf("AI `%d` fail to connect `%s`, %s\n", this.pid, this.Addr, err.Error())
		time.Sleep(1 * time.Second)
	}
}
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

// recv & send & process action
func (this *Client)recv(conn net.Conn){
	for {
		if this.IsStop() {
			return
		}
		var err error
		// read header
		var header common.ClientPacketHeader
		if err = binary.Read(conn, binary.BigEndian, &header); err != nil {
			log.Error("AI `%d` `%s` read header error, %s", this.pid, this.Addr, err.Error())
			this.Stop()
			return
		}
		log.Debug("recv %+v", header)

		// read body
		bs := make([]byte, header.Length - uint32(binary.Size(header)))
		if _, err = io.ReadFull(conn, bs); err != nil {
			log.Error("AI `%d` `%s` read body error, %s", this.pid, this.Addr, err.Error())
			this.Stop()
			return
		}

		// decode body
		body, err := amf.Decode(bytes.NewBuffer(bs))
		if err != nil {
			log.Error("AI `%d` `%s` decode amf error, %s", this.pid, this.Addr, err.Error())
			this.Stop()
			return
		}

		// dispatch
		if request, ok := body.([]interface{}); ok {
			if !logic.ProcessMsg(header, bs, request, this.ai) {
				this.Stop()
				return
			}
		} else {
			log.Error("AI `%d` `%s` decode amf error, not a array", this.pid, this.Addr)
			this.Stop()
			return
		}
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
			log.Error("client `%s` write error, %s", this.Addr, err.Error())
			this.Stop()
			return
		}
		log.Debug("Client[remote addr : %s] success send data", this.Addr)
	}
}
