package gift

import (
	"encoding/json"
	//	"errors"
	"log"
	"math/rand"
	"fmt"
	"net/http"
	"strconv"
	"sync"
	"time"

	database "code.agame.com/redeem/database"
	gm "code.agame.com/redeem/gm"
)

//=======================type===============================
const timeLayout = "2006-01-02 15:04:05"
type Card struct {
	Code     string `json:"code"`
	Password string `json:"password"`
	Value    int `json:"value"`
	Type     int `json:"type"`
	Account  string
	Sid      string
}

type CardGroup struct {
	Used        []*Card
	Unuse       []*Card
	Type        int
	Value       int
	Cost        int
	UnuseCount  int
	UsedCount   int
	InSell      int
	FakeInSell  int
	InProcess   uint32
	lock        sync.Mutex
}

type StoreRespond struct {
	Type    int `json:"type"`
	Value   int `json:"value"`
	FakeInSell int `json:"in_sell"`
	Cost       int `json:"cost"`
}

type UseRespond struct{
	Errno    int    `json:"errno"`
	Code     string `json:"code"`
	Password string `json:"password"`
}

type CardPool struct {
	FreshDay  int
	FreshHour int
	Group     map[int]*CardGroup
}

//==========================var========================
var g_card_pool *CardPool
var g_card_pool_lock sync.Mutex

var lastImportTime int64 = 0
var g_sell_config map[string]int
var g_cost_config map[int]int
var g_access_time map[string]int64 = make(map[string]int64, 0)

//=========================func=======================
func getGroupIdx(card_type int, card_value int) int {
	return (card_type*100000 + card_value)
}

func getCost(card_type int, card_value int) int {
	t_idx := getGroupIdx(card_type, card_value)
	if v, ok := g_cost_config[t_idx]; ok {
		return v
	}
	return 9999999
}
func getConfigIdx(card_type int, card_value int, fresh_hour int) string {
	t_idx := fmt.Sprintf("%d:%d:%d", card_type,card_value,fresh_hour)
	return t_idx
}

func getConfigInSell(card_type int, card_value int, fresh_hour int) int {
	t_idx := getConfigIdx(card_type,card_value,fresh_hour)
	if v, ok := g_sell_config[t_idx]; ok {
		return v
	}
	return 0
}

func getInstance() *CardPool {
	if g_card_pool == nil {
		if !loadCard() {
			return nil
		}
	}
	return g_card_pool
}

func Update(){
	pool := getInstance()
	for{
		now := time.Now()
		if g_card_pool != nil && ( now.YearDay() != g_card_pool.FreshDay || now.Hour() != g_card_pool.FreshHour ) {
			pool.Fresh()
		}
		time.Sleep(30 * time.Second);
	}
}

func init(){
	getInstance()
	go Update()
}

func runWithLock(lock *sync.Mutex, action func() bool) bool {
	lock.Lock();
	defer lock.Unlock();
	return action();
}

func (pool *CardPool) Fresh() {
	db := database.Get()
	if db == nil {
		log.Println("CardPool fresh fail, get db error")
		return
	}
	now := time.Now()
	t_day  := now.YearDay()
	t_hour := now.Hour()
	log.Println("card pool fresh", "before", pool.FreshDay, pool.FreshHour, "after", t_day, t_hour)
	pool.FreshDay  = t_day
	pool.FreshHour = t_hour
	for _, v := range pool.Group {
		v.Fresh()
	}
}

func (group *CardGroup) AddCode(sid, account, card_code, card_password string, card_type, card_value int) {
	group.lock.Lock()
	log.Println("AddCode", card_type, card_value, "code", card_code, "sid", sid, "account", account)
	if account == "" {
		group.Unuse = append(group.Unuse, &Card{Code: card_code, Password: card_password, Value: card_value, Type: card_type })
		group.UnuseCount += 1
	} else {
		group.Used = append(group.Used, &Card{Code: card_code, Password: card_password, Value: card_value, Type: card_type,
			Account: account, Sid: sid})
		group.UsedCount += 1
	}
	group.lock.Unlock()
}

func (group *CardGroup) Fresh() bool{
	db := database.Get()
	if db == nil {
		log.Println("Fresh CardGroup get db error")
		return false
	}
	now := time.Now()
	t_in_sell := getConfigInSell(group.Type, group.Value, now.Hour())
	if t_in_sell == 0 {
		//db.Exec(`update gift_card_info set fresh_day = ?, fresh_hour = ?  where card_type = ? and card_value = ?`, now.YearDay(), now.Hour(), group.Type, group.Value)
		log.Println("CardGroup Fresh", "type", group.Type, "value", group.Value, "sell_config is 0")
		return false
	}
	group.lock.Lock()
	defer group.lock.Unlock()
	if t_in_sell > group.UnuseCount {
		t_in_sell = group.UnuseCount
	}
	t_fake_in_sell := t_in_sell * 10
	_, err := db.Exec(`update gift_card_info set in_sell = ?, fake_in_sell = ?, fresh_day = ?, fresh_hour = ? 
	where card_type = ? and card_value = ?`, t_in_sell, t_fake_in_sell, now.YearDay(), now.Hour(), group.Type, group.Value)
	if err != nil {
		log.Println("Fresh CardGroup err", err)
		return false
	}
	group.InSell = t_in_sell
	group.FakeInSell = t_fake_in_sell
	group.InProcess  = 0
	return true
}

func loadConfig() bool {
	db := database.Get()
	if db == nil {
		log.Println("loadConfig get db error")
		return false
	}
	result, ok := db.Query("select `card_type`, `card_value`, `in_sell`, `fresh_hour` from gift_card_time")
	if ok != nil {
		log.Println(ok)
		return false
	}
	defer result.Close()
	g_sell_config = make(map[string]int, 0)
	for result.Next() {
		var card_type int
		var card_value int
		var fresh_hour int
		var fresh_count int
		if err := result.Scan(&card_type, &card_value, &fresh_count, &fresh_hour); err != nil {
			log.Println(err)
			break
		}
		t_idx := getConfigIdx(card_type, card_value, fresh_hour)
		g_sell_config[t_idx] = fresh_count
	}

	result, ok = db.Query("select card_type, card_value, card_cost from gift_card_config")
	if ok != nil {
		log.Println(ok)
		return false
	}
	defer result.Close()
	g_cost_config = make(map[int]int, 0)
	for result.Next() {
		var card_type int
		var card_value int
		var card_cost  int
		if err := result.Scan(&card_type, &card_value, &card_cost); err != nil {
			log.Println(err)
			break
		}
		t_idx := getGroupIdx(card_type, card_value)
		g_cost_config[t_idx] = card_cost
	}
	return true
}

func genGroup(card_type, card_value int) *CardGroup {
	now := time.Now()
	day := now.YearDay()
	hour:= now.Hour()
	db := database.Get()
	t_in_sell := getConfigInSell(card_type, card_value, hour)
	//当发现需要销售
	t_group   := &CardGroup{Unuse: make([]*Card, 0), Used: make([]*Card, 0), Cost:getCost(card_type, card_value), Type: card_type, Value: card_value, UnuseCount: 0, UsedCount: 0, InSell: t_in_sell, FakeInSell: t_in_sell*10, InProcess:0}
	if db != nil{
		_, err := db.Exec("insert into gift_card_info(`card_type`, `card_value`, `in_sell`,`fake_in_sell`, `fresh_day`, `fresh_hour`) values(?, ?, ?, ?, ? , ?)", 
		card_type, card_value, t_in_sell, t_in_sell*10, day, hour)
		if err!=nil {
			log.Println("insert gift_card_info fail", err, card_type, card_value, hour, getConfigInSell(card_type, card_value, hour))
		}
	}
	return t_group
}

func loadCard() bool {
	now    := time.Now()
	cur_day  := now.YearDay()
	cur_hour := now.Hour()
	t_card_pool := &CardPool{Group: make(map[int]*CardGroup, 0), FreshHour: cur_hour, FreshDay: cur_day}

	if !loadConfig() {
		return false
	}
	db := database.Get()
	if db == nil {
		log.Println("loadCard get db error")
		return false
	}

	//先导入库存信息
	result, ok := db.Query("select `fresh_day`, `fresh_hour`, `card_value`, `card_type`, `in_sell`, `fake_in_sell` from gift_card_info")
	if ok != nil {
		log.Println(ok)
		return false
	}
	defer result.Close()

	for result.Next() {
		var fresh_day int
		var fresh_hour int
		var card_value int
		var card_type int
		var in_sell int
		var fake_in_sell int
		if err := result.Scan(&fresh_day, &fresh_hour, &card_value, &card_type, &in_sell, &fake_in_sell); err != nil {
			break
		}
		t_idx := getGroupIdx(card_type, card_value)
		t_card_pool.Group[t_idx] = &CardGroup{
										Unuse: make([]*Card, 0), Used: make([]*Card, 0), Type: card_type, 
										Value: card_value, UnuseCount: 0, UsedCount: 0, Cost:getCost(card_type, card_value),
										InSell: in_sell, FakeInSell:fake_in_sell,InProcess:0,
									}
		log.Println("loadCard", "cur_day", cur_day, "fresh_day", fresh_day, "cur_hour", cur_hour, "fresh_hour", fresh_hour, "card_type",
		card_type, "card_value",card_value, "in_sell", in_sell, "fake_in_sell", fake_in_sell)
		if fresh_day != cur_day || fresh_hour != cur_hour {
			t_card_pool.Group[t_idx].Fresh()
		}
	}
	//导入库中的礼品卡
	row, err := db.Query("select `code`, `password`, `type`, `value`, `account`, `sid` from gift_card")
	if err != nil {
		log.Println(err)
		return false
	}
	defer row.Close()

	for row.Next() {
		var card_code string
		var card_password string
		var card_type int
		var card_value int
		var account string
		var sid string

		if err = row.Scan(&card_code, &card_password, &card_type, &card_value, &account, &sid); err != nil {
			log.Println(err)
			break
		}
		t_idx := getGroupIdx(card_type, card_value)
		//发现不存在的卡片种类
		if t_card_pool.Group[t_idx] == nil {
			t_card_pool.Group[t_idx] = genGroup(card_type, card_value)
		}
		t_card_pool.Group[t_idx].AddCode(sid, account, card_code, card_password, card_type, card_value)
	}
	g_card_pool = t_card_pool
	return true
}

func Import(w http.ResponseWriter, r *http.Request) {
	instance := getInstance()
	if instance == nil {
		log.Println("Import Fail to get instance")
		w.WriteHeader(404)
		return
	}
	now := time.Now()
	if now.Unix() <= lastImportTime {
		log.Println("lastImportTime")
		w.WriteHeader(404)
		return
	}

	lastImportTime = now.Unix()
	var request struct {
		CardList []Card `json:"card_list"`
	}

	err := json.NewDecoder(r.Body).Decode(&request)
	log.Println(request)
	if err != nil {
		log.Println(err)
		w.WriteHeader(404)
		return
	}

	db := database.Get()
	tx, err := db.Begin()
	if err != nil {
		log.Println(err)
		w.WriteHeader(404)
		return
	}
	defer tx.Commit()

	stmt, err := tx.Prepare("insert into gift_card(`code`, `password`, `type`, `value`, `account`, `sid`) values(?, ?, ?, ?, '', '')")
	if err != nil {
		log.Println(err)
		w.WriteHeader(404)
		return
	}

	defer stmt.Close()
	for i := 0; i < len(request.CardList); i++ {
		t_card := request.CardList[i]
		log.Printf("Import Card %s %s %d %d\n", t_card.Code, t_card.Password, t_card.Type, t_card.Value)
		_, err := stmt.Exec(t_card.Code, t_card.Password, t_card.Type, t_card.Value)
		if err != nil {
			log.Println(err)
			w.WriteHeader(404)
			w.Write([]byte(fmt.Sprintf("Import %v error, %v", t_card.Code, err)))
			return
		}

		t_idx := getGroupIdx(t_card.Type, t_card.Value)
		if instance.Group[t_idx] == nil {
			instance.Group[t_idx] = genGroup(t_card.Type, t_card.Value)
			log.Println("[NEW] Import Card , new group",  t_card.Code, t_card.Password, t_card.Type, t_card.Value)
		}
		instance.Group[t_idx].AddCode("", "", t_card.Code, t_card.Password, t_card.Type, t_card.Value)
	}

	w.WriteHeader(200)
	return
}

func isPlayer(sid string, account string) bool {
	var request struct {
		Username string `json:"username"`
	}
	request.Username = account

	bs, err := gm.Request(sid, "query", &request)
	if err != nil {
		log.Println("isPlayer error:", err.Error(), sid, account)
		return false
	}

	var gmRespond struct {
		Errno int    `json:"errno"`
		Error string `json:"error",omitempty`
	}
	err = json.Unmarshal(bs, &gmRespond)
	if err != nil || gmRespond.Errno != 0 {
		log.Println("isPlayer Errno != nil", sid, account)
		return false
	}
	return true
}

func (group *CardGroup)Consume(sid, account string, card *Card) bool {
	type TypeIdValue struct {
		Type  int `json:"type"`
		Id    int `json:"id"`
		Value int `json:"value"`
	}
	var request struct {
		Username string        `json:"username"`
		Reason   int        `json:"reason"`
		Consume  []TypeIdValue `json:"consumes,omitempty"`
	}
	request.Username = account
	request.Reason = 50120
	request.Consume = make([]TypeIdValue, 1)
	request.Consume[0].Type = 90
	request.Consume[0].Id = 24
	request.Consume[0].Value = group.Cost

	bs, err := gm.Request(sid, "punish", &request)
	if err != nil {
		log.Println("send punish to player failed(1)", sid, account, card.Code, err)
		return false
	}

	var gmRespond struct {
		Errno int    `json:"errno"`
		Error string `json:"error",omitempty`
	}
	err = json.Unmarshal(bs, &gmRespond)
	if err != nil {
		log.Println("send punish to player failed(2)", sid, account, card.Code, err)
		return false
	}

	if gmRespond.Errno != 0 {
		log.Println("send punish to player failed(3)", sid, account, card.Code)
		return false
	}
	log.Printf("[CONSUME CHECK] sid %s, player %s, type %v, value %v, consume %v for code %s \n", sid, account, card.Type, card.Value, group.Cost, card.Code)
	return true
}

func sendCard(sid, account string, card *Card) bool {
	var request struct {
		Username string `json:"username"`
		Title    string `json:"title"`
		Content  string `json:"content"`
	}
	request.Username = account
	request.Title    = "京东卡兑换"
	t_msg_time       := time.Now().Format(timeLayout)
	request.Content  = fmt.Sprintf("于%s在暴走商城中获得京东卡一张,兑换码为%s,请及时使用切勿泄露兑换码.\n", t_msg_time, card.Code)

	bs, err := gm.Request(sid, "sendmail", &request)
	if err != nil {
		log.Println("sendmail to player failed(1)", sid, account, card.Code)
		return false
	}

	var gmRespond struct {
		Errno int    `json:"errno"`
		Error string `json:"error",omitempty`
	}
	err = json.Unmarshal(bs, &gmRespond)
	if err != nil {
		log.Println("sendmail to player failed(2)", sid, account, card.Code)
		return false
	}

	if gmRespond.Errno != 0 {
		log.Println("sendmail to player failed(3)", sid, account, card.Code)
		return false
	}
	return true
}

func Min(a, b int) int{
	if a > b {
		return b
	}
	return a
}

func isTimeLimit(account string) bool{
	t_time := time.Now().Unix()
	if v, ok := g_access_time[account]; ok {
		if t_time - v > 1 {
			g_access_time[account] = t_time
			return false
		}
		return true
	}
	g_access_time[account] = t_time
	return false
}


func Use(w http.ResponseWriter, r *http.Request) {
	instance := getInstance()
	if instance == nil {
		log.Println("Use Error to get instance")
		w.WriteHeader(404)
		return
	}
	query := r.URL.Query()
	if len(query["account"]) == 0 || len(query["sid"]) == 0 {
		w.WriteHeader(404)
		return
	}
	if len(query["card_type"]) == 0 || len(query["card_value"]) == 0 {
		w.WriteHeader(404)
		return
	}
	card_type, err := strconv.Atoi(query["card_type"][0])
	if err != nil || card_type < 0 {
		w.WriteHeader(404)
		return
	}
	card_value, err := strconv.Atoi(query["card_value"][0])
	if err != nil || card_value < 0 {
		w.WriteHeader(404)
		return
	}
	log.Println("[CONSUME PREPARE] sid", query["sid"][0], "account", query["account"][0], "card_type", card_type, "card_value", card_value)
	t_group_idx := getGroupIdx(card_type, card_value)
	t_group := instance.Group[t_group_idx]
	if t_group == nil {
		log.Printf("Use fail, incorrect index %v %v\n", card_type, card_value)
		w.WriteHeader(404)
		return
	}

	sid := query["sid"][0]
	account := query["account"][0]
	if isTimeLimit(account){
		log.Printf("[CONSUME FAIL] sid %v account %v, time limit\n", sid, account)
		w.WriteHeader(404)
		return
	}
	if !isPlayer(sid, account) {
		log.Printf("[CONSUME FAIL] sid %v account %v, query player fail\n", sid, account)
		w.WriteHeader(404)
		return
	}

	var t_unuse_len int;
	var t_card *Card;
	if !runWithLock(&t_group.lock, func() bool {
		log.Println("[CONSUME WAIT] sid", query["sid"][0], "account", query["account"][0], "in_process", t_group.InProcess, "in_sell", t_group.InSell)
		if t_group.InSell <= 0{
			var resp = UseRespond {
				Errno:1,
			}
			if bs, _ := json.Marshal(resp); bs != nil {
				w.Write(bs)
			}
			log.Printf("Use fail, no more in_sell\n");
			return false
		}
		t_unuse_len = t_group.UnuseCount
		if t_unuse_len <= 0 {
			log.Printf("Use fail, no more card %v %v\n", card_type, card_value)
			w.WriteHeader(401)
			return false
		}
		if int(t_group.InProcess) >= t_group.InSell {
			log.Printf("Use fail, InProcess %d >= InSell %d", t_group.InProcess, t_group.InSell)
			w.WriteHeader(418)
			return false
		}
		t_card        = t_group.Unuse[t_unuse_len-1]
		t_group.Unuse = t_group.Unuse[:t_unuse_len-1]
		t_group.UnuseCount -= 1
		t_group.InProcess  += 1
		return true
	}){
		return
	}

	if ok := t_group.Consume(sid, account, t_card); !ok {
		if !runWithLock(&t_group.lock, func() bool{
			if t_group.InProcess > 0 {
				t_group.InProcess -= 1
			}
			t_group.Unuse      = append(t_group.Unuse, t_card)
			t_group.UnuseCount = t_group.UnuseCount + 1
			return true
		}){
			return
		}
		var resp = UseRespond {
			Errno:2,
		}
		if bs, _ := json.Marshal(resp); bs != nil {
			w.Write(bs)
		}
		log.Println("Use Fail, Consume fail", sid, account)
		return
	}

	db := database.Get()
	var t_cost int
	runWithLock(&t_group.lock, func() bool{
		t_cost = t_group.Cost
		t_group.Used = append(t_group.Used, t_card)
		t_group.UsedCount += 1
		t_group.InSell    -= 1
		if t_group.InProcess > 0 {
			t_group.InProcess -= 1
		}
		if t_group.InSell > 0 {
			t_in_sell := t_group.InSell * 10 - int(rand.Intn(10))
			t_group.FakeInSell = Min(t_group.FakeInSell, t_in_sell)
		}else{
			t_group.FakeInSell = 0
		}
		_, err = db.Exec(`update gift_card_info set in_sell = ?, fake_in_sell = ?  where card_type = ? and card_value = ?`, t_group.InSell, t_group.FakeInSell, card_type, card_value)
		if err != nil {
			log.Println("update gift_card_info set error, err = ", err, "in_sell", t_group.InSell, "fake_in_sell", t_group.FakeInSell)
		}
		return true
	})

	_, err = db.Exec("update gift_card set account = ?, sid = ?, status = 1 where code = ?", account, sid, t_card.Code)
	if err != nil {
		log.Printf("[CONSUME RECORD STEP 1]database update error %s; account %s, sid %s, Code %s, Cost %v\n", err, account, sid, t_card.Code, t_cost)
		w.WriteHeader(404)
		return
	}

	if ok := sendCard(sid, account, t_card); ok {
		_, err = db.Exec("update gift_card set status = 2 where code = ?", t_card.Code)
		if err != nil {
			log.Printf("[CONSUME RECORD STEP 2]database update error %s; account %s, sid %s, Code %s, Cost %v\n", err, account, sid, t_card.Code, t_cost)
			return
		}
		log.Printf("[CONSUME SEND] account %v sid %v Code %v", account, sid, t_card.Code)
	}
	var resp = UseRespond {
		Code:t_card.Code,
		Password:t_card.Password,
	}
	if bs, _ := json.Marshal(resp); bs != nil {
		w.Write(bs)
	}
	return
}

func List(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()

	if len(query["type"]) == 0 {
		w.WriteHeader(404)
		return
	}

	card_type := query["type"][0]

	db := database.Get()
	rows, err := db.Query("select `code`, `account`, `sid` from gift_card where `type` = ?", card_type)
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

func Store(w http.ResponseWriter, r *http.Request) {
	resp := make([]StoreRespond, 0)
	instance := getInstance()
	if instance == nil {
		log.Println("Store fail to get instance")
		w.WriteHeader(404)
		return
	}
	for i := 1; i <= 10; i++ {
		t_idx := getGroupIdx(i, 100)
		t_group := instance.Group[t_idx]
		if t_group != nil {
			resp = append(resp, StoreRespond{Type: i, Value: 100, Cost:t_group.Cost, FakeInSell: t_group.FakeInSell})
		}
	}
	w.Header().Add("Content-Type", "text/json")
	if bs, _ := json.Marshal(resp); bs != nil {
		w.Write(bs)
	} else {
		w.WriteHeader(404)
	}
}
