local EventManager = require 'utils.EventManager';
local UserDefault = require "utils.UserDefault"
local timeModule = require "module.Time"

local notificationCenter = nil;
local notificationIndex = {};

local function Get()
    if notificationCenter == nil then
        notificationCenter = UnityEngine.GameObject.FindWithTag("UITopRoot"):GetComponent(typeof(CS.SGK.NotificationCenter));
    end
    assert(notificationCenter, "NotificationCenter not exist");
    return notificationCenter
end

-- local function AddNotification(afterSec, content, launchCallback, receiveCallback, mark)
--     mark = mark or "default"
--     local controller = Get();
--     if controller then
--         local id = controller:AddNotification(afterSec, content);
--         notificationIndex[mark] = id;
--         if launchCallback then
--             controller:AddLaunchCallbacks(id, launchCallback);
--         end
--         if receiveCallback then
--             controller:AddReceiveCallbacks(id, receiveCallback);
--         end
--     end
-- end

local System_Set_data=UserDefault.Load("System_Set_data");
local function AddNotification(period_begin, content, launchCallback, receiveCallback, mark)
    mark = mark or "default"
    local controller = Get();
    System_Set_data.SystemNoticeStatus=System_Set_data.SystemNoticeStatus==nil and true or System_Set_data.SystemNoticeStatus
    if controller then
        notificationIndex[mark] = {_period_begin=period_begin, _content=content, _launchCallback=launchCallback, _receiveCallback=launchCallback,_id=0};
        if System_Set_data.SystemNoticeStatus then
            local afterSec=period_begin-timeModule.now()
            local id = controller:AddNotification(afterSec, content);
            notificationIndex[mark]._id=id
            if launchCallback then
                controller:AddLaunchCallbacks(id, launchCallback);
            end
            if receiveCallback then
                controller:AddReceiveCallbacks(id, receiveCallback);
            end
        end
    end
end

-- local function RemoveNotification(mark)  
--     local controller = Get();
--     if controller and notificationIndex[mark] then
--         controller:CancelLocalNotification(notificationIndex[mark]);
--     end 
-- end
local function RemoveNotification(mark)  
    local controller = Get();
    if controller and notificationIndex[mark] and notificationIndex[mark]._id~=0 then
        controller:CancelLocalNotification(notificationIndex[mark]._id);
    end 
end

local System_Set_data=UserDefault.Load("System_Set_data");
EventManager.getInstance():addListener("CHECK_SYSTEM_NOTICE", function(event, pid)
    --ERROR_LOG("切换 活动推送状态")
    local controller = Get();
    if next(notificationIndex)~= nil then
        System_Set_data.SystemNoticeStatus=System_Set_data.SystemNoticeStatus==nil and true or System_Set_data.SystemNoticeStatus
        for k,v in pairs(notificationIndex) do
            if System_Set_data.SystemNoticeStatus then
                if controller and v._id==0 and v._period_begin-timeModule.now()>0 then
                    local afterSec=v._period_begin-timeModule.now()
                    local id = controller:AddNotification(afterSec, v._content);
                    notificationIndex[mark]._id=id
                    if v._launchCallback then
                        controller:AddLaunchCallbacks(id, v._launchCallback);
                    end
                    if v._receiveCallback then
                        controller:AddReceiveCallbacks(id, v._receiveCallback);
                    end
                end
            else
                if v._id~=0 then
                    controller:CancelLocalNotification(v._id);
                end
            end
        end   
    end
end)

return{
    AddNotification = AddNotification,
    RemoveNotification = RemoveNotification,
}