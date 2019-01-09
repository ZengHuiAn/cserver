package common

import (
	"net"
	"io"
	"fmt"
	"log"
	"sync"
	"encoding/binary"
)

/*
	struct Transceiver
*/
type Transceiver struct {
	Addr        string
	_conn       net.Conn
	_mutex      sync.Mutex
	_id         int64
	_send_buffer *SendBuffer
}

/*
	new
*/
func NewTransceiver(id int64, conn net.Conn)*Transceiver{
	transceiver := &Transceiver{
		Addr   : conn.RemoteAddr().String(),
		_conn  : conn,
		_id    : id,
	}
	transceiver.Open(conn)
	return transceiver
}

/*
	Open Close
*/
func (this *Transceiver)GetId()int64{
	return this._id
}
func (this *Transceiver)Open(conn net.Conn){
	sb := NewSendBuffer()
	go this.recv(conn, sb)
	go this.send(conn, sb)
	log.Printf("Transceiver %s Opened\n", this.Addr)
}
func (this *Transceiver)Close(){
	var conn net.Conn
	this._mutex.Lock()
	if this._conn != nil {
		conn =this._conn
		this._conn =nil
	}
	this._mutex.Unlock()
	if conn != nil {
		defer func(){
			if err := recover(); err!=nil {
				log.Printf("WTF:%+v\n", err)
			}
			log.Printf("Transceiver %s Closed\n", this.Addr)
		}()
		conn.Close()
	}
}

/* 
	recv, send
*/
func (this *Transceiver)recv(conn net.Conn, send_buffer *SendBuffer){
	defer this.Close()
	service_manager := Framework.ServiceManager
	logger := NewLogger()
	logger.SetOutputFile(fmt.Sprintf("%s_recv_%s", Framework.LoggerPrefix, this.Addr))
	defer logger.Close()

	for {
		// read head
		var head MessageHead
		if err := binary.Read(conn, binary.BigEndian, &head); err != nil {
			logger.Error("read head from %s error, %s", this.Addr, err.Error())
			break
		}

		// read body
		bs := make([]byte, head.Length - uint32(binary.Size(head)))
		if _, err := io.ReadFull(conn, bs); err != nil {
			logger.Error("read body from %s error, %s", this.Addr, err.Error())
			break
		}

		// make message
		msg := Message{ MessageHead : head, Body : bs, Respond : send_buffer }

		// dispatch
		if err := service_manager.Dispatch(&msg); err!=nil {
			logger.Warn("dispatch msg %+v from %s error, %s", head, this.Addr, err.Error())
		}
	}
}
func (this *Transceiver)send(conn net.Conn, send_buffer *SendBuffer){
	defer this.Close()
	logger := NewLogger()
	logger.SetOutputFile(fmt.Sprintf("%s_send_%s", Framework.LoggerPrefix, this.Addr))
	defer logger.Close()

	for {
		// pre buffer
		bs,_ := send_buffer.Pop()
		if bs == nil {
			break;
		}

		// write
		if _, err := conn.Write(bs); err != nil {
			logger.Error("write to %s error, %s", this.Addr, err.Error())
			break
		}
	}
}
func (this *Transceiver) Send(bs []byte)error{
	_, err := this._send_buffer.Write(bs)
	return err
}
