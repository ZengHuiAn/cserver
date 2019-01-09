local class = require "utils.class"
local Thread = require "utils.Thread"
local DialogCfg = require "config.DialogConfig"

local DialogStack = class()

function DialogStack:_init_()
	self.stack = {};
	self.PushPref_stact = {}
	self.PushPref_list = {}
end

function DialogStack:Keep(keep)
	self.stack[#self.stack].keep = keep;
end

local function haveComponent(xx, type)
	local com = xx:GetComponent(typeof(type))
	if not com then
		return false;
	end

	--if string.sub(tostring(com), 1, 5) == "null:" then
	if utils.SGKTools.GameObject_null(com) then
		return false;
	end

	return com;
end

local function findParent(prefab,tag)
	local findType = UnityEngine.RectTransform;
	local isNGUI = false;

	tag = tag or "UGUIRoot"
	for _, _tag in ipairs({tag,"UGUIRoot","NGUIRoot", }) do
		local parent = UnityEngine.GameObject.FindWithTag(_tag);
		if parent and haveComponent(parent, findType) then
			return parent, isNGUI;
		end
	end
	return nil, isNGUI;
end

local function ControllerProfiler(controller, name)
	do return controller end;

	if UnityEngine.Application.isEditor and controller.Start then
		local Start = controller.Start;
		controller.Start = function(...)
			local profiler = require "perf.profiler"
			profiler.start();
			Start(...)
			print(name .. " Start cost " .. profiler.time() .. "ms\n" .. profiler.report('TOTAL'));
			profiler.stop();
		end
	end
	return controller
end

function DialogStack:PushPref(name, arg, parObj, add, func)
    if add then
    	if DialogCfg.GetCfg(name) then
            if not DialogCfg.GetCfg(name).Ignore then
                DispatchEvent("LOCAL_DIALOGSTACK_PUSHMID", false)
            end
        else
            DispatchEvent("LOCAL_DIALOGSTACK_PUSHMID", true)
        end
    end
	self:LoadAsync("prefabs/"..name,function (prefab)
		--local prefab = SGK.ResourcesManager.Load("prefabs/" .. name);
		if prefab == nil then
			print("[DialogStack] prefab", name, " not exists");
			self.PushPref_list[name] = nil;
            if func then
                func()
            end
			return;
		end

		local parent, isNGUI = findParent(prefab);
		if parObj ~= nil then
			parent = parObj
		end

		if not parent then
			ERROR_LOG("[DialogStack] no parent");
			return
		end

        if utils.SGKTools.GameObject_null(parent) then
            ERROR_LOG("[DialogStack] no parent");
            if func then
                func()
            end
			return
        end

		local dialog = CS.UnityEngine.GameObject.Instantiate(prefab,parent.transform)
		if dialog == nil then
			print("[DialogStack] Instantiate failed");
            if func then
                func()
            end
			return;
		end

        local _dialogAnim = dialog:GetComponent(typeof(SGK.DialogAnim))
        if _dialogAnim and _dialogAnim.OnStart then
            _dialogAnim:PlayStartAnim()
        end

		local scriptFileName = "view/" .. name .. ".lua";
		local luaBehaviour = dialog:GetComponent(typeof(SGK.LuaBehaviour));
		if luaBehaviour == nil then
			luaBehaviour = dialog:AddComponent(typeof(SGK.LuaBehaviour))
		elseif luaBehaviour.luaScriptFileName ~= "" then
			scriptFileName = luaBehaviour.luaScriptFileName
		end
		local controller = nil
			local script = SGK.FileUtils.LoadStringFromFile(scriptFileName);
			if script then
				local func = loadstring(script, scriptFileName);
				if func then
					controller = ControllerProfiler(func(), scriptFileName);
				end
			end
		if controller then
			controller.savedValues = {};
			luaBehaviour:LoadScript(scriptFileName, controller, arg);
		end
		if add then
			table.insert(self.PushPref_stact,dialog)
		end
		self.PushPref_list[name] = dialog
		DispatchEvent("PushPref_Load_success",{name = name})
        if func then
            func(dialog)
        end
		--return dialog
	end)
end

function DialogStack:LoadAsync(name, func)
	SGK.ResourcesManager.LoadAsync(name, func);
end

function DialogStack:Create(name, controller, arg, savedValues,tag,_type)
	--local prefab = SGK.ResourcesManager.Load("prefabs/" .. name);
	local cfg = DialogCfg.GetCfg(name);
	if cfg then
		if cfg.parentTag and cfg.parentTag ~= "" then
			DispatchEvent("LOCAL_DIALOGSTACK_PUSHMID", false)
		end
	else
		DispatchEvent("LOCAL_DIALOGSTACK_PUSHMID", true)
	end

	local parent, _ = findParent(nil,tag);
	if not parent then
        ERROR_LOG("parent error")
		return;
	end

    local parent, isNGUI = findParent(nil, tag)
    if not parent then
        ERROR_LOG("[DialogStack] no parent");
        return
    end

	self:LoadAsync("prefabs/"..name,function (prefab)
		if prefab == nil then
			print("[DialogStack] prefab", name, " not exists");
			return;
		end

		local dialog = nil;
		if isNGUI then
			ERROR_LOG('!!!! dialog', name, "is ngui !!!")
			dialog = CS.NGUITools.AddChild(parent, prefab);
		else
			local canvasScaler = haveComponent(prefab, UnityEngine.UI.CanvasScaler);
			if canvasScaler then
				ERROR_LOG('!!!! dialog', name, "have canvas !!!")
				dialog = CS.UnityEngine.GameObject.Instantiate(prefab)
			else
				dialog = CS.UnityEngine.GameObject.Instantiate(prefab)
				if parent then
					dialog.transform:SetParent(parent.transform, false);
				end
			end
		end

		if dialog == nil then
			print("[DialogStack] Instantiate failed");
			return;
		end

        --当push时才播放动画 从堆栈中恢复时不执行
        if _type == 1 then
            local _dialogAnim = dialog:GetComponent(typeof(SGK.DialogAnim))
            if _dialogAnim and _dialogAnim.OnStart then
                _dialogAnim:PlayStartAnim()
            end
        end

		local luaBehaviour = dialog:GetComponent(typeof(SGK.LuaBehaviour));
		if luaBehaviour == nil then
			luaBehaviour = dialog:AddComponent(typeof(SGK.LuaBehaviour))
		end

		local scriptFileName = "view/" .. name .. ".lua";
		if not controller then
			local script = SGK.FileUtils.LoadStringFromFile(scriptFileName);
			if script then
				local func = loadstring(script, scriptFileName);
				if func then
					controller = ControllerProfiler(func(), scriptFileName);
				end
			end
		end

		if controller then
			controller.savedValues = savedValues or {};
			luaBehaviour:LoadScript(scriptFileName, controller, arg);
		end
		-- local script = "Assets/Lua/view/" .. name .. ".lua"; -- TODO: fix file path
		-- controller = controller or loadstring(script)();

		-- collectgarbage();
		-- CS.UnityEngine.Resources.UnloadUnusedAssets()
        for i,v in ipairs(self.PushPref_stact) do
            --if string.sub(tostring(v.gameObject), 1, 5) ~= "null:"  then
            if utils.SGKTools.GameObject_null(v.gameObject) == false then
                v:SetActive(_type == 2)
            else
                self:Pop()
            end
        end
		if _type == 1 then
			self:Push_tableInsert(name, arg, tag, dialog, controller,savedValues, #self.PushPref_stact)
		elseif _type == 2 then
			local top = self.stack[#self.stack]
			if top and not top.gameObject then
				top.gameObject = dialog
			end
		end
	end)
	--return dialog, controller;
end
function DialogStack:Push(name, arg,tag)
	local savedValues = {}
	self:Create(name, nil, arg, savedValues,tag,1)
end

function DialogStack:Push_tableInsert(name,arg,tag,dialog,controller,savedValues, stactDialogSize)
	--local savedValues = {}
	if not dialog then
        DispatchEvent("LOCAL_NOTIFY_MAPSCENE_PUSH_ERROR", {name = name})
		return;
	end

	-- print("DialogStack:Push", name, #self.stack);

	local top = self.stack[#self.stack];
	if top and not top.keep and top.gameObject then
		-- print("destroy dialog")
		UnityEngine.GameObject.Destroy(top.gameObject);
		top.gameObject = nil;
	end
    table.insert(self.stack, {
		name = name,
		arg = arg,
		savedValues = savedValues,
		gameObject = dialog,
		controller = controller,
		tag= tag,
        stactDialogSize = stactDialogSize,
	})
end

function DialogStack:GetStack()
	return self.stack
end

function DialogStack:Top()
	return self.stack[#self.stack];
end


function DialogStack:GetPref_stact()
	return self.PushPref_stact
end
function DialogStack:GetPref_list(name)
	local t = type(name)
	if t == "string" then
		return self.PushPref_list[name]
	else
		return name
	end
end
function DialogStack:Destroy(name)
	if self.PushPref_list[name] and self.PushPref_list[name] ~= {} then
		UnityEngine.GameObject.Destroy(self.PushPref_list[name])
		self.PushPref_list[name] = nil
	else
		self.PushPref_list[name] = nil
	end
end
function DialogStack:Pop()
	local top = self.stack[#self.stack];
	if top then
        if top.stactDialogSize then
            if top.stactDialogSize < #self.PushPref_stact then
                self:deActive(top)
                return
            end
        end
		local state,success= true
		if top.controller and top.controller.deActive then
			success,state = pcall(top.controller.deActive, top.controller, {Function = function()
				self:deActive(top)
			end})
			if not success then
				ERROR_LOG(state);
				self:deActive(top);
				return;
			end
		end
		if state then
			self:deActive(top)
		end
		utils.UserDefault.Save();
    else
        if #self.PushPref_stact > 0 then
            UnityEngine.GameObject.Destroy(self.PushPref_stact[#self.PushPref_stact]);
            table.remove(self.PushPref_stact, #self.PushPref_stact)
            DispatchEvent("PrefStact_POP")
        end
	end
end

function DialogStack:deActive(top)
    if top.stactDialogSize and top.stactDialogSize < #self.PushPref_stact then
		UnityEngine.GameObject.Destroy(self.PushPref_stact[#self.PushPref_stact]);
        table.remove(self.PushPref_stact, #self.PushPref_stact)
        DispatchEvent("PrefStact_POP")
		return
	end
	if top.gameObject then
		UnityEngine.GameObject.Destroy(top.gameObject);
	end

	self.stack[#self.stack] = nil;
	top = self.stack[#self.stack];
	if top and top.gameObject == nil then
		self:Create(top.name, top.controller, nil, top.savedValues,top.tag,2);
	end
    DispatchEvent("LOCAL_DIALOGSTACK_POP");
	if #self.stack == 0 then
		DispatchEvent("UIRoot_refresh",{IsActive = false});
		module.guideModule.PlayByType(4, 0.1)
		module.guideModule.PlayByType(1, 0.2)
	end
end

function DialogStack:Replace(name, arg)
	self:Pop();
	self:Push(name, arg)
end

function DialogStack:Show()
	local top = self.stack[#self.stack]
	if top and not top.gameObject then
		self:Create(top.name, top.controller, nil, top.savedValues,top.tag,2);
	end
end

function DialogStack:HideAll()
	for _, info in ipairs(self.stack) do
		if info.gameObject then
			UnityEngine.GameObject.Destroy(info.gameObject)
			info.gameObject = nil;
		end
	end
end


local _global_dialog_stack = nil;
local _instance = nil;
local function SetInstance(instance)
	if _instance then
		_instance:HideAll()
	end

	_global_dialog_stack = DialogStack();

	instance = instance or _global_dialog_stack;
	_instance = instance;

	_instance:Show();

	return _instance;
end

local function GetInstance()
	if not _instance then
		_instance = DialogStack();
	end
	return _instance;
end

local function GetStack()
	return GetInstance():GetStack()
end

local function Top()
	return GetInstance():Top()
end

local function Show()
    return GetInstance():Show()
end

local function GetPref_stact()
	return GetInstance():GetPref_stact()
end
local function GetPref_list(name)
	return GetInstance():GetPref_list(name)
end
local function Destroy(name)
	GetInstance():Destroy(name)
end
local thread = Thread.Create(function()
	while true do
		local cmd, name ,arg, parObj, func = Thread.Self():read_message()
		-- print("DialogStack", cmd, name, arg, parObj);
		if cmd == "PUSH" then
			GetInstance():Push(name, arg,parObj)
			WaitForEndOfFrame();
			DispatchEvent("LOCAL_NOTIFY_MAPSCENE_PUSH", {name = name})
			DispatchEvent("UIRoot_refresh",{IsActive = true});
			module.guideModule.PlayByType(4, 0.1)
			module.guideModule.PlayByType(1, 0.2)
		elseif cmd == "POP" then
			GetInstance():Pop()
		elseif cmd == "PUSH_PREF" then
			GetInstance():PushPref(name,arg,parObj, false, func)
			WaitForEndOfFrame();
		end
	end
end):Start()


local function Pop()
	thread:send_message('POP');
	-- GetInstance():Pop()
end

local function Push(name, arg,tag)
    if not DialogCfg.CheckDialog(name or "") then
        return
    end
    module.EncounterFightModule.GUIDE.StopPushDialog()
	thread:send_message('PUSH', name, arg,tag);
	-- GetInstance():Push(name, arg)
	--DispatchEvent("UIRoot_refresh",{IsActive = true});
end

local function Replace(name, arg,tag)
	thread:send_message('POP');
	thread:send_message('PUSH', name, arg,tag);
	-- GetInstance():Replace(name, arg)
end

local function PushPref(name,arg, parObj, func)
	--print('PUSH_PREF')
    if not DialogCfg.CheckDialog(name or "") then
        return
    end
    GetInstance().PushPref_list[name] = {}
    module.EncounterFightModule.GUIDE.StopPushDialog()
	thread:send_message('PUSH_PREF', name, arg or {}, parObj, func);
	--return GetInstance():PushPref(name,arg,parObj)
end

local function PushPrefStact(name,arg,parObj)
	return GetInstance():PushPref(name,arg,parObj,true)
end

local function PushMapScene(name, arg, tag)
    Push(name, arg, tag)
    --utils.EventManager.getInstance():dispatch("LOCLA_MAPSCENE_OPEN_OTHER", {name = name, data = arg})
end

local function CleanAllStack()
    for i,v in ipairs(GetInstance().PushPref_stact) do
        --if v and string.sub(tostring(v), 1, 5) ~= "null:" then
        if v and utils.SGKTools.GameObject_null(v) == false then
            UnityEngine.GameObject.Destroy(v)
    	end
    end
    GetInstance().PushPref_stact = {}
    if #GetInstance().stack == 0 then
        return
    elseif #GetInstance().stack == 1 then
        GetInstance().stack[#GetInstance().stack].stactDialogSize = nil
        GetInstance():Pop()
    else
        local i = 1
        while i < #GetInstance().stack do
            table.remove(GetInstance().stack, i)
        end
        GetInstance():Pop()
    end
end

local insertDialogList = {}
local function InsertDialog(name, arg, tag)
    table.insert(insertDialogList, {name = name, arg = arg, tag = tag})
end

local function CheckInserStack()
    for i,v in ipairs(insertDialogList) do
        Push(v.name, v.arg, v.tag)
    end
    if #insertDialogList > 0 then
        insertDialogList = {}
        return true
    else
        insertDialogList = {}
        return false
    end
end

return {
	Push = Push,
	Replace = Replace,
    Pop = Pop,
    SetInstance = SetInstance,
	GetStack = GetStack,
	Show = Show,
	Top = Top,
    Show = Show,
    PushPref = PushPref,
    PushPrefStact = PushPrefStact,
    GetPref_stact = GetPref_stact,
    PushMapScene = PushMapScene,
    GetPref_list = GetPref_list,
    Destroy = Destroy,
    CleanAllStack = CleanAllStack,
    CheckInserStack = CheckInserStack,
    InsertDialog = InsertDialog,
}
