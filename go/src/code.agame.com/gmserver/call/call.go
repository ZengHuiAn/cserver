package main

import (
	"crypto/md5"
	"fmt"
	"os"
	"flag"
	"io/ioutil"
	"net/http"
	"strings"
)

const SrvKey = "123456789"

func main() {
	// load cfg
	var file_name = flag.String("f", "", "file");
	flag.Parse()

	// load msgs
    fin, err := os.Open(*file_name)
    if err != nil {
        fmt.Printf("fail to open file `%s`, %s\n", *file_name, err.Error())
        return
    }
    defer fin.Close()
    bs, err := ioutil.ReadAll(fin)
    if err != nil {
        fmt.Printf("fail to read file `msgs`, %s\n", err.Error())
        return
    }
    str := string(bs)
    msg_list := strings.Split(str, "\n")

	// process msgs
    for i:=0; i<len(msg_list); i++{
		// parse msg
        msg := msg_list[i]
        if len(msg)==0 {
			break
        }
		if msg[0:1] == "#" {
			continue
		}
        fmt.Printf("################ send msg %d ###############\n", i)
        fmt.Printf("\tmsg = %s\n", msg)
		// parse gmserver
		msg =strings.Trim(msg, " ")
		sep_idx := strings.Index(msg, " ")
		if sep_idx == -1 || sep_idx == 0 || sep_idx == len(msg)-1 {
			fmt.Printf("invalidate msg format\n")
			break
		}
		gmserver := msg[0:sep_idx]
		gmserver =strings.Trim(gmserver, " ")
		if len(gmserver) == 0 {
			fmt.Printf("invalidate msg format, gmserver is empty\n")
			break
		}
		// parse cmd
		sub_msg := msg[sep_idx+1:]
		sub_msg =strings.Trim(sub_msg, " ")
		sep_idx = strings.Index(sub_msg, " ")
		if sep_idx == -1 || sep_idx == 0 || sep_idx == len(msg)-1 {
			fmt.Printf("invalidate msg format\n")
			break
		}
		cmd := sub_msg[0:sep_idx]
		cmd =strings.Trim(cmd, " ")
		if len(cmd) == 0 {
			fmt.Printf("invalidate msg format, cmd is empty\n")
			break
		}
		// parse arg
		arg := sub_msg[sep_idx+1:]
		if len(arg) == 0 {
			fmt.Printf("invalidate msg format\n")
			break
		}
		arg =strings.Trim(arg, " ")
		// log
        fmt.Printf("\tgm  = %s\n", gmserver)
        fmt.Printf("\tcmd = %s\n", cmd)
        fmt.Printf("\targ = %s\n", arg)

        // make url
        t := "123456789"
        body_string := arg
        check_sum := md5.New()
        fmt.Fprintf(check_sum, "%s%s%s", body_string, t, SrvKey)
        s := fmt.Sprintf("%x", check_sum.Sum(nil))
        url_str := fmt.Sprintf("http://%s/api/%s?s=%s&t=%s", gmserver, cmd, s, t)
        fmt.Printf("\turl = %s\n", url_str)

        // make body
        body_reader := strings.NewReader(body_string)

        // post
        resp, err := http.Post(url_str, "text/plain; charset=utf-8", body_reader)
        if err != nil {
            fmt.Printf("\trespond : %+v\n", resp)
            fmt.Printf("\terror : %+v\n", err)
            break
        } else {
            defer resp.Body.Close()
            bs, _ := ioutil.ReadAll(resp.Body)
            fmt.Printf("\tbody: %s\n", bs)
        }
    }
}
