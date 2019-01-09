package server

import (
	"bytes"
	"code.agame.com/proto/amf"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"strconv"
)

type Header struct {
	Length uint32
	Flag   uint32
	Cmd    uint32
}

func getTargetIp(conn *net.TCPConn) (*net.TCPAddr, *Header, []byte, error) {
	//read header
	var header Header
	err := binary.Read(conn, binary.BigEndian, &header)
	if err != nil {
		log.Printf("[getTargetIp] error, binary fail to read, %v\n", err)
		return nil, nil, nil, err
	}

	//read body
	bs := make([]byte, header.Length-12)
	_, err = io.ReadFull(conn, bs)
	if err != nil {
		log.Printf("[getTargetIp] error, io fail to read body\n", err)
		return nil, nil, nil, err
	}

	//encode amf message
	cli_buf := bytes.NewBuffer(bs)
	amf_buf, err := amf.Decode(cli_buf)
	if err != nil {
		log.Printf("[getTargetIp] fail to decode bs %v\n", err)
		return nil, nil, nil, err
	}

	//get target srv_id
	req := amf_buf.([]interface{})
	if len(req) < 5 {
		return nil, nil, nil, errors.New("len != 4")
	}
	switch req[4].(type) {
	case string:
		break
	default:
		return nil, nil, nil, errors.New("not string type")
	}

	string_srv_id, err := strconv.Atoi(req[4].(string))
	if err != nil {
		log.Printf("[getTargetIp] fail to strconv.Atoi err : %v", err)
		return nil, nil, nil, err
	}
	t_srv_id := int32(string_srv_id)
	if _, ok := g_server_list.Get(t_srv_id); !ok {
		return nil, nil, nil, errors.New(fmt.Sprintf("could not found server for %v", t_srv_id))
	}

	srv_addr, _ := g_server_list.Get(t_srv_id)
	tcp_addr, err := net.ResolveTCPAddr("tcp", srv_addr)
	if err != nil {
		log.Printf("[getTargetIp] could not solve tcp addr %v\n", err)
		return nil, nil, nil, err
	}


	// rewrite server_id -> client_host
	client_host, _, err := net.SplitHostPort(conn.RemoteAddr().String())
	if err == nil {
		req[4] = "ip:" + client_host
		log.Println(client_host, "login");
		var buffer bytes.Buffer
		_, err = amf.Encode(&buffer, req)
		if err == nil {
			bs = buffer.Bytes()
			header.Length = 12 + uint32(len(bs))
		} else {
			log.Println("rewrite client ip failed", err);
		}
	} else {
		log.Println("get client host failed", err);
	}

	return tcp_addr, &header, bs, nil
}

func sendLoginFailedToClient(conn net.Conn) {
	var header Header
	header.Cmd = 2;
	header.Flag = 1;

	var buffer bytes.Buffer;

	amf.Encode(&buffer, []int{0, 100});

	header.Length = uint32(buffer.Len()) + 12;

	binary.Write(conn, binary.BigEndian, &header);
	conn.Write(buffer.Bytes());
}

// cli <-> gate <-> server
func handleRequest(conn *net.TCPConn) {
	target_addr, header, bs, err := getTargetIp(conn)
	if err != nil {
		log.Printf("[handleRequest] fail to get target ip, err = %v", err)
		conn.Close()
		return
	}
	log.Println("[handleRequest] cli prepare dial tcp ", target_addr)
	target_conn, err := net.DialTCP("tcp", nil, target_addr)
	if err != nil {
		log.Println("[handleRequest] dial target addr error:", err, target_addr)
		sendLoginFailedToClient(conn);
		conn.Close()
		return
	}
	log.Println("[handleRequest] cli dial tcp", target_addr)

	if err := binary.Write(target_conn, binary.BigEndian, header); err != nil {
		sendLoginFailedToClient(conn);
		conn.Close()
		target_conn.Close()
		log.Println("[handleRequest] fail to write header")
		return
	}

	if _, err := target_conn.Write(bs); err != nil {
		sendLoginFailedToClient(conn);
		conn.Close()
		target_conn.Close()
		log.Println("[handleRequest] fail to write bs")
		return
	}

	go func() {
		_, err := target_conn.ReadFrom(conn)
		log.Println("[handleRequest] proxy to server read over", err)
		conn.Close()
		target_conn.Close()
		return
	}()
	go func() {
		conn.ReadFrom(target_conn)
		log.Println("[handleRequest] cli to proxy read over", err)
		conn.Close()
		target_conn.Close()
		return
	}()
}

func StartTransfer() {
	tcp_addr, err := net.ResolveTCPAddr("tcp", GetServeAddr())
	if err != nil {
		log.Fatal(err)
	}
	l, err := net.ListenTCP("tcp", tcp_addr)
	if err != nil {
		log.Fatal(err)
	}
	defer l.Close()
	log.Printf("[TransferTcpStart]tcp listening on %+v\n", tcp_addr)
	for {
		c, err := l.AcceptTCP()
		if err != nil {
			log.Printf("[TransferTcpStart] AcceptTCP error %v\n", err)
			continue
		}
		go handleRequest(c)
	}
}
