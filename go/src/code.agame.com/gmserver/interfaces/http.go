package interfaces

import (
	// "html"
	"code.agame.com/config"
	"code.agame.com/gmserver/logic"
	log "code.agame.com/logger"
	"crypto/md5"
	"fmt"
	"io/ioutil"
	"net/http"
)

type HttpInterface struct {
	pro  string
	addr string
}

func init() {
	hi := &HttpInterface{}
	hi.pro, hi.addr = config.GetGMServerHttpAddr(0)

	register(hi)
}

func (hi *HttpInterface) Name() string {
	return "HttpInterface " + hi.addr
}

func (hi *HttpInterface) Startup() error {
	var err error
	go (func() {
		err = http.ListenAndServe(hi.addr, hi)
	})()
	return err
}

func (hi *HttpInterface) ServeHTTP(w http.ResponseWriter, r *http.Request) {

	bs, err := ioutil.ReadAll(r.Body)
	if err != nil {
		w.Write(logic.BuildErrorMessage(logic.ERROR_PARAM_ERROR))
		return
	}

	log.Println("ServeHTTP", r.URL.Path)
	log.Println(string(bs))

	if len(r.URL.Path) <= 5 {
		w.Write(logic.BuildErrorMessage(logic.ERROR_PARAM_ERROR))
		return
	}
	if r.URL.Path[:5] != "/api/" {
		w.Write(logic.BuildErrorMessage(logic.ERROR_PARAM_ERROR))
		return
	}

	key := config.GetGMServerKey()
	if key != "-" {
		r.ParseForm()
		log.Println(r.Form)

		if r.Form["t"] == nil || r.Form["s"] == nil ||
			len(r.Form["t"]) == 0 || len(r.Form["s"]) == 0 {
			w.Write(logic.BuildErrorMessage(logic.ERROR_PREMISSIONS))
			return
		}

		t := r.Form["t"][0]
		s := r.Form["s"][0]

		h := md5.New()
		fmt.Fprintf(h, "%s%s%s", string(bs), t, key)
		check := fmt.Sprintf("%x", h.Sum(nil))
		if check != s {
			w.Write(logic.BuildErrorMessage(logic.ERROR_PREMISSIONS))
			return
		}
	}

	cmd := r.URL.Path[5:]

	w.Write(logic.HandleCommand(cmd, nil, bs, false))
}
