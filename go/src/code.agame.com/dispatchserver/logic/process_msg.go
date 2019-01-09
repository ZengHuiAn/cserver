package logic

import(
	"code.agame.com/dispatchserver/common"
	"code.agame.com/dispatchserver/log"
	"code.agame.com/dispatchserver/config"
)

func ProcessMsg(header *common.ServerPacketHeader, body []byte, context *Context)bool{
	if target, ok := config.Config.TargetMap[int64(header.Cmd)]; ok {
		switch target.Protocol {
		case common.PROTOCOL_HTTP:
			return on_dispatch_http(header, body, &target, context);
		case common.PROTOCOL_TCP:
			return on_dispatch_tcp(header, body, &target, context);
		default:
			log.Warn("unknown protocol %d", target.Protocol)
		}
	} else {
		log.Warn("unknown target %d", header.Cmd)
	}
	return true
}
