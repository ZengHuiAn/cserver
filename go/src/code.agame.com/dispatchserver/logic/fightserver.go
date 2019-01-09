package logic

import (
	"net"
	//"time"
	"io"
	"encoding/binary"
	"bytes"
	"code.agame.com/dispatchserver/log"
	"code.agame.com/dispatchserver/common"
);
//** FightServer **//
type FightServer struct{
	Addr         string
	pipe         chan []byte
	context_conn net.Conn
}

func NewFightServer(addr string, ctx_conn net.Conn)(*FightServer){
	// new fight server
	fs := &FightServer{
		Addr         : addr,
		pipe         : make(chan []byte),
		context_conn : ctx_conn,
	}

	// go
	go fs.send(nil)
	return fs
}
func (this *FightServer)Release(){
	defer func(){
		if err := recover(); err!=nil {
			log.Warn("fight server `%s` double release", this.Addr)
		} else {
			log.Info("fight server `%s` release gracefully", this.Addr)
		}
	}()
	close(this.pipe)
}
func (this *FightServer)Send(bs []byte){
	// check arg
	if len(bs) == 0 {
		return
	}

	// work
	defer func(){
		if err := recover(); err!=nil {
			log.Warn("fight server `%s` fail to send, close already", this.Addr)
		}
	}()
	this.pipe <- bs
}
func (this *FightServer)send(conn net.Conn){
	defer func(){
		if conn != nil {
			conn.Close()
		}
	}()
	for {
		var err error

		// prepare data
		bs, ok := <-this.pipe
		if !ok {
			break
		}
		if len(bs) == 0 {
			continue
		}

		// try reconnect
		if nil == conn {
			conn, err = net.Dial("tcp", this.Addr)
			if conn == nil {
				log.Error("fail to connect to fightserver `%s`, error %+v", this.Addr, err)
				continue
			} else {
				go this.recv(conn)
			}
		}

		// send data
		if _, err := conn.Write(bs); err != nil {
			log.Error("fightserver `%s` write error, %s", this.Addr, err.Error())
			conn.Close()
			conn =nil
			continue
		} else {
			log.Debug("success send to fightserver `%s`", this.Addr)
		}
	}
}
func (this *FightServer)recv(conn net.Conn){
	defer func(){
		recover()
	}()
	for {
		// read header
		var header common.ServerPacketHeader
		if err := binary.Read(conn, binary.BigEndian, &header); err != nil {
			log.Error("fightserver `%s` read header error, %s", this.Addr, err.Error())
			break
		}

		// read body
		body_bs := make([]byte, header.Length - uint32(binary.Size(header)))
		if _, err := io.ReadFull(conn, body_bs); err != nil {
			log.Error("fightserver `%s` read body error, %s", this.Addr, err.Error())
			break
		}

		// prepare header bytes
		header_buffer := new(bytes.Buffer)
		if err:=binary.Write(header_buffer, binary.BigEndian, header); err!=nil {
			log.Warn("fail to call recv, binary.Write error")
			continue
		}
		header_bs := header_buffer.Bytes()

		// make packet
		packet_bs := append(header_bs, body_bs...)

		// log
		log.Debug("success recv from fightserver `%s`", this.Addr)

		// send to requester
		if _, err :=this.context_conn.Write(packet_bs); err != nil {
			log.Error("send to back error, %s", err.Error())
			break
		}
	}
}

