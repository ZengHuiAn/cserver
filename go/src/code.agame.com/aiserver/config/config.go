package config

import (
	"os"
	"fmt"
	"io/ioutil"
	"log"
	"encoding/xml"

	"database/sql"
	_ "github.com/go-sql-driver/mysql"

	"time"
)

// type
type Server struct {
	Id   int64 `xml:"Id,attr"`;
	Name string `xml:"Name,attr"`;

	Protocol   string
	GMURL      string
	Address    string
	GameDBConnectString string
	AccountDBConnectString string
	LogDBConnectString string

	IsSource bool;
	IsTarget bool;
};

type TargetServer struct {
	Id         int64 `xml:"Id,attr"`;
	GroupIndex int64 `xml:"GroupIndex,attr"`;

	Server     *Server
}
type ServerRoute struct {
	SourceId        int64 `xml:"SourceId"`;
	TargetServers []TargetServer `xml:"TargetServers>TargetServer"`;
}

type XMLConfig struct {
	Version   int64 `xml:"Version,attr"`;
	Protocol  string   `xml:"Protocol"`;
	Address	  string   `xml:"Addr"`;
	LogDir    string   `xml:"LogDir"`;
	LoginCryptoString string   `xml:"LoginCryptoString"`;

	ConfigAutoLoadDB string `xml:'ConfigAutoLoadDB'`;
	ConfigAutoLoadSQL string `xml:'ConfigAutoLoadSQL'`;

	ServerRoutes []*ServerRoute `xml:"ServerRoutes>ServerRoute"`

	AiPidBegin			int32 `xml:"AiPidBegin"`;
	AiPidGroupSize      int32 `xml:"AiPidGroupSize"`;
	VipLevelCopyMax     int32 `xml:"VipLevelCopyMax"`;

	ArmamentPlaceholderMinCopy int32 `xml:"ArmamentPlaceholderMinCopy"`
	ArmamentPlaceholderMaxCopy int32 `xml:"ArmamentPlaceholderMaxCopy"`

	TacticBagIdMinCopy int32 `xml:"TacticBagIdMinCopy"`
	TacticBagIdMaxCopy int32 `xml:"TacticBagIdMaxCopy"`

	AutoAddFriendUpperBound int64 `xml:"AutoAddFriendUpperBound"`
	IdleDuration int64 `xml:"IdleDuration"`

	ServerTable      map[int64]*Server
	ServerRouteTable map[int64][]TargetServer
}

// global var
var Config XMLConfig

// load
func add_server(id int64)*Server {
	server := Config.ServerTable[id]
	if server == nil {
		server = &Server{}
		server.Id                    =id
		server.Protocol              = "tcp"
		server.Address               =fmt.Sprintf("localhost:%d", server.Id)
		server.GMURL                 =fmt.Sprintf("http://localhost:%d", server.Id + 10000)
		server.GameDBConnectString   =fmt.Sprintf("agame:agame@123@tcp(localhost:3306)/aGameMobile_%d", server.Id)
		server.AccountDBConnectString=fmt.Sprintf("agame:agame@123@tcp(localhost:3306)/aGameMobileAccount_%d", server.Id)
		server.LogDBConnectString    =fmt.Sprintf("agame:agame@123@tcp(localhost:3306)/aGameMobileLog_%d", server.Id)
		if server.Id == 101001002 {
			server.Address               =fmt.Sprintf("localhost:7810")
			server.GMURL                 =fmt.Sprintf("http://localhost:7811")
		}
		Config.ServerTable[id] =server
	}
	return server
}
func LoadConfig(path string) {
	log.Printf("cfg path %s", path)
	file, err := os.Open(path);
	if err != nil {
		log.Fatal(err);
	}

	bs, err := ioutil.ReadAll(file);
	if err != nil {
		log.Fatal(err);
	}

	err = xml.Unmarshal(bs, &Config);
	if err != nil {
		log.Fatal(err);
	}

	// server route table
	Config.ServerTable =make(map[int64]*Server);
	Config.ServerRouteTable =make(map[int64][]TargetServer);

	if Config.ConfigAutoLoadDB != "" {
		err = loadAutoConfig();
		if err != nil {
			log.Fatal(err);
		}

		go func() {
			for {
				time.Sleep(1 * time.Minute);
				loadAutoConfig();
			}
		}()
	} else {
		for i:=0; i<len(Config.ServerRoutes); i++ {
			route       :=Config.ServerRoutes[i];
			add_server(route.SourceId)

			target_srvs := route.TargetServers
			for j:=0; j<len(target_srvs); j++ {
				target_srvs[j].Server =add_server(target_srvs[j].Id)
				log.Println(route.SourceId, "->", target_srvs[j].Id);
			}
			Config.ServerRouteTable[route.SourceId] =route.TargetServers;
		}
	}

	log.Printf("Config >>>>>")
	log.Printf("%+v\n", Config)
	for _, v := range(Config.ServerTable) {
		log.Printf("%+v\n", v)
	}

	for id, v := range(Config.ServerRouteTable) {
		log.Printf("copy Server %d to", id);
		for _, s := range(v) {
			log.Printf(" |---> %d as index %d", s.Id, s.GroupIndex);
		}
	}
}

func loadAutoConfig() error {
	var db *sql.DB;
	var err error;

	if db, err = sql.Open("mysql", Config.ConfigAutoLoadDB); err != nil {
		log.Println("Fail to open mysql `%s`, %s", Config.ConfigAutoLoadDB, err.Error)
		return err;
	}
	defer db.Close();

	sql := "select server_id, name, gateway_addr, gm_url, db_addr, 3 from server_config where flag >= 0";
	if Config.ConfigAutoLoadSQL != "" {
		sql = Config.ConfigAutoLoadSQL;
	}

    rows, err := db.Query(sql);
    if err != nil {
		log.Println(err);
		return err;
    }
    defer rows.Close()

	ServerTable      := make(map[int64]*Server);
	ServerRouteTable := make(map[int64][]TargetServer);

    for rows.Next() {
		var id   int64;
		var name string;
		var gw   string;
		var gm   string;
		var dbs  string;
		var ai   int;
		if err := rows.Scan(&id, &name, &gw, &gm, &dbs, &ai); err != nil {
			log.Println(err);
			return err;
		}
		log.Printf("%d %s %s %s %s", id, name, gw, gm, dbs);

		ServerTable[id] = &Server{
			Id:id,
			Protocol:"tcp",
			Address:gw,
			GMURL:gm,
			Name:name,
			GameDBConnectString:fmt.Sprintf("agame:agame@123@tcp(%s:3306)/aGameMobile_%d", dbs, id),
			AccountDBConnectString:fmt.Sprintf("agame:agame@123@tcp(%s:3306)/aGameMobileAccount_%d", dbs, id),
			LogDBConnectString:fmt.Sprintf("agame:agame@123@tcp(%s:3306)/aGameMobileLog_%d", dbs, id),
			IsSource:true,
			IsTarget:true,
		};

		if (ai&1) == 0 {
			ServerTable[id].IsSource = false;
		}

		if (ai&2) == 0 {
			ServerTable[id].IsTarget = false;
		}
    }

	for _, server := range(ServerTable) {
		if !server.IsSource {
			continue;
		}

		targets := make([]TargetServer, 0);

		for i := int64(1); i <= 5; i++ {
			tid := server.Id - i;
			if ts, ok := ServerTable[tid]; ok && ts != nil && ts.IsTarget {
				target := TargetServer {
					Id:tid,
					GroupIndex:i,
					Server:ts,
				}
				targets = append(targets, target);
			}
		}
		ServerRouteTable[server.Id] = targets;
	}

	Config.ServerTable = ServerTable
	Config.ServerRouteTable = ServerRouteTable;

	return nil;
}
