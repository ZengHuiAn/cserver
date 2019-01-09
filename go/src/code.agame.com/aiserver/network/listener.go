package network

import (
	"net"
	"time"
	"io"
	"encoding/binary"
	agame "code.agame.com/com_agame_protocol"
	proto "code.google.com/p/goprotobuf/proto"
	"code.agame.com/aiserver/log"
	"code.agame.com/aiserver/common"
	"code.agame.com/aiserver/config"
	"code.agame.com/aiserver/dbmgr"
	"code.agame.com/aiserver/logic"
);

// Listener
type Listener struct {
	Protocol string
	Addr     string
	listener net.Listener
	client_table map[uint32]*Client
}

func NewListener(protocol, addr string) *Listener {
	if len(protocol) == 0 {
		protocol =config.Config.Protocol
	}
	if len(addr) == 0 {
		addr =config.Config.Address
	}
	listener := &Listener{Protocol : protocol, Addr : addr, client_table : make(map[uint32]*Client)}
	listener.Startup()
	return listener
}

func (this *Listener) Startup() {
	if this.listener != nil {
		this.listener.Close()
	}
	go func() {
/*
		// connect to db
		for id, _ := range(config.Config.ServerTable) {
			dbmgr.GetDBMgr(id)
		}
*/

		// listen
		for {
			listener, err := net.Listen(this.Protocol, this.Addr)
			if err == nil {
				log.Info("success to start aiserver %s", this.Addr)
				this.listener = listener
				break
			} else {
				log.Warn("fail to aiserver %s, %s", this.Addr, err.Error())
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
	remote_addr := conn.RemoteAddr().String()
	for {
		var err error
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
		if header.Cmd != common.NOTIFY_AI_ACTION {
			time.Sleep(1)
			continue
		}
		// log.Debug("WTF:%d", header.Cmd)

		// decode body
		request := &agame.AIActionNotify{}
		if err = proto.Unmarshal(bs, request); err != nil {
			log.Error("`%s` decode body from `%s` error, %s", this.Addr, remote_addr, err.Error())
			log.Error("%s", bs);
			break
		}
		/*
		if *request.FromPid == 1 {
			continue
		}
		*/

		// log
		log.Info("`%s` recv action from `%s`:\n\theader = %+v\n\trequest = %+v", this.Addr, remote_addr, header, request)

		// prepare to dispatch to each target server
		action_id        := *request.ActionId
		from_server_id   := int64(*request.FromServerId)
		from_pid         := *request.FromPid
		ai_pid_begin     := uint32(config.Config.AiPidBegin)
		ai_pid_group_size:= uint32(config.Config.AiPidGroupSize)
		if ai_pid_begin <= 4500000 {
			ai_pid_begin =4500000
		}
		if ai_pid_group_size <= 200000 {
			ai_pid_group_size =200000
		}

		// check vip
		vip_exp :=dbmgr.QueryVipExp(from_server_id, from_pid)
		if vip_exp >= 5000 {
			log.Debug("refuse dispatch ai from %d pid %d, vip exp %d >= 5000", from_server_id, from_pid, vip_exp)
			continue;
		} else {
			log.Debug("allow dispatch ai from %d pid %d, vip exp %d < 5000", from_server_id, from_pid, vip_exp)
		}

		// dispatch
		target_srvs      := config.Config.ServerRouteTable[from_server_id]
		for i:=0; i<len(target_srvs); i++ {
			grp_idx      := target_srvs[i].GroupIndex
			target_srv   := target_srvs[i].Server
			to_server_id := target_srv.Id
			to_pid       := ai_pid_begin + uint32(grp_idx)*ai_pid_group_size + from_pid
			if action_id == common.ACTION_LOGOUT {
				RemoveClient(to_server_id, to_pid)
			} else {
				log.Debug("ACTION %d", action_id)
				if client := GetClient(target_srv.Protocol, target_srv.Address, to_pid, to_server_id, from_pid, from_server_id); client!=nil {
					client.PushAction(logic.Action{
						Header : header,
						FromServerId : from_server_id,
						FromPid      : from_pid,
						ToServerId   : to_server_id,
						ToPid        : to_pid,
						ActionId     : action_id,
						Args         : request.Args,
						StrArgs      : request.StrArgs,
					})
				} else {
					log.Debug("not found client")
				}
			}
		}

		// remove zombie
		ClearZombie()
	}
}

