package interfaces

import (
	"bufio"
	"bytes"
	"code.agame.com/config"
	"code.agame.com/gmserver/logic"
	log "code.agame.com/logger"
	"encoding/json"
	"net"
)

type TcpInterface struct {
	pro  string
	addr string

	ln net.Listener
}

func init() {
	ti := &TcpInterface{}
	ti.pro, ti.addr = config.GetGMServerAddr(0)

	register(ti)
}

func (ti *TcpInterface) Name() string {
	return "TcpInterface " + ti.pro + "://" + ti.addr
}

func (ti *TcpInterface) Startup() error {
	if ti.ln != nil {
		ti.ln.Close()
		ti.ln = nil
	}

	ln, err := net.Listen(ti.pro, ti.addr)
	if err != nil {
		return err
	}

	ti.ln = ln

	log.Println("listen", ti.pro, ti.addr, "success")

	go (func() {
		defer (func() {
			ti.ln.Close()
			ti.ln = nil
		})()

		for {
			conn, err := ln.Accept()
			if err != nil {
				continue
			}
			go ti.handleConn(conn)
		}
	})()
	return nil
}

type tcpRequest struct {
	logic.JsonRequest

	Cmd string `json:"cmd"`
}

func (ti *TcpInterface) handleConn(conn net.Conn) {
	defer conn.Close()

	scanner := bufio.NewScanner(conn)
	scanner.Split(func(data []byte, atEOF bool) (advance int, token []byte, err error) {
		if atEOF && len(data) == 0 {
			return 0, nil, nil
		}

		start := -1
		stop := -1

		for i := 0; i < len(data); i++ {
			if data[i] == '\r' || data[i] == '\n' || data[i] == '\000' {
				if start == -1 {
					start = 0
				}

				if stop == -1 {
					stop = start - 1
				}

				return i + 1, data[start : stop+1], nil
			} else if data[i] != ' ' && data[i] != '\t' {
				if start == -1 {
					start = i
				}
				stop = i
			}
		}

		// If we're at EOF, we have a final, non-terminated line. Return it.
		if atEOF {
			return len(data), data, nil
		}
		// tcpRequest more data.
		return 0, nil, nil
	})

	for scanner.Scan() {
		bs := scanner.Bytes()
		if len(bs) == 0 {
			continue
		}

		log.Println(string(bs))

		if bytes.Compare(bs[:14], []byte("tgw_l7_forward")) == 0 {
			continue
		}

		if bytes.Compare(bs[:5], []byte("Host:")) == 0 {
			continue
		}

		var request tcpRequest
		if err := json.Unmarshal(bs, &request); err != nil {
			log.Println("json unmarshal failed:", err)

			bs := logic.BuildErrorMessage(logic.ERROR_PARAM_ERROR)
			ti.sendRespond(conn, bs)
			break
		}

		log.Println("start do logic")

		ti.sendRespond(conn, logic.HandleCommand(request.Cmd, &request.JsonRequest, bs, true))
	}

	if scanner.Err() != nil {
		log.Println(scanner.Err())
	} else {
		log.Println("client closed")
	}
}

func (ti *TcpInterface) sendRespond(conn net.Conn, bs []byte) {
	conn.Write(append(bs, '\n', byte(0)))
}
