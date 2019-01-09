package common

import(
	"io"
	"time"
	"fmt"
	"os"
	lg "log"
)

/*
	var
*/
const (
	PRINT_LEVEL_MIN =iota
	PRINT_LEVEL_ERROR
	PRINT_LEVEL_WARN
	PRINT_LEVEL_DEBUG
	PRINT_LEVEL_INFO
	PRINT_LEVEL_MAX
)

/*
	type
*/
type Logger struct {
	PrintLevel int
	OutputFilePrefix string
	OutputFileCreateTime time.Time
	logger *lg.Logger
}
func NewLogger() *Logger {
	return &Logger{
		PrintLevel:PRINT_LEVEL_MAX,
		OutputFileCreateTime: time.Date(1987, 1, 1, 0, 0, 0, 0, time.Now().Location()),
	}
}

/*
	func
*/
func (this *Logger)Close(){
}
func (this *Logger)SetOutput(w io.Writer){
	this.OutputFilePrefix =""
	this.OutputFileCreateTime =time.Date(1987, 1, 1, 0, 0, 0, 0, time.Now().Location())
	this.logger =lg.New(w, "", lg.LstdFlags)
}
func (this *Logger)SetOutputFile(prefix string){
	// prepare & check
	now := time.Now();
	if now.Year()==this.OutputFileCreateTime.Year() && now.Month()==this.OutputFileCreateTime.Month() && now.Day()==this.OutputFileCreateTime.Day() && now.Hour()==this.OutputFileCreateTime.Hour() {
		return
	}
	path := fmt.Sprintf("%s_%04d%02d%02d%02d.log", prefix, now.Year(), now.Month(), now.Day(), now.Hour());

	// open & set
	if file, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666); err != nil {
		lg.Printf("Fail to redirect to %s\n", path)
	} else {
		lg.Printf("Success to redirect to %s\r\n", path)
		this.SetOutput(file)
		this.OutputFilePrefix =prefix
		this.OutputFileCreateTime =now
	}
}
func (this *Logger)TryRedirectOutputFile(){
	if len(this.OutputFilePrefix) != 0 {
		this.SetOutputFile(this.OutputFilePrefix)
	}
}
func (this *Logger)SetPrintLevel(lv int){
	if lv <= PRINT_LEVEL_MIN {
		this.PrintLevel =PRINT_LEVEL_MIN
	} else if lv >= PRINT_LEVEL_MAX {
		this.PrintLevel =PRINT_LEVEL_MAX
	} else {
		this.PrintLevel =lv
	}
}
func (this *Logger)Error(format string, v ...interface{}){
	if this.PrintLevel >= PRINT_LEVEL_ERROR {
		this.TryRedirectOutputFile()
		if nil != this.logger {
			var str_fmt ="[ ERROR ]" + format + "\n"
			this.logger.Printf(str_fmt, v...)
		}
	}
}

func (this *Logger)Warn(format string, v ...interface{}){
	if this.PrintLevel >= PRINT_LEVEL_WARN {
		this.TryRedirectOutputFile()
		if nil != this.logger {
			var str_fmt ="[ WARN ]" + format + "\n"
			this.logger.Printf(str_fmt, v...)
		}
	}
}

func (this *Logger)Debug(format string, v ...interface{}){
	if this.PrintLevel >= PRINT_LEVEL_DEBUG {
		this.TryRedirectOutputFile()
		if nil != this.logger {
			var str_fmt ="[ DEBUG ]" + format + "\n"
			this.logger.Printf(str_fmt, v...)
		}
	}
}

func (this *Logger)Info(format string, v ...interface{}){
	if this.PrintLevel >= PRINT_LEVEL_INFO {
		this.TryRedirectOutputFile()
		if nil != this.logger {
			var str_fmt ="[ INFO ]" + format + "\n"
			this.logger.Printf(str_fmt, v...)
		}
	}
}
func (this *Logger)Printf(format string, v ...interface{}){
	this.TryRedirectOutputFile()
	if nil != this.logger {
		this.logger.Printf(format, v...)
	}
}
