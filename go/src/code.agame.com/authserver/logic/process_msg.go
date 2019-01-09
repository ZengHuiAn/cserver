package logic

import(
	"code.agame.com/authserver/common"
)

// type
type MsgHandler func(header common.ServerPacketHeader, bs []byte, context *common.Context)bool

// var
var g_msg_table =map[uint32]MsgHandler{}

// register
func RegisterMsg(cmd uint32, handler MsgHandler){
	g_msg_table[cmd] =handler
}
func UnregisterMsg(cmd uint32, handler MsgHandler){
	delete(g_msg_table, cmd)
}
func OnMsg(cmd uint32, handler MsgHandler){
	RegisterMsg(cmd, handler)
}
func SetMsgCallback(cmd uint32, handler MsgHandler){
	RegisterMsg(cmd, handler)
}
func SetMsgListener(cmd uint32, handler MsgHandler){
	RegisterMsg(cmd, handler)
}

// process msg
func ProcessMsg(header common.ServerPacketHeader, bs []byte, context *common.Context)bool{
	if handler, ok := g_msg_table[header.Cmd]; ok && handler!=nil {
		return handler(header, bs, context)
	}
	return true
}
