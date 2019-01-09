package comma_log

import (
	"code.agame.com/config"
	"fmt"
	"os"
	"time"
)

var last *time.Time
var file *os.File

func init() {
	updateLogger()
}

func Println(v ...interface{}) {
	updateLogger()
	fmt.Fprintln(file, v...)
}

func GetLogPath() string {
	now := time.Now()
	return fmt.Sprintf("%s/charge_%04d%02d%02d_%02d.log",
		config.GetLogDir(),
		now.Year(), now.Month(), now.Day(), now.Hour())
}

func updateLogger() {
	if !config.IsDaemon() {
		return
	}
	now := time.Now()
	if last != nil && last.Hour() == now.Hour() {
		return
	}
	if last != nil && last.Hour() != now.Hour() && file != nil {
		file.Close()
	}
	last = &now
	name := fmt.Sprintf("%s/charge_%04d%02d%02d_%02d.log",
		config.GetLogDir(),
		now.Year(), now.Month(), now.Day(), now.Hour())
	var err error
	file, err = os.OpenFile(name, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
	if err != nil {
		return
	}
}
