package logic

import(
	"code.agame.com/aiserver/common"
	"code.agame.com/aiserver/log"
)

// type
type ActionHandler func(act Action, ai *common.AIObject)bool
type Action struct {
	Header       common.ServerPacketHeader
	FromServerId int64
	FromPid      uint32
	ToServerId   int64
	ToPid        uint32
	ActionId     uint32
	Args         []float64
	StrArgs      []string
}

// var
var g_action_table =map[uint32]ActionHandler{}

// register
func RegisterAction(act_id uint32, handler ActionHandler){
	g_action_table[act_id] =handler
}
func UnregisterAction(act_id uint32, handler ActionHandler){
	delete(g_action_table, act_id)
}
func OnAction(act_id uint32, handler ActionHandler){
	RegisterAction(act_id, handler)
}
func SetActionCallback(act_id uint32, handler ActionHandler){
	RegisterAction(act_id, handler)
}
func SetActionListener(act_id uint32, handler ActionHandler){
	RegisterAction(act_id, handler)
}

// process action
func ProcessAction(act Action, ai *common.AIObject)bool{
	log.Debug("Process Action %d", act.ActionId)
	if handler, ok := g_action_table[act.ActionId]; ok && handler!=nil {
		return handler(act, ai)
	} else {
		log.Debug("Action %d not registed", act.ActionId)
	}
	return true
}
