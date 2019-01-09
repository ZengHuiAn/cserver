package redeem

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"math/rand"
	"net/http"
	"strconv"
	"sync"
	"time"

	database "code.agame.com/redeem/database"
	gm "code.agame.com/redeem/gm"
)

var lastGenTime int64 = 0

func Gen(w http.ResponseWriter, r *http.Request) {
	now := time.Now()
	if now.Unix() <= lastGenTime {
		log.Println("lastGenTime")
		w.WriteHeader(404)
		return
	}

	if lastGenTime == 0 {
		rand.Seed(now.UnixNano())
	}

	lastGenTime = now.Unix()

	var request struct {
		Count int `json:"count"`
		Type  int `json:"type"`
	}

	err := json.NewDecoder(r.Body).Decode(&request)
	if err != nil {
		log.Println(err)
		w.WriteHeader(404)
		return
	}

	if request.Count > 5000 {
		request.Count = 5000
	}

	prefix := strconv.FormatInt(now.Unix()^957843216, 36)

	min, _ := strconv.ParseInt("100000", 36, 64)
	max, _ := strconv.ParseInt("zzzzzz", 36, 64)
	rang := max - min

	values := make(map[int64]bool)
	for len(values) < request.Count {
		v := (rand.Int63() % rang) + min
		values[v] = true
	}

	// GetManager().AddConfig(cfg.Type, cfg.Name, cfg.Group, cfg.Channel, cfg.Limit, cfg.Content)

	codes := make([]string, 0)
	for k, _ := range values {
		code := prefix + strconv.FormatInt(k, 36)
		codes = append(codes, code)
	}

	n := GetManager().AddCodeN(codes, request.Type)

	w.Header().Add("Content-Type", "text/json")
	bs, _ := json.Marshal(codes[:n])
	w.Write(bs)
}

func New(w http.ResponseWriter, r *http.Request) {
	cfg := &Config{}
	err := json.NewDecoder(r.Body).Decode(cfg)
	if err != nil {
		log.Println(err)
		w.WriteHeader(404)
		return
	}

	err = GetManager().AddConfig(cfg.Type, cfg.Name, cfg.Group, cfg.Channel, cfg.Limit, cfg.Content)
	if err != nil {
		w.WriteHeader(404)
		return
	}
	return
}

type queryReqeust struct {
	Username string `json:"username"`
}

type rewardReqeust struct {
	Username string `json:"username"`

	Reason uint32 `json:"reason"`
	Limit  uint32 `json:"limit,omitempty"`
	Name   string `json:"name,omitempty"`
	Manual bool   `json:"manual,omitempty"`
	Type   string `json:"type"`

	Content []*Content `json:"content"`
}

func Exchange(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()

	if len(query["account"]) == 0 {
		w.WriteHeader(404)
		w.Write([]byte("no account"))
		return
	}

	if len(query["code"]) == 0 {
		w.WriteHeader(404)
		w.Write([]byte("no code"))
		return
	}

	if len(query["sid"]) == 0 {
		w.WriteHeader(404)
		w.Write([]byte("no sid"))
		return
	}

	account := query["account"][0]
	code := query["code"][0]
	sid := query["sid"][0]

	var request queryReqeust
	request.Username = account

	bs, err := gm.Request(sid, "query", &request)
	if err != nil {
		w.WriteHeader(404)
		w.Write([]byte(err.Error()))
		return
	}

	var gmRespond struct {
		Errno int    `json:"errno"`
		Error string `json:"error",omitempty`
	}
	err = json.Unmarshal(bs, &gmRespond)
	if err != nil || gmRespond.Errno != 0 {
		w.WriteHeader(404)
		if err != nil {
			w.Write([]byte(err.Error()))
		} else {
			w.Write(bs)
		}
		return
	}

	rc, err := GetManager().Use(code, account, sid)
	if err != nil {
		w.WriteHeader(404)
		log.Println(err.Error())
		w.Write([]byte(err.Error()))
	} else if rc != nil {
		var request rewardReqeust
		request.Username = account
		request.Reason = 24001
		request.Limit = 0
		request.Name = rc.config.Name
		request.Manual = false
		request.Type = "reward"
		request.Content = rc.config.Content

		bs, err := gm.Request(sid, "reward", &request)
		if err != nil {
			log.Println("send reward to player failed(1)", sid, account, code)
			w.WriteHeader(404)
			return
		}

		err = json.Unmarshal(bs, &gmRespond)
		if err != nil {
			log.Println("send reward to player failed(2)", sid, account, code)
			w.WriteHeader(404)
			return
		}

		if gmRespond.Errno != 0 {
			log.Println("send reward to player failed(3)", sid, account, code)
			w.WriteHeader(404)
			return
		}

		var clientRespond struct {
			Name    string     `json:"name"`
			Content []*Content `json:"content"`
		}

		clientRespond.Name = rc.config.Name
		clientRespond.Content = rc.config.Content

		bs, _ = json.Marshal(clientRespond)

		w.Write(bs)
	} else {
		// gmRespond.Errno = 0
		// gmRespond.Error = "success"
		// bs, _ := json.Marshal(&queryRespond)
		w.Write([]byte("{}"))
	}
}

func List(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()

	if len(query["type"]) == 0 {
		w.WriteHeader(404)
		return
	}

	typo := query["type"][0]

	// read redeem_type
	db := database.Get()
	rows, err := db.Query("select `code`, `account`, `sid` from redeem_code where `type` = ?", typo)
	if err != nil {
		log.Println(err)
		return
	}

	w.Header().Add("Content-Type", "text/json")

	type Info struct {
		Code    string `json:"code"`
		Account string `json:"account"`
		Sid     string `json:"sid"`
	}

	respond := make([]*Info, 0)

	for rows.Next() {
		var code string
		var account string
		var sid string
		if err = rows.Scan(&code, &account, &sid); err != nil {
			log.Println(err)
			break
		}

		respond = append(respond, &Info{Code: code, Account: account, Sid: sid})
	}
	rows.Close()

	bs, _ := json.Marshal(respond)
	w.Write(bs)
}

func Status(w http.ResponseWriter, r *http.Request) {
	GetManager().Status(w)
}

type Group struct {
	id       int
	accounts map[string]*Code
}

type Content struct {
	Type  string `json:"type"`
	ID    uint32 `json:"id"`
	Count uint32 `json:"count"`
}

type Config struct {
	Type    int        `json:"type"`
	Name    string     `json:"name"`
	Group   int        `json:"group"`
	Channel string     `json:"channel"`
	Content []*Content `json:"content"`
	Limit   int64      `json:"limit"`
	used    int
	unused  int
	group   *Group
}

type Code struct {
	sid     string
	account string
	code    string
	time    int64
	config  *Config
}

type Redeem struct {
	groups  map[int]*Group
	configs map[int]*Config
	used    map[string]*Code
	unused  map[string]*Code
	lock    sync.Mutex
}

var instance *Redeem = nil

var inited bool = false

func init() {
	GetManager()
}

func GetManager() *Redeem {
	if instance == nil {
		instance = &Redeem{groups: make(map[int]*Group), configs: make(map[int]*Config), used: make(map[string]*Code), unused: make(map[string]*Code)}
		instance.Load()
	}
	return instance
}

func (r *Redeem) Load() {
	db := database.Get()

	// read redeem_type
	rows, err := db.Query("select `type`, `name`, `group`,  unix_timestamp(`limit`), `channel` from redeem_type")
	if err != nil {
		log.Println(err)
		return
	}

	for rows.Next() {
		var typo int
		var name string
		var group int
		var limit int64
		var channel string
		if err = rows.Scan(&typo, &name, &group, &limit, &channel); err != nil {
			log.Println(err)
			break
		}

		r.AddConfig(typo, name, group, channel, limit, nil)
	}
	rows.Close()

	// read redeem_content
	rows, err = db.Query("select `type`, `rtype`, `rid`, `rvalue` from redeem_content")
	if err != nil {
		log.Println(err)
		return
	}

	for rows.Next() {
		var typo int
		var rtype string
		var rid uint32
		var rvalue uint32

		if err = rows.Scan(&typo, &rtype, &rid, &rvalue); err != nil {
			log.Println(err)
			break
		}

		r.lock.Lock()
		cfg, ok := r.configs[typo]
		if ok {
			cfg.Content = append(cfg.Content, &Content{Type: rtype, ID: rid, Count: rvalue})
		}
		r.lock.Unlock()
	}
	rows.Close()

	// read redeem_code
	rows, err = db.Query("select `code`, `type`, `account`, `sid` from redeem_code")
	if err != nil {
		log.Println(err)
		return
	}

	for rows.Next() {
		var code string
		var typo int
		var account string
		var sid string

		if err = rows.Scan(&code, &typo, &account, &sid); err != nil {
			log.Println(err)
			break
		}
		r.AddCode(code, typo, account, sid)
	}
	rows.Close()

	inited = true
}

func (r *Redeem) AddConfig(typo int, name string, group int, channel string, limit int64, content []*Content) error {
	log.Println("AddConfig", typo, name, group, channel, limit)

	// group < 0 表示存量无限的兑换码
	if group == 9999 {
		group = -typo
	}

	r.lock.Lock()
	defer r.lock.Unlock()

	if _, ok := r.configs[typo]; ok {
		return errors.New("already exists")
	}

	cfg := &Config{Type: typo, Name: name, Group: group, Channel: channel, Limit: limit, Content: make([]*Content, 0)}

	if inited {
		db := database.Get()
		xgroup := group
		if xgroup < 0 {
			xgroup = 9999
		}
		_, err := db.Exec("insert into redeem_type(`type`, `name`, `channel`, `group`, `limit`) values(?, ?, ?, ?, from_unixtime(?))",
			typo, name, channel, xgroup, limit)

		if err != nil {
			log.Println(err)
			return err
		}

		stmt, err := db.Prepare("insert into redeem_content(`type`, `rtype`, `rid`, `rvalue`) values(?, ?, ?, ?)")
		if err != nil {
			log.Println(err)
			return err
		}
		defer stmt.Close()

		for _, c := range content {
			if inited {
				_, err := stmt.Exec(typo, c.Type, c.ID, c.Count)
				if err != nil {
					log.Println(err)
					stmt.Close()
					return err
				}
			}
			cfg.Content = append(cfg.Content, &Content{Type: c.Type, ID: c.ID, Count: c.Count})
		}
	} else {
		for _, c := range content {
			cfg.Content = append(cfg.Content, &Content{Type: c.Type, ID: c.ID, Count: c.Count})
		}
	}

	xgroup, ok := r.groups[group]
	if !ok {
		xgroup = &Group{id: group, accounts: make(map[string]*Code)}
		r.groups[group] = xgroup
	}

	cfg.group = xgroup
	r.configs[typo] = cfg

	return nil
}

func (r *Redeem) AddCodeN(codes []string, typo int) int {
	r.lock.Lock()
	defer r.lock.Unlock()

	cfg, ok := r.configs[typo]
	if !ok {
		return 0
	}

	db := database.Get()
	tx, err := db.Begin()
	if err != nil {
		return 0
	}
	defer tx.Commit()

	stmt, err := tx.Prepare("insert into redeem_code(`code`, `type`, `account`, `sid`) values(?, ?, '', '')")
	if err != nil {
		return 0
	}
	defer stmt.Close()

	var n = 0
	for _, code := range codes {
		log.Println("AddCodeN", code, typo, cfg.group.id, cfg.Name)
		if _, ok := r.unused[code]; ok {
			log.Println(errors.New("code exists"))
			return n
		}

		if cfg.group.id >= 0 {
			if _, ok := r.used[code]; ok {
				log.Println(errors.New("code exists"))
				return n
			}
		}

		if inited {
			_, err := stmt.Exec(code, typo)
			if err != nil {
				log.Println(err)
				return n
			}
		}

		r.unused[code] = &Code{code: code, config: cfg}
		cfg.unused++
		n++
	}

	return n
}

func (r *Redeem) AddCode(code string, typo int, account string, sid string) error {
	r.lock.Lock()
	defer r.lock.Unlock()

	cfg, ok := r.configs[typo]
	if !ok {
		return errors.New("no redeem config")
	}

	if inited {
		if account != "" {
			log.Println("AddCode", code, typo, cfg.group.id, cfg.Name, "<"+account+":"+sid+">")
		} else {
			log.Println("AddCode", code, typo, cfg.group.id, cfg.Name)
		}
	}

	if cfg.group.id >= 0 {
		if _, ok := r.used[code]; ok {
			return errors.New("code exists")
		}

		if _, ok := r.unused[code]; ok {
			return errors.New("code exists")
		}
	} else if account == "" {
		if _, ok := r.unused[code]; ok {
			return errors.New("code exists")
		}
	}

	if account == "" {
		r.unused[code] = &Code{code: code, config: cfg}
		cfg.unused++
	} else {
		if cfg.group.id != 8888 {
			rc := &Code{code: code, config: cfg, account: account, sid: sid, time: time.Now().Unix()}
			r.used[code] = rc
			cfg.group.accounts[account+":"+sid] = rc
		}
		cfg.used++
	}

	if inited {
		db := database.Get()
		_, err := db.Exec("insert into redeem_code(`code`, `type`, `account`, `sid`) values(?, ?, ?, ?)", code, typo, account, sid)
		if err != nil {
			log.Println(err)
			return err
		}
	}

	return nil
}

func (r *Redeem) Use(code string, account string, sid string) (*Code, error) {
	r.lock.Lock()
	defer r.lock.Unlock()

	log.Println("Use code", code, account, sid)

	rc, ok := r.unused[code]
	if !ok {
		rc, ok = r.used[code]
		if ok && rc.account == account && rc.sid == sid {
			return nil, nil
		} else {
			return nil, errors.New("code is not exists or used")
		}
	}

	if rc.config.group.id != 8888 {
		if _, ok := rc.config.group.accounts[account+":"+sid]; ok {
			return nil, errors.New("code of this group is used for this account")
		}
	}

	if rc.config.Limit <= time.Now().Unix() {
		return nil, errors.New("code is expired")
	}

	l := len(rc.config.Channel)
	if l > 0 {
		log.Println("Channel", "["+rc.config.Channel+"]", account)
		if len(account) < l || account[:l] != rc.config.Channel {
			return nil, errors.New("channel not match")
		}
	}

	log.Println("UseCode", code, rc.config.Type, rc.config.group.id, rc.config.Name, "<"+account+":"+sid+">")

	rc.config.used++

	if rc.config.group.id >= 0 {
		rc.config.unused--
		r.used[code] = rc
		rc.account = account
		rc.sid = sid
		delete(r.unused, code)
	}

	if rc.config.group.id != 8888 {
		rc.config.group.accounts[account+":"+sid] = rc
	}

	if inited {
		db := database.Get()
		if rc.config.group.id >= 0 {
			_, err := db.Exec("update redeem_code set account = ?, sid = ? where code = ?", account, sid, code)
			if err != nil {
				log.Println(err)
			}
		} else {
			_, err := db.Exec("insert into redeem_code(`code`, `type`, `account`, `sid`) values(?, ?, ?, ?)", code, rc.config.Type, account, sid)
			if err != nil {
				log.Println(err)
			}
		}
	}

	return rc, nil
}

func (r *Redeem) Status(w io.Writer) {
	type Info struct {
		ID      int    `json:"id"`
		Name    string `json:"name"`
		Group   int    `json:"group"`
		Used    int    `json:"used"`
		Unused  int    `json:"unused"`
		Limit   int64  `json:"limit"`
		Channel string `json:"channel"`
	}

	result := make([]*Info, 0)

	r.lock.Lock()
	for _, cfg := range r.configs {
		group := cfg.Group
		if group < 0 {
			group = 9999
		}
		result = append(result, &Info{ID: cfg.Type, Name: cfg.Name, Group: group, Used: cfg.used, Unused: cfg.unused, Limit: cfg.Limit, Channel: cfg.Channel})
	}
	r.lock.Unlock()

	data, _ := json.Marshal(&result)

	w.Write(data)
}
