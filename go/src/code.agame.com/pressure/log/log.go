package log

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
var PrintLevel int= PRINT_LEVEL_MAX
var OutputFilePrefix string
var OutputFileCreateTime time.Time =time.Date(1987, 1, 1, 0, 0, 0, 0, time.Now().Location())

/*
	func
*/
func init(){
	lg.SetFlags(lg.LstdFlags)
}
func SetOutput(w io.Writer){
	lg.SetOutput(w)
	OutputFilePrefix =""
	OutputFileCreateTime =time.Date(1987, 1, 1, 0, 0, 0, 0, time.Now().Location())
}
func SetOutputFile(prefix string){
	// prepare & check
	now := time.Now();
	if now.Year()==OutputFileCreateTime.Year() && now.Month()==OutputFileCreateTime.Month() && now.Day()==OutputFileCreateTime.Day() {
		return
	}
	path := fmt.Sprintf("%s_%04d%02d%02d.log", prefix, now.Year(), now.Month(), now.Day());

	// open & set
	if file, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666); err != nil {
		lg.Printf("Fail to redirect to %s\n", path)
	} else {
		lg.Printf("Success to redirect to %s\r\n", path)
		lg.SetOutput(file)
		OutputFilePrefix =prefix
		OutputFileCreateTime =now
	}
}
func TryRedirectOutputFile(){
	if len(OutputFilePrefix) != 0 {
		SetOutputFile(OutputFilePrefix)
	}
}
func SetPrintLevel(lv int){
	if lv <= PRINT_LEVEL_MIN {
		PrintLevel =PRINT_LEVEL_MIN
	} else if lv >= PRINT_LEVEL_MAX {
		PrintLevel =PRINT_LEVEL_MAX
	} else {
		PrintLevel =lv
	}
}
func Error(format string, v ...interface{}){
	if PrintLevel >= PRINT_LEVEL_ERROR {
		TryRedirectOutputFile()
		var str_fmt ="[ ERROR ]" + format + "\n"
		lg.Printf(str_fmt, v...)
	}
}

func Warn(format string, v ...interface{}){
	if PrintLevel >= PRINT_LEVEL_WARN {
		TryRedirectOutputFile()
		var str_fmt ="[ WARN ]" + format + "\n"
		lg.Printf(str_fmt, v...)
	}
}

func Debug(format string, v ...interface{}){
	if PrintLevel >= PRINT_LEVEL_DEBUG {
		TryRedirectOutputFile()
		var str_fmt ="[ DEBUG ]" + format + "\n"
		lg.Printf(str_fmt, v...)
	}
}

func Info(format string, v ...interface{}){
	if PrintLevel >= PRINT_LEVEL_INFO {
		TryRedirectOutputFile()
		var str_fmt ="[ INFO ]" + format + "\n"
		lg.Printf(str_fmt, v...)
	}
}
func Printf(format string, v ...interface{}){
	TryRedirectOutputFile()
	var str_fmt =format + "\n"
	lg.Printf(str_fmt, v...)
}
func Println(v ...interface{}){
	TryRedirectOutputFile()
	lg.Println(v...)
}
