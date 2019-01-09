package logic

import (
	"math/rand"
	"net"
	"code.agame.com/dispatchserver/log"
	"code.agame.com/dispatchserver/common"
	"code.agame.com/dispatchserver/config"
);

//** MessageCache **//
type MessageCache struct {
	Header *common.ServerPacketHeader
	Body   []byte
}

//** Context **//
type Context struct {
	CacheList       []MessageCache
	FightServerList []*FightServer
	pipe            chan []byte
	conn            net.Conn
}

func NewContext(conn net.Conn)*Context{
	// new Context
	ctx := &Context{
		CacheList       : make([]MessageCache, 0),
		FightServerList : make([]*FightServer, 0),
		pipe            : make(chan []byte),
		conn            : conn,
	}

	// init fight server
	for i:=0; i<len(config.Config.FightServerList); i++ {
		cfg := config.Config.FightServerList[i]
		if len(cfg.Addr) > 0 {
			fs := NewFightServer(cfg.Addr, conn)
			ctx.FightServerList =append(ctx.FightServerList, fs)
		}
	}

	// go
	go ctx.on_data()
	return ctx
}
func (this *Context)Release(){
	defer func(){
		if err:=recover(); err!=nil {
			log.Error("context recover, double release")
		}
	}()
	// close pipe
	close(this.pipe)

	// release all fight server
	for i:=0; i<len(this.FightServerList); i++ {
		fs := this.FightServerList[i]
		fs.Release()
	}

	// log
	for i:=0; i<len(this.CacheList); i++ {
		cache := this.CacheList[i]
		log.Warn("Lost message %+v", cache.Header)
	}
	log.Info("context release")
}
func (this *Context)AppendCache(header *common.ServerPacketHeader, body []byte){
	if int64(len(this.CacheList)) < config.Config.MaxCacheSize {
		this.CacheList =append(this.CacheList, MessageCache{ Header:header, Body:body })
	}
}
func (this *Context)DrainCache(){
	for len(this.CacheList) > 0 {
		cache := this.CacheList[0]
		if ProcessMsg(cache.Header, cache.Body, this) {
			this.CacheList =this.CacheList[1:]
		} else {
			break
		}
	}
}
func (this *Context)SendToFightServer(bs []byte)bool{
	if len(bs) <= 0 {
		return true
	}
	cnt := len(this.FightServerList)
	if cnt == 0 {
		return false
	}
	idx := int(rand.Int31n(int32(cnt)))
	fs := this.FightServerList[idx]
	fs.Send(bs)
	return true
}
func (this *Context)on_data(){
	for {
		// prepare data
		bs, ok := <-this.pipe
		if !ok {
			break
		}

		// send back
		if _, err := this.conn.Write(bs); err != nil {
			log.Error("context write error, %s", err.Error())
			break
		}
	}
}
