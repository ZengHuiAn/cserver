package remote

import (
	"bytes"
	log "code.agame.com/logger"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"sync"
	"time"

	agame "code.agame.com/com_agame_protocol"
	proto "code.google.com/p/goprotobuf/proto"
)

var ErrTimeout = errors.New("remote.Timeout")
var ErrInvalidConnection = errors.New("remote.InvalidConnection")
var ErrUnknownRequest = errors.New("remote.UnknownRequest")
var ErrDuplicateSN = errors.New("remote.DuplicateSN")

var byteOrder = binary.BigEndian

////////////////////////////////////////////////////////////////////////////////
// Remote
type Remote struct {
	pro     string
	addr    string
	conn    net.Conn
	waiting map[uint32]chan Respond
	lock    sync.Mutex
}

func New(pro, addr string) *Remote {
	return &Remote{pro: pro, addr: addr, waiting: make(map[uint32]chan Respond)}
}

func (r *Remote) Startup() {
	if r.conn != nil {
		r.conn.Close()
	}

	go (func() {
		// connect;
		for {
			log.Println("remote connect", r.addr)
			conn, err := net.Dial(r.pro, r.addr)
			if err == nil {
				log.Println("remote", r.addr, "connect success")
				r.conn = conn
				break
			}
			log.Println("remote", r.addr, "connect failed", err)
			time.Sleep(1 * time.Second)
		}
		go r.r()
	})()
}

func (r *Remote) push(sn uint32) (chan Respond, error) {
	r.lock.Lock()
	defer r.lock.Unlock()

	if r.waiting[sn] != nil {
		return nil, ErrDuplicateSN
	}

	ch := make(chan Respond, 1)
	r.waiting[sn] = ch

	return ch, nil
}

func (r *Remote) pop(sn uint32) chan Respond {
	r.lock.Lock()
	defer r.lock.Unlock()

	ch := r.waiting[sn]
	delete(r.waiting, sn)

	return ch
}

func (r *Remote) clear() {
	r.lock.Lock()
	m := r.waiting
	r.waiting = make(map[uint32]chan Respond)
	r.lock.Unlock()

	// 释放
	for _, ch := range m {
		ch <- nil
	}
}

func (r *Remote) r() {
	var err error
	for {
		var header tHeader
		if err = binary.Read(r.conn, byteOrder, &header); err != nil {
			log.Println("remote", r.addr, "read header error", err)
			break
		}

		// log.Println("header.Length", header.Length, binary.Size(header));

		bs := make([]byte, header.Length-uint32(binary.Size(header)))
		if _, err = io.ReadFull(r.conn, bs); err != nil {
			log.Println("remote", r.addr, "read body error", err)
			break
		}

		// log.Println("remote", r.addr, "recv", bs);

		respond := newRespond(header.Cmd)

		// log.Printf("%+v\n", header)

		if respond == nil {
			log.Println("remote", r.addr, "unknown respond", header.Cmd)
			continue
		}

		if err = proto.Unmarshal(bs, respond); err != nil {
			log.Println("remote", r.addr, "unmarshal error", header.Cmd)
			break
		}

		sn := respond.GetSn()

		ch := r.pop(sn)
		if ch == nil {
			log.Println("remote", r.addr, "unknown sn", sn)
			continue
		}

		ch <- respond
	}

	r.clear()

	time.Sleep(1 * time.Second) // delay one second and reconnect
	r.Startup()
}

func (r *Remote) Talk(request Request) (Respond, error) {
	if r.conn == nil {
		return nil, ErrInvalidConnection
	}

	cmd := cmdOfRequest(request)
	if cmd == 0 {
		return nil, ErrUnknownRequest
	}

	sn := request.GetSn()

	var header tHeader

	bs, err := proto.Marshal(request)
	if err != nil {
		return nil, err
	}

	header.Length = uint32(len(bs) + binary.Size(header))
	header.Pid = 0
	header.Flag = 2
	header.Cmd = cmd

	var buffer bytes.Buffer
	binary.Write(&buffer, byteOrder, &header)
	buffer.Write(bs)

	// add to waiting list
	ch, err := r.push(sn)
	if err != nil {
		return nil, ErrDuplicateSN
	}

	bs = buffer.Bytes()
	// log.Println("remote", r.addr, "send", bs);
	if _, err := r.conn.Write(buffer.Bytes()); err != nil {
		return nil, err
	}

	// 超时检查
	select {
	case respond := <-ch:
		if respond == nil {
			return nil, ErrInvalidConnection
		} else {
			return respond, nil
		}
	case <-time.After(500 * time.Second):
		r.pop(sn)
		return nil, ErrTimeout
	}
	return nil, nil
}

////////////////////////////////////////////////////////////////////////////////
// struct and cmd
type tHeader struct {
	Length   uint32
	Sn       uint32
	Pid      uint64
	Flag     uint32
	Cmd      uint32
	ServerID uint32
}

type Request interface {
	proto.Message

	GetSn() uint32
}

type Respond interface {
	proto.Message
	GetSn() uint32
	GetResult() int32
}

const (
	S_UNLOAD_PLAYER_REQUEST = 6017
	S_UNLOAD_PLAYER_RESPOND = 6018

	S_BUY_MONTH_CARD_REQUEST = 6019
	S_BUY_MONTH_CARD_RESPOND = 6020

	S_ADMIN_ADD_VIP_EXP_REQUEST = 1012
	S_ADMIN_ADD_VIP_EXP_RESPOND = 1013

	S_CHAT_MESSAGE_REQUEST = 2900
	S_CHAT_MESSAGE_RESPOND = 2901

	S_RECORD_NOTIRY_MESSAGE_REQUEST = 2902
	S_RECORD_NOTIRY_MESSAGE_RESPOND = 2903

	S_TIMING_NOTIFY_ADD_REQUEST = 2904
	S_TIMING_NOTIFY_ADD_RESPOND = 2905

	S_TIMING_NOTIFY_QUERY_REQUEST = 2906
	S_TIMING_NOTIFY_QUERY_RESPOND = 2907

	S_TIMING_NOTIFY_DEL_REQUEST = 2908
	S_TIMING_NOTIFY_DEL_RESPOND = 2909

	S_ADMIN_ADD_MAIL_REQUEST = 2910
	S_ADMIN_ADD_MAIL_RESPOND = 2911

	S_ADMIN_QUERY_MAIL_REQUEST = 2912
	S_ADMIN_QUERY_MAIL_RESPOND = 2913

	S_ADMIN_DEL_MAIL_REQUEST = 2914
	S_ADMIN_DEL_MAIL_RESPOND = 2915

	S_GET_PLAYER_ARMY_REQUEST         = 3001
	S_GET_PLAYER_ARMY_RESPOND         = 3002
	S_FIGHT_NOTIFICATION              = 3003
	S_GET_PLAYER_INFO_REQUEST         = 3004
	S_GET_PLAYER_INFO_RESPOND         = 3005
	S_ADD_PLAYER_NOTIFICATION_REQUEST = 3006
	S_ADD_PLAYER_NOTIFICATION_RESPOND = 3007
	S_ADMIN_REWARD_REQUEST            = 3008
	S_ADMIN_REWARD_RESPOND            = 3009
	REWARD_PLAYER_EXP                 = 1
	REWARD_PLAYER_PRESTIGE            = 2
	REWARD_RESOURCES_VALUE            = 3
	REWARD_HERO_EXP_SPEC              = 4
	REWARD_ITEM                       = 5
	REWARD_GEM                        = 6
	REWARD_EQUIP                      = 7
	REWARD_HERO_ID                    = 10
	S_SET_PLAYER_LOCATION_REQUEST     = 3010
	S_SET_PLAYER_LOCATION_RESPOND     = 3011
	S_GET_PLAYER_STORY_REQUEST        = 3012
	S_GET_PLAYER_STORY_RESPOND        = 3013
	S_SET_PLAYER_STATUS_REQUEST       = 3014
	S_SET_PLAYER_STATUS_RESPOND       = 3015
	PLAYER_STATUS_NORMAL              = 0
	PLAYER_STATUS_BAN                 = 0
	PLAYER_STATUS_MUTE                = 0

	S_ADMIN_PLAYER_KICK_REQUEST = 3016
	S_ADMIN_PLAYER_KICK_RESPOND = 3017

	S_GET_PLAYER_BUILDING_REQUEST = 3018
	S_GET_PLAYER_BUILDING_RESPOND = 3019

	S_GET_PLAYER_TECHNOLOGY_REQUEST = 3020
	S_GET_PLAYER_TECHNOLOGY_RESPOND = 3021

	S_ADMIN_SET_ADULT_REQUEST = 3022
	S_ADMIN_SET_ADULT_RESPOND = 3023

	S_GET_PLAYER_RETURN_INFO_REQUEST = 3036
	S_GET_PLAYER_RETURN_INFO_RESPOND = 3037

	S_SET_PLAYER_SALARY_REQUEST = 3094
	S_SET_PLAYER_SALARY_RESPOND = 3095

	S_QUERY_ALL_BONUS_REQUEST = 6047
	S_QUERY_ALL_BONUS_RESPOND = 6048

	S_QUERY_BONUS_REQUEST = 6021
	S_QUERY_BONUS_RESPOND = 6022

	S_ADD_BONUS_TIME_RANGE_REQUEST = 6025
	S_ADD_BONUS_TIME_RANGE_RESPOND = 6026

	S_REMOVE_BONUS_REQUEST = 6031
	S_REMOVE_BONUS_RESPOND = 6032

	S_QUERY_EXCHANGE_GIFT_REWARD_REQUEST = 6033
	S_QUERY_EXCHANGE_GIFT_REWARD_RESPOND = 6034

	S_REPLACE_EXCHANGE_GIFT_REWARD_REQUEST = 6035
	S_REPLACE_EXCHANGE_GIFT_REWARD_RESPOND = 6036

	S_QUERY_ACCUMULATE_CONSUME_GOLD_REWARD_REQUEST = 6037
	S_QUERY_ACCUMULATE_CONSUME_GOLD_REWARD_RESPOND = 6038

	S_QUERY_ACCUMULATE_EXCHANGE_REWARD_REQUEST = 6053
	S_QUERY_ACCUMULATE_EXCHANGE_REWARD_RESPOND = 6054

	S_REPLACE_ACCUMULATE_CONSUME_GOLD_REWARD_REQUEST = 6039
	S_REPLACE_ACCUMULATE_CONSUME_GOLD_REWARD_RESPOND = 6040

	S_REPLACE_ACCUMULATE_EXCHANGE_REWARD_REQUEST = 6055
	S_REPLACE_ACCUMULATE_EXCHANGE_REWARD_RESPOND = 6056

	S_QUERY_FESTIVAL_REWARD_REQUEST = 6049
	S_QUERY_FESTIVAL_REWARD_RESPOND = 6050

	S_REPLACE_FESTIVAL_REWARD_REQUEST = 6051
	S_REPLACE_FESTIVAL_REWARD_RESPOND = 6052

	S_SET_ITEM_PACKAGE_REQUEST = 6041
	S_SET_ITEM_PACKAGE_RESPOND = 6042

	S_DEL_ITEM_PACKAGE_REQUEST = 6043
	S_DEL_ITEM_PACKAGE_RESPOND = 6044

	S_QUERY_ITEM_PACKAGE_REQUEST = 6045
	S_QUERY_ITEM_PACKAGE_RESPOND = 6046

	S_GM_HOT_UPDATE_BONUS_REQUEST = 70001
	S_GM_HOT_UPDATE_BONUS_RESPOND = 70002

	S_BIND7725_REQUEST = 6059
	S_BIND7725_RESPOND = 6060

	S_ADMIN_FRESH_POINT_REWARD_REQUEST = 15025
	S_ADMIN_FRESH_POINT_REWARD_RESPOND = 15026

	S_ADMIN_QUERY_POINT_REWARD_INFO_REQUEST = 15027
	S_ADMIN_QUERY_POINT_REWARD_INFO_RESPOND = 15028

	S_ADMIN_FRESH_LIMITED_SHOP_REQUEST = 15031
	S_ADMIN_FRESH_LIMTIED_SHOP_RESPOND = 15032

	S_ADSUPPORT_EVENT_INSERT_EVENT_NUM_REQUEST = 14006
	S_ADSUPPORT_EVENT_INSERT_EVENT_NUM_RESPOND = 14007

	S_ADSUPPORT_GMADDGROUP_REQUEST = 14020
	S_ADSUPPORT_GMADDGROUP_RESPOND = 14021

	S_ADSUPPORT_GMADDQUEST_REQUEST = 14022
	S_ADSUPPORT_GMADDQUEST_RESPOND = 14023

	S_ADSUPPORT_GMRELOADGROUP_REQUEST = 14024
	S_ADSUPPORT_GMRELOADGROUP_RESPOND = 14025

	S_ADSUPPORT_GMGETGROUPID_REQUEST = 14026
	S_ADSUPPORT_GMGETGROUPID_RESPOND = 14027

	S_ADSUPPORT_LOGIN_GMADDGROUP_REQUEST = 14034
	S_ADSUPPORT_LOGIN_GMADDGROUP_RESPOND = 14035

	S_ADSUPPORT_INVEST_GMADDGROUP_REQUEST = 14036
	S_ADSUPPORT_INVEST_GMADDGROUP_RESPOND = 14037

	GM_INTERFACE_REQUEST = 19200
	GM_INTERFACE_RESPOND = 19201
)

func cmdOfRequest(request Request) uint32 {
	switch request.(type) {
	case *agame.ChatMessageRequest:
		return S_CHAT_MESSAGE_REQUEST
	case *agame.RecordNotifyMessageRequest:
		return S_RECORD_NOTIRY_MESSAGE_REQUEST
	case *agame.PGetPlayerArmyRequest:
		return S_GET_PLAYER_ARMY_REQUEST
	case *agame.PGetPlayerInfoRequest:
		return S_GET_PLAYER_INFO_REQUEST
	case *agame.PAddPlayerNotificationRequest:
		return S_ADD_PLAYER_NOTIFICATION_REQUEST
	case *agame.PAdminRewardRequest:
		return S_ADMIN_REWARD_REQUEST
	case *agame.PSetPlayerLocationRequest:
		return S_SET_PLAYER_LOCATION_REQUEST
	case *agame.PGetPlayerStoryRequest:
		return S_GET_PLAYER_STORY_REQUEST
	case *agame.PSetPlayerStatusRequest:
		return S_SET_PLAYER_STATUS_REQUEST
	case *agame.PAdminPlayerKickRequest:
		return S_ADMIN_PLAYER_KICK_REQUEST
	case *agame.PGetPlayerBuildingRequest:
		return S_GET_PLAYER_BUILDING_REQUEST
	case *agame.PGetPlayerTechnologyRequest:
		return S_GET_PLAYER_TECHNOLOGY_REQUEST
	case *agame.TimingNotifyAddRequest:
		return S_TIMING_NOTIFY_ADD_REQUEST
	case *agame.TimingNotifyQueryRequest:
		return S_TIMING_NOTIFY_QUERY_REQUEST
	case *agame.TimingNotifyDelRequest:
		return S_TIMING_NOTIFY_DEL_REQUEST
	case *agame.AdminAddMailRequest:
		return S_ADMIN_ADD_MAIL_REQUEST
	case *agame.AdminQueryMailRequest:
		return S_ADMIN_QUERY_MAIL_REQUEST
	case *agame.AdminDelMailRequest:
		return S_ADMIN_DEL_MAIL_REQUEST
	case *agame.PAdminSetAdultRequest:
		return S_ADMIN_SET_ADULT_REQUEST
	case *agame.PAdminAddVIPExpRequest:
		return S_ADMIN_ADD_VIP_EXP_REQUEST
	case *agame.UnloadPlayerRequest:
		return S_UNLOAD_PLAYER_REQUEST
	case *agame.BuyMonthCardRequest:
		return S_BUY_MONTH_CARD_REQUEST

	case *agame.QueryAllBonusRequest:
		return S_QUERY_ALL_BONUS_REQUEST
	case *agame.QueryBonusRequest:
		return S_QUERY_BONUS_REQUEST
	case *agame.AddBonusTimeRangeRequest:
		return S_ADD_BONUS_TIME_RANGE_REQUEST
	case *agame.RemoveBonusRequest:
		return S_REMOVE_BONUS_REQUEST

	case *agame.QueryExchangeGiftRewardRequest:
		return S_QUERY_EXCHANGE_GIFT_REWARD_REQUEST
	case *agame.ReplaceExchangeGiftRewardRequest:
		return S_REPLACE_EXCHANGE_GIFT_REWARD_REQUEST

	case *agame.QueryAccumulateConsumeGoldRewardRequest:
		return S_QUERY_ACCUMULATE_CONSUME_GOLD_REWARD_REQUEST
	case *agame.ReplaceAccumulateConsumeGoldRewardRequest:
		return S_REPLACE_ACCUMULATE_CONSUME_GOLD_REWARD_REQUEST

	case *agame.QueryAccumulateExchangeRewardRequest:
		return S_QUERY_ACCUMULATE_EXCHANGE_REWARD_REQUEST
	case *agame.ReplaceAccumulateExchangeRewardRequest:
		return S_REPLACE_ACCUMULATE_EXCHANGE_REWARD_REQUEST

	case *agame.QueryFestivalRewardRequest:
		return S_QUERY_FESTIVAL_REWARD_REQUEST
	case *agame.ReplaceFestivalRewardRequest:
		return S_REPLACE_FESTIVAL_REWARD_REQUEST

	case *agame.QueryItemPackageRequest:
		return S_QUERY_ITEM_PACKAGE_REQUEST
	case *agame.SetItemPackageRequest:
		return S_SET_ITEM_PACKAGE_REQUEST
	case *agame.DelItemPackageRequest:
		return S_DEL_ITEM_PACKAGE_REQUEST

	case *agame.GmHotUpdateBonusRequest:
		return S_GM_HOT_UPDATE_BONUS_REQUEST

	case *agame.Bind7725Request:
		return S_BIND7725_REQUEST

	case *agame.AdminFreshPointRewardRequest:
		return S_ADMIN_FRESH_POINT_REWARD_REQUEST
	case *agame.AdminQueryPointRewardRequest:
		return S_ADMIN_QUERY_POINT_REWARD_INFO_REQUEST
	case *agame.AdminFreshLimitedShopRequest:
		return S_ADMIN_FRESH_LIMITED_SHOP_REQUEST

	case *agame.PSetPlayerSalaryRequest:
		return S_SET_PLAYER_SALARY_REQUEST
	case *agame.ADSupportAddGroupRequest:
		return S_ADSUPPORT_GMADDGROUP_REQUEST
	case *agame.ADSupportAddQuestRequest:
		return S_ADSUPPORT_GMADDQUEST_REQUEST
	case *agame.ADSupportGetGroupidRequest:
		return S_ADSUPPORT_GMGETGROUPID_REQUEST
	case *agame.ADSupportreloadConfigRequest:
		return S_ADSUPPORT_GMRELOADGROUP_REQUEST
	case *agame.NotifyADSupportEventRequest:
		return S_ADSUPPORT_EVENT_INSERT_EVENT_NUM_REQUEST
	case *agame.PGetPlayerReturnInfoRequest:
		return S_GET_PLAYER_RETURN_INFO_REQUEST
	case *agame.ADSupportAddLoginGroupRequest:
		return S_ADSUPPORT_LOGIN_GMADDGROUP_REQUEST
	case *agame.ADSupportAddInvestGroupRequest:
		return S_ADSUPPORT_INVEST_GMADDGROUP_REQUEST
	case *agame.GMRequest:
		return GM_INTERFACE_REQUEST
	default:
		return 0
	}
}

func newRespond(cmd uint32) Respond {
	switch cmd {
	case S_CHAT_MESSAGE_RESPOND:
		return &agame.ChatMessageRespond{}
	case S_RECORD_NOTIRY_MESSAGE_RESPOND:
		return &agame.AGameRespond{}
	case S_GET_PLAYER_ARMY_RESPOND:
		return &agame.PGetPlayerArmyRespond{}
	case S_GET_PLAYER_INFO_RESPOND:
		return &agame.PGetPlayerInfoRespond{}
	case S_ADD_PLAYER_NOTIFICATION_RESPOND:
		return &agame.PAddPlayerNotificationRespond{}
	case S_ADMIN_REWARD_RESPOND:
		return &agame.PAdminRewardRespond{}
	case S_SET_PLAYER_LOCATION_RESPOND:
		return &agame.PSetPlayerLocationRespond{}
	case S_GET_PLAYER_STORY_RESPOND:
		return &agame.PGetPlayerStoryRespond{}
	case S_SET_PLAYER_STATUS_RESPOND:
		return &agame.PSetPlayerStatusRespond{}
	case S_ADMIN_PLAYER_KICK_RESPOND:
		return &agame.PAdminPlayerKickRespond{}
	case S_GET_PLAYER_BUILDING_RESPOND:
		return &agame.PGetPlayerBuildingRespond{}
	case S_GET_PLAYER_TECHNOLOGY_RESPOND:
		return &agame.PGetPlayerTechnologyRespond{}

	case S_TIMING_NOTIFY_ADD_RESPOND:
		return &agame.TimingNotifyAddRespond{}
	case S_TIMING_NOTIFY_QUERY_RESPOND:
		return &agame.TimingNotifyQueryRespond{}
	case S_TIMING_NOTIFY_DEL_RESPOND:
		return &agame.AGameRespond{}

	case S_ADMIN_ADD_MAIL_RESPOND:
		return &agame.AGameRespond{}
	case S_ADMIN_QUERY_MAIL_RESPOND:
		return &agame.AdminQueryMailRespond{}
	case S_ADMIN_DEL_MAIL_RESPOND:
		return &agame.AGameRespond{}
	case S_ADMIN_SET_ADULT_RESPOND:
		return &agame.AGameRespond{}
	case S_ADMIN_ADD_VIP_EXP_RESPOND:
		return &agame.AGameRespond{}
	case S_UNLOAD_PLAYER_RESPOND:
		return &agame.AGameRespond{}
	case S_BUY_MONTH_CARD_RESPOND:
		return &agame.AGameRespond{}

	case S_QUERY_ALL_BONUS_RESPOND:
		return &agame.QueryAllBonusRespond{}
	case S_QUERY_BONUS_RESPOND:
		return &agame.QueryBonusRespond{}
	case S_ADD_BONUS_TIME_RANGE_RESPOND:
		return &agame.AddBonusTimeRangeRespond{}
	case S_REMOVE_BONUS_RESPOND:
		return &agame.AGameRespond{}

	case S_QUERY_EXCHANGE_GIFT_REWARD_RESPOND:
		return &agame.QueryExchangeGiftRewardRespond{}
	case S_REPLACE_EXCHANGE_GIFT_REWARD_RESPOND:
		return &agame.AGameRespond{}

	case S_QUERY_ACCUMULATE_CONSUME_GOLD_REWARD_RESPOND:
		return &agame.QueryAccumulateConsumeGoldRewardRespond{}
	case S_REPLACE_ACCUMULATE_CONSUME_GOLD_REWARD_RESPOND:
		return &agame.AGameRespond{}

	case S_QUERY_ACCUMULATE_EXCHANGE_REWARD_RESPOND:
		return &agame.QueryAccumulateExchangeRewardRespond{}
	case S_REPLACE_ACCUMULATE_EXCHANGE_REWARD_RESPOND:
		return &agame.AGameRespond{}

	case S_QUERY_FESTIVAL_REWARD_RESPOND:
		return &agame.QueryFestivalRewardRespond{}
	case S_REPLACE_FESTIVAL_REWARD_RESPOND:
		return &agame.AGameRespond{}

	case S_QUERY_ITEM_PACKAGE_RESPOND:
		return &agame.QueryItemPackageRespond{}
	case S_SET_ITEM_PACKAGE_RESPOND:
		return &agame.AGameRespond{}
	case S_DEL_ITEM_PACKAGE_RESPOND:
		return &agame.AGameRespond{}

	case S_GM_HOT_UPDATE_BONUS_RESPOND:
		return &agame.AGameRespond{}

	case S_BIND7725_RESPOND:
		return &agame.AGameRespond{}

	case S_ADMIN_FRESH_POINT_REWARD_RESPOND:
		return &agame.AGameRespond{}
	case S_ADMIN_QUERY_POINT_REWARD_INFO_RESPOND:
		return &agame.AdminQueryPointRewardRespond{}
	case S_ADMIN_FRESH_LIMTIED_SHOP_RESPOND:
		return &agame.AGameRespond{}
	case S_SET_PLAYER_SALARY_RESPOND:
		return &agame.AGameRespond{}
	case S_ADSUPPORT_GMADDGROUP_RESPOND:
		return &agame.AGameRespond{}
	case S_ADSUPPORT_GMADDQUEST_RESPOND:
		return &agame.AGameRespond{}
	case S_ADSUPPORT_GMGETGROUPID_RESPOND:
		return &agame.AGameRespond{}
	case S_ADSUPPORT_GMRELOADGROUP_RESPOND:
		return &agame.AGameRespond{}
	case S_ADSUPPORT_EVENT_INSERT_EVENT_NUM_RESPOND:
		return &agame.AGameRespond{}
	case S_GET_PLAYER_RETURN_INFO_RESPOND:
		return &agame.PGetPlayerReturnInfoRespond{}
	case S_ADSUPPORT_LOGIN_GMADDGROUP_RESPOND:
		return &agame.AGameRespond{}
	case S_ADSUPPORT_INVEST_GMADDGROUP_RESPOND:
		return &agame.AGameRespond{}

	case GM_INTERFACE_RESPOND:
		return &agame.GMRespond{}

	default:
		return nil
	}
}
