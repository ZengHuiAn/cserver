package dbmgr

import (
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
	"code.agame.com/aiserver/log"
	"code.agame.com/aiserver/config"
)

// type
type DataMgr struct {
	Id        int64;
	Gamedb    *sql.DB;
	Logdb     *sql.DB;
	Accountdb *sql.DB;
};

// global var
var g_dbmgr_table =make(map[int64]*DataMgr)

func GetDBMgr(server_id int64)*DataMgr{
	if mgr := g_dbmgr_table[server_id]; mgr!=nil {
		return mgr
	}
	if cfg, ok := config.Config.ServerTable[server_id]; ok {
		var err error
		mgr := &DataMgr{ Id : server_id}
		if len(cfg.GameDBConnectString) > 0 {
			if mgr.Gamedb, err =sql.Open("mysql", cfg.GameDBConnectString); err != nil {
				log.Error("Fail to open mysql `%s`, %s", cfg.GameDBConnectString, err.Error)
				return nil
			}
			log.Info("Success to open mysql `%s`", cfg.GameDBConnectString)
		}
		if len(cfg.AccountDBConnectString) > 0 {
			if mgr.Accountdb, err =sql.Open("mysql", cfg.AccountDBConnectString); err!=nil {
				log.Error("Fail to open mysql `%s`, %s", cfg.AccountDBConnectString, err.Error)
				return nil
			}
			log.Info("Success to open mysql `%s`", cfg.AccountDBConnectString)
		}
		if len(cfg.LogDBConnectString) > 0 {
			if mgr.Logdb, err =sql.Open("mysql", cfg.LogDBConnectString); err!=nil {
				log.Error("Fail to open mysql `%s`, %s", cfg.LogDBConnectString, err.Error)
				return nil
			}
			log.Info("Success to open mysql `%s`", cfg.LogDBConnectString)
		}
		g_dbmgr_table[server_id] =mgr
		// begin test
		// end test
		return mgr
	}
	return nil
}

// load
func init(){
/*
	for id, _ := range(config.Config.ServerTable) {
		GetDBMgr(id)
	}
*/
}
