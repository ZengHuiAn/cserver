package logic

import(
	"fmt"
	"time"
	"encoding/json"
	"math/rand"
	"code.agame.com/aiserver/common"
	"code.agame.com/aiserver/gmserver"
	"code.agame.com/aiserver/config"
	"code.agame.com/aiserver/log"
)

// register
func init(){
	RegisterAction(common.ACTION_LOGIN, on_login_action)
	RegisterAction(common.ACTION_LOGOUT, on_logout_action)

	RegisterAction(common.ACTION_ARENA_ATTACK, on_arena_attack_action)

	RegisterAction(common.ACTION_GUILD_APPLY, on_guild_apply_action)
	RegisterAction(common.ACTION_GUILD_DONATE, on_guild_donate_action)
	RegisterAction(common.ACTION_GUILD_JOIN_5XING, on_guild_join_5xing_action)

	RegisterAction(common.ACTION_MANOR_ENTER, on_manor_enter_action)
	RegisterAction(common.ACTION_MANOR_LEAVE, on_manor_leave_action)
	RegisterAction(common.ACTION_MANOR_ATTACK_BOSS, on_manor_attack_boss_action)

	RegisterAction(common.ACTION_SHOW_BILLBOARD, on_show_billboard_action)
}

//// callback
// login logout
func on_login_action(act Action, ai *common.AIObject)bool{
	log.Info("AI `%d` on_login_action(ignore)", ai.Pid)
	return true
}
func on_logout_action(act Action, ai *common.AIObject)bool{
	log.Info("AI `%d` on_logout_action", ai.Pid)
	ai.Logout()
	return false
}
// arena
func on_arena_attack_action(act Action, ai *common.AIObject)bool{
	log.Info("AI `%d` on_arena_attack_action", ai.Pid)
	ai.ArenaJoin()
	return true
}
// guild
func on_guild_apply_action(act Action, ai *common.AIObject)bool{
	log.Info("AI `%d` on_guild_apply_action", ai.Pid)
	ai.GuildQueryMembers()
	return true
}
func on_guild_donate_action(act Action, ai *common.AIObject)bool{
	log.Info("AI `%d` on_guild_donate_action", ai.Pid)
	if len(act.Args) > 0 {
		donate_type := int32(act.Args[0])
		ai.GuildDonate(donate_type)
	} else {
		ai.GuildDonate(1)
	}
	return true
}
func on_guild_join_5xing_action(act Action, ai *common.AIObject)bool{
	log.Info("AI `%d` on_guild_join_5xing_action", ai.Pid)
	ai.GuildJoin5Xing()
	return true
}
// manor
func on_manor_enter_action(act Action, ai *common.AIObject)bool{
	log.Info("AI `%d` on_manor_enter_action", ai.Pid)
	if len(act.Args) > 1 {
		manor_type := uint32(act.Args[0])
		manor_id := uint32(act.Args[1])
		if manor_id + uint32(config.Config.AiPidBegin) == ai.Pid {
			ai.ManorEnter(manor_type, ai.Pid)
		} else if manor_id == common.MANOR_WORLD_BOSS_ID {
			ai.ManorEnter(manor_type, manor_id)
		} else {
			ai.QueryMailContact(common.FLAG_MANOR_ENTER)
		}
	} else {
		log.Error("parameter error")
	}
	return true
}
func on_manor_leave_action(act Action, ai *common.AIObject)bool{
	log.Info("AI `%d` on_manor_leave_action", ai.Pid)
	ai.ManorLeave()
	return true
}
func on_manor_attack_boss_action(act Action, ai *common.AIObject)bool{
	log.Info("AI `%d` on_manor_attack_boss_action", ai.Pid)
	if len(act.Args) > 0 {
		manor_id := uint32(act.Args[0])
		ai.ManorAttackBoss(manor_id)
	}
	return true
}
// billboard
func on_show_billboard_action(act Action, ai *common.AIObject)bool{
	log.Info("AI `%d` on_show_billboard_action", ai.Pid)

	type HttpRequest struct {
		Pid      uint32 `json:"Pid"`
		Start    uint32 `json:"start"`;
		Duration uint32 `json:"duration"`;
		Interval uint32 `json:"interval"`;
		Type     uint32 `json:"type"`;
		Msg      string `json:"message"`;
	};

	if len(act.StrArgs) > 0 {
		format := common.I2String(act.StrArgs[0])
		ai_name:= ai.Name
		ai_pid := ai.Pid
		go func(){
			secs := rand.Int31() % 30
			log.Info("AI `%d` on_show_billboard_action, sleep %d", ai_pid, secs)
			time.Sleep(time.Duration(secs) * time.Second)
			ai_rich_name :=fmt.Sprintf("#[type=player,pid=%d]%s#[end]", ai_pid, ai_name)
			str := fmt.Sprintf(format, ai_rich_name)

			request := HttpRequest{
				Pid : ai_pid,
				Start : uint32(time.Now().Unix()),
				Duration : 1,
				Interval : 3,
				Type : 1,
				Msg : str,
			}

			if bs, err := json.Marshal(request); err==nil {
				gmserver.Request(config.Config.ServerTable[ai.ServerId].GMURL, "notify", string(bs))
				log.Info("AI `%d` show billboard:%s", ai_pid, str)
			} else {
				log.Error("AI `%d` fail to broadcast, json marshal error, %s", ai_pid, err.Error());
			}
		}()
	}
	return true
}
