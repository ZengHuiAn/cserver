package redeem

import (
	"log"
	"os"
	"sync"

	"database/sql"
	_ "github.com/go-sql-driver/mysql"
)

var xdb *sql.DB
var lock sync.Mutex

/*
func init () {
	GetConnection();
}
*/

func Get() *sql.DB {
	lock.Lock()
	defer lock.Unlock()

	var err error

	if xdb != nil {
		if err := xdb.Ping(); err != nil {
			log.Println(err)
		} else {
			return xdb
		}
	}

	addr := os.Getenv("AGAME_DATABASE_URL")
	if addr == "" {
		addr = "agame:agame@123@tcp(localhost:3306)/aGameMobile?charset=utf8"
	}

	xdb, err = sql.Open("mysql", addr)
	if xdb == nil {
		log.Println(err)
		return nil
	}

	// check connection
	if err := xdb.Ping(); err != nil {
		log.Println(err)
		xdb.Close()
		xdb = nil
	}

	return xdb
}

/*
func Exec(query string, args ...interface{}) (sql.Result, error) {
	db := get()
	if db != nil {
		:= db.Exec(query, args)
		if err != nil {
			log.Println(err)
		} else {
			return result
		}
	}
	return nil
}

func Query(query string, args ...interface{}) *sql.Rows {
	db := get()
	if db != nil {
		rows, err := db.Query(query, args)
		if err != nil {
			log.Println(err)
		} else {
			return rows
		}
	}
	return nil
}

func Prepare(query string) *sql.Stmt {
	db := get()
	if db != nil {
		stmt, err := db.Prepare(query)
		if err != nil {
			log.Println(err)
		} else {
			return stmt
		}
	}
	return nil
}
*/
