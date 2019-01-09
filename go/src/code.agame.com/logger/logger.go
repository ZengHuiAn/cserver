package logger


import (
	olog "log"
	"path"
	"time"
	"fmt"
	"os"
	"code.agame.com/config"
)

func init() {
	updateLogger();
}

func Printf(format string, v ...interface{}) {
	updateLogger();
	olog.Printf(format, v ...);
}

func Println(v ...interface{}) {
	updateLogger();
	olog.Println(v ...);
}

func Fatal(v ...interface{}) {
	updateLogger();
	olog.Fatal(v ...);
}

var last *time.Time;
var file *os.File;
func updateLogger() {
	if !config.IsDaemon() {
		return;
	}

	now := time.Now();
	if last != nil && last.YearDay() == now.YearDay() {
		return;
	}
	last = &now;

	olog.SetFlags(olog.Ldate|olog.Lmicroseconds);

	name := fmt.Sprintf("%s/%s_%04d%02d%02d.log",
			config.GetLogDir(),
			path.Base(os.Args[0]),
			now.Year(), now.Month(), now.Day());

	olog.Println("redirect log to", name);

	var err error;
	file, err = os.OpenFile(name, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666);
	if err != nil {
		olog.Println(name, err);
		return;
	}

	olog.SetOutput(file);
}
