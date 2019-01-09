package gmserver
import(
	"fmt"
	"strings"
	"io/ioutil"
	"net/http"
	"crypto/md5"
	"code.agame.com/aiserver/log"
	// "code.agame.com/aiserver/config"
)
const SrvKey ="123456789"
func Request(gmserver_url, cmd, body_string string){
	// make url
	t :="123456789"
	check_sum := md5.New()
	fmt.Fprintf(check_sum, "%s%s%s", body_string, t, SrvKey)
	s := fmt.Sprintf("%x", check_sum.Sum(nil))
	url_str := fmt.Sprintf("%s/api/%s?s=%s&t=%s", gmserver_url, cmd, s, t)

	// make body
	body_reader := strings.NewReader(body_string)

	// log
	log.Debug("GM request url : %s", url_str)
	log.Debug("GM request body : %s", body_string)

	// post
	resp, err := http.Post(url_str, "text/plain; charset=utf-8", body_reader)
	if err != nil {
		log.Error("Fail to Request gmserver, error : %s", err.Error())
	} else {
		defer resp.Body.Close()
		bs, _:= ioutil.ReadAll(resp.Body)
		log.Info("respond : %+v\n\tbs : %s", resp, string(bs))
	}
}
