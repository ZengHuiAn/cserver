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

	if string.sub(tostring(com), 1, 5) == "null:" then
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

function DialogStack:PushPref(name, arg,parObj,add)
	self.PushPref_list[name] = {gameObject = nil}
	SceneService:LoadPrefabs("prefabs/"..name,function (prefab)
		--local prefab = SGK.ResourcesManager.Load("prefabs/" .. name);
		if prefab == nil then
			print("[DialogStack] prefab", name, " not exists");
			return;
		end

		local parent, isNGUI = findParent(prefab);
		if parObj ~= nil then
			parent = parObj
		end

		local dialog = CS.UnityEngine.GameObject.Instantiate(prefab,parent.transform)
		if dialog == nil then
			print("[DialogStack] Instantiate failed");
			return;
		end

		local luaBehaviour = dialog:GetComponent(typeof(SGK.LuaBehaviour));
		if luaBehaviour == nil then
			luaBehaviour = dialog:AddComponent(typeof(SGK.LuaBehaviour))
		end

		local scriptFileName = "view/" .. name .. ".lua";
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
		--return dialog
	end)
end

function DialogStack:Create(name, controller, arg, savedValues,tag,_type)
	--local prefab = SGK.ResourcesManager.Load("prefabs/" .. name);
    if DialogCfg.GetCfg(name) then
        DispatchEvent("LOCAL_DIALOGSTACK_PUSHMID", false)
    else
        DispatchEvent("LOCAL_DIALOGSTACK_PUSHMID", true)
    end
	SceneService:LoadPrefabs("prefabs/"..name,function (prefab)
		if prefab == nil then
			print("[DialogStack] prefab", name, " not exists");
			return;
		end

		local parent, isNGUI = findParent(prefab,tag);
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
		if _type == 1 then
			self:Push_tableInsert(name, arg, tag, dialog, controller,savedValues)
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

function DialogStack:Push_tableInsert(name,arg,tag,dialog,controller,savedValues)
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
	if self.PushPref_list[name] then
		UnityEngine.GameObject.Destroy(self.PushPref_list[name])
		self.PushPref_list[name] = nil
	end
end
function DialogStack:Pop()
	if #self.PushPref_stact > 0 then
		self:deActive()
		return;
	end
	local top = self.stack[#self.stack];
	if top then
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
	end
end

function DialogStack:deActive(top)
	if #self.PushPref_stact > 0 then
		UnityEngine.GameObject.Destroy(self.PushPref_stact[#self.PushPref_stact]);
		self.PushPref_stact[#self.PushPref_stact] = nil
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
		local cmd, name ,arg, parObj = Thread.Self():read_message()
		-- print("DialogStack", cmd, name, arg, parObj);
		if cmd == "PUSH" then
            DispatchEvent("LOCAL_NOTIFY_MAPSCENE_PUSH", {name = name})
			GetInstance():Push(name, arg,parObj)
			WaitForEndOfFrame();
			DispatchEvent("UIRoot_refresh",{IsActive = true});
		elseif cmd == "POP" then
			GetInstance():Pop()
		elseif cmd == "PUSH_PREF" then
			GetInstance():PushPref(name,arg,parObj)
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
	thread:send_message('PUSH', name, arg,tag);
	-- GetInstance():Push(name, arg)
	--DispatchEvent("UIRoot_refresh",{IsActive = true});
end

local function Replace(name, arg,tag)
	thread:send_message('POP');
	thread:send_message('PUSH', name, arg,tag);
	-- GetInstance():Replace(name, arg)
end

local function PushPref(name,arg,parObj)
	--print('PUSH_PREF')
    if not DialogCfg.CheckDialog(name or "") then
        return
    end
	thread:send_message('PUSH_PREF', name, arg, parObj);
	--return GetInstance():PushPref(name,arg,parObj)
end

local function PushPrefStact(name,arg,parObj)
	return GetInstance():PushPref(name,arg,parObj,true)
end

local function PushMapScene(name, arg, tag)
    Push(name, arg, tag)
    --utils.EventManager.getInstance():dispatch("LOCLA_MAPSCENE_OPEN_OTHER", {name = name, data = arg})
end

return {
	Push = Push,
	Replace = Replace,
    Pop = Pop,
    SetInstance = SetInstance,
    GetStack = GetStack,
	Top = Top,
    PushPref = PushPref,
    PushPrefStact = PushPrefStact,
    GetPref_stact = GetPref_stact,
    PushMapScene = PushMapScene,
    GetPref_list = GetPref_list,
    Destroy = Destroy,
}
