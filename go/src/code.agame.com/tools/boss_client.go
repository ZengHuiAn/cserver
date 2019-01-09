package main

import (
	"code.agame.com/proto/amf"
	"log"
	"net"
	"io"
	"os"
	"os/signal"
	"flag"
	"bufio"
	// "strconv"
	"bytes"
	"encoding/binary"
	"time"
)

var addr = flag.String("r", "localhost:7810", "gateway address");
var accountFileName = flag.String("f", "account.txt", "pid file");

func main() {
	flag.Parse();

	file, err := os.Open(*accountFileName);
	if err != nil {
		log.Fatal(err);
	}

	reader := bufio.NewReader(file);

	i := 0;
	for i < 100 {
		account, _, err := reader.ReadLine();
		if err == io.EOF {
			break;
		} else if err != nil {
			log.Fatal(err);
		}

		time.Sleep(300 * time.Millisecond);
		go clientProcess(string(account));
		i ++;
	}

	c := make(chan os.Signal, 1);
	signal.Notify(c, os.Interrupt, os.Kill);
	s := <-c;
	log.Println("Get Signal:", s);
}

type Header struct {
	Length uint32;
	Flag   uint32;
	Cmd    uint32;
};



func writeAndRead(conn net.Conn, sn uint32, cmd uint32, request []interface{}) ([]interface{}, error) {
	var header Header;

	request[0] = sn;

	// log.Println(">", request);
	// login
	var buffer bytes.Buffer;
	length, err := amf.Encode(&buffer, &request);
	if err != nil {
		return nil, err;
	}

	header.Length = uint32(length) + 12;
	header.Flag = 1;
	header.Cmd = cmd;

	err = binary.Write(conn, binary.BigEndian, &header);
	if err != nil {
		return nil, err;
	}

	_, err = conn.Write(buffer.Bytes());
	if err != nil {
		return nil, err;
	}

	for {
		err := binary.Read(conn, binary.BigEndian, &header);
		if err != nil {
			return nil, err;
		}

		bs := make([]byte, header.Length - 12);
		_, err = io.ReadFull(conn, bs);
		if err != nil {
			return nil, err;
		}

		respond_buffer := bytes.NewBuffer(bs);
		respond, err := amf.Decode(respond_buffer);
		if err != nil {
			return nil, err;
		}

		respondArray := respond.([]interface{});

		// log.Println("<", respondArray);
		if uint32(respondArray[0].(int64)) == sn {
			return respondArray, nil;
		}
	}
	return nil, nil;
}



func clientProcess(account string) {
	conn, err := net.Dial("tcp", *addr);
	if err != nil {
		log.Println(err);
		return;
	}
	defer conn.Close();

	var sn uint32 = 0;
	respond, err := writeAndRead(conn, sn, 1, []interface{}{sn, account, "xxx:xxxx:xxxx:xxxx:xxxx:000000000000000000000000000000", 3});
	if respond[1].(int64) != 0 {
		log.Println(account, "login error", respond);
		return;
	}

	for {
		// join boss
		sn++;
		respond, err = writeAndRead(conn, sn, 11001, []interface{}{sn, 9999999});
		if respond[1].(int64) != 0 {
			log.Println(account, "join boss error", respond);
			time.Sleep(5 * time.Second);
			continue;
		}
		log.Println(account, "join boss success");

		for {
			// relive
			sn ++;
			respond, err = writeAndRead(conn, sn, 11037, []interface{}{sn, 9999999, 90, 6, 10});
			if respond == nil {
				return;
			}

			log.Println(account, "relive respond", respond);
			if respond[1].(int64) != 0 && respond[1].(int64) != 2018 {
				log.Println(account, "relive error", respond);
			}

			time.Sleep(2 * time.Second);

			// attack
			sn ++;
			respond, err = writeAndRead(conn, sn, 11019, []interface{}{sn, 9999999});
			if respond == nil {
				return;
			}

			if respond[1].(int64) != 0 {
				log.Println(account, "attack error", respond);
			}

			if  respond[1].(int64) == 1 {
				return;
			}

			log.Println(account, "attack success");
			time.Sleep(3 * time.Second);
		}
	}
}
