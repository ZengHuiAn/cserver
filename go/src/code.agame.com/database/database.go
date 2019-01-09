package database


import (
	log "code.agame.com/logger"
	"errors"

	"database/sql"
	_ "github.com/go-sql-driver/mysql"

	"code.agame.com/config"
)

type Database struct {
	*sql.DB;

	name string;
};

var dbs = make(map[string] chan*Database);

func makeDB(names ... string) {
	ch := make(chan*Database, 1);

	ch <- &Database{name:names[0]};

	for _, name := range names {
		dbs[name] = ch;
	}
}

func init() {
	makeDB("Account");
	makeDB("Game", "Role");
	makeDB("Log");
}

var ErrNil = errors.New("Invalid database name");

func Get(name string) (*Database, error) {
	ch := dbs[name];
	if ch == nil {
		return nil, ErrNil;
	}
	db := <-ch;
	log.Println("Database::Get", name);

	if db.DB != nil {
		// check connection
		if db.Ping() != nil {
			db.Close();
			db.DB = nil;
		}
	}

	if db.DB == nil {
		log.Println("connect to mysql", name);
		addr := config.GetDBAddr(name);
		conn, err := sql.Open("mysql", addr);
		if err != nil {
			log.Println("mysql", addr, "connect failed", err);
			ch <- db;
			return nil, err;
		}
		log.Println("mysql", addr, "connected");
		db.DB = conn;
	}
	return db, nil;
}

func (db*Database) Release() {
	log.Println("Database::Release", db.name);
	ch  := dbs[db.name];

	if len(ch) >= cap(ch) {
		panic("database release error");
	}
	ch <- db;
}
