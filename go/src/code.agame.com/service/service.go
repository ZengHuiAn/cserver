package service

import (
	"errors"
	"fmt"
	"sync/atomic"
	"time"

	"log"

	"code.agame.com/config"
	"code.agame.com/remote"

	agame "code.agame.com/com_agame_protocol"
	proto "code.google.com/p/goprotobuf/proto"
)

type TypeIdValue struct {
	Type  int32 `json:"type,omitempty"`
	Id    int32 `json:"id,omitempty"`
	Value int32 `json:"value,omitempty"`
}

var world []*remote.Remote
var service map[string]*remote.Remote

var _sn uint32 = 1

func sn() uint32 {
	return atomic.AddUint32(&_sn, 1)
}

func u(u uint32) *uint32 {
	return proto.Uint32(u)
}

func s(s string) *string {
	return proto.String(s)
}

func u64(u64 uint64) *uint64 {
	return proto.Uint64(u64)
}

func init() {
	pro, addr := config.GetWorldAddr(0)
	fmt.Println(pro, addr)

	world = []*remote.Remote{remote.New(pro, addr)}
	for _, w := range world {
		w.Startup()
	}

	service = make(map[string]*remote.Remote)

	pro, addr = config.GetServiceAddr("Chat", 0)
	service["Chat"] = remote.New(pro, addr)
	service["Chat"].Startup()

	pro, addr = config.GetServiceAddr("Consume", 0)
	service["Consume"] = remote.New(pro, addr)
	service["Consume"].Startup()

	pro, addr = config.GetServiceAddr("Gm", 0)
	service["Gm"] = remote.New(pro, addr)
	service["Gm"].Startup()

	/*
	       pro, addr = config.GetServiceAddr("Activity", 0);
	   	service["Activity"] = remote.New(pro, addr);
	   	service["Activity"].Startup();


	       pro, addr = config.GetServiceAddr("ADSupport", 0);
	   	service["ADSupport"] = remote.New(pro, addr);
	   	service["ADSupport"].Startup();
	*/
}

func SendChatMessage(channel uint64, msg string) error {
	request := &agame.ChatMessageRequest{
		Sn:      u(sn()),
		From:    u64(3),
		Channel: u64(channel),
		Message: s(msg),
	}

	respond, err := service["Chat"].Talk(request)
	if err != nil {
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		return ErrResult
	}
	return nil
}

func QueryPlayer(pid uint64, name string) (*agame.Player, error) {
	request := &agame.PGetPlayerInfoRequest{
		Sn:       u(sn()),
		Playerid: u64(pid),
		Name:     s(name),
	}

	w := world[pid%uint64(len(world))]

	respond, err := w.Talk(request)
	if err != nil {
		return nil, err
	}

	result := respond.GetResult()
	if result != 0 {
		if result == 3 {
			return nil, ErrPlayerNotExist
		}
		return nil, ErrResult
	}
	return (respond.(*agame.PGetPlayerInfoRespond)).GetPlayer(), nil
}

func QueryPlayerReturnInfo(pid uint64, name string) (*agame.PGetPlayerReturnInfoRespond, error) {
	request := &agame.PGetPlayerReturnInfoRequest{
		Sn:       u(sn()),
		Playerid: u64(pid),
		Name:     s(name),
	}

	w := world[pid%uint64(len(world))]

	respond, err := w.Talk(request)
	if err != nil {
		return nil, err
	}

	result := respond.GetResult()
	if result != 0 {
		if result == 3 {
			return nil, ErrPlayerNotExist
		}
		return nil, ErrResult
	}
	return respond.(*agame.PGetPlayerReturnInfoRespond), nil
}

func SendReward(pid uint64, reason uint32, manual bool, limit uint32, name string, rewards []*agame.Reward) error {
	request := &agame.PAdminRewardRequest{
		Sn:       u(sn()),
		Playerid: u64(pid),
		Reward:   []*agame.Reward(rewards),
		Reason:   u(reason),
		Limit:    u(limit),
		Name:     s(name),
	}

	if manual {
		request.Manual = u(1)
	}

	w := world[pid%uint64(len(world))]

	respond, err := w.Talk(request)
	if err != nil {
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		if result == 3 {
			return ErrPlayerNotExist
		}
		return ErrResult
	}
	return nil
}

func SendRewardWithCondition(pid uint64, reason uint32, manual bool, limit uint32, name string, rewards []*agame.Reward, condition *agame.PAdminRewardRequest_Condition) error {
	request := &agame.PAdminRewardRequest{
		Sn:        u(sn()),
		Playerid:  u64(pid),
		Reward:    []*agame.Reward(rewards),
		Reason:    u(reason),
		Limit:     u(limit),
		Name:      s(name),
		Condition: condition,
	}

	if manual {
		request.Manual = u(1)
	}

	w := world[pid%uint64(len(world))]

	respond, err := w.Talk(request)
	if err != nil {
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		if result == 3 {
			return ErrPlayerNotExist
		}
		return ErrResult
	}
	return nil
}

func SendPunish(pid uint64, reason uint32, consumes []*agame.PAdminRewardRequest_Consume) error {
	request := &agame.PAdminRewardRequest{
		Sn:       u(sn()),
		Playerid: u64(pid),
		Consume:  []*agame.PAdminRewardRequest_Consume(consumes),
		Reason:   u(reason),
	}

	w := world[pid%uint64(len(world))]

	respond, err := w.Talk(request)
	if err != nil {
		return err
	}
	result := respond.GetResult()
	if result != 0 {
		if result == 3 {
			return ErrPlayerNotExist
		}
		return ErrResult
	}
	return nil
}

func SetPlayerStatus(pid uint64, status uint32) error {
	request := &agame.PSetPlayerStatusRequest{
		Sn:       u(sn()),
		Playerid: u64(pid),
		Status:   u(status),
	}

	w := world[pid%uint64(len(world))]

	respond, err := w.Talk(request)
	if err != nil {
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		if result == 3 {
			return ErrPlayerNotExist
		}
		return ErrResult
	}
	return nil
}

func KickPlayer(pid uint64) error {
	request := &agame.PAdminPlayerKickRequest{
		Sn:       u(sn()),
		Playerid: u64(pid),
	}

	w := world[pid%uint64(len(world))]

	respond, err := w.Talk(request)
	if err != nil {
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		if result == 3 {
			return ErrPlayerNotExist
		}
		return ErrResult
	}
	return nil
}

func SendBroadCast(start uint32, duration uint32, interval uint32, typa uint32, msg string) (uint32, error) {
	if start == 0 {
		start = uint32(time.Now().Unix())
	}

	if interval == 0 {
		interval = 60
	}

	request := &agame.TimingNotifyAddRequest{
		Sn:       u(sn()),
		Start:    u(start),
		Duration: u(duration),
		Interval: u(interval),
		Type:     u(typa),
		Message:  s(msg),
	}

	respond, err := service["Chat"].Talk(request)
	if err != nil {
		return 0, err
	}

	result := respond.GetResult()
	if result != 0 {
		return 0, ErrResult
	}

	id := (respond.(*agame.TimingNotifyAddRespond)).GetId()

	return id, nil
}

// type Broadcast agame.TimingNotifyQueryRespond_TimingNotify;

func QueryBroadCast() ([]*agame.TimingNotifyQueryRespond_TimingNotify, error) {
	request := &agame.TimingNotifyQueryRequest{
		Sn: u(sn()),
	}

	respond, err := service["Chat"].Talk(request)
	if err != nil {
		return nil, err
	}

	result := respond.GetResult()
	if result != 0 {
		return nil, ErrResult
	}

	notifys := (respond.(*agame.TimingNotifyQueryRespond)).GetAllTimingNotify()

	return notifys, nil
}

func DeleteBroadCast(id uint32) error {
	request := &agame.TimingNotifyDelRequest{
		Sn: u(sn()),
		Id: u(id),
	}

	respond, err := service["Chat"].Talk(request)
	if err != nil {
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		return ErrResult
	}

	return nil
}

func SendMail(from uint64, to uint64, typa uint32, title, content string, reward_content_list []TypeIdValue) error {
	request := &agame.AdminAddMailRequest{
		Sn:       u(sn()),
		From:     u64(from),
		To:       u64(to),
		Type:     u(typa),
		Title:    s(title),
		Content:  s(content),
		Appendix: make([]*agame.AdminAddMailRequest_Appendix, 0, len(reward_content_list)),
	}
	for i := 0; i < len(reward_content_list); i++ {
		item := reward_content_list[i]
		t := item.Type
		id := item.Id
		value := item.Value
		request.Appendix = append(request.Appendix, &agame.AdminAddMailRequest_Appendix{Type: &t, Id: &id, Value: &value})
	}

	respond, err := service["Chat"].Talk(request)
	if err != nil {
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		if result == 3 {
			return ErrPlayerNotExist
		}
		return ErrResult
	}

	return nil
}

func QueryMail(pid uint64) ([]*agame.AdminQueryMailRespond_Mail, error) {
	request := &agame.AdminQueryMailRequest{
		Sn:  u(sn()),
		Pid: u64(pid),
	}

	respond, err := service["Chat"].Talk(request)
	if err != nil {
		return nil, err
	}

	result := respond.GetResult()
	if result != 0 {
		if result == 3 {
			return nil, ErrPlayerNotExist
		}
		return nil, ErrResult
	}

	mail := (respond.(*agame.AdminQueryMailRespond)).GetMails()

	return mail, nil
}

func DeleteMail(id uint32) error {
	request := &agame.AdminDelMailRequest{
		Sn: u(sn()),
		Id: u(id),
	}

	respond, err := service["Chat"].Talk(request)
	if err != nil {
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		return ErrResult
	}
	return nil
}

func AddVIPExp(pid uint64, exp uint32) error {
	request := &agame.PAdminAddVIPExpRequest{
		Sn:  u(sn()),
		Pid: u64(pid),
		Exp: u(exp),
	}

	w := world[pid%uint64(len(world))]

	respond, err := w.Talk(request)
	if err != nil {
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		if result == 3 {
			return ErrPlayerNotExist
		}
		return ErrResult
	}
	return nil
}

func UnloadPlayer(pid uint64) error {
	request := &agame.UnloadPlayerRequest{
		Sn:       u(sn()),
		Playerid: u64(pid),
	}

	w := world[pid%uint64(len(world))]

	respond, err := w.Talk(request)
	if err != nil {
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		if result == 3 {
			return ErrPlayerNotExist
		}
		return ErrResult
	}
	return nil
}

func BuyMonthCard(pid uint64) error {
	request := &agame.BuyMonthCardRequest{
		Sn:       u(sn()),
		Playerid: u64(pid),
	}

	w := world[pid%uint64(len(world))]

	respond, err := w.Talk(request)
	if err != nil {
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		if result == 3 {
			return ErrPlayerNotExist
		}
		return ErrResult
	}
	return nil
}

func QueryAllBonus() ([]*agame.QueryAllBonusRespond_Bonus, error) {
	request := &agame.QueryAllBonusRequest{
		Sn: u(sn()),
	}

	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return nil, err
	}

	result := respond.GetResult()
	if result != 0 {
		return nil, ErrResult
	}
	bonus_list := (respond.(*agame.QueryAllBonusRespond)).GetBonus()
	return bonus_list, nil
}
func QueryBonus(bonus_id int64) (int64, []*agame.QueryBonusRespond_TimeRange, []*agame.QueryBonusRespond_TimeRange, error) {
	request := &agame.QueryBonusRequest{
		Sn:      u(sn()),
		BonusId: proto.Int64(bonus_id),
	}

	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return 0, nil, nil, err
	}

	result := respond.GetResult()
	if result != 0 {
		return 0, nil, nil, ErrResult
	}

	respond_bonus_id := (respond.(*agame.QueryBonusRespond)).GetBonusId()
	reward := (respond.(*agame.QueryBonusRespond)).GetReward()
	count := (respond.(*agame.QueryBonusRespond)).GetCount()
	return respond_bonus_id, reward, count, nil
}

func AddBonus(bonus_id, flag, ratio, begin_time, end_time int64) (int64, error) {
	request := &agame.AddBonusTimeRangeRequest{
		Sn:        u(sn()),
		BonusId:   proto.Int64(bonus_id),
		Flag:      proto.Int64(flag),
		Ratio:     proto.Int64(ratio),
		BeginTime: proto.Int64(begin_time),
		EndTime:   proto.Int64(end_time),
	}
	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return 0, err
	}
	result := respond.GetResult()
	if result != 0 {
		return 0, ErrResult
	}
	uuid := (respond.(*agame.AddBonusTimeRangeRespond)).GetUuid()
	return uuid, nil
}

func RemoveBonus(bonus_id int64, uuid int64) error {
	request := &agame.RemoveBonusRequest{
		Sn:      u(sn()),
		BonusId: proto.Int64(bonus_id),
		Uuid:    proto.Int64(uuid),
	}

	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return err
	}
	result := respond.GetResult()
	if result != 0 {
		return ErrResult
	}
	return nil
}

func UpdateBonus(bonus_id int64) error {
	request := &agame.GmHotUpdateBonusRequest{
		Sn:      u(sn()),
		BonusId: proto.Int64(bonus_id),
	}
	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return err
	}
	result := respond.GetResult()
	if result != 0 {
		return ErrResult
	}
	return nil
}

func QueryExchangeGift() (int64, []*agame.QueryExchangeGiftRewardRespond_Reward, error) {
	request := &agame.QueryExchangeGiftRewardRequest{
		Sn: u(sn()),
	}
	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return 0, nil, err
	}
	result := respond.GetResult()
	if result != 0 {
		return 0, nil, ErrResult
	}
	rewards := (respond.(*agame.QueryExchangeGiftRewardRespond)).GetReward()
	open_time := (respond.(*agame.QueryExchangeGiftRewardRespond)).GetOpenTime()
	return open_time, rewards, nil
}

func ReplaceExchangeGift(open_time int64, rewards []*agame.ReplaceExchangeGiftRewardRequest_Reward) error {
	request := &agame.ReplaceExchangeGiftRewardRequest{
		Sn:       u(sn()),
		OpenTime: proto.Int64(open_time),
		Reward:   []*agame.ReplaceExchangeGiftRewardRequest_Reward(rewards),
	}
	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return err
	}
	result := respond.GetResult()
	if result != 0 {
		return ErrResult
	}
	return nil
}

func QueryFestivalReward() ([]*agame.QueryFestivalRewardRespond_Reward, error) {
	request := &agame.QueryFestivalRewardRequest{
		Sn: u(sn()),
	}
	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return nil, err
	}
	result := respond.GetResult()
	if result != 0 {
		return nil, ErrResult
	}
	rewards := (respond.(*agame.QueryFestivalRewardRespond)).GetReward()
	return rewards, nil
}

func ReplaceFestivalReward(rewards []*agame.ReplaceFestivalRewardRequest_Reward) error {
	request := &agame.ReplaceFestivalRewardRequest{
		Sn:     u(sn()),
		Reward: []*agame.ReplaceFestivalRewardRequest_Reward(rewards),
	}
	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return err
	}
	result := respond.GetResult()
	if result != 0 {
		return ErrResult
	}
	return nil
}

func QueryItemPackage() ([]*agame.QueryItemPackageRespond_Package, error) {
	request := &agame.QueryItemPackageRequest{
		Sn: u(sn()),
	}
	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return nil, err
	}
	result := respond.GetResult()
	if result != 0 {
		return nil, ErrResult
	}
	packages := (respond.(*agame.QueryItemPackageRespond)).GetPackage()
	return packages, nil
}

func SetItemPackage(pkg_id int64, items []*agame.SetItemPackageRequest_Item) error {
	request := &agame.SetItemPackageRequest{
		Sn:        u(sn()),
		PackageId: proto.Int64(pkg_id),
		Item:      []*agame.SetItemPackageRequest_Item(items),
	}
	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return err
	}
	result := respond.GetResult()
	if result != 0 {
		return ErrResult
	}
	return nil
}

func DelItemPackage(pkg_id int64) error {
	request := &agame.DelItemPackageRequest{
		Sn:        u(sn()),
		PackageId: proto.Int64(pkg_id),
	}
	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return err
	}
	result := respond.GetResult()
	if result != 0 {
		return ErrResult
	}
	return nil
}
func QueryAccumulateGift() (int64, int64, []*agame.QueryAccumulateConsumeGoldRewardRespond_Reward, error) {
	request := &agame.QueryAccumulateConsumeGoldRewardRequest{
		Sn: u(sn()),
	}
	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return 0, 0, nil, err
	}
	result := respond.GetResult()
	if result != 0 {
		return 0, 0, nil, ErrResult
	}
	rewards := (respond.(*agame.QueryAccumulateConsumeGoldRewardRespond)).GetReward()
	begin_time := (respond.(*agame.QueryAccumulateConsumeGoldRewardRespond)).GetBeginTime()
	end_time := (respond.(*agame.QueryAccumulateConsumeGoldRewardRespond)).GetEndTime()
	return begin_time, end_time, rewards, nil
}

func QueryAccumulateExchange() (int64, int64, []*agame.QueryAccumulateExchangeRewardRespond_Reward, error) {
	request := &agame.QueryAccumulateExchangeRewardRequest{
		Sn: u(sn()),
	}
	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return 0, 0, nil, err
	}
	result := respond.GetResult()
	if result != 0 {
		return 0, 0, nil, ErrResult
	}
	rewards := (respond.(*agame.QueryAccumulateExchangeRewardRespond)).GetReward()
	begin_time := (respond.(*agame.QueryAccumulateExchangeRewardRespond)).GetBeginTime()
	end_time := (respond.(*agame.QueryAccumulateExchangeRewardRespond)).GetEndTime()
	return begin_time, end_time, rewards, nil
}

func ReplaceAccumulateGift(begin_time int64, end_time int64, rewards []*agame.ReplaceAccumulateConsumeGoldRewardRequest_Reward) error {
	request := &agame.ReplaceAccumulateConsumeGoldRewardRequest{
		Sn:        u(sn()),
		BeginTime: proto.Int64(begin_time),
		EndTime:   proto.Int64(end_time),
		Reward:    []*agame.ReplaceAccumulateConsumeGoldRewardRequest_Reward(rewards),
	}
	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return err
	}
	result := respond.GetResult()
	if result != 0 {
		return ErrResult
	}
	return nil
}

func ReplaceAccumulateExchange(begin_time int64, end_time int64, rewards []*agame.ReplaceAccumulateExchangeRewardRequest_Reward) error {
	request := &agame.ReplaceAccumulateExchangeRewardRequest{
		Sn:        u(sn()),
		BeginTime: proto.Int64(begin_time),
		EndTime:   proto.Int64(end_time),
		Reward:    []*agame.ReplaceAccumulateExchangeRewardRequest_Reward(rewards),
	}
	w := world[1%uint32(len(world))]
	respond, err := w.Talk(request)
	if err != nil {
		return err
	}
	result := respond.GetResult()
	if result != 0 {
		return ErrResult
	}
	return nil
}

func FreshPointReward(items []*agame.AdminFreshPointRewardRequest_Item) error {
	request := &agame.AdminFreshPointRewardRequest{
		Sn:    u(sn()),
		Items: []*agame.AdminFreshPointRewardRequest_Item(items),
	}

	respond, err := service["Consume"].Talk(request)
	if err != nil {
		return err
	}
	result := respond.GetResult()
	if result != 0 {
		if result == 14 {
			return errors.New("database update error")
		} else {
			return ErrResult
		}
	}
	return nil
}

func QueryPointReward() ([]*agame.AdminQueryPointRewardRespond_Item, error) {
	request := &agame.AdminQueryPointRewardRequest{
		Sn: u(sn()),
	}

	respond, err := service["Consume"].Talk(request)
	if err != nil {
		return nil, err
	}
	result := respond.GetResult()
	if result != 0 {
		if result == 14 {
			return nil, errors.New("database update error")
		} else {
			return nil, ErrResult
		}
	}
	items := (respond.(*agame.AdminQueryPointRewardRespond)).GetItems()
	return items, nil
}

func Bind7725(pid uint64) error {
	if _, ok := service["Activity"]; !ok {
		return errors.New("service Activity not exist")
	}
	request := &agame.Bind7725Request{
		Sn:  u(sn()),
		Pid: u64(pid),
	}
	respond, err := service["Activity"].Talk(request)
	if err != nil {
		return err
	}
	result := respond.GetResult()
	if result != 0 {
		return ErrResult
	}
	return nil
}

func AdminFreshLimitedShop(shop_type, fresh_period, fresh_count, begin_time, end_time uint32) error {
	request := &agame.AdminFreshLimitedShopRequest{
		Sn:        u(sn()),
		BeginTime: u(begin_time),
		EndTime:   u(end_time),
	}
	respond, err := service["Consume"].Talk(request)
	if err != nil {
		return err
	}
	result := respond.GetResult()
	if result != 0 {
		return ErrResult
	}
	return nil
}

func SetSalary(pid uint64, salary uint32) error {
	request := &agame.PSetPlayerSalaryRequest{
		Sn:     u(sn()),
		Pid:    u64(pid),
		Salary: u(salary),
	}

	w := world[pid%uint64(len(world))]

	respond, err := w.Talk(request)
	if err != nil {
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		if result == 3 {
			return ErrPlayerNotExist
		}
		return ErrResult
	}
	return nil
}

func ADSupportInsertEvent(request *agame.NotifyADSupportEventRequest) error {
	request.Sn = u(sn())

	log.Println("service.NotifyADSupportEventRequest")
	respond, err := service["ADSupport"].Talk(request)
	if err != nil {
		log.Println("Talk Error", err)
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		log.Println("Result Error", result)
		return ErrResult
	}
	return nil
}

func ADSupportAddLoginGroup(request *agame.ADSupportAddLoginGroupRequest) error {
	request.Sn = u(sn())

	log.Println("service.ADSupportAddGroupLoginRequest")
	respond, err := service["ADSupport"].Talk(request)
	if err != nil {
		log.Println("Talk Error", err)
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		log.Println("Result Error", result)
		return ErrResult
	}
	return nil
}

func ADSupportAddInvestGroup(request *agame.ADSupportAddInvestGroupRequest) error {
	request.Sn = u(sn())

	log.Println("service.ADSupportAddGroupInvestRequest")
	respond, err := service["ADSupport"].Talk(request)
	if err != nil {
		log.Println("Talk Error", err)
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		log.Println("Result Error", result)
		return ErrResult
	}
	return nil
}

func ADSupportAddGroup(request *agame.ADSupportAddGroupRequest) error {
	request.Sn = u(sn())

	log.Println("service.ADSupportAddGroupRequest")
	respond, err := service["ADSupport"].Talk(request)
	if err != nil {
		log.Println("Talk Error", err)
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		log.Println("Result Error", result)
		return ErrResult
	}
	return nil
}

func ADSupportAddQuest(request *agame.ADSupportAddQuestRequest) error {
	request.Sn = u(sn())

	log.Println("service.ADSupportAddQuestRequest")
	respond, err := service["ADSupport"].Talk(request)
	if err != nil {
		log.Println("Talk Error", err)
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		log.Println("Result Error", result)
		return ErrResult
	}
	return nil
}

func ADSupportGetGroupid(request *agame.ADSupportGetGroupidRequest) error {
	request.Sn = u(sn())

	log.Println("service.ADSupportGetGroupidRequest")
	respond, err := service["ADSupport"].Talk(request)
	if err != nil {
		log.Println("Talk Error", err)
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		log.Println("Result Error", result)
		return ErrResult
	}
	return nil
}

func ADSupportreloadConfig(request *agame.ADSupportreloadConfigRequest) error {
	request.Sn = u(sn())

	log.Println("service.ADSupportreloadConfigRequest")
	respond, err := service["ADSupport"].Talk(request)
	if err != nil {
		log.Println("Talk Error", err)
		return err
	}

	result := respond.GetResult()
	if result != 0 {
		log.Println("Result Error", result)
		return ErrResult
	}
	return nil
}

////////////////////////////////////////////////////////////////////////////////
//

func RewardN(n int) []*agame.Reward {
	return make([]*agame.Reward, n)
}

func Rewards(rewards ...*agame.Reward) []*agame.Reward {
	return rewards
}

func makeSomething(typa, id, value uint32) *agame.Reward {
	return &agame.Reward{
		Type:  u(typa),
		Id:    u(id),
		Value: u(value),
	}
}

func Resource(id, value uint32) *agame.Reward {
	return makeSomething(90, id, value)
}
func Item(id, value uint32) *agame.Reward {
	return makeSomething(41, id, value)
}
func Armament(id, value uint32) *agame.Reward {
	return makeSomething(10, id, value)
}
func Tactic(id, value uint32) *agame.Reward {
	return makeSomething(23, id, value)
}
func King(id, value uint32) *agame.Reward {
	return makeSomething(1, id, value)
}
func ItemPackage(id, value uint32) *agame.Reward {
	return makeSomething(42, id, value)
}

//-----
func Money(value uint32) *agame.Reward {
	return Resource(6, value)
}

func Coin(value uint32) *agame.Reward {
	return Resource(2, value)
}

var ErrPlayerNotExist = errors.New("player not exists")
var ErrResult = errors.New("result error")

func SendGMCommand(cmd string, bs []byte) ([]byte, error) {
	request := &agame.GMRequest{
		Sn:      u(sn()),
		Command: s(cmd),
		Json:    s(string(bs)),
	}

	log.Println("service.SendGMCommand")
	respond, err := service["Gm"].Talk(request)
	if err != nil {
		log.Println("Talk Error", err)
		return nil, err
	}

	result := respond.GetResult()
	if result != 0 {
		log.Println("Result Error", result)
		return nil, ErrResult
	}

	info := (respond.(*agame.GMRespond)).GetJson()

	return []byte(info), nil
}
