package network

import (
	"net"
	"time"
	"bytes"
	"io"
	"sync"
	"encoding/binary"
	"code.agame.com/aiserver/log"
	"code.agame.com/aiserver/logic"
	"code.agame.com/aiserver/config"
	"code.agame.com/aiserver/amf"
	"code.agame.com/aiserver/common"
)

// Client
type Client struct {
	Protocol string
	Addr     string
	pid      uint32
	server_id int64
	conn     net.Conn
	send_buffer  *common.SendBuffer
	action_ch    chan logic.Action
	ai           *common.AIObject
	is_stop      bool
	locker       sync.Mutex
	process_action_coroutine_ready bool
	push_action_time int64
}

// new
func NewClient(protocol, addr string, pid uint32, server_id int64, from_pid uint32, from_srv_id int64)*Client{
	log.Info("NewClient(%s, %s, %d, %d)", protocol, addr, pid, server_id)
	send_buffer :=common.NewSendBuffer()
	ai :=common.NewAIObject(pid, server_id, send_buffer, from_pid, from_srv_id)
	if ai == nil || send_buffer == nil {
		return nil
	}
	ai.Login()

	client := &Client{
		Protocol : protocol,
		Addr : addr,
		pid  : pid,
		server_id : server_id,
		send_buffer : send_buffer,
		action_ch   : make(chan logic.Action, 3),
		ai : ai,
		push_action_time : time.Now().Unix(),
	}
	if client.Startup() {
		return client
	} else {
		return nil
	}
}

// startup & stop
func (this *Client)Startup()bool{
	return this.connect()
}
func (this *Client)Stop(){
	this.locker.Lock()
	is_log := !this.is_stop
	this.is_stop =true
	this.locker.Unlock()
	this.disconnect()

	if is_log {
		log.Info("Client `%d` @ `%s[%d]` stopped", this.pid, this.Addr, this.server_id)
	}
}
func (this *Client)IsStop()bool{
	this.locker.Lock()
	defer this.locker.Unlock()
	return this.is_stop
}

// connect & disconnect
func (this *Client)connect()bool{
	conn, err := net.Dial(this.Protocol, this.Addr)
	if err == nil {
		this.conn = conn
		go this.send(conn)
		go this.recv(conn)
		go this.process_action()
		log.Info("AI `%d` success to connect `%s`", this.pid, this.Addr)
		return true
	} else {
		log.Printf("AI `%d` fail to connect `%s`, %s\n", this.pid, this.Addr, err.Error())
		return false
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
		close(this.action_ch)
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
			this.Stop()
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
func (this *Client)process_action(){
	this.locker.Lock()
	this.process_action_coroutine_ready =true
	this.locker.Unlock()
	for {
		if this.IsStop() {
			return
		}
		if !this.ai.IsOnline() {
			time.Sleep(time.Second / 1000)
			continue;
		}
		if !this.ai.IsActive() {
			log.Debug("ai %d stopped, not active", this.ai.Pid)
			this.Stop()
			return
		}
		if act, ok := this.PopAction(); ok {
			if !logic.ProcessAction(act, this.ai) {
				this.Stop()
				return
			}
		} else {
			this.Stop()
			return
		}
	}
}
func (this *Client)PushAction(act logic.Action){
	if this.IsStop() {
		return
	}
	this.locker.Lock()
	ready := this.process_action_coroutine_ready
	this.push_action_time =time.Now().Unix()
	this.locker.Unlock()
	if ready {
		defer func(){
			if err := recover(); err!=nil {
				log.Error("Client %d fail to push action %d, %+v", this.pid, act.ActionId, err)
			}
		}()
		log.Debug("Client %d push action %d", this.pid, act.ActionId)
		this.action_ch <- act
	}
}
func (this *Client)PopAction()(logic.Action, bool){
	defer func(){
		if err := recover(); err!=nil {
			log.Error("Client %d fail to pop action, %+v", this.pid, err)
		}
	}()
	act, ok := <-this.action_ch
	return act, ok
}
func (this *Client)IsIdle()bool{
	var idle bool
	this.locker.Lock()
	idle =((time.Now().Unix() - this.push_action_time) > config.Config.IdleDuration)
	this.locker.Unlock()
	return idle
}
