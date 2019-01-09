package common
import(
	"errors"
	"sync"
)


/* 
	struct RingBuffer
	thread safe guarantee
*/
type RingBuffer struct {
	list    [][]byte
	closed  bool
	_mutex  sync.Mutex
	_cond   *sync.Cond
}
func NewRingBuffer()*RingBuffer{
	mutex := sync.Mutex{}
	return &RingBuffer{
		_mutex : mutex,
		_cond  : sync.NewCond(&mutex),
	}
}

/*
	Append, Pop, Clear, IsClosed
*/
func (this *RingBuffer)Append(buf []byte)(err error){
	if nil == buf {
		return errors.New("arg buf is nil")
	}
	this._mutex.Lock()
	if false == this.closed {
		if this.list == nil {
			this.list =make([][]byte, 0)
		}
		this.list =append(this.list, buf)
		this._cond.Signal()
	}
	this._mutex.Unlock()
	return nil
}
func (this *RingBuffer)Pop()([]byte, error){
	var bs []byte
	this._mutex.Lock()
	if len(this.list) > 0 {
		bs =this.list[0]
		this.list =this.list[1:]
	} else {
		for !this.closed {
			this._cond.Wait()
			if len(this.list) > 0 {
				bs =this.list[0]
				this.list =this.list[1:]
				break
			}
		}
	}
	this._mutex.Unlock()
	return bs, nil
}

func (this *RingBuffer)Clear()(error){
	this._mutex.Lock()
	this.list =nil
	this._mutex.Unlock()
	return nil
}
func (this *RingBuffer)IsClosed()bool{
	var ret bool
	this._mutex.Lock()
	ret =this.closed
	this._mutex.Unlock()
	return ret
}

/*
	impl io.WriterCloser
*/
func (this *RingBuffer)Write(bs []byte)(int, error){
	if err := this.Append(bs); err!=nil {
		return 0, err
	} else {
		return len(bs), nil
	}
}
func (this *RingBuffer)Close()(error){
	this._mutex.Lock()
	this.closed =true
	this._mutex.Unlock()
	return nil
}
