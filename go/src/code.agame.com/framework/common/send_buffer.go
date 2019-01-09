package common

/* 
	struct SendBuffer
	thread safe guarantee
*/
type SendBuffer struct {
	ch chan []byte;
}
func NewSendBuffer()*SendBuffer{
	return &SendBuffer{ch:make(chan[]byte, 0)}
}

/*
	Append, Pop, Clear
*/
func (this *SendBuffer)Append(buf []byte)(ret_err error){
	defer func(){
		if err := recover(); err!=nil {
			ret_err =err.(error)
		}
	}()
	this.ch <- buf;
	return
}
func (this *SendBuffer)Pop()(ret_bs []byte, ret_err error){
	defer func(){
		if err := recover(); err!=nil {
			ret_bs  =nil
			ret_err =err.(error)
		}
	}()
	ret_bs = <-this.ch;
	return
}

/*
	impl io.WriterCloser
*/
func (this *SendBuffer)Write(bs []byte)(int, error){
	if err := this.Append(bs); err!=nil {
		return 0, err
	} else {
		return len(bs), nil
	}
}
func (this *SendBuffer)Close()(ret_err error){
	defer func(){
		if err := recover(); err!=nil {
			ret_err =err.(error)
		}
	}()
	close(this.ch);
	return
}
