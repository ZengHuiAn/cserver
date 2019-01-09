package common
 import(
	// "sync"
	"code.agame.com/pressure/log"
 )

// send buffer
type SendBuffer struct {
	ch chan []byte;
}

func NewSendBuffer()*SendBuffer{
	return &SendBuffer{ch:make(chan[]byte, 10)}
}

func (this *SendBuffer)AppendSendBuffer(buf []byte){
	defer func(){
		if err := recover(); err!=nil {
			log.Debug("channel closed")
		}
	}()
	this.ch <- buf;
}
func (this *SendBuffer)PopSendBuffer()[]byte{
	return <-this.ch;
}

func (this *SendBuffer)Clear(){
	defer func(){
		if err := recover(); err!=nil {
			log.Debug("channel closed")
		}
	}()
	close(this.ch);
}

