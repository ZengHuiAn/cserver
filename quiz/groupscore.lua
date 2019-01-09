package.cpath=package.cpath .. ";../lib/?.so";
package.path =package.path .. ";../lib/?.lua";

require "log"
require "database"	 --PlayerTeamFight
require "NetService"
require "Command"
require "AMF"
require "XMLConfig"
require "protobuf"

local base64 = require "base64"

if log.open then
        local l = log.open(XMLConfig.FileDir and XMLConfig.FileDir .. "/gscore_%T.log" or "../log/gscore_%T.log");
        log.debug    = function(...) l:debug   (...) end;
        log.info     = function(...) l:info   (...)  end;
        log.warning  = function(...) l:warning(...)  end;
        log.error    = function(...) l:error  (...)  end;
end


local function sendClientRespond(conn, cmd, channel, msg)
        assert(conn);
        assert(cmd);
        assert(channel);
        assert(msg and (table.maxn(msg) >= 2));

        local sid = tonumber(bit32.rshift_long(channel, 32))
        assert(sid > 0)

        local code = AMF.encode(msg);

        if code then conn:sends(1, cmd, channel, sid, code) end
end

local function encode(protocol, msg)
        local code = protobuf.encode("com.agame.protocol." .. protocol, msg);
        if code == nil then
                print(string.format(" * encode %s failed", protocol));
                loop.exit();
                return nil;
        end
        return code;
end

function sendServiceRespond(conn, cmd, channel, protocol, msg)
    local code = encode(protocol, msg);
        local sid = tonumber(bit32.rshift_long(channel, 32))
    if code then
        return conn:sends(2, cmd, channel, sid, code);
    else
        return false;
    end
end

local function decode(code, protocol)
        return protobuf.decode("com.agame.protocol." .. protocol, code);
end

--[[local cfg = XMLConfig.Social["Groupscore"];
service = NetService.New(cfg.port,cfg.host,cfg.name)
assert(service,"listen on" .. cfg.host .. ":" .. cfg.port .. "failed");-]]

local function onServiceRegister(conn, channel, request) -- 此函数暂时没啥用处。。。
        if request.type == "GATEWAY" then
                for k, v in pairs(request.players) do

                end
        end
end

--------- central  code --------------------
--- 反馈给客户端  分组积分数据
local MAX_GROUP_RECORD_COUNT = 100	
local EFFECTIVE_TIME = 10000

local groupData = {}
local function insertGroupData(pid, group, score, extData,time,id)
        if not groupData[group] then
                groupData[group] = {}
        end
	if not id then
		id = databaseInsert(pid,group,score,extData,time)
	end
        table.insert(groupData[group],{id = id,pid = pid,score = score,extData = extData,time = time})
end

local function deleteGroupData(group,key,id)
	database.update("delete from group_score where id = %d",id)
	table.remove(groupData[group],key)
end

local function test()
        for k = 1, 50 do
            insertGroupData(math.random(1,100),math.random(1000,2000), math.random(1,3), math.random(0,100), 'xxx',loop.now())
        end

        for k,v in pairs(groupData) do
                local n = table.getn(groupData[k])
                for i = 1, n do
                        print(k,v[i].id,v[i].pid,v[i].score,v[i].extData,v[i].time)
                end

                print('============== a common test ====================')
        end
end

local function testdata()
	print("================================ a database test  ===================================")
	for k,v in pairs(groupData) do
		print('第'..k..'组:')
		local n = table.getn(groupData[k])
                for i = 1, n do
                        print(v[i].id,k,v[i].pid,v[i].score,v[i].extData,v[i].time)
                end
        end
end

local function loadDatabase(dbname)   --加载数据库。。。
        local ok,result = database.query("select id,pid,groupid,score,extradata,time from %s",dbname)
	print(#result)
        if ok and #result >=1 then
                for i = 1,#result do
                        local row = result[i]
			insertGroupData(row.pid,row.groupid,row.score,base64.decode(row.extradata),row.time,row.id) 
                end
        end
end

local function sortGroupScoreDes(a,b)
	if a.score == b.score then
		return a.pid < b.pid
	else
		return a.score > b.score
	end
end

local function databaseInsert(pid,group,score,extData,time)
	local ok = database.update("insert into group_score (pid,groupid,score,extradata,time) values(%d,%d,%d,'%s',%d); ",pid,group,score,base64.encode(extData),time)
	if not ok then
		return nil
	else
		local id = database.last_id()
		return id		
	end
end

-- service:on(Command.S_SERVICE_REGISTER_REQUEST,  onServiceRegister) 

local function handleGroupData(pid,group,score,extData,time,delKey,delId)
        local tmpGroupData = groupData[group]
	local id = databaseInsert(pid,group,score,extData,time)
	database.update("delete from group_score where id = %d",delId)
	tmpGroupData[delKey] = {id = id,pid = pid,score = score,extData = extData,time = time}
end

local function addRecordData(pid,group,score,extData,time)
	if not groupData[group] then
		groupData[group] = {}		
	end
	local tmpGroupData = groupData[group]
        local nmember = #tmpGroupData	
	if nmember < MAX_GROUP_RECORD_COUNT then			
		insertGroupData(pid,group,score,extData,time)
		table.sort(tmpGroupData,sortGroupScoreDes)
		return
	end	
	local dkey = 1
	local delRecord = tmpGroupData[1]
	for k,v in ipairs(tmpGroupData) do
		if delRecord.time > tmpGroupData[k].time then
			delRecord = tmpGroupData[k]
			dkey = k
		end 
	end

	if loop.now() - delRecord.time > EFFECTIVE_TIME then			
		handleGroupData(pid,group,score,extData,time,dkey,delRecord.id)
                table.sort(tmpGroupData,sortGroupScoreDes)
	else
		if score > tmpGroupData[nmember].score then
                        local did = tmpGroupData[nmember].id
			handleGroupData(pid,group,score,extData,time,nmember,did)
			table.sort(tmpGroupData,sortGroupScoreDes)
                end
	end
end

local function onSearchGroupScore(conn,id,request)
	local sn = request[1] or 0
	local time = loop.now()
	local group = request[1]

	conn:sendClientRespond(Command.C_GROUP_SCORE_RESPOND,pid,{sn,Command.RET_SUCCESS,time,groupData[group]} )
end

local groupscore = {}

function groupscore.RegisterCommand(service)
	service:on(Command.C_ADD_GROUP_SCORE_REQUEST, function(conn,pid,request)
		local sn       = request[1] or 0
		local group    = request[2]
		local score    = request[3]
		local extData  = request[4]
		local time     = loop.now()

		addRecordData(pid,group,score,extData,time)

	end)
	service:on(Command.C_GROUP_SCORE_REQUEST,onSearchGroupScore)
end


loadDatabase("group_score")
--[[
table.sort(groupData[1],sortGroupScoreDes)
table.sort(groupData[2],sortGroupScoreDes)
table.sort(groupData[3],sortGroupScoreDes)
table.sort(groupData[4],sortGroupScoreDes)
table.sort(groupData[5],sortGroupScoreDes)
--]]
--testdata()
--database.update("truncate table group_score;")
--database.update("insert into group_score (pid,groupid,score,extradata,time) values(%d,%d,%d,'%s',%d); ",math.random(10),math.random(5),math.random(100),base64.encode('人生自古谁无死'),20171025163001)
--[[
math.randomseed(os.time())
for i = 1,10 do
	database.update("insert into group_score (pid,groupid,score,extradata,time) values(%d,%d,%d,'%s',%d); ",math.random(10),math.random(5),math.random(100),'zzz',20171025163001)
end
--database.update("truncate table group_score;")

--]]

return groupscore
