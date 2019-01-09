local BinaryConfig = require "BinaryConfig"
local database = require "database"
local Command = require "Command"
local SocialManager = require "SocialManager"
require "MailReward"
local ORIGIN_TIME = 1514736000                  -- 2018-1-01 0:0:0

local LIMITLINE = 100000
---------------------------------config--------------------------------------
SocialManager.Connect("Guild")

local Rewards = {}
local Rank_Rewards = {}
local function load_activity_rewards()		
	local rows = BinaryConfig.Load("config_rank_rewards", "quiz")
	for _,row in ipairs(rows) do
		Rewards[row.rankid] =
		{
			type       = row.type,						-- type:   1:玩家  2:公会
			begin_time = row.begin_time,
			end_time = row.end_time,
			period   = row.period,
			duration = row.duration,
			reward_id = row.reward_id,	
			reward_type = row.reward_type,
		}
        end
end
load_activity_rewards()

local function GetActivityReward(rankid)
	if Rewards[rankid] then
		return Rewards[rankid]
	else
		return false
	end
end

local function load_activity_rank_rewards()
	local rows = BinaryConfig.Load("config_rank_rewards_content", "quiz")
	for _,row in ipairs(rows) do
		Rank_Rewards[row.id] = Rank_Rewards[row.id] or {}
		Rank_Rewards[row.id][row.rank_range] = 
		{
			reward1_type = row.reward1_type,
			reward1_id   = row.reward1_id,
			reward1_value= row.reward1_value,
	
			reward2_type = row.reward2_type,
                        reward2_id   = row.reward2_id,
                        reward2_value= row.reward2_value,

			reward3_type = row.reward3_type,
                        reward3_id   = row.reward3_id,
                        reward3_value= row.reward3_value,			

			drop_id     = row.drop_id,
			
			mail_title  = row.mail_title,
			mail_content = row.mail_content,
		}
        end
end
load_activity_rank_rewards()

local function sortTeamScoreDes(a,b)
        if a.score == b.score then
                return a.time < b.time
        else
                return a.score > b.score
        end
end

---------------------------------database------------------------------------
local RankList = {}
local function LoadRankDatum()
	local success,rows = database.query("select rankid,period,id,score,time from rank_score_reward")
	if success and #rows > 0 then
		for _,v in ipairs(rows) do
			RankList[v.rankid] = RankList[v.rankid] or {}
			RankList[v.rankid][v.period] = RankList[v.rankid][v.period] or {}
			RankList[v.rankid][v.period][v.id] = 
			{
				score  = v.score,
				time   = v.time,	
			}
		end	
	end	
end
LoadRankDatum()

local Rank = {}
local PlayerOfferScore = {}
local function Select_PlayerOfferScore(rankid,period,gid,pid)
	if type(rankid) ~= "number" or type(period) ~= "number" or type(gid) ~= "number" or type(pid) ~= "number" then
		return false	
	end

	local ok,result = database.query("select rankid,period,gid,pid,score from rank_player_offer_score where rankid = %d and period = %d and gid = %d and pid = %d",rankid,period,gid,pid)
	if ok and #result > 0 then
		local row = result[1]
		print(row.rankid,row.period)
		PlayerOfferScore[row.rankid] = PlayerOfferScore[row.rankid] or {}
		PlayerOfferScore[row.rankid][row.period] = PlayerOfferScore[row.rankid][row.period] or {}
		PlayerOfferScore[row.rankid][row.period][row.gid] = PlayerOfferScore[row.rankid][row.period][row.gid] or {}
		PlayerOfferScore[row.rankid][row.period][row.gid][row.pid] = row.score 
		return PlayerOfferScore[row.rankid][row.period][row.gid][row.pid]
	else
		return false
	end
end

local function Update_PlayerOfferScore(info)
	if type(info) ~= "table" then
                return false
        end

        if info.in_db then
                local ok = database.update("update rank_player_offer_score set score = %d where rankid = %d and period = %d and gid = %d and pid = %d",info.score,info.rankid,info.period,info.gid,info.pid)
                if ok then
                        return true
                end
        else
                local ok =  database.update("insert into rank_player_offer_score(rankid,period,gid,pid,score) values(%d,%d,%d,%d,%d)",info.rankid,info.period,info.gid,info.pid,info.score)
                if ok then
                        return true
                end
        end
end

local function LoadRanks(rankid,period,result)
	Rank[rankid] = Rank[rankid] or {}
	Rank[rankid][period] = Rank[rankid][period] or {}
	local ranklist = {}
	local ranks = result
	for _,v in ipairs(ranks) do
		print(v.id,v.score,v.time)
		table.insert(ranklist,{id = v.id,score = v.score,time = v.time})
	end
	table.sort(ranklist,sortTeamScoreDes)
	for rank,v in ipairs(ranklist) do
		table.insert(Rank[rankid][period],{id = v.id,score = v.score})
        end
end

local function Select_RankDB(rankid,period,id)	-- 查询
	if type(rankid) ~= "number" or type(period) ~= "number" then
		return false
	end
	if not id then
		local ok,result = database.query("select rankid,period,id,score,time from rank_score_reward where rankid = %d and period = %d",rankid,period)
		if ok and #result > 0 then
			if not Rank[rankid] or not Rank[rankid][period] then
				LoadRanks(rankid,period,result)
			end
			return result
		else
			return false
		end
	end
	local ok,result = database.query("select rankid,period,id,score,time from rank_score_reward where rankid = %d and period = %d and id = %d",rankid,period,id)
	if ok and #result > 0 then
		return result[1]
	else
		return false
	end
end

local function Update_RankScoreReward(info)
	if type(info) ~= "table" then
                return false
        end

	if info.in_db then
		local ok = database.update("update rank_score_reward set score = %d,time = %d where rankid = %d and period = %d and id = %d",info.score,info.time,info.rankid,info.period,info.id)
		if ok then
			return true
		end
	else
		local ok =  database.update("insert into rank_score_reward(rankid,period,id,score,time) values(%d,%d,%d,%d,%d)",info.rankid,info.period,info.id,info.score,info.time)
		if ok then
			return true
		end
	end
	
	return false
end

local RewardTime = {}
local function Select_PlayerRewardTime(rankid,period,pid)  -- 查询
        if type(rankid) ~= "number" or type(period) ~= "number" or type(pid) ~= "number" then
                return false
        end

	local ok,result = database.query("select rankid,period,pid,unix_timestamp(rewardtime) as rewardtime from rank_player_rewardtime where rankid = %d and period = %d and pid = %d",rankid,period,pid)
        if ok and #result > 0 then
                return result[1]
        else
                return false
        end
end

local function Update_PlayerRewardTime(info)
        if type(info) ~= "table" then
                return false
        end

        local ok
        if info.in_db then
		ok = database.update("update rank_player_rewardtime set rewardtime = from_unixtime_s(%d) where rankid = %d and period = %d and pid = %d",info.rewardtime,info.rankid,info.period,info.id)
                if ok then
                        return true
                end
        else
                ok =  database.update("insert into rank_player_rewardtime(rankid,period,pid,rewardtime) values(%d,%d,%d,from_unixtime_s(%d))",info.rankid,info.period,info.pid,info.rewardtime)
                if ok then
                        return true
                end
        end

        return false
end
-------------------------------------------------------------------------------------------------------------------

local time_count = 0

local function GetRank(rankid,period,id)
	if Rank[rankid] and Rank[rankid][period] then
		for rank,v in ipairs(Rank[rankid][period]) do
			if v.id == id then
				return {rank,v.score}
			end
		end
	end
	
	if Select_RankDB(rankid,period) then
		for rank,v in ipairs(Rank[rankid][period]) do
                        if v.id == id then
                                return {rank,v.score}
                        end
                end
	end
	return false
end

local function GetNowPeriod(rankid)
	local cfg = GetActivityReward(rankid)
        if not cfg then
		log.warning('there is no cfg...')
                return nil
        end

        local begin_time = cfg.begin_time
        local end_time = cfg.end_time
        local period = cfg.period
        local duration = cfg.duration

        return math.ceil((loop.now() + 1 - begin_time) / period)
end

local function notify(cmd, pid, msg)
        local agent = Agent.Get(pid);
        if agent then
                agent:Notify({cmd, msg});
        end
end

Scheduler.Register(function(now)
        time_count = 0
	if now%5 ~= 0 then return end
	local co = coroutine.create(function()
        for rankid,v in pairs(Rewards) do
                local cfg = GetActivityReward(rankid)
                if not cfg then
                        return nil
                end
                if cfg.type ~= 2 then return end
                local _period =  GetNowPeriod(rankid)
                local end_time = cfg.begin_time + cfg.period * (_period - 1) + cfg.duration
                if now >= end_time and now < end_time + 5  then
			print('------------------------------------- notify:',_period,end_time)
                        if RankList[rankid] and RankList[rankid][_period] then
				print('--------------------1')
                                for id,v in pairs(RankList[rankid][_period] or {}) do
                                        print('--------------------- id = '..id)
                                        local rank = GetRank(rankid,_period,id)
                                        if not rank then
                                                print('----------------------2')
                                                return false
                                        end

                                        local guild = SocialManager.getGuildByGuildId(id)
                                        if not guild then
                                                print('-----------------------3')
                                                return false
                                        end
                                        local pids = guild.members_id
                                        for _,pid in pairs(pids) do
                                                print('-----------------------------------------activity is end..',pid,rankid,_period)
                                                notify(Command.NOTIFY_GUILD_ACTIVITY_END,pid,{0,Command.RET_SUCCESS,rankid,_period,id,rank[1]})
                                        end
                                end
                        end
                end
        end
	end)

	coroutine.resume(co)
end)

local function getRankListDate(rankid,period)
        RankList[rankid] = RankList[rankid] or {}
        if not RankList[rankid][period] then
                local ranks = Select_RankDB(rankid,period)
                if ranks then
                        for _,v in ipairs(ranks) do
                                RankList[rankid][period][v.id] = { score  = v.score,time = v.time}
                        end
		else
			return false
                end
        end
        return RankList[rankid][period]
end

local function SortRank(rankid,period)
	Rank[rankid] = Rank[rankid] or {}
	Rank[rankid][period] = {}
	local ranklist = {}
	local ranks = getRankListDate(rankid,period)
	for id,v in pairs(ranks) do
		table.insert(ranklist,{id = id,score = v.score,time = v.time})
	end
	table.sort(ranklist,sortTeamScoreDes)

		
	for rank,v in ipairs(ranklist) do
		table.insert(Rank[rankid][period],{id = v.id,score = v.score})
	end
end


local function RanksResult(rankid,period,num)
	local amf = {}
	for rank,v in ipairs(Rank[rankid][period] or {}) do
        	if rank < num then 
			table.insert(amf,{v.id,rank,v.score})
		end
        end
        return amf
end

local function GetRanks(rankid,period,num)
	if Rank[rankid] and Rank[rankid][period] then
		return RanksResult(rankid,period,num) 
        end
	
	if Select_RankDB(rankid,period) then
                return RanksResult(rankid,period,num)
        end
	
        return false
end

local function Update_Score(rankid,score,id,pid)
	time_count = time_count + 1
	local _time = (loop.now() - ORIGIN_TIME)*1000 + time_count 
	print('---------------------------------- _time = '.._time)
	local period = GetNowPeriod(rankid)
	if not period then
		log.warning('there is no period...')
		return false
	end
	print('========================== period = '..period)
	RankList[rankid] = RankList[rankid] or {}
	RankList[rankid][period] = RankList[rankid][period] or {}
	local _in_db  = true
	if not RankList[rankid][period][id] then
		local ranklist = Select_RankDB(rankid,period,id)
		if not ranklist then
			_in_db = false
			RankList[rankid][period][id] = { score = score,time = _time }
		else
			_in_db = true
			RankList[rankid][period][id] = { score = ranklist.score + score,time = _time}
		end
	else
		_in_db = true
		local temp = RankList[rankid][period][id]
		RankList[rankid][period][id] = { score = temp.score + score,time = _time}
	end
	---------------------------------
	local _in_db2 = true
	PlayerOfferScore[rankid] = PlayerOfferScore[rankid] or {}
	PlayerOfferScore[rankid][period] = PlayerOfferScore[rankid][period] or {}
	PlayerOfferScore[rankid][period][id] = PlayerOfferScore[rankid][period][id] or {}
	if not PlayerOfferScore[rankid][period][id][pid] then
		local offerscore = Select_PlayerOfferScore(rankid,period,id,pid)
		if not offerscore then
			_in_db2 = false
			PlayerOfferScore[rankid][period][id][pid] = score
		else
			_in_db2 = true
			PlayerOfferScore[rankid][period][id][pid] = offerscore + score
		end
	else
		PlayerOfferScore[rankid][period][id][pid] = PlayerOfferScore[rankid][period][id][pid] + score
	end
	
	local temp2 = {rankid = rankid,period = period,gid = id,pid = pid,score = PlayerOfferScore[rankid][period][id][pid],in_db = _in_db2}
	Update_PlayerOfferScore(temp2)
	local tmp = RankList[rankid][period][id]

	local info = {rankid = rankid,period = period,id = id,score = tmp.score,time = tmp.time,in_db = _in_db}	

	if Update_RankScoreReward(info) then
		SortRank(rankid,period)
		return true
	else
		return false
	end
end

local function IsOfferScore(rankid,period,id,pid)
	PlayerOfferScore[rankid] = PlayerOfferScore[rankid] or {}
        PlayerOfferScore[rankid][period] = PlayerOfferScore[rankid][period] or {}
        PlayerOfferScore[rankid][period][id] = PlayerOfferScore[rankid][period][id] or {}
        if not PlayerOfferScore[rankid][period][id][pid] then
		local offerscore = Select_PlayerOfferScore(rankid,period,id,pid)
		if not offerscore then
			return false
		else
			return true
		end
	else
		return true
	end	
end

local function Updata_ScorebyPlayerid(pid,rankid,score)
	local cfg = GetActivityReward(rankid)
        if not cfg then
                log.warning('----------------- no cfg...')
                return nil
        end		

	if cfg.type == 1 then		-- 玩家
		local res = Update_Score(rankid,score,pid)
		if not res then
			return false
		end
	elseif cfg.type == 2 then 				-- 公会
		local respond = SocialManager.getGuild(pid)
		if not respond then
			return false
		end
		
		local res = Update_Score(rankid,score,respond.guild.id)
		if not res then
			return false
		end
	end

	return true
end

local function Update_RewardTime(rankid,period,pid)
	RewardTime[rankid] = RewardTime[rankid] or {}
	RewardTime[rankid][period] = RewardTime[rankid][period] or {}
	if not RewardTime[rankid][period][pid] then
		local ranklist = Select_PlayerRewardTime(rankid,period,pid)
                if not ranklist then
			local time = loop.now()
                        RewardTime[rankid][period][pid] = time
			print('^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^')	
			database.update("insert into rank_player_rewardtime(rankid,period,pid,rewardtime) values(%d,%d,%d,from_unixtime_s(%d))",rankid,period,pid,time)	
			return true
		else
			print('----------------------------001')
			return false
                end
	else
		print('----------------------------002',RewardTime[rankid][period][pid])
		return false
	end
end

local function get_rank_reward(rankid,type,rank)
	if Rewards[rankid] then
		local reward_id = Rewards[rankid].reward_id
		
		local ranges = {}
		if Rank_Rewards[reward_id] then
			for range,v in pairs(Rank_Rewards) do
				table.insert(ranges,range)	
			end
			table.sort(ranges,function(a,b) return a < b end)
		end

		for _,v in ipairs(ranges) do
			if rank <= v then 
				rank = v 
				break
			end	
		end

		if Rank_Rewards[reward_id] and Rank_Rewards[reward_id][rank] then
			return Rank_Rewards[reward_id][rank]
		else
			log.warning("there is no rank_info in configure file config_rank_rewards_content...")
			return false
		end		
		
	else
		log.warning("there is no rank_info in configure file config_rank_rewards...")
		return false
	end			
end

local function Exchange(pid,reward,consume)
        local ret = cell.sendReward(pid,reward,consume,Command.REASON_REWARD)
        if ret and ret.result == Command.RET_SUCCESS then
                return true
        else
                log.warning("Exchange fail, cell error")
                return false
        end
end

----------------------------------------------------------------------------------------------


local function getRankListScorebyId(rankid,period,pid)
        local ranks = getRankListDate(rankid,period)
	local ranklist = {}
        if ranks then
		for id,rank in pairs(ranks or {}) do
			if id == pid then return score end
		end
        end

        return false
end

local function get_members_rank(rankid,period)
	local amf = {}
	local ranklist = {}
	local ranks = getRankListDate(rankid,period)
	if ranks then
		for id,rank in pairs(ranks or {}) do
			table.insert(ranklist,{id = id,score = rank.score,time = rank.time})		
		end
                table.sort(ranklist,sortTeamScoreDes)
                for i,v in ipairs(ranklist) do
			if i > 10 then break end
			table.insert(amf,{v.id,i})
                end
		return amf
	else
		log.warning("there is no ranks ...")
		return amf
        end
end

local function GetRankandScore(rankid,period)
	local amf = {}
	local ranks = getRankListDate(rankid,period)
	if not ranks then return end
end
---------------------------------------------------------------------------------------------------------
local function onQueryPlayerRank(conn,pid,request)
	local cmd = Command.C_RANKLIST_QUERY_PLAYER_RANK_RESPOND
	local sn = request[1]
	local rankid = request[2]
	local period = request[3]
	local id = request[4]

	print('---------------------------------------onQueryPlayerRank:',rankid,period,id)
	if type(rankid) ~= "number" or type(period) ~= "number" or type(id) ~= "number" then
		log.warning('paramter is erro ...')
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	local rank = GetRank(rankid,period,id)
	if not rank then
		print('----------------not rank')
		return conn:sendClientRespond(cmd, pid, {sn,Command.RET_ERROR})
	end
	print('----------------rank:',rank[1],rank[2])
	return conn:sendClientRespond(cmd, pid, {sn,Command.RET_SUCCESS,rank})
end

local function onQueryTeamMembersRank(conn,pid,request)
	local cmd = Command.C_RANKLIST_QUERY_TEAM_RANK_RESPOND
	local sn = request[1]
	local rankid = request[2]
	local period = request[3]
	local num = request[4]
	print('---------------------------------------onQueryTeamMembersRank:',rankid,period,num)
	if type(rankid) ~= "number" or type(period) ~= "number" or type(num) ~= "number" then
                log.warning('paramter is erro ...')
                return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
        end
	
	local ranks = GetRanks(rankid,period,num)
	if not ranks then
		print('-------------no ranks')
		return conn:sendClientRespond(cmd, pid, {sn,Command.RET_ERROR})
	end
	for _,v in ipairs(ranks) do
		print('----------ranks:',v[1],v[2],v[3])
	end
	return conn:sendClientRespond(cmd, pid, {sn,Command.RET_SUCCESS,ranks})
end

local function onPlayerRewards(conn,pid,request)
	local cmd = Command.C_RANKLIST_REWARD_RESPOND
	local sn = request[1]
	local rankid = request[2]
	local period = request[3]
	local sendmail = request[4]   

	local id = pid
	print('---------------------------------------onPlayerRewards:',rankid,period,pid)
	if type(rankid) ~= "number" or type(period) ~= "number" then
		log.warning('paramter is erro ...')
                return conn:sendClientRespond(cmd, pid, {sn, Command.RET_PARAM_ERROR})
	end

	
	local cfg = GetActivityReward(rankid)
        if not cfg then
		log.warning('----------------- no cfg...')
                return nil
        end
	
	if cfg.reward_type == 2 then
		local begin_time = cfg.begin_time + cfg.period * (period - 1)
		local now = loop.now()
		if now >= begin_time and now < begin_time + cfg.duration then
			log.warning('the activity is not end...')
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end
	end

	if cfg.type == 2 then
		local respond = SocialManager.getGuild(pid)
		if not respond then
			print('%%%%%%%%%%%%%%%%%%%%%%%%%')
			return false
		end
		id = respond.guild.id
		--[[
		local join_time = respond.jointime
		local end_time = cfg.begin_time + cfg.period * (period - 1) + cfg.duration
		print('------------------------- join_time、end_time = '..join_time,end_time)
		if join_time > end_time then
			log.warning("jointime is more then activity endtime ...")
			return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
		end--]]
	end

	if not IsOfferScore(rankid,period,id,pid) then					-- 只有对公会贡献积分才会获得奖励
		log.warning("you have no offer score for guild...")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

		
	print('--------------------------- rankid,period,id = '..rankid,period,id)
	local rank = GetRank(rankid,period,id)	
	if not rank then
		log.warning("there is no player...")
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})	
	end

	local _reward = get_rank_reward(rankid,2,rank[1])  -- 1:玩家    2:公会
	if not _reward then
		return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end
		
	local reward1 = {type = _reward.reward1_type,id = _reward.reward1_id,value = _reward.reward1_value}
	local reward2 = {type = _reward.reward2_type,id = _reward.reward2_id,value = _reward.reward2_value}
	local reward3 = {type = _reward.reward3_type,id = _reward.reward3_id,value = _reward.reward3_value}
	
	if _reward.reward1_type == 0 or  _reward.reward1_id == 0 then
		reward1 = nil
	end
	if _reward.reward2_type == 0 or  _reward.reward2_id == 0 then
                reward2 = nil
        end
	if _reward.reward3_type == 0 or  _reward.reward3_id == 0 then
                reward3 = nil
        end

	if not Update_RewardTime(rankid,period,pid) then
		log.warning("you have accepted reward...")
                return conn:sendClientRespond(cmd, pid, {sn, Command.RET_ERROR})
	end

	local ret
	if sendmail == 1 then
		print('-------------------------------------mail')
		ret = send_reward_by_mail(pid, _reward.mail_title,_reward.mail_content, {reward1,reward2,reward3})
	else
		print('-------------------------------------common')
		ret = Exchange(pid,{reward1,reward2,reward3},nil)
	end

	return conn:sendClientRespond(cmd, pid, {sn,ret and Command.RET_SUCCESS or Command.RET_ERROR})
end

local function onUpdateDatum(conn,channel,request)
	local cmd = Command.S_RANKLIST_UPDATE_DATUM_RESPOND
	local proto = 'aGameRespond'
	if channel ~= 0 then
                log.error("Fail to `S_RANKLIST_UPDATE_DATUM_REQUEST`, channel ~= 0")
                return sendServiceRespond(conn, cmd, channel, proto, { sn = request.sn or 0, result = Command.RET_PREMISSIONS });
        end

	local sn,pid,rankid,score,sociaty = request.sn,request.pid,request.rankid,request.score,request.sociaty
	local ret
	if sociaty == 0 then
		ret = Updata_ScorebyPlayerid(pid,rankid,score)			
	else
		ret = Update_Score(rankid,score,sociaty,pid)	
	end
	return sendServiceRespond(conn,cmd, channel,proto, { sn = sn, result = ret and Command.RET_SUCCESS or Command.RET_ERROR})
end

local function onNotifyToReward(conn,channel,request)
	local cmd = Command.S_RANKLIST_NOTIFY_REWARD_RESPOND
	local proto = 'aGameRespond'
	if channel ~= 0 then
		log.error("Fail to `S_RANKLIST_NOTIFY_REWARD_REQUEST`, channel ~= 0")
                return sendServiceRespond(conn, cmd, channel, proto, { sn = request.sn or 0, result = Command.RET_PREMISSIONS })
	end
	
	return sendServiceRespond(conn,cmd,channel,proto, { sn = sn,Command.RET_ERROR})	
end

local RankListManager = {}
function RankListManager.RegisterCommand(service)
	service:on(Command.C_RANKLIST_QUERY_PLAYER_RANK_REQUEST,onQueryPlayerRank)
	service:on(Command.C_RANKLIST_QUERY_TEAM_RANK_REQUEST,onQueryTeamMembersRank)
	service:on(Command.C_RANKLIST_REWARD_REQUEST,onPlayerRewards)

	service:on(Command.S_RANKLIST_UPDATE_DATUM_REQUEST,'RankListUpdateDatumRequest',onUpdateDatum)
--	service:on(Command.S_RANKLIST_NOTIFY_REWARD_REQUEST,'RankListNotifyToReward',onNotifyToReward)
end

return RankListManager 

