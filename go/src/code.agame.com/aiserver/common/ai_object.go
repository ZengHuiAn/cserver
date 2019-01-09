package common
import(
	"sync"
	"fmt"
	"math/rand"
	"errors"
	"crypto/md5"
	"database/sql"
	// "strings"
	"code.agame.com/aiserver/log"
	"code.agame.com/aiserver/dbmgr"
	"code.agame.com/aiserver/gmserver"
	"code.agame.com/aiserver/config"
)

// error
var(
	ErrAINotOnline = errors.New("AI Not Online")
	ErrAIOnline    = errors.New("AI Online Already")
)

//state
const(
	ST_REGISTERING =iota //正在注册
	ST_LOGINING          //正在登陆
	ST_ONLINE            //在线
	ST_OFFLINE           //离线
)

// AIObject
type AIObject struct {
	Pid uint32
	Name string
	ServerId int64
	state int
	is_active  bool // true -> 可以执行行为(打怪，收集资源等), 否则不可以
	send_buffer *SendBuffer
	sn uint32
	locker sync.Mutex
	gamedb *sql.DB
	data map[uint32]interface{}

	FromServerId int64
	FromPid uint32
}
func LoadGameDB(server_id int64)*sql.DB{
	mgr   := dbmgr.GetDBMgr(server_id)
	if mgr == nil {
		log.Error("Fail to LoadGameDB(%d), mysql dbmgr not exist", server_id)
		return nil
	}
	gamedb := mgr.Gamedb
	if gamedb == nil {
		log.Error("Fail to LoadGameDB(%d), mysql gamedb not exist", server_id)
		return nil
	}
	return gamedb
}
func NewAIObject(pid uint32, server_id int64, send_buffer *SendBuffer, from_pid uint32, from_server_id int64)*AIObject{
	// load data from db
	gamedb := LoadGameDB(server_id)
	if nil == gamedb {
		return nil
	}

	// new
	return &AIObject{
		Pid : pid,
		ServerId : server_id,
		state : ST_OFFLINE,
		send_buffer : send_buffer,
		data   : make(map[uint32]interface{}),
		gamedb : gamedb,
		is_active : true,
		FromServerId : from_server_id,
		FromPid : from_pid,
	}
}
func (this *AIObject)SetData(sn uint32, data interface{}){
	this.locker.Lock()
	defer this.locker.Unlock()
	this.data[sn] =data
}
func (this *AIObject)GetData(sn uint32)interface{}{
	this.locker.Lock()
	defer this.locker.Unlock()
	dt :=this.data[sn]
	delete(this.data, sn)
	return dt
}
func (this *AIObject)NextSn()uint32{
	this.locker.Lock()
	defer this.locker.Unlock()
	this.sn +=1
	return this.sn
}
// state
func (this *AIObject)ChangeState(st int)int{
	this.locker.Lock()
	defer this.locker.Unlock()
	old_st := this.state
	this.state =st
	return old_st
}

func (this *AIObject)IsRegistering()bool {
	this.locker.Lock()
	defer this.locker.Unlock()
	return this.state == ST_REGISTERING
}

func (this *AIObject)IsLoging()bool {
	this.locker.Lock()
	defer this.locker.Unlock()
	return this.state == ST_LOGINING
}

func (this *AIObject)IsOnline()bool {
	this.locker.Lock()
	defer this.locker.Unlock()
	return this.state == ST_ONLINE
}

func (this *AIObject)IsOffline()bool {
	this.locker.Lock()
	defer this.locker.Unlock()
	return this.state == ST_OFFLINE
}

// active
func (this *AIObject)IsActive()bool{
	return this.is_active
}

// action 
func (this *AIObject)Login()error{
	if this.IsOnline() {
		return ErrAIOnline
	}
	this.ChangeState(ST_LOGINING)
	//// prepare
	/* 
		signature := md5sum(rand_num, pid, CryptoString)
		account   := [pid@ai]
		token     := [rand_num:pid:signature]
	*/
	// [sn, "account", "token", version]
	rand_num  := rand.Int()
	check_sum := md5.New()
	fmt.Fprintf(check_sum, "%d%d%s", rand_num, this.Pid, config.Config.LoginCryptoString)
	signature := fmt.Sprintf("%x", check_sum.Sum(nil))
	log.Debug("signature =%s", signature)

	sn := this.NextSn()
	account := fmt.Sprintf("%d@ai", this.Pid)
	token := fmt.Sprintf("%d:%d:%s", rand_num, this.Pid, signature)
	header  := MakeAmfHeader(this.Pid, sn, C_LOGIN_REQUEST)
	request := []interface{}{ sn, account, token, config.Config.Version }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to Login(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` Login", this.Pid)
		return nil
	}
}

func (this *AIObject)Logout()error{
	if false == this.IsOnline() {
		return ErrAINotOnline
	}
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_LOGOUT_REQUEST)
	request := []interface{}{ 0 }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to Logout(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` Logout", this.Pid)
		return nil
	}
}

func (this *AIObject)QueryPlayerInfo()error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_QUERY_PLAYER_REQUEST)
	request := []interface{}{ sn, this.Pid }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to QueryPlayerInfo(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` QueryPlayerInfo", this.Pid)
		return nil
	}
}
func (this *AIObject)CreatePlayer()error{
	if this.IsOnline() {
		return ErrAIOnline
	}
	this.ChangeState(ST_REGISTERING)

	//// prepare
	// [sn, "name", country, "BIO", head, sex]
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_CREATE_PLAYER_REQUEST)
	name := config.GenAIName()
	log.Info("create player, name is '%s'", name)
	request := []interface{}{ sn, name, 0, "", 0, 0 }

	// cache
	this.SetData(sn, name)

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to CreatePlayer(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` CreatePlayer", this.Pid)
		return nil
	}
}

func (this *AIObject)OnLogin(vip_lv int64)bool{
	// active
	var is_active int64
	err := this.gamedb.QueryRow("SELECT `active` FROM `ai` WHERE `pid`=?", this.Pid).Scan(&is_active)
	if err == sql.ErrNoRows {
		if _, err := this.gamedb.Exec("INSERT INTO `ai`(`pid`, `freezed`, `active`)VALUES(?, 0, 1)", this.Pid); err!=nil {
			log.Error("Fail to NewAIObject(%d, %d, send_buffer), mysql INSERT INTO error %s", this.Pid, this.ServerId, err.Error())
			return false
		}
	} else if err != nil {
		log.Error("Fail to NewAIObject(%d, %d, send_buffer), mysql SELECT error %s", this.Pid, this.ServerId, err.Error())
		return false
	}
	// this.is_active =(is_active!=0 && vip_lv<=int64(config.Config.VipLevelCopyMax))
	this.is_active =(is_active!=0)

	if !this.is_active {
		log.Debug("ai %d OnLogin fail, vip is %d", this.Pid, vip_lv)
		return false
	}
	log.Debug("ai %d OnLogin success, vip is %d", this.Pid, vip_lv)

	/* name
	if len(this.name) == 0 {
		var name string
		err = this.gamedb.QueryRow("SELECT `name` FROM `property` WHERE `pid`=?", this.Pid).Scan(&name)
		if err != nil {
			log.Error("Fail to NewAIObject(%d, %d, send_buffer), mysql error %s", this.Pid, ServerId, err.Error())
			return
		}
		this.Name =name
	}
	*/
	this.Unload()
	dbmgr.CopyPlayer(this.FromServerId, this.FromPid, this.ServerId, this.Pid)
	this.GuildQueryApply()
	this.StoryFinishFight()
	this.QueryMailContact(FLAG_MAIL_CONTACT_AUTO_ADD)
	this.ChangeState(ST_ONLINE)
	return true
}
// story
func (this *AIObject)StoryFinishFight()error{
	//// prepare
	// [sn]
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_STORY_FINISH_FIGHT_REQUEST)
	request := []interface{}{ sn }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to StoryFinishFight(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` StoryFinishFight", this.Pid)
		return nil
	}
}
// guild
func (this *AIObject)GuildQueryApply()error{
	//// prepare
	// [sn]
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_GUILD_QUERY_APPLY_REQUEST)
	request := []interface{}{ sn }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to GuildQueryApply(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` GuildQueryApply", this.Pid)
		return nil
	}
}
func (this *AIObject)GuildAudit(pid uint32, audit_type int32)error{
	//// prepare
	// [sn, playerid, type] type:1 同意， 2 不同意
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_GUILD_AUDIT_REQUEST)
	request := []interface{}{ sn, pid, audit_type }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to GuildAudit(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` GuildAudit", this.Pid)
		return nil
	}
}
func (this *AIObject)GuildQueryMembers()error{
	//// prepare
	// [sn, type]
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_GUILD_QUERY_MEMBERS_REQUEST)
	request := []interface{}{ sn }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to GuildQueryMembers(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` GuildQueryMembers", this.Pid)
		return nil
	}
}
func (this *AIObject)QueryGuildList()error{
	//// prepare
	// [sn]
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_GUILD_QUERY_GUILD_LIST_REQUEST)
	request := []interface{}{ sn }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to QueryGuildList(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` QueryGuildList", this.Pid)
		return nil
	}
}
func (this *AIObject)GuildJoin(guild_id int32)error{
	//// prepare
	// [sn, guildid]
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_GUILD_JOIN_REQUEST)
	request := []interface{}{ sn, guild_id }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to GuildJoin(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` GuildJoin", this.Pid)
		return nil
	}
}
func (this *AIObject)GuildJoin5Xing()error{
	//// prepare
	// [sn]
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_GUILD_5XING_JOIN_REQUEST)
	request := []interface{}{ sn }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to GuildJoin5Xing(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` GuildJoin5Xing", this.Pid)
		return nil
	}
}
func (this *AIObject)GuildDonate(donate_type int32)error{
	//// prepare
	// [sn, type]
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_GUILD_DONATE_REQUEST)
	request := []interface{}{ sn, donate_type}

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to GuildDonate(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` GuildDonate", this.Pid)
		return nil
	}
}
// manor
func (this *AIObject)ManorEnter(manor_type, manor_id uint32)error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_MANOR_ENTER_REQUEST)
	request := []interface{}{ sn, manor_id }

	// set data
	this.SetData(sn, []interface{}{ int64(manor_type), int64(manor_id) })

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to ManorEnter(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` ManorEnter(%d, %d)", this.Pid, manor_type, manor_id)
		return nil
	}
}
func (this *AIObject)ManorLeave()error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_MANOR_LEAVE_REQUEST)
	request := []interface{}{ sn }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to ManorLeave(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` ManorLeave", this.Pid)
		return nil
	}
}
func (this *AIObject)ManorGetPlaceholderList(manor_id uint32)error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_MANOR_QUERY_PLACEHOLDER_REQUEST)
	request := []interface{}{ sn, manor_id }

	// set data
	this.SetData(sn, manor_id)

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to ManorGetPlaceholderList(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` ManorGetPlaceholderList", this.Pid)
		return nil
	}
}
func (this *AIObject)ManorPrepareAttackMonster(manor_id uint32, placeholder int32)error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_MANOR_PREPARE_ATTACK_MONSTER_REQUEST)
	request := []interface{}{ sn, manor_id, placeholder }

	// set data
	this.SetData(sn, []int64{ int64(manor_id), int64(placeholder) })

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to ManorPrepareAttackMonster(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` ManorPrepareAttackMonster", this.Pid)
		return nil
	}
}
func (this *AIObject)ManorCheckAttackMonster(manor_id uint32, placeholder int32, fight_data string)error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_MANOR_CHECK_ATTACK_MONSTER_REQUEST)
	request := []interface{}{ sn, manor_id, placeholder, fight_data }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to ManorCheckAttackMonster(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` ManorCheckAttackMonster", this.Pid)
		return nil
	}
}
func (this *AIObject)ManorAttackBoss(manor_id uint32)error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_MANOR_ATTACK_BOSS_REQUEST)
	request := []interface{}{ sn, manor_id }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to ManorAttackBoss(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` ManorAttackBoss", this.Pid)
		return nil
	}
}
func (this *AIObject)ManorGatherResource(res_type int32)error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_MANOR_GATHER_RESOURCE_REQUEST)
	request := []interface{}{ sn, res_type }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to ManorGatherResource(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` ManorGatherResource", this.Pid)
		return nil
	}
}
func (this *AIObject)ManorUpgradeResource(res_type int32)error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_MANOR_UPGRADE_RESOURCE_REQUEST)
	request := []interface{}{ sn, res_type }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to ManorUpgradeResource(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` ManorUpgradeResource", this.Pid)
		return nil
	}
}
func (this *AIObject)ManorAssistResource(manor_id uint32, res_type int32)error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_MANOR_ASSIST_RESOURCE_REQUEST)
	request := []interface{}{ sn, manor_id, res_type }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to ManorAssistResource(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` ManorAssistResource", this.Pid)
		return nil
	}
}
func (this *AIObject)ManorPickTreasure(placeholder int32)error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_MANOR_PICK_TREASURE_REQUEST)
	request := []interface{}{ sn, placeholder }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to ManorPickTreasure(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` ManorPickTreasure", this.Pid)
		return nil
	}
}
// arena
func (this *AIObject)ArenaJoin()error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_ARENA_JOIN_REQUEST)
	request := []interface{}{ sn }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to ArenaJoin(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` ArenaJoin", this.Pid)
		return nil
	}
}
func (this *AIObject)ArenaAttack(pos int32)error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_ARENA_ATTACK_REQUEST)
	request := []interface{}{ sn, pos }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to ArenaAttack(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` ArenaAttack", this.Pid)
		return nil
	}
}

// unload player
func (this *AIObject)Unload()bool{
	log.Info("AI `%d` Unload", this.Pid)
	str := fmt.Sprintf("{\"Pid\":%d}", this.Pid)
	gmserver.Request(config.Config.ServerTable[this.ServerId].GMURL, "unload_player", str)
	return true
}

// QueryMailContact
func (this *AIObject)QueryMailContact(flag int64)error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_MAIL_CONTACT_GET_REQUEST)
	request := []interface{}{ sn }

	// rpc data
	this.SetData(sn, flag)

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to QueryMailContact(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` QueryMailContact", this.Pid)
		return nil
	}
}

// AddFriend
func (this *AIObject)MailContactAdd(pid int64)error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_MAIL_CONTACT_ADD_REQUEST)
	request := []interface{}{ sn, 1, pid, "" }

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to MailContactAdd(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` MailContactAdd `%d`", this.Pid, pid)
		return nil
	}
}
func (this *AIObject)QueryMailContactRecommend(frientd_pids []int64)error{
	//// prepare
	sn := this.NextSn()
	header := MakeAmfHeader(this.Pid, sn, C_MAIL_CONTACT_RECOMMEND_REQUEST)
	request := []interface{}{ sn }

	// set data
	this.SetData(sn, frientd_pids)

	//// make and send
	if bs, err := MakeNetPacket(header, request); err!=nil {
		log.Error("fail to QueryMailContactRecommend(%s), amf encode error %s", err.Error())
		return err
	} else {
		this.send_buffer.AppendSendBuffer(bs)
		log.Info("AI `%d` QueryMailContactRecommend", this.Pid)
		return nil
	}
}
