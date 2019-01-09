package invite

import (
	"fmt"
)

// 名词解释
// active_friend => 字面意思'主动的朋友'，即我主动发码邀请的玩家
// passive_friend => 字面意思'被动的朋友'，即发码邀请我的玩家
// active 和 passive 基准点永远都是玩家自己，例如：active_friend_count => 我主动邀请的好友数量

// helper //
var g_alpha ="qazxswedcvfrtgbnhyujmkiolp"
func num_to_code(num uint32) string {
	code := "";
	for num > 0 {
		r := num%26;
		c := g_alpha[r:r+1] //string.sub(g_alpha, r, r)
		code = c + code;
		num = num / 26
	}
	return code
}

var alphaMap map[string]uint32;
func findAlpha(alpha string) uint32 {
	if alphaMap == nil {
		alphaMap = make(map[string]uint32);
		for i := 0; i < len(g_alpha); i++ {
			alphaMap[g_alpha[i:i+1] ] = uint32(i);
		}
	}
	return alphaMap[alpha];
}

func code_to_num(code string) uint32 {
	var num uint32 = 0
	for i := 0; i < len(code); i++ {
		ch := code[i:i+1];
		v  := findAlpha(ch);

		num = v + num * 26
	}
	return num
}

/*
func pid_to_code(sid string, pid uint32) (string, error) {
        local srv_code =num_to_code(XMLConfig.ServerId)
        local pid_code =num_to_code(pid)
        local code =""
        local cnt =math.max(#srv_code, #pid_code)
        if cnt > #srv_code then
                srv_code =string.rep(string.sub(g_alpha, 1, 1), cnt - #srv_code) .. srv_code
        end
        if cnt > #pid_code then
                pid_code =string.rep(string.sub(g_alpha, 1, 1), cnt - #pid_code) .. pid_code
        end
        for i=1, cnt do
                local a =string.sub(srv_code, i, i)
                local b =string.sub(pid_code, i, i)
                code =code .. a .. b
        end

        // print("pid_to_code", srv_code, pid_code)
        return code
}
*/

func code_to_pid(code string) (sid string, pid uint32, err error) {
	srv_code := ""
	pid_code := ""
	cnt      := len(code) / 2
	for i := 0; i < cnt; i++ {
		a, b, c := i*2, i*2+1, i*2+2
		srv_code = srv_code + code[a:b]
		pid_code = pid_code + code[b:c]
	}

	sid = fmt.Sprintf("%v", code_to_num(srv_code));
	pid = code_to_num(pid_code);
	return;
}

func Code2PID(code string) (sid string, pid uint32, err error) {
	return code_to_pid(code);
}
