package invite

import (
	"encoding/json"
	"io/ioutil"
	"os"
	//	"errors"
	"log"
	// "math/rand"
	"errors"
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

/*
func Update(){
	pool := getInstance()
	for{
		now := time.Now()
		if now.YearDay() != g_card_pool.FreshDay || now.Hour() != g_card_pool.FreshHour {
			pool.Fresh()
		}
		time.Sleep(30 * time.Second);
	}
}
*/

func init() {
	loadConfig()
	loadData()
}

type PlayerInfo struct {
	username string
	tag      bool
}

type ReturnPlayer struct {
	username    string
	reward_time int64
	invitePid   uint32
	inviteSid   string
}

type NewPlayer struct {
	sid string
	pid uint32

	codes []string
}

type RewardContent struct {
	Type  string `json:"type",omitempty`
	ID    uint32 `json:"id",omitempty`
	Count uint32 `json:"count",omitempty`
}

type ActivityConfig struct {
	Begintime int64 `json:"begin_time"`
	Endtime   int64 `json:"end_time"`

	NewServerIDStart int64 `json:"new_server_id_start"`

	RewardReturnName        string          `json:"reward_return_name"`
	RewardReturnContent_new []RewardContent `json:"reward_return_content_new"`
	RewardReturnContent_old []RewardContent `json:"reward_return_content_old"`
	RewardInviteName        string          `json:"reward_invite_name"`
	RewardInviteContent     []RewardContent `json:"reward_invite_content"`
}

type ActivityConfigClient struct {
	Begintime int64 `json:"begin_time"`
	Endtime   int64 `json:"end_time"`

	RewardReturnName    string          `json:"reward_return_name"`
	RewardReturnContent []RewardContent `json:"reward_return_content"`
	RewardInviteName    string          `json:"reward_invite_name"`
	RewardInviteContent []RewardContent `json:"reward_invite_content"`
}

var config *ActivityConfig = &ActivityConfig{
	Begintime: 0,
	Endtime:   0,

	NewServerIDStart: 0,

	RewardReturnName:        "回归奖励",
	RewardReturnContent_new: make([]RewardContent, 0),
	RewardReturnContent_old: make([]RewardContent, 0),

	RewardInviteName:    "邀请奖励",
	RewardInviteContent: make([]RewardContent, 0),
}

var lock sync.Mutex

var playerInfo map[string]*PlayerInfo = map[string]*PlayerInfo{}
var returnPlayer map[string]*ReturnPlayer = map[string]*ReturnPlayer{}
var newPlayer map[uint32]map[string]*NewPlayer = map[uint32]map[string]*NewPlayer{}

func GetPlayerQueryDBInfo(username string) bool {
	//lock.Lock()
	//defer lock.Unlock()
	player, ok := playerInfo[username]
	if !ok {
		player = &PlayerInfo{username: username, tag: false}
	}
	return player.tag
}

func SetPlayerQueryDBInfo(username string, tag bool) {
	lock.Lock()
	defer lock.Unlock()

	if player, ok := playerInfo[username]; !ok {
		player = &PlayerInfo{username: username, tag: tag}
	} else {
		player.tag = tag
	}
}

func GetReturnPlayer(username string) *ReturnPlayer {
	lock.Lock()
	db := database.Get()
	if db == nil {
		lock.Unlock()
		log.Println("loadConfig get db error")
		return nil
	}

	player, ok := returnPlayer[username]

	//判断是否查过数据库
	if queryDBtag := GetPlayerQueryDBInfo(username); queryDBtag {
		log.Println("already query DB")
		lock.Unlock()
		return player
	}
	if ok {
		log.Println("get before loadDB")
		lock.Unlock()
		return player
	}

	lock.Unlock()

	// load from db
	result, ok1 := db.Query("select `award_time`, `isid`, `ipid` from returnplayer_reward where username = ?", username)
	if ok1 != nil {
		log.Println(ok)
		return nil
	}
	defer result.Close()
	for result.Next() {
		var award_time int64
		var isid string
		var ipid uint32
		if err := result.Scan(&award_time, &isid, &ipid); err != nil {
			log.Println(err)
			break
		}
		SetReturnPlayerRewardTime(username, award_time, ipid, isid)
	}
	//设置此用户已经查过数据
	SetPlayerQueryDBInfo(username, true)

	lock.Lock()
	if player, ok := returnPlayer[username]; ok {
		lock.Unlock()
		return player
	}
	returnPlayer[username] = player
	lock.Unlock()

	return player
}

func SetReturnPlayerRewardTime(username string, reward_time int64, ipid uint32, isid string) {
	lock.Lock()
	defer lock.Unlock()

	if player, ok := returnPlayer[username]; ok {
		if reward_time != 0 {
			player.reward_time = reward_time
		}
		player.invitePid = ipid
		player.inviteSid = isid
	} else {
		returnPlayer[username] = &ReturnPlayer{username: username, reward_time: reward_time, invitePid: ipid, inviteSid: isid}
	}
}

func GetNewPlayer(sid string, pid uint32) *NewPlayer {
	lock.Lock()
	defer lock.Unlock()

	if player, ok := newPlayer[pid][sid]; ok {
		return player
	}
	player := &NewPlayer{sid: sid, pid: pid, codes: make([]string, 0)}
	if _, k := newPlayer[pid]; !k {
		newPlayer[pid] = make(map[string]*NewPlayer, 0)
	}
	newPlayer[pid][sid] = player
	return player
}

func AppendNewPlayerCode(sid string, pid uint32, code string) int {
	lock.Lock()
	defer lock.Unlock()
	if player, ok := newPlayer[pid][sid]; ok {
		if len(player.codes) >= 3 {
			return 3
		} else {
			for i := 0; i < len(player.codes); i++ {
				if player.codes[i] == code {
					return 1
				}
			}
		}

		player.codes = append(player.codes, code)
	} else {
		if _, k := newPlayer[pid]; !k {
			newPlayer[pid] = make(map[string]*NewPlayer)
		}
		newPlayer[pid][sid] = &NewPlayer{pid: pid, codes: []string{code}}

	}
	return 0
}

func loadConfig() {
	loadConfigTick()
	go func() {
		for {
			time.Sleep(60 * time.Second)
			loadConfigTick()
		}
	}()
}

func loadConfigTick() {
	log.Println("reload invite config file")
	file, err := os.Open("invite_config.json")
	if err != nil {
		log.Println(err)
		return
	}

	bs, err := ioutil.ReadAll(file)
	if err != nil {
		log.Println(err)
		return
	}

	xconfig := &ActivityConfig{}

	if err := json.Unmarshal(bs, &xconfig); err != nil {
		log.Println(err)
		return
	}

	config = xconfig
}

func loadData() bool {
	fmt.Println("loadConfig ......")
	db := database.Get()
	if db == nil {
		log.Println("loadConfig get db error")
		return false
	}

	result3, ok3 := db.Query("select sid, pid, code from newplayer_invite")
	if ok3 != nil {
		log.Println(ok3)
		return false
	}
	for result3.Next() {
		var sid string
		var pid uint32
		var code string
		if err := result3.Scan(&sid, &pid, &code); err != nil {
			log.Println(err)
			break
		}
		AppendNewPlayerCode(sid, pid, code)
	}
	return true
}

func Reload(w http.ResponseWriter, r *http.Request) {
	log.Println("invite.Reload")

	returnPlayer = map[string]*ReturnPlayer{}
	newPlayer = map[uint32]map[string]*NewPlayer{}
	var respond struct {
		Errno int `json:"errno"`
	}

	respond.Errno = 0
	if ok := loadData(); !ok {
		respond.Errno = 1
	}

	w.Header().Add("Content-Type", "text/json")
	if bs, _ := json.Marshal(respond); bs != nil {
		log.Println(string(bs))
		w.Write(bs)
	} else {
		w.WriteHeader(500)
	}
}

func isReturnPlayer(username string) (bool, error) {

	/*	var request struct {
			Pid uint32 `json:"pid"`
		}

		request.Pid = uint32(pid)
		bs, err := gm.Request(sid, "query_return_info", &request)
		if err != nil {
			log.Println("isPlayer error:", err.Error(), sid, pid)
			return false, errors.New("gm error")
		}

		var gmRespond struct {
			Errno       int    `json:"errno"`
			Error       string `json:"error",omitempty`
			Return7Time int64  `json:"return_7_time",omitempty`
		}

		err = json.Unmarshal(bs, &gmRespond)
		if err != nil || gmRespond.Errno != 0 {
			log.Println("isPlayer Errno != nil", err, sid, pid)
			return false, errors.New("gm error")
		}
		return (gmRespond.Return7Time >= config.Begintime), nil
		//return false, nil;
	*/
	player := GetReturnPlayer(username)
	if player != nil {
		return true, nil
	} else {
		return false, nil
	}
}
func getPlayerUserName(sid string, pid uint32) (string, error) {
	var request struct {
		Pid uint32 `json:"pid"`
	}

	request.Pid = uint32(pid)

	bs, err := gm.Request(sid, "query", &request)
	if err != nil {
		log.Println("getPlayerUserName error:", err.Error(), sid, pid)
		return string(""), errors.New("gm error")
	}

	var gmRespond struct {
		Errno    int    `json:"errno"`
		Error    string `json:"error",omitempty`
		UserName string `json:"username",omitempty`
	}

	err = json.Unmarshal(bs, &gmRespond)
	if err != nil || gmRespond.Errno != 0 {
		log.Println("isPlayer Errno != nil", err, sid, pid)
		return string(""), errors.New("gm error")
	}

	return gmRespond.UserName, nil
}

func Query(w http.ResponseWriter, r *http.Request) {
	log.Println("invite.Query")

	db := database.Get()
	if db == nil {
		log.Println("Query get db error")
		return
	}

	query := r.URL.Query()
	if len(query["pid"]) == 0 || len(query["sid"]) == 0 {
		log.Println("miss quere param")
		w.WriteHeader(403)
		return
	}
	sid := query["sid"][0]
	pid, err := strconv.Atoi(query["pid"][0])
	if err != nil || pid <= 0 {
		log.Println("convert pid failed")
		w.WriteHeader(403)
		return
	}
	sidInterger, err := strconv.ParseInt(sid, 10, 32)
	if err != nil {
		w.WriteHeader(403)
		return
	}

	username, error := getPlayerUserName(sid, uint32(pid))
	if error != nil {
		log.Println("get username failed")
		w.WriteHeader(403)
		return
	}

	log.Printf("player %v query invite info", pid)

	var respond struct {
		Config       ActivityConfigClient `json:"config"`
		ReturnStatus uint32               `json:"return_status",omitempty`
		RewardTime   int64                `json:"reward_time",omitempty`
		InviteCode   []string             `json:"invite_code",omitempty`
	}

	respond.Config.Begintime = config.Begintime
	respond.Config.Endtime = config.Endtime

	respond.Config.RewardReturnName = config.RewardReturnName
	respond.Config.RewardInviteName = config.RewardInviteName
	respond.Config.RewardInviteContent = config.RewardInviteContent

	if sidInterger >= config.NewServerIDStart {
		respond.Config.RewardReturnContent = config.RewardReturnContent_new
	} else {
		respond.Config.RewardReturnContent = config.RewardReturnContent_old
	}

	respond.InviteCode = make([]string, 0)

	status, err := isReturnPlayer(username)
	if err != nil {
		log.Println("query player return info failed")
		w.WriteHeader(500)
		return
	}
	if status {
		respond.ReturnStatus = 1
		player := GetReturnPlayer(username)
		if player != nil && player.reward_time >= config.Begintime {
			respond.RewardTime = player.reward_time
		}
	} else {
		respond.ReturnStatus = 0
		player := GetNewPlayer(sid, uint32(pid))
		if player != nil {
			for _, code := range player.codes {
				respond.InviteCode = append(respond.InviteCode, code)
			}

		}
	}

	w.Header().Add("Content-Type", "text/json")
	if bs, _ := json.Marshal(respond); bs != nil {
		log.Println(string(bs))
		w.Write(bs)
	} else {
		w.WriteHeader(500)
	}
}

/*
func DoInviteList(invitelist []InviteInfo, inviteSid string, invitePid uint32) bool {
	for _, item := range invitelist {
		status, err := isReturnPlayer(item.sid, uint32(item.pid))
		if err != nil {
			log.Println("DoInviteList failed")
			return false
		}
		if !status {
			log.Println("DoInviteList invite is not return")
			return false
		}
		if inviteSid == item.sid && invitePid == item.pid {
			return false
		}
	}
	return true

}
*/

func SendReward(sid string, pid uint32, name string, content []RewardContent) bool {
	log.Println("SendReward", sid, pid, name)
	now := time.Now()

	var request struct {
		//	ServerId string `json:"serverid,omitempty"`;
		Pid    uint32 `json:"pid"`
		Reason uint32 `json:"reason"`
		Limit  uint32 `json:"limit",omitempty`

		RewardContent

		Name   string `json:"name",omitempty`
		Manual bool   `json:"manual",omitempty`

		Content []RewardContent `json:"content",omitempty`
		//		Condition *agame.PAdminRewardRequest_Condition `json:"condition,omitempty"`;
	}
	//request.ServerId = sid;
	request.Pid = pid
	request.Reason = uint32(24001)
	request.Limit = uint32(now.Unix() + 1209600) // 14天 过期
	request.Name = name
	request.Manual = true
	request.Type = "reward"
	request.Content = content

	bs, err := gm.Request(sid, "reward", &request)
	if err != nil {
		log.Println("send reward error:", err)
		return false
	}
	var gmRespond struct {
		Errno int    `json:"errno"`
		Error string `json:"error",omitempty`
	}

	err = json.Unmarshal(bs, &gmRespond)
	if err != nil || gmRespond.Errno != 0 {
		log.Println("SendReward Errno != nil", string(bs), err, sid, pid, name)
		return false
	}
	return true
}
func Invite(w http.ResponseWriter, r *http.Request) {
	now := time.Now().Unix()
	if now < config.Begintime || now > config.Endtime {
		w.WriteHeader(403)
		return
	}

	query := r.URL.Query()
	if len(query["pid"]) == 0 || len(query["sid"]) == 0 || len(query["code"]) == 0 {
		w.WriteHeader(403)
		return
	}
	sid := query["sid"][0]

	pid, err := strconv.Atoi(query["pid"][0])
	if err != nil || pid <= 0 {
		w.WriteHeader(403)
		return
	}
	code := query["code"][0]

	var respond struct {
		Errno uint32 `json:"errno"`
		// Error string `json:"error",omitempty`
	}

	insid, inpid, err := code_to_pid(code)
	if err != nil {
		w.WriteHeader(400)
		return
	}
	inusername, inerror := getPlayerUserName(insid, uint32(inpid))
	if inerror != nil {
		log.Println("get invite username failed")
		w.WriteHeader(403)
		return
	}
	username, error := getPlayerUserName(sid, uint32(pid))
	if error != nil {
		log.Println("get username failed")
		w.WriteHeader(403)
		return
	}

	log.Printf("player %v:%v name:%v invite %v:%v inname:%v ", sid, pid, username, insid, inpid, inusername)

	invitetag := 0
	player := GetReturnPlayer(inusername)
	if player != nil && player.invitePid != 0 {
		invitetag = 1
	}

	istatus, err := isReturnPlayer(inusername)
	if err != nil {
		w.WriteHeader(500)
		return
	}

	if !istatus {
		log.Printf("%v:%v is not return player", insid, inpid)
		respond.Errno = 1
		// respond.Error = "target is not return player"
	} else {
		//判断是否是回归用户
		status, err := isReturnPlayer(username)
		if err != nil {
			w.WriteHeader(500)
			return
		}
		if status {
			respond.Errno = 2
			log.Printf("%v:%v is return player", sid, pid)
			// respond.Error = "is ReturnPlayer"
		} else {
			ret := AppendNewPlayerCode(sid, uint32(pid), code)
			if ret == 3 {
				log.Printf("%v:%v invite list is full", sid, pid)
				respond.Errno = 3
			} else if ret == 1 || invitetag == 1 {
				log.Printf("%v:%v is already in invite list", insid, inpid)
				respond.Errno = 4
			} else {
				_, err := database.Get().Exec("insert into newplayer_invite(`sid`, `pid`, `code`) values(?, ?, ?)", sid, pid, code)
				if err != nil {
					log.Println("insert newplayer_invite fail", err, pid)
					w.WriteHeader(500)
					return
				}
				_, err1 := database.Get().Exec("replace into returnplayer_reward(`username`, `award_time`, `ipid`, `isid`) values(?, ?, ?, ?)", inusername, player.reward_time, pid, sid)
				if err1 != nil {
					log.Println("set returnplayer invitepid failed", err)
					w.WriteHeader(500)
					return
				}
				SetReturnPlayerRewardTime(inusername, 0, uint32(pid), sid)
				respond.Errno = 0
				SendReward(sid, uint32(pid), config.RewardInviteName, config.RewardInviteContent)
			}
		}
	}

	w.Header().Add("Content-Type", "text/json")
	if bs, _ := json.Marshal(respond); bs != nil {
		w.Write(bs)
	} else {
		w.WriteHeader(403)
	}
}

func Reward(w http.ResponseWriter, r *http.Request) {
	now := time.Now().Unix()
	if now < config.Begintime || now > config.Endtime {
		w.WriteHeader(403)
		return
	}

	query := r.URL.Query()
	if len(query["pid"]) == 0 || len(query["sid"]) == 0 {
		w.WriteHeader(403)
		return
	}
	sid := query["sid"][0]

	pid, err := strconv.Atoi(query["pid"][0])
	if err != nil || pid <= 0 {
		w.WriteHeader(403)
		return
	}

	username, error := getPlayerUserName(sid, uint32(pid))
	if error != nil {
		log.Println("get username failed")
		w.WriteHeader(403)
		return
	}

	log.Println("player %v:%v try to get return reward", sid, pid)

	var respond struct {
		Errno uint32 `json:"errno"`
	}
	//判断是否是回归用户
	status, err := isReturnPlayer(username)
	if err != nil {
		w.WriteHeader(500)
		return
	}

	sidInterger, err := strconv.ParseInt(sid, 10, 32)
	if err != nil {
		w.WriteHeader(403)
		return
	}

	if status {
		player := GetReturnPlayer(username)
		if player != nil && player.reward_time >= config.Begintime {
			log.Printf("player %v:%v already get return reward", sid, pid)
			respond.Errno = 0
		} else {
			var ipid uint32
			var isid string
			if player != nil {
				ipid = player.invitePid
				isid = player.inviteSid
			} else {
				ipid = 0
				isid = "0"
			}
			_, err := database.Get().Exec("replace into returnplayer_reward(`username`, `award_time`, `ipid`, `isid`) values(?, ?, ?, ?)", username, now, ipid, isid)
			if err != nil {
				log.Println("set player reward time failed", err)
				w.WriteHeader(500)
				return
			}
			respond.Errno = 0

			SetReturnPlayerRewardTime(username, now, player.invitePid, player.inviteSid)

			if sidInterger >= config.NewServerIDStart {
				SendReward(sid, uint32(pid), config.RewardReturnName, config.RewardReturnContent_new)
			} else {
				SendReward(sid, uint32(pid), config.RewardReturnName, config.RewardReturnContent_old)
			}
		}
	} else {
		respond.Errno = 2
		// respond.Error = "Reward error not ReturnPlayer"
	}

	w.Header().Add("Content-Type", "text/json")
	if bs, _ := json.Marshal(respond); bs != nil {
		w.Write(bs)
	} else {
		w.WriteHeader(403)
	}

}
