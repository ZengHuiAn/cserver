package logic

import (
	"code.agame.com/authserver/common"
	"code.agame.com/authserver/config"
	"code.agame.com/authserver/log"
	agame "code.agame.com/com_agame_protocol"
	proto "code.google.com/p/goprotobuf/proto"
	"crypto/md5"
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

// register
func init() {
	OnMsg(common.S_AUTH_REQUEST, on_auth_msg)
}

// helper
func new_result(result int32) *int32 {
	return proto.Int32(result)
}

func send_common_respond(header common.ServerPacketHeader, respond proto.Message, context *common.Context) {
	if bs, err := proto.Marshal(respond); err == nil {
		if res_data, err := common.MakeNetPacket(header, bs); err == nil {
			context.AppendSendBuffer(res_data)
		} else {
			log.Error("MakeNetPacket error, %s, remote addr is %s", err.Error(), context.RemoteAddrString)
			panic("unexpected error")
		}
	} else {
		log.Error("proto.Marshal error, %s, remote addr is %s", err.Error(), context.RemoteAddrString)
		panic("unexpected error")
	}
}
func send_auth_respond(header common.ServerPacketHeader, sn, result uint32, account string, context *common.Context) {
	respond := &agame.AuthRespond{Sn: proto.Uint32(sn), Result: new_result(int32(result)), Account: proto.String(account)}
	send_common_respond(header, respond, context)
}

// callback //
func on_auth_msg(header common.ServerPacketHeader, bs []byte, context *common.Context) bool {
	log.Info("on_auth_msg")
	log.Debug("header =%+v", header)
	log.Debug("len(bs) =%d", len(bs))
	res_header := header
	res_header.Cmd = common.S_AUTH_RESPOND
	//// decode request
	request := &agame.AuthRequest{}
	if err := proto.Unmarshal(bs, request); err != nil {
		log.Error("fail to call on_auth_msg , remote addr is %s, proto.Unmarshal error, %s", context.RemoteAddrString, err.Error())
		send_auth_respond(res_header, 0, common.RET_PARAM_ERROR, "", context)
		log.Debug("%s", bs)
		return true
	}
	sn := *request.Sn
	account := *request.Account
	token := *request.Token
	var platform string
	len_account := len(account)
	if len_account > 3 && account[len_account-3] == '@' {
		platform = account[len_account-2:]
	} else {
		platform = "00"
	}
	log.Debug("recv auth, sn =%d, account =%s, token =%s", sn, account, token)

	//// dispatch
	var result uint32
	var ret_account string
	if platform == "00" && config.Config.Test.Enable {
		result, ret_account = auth_from_00(account, token)
	} else if platform == "an" && config.Config.ANY.Enable {
		result, ret_account = auth_from_any(account, token)
	} else {
		log.Error("fail to call on_auth_msg, platform unsupported, account =`%s`, token =`%s`", account, token)
		send_auth_respond(res_header, sn, common.RET_PARAM_ERROR, "", context)
		return true
	}

	//// respond
	if result == common.RET_SUCCESS {
		log.Info("success to call on_auth_msg, account =%s, token =%s", account, token)
	} else {
		log.Warn("fail to call on_auth_msg, account =%s, token =%s", account, token)
	}
	send_auth_respond(res_header, sn, uint32(result), ret_account, context)
	return true
}

func auth_from_00(account, token string) (uint32, string) {
	log.Info("success to call auth_from_00 account =%s, token =%s", account, token)
	return common.RET_SUCCESS, account
}

func auth_from_any(account, token string) (uint32, string) {
	log.Info("auth_from_any")
	type RequestInfo struct {
		Status  string `json:"status"`
		Account string `json:"account"`
		Time    int64  `json:"time"`
		Sign    string `json:"sign"`
	}
	// parse request
	reader := strings.NewReader(token)
	decoder := json.NewDecoder(reader)
	if decoder == nil {
		log.Error("fail to call auth_from_any account =%s, token =%s, token is not json", account, token)
		return common.RET_ERROR, ""
	}
	var request RequestInfo
	if err := decoder.Decode(&request); err != nil {
		log.Error("fail to call auth_from_any account =%s, token =%s, %s", account, token, err.Error())
		return common.RET_ERROR, ""
	}
	// check status
	if request.Status != "ok" {
		log.Error("fail to call auth_from_any account =%s, token =%s, status is not ok", account, token)
		return common.RET_ERROR, ""
	}

	// check signature
	apikey := config.Config.ANY.ApiKey
	check_sum := md5.New()
	fmt.Fprintf(check_sum, "apikey=%s&account=%s&time=%d", apikey, request.Account, request.Time)
	sign := fmt.Sprintf("%x", check_sum.Sum(nil))
	log.Debug("apikey=`%s`, account= `%s`, time=`%d`, sign =`%s`", apikey, request.Account, request.Time, sign)
	if sign != request.Sign {
		log.Error("fail to call auth_from_any account =%s, token =%s, sign mismatch", account, token)
		return common.RET_ERROR, ""
	}

	// check expire
	now := time.Now().Unix()
	if now > (request.Time + config.Config.ANY.TTL) {
		log.Error("fail to call auth_from_any account =%s, token =%s, timeout", account, token)
		return common.RET_ERROR, ""
	}

	// success
	log.Info("success to call auth_from_any account =%s, token =%s", account, token)
	return common.RET_SUCCESS, fmt.Sprintf("%s@an", request.Account)
}
