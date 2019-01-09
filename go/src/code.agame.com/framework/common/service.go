package common

import(
	"sync"
	"io"
	"errors"
	"fmt"
)

/*
	struct Message
*/
type MessageHead struct {
	Length       uint32
	Sn           uint32
	FromServerId EnumType
	ToServerId   EnumType
	Command      EnumType
	Option       EnumType
}
type Message struct {
	MessageHead
	Body    []byte
	Respond io.Writer
}

/*
	interface IService
	every struct who support this interface, must provide thread safe guarantee
*/
type IService interface {
	// info
	GetId() int64
	GetName() string
	GetDesc() string

	// scheduler
	Start()
	Pause()
	Stop()

	// communication
	Request(msg *Message)error
	Respond(msg *Message)error
}

/*
	struct ServiceManager
	thread safe guarantee
	no panic guarantee
*/
type ServiceManager struct {
	service_map   map[int64]IService
	mutex         sync.RWMutex
}
func NewServiceManager()(*ServiceManager){
	return &ServiceManager{ service_map : make(map[int64]IService) }
}

/*
	internal func
*/
func (this *ServiceManager) tryset_service(service_id int64, service IService)bool{
	ok := false
	this.mutex.Lock()
	if this.service_map[service_id] == nil {
		this.service_map[service_id] =service
		ok =true
	}
	this.mutex.Unlock()
	return ok
}
func (this *ServiceManager) del_service(service_id int64)IService{
	var service IService
	this.mutex.Lock()
	service =this.service_map[service_id]
	this.service_map[service_id] =nil
	this.mutex.Unlock()
	return service
}

/*
	Get Register Unregister
*/
func (this *ServiceManager) GetServiceList()[]IService{
	this.mutex.RLock()
	service_list := make([]IService, len(this.service_map))
	for _, v := range this.service_map {
		service_list = append(service_list, v)
	}
	this.mutex.RUnlock()
	return service_list
}
func (this *ServiceManager) Get(service_id int64)IService{
	this.mutex.RLock()
	service := this.service_map[service_id]
	this.mutex.RUnlock()
	return service
}
func (this *ServiceManager) GetServiceCount()int64{
	this.mutex.RLock()
	count := int64(len(this.service_map))
	this.mutex.RUnlock()
	return count
}
func (this *ServiceManager) Register(service IService)error{
	// check arg
	if nil == service {
		return errors.New("arg service is nil")
	}

	// pre var
	service_id :=service.GetId()

	// safe register
	if this.tryset_service(service_id, service) == false {
		return fmt.Errorf("service %d registered already", service_id)
	}

	// start service
	go service.Start()
	return nil
}
func (this *ServiceManager) Unregister(service_id int64){
	if service := this.del_service(service_id); service!=nil {
		service.Stop()
	}
}
/*  
	Dispatch
*/
func (this *ServiceManager) Dispatch(msg *Message)error{
	// check arg
	if nil == msg {
		return errors.New("arg msg is nil")
	}

	// dispatch
	to_service_id := int64(msg.ToServerId)
	if service:=this.Get(to_service_id); service!=nil {
		return service.Request(msg)
	} else {
		return fmt.Errorf("service %d not found", to_service_id)
	}
}
func (this *ServiceManager) Broadcast(msg *Message)error{
	// check arg
	if nil == msg {
		return errors.New("arg msg is nil")
	}

	// broadcast
	service_list := this.GetServiceList()
	for i:=0; i<len(service_list); i++ {
		service := service_list[i]
		service.Request(msg)
	}
	return nil
}
