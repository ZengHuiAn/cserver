package main

import (
	"bufio"
	"log"
	"net"
	"net/http"
	"net/http/fcgi"
	"os"
	"strings"

	"code.agame.com/redeem/gift"
	"code.agame.com/redeem/invite"
	"code.agame.com/redeem/redeem"
)

func main() {
	ln, err := net.Listen("tcp", ":9001")
	if err != nil {
		log.Fatal(err)
	}

	RegisterRoute("/go/hello", hello, false)
	RegisterRoute("/go/redeem/new", redeem.New, true)
	RegisterRoute("/go/redeem/gen", redeem.Gen, true)
	RegisterRoute("/go/redeem/status", redeem.Status, true)
	RegisterRoute("/go/redeem/list", redeem.List, true)
	RegisterRoute("/go/redeem/exchange", redeem.Exchange, false)
	RegisterRoute("/go/gift/import", gift.Import, true)
	RegisterRoute("/go/gift/list", gift.List, true)
	RegisterRoute("/go/gift/exchange", gift.Use, false)
	RegisterRoute("/go/gift/store", gift.Store, false)
	RegisterRoute("/go/invite/query", invite.Query, false)
	RegisterRoute("/go/invite/invite", invite.Invite, false)
	RegisterRoute("/go/invite/reward", invite.Reward, false)
	RegisterRoute("/go/invite/reload", invite.Reload, false)

	err = fcgi.Serve(ln, getHandler())
	if err != nil {
		log.Fatal(err)
	}
}

func RegisterRoute(path string, f http.HandlerFunc, admin bool) {
	getHandler().Route(path, f, admin)
}

type routeHandlerItem struct {
	cb    http.HandlerFunc
	admin bool
}

type routeHandler struct {
	route map[string]*routeHandlerItem
}

var handler *routeHandler = nil

func getHandler() *routeHandler {
	if handler == nil {
		handler = &routeHandler{route: make(map[string]*routeHandlerItem)}
	}
	return handler
}

func (h *routeHandler) Route(path string, f http.HandlerFunc, admin bool) {
	h.route[path] = &routeHandlerItem{cb: f, admin: admin}
}

var whiteList []*net.IPNet

func appendNet(addr string) {
	if addr == "" {
		return
	}

	ip, ipnet, err := net.ParseCIDR(addr)
	if err != nil {
		log.Println(err)
		return
	}

	log.Println(ip, ipnet)
	whiteList = append(whiteList, ipnet)
}

func init() {
	whiteList = make([]*net.IPNet, 0)

	appendNet("127.0.0.1/8")
	appendNet("192.0.0.1/8")
	appendNet("10.1.1.1/8")
	appendNet("172.1.1.1/8")
	appendNet("101.231.222.238/32")

	f, err := os.Open("white.txt")
	if err != nil {
		return
	}
	defer f.Close()

	b := bufio.NewReader(f)
	for {
		line, _, err := b.ReadLine()
		if err != nil {
			break
		}
		appendNet(strings.TrimSpace(string(line)))
	}
}

func isWhiteList(r *http.Request) bool {
	remoteAddr := r.RemoteAddr
	host, _, err := net.SplitHostPort(remoteAddr)
	if err != nil {
		return false
	}

	if r.Header.Get("X-Forwarded-For") != "" {
		log.Println("X-Forwarded-For", r.Header.Get("X-Forwarded-For"))
		host = r.Header.Get("X-Forwarded-For")
	}

	log.Println("check", host)

	ip := net.ParseIP(host)
	for _, v := range whiteList {
		if v.Contains(ip) {
			return true
		}
	}
	return false
}

func (h *routeHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	log.Println(r.URL.Path)
	if t, ok := h.route[r.URL.Path]; ok {
		if t.admin {
			if !isWhiteList(r) {
				w.WriteHeader(404)
				return
			}
		}
		t.cb(w, r)
	} else {
		w.WriteHeader(404)
	}
}

func hello(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("hello world"))
}
