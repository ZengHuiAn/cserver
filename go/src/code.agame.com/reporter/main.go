package main

import (
	"os"
	"flag"
	"path/filepath"
	"time"
	"fmt"
	"errors"
	"bytes"
	"io/ioutil"
	"archive/tar"
	"encoding/json"
	"strings"
	"path"
	"net/http"
	"os/signal"
	"code.agame.com/reporter/log"
	"code.agame.com/reporter/config"
)

type LogInfo struct {
	log_type string
	log_file_name string
	log_file_content []byte
	log_beg_time int64
	log_end_time int64
}
type HttpRespond struct {
	Status  string `json:"status"`;
	Message string `json:"message"`;
	Code    int32  `json:"code"`;
};

func upload_log(info *LogInfo)error{
	// compress content
	hdr := &tar.Header{
		Name: info.log_file_name,
		Size: int64(len(info.log_file_content)),
	}
	buffer := new(bytes.Buffer)
	tar_writer := tar.NewWriter(buffer)
	if err := tar_writer.WriteHeader(hdr); err!=nil {
		log.Error("fail to report file %s, %s", info.log_file_name, err.Error())
		return err
	}
	if _, err := tar_writer.Write(info.log_file_content); err!=nil {
		log.Error("fail to report file %s, %s", info.log_file_name, err.Error())
		return err
	}
	body := bytes.NewReader(buffer.Bytes())

	// post
	res, err := http.Post(config.Config.Url, "application/x-gzip", body)
	if err != nil {
		log.Error("fail to report file %s, %s", info.log_file_name, err.Error())
		return err
	}
	res_bs, err := ioutil.ReadAll(res.Body)
	res.Body.Close()
	if err != nil {
		log.Error("fail to report file %s, \n\terror %s\n\t%+v", info.log_file_name, err.Error(), res)
		return err
	}
	var respond HttpRespond
    err = json.Unmarshal(res_bs, &respond);
    if err != nil {
		log.Error("fail to report file %s, \n\terror %s\n\t%+v", info.log_file_name, err.Error(), res)
		return err
    }
	if respond.Code == 0 {
		log.Info("success report file %s, %s", info.log_file_name, respond.Message)
		return nil
	} else {
		log.Info("fail to report file %s, %s", info.log_file_name, respond.Message)
		return errors.New(respond.Message)
	}
}
func report_special(fi os.FileInfo)error{
	name := fi.Name()
	// basic prepare
	now := time.Now().Unix()
	full_path := filepath.Join(config.Config.Dir, name)
	full_path_up := filepath.Join(config.Config.Dir, "upload", name + ".up")

	// check file name
	sep := strings.Index(name, "_")
	if sep <= 0 {
		err := errors.New("invalid file name")
		log.Error("fail to report file %s, %s", name, err.Error())
		return err
	}

	// prepare log info
	var li LogInfo
	li.log_file_name = name
	li.log_type = name[0:sep]

	// parse timestamp
	var year, month, day, hour, min int
	if _, err := fmt.Sscanf(name[sep+1:], "%4d%2d%2d%2d%2d", year, month, day, hour, min); err != nil {
		log.Error("fail to report file %s, %s", name, err.Error())
		return err
	}
	timestamp := time.Date(year, time.Month(month), day, hour, min, 0, 0, time.Local).Unix()

	// upload
	cur_timestamp := now - now % config.Config.FileTTL
	if timestamp >= cur_timestamp {
		return nil
	}

	// set log info
	li.log_beg_time = timestamp
	li.log_end_time = timestamp + config.Config.FileTTL

	// read file content
	f, err := os.Open(full_path)
	if err != nil {
		log.Error("fail to report file %s, %s", name, err.Error())
		return err
	}
	content, err := ioutil.ReadAll(f)
	f.Close()
	if err != nil {
		log.Error("fail to report file %s, %s", name, err.Error())
		return err
	}
	if content == nil {
		err := errors.New("content is empty")
		log.Error("fail to report file %s, %s", name, err.Error())
		return err
	}

	// report
	li.log_file_content =content
	if err := upload_log(&li); err!=nil {
		return err
	}

	// mv log file to upload
	// for strange error(SIGINT, ...) occurs, must try 100 times
	try_count := 100
	for {
		err := os.Rename(full_path, full_path_up)
		if err == nil {
			break
		}
		try_count-=1;
		if try_count == 0 {
			log.Error("< FATAL ERROR, MUST MV %s TO UPLOAD BY HAND >fail to report file %s, %s", name, err.Error())
			os.Exit(1);
		}
	}
	return nil
}

func report()error{
	// basic prepare
	dir_path := config.Config.Dir

	// prepare file info list
	dir, err := os.Open(dir_path)
	if err != nil {
		log.Error("fail to open file %s, %s", dir_path, err.Error())
		return err
	}
	fis, err := dir.Readdir(0);
	dir.Close()
	if err != nil {
		log.Error("fail to read dir from file %s, %s", dir_path, err.Error())
		return err
	}

	// report
	for i:=0; i<len(fis); i++ {
		fi := fis[i]
		if fi.IsDir() {
			continue;
		}
		if err := report_special(fi); err!=nil {
			return err
		}
	}
	return nil
}

func main() {
	// flag
	var cfg_path             = flag.String("c",   "../etc/reporter.xml", "config file");
	var daemon               = flag.Bool("d",   false, "daemon");
	flag.Parse()

	// load config
	config.LoadConfig(*cfg_path)

	// set log output
	if *daemon {
		prefix := path.Join(config.Config.Dir, path.Base(os.Args[0]))
		log.SetOutputFile(prefix)
	}

	// loop
	sync_time := time.Now().Unix()
	for {
		now := time.Now().Unix()
		if now - sync_time > config.Config.FileTTL {
			report()
			sync_time =now
		}
		time.Sleep(30 * time.Second)
	}
}

func must(i interface{}, err error) interface{} {
	if err != nil {
		log.Error("must occurs error `%v`", err);
	}
	return i;
}

func wait(signals ... os.Signal) os.Signal {
    c := make(chan os.Signal, 1)
    signal.Notify(c, signals ...);
    s := <-c;
    return s;
}
