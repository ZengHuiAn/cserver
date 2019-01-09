package payback
import (
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
)

type AccumulateConsumeConfig struct {
	flag          int
	consume_value int
	item_type     int
	item_id       int
	item_value    int
	begin_time    int
	end_time      int
}

func main(){
	var err error
	// load arg
	var srv_id = flag.String("s", 10004, "server id")
	var pid = flag.String("p", 0, "player id")
	flag.Parse()
	if pid == 0 {
		fmt.Printf("player id is 0\n")
		return
	}

	// init db mgr
	var game_db *sql.DB
	game_db_conn_str    :=fmt.Sprintf("agame:agame@123@unix(/data/mysql/3306/mysql.sock)/aGameMobile_%d", srv_id)
	if game_db, err =sql.Open("mysql", game_db_conn_str); err != nil {
		log.Error("Fail to open mysql `%s`, %s", game_db_conn_str, err.Error)
		return false
	}

	// load player data
	var consume, status int64
	err =game_db.QueryRow("SELECT `reward_for_accumulate_consume_gold_activity_consume`,`reward_for_accumulate_consume_gold_activity_consume_status` FROM `accountreward` WHERE `pid`=?", pid).Scan(&consume, &status)
	if err != nil {
		fmt.Printf("Fail to load player data, mysql query error %s\n", err.Error())
		return
	}

	// load config data
	consume_values :=make([]int, 0)
	rows :=game_db.Query("SELECT `consume_value` FROM `accumulate_consume_config` WHERE `flag`=2")
	for rows.Next() {
		var consume_value int
		err = rows.Scan(&consume_value)
		if err != nil {
			fmt.Printf("Fail to load config data, mysql query error %s\n", err.Error())
			return
		}
		consume_values =append(consume_values, consume_value)
	}

	// process
	for i=0; i<len(consume_values); i++ {
		if consume >= consume_values[i] {
			var offset uint64
			offset =i
			state := ((status>>(offset*2))&3)
			if 0 == state {
				fmt.Printf("玩家%d该发 第%d个奖励\n", pid, i)
			}
		}
	}
}
