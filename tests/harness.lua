-- Minimal WoW API mock to exercise ActionBarSwitcher's logic in plain Lua 5.1.
-- Usage (from the repository root): lua5.1 tests/harness.lua [ActionBarSwitcher] [enUS|deDE]
local ADDON_DIR = arg[1] or "ActionBarSwitcher"
local LOCALE = arg[2] or "enUS"

local inCombat = false
local actionBarPage = 1
local chat = {}
local errors = {}

-- frame mock ---------------------------------------------------------------
local Frame = {}
Frame.__index = Frame
local frames = {}

local function newFrame(kind, name, parent, template)
	local f = setmetatable({ _attrs = {}, _scripts = {}, _name = name, _parent = parent, _template = template or "", _shown = true, _refs = {} }, Frame)
	if name then _G[name] = f end
	frames[#frames + 1] = f
	return f
end

function Frame:IsProtected()
	local p = self._template:find("Secure") ~= nil or self._protected
	return p, p
end
function Frame:SetAttribute(k, v)
	if inCombat and self:IsProtected() and not _G.__secureExec then
		error("ADDON_ACTION_BLOCKED: SetAttribute in combat on " .. tostring(self._name))
	end
	self._attrs[k] = v
	if self._onAttr then self:_onAttr(k, v) end
end
function Frame:GetAttribute(k) return self._attrs[k] end
function Frame:SetFrameRef(label, f) self._refs[label] = f end
function Frame:GetName() return self._name end
function Frame:GetParent() return self._parent end
function Frame:SetScript(s, fn) self._scripts[s] = fn end
function Frame:GetScript(s) return self._scripts[s] end
function Frame:HookScript() end
function Frame:RegisterEvent(e) self._events = self._events or {}; self._events[e] = true end
function Frame:UnregisterEvent(e) if self._events then self._events[e] = nil end end
function Frame:IsShown() return self._shown end
function Frame:Show() self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end
function Frame:Hide() local was = self._shown; self._shown = false; if was and self._scripts.OnHide then self._scripts.OnHide(self) end end
local noop = function() end
for _, m in ipairs({ "SetSize", "SetFrameStrata", "SetClampedToScreen", "SetMovable", "RegisterForClicks", "RegisterForDrag",
	"SetAllPoints", "SetColorTexture", "SetPoint", "ClearAllPoints", "SetWordWrap", "SetText", "SetAlpha", "EnableMouse",
	"StartMoving", "StopMovingOrSizing", "SetDrawLayer", "EnableKeyboard", "SetPropagateKeyboardInput", "SetToplevel",
	"Raise", "EnableMouseWheel", "SetJustifyH", "SetWidth" }) do
	Frame[m] = function(self, ...)
		if m == "SetText" then self._text = ... end
		if m == "SetAlpha" then self._alpha = ... end
	end
end
function Frame:CreateTexture() return newFrame("Texture") end
function Frame:CreateFontString() return newFrame("FontString") end
function Frame:GetPoint() return "BOTTOM", UIParent, "BOTTOM", 0, 140 end

function CreateFrame(kind, name, parent, template)
	return newFrame(kind, name, parent, template)
end
UIParent = newFrame("Frame", "UIParent")

-- Blizzard action bars: bar frame with "actionpage", 12 buttons each that
-- compute their slot like SecureActionButtonMixin:CalculateAction.
local BARDEF = { { "MultiBarBottomLeft", 6 }, { "MultiBarBottomRight", 5 }, { "MultiBarRight", 3 }, { "MultiBarLeft", 4 },
	{ "MultiBar5", 13 }, { "MultiBar6", 14 }, { "MultiBar7", 15 } }
for _, d in ipairs(BARDEF) do
	local bar = newFrame("Frame", d[1], UIParent, "")
	bar._attrs.actionpage = d[2]
	bar._shown = (d[1] == "MultiBarBottomLeft") -- user only uses bars 1 + 2
	for i = 1, 12 do
		local b = newFrame("CheckButton", d[1] .. "Button" .. i, bar, "SecureActionButtonTemplate")
		b._id = i
		b._attrs["useparent-actionpage"] = true
		b._onAttr = function(self) self.action = self:CalculateAction() end
		function b:CalculateAction()
			local page = self._attrs.actionpage
			if page == nil and self._attrs["useparent-actionpage"] then page = self._parent._attrs.actionpage end
			return self._id + (page - 1) * 12
		end
		b.action = b:CalculateAction()
	end
end

-- Restricted environment ---------------------------------------------------
local handles = setmetatable({}, { __mode = "k" })
local function handle(frame)
	if not frame then return nil end
	if handles[frame] then return handles[frame] end
	local h = {}
	function h:SetAttribute(k, v)
		assert(type(k) == "string" and not k:match("^_"), "Invalid attribute name")
		frame:SetAttribute(k, v)
	end
	function h:GetAttribute(k) return frame:GetAttribute(k) end
	function h:GetFrameRef(l) return handle(frame._refs[l]) end
	function h:RunAttribute(attr, ...) return _G.__runSnippet(frame, frame:GetAttribute(attr), "self,...", handle(frame), handle(frame), ...) end
	function h:CallMethod(m, ...) local fn = frame[m]; _G.__secureExec = false; fn(frame, ...); _G.__secureExec = true end
	handles[frame] = h
	return h
end

local RESTRICTED_GLOBALS = { tonumber = tonumber, tostring = tostring, strmatch = string.match, select = select,
	math = math, string = string, format = string.format, IsShiftKeyDown = function() return _G.__shift end }

function _G.__runSnippet(ownerFrame, body, signature, ownerHandle, ...)
	local env = setmetatable({ owner = ownerHandle, control = ownerHandle }, { __index = RESTRICTED_GLOBALS })
	local factory = assert(loadstring("return function(" .. signature .. ") " .. body .. " end"))
	setfenv(factory, env)
	local fn = factory()
	local prev = _G.__secureExec
	_G.__secureExec = true
	local r = { pcall(fn, ...) }
	_G.__secureExec = prev
	if not r[1] then error("snippet error: " .. tostring(r[2])) end
	return unpack(r, 2)
end

function SecureHandlerExecute(frame, body)
	assert(not inCombat, "Cannot use SecureHandlers API during combat")
	_G.__runSnippet(frame, body, "self", handle(frame), handle(frame))
end

function SecureHandlerWrapScript(frame, script, header, pre, post)
	assert(not inCombat)
	frame._wrap = { header = header, pre = pre, post = post }
end

-- Emulates a hardware click (binding or mouse) going through the wrapper
-- and SecureActionButton_OnClick ("actionbar" type).
local function Click(frame, button, down)
	if down == nil then down = true end
	if down and not frame._clickDown then end
	local w = frame._wrap
	local newbutton, message = _G.__runSnippet(w.header, w.pre, "self,button,down", handle(w.header), handle(frame), button, down)
	if newbutton == false then return "cancelled" end
	if newbutton then button = tostring(newbutton) end
	-- SecureActionButton_OnClick: useOnKeyDown attribute is true, so act on down.
	if down == (frame:GetAttribute("useOnKeyDown") and true or false) then
		local t = frame:GetAttribute("type")
		if t == "actionbar" then
			actionBarPage = tonumber(frame:GetAttribute("action"))
		end
	end
	if w.post and message ~= nil then
		_G.__runSnippet(w.header, w.post, "self,message,button,down", handle(w.header), handle(frame), message, button, down)
	end
	return "ok"
end

-- Key binding API ------------------------------------------------------------
local bindings = { ["SHIFT-1"] = "ACTIONPAGE1" }
_G.BINDING_NAME_ACTIONPAGE1 = "Action Page 1"
function GetBindingKey(cmd)
	local keys = {}
	for k, c in pairs(bindings) do if c == cmd then keys[#keys + 1] = k end end
	table.sort(keys)
	return unpack(keys)
end
function GetBindingAction(key) return bindings[key] or "" end
function SetBinding(key, cmd) bindings[key] = cmd; return true end
function SetBindingClick(key, button, mb) bindings[key] = "CLICK " .. button .. ":" .. (mb or "LeftButton"); return true end
function GetBindingText(k) return k end
local savedBindings = 0
function SaveBindings() savedBindings = savedBindings + 1 end
function GetCurrentBindingSet() return 1 end
function IsAltKeyDown() return false end
function IsControlKeyDown() return false end
UISpecialFrames = {}
tinsert = table.insert
function CreateSettingsButtonInitializer(name, text, fn) _G.__settingsButton = fn; return {} end

-- Misc API ------------------------------------------------------------------
C_ActionBar = {
	GetActionBarPage = function() return actionBarPage end,
	SetActionBarPage = function(p) actionBarPage = p end,
}
function InCombatLockdown() return inCombat end
function GetLocale() return LOCALE end
function IsShiftKeyDown() return _G.__shift end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat + 1] = m end }
GameTooltip = { SetOwner = noop, SetText = noop, AddLine = noop, Show = noop, Hide = noop }
GameTooltip_Hide = noop
function geterrorhandler() return function(e) errors[#errors + 1] = e end end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
SlashCmdList = {}

-- Settings API stub (records what gets registered)
local settingsLog = { settings = {}, categories = 0 }
Settings = {
	VarType = { Number = "number", Boolean = "boolean" },
	RegisterVerticalLayoutCategory = function(name) settingsLog.categories = settingsLog.categories + 1; return { GetID = function() return 1 end }, { AddInitializer = noop } end,
	RegisterVerticalLayoutSubcategory = function(p, name) settingsLog.categories = settingsLog.categories + 1; return { GetID = function() return 2 end }, { AddInitializer = noop } end,
	RegisterProxySetting = function(cat, var, vt, name, def, get, set)
		local s = { var = var, get = get, set = set, def = def }
		settingsLog.settings[var] = s
		return s
	end,
	CreateControlTextContainer = function()
		local c = { data = {} }
		function c:Add(v, l) self.data[#self.data + 1] = { value = v, label = l } end
		function c:GetData() return self.data end
		return c
	end,
	CreateDropdown = function(cat, setting, opts, tt)
		setting.opts = opts(); setting.tt = type(tt) == "function" and tt() or tt
	end,
	CreateCheckbox = noop,
	RegisterAddOnCategory = noop,
	OpenToCategory = function() settingsLog.opened = true end,
}
function CreateSettingsListSectionHeaderInitializer() return {} end

-- Load addon -----------------------------------------------------------------
local ns = {}
local function load(file)
	local fn = assert(loadfile(ADDON_DIR .. "/" .. file))
	fn("ActionBarSwitcher", ns)
end
load("Locales.lua")
load("Core.lua")
load("KeyBinds.lua")
load("Options.lua")

local function fire(event, ...)
	for _, f in ipairs(frames) do
		if f._events and f._events[event] and f._scripts.OnEvent then
			f._scripts.OnEvent(f, event, ...)
		end
	end
end

-- Tests ------------------------------------------------------------------------
local failures = 0
local function check(cond, msg)
	if cond then print("  ok   " .. msg) else failures = failures + 1; print("  FAIL " .. msg) end
end
local function bar2Slot1() return MultiBarBottomLeftButton1.action end

print("== load / init")
fire("ADDON_LOADED", "ActionBarSwitcher")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", true, false)
local btn = ActionBarSwitcherButton
check(btn ~= nil, "switch button created")
check(ActionBarSwitcherHeader:GetAttribute("abs-count") == 2, "set count pushed")
check(actionBarPage == 1, "bar1 on page 1 (set 1)")
check(bar2Slot1() == 61, "bar2 shows default page 6 (slot 61)")
check(btn.Text._text == "Set 1", "button shows set name")
check(#errors == 0, "no errors while creating options (" .. tostring(errors[1]) .. ")")
check(settingsLog.categories == 5, "1 category + 4 set subcategories")

print("== keybind 'next' out of combat")
check(Click(btn, "next") == "ok", "click accepted")
check(actionBarPage == 2, "bar1 -> page 2")
check(bar2Slot1() == 145, "bar2 -> page 13 (slot 145)")
check(MultiBarBottomLeftButton12.action == 156, "bar2 button 12 -> slot 156")
check(ns.DB.current == 2 and btn.Text._text == "Set 2", "DB/current + label updated via CallMethod")

print("== keybind 'next' IN COMBAT (wraps around)")
inCombat = true
check(Click(btn, "next") == "ok", "click accepted in combat")
check(actionBarPage == 1, "bar1 -> page 1")
check(bar2Slot1() == 61, "bar2 back to default page 6")
check(MultiBarBottomLeftButton1:GetAttribute("actionpage") == nil, "attribute cleared (falls back to bar)")

print("== direct set bindings / prev / mouse")
check(Click(btn, "set2") == "ok" and actionBarPage == 2 and bar2Slot1() == 145, "set2 binding")
check(Click(btn, "set2") == "ok" and actionBarPage == 2, "set2 again is idempotent")
check(Click(btn, "set3") == "cancelled", "set3 rejected while count = 2")
check(Click(btn, "prev") == "ok" and ns.DB.current == 1, "prev binding")
check(Click(btn, "RightButton") == "ok" and ns.DB.current == 2, "right click = previous (wraps)")
_G.__shift = true
check(Click(btn, "LeftButton") == "cancelled" and ns.DB.current == 2, "shift+click does not switch (drag)")
_G.__shift = false

print("== combat restrictions for insecure paths")
ns.SwitchTo(1)
check(ns.DB.current == 2 and chat[#chat] == ns.L.IN_COMBAT:gsub("^", "|cff33ff99" .. ns.L.TITLE .. "|r: "), "/abs 1 refused in combat")
local s = settingsLog.settings["ABS_Set2_Bar2"]
s.set(3)
check(ns.DB.sets[2].pages[2] == 3 and bar2Slot1() == 145, "config change in combat is deferred")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check(bar2Slot1() == 25, "after combat: bar2 now on page 3 (slot 25)")

print("== 3 sets incl. bar 3, slash commands")
settingsLog.settings["ABS_SetCount"].set(3)
settingsLog.settings["ABS_Set3_Bar1"].set(1)
settingsLog.settings["ABS_Set3_Bar2"].set(14)
settingsLog.settings["ABS_Set3_Bar3"].set(15)
check(ActionBarSwitcherHeader:GetAttribute("abs-managed-3") == true, "bar3 now managed")
SlashCmdList.ACTIONBARSWITCHER("3")
check(ns.DB.current == 3 and actionBarPage == 1 and bar2Slot1() == 157 and MultiBarBottomRightButton1.action == 169, "/abs 3 applies set 3")
inCombat = true
Click(btn, "next")
check(ns.DB.current == 1 and MultiBarBottomRightButton1.action == 49, "set1 resets bar3 to default page 5")
inCombat = false
SlashCmdList.ACTIONBARSWITCHER("name 1 Raid")
check(ns.DB.sets[1].name == "Raid" and btn.Text._text == "Raid", "rename")
SlashCmdList.ACTIONBARSWITCHER("hide")
check(btn._alpha == 0, "hide -> alpha 0 (bindings keep working)")
SlashCmdList.ACTIONBARSWITCHER("show")
check(btn._alpha == 1, "show")

print("== un-managing a bar resets it")
settingsLog.settings["ABS_Set3_Bar3"].set(0)
SlashCmdList.ACTIONBARSWITCHER("3")
check(MultiBarBottomRightButton1.action == 49 and MultiBarBottomRightButton1:GetAttribute("actionpage") == nil, "bar3 untouched/default")

print("== conflict check")
local before = #chat
settingsLog.settings["ABS_Set2_Bar2"].set(8)
local found = ns.CheckConflicts(true)
check(found >= 1, "bonus page 8 warned (" .. found .. ")")
settingsLog.settings["ABS_Set2_Bar2"].set(2)
check(ns.CheckConflicts(true) >= 1, "bar2 page 2 == bar1 page 2 in set 2 warned")
settingsLog.settings["ABS_Set2_Bar2"].set(13)
check(ns.CheckConflicts(true) == 0, "default style config has no conflicts")

print("== reset")
SlashCmdList.ACTIONBARSWITCHER("reset")
check(actionBarPage == 1 and bar2Slot1() == 61, "everything back to Blizzard defaults")

print("== reload: saved state restored")
local saved = ActionBarSwitcherCharDB
check(saved.current == ns.DB.current, "SavedVariables table is the live DB")

print("== key binding window")
check(chat[1] and chat[1]:find("bind"), "first-login hint about /abs bind")
_G.__settingsButton()
local kb = ActionBarSwitcherKeyBindFrame
check(kb and kb:IsShown(), "settings button opens the window")
local row = kb.rows[1]
row.Key._scripts.OnClick(row.Key, "LeftButton")
check(row.Key._text:find("..."), "field waits for a key")
_G.__shift = true
kb._scripts.OnKeyDown(kb, "LSHIFT")
check(GetBindingKey("CLICK ActionBarSwitcherButton:next") == nil, "modifier alone is ignored")
kb._scripts.OnKeyDown(kb, "1")
_G.__shift = false
check(GetBindingKey("CLICK ActionBarSwitcherButton:next") == "SHIFT-1", "Shift+1 bound to 'next set'")
check(chat[#chat - 1]:find("Action Page 1"), "warned that Shift+1 was used before")
check(savedBindings == 1, "bindings saved")
row.Key._scripts.OnClick(row.Key, "LeftButton")
kb._scripts.OnKeyDown(kb, "F5")
check(GetBindingKey("CLICK ActionBarSwitcherButton:next") == "F5" and bindings["SHIFT-1"] == nil, "rebinding replaces the old key")
row.Key._scripts.OnClick(row.Key, "LeftButton")
kb._scripts.OnKeyDown(kb, "ESCAPE")
check(GetBindingKey("CLICK ActionBarSwitcherButton:next") == "F5", "Esc cancels without change")
local row4 = kb.rows[4]
row4.Key._scripts.OnClick(row4.Key, "LeftButton")
row4.Key._scripts.OnClick(row4.Key, "Button4")
check(GetBindingKey("CLICK ActionBarSwitcherButton:set2") == "BUTTON4", "mouse button 4 bound to set 2")
row4.Key._scripts.OnClick(row4.Key, "RightButton")
check(GetBindingKey("CLICK ActionBarSwitcherButton:set2") == nil, "right click clears")
inCombat = true
row.Key._scripts.OnClick(row.Key, "LeftButton")
check(GetBindingKey("CLICK ActionBarSwitcherButton:next") == "F5" and row.Key._text == "F5", "no capture in combat")
inCombat = false
kb:Hide()

print("== options labels (" .. LOCALE .. ")")
local opts = settingsLog.settings["ABS_Set1_Bar2"].opts
print("   " .. opts[1].label .. " | " .. opts[5].label .. " | " .. opts[#opts].label)
print("   tooltip: " .. tostring(settingsLog.settings["ABS_Set4_Bar2"].tt):sub(1, 80) .. "...")
print("   binding: " .. _G["BINDING_NAME_CLICK ActionBarSwitcherButton:next"])

print(failures == 0 and "ALL TESTS PASSED" or (failures .. " FAILURE(S)"))
os.exit(failures == 0 and 0 or 1)
