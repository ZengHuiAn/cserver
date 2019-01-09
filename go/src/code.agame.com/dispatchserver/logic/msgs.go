package logic
import(
	// "math/rand"
	"bytes"
	"strings"
	"encoding/binary"
	"net/http"
	"io/ioutil"
	// "net/url"
	//"encoding/json"
	//agame "code.agame.com/com_agame_protocol"
	"code.agame.com/dispatchserver/common"
	"code.agame.com/dispatchserver/log"
	"code.agame.com/dispatchserver/config"
)
// callback
func on_dispatch_http(header *common.ServerPacketHeader, req_body_bs []byte, target *config.DispatchTarget, context *Context)bool{
	log.Info("on_dispatch_http_msg")
	// prepare
	var err error
	var respond *http.Response
	szUrl := target.Addr
	if len(req_body_bs) == 0 {
		log.Error("Fail to request %s, body length is 0: %s", szUrl)
		return false
	}
	req_body_str := string(req_body_bs)

	// post or get
	if target.IsPost {
		respond, err = http.Post(szUrl, "text/plain; charset=utf-8", strings.NewReader(req_body_str))
		if err != nil {
			log.Error("Fail to post %s, error : %s", szUrl, err.Error())
			log.Error("\trequest body : %s", req_body_str)
			context.AppendCache(header, req_body_bs)
			return false
		}
	} else {
		query :="?" + req_body_str;
		szUrl += query
		respond, err = http.Get(szUrl)
		if err != nil {
			log.Error("Fail to get %s, error : %s", szUrl, err.Error())
			log.Error("\trequest body: %s", req_body_str)
			log.Error("\trequest query: %s", query)
			context.AppendCache(header, req_body_bs)
			return false
		}
	}

	// process respond
	if respond != nil {
		defer respond.Body.Close()
		res_body_bs, _:= ioutil.ReadAll(respond.Body)
		log.Debug("Success request %s", szUrl)
		log.Debug("\trequest body : %s", req_body_str)
		if target.IsPost {
			log.Debug("\tmethod is post")
		} else {
			log.Debug("\tmethod is get")
		}
		log.Debug("\trespond body : %s", string(res_body_bs))
	} else {
		log.Debug("Fail request %s, respond is nil", szUrl)
		context.AppendCache(header, req_body_bs)
		return false
	}
	return true
}
func on_dispatch_tcp(header *common.ServerPacketHeader, req_body_bs []byte, target *config.DispatchTarget, context *Context)bool{
	// prepare header bytes
	header_buffer := new(bytes.Buffer)
	if err:=binary.Write(header_buffer, binary.BigEndian, *header); err!=nil {
		log.Error("fail to call on_dispatch_tcp, binary.Write error")
		return false
	}
	header_bs := header_buffer.Bytes()

	// make packet
	packet_bs := append(header_bs, req_body_bs...)

	// send
	context.SendToFightServer(packet_bs)

	log.Debug("on_dispatch_tcp success")
	return true
}
