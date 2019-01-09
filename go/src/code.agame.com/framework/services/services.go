package services
import(
	"log"
	"code.agame.com/framework/common"
)

/*
	service table
*/
type ServiceDesc struct {
	Name    string
	Creator func ()common.IService
}

/*
	func
*/
func Register(cfg_path string){
	// prepare
	service_list := []ServiceDesc{
		ServiceDesc{ "", nil },
	}

	// load config
	LoadConfig(cfg_path)

	// register service
	for i:=0; i<len(service_list); i++ {
		name    := service_list[i].Name
		creator := service_list[i].Creator
		if len(name)==0 || creator==nil {
			continue
		}
		if false == Config.ServerMap[name] {
			continue
		}
		service := creator()
		if err:=common.Framework.ServiceManager.Register(service); err!=nil {
			log.Printf("fail to register service %s, %s\n", name, err.Error())
		} else {
			log.Printf("success register service %s\n", name)
		}
	}
}
