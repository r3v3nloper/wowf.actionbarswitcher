--[[
	ActionBar Switcher

	How it works (and why it is combat safe):

	* Action Bar 1: Blizzard's own page stays 1, so Blizzard keeps handling
	  stealth, druid forms, skyriding, vehicles, override and possess bars as
	  usual: its ActionBarController then sets MainActionBar's "actionpage"
	  to the special page (e.g. 7 for rogue stealth). We watch that attribute
	  (secure OnAttributeChanged wrapper). While it is 1 (normal), the set's
	  page is put on the 12 ActionButtons as an "actionpage" override; as soon
	  as Blizzard switches to anything else, the override is removed and the
	  buttons follow MainActionBar again.
	  Trigger: a secure state driver with [stealth] (rogue/druid), [form]
	  (druid), vehicle/override/possess/pet battle conditions. While it reports
	  "special", the override is removed, so Blizzard's own bar shows.
	  (On WoW Forever [bonusbar] stays false in rogue stealth and wrapping
	  MainActionBar's OnAttributeChanged does not fire reliably, so neither is
	  relied upon.)
	* Action Bars 2-8 (MultiBarBottomLeft, ...): every Blizzard button computes
	  its action slot as  ID + (actionpage - 1) * 12  and reads "actionpage"
	  from itself first, then from its bar. We set "actionpage" directly on the
	  12 buttons of a bar; the button's OnAttributeChanged handler then calls
	  UpdateAction() and the bar shows the new page. Clearing the attribute
	  falls back to the bar's own page.

	All attribute changes happen inside restricted (secure) snippets of a
	SecureHandler header, triggered by a SecureActionButton click (key binding
	or the on-screen button). That is the only way to modify protected frames
	in combat, and it keeps Blizzard's action buttons free of addon taint.
	The default UI is not replaced or re-skinned in any way.
]]

local ADDON_NAME, ns = ...
local L = ns.L

local MAX_SETS = 4
local NUM_BARS = 8
local BUTTONS_PER_BAR = 12
local BAR1_MAX_PAGE = 6 -- pages offered for Action Bar 1 (like Blizzard's NUM_ACTIONBAR_PAGES)

-- When does Blizzard show something special on Action Bar 1?
local function BuildBar1StateDriver()
	local special = "[petbattle][vehicleui][overridebar][possessbar][shapeshift][bonusbar]"
	local _, class = UnitClass("player")
	if class == "ROGUE" then
		special = special .. "[stealth]"
	elseif class == "DRUID" then
		special = special .. "[stealth][form]"
	end
	return special .. " special; normal"
end
local bar1StateDriver
local wrapStatus = "-"
local MAX_PAGE = 15

-- Blizzard bar frames, numbered like in Edit Mode ("Action Bar 2" ...).
-- defaultPage = the "actionpage" attribute the bar has in Blizzard's XML.
local BARS = {
	[1] = { frame = "MainActionBar", button = "ActionButton", defaultPage = 1 },
	[2] = { frame = "MultiBarBottomLeft", defaultPage = 6 },
	[3] = { frame = "MultiBarBottomRight", defaultPage = 5 },
	[4] = { frame = "MultiBarRight", defaultPage = 3 },
	[5] = { frame = "MultiBarLeft", defaultPage = 4 },
	[6] = { frame = "MultiBar5", defaultPage = 13 },
	[7] = { frame = "MultiBar6", defaultPage = 14 },
	[8] = { frame = "MultiBar7", defaultPage = 15 },
}
ns.BARS = BARS
ns.MAX_SETS = MAX_SETS
ns.NUM_BARS = NUM_BARS
ns.BAR1_MAX_PAGE = BAR1_MAX_PAGE
ns.MAX_PAGE = MAX_PAGE

-- Pages 7-12 are used by class/bonus bars (forms, stealth, skyriding, vehicles ...).
local function IsBonusPage(page)
	return page >= 7 and page <= 12
end
ns.IsBonusPage = IsBonusPage

-- Which bar normally shows a given page (nil for bonus pages).
local function BarForDefaultPage(page)
	for bar = 1, NUM_BARS do
		if BARS[bar].defaultPage == page then
			return bar
		end
	end
end
ns.BarForDefaultPage = BarForDefaultPage

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

local DEFAULTS = {
	version = 1,
	count = 2,
	current = 1,
	announce = false,
	button = { shown = true, locked = false, point = nil },
	sets = {
		-- pages[1]: 1-6 = page of Action Bar 1 (1 = normal)
		-- pages[2..8]: 0 = bar's default page, 1-15 = page to show
		{ name = "Set 1", pages = { [1] = 1, [2] = 0 } },
		{ name = "Set 2", pages = { [1] = 2, [2] = 13 } },
		{ name = "Set 3", pages = { [1] = 1, [2] = 0 } },
		{ name = "Set 4", pages = { [1] = 1, [2] = 0 } },
	},
}

local DB

function ns.DefaultPage(setIndex, bar)
	local set = DEFAULTS.sets[setIndex]
	return set and set.pages[bar] or 0
end

local function Clamp(value, minValue, maxValue, fallback)
	value = tonumber(value)
	if not value then
		return fallback
	end
	value = math.floor(value)
	if value < minValue or value > maxValue then
		return fallback
	end
	return value
end

local function SanitizeDB(db)
	if type(db) ~= "table" then
		db = {}
	end
	db.version = DEFAULTS.version
	db.count = Clamp(db.count, 1, MAX_SETS, DEFAULTS.count)
	db.current = Clamp(db.current, 1, db.count, 1)
	db.announce = db.announce and true or false

	if type(db.button) ~= "table" then
		db.button = {}
	end
	if db.button.shown == nil then
		db.button.shown = DEFAULTS.button.shown
	end
	db.button.locked = db.button.locked and true or false
	if type(db.button.point) ~= "table" then
		db.button.point = nil
	end

	if type(db.sets) ~= "table" then
		db.sets = {}
	end
	for s = 1, MAX_SETS do
		local set = db.sets[s]
		local def = DEFAULTS.sets[s]
		if type(set) ~= "table" then
			set = {}
			db.sets[s] = set
		end
		if type(set.name) ~= "string" or set.name == "" then
			set.name = def.name
		end
		if type(set.pages) ~= "table" then
			set.pages = {}
			for bar, page in pairs(def.pages) do
				set.pages[bar] = page
			end
		end
		set.pages[1] = Clamp(set.pages[1], 1, BAR1_MAX_PAGE, 1)
		for bar = 2, NUM_BARS do
			set.pages[bar] = Clamp(set.pages[bar], 0, MAX_PAGE, 0)
		end
	end
	return db
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. L.TITLE .. "|r: " .. tostring(msg))
end
ns.Print = Print

local function BarName(bar)
	return L.BAR:format(bar)
end
ns.BarName = BarName

local function SetName(index)
	local set = DB and DB.sets[index]
	return set and set.name or (L.SET .. " " .. tostring(index))
end
ns.SetName = SetName

local function GetBar1Page()
	if C_ActionBar and C_ActionBar.GetActionBarPage then
		return C_ActionBar.GetActionBarPage()
	end
	return GetActionBarPage and GetActionBarPage() or 1
end

local function SetBar1Page(page)
	if C_ActionBar and C_ActionBar.SetActionBarPage then
		C_ActionBar.SetActionBarPage(page)
	elseif ChangeActionBarPage then
		ChangeActionBarPage(page)
	end
end

local function IsBarShown(bar)
	local frame = _G[BARS[bar].frame]
	return frame and frame.IsShown and frame:IsShown() or false
end

---------------------------------------------------------------------------
-- Secure code
---------------------------------------------------------------------------

-- Runs on the header (self = header). Arguments: set index, resetUnmanaged.
-- Applies the pages of all bars for the given set.
local SNIPPET_APPLY = [[
	local set, resetUnmanaged = ...
	set = tonumber(set)
	local count = self:GetAttribute("abs-count") or 0
	if not set or set < 1 or set > count then
		return
	end
	for bar = 2, 8 do
		local managed = self:GetAttribute("abs-managed-" .. bar)
		if managed or resetUnmanaged then
			local page
			if managed then
				page = self:GetAttribute("abs-p-" .. set .. "-" .. bar) or 0
			end
			if not page or page < 1 then
				page = nil
			end
			for i = 1, 12 do
				local button = self:GetFrameRef("b" .. bar .. "-" .. i)
				if button and button:GetAttribute("actionpage") ~= page then
					button:SetAttribute("actionpage", page)
				end
			end
		end
	end
	self:SetAttribute("abs-current", set)
	self:SetAttribute("abs-bar1page", self:GetAttribute("abs-p-" .. set .. "-1") or 1)
	self:RunAttribute("_abs_bar1")
]]

-- Action Bar 1: override the page only in the normal state; otherwise let
-- the buttons follow MainActionBar (Blizzard's stealth/form/vehicle bars).
local SNIPPET_BAR1 = [[
	local mainBar = self:GetFrameRef("mainbar")
	local mainPage = mainBar and mainBar:GetAttribute("actionpage") or 1
	local page = self:GetAttribute("abs-bar1page") or 1
	if page <= 1 or mainPage ~= 1 or self:GetAttribute("state-absbar1") == "special" then
		-- Blizzard shows something special (stealth, form, vehicle ...)
		-- or was paged by hand: follow Blizzard.
		page = nil
	end
	for i = 1, 12 do
		local button = self:GetFrameRef("b1-" .. i)
		if button and button:GetAttribute("actionpage") ~= page then
			button:SetAttribute("actionpage", page)
		end
	end
]]

-- Clears every page override (all bars back to Blizzard's defaults).
local SNIPPET_RESET = [[
	self:SetAttribute("abs-bar1page", 1)
	for bar = 1, 8 do
		for i = 1, 12 do
			local button = self:GetFrameRef("b" .. bar .. "-" .. i)
			if button and button:GetAttribute("actionpage") ~= nil then
				button:SetAttribute("actionpage", nil)
			end
		end
	end
]]

-- Wrapped around the switch button's OnClick (self = switch button,
-- owner = header). Decides which set to activate and applies it. The
-- returned message (the new set index) is passed to the post snippet.
local SNIPPET_PRECLICK = [[
	if (button == "LeftButton" or button == "RightButton") and IsShiftKeyDown() then
		return false -- Shift + drag moves the button
	end
	local count = owner:GetAttribute("abs-count") or 0
	if count < 1 then
		return false
	end
	local current = owner:GetAttribute("abs-current") or 1
	local target
	if button == "next" or button == "LeftButton" then
		target = current % count + 1
	elseif button == "prev" or button == "RightButton" then
		target = (current - 2) % count + 1
	else
		target = tonumber(strmatch(button or "", "^set(%d+)$"))
	end
	if not target or target < 1 or target > count then
		return false
	end
	owner:RunAttribute("_abs_apply", target)
	return nil, target
]]

local SNIPPET_POSTCLICK = [[
	owner:CallMethod("ABS_OnSwitched", message)
]]

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

local header, switchButton
local initialized = false
local pending = {} -- work deferred until combat ends

local function UpdateButtonText()
	if switchButton then
		switchButton.Text:SetText(SetName(DB.current))
	end
end

local function UpdateButtonVisibility()
	if not switchButton then
		return
	end
	if InCombatLockdown() then
		pending.visibility = true
		return
	end
	-- The button is never hidden, so its key bindings keep working.
	-- "Hidden" just means invisible and not clickable.
	local shown = DB.button.shown
	switchButton:SetAlpha(shown and 1 or 0)
	switchButton:EnableMouse(shown)
end
ns.UpdateButtonVisibility = UpdateButtonVisibility

local function RestoreButtonPosition()
	switchButton:ClearAllPoints()
	local p = DB.button.point
	if p and p[1] then
		switchButton:SetPoint(p[1], UIParent, p[3] or p[1], p[4] or 0, p[5] or 0)
	else
		switchButton:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 140)
	end
end

local function OnSwitched(_, setIndex, silent)
	setIndex = tonumber(setIndex)
	if not setIndex or not DB then
		return
	end
	DB.current = setIndex
	UpdateButtonText()
	if DB.announce and not silent then
		Print(L.SWITCHED:format(SetName(setIndex)))
	end
	if ns.OnSetChanged then
		ns.OnSetChanged()
	end
end

local function CreateFrames()
	header = CreateFrame("Frame", "ActionBarSwitcherHeader", UIParent, "SecureHandlerStateTemplate")
	header:SetAttribute("_abs_apply", SNIPPET_APPLY)
	header:SetAttribute("_abs_bar1", SNIPPET_BAR1)
	header:SetAttribute("_abs_reset", SNIPPET_RESET)
	header:SetAttribute("_onstate-absbar1", [[self:RunAttribute("_abs_bar1")]])
	header.ABS_OnSwitched = OnSwitched

	if MainActionBar then
		header:SetFrameRef("mainbar", MainActionBar)
	end

	for bar = 1, NUM_BARS do
		local prefix = BARS[bar].button or (BARS[bar].frame .. "Button")
		for i = 1, BUTTONS_PER_BAR do
			local button = _G[prefix .. i]
			if button then
				header:SetFrameRef("b" .. bar .. "-" .. i, button)
			end
		end
	end

	switchButton = CreateFrame("Button", "ActionBarSwitcherButton", UIParent, "SecureActionButtonTemplate")
	switchButton:SetSize(120, 22)
	switchButton:SetFrameStrata("MEDIUM")
	switchButton:SetClampedToScreen(true)
	switchButton:SetMovable(true)
	-- Only react on press: one switch per key press / mouse click.
	switchButton:RegisterForClicks("AnyDown")
	switchButton:SetAttribute("useOnKeyDown", true)
	switchButton:RegisterForDrag("LeftButton")

	local border = switchButton:CreateTexture(nil, "BACKGROUND", nil, 0)
	border:SetAllPoints()
	border:SetColorTexture(1, 0.82, 0, 0.5)

	local bg = switchButton:CreateTexture(nil, "BACKGROUND", nil, 1)
	bg:SetPoint("TOPLEFT", 1, -1)
	bg:SetPoint("BOTTOMRIGHT", -1, 1)
	bg:SetColorTexture(0, 0, 0, 0.8)

	local highlight = switchButton:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.12)

	local text = switchButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("LEFT", 4, 0)
	text:SetPoint("RIGHT", -4, 0)
	text:SetWordWrap(false)
	switchButton.Text = text

	switchButton:SetScript("OnDragStart", function(self)
		if DB.button.locked or InCombatLockdown() or not IsShiftKeyDown() then
			return
		end
		self:StartMoving()
	end)
	switchButton:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint(1)
		DB.button.point = { point, "UIParent", relPoint, x, y }
	end)
	switchButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L.TITLE)
		GameTooltip:AddLine(SetName(DB.current), 1, 1, 1)
		GameTooltip:AddLine(" ")
		if ns.GetKeyText then
			local nextKey, prevKey = ns.GetKeyText("next"), ns.GetKeyText("prev")
			if nextKey or prevKey then
				GameTooltip:AddLine(L.KEYS .. ": " .. (nextKey or "-") .. " / " .. (prevKey or "-"), 1, 0.82, 0)
			end
		end
		GameTooltip:AddLine(L.TT_LEFT, 0.8, 0.8, 0.8)
		GameTooltip:AddLine(L.TT_RIGHT, 0.8, 0.8, 0.8)
		if not DB.button.locked then
			GameTooltip:AddLine(L.TT_MOVE, 0.8, 0.8, 0.8)
		end
		GameTooltip:Show()
	end)
	switchButton:SetScript("OnLeave", GameTooltip_Hide)

	SecureHandlerWrapScript(switchButton, "OnClick", header, SNIPPET_PRECLICK, SNIPPET_POSTCLICK)
	-- React whenever Blizzard changes the page of Action Bar 1.
	if MainActionBar then
		-- Extra trigger only (does not fire reliably on WoW Forever).
		local ok = pcall(SecureHandlerWrapScript, MainActionBar, "OnAttributeChanged", header,
			[[ if name == "actionpage" then owner:RunAttribute("_abs_bar1") end ]])
		wrapStatus = ok and "ok" or "failed"
	end
	bar1StateDriver = BuildBar1StateDriver()
	RegisterStateDriver(header, "absbar1", bar1StateDriver)

	RestoreButtonPosition()
	UpdateButtonVisibility()
	UpdateButtonText()
end

---------------------------------------------------------------------------
-- Configuration -> secure attributes
---------------------------------------------------------------------------

local function IsBarManaged(bar)
	local threshold = (bar == 1) and 1 or 0 -- page 1 is Action Bar 1's normal page
	for s = 1, DB.count do
		if (DB.sets[s].pages[bar] or 0) > threshold then
			return true
		end
	end
	return false
end

-- Out of combat only: apply a set without a hardware click.
-- SecureHandlerExecute runs the snippet securely, so Blizzard's buttons stay untainted.
local function ApplySetOutOfCombat(setIndex, resetUnmanaged, silent)
	SecureHandlerExecute(header, ("self:RunAttribute(%q, %d, %s)"):format("_abs_apply", setIndex, tostring(resetUnmanaged and true or false)))
	OnSwitched(nil, setIndex, silent)
end

local function PushConfig()
	if not initialized then
		return
	end
	if InCombatLockdown() then
		pending.config = true
		return
	end
	header:SetAttribute("abs-count", DB.count)
	for s = 1, MAX_SETS do
		local pages = DB.sets[s].pages
		for bar = 1, NUM_BARS do
			header:SetAttribute(("abs-p-%d-%d"):format(s, bar), s <= DB.count and (pages[bar] or 0) or 0)
		end
	end
	for bar = 2, NUM_BARS do
		header:SetAttribute("abs-managed-" .. bar, IsBarManaged(bar))
	end
	-- Blizzard only shows stealth/form bars while its own page is 1. Older
	-- versions of this addon paged it directly, so put it back once.
	if GetBar1Page() ~= 1 and IsBarManaged(1) then
		SetBar1Page(1)
	end
	if DB.current > DB.count then
		DB.current = 1
	end
	ApplySetOutOfCombat(DB.current, true, true)
end
ns.PushConfig = PushConfig

-- Public entry for the options panel / slash commands.
function ns.SwitchTo(setIndex)
	if not initialized then
		Print(L.NOT_READY)
		return
	end
	if InCombatLockdown() then
		Print(L.IN_COMBAT)
		return
	end
	if setIndex < 1 or setIndex > DB.count then
		Print(L.UNKNOWN_SET:format(tostring(setIndex)))
		return
	end
	ApplySetOutOfCombat(setIndex, false)
end

function ns.SwitchRelative(delta)
	if not DB then
		return
	end
	ns.SwitchTo((DB.current - 1 + delta) % DB.count + 1)
end

function ns.ResetAll()
	if not initialized then
		Print(L.NOT_READY)
		return
	end
	if InCombatLockdown() then
		Print(L.IN_COMBAT)
		return
	end
	SecureHandlerExecute(header, [[self:RunAttribute("_abs_reset")]])
	SetBar1Page(1)
	Print(L.RESET_DONE)
end

---------------------------------------------------------------------------
-- Conflict check
---------------------------------------------------------------------------

function ns.CheckConflicts(quietIfOk)
	local found = 0
	local function warn(msg)
		found = found + 1
		Print("|cffff8800" .. msg .. "|r")
	end

	for s = 1, DB.count do
		local pages = DB.sets[s].pages
		local used = {} -- page -> bar within this set
		local setName = SetName(s)

		for bar = 1, NUM_BARS do
			local page = pages[bar] or 0
			local effective
			if bar == 1 then
				effective = page > 0 and page or nil
			else
				effective = page > 0 and page or BARS[bar].defaultPage
			end

			if effective then
				if page > 0 and IsBonusPage(page) then
					warn(L.WARN_BONUS:format(setName, BarName(bar), page))
				end
				-- Overridden page that is the normal page of another visible, untouched bar.
				if page > 0 then
					local owner = BarForDefaultPage(page)
					if owner and owner ~= bar and owner ~= 1 and IsBarShown(owner) and (pages[owner] or 0) == 0 then
						warn(L.WARN_SHARED_VISIBLE:format(setName, BarName(bar), page, BarName(owner)))
					end
				end
				-- Two bars of the same set showing the same page.
				-- Only relevant for bars that are actually visible (bar 1 always is).
				if bar == 1 or IsBarShown(bar) then
					local other = used[effective]
					if other and (page > 0 or (pages[other] or 0) > 0) then
						warn(L.WARN_DUPLICATE:format(setName, BarName(other), BarName(bar), effective))
					end
					used[effective] = used[effective] or bar
				end
			end
		end
	end

	if found == 0 and not quietIfOk then
		Print(L.NO_CONFLICTS)
	end
	return found
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

function ns.PrintDebug()
	local function safe(fn)
		local ok, a, b = pcall(fn)
		if not ok then
			return "err"
		end
		return tostring(a) .. (b ~= nil and ("/" .. tostring(b)) or "")
	end
	local version = safe(function()
		return (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON_NAME, "Version")
	end)
	Print(("debug v%s, set %s, init %s"):format(version, tostring(DB and DB.current), tostring(initialized)))
	DEFAULT_CHAT_FRAME:AddMessage("  state: " .. safe(function() return header:GetAttribute("state-absbar1") end)
		.. "  macro: " .. safe(function() return SecureCmdOptionParse(bar1StateDriver or BuildBar1StateDriver()) end)
		.. "  stealth: " .. safe(function() return SecureCmdOptionParse("[stealth] yes; no") end)
		.. "  wrap: " .. wrapStatus
		.. "  want: " .. safe(function() return header:GetAttribute("abs-bar1page") end))
	DEFAULT_CHAT_FRAME:AddMessage("  blizz page: " .. safe(GetBar1Page)
		.. "  main bar: " .. safe(function() return MainActionBar:GetAttribute("actionpage") end)
		.. "  btn1: " .. safe(function() return ActionButton1:GetAttribute("actionpage"), ActionButton1.action end))
	DEFAULT_CHAT_FRAME:AddMessage("  bonus: " .. safe(function()
		return C_ActionBar.HasBonusActionBar and C_ActionBar.HasBonusActionBar(), GetBonusBarOffset and GetBonusBarOffset()
	end))
end

local function PrintHelp()
	for _, line in ipairs(L.HELP) do
		DEFAULT_CHAT_FRAME:AddMessage(line)
	end
end

local function SlashHandler(msg)
	msg = strtrim(msg or "")
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()

	if cmd == "" or cmd == "config" or cmd == "options" then
		if ns.OpenOptions then
			ns.OpenOptions()
		else
			PrintHelp()
		end
	elseif cmd == "help" or cmd == "?" then
		PrintHelp()
	elseif cmd == "bind" or cmd == "keys" or cmd == "key" then
		if ns.OpenKeyBindings then
			ns.OpenKeyBindings()
		end
	elseif cmd == "next" then
		ns.SwitchRelative(1)
	elseif cmd == "prev" then
		ns.SwitchRelative(-1)
	elseif tonumber(cmd) then
		ns.SwitchTo(tonumber(cmd))
	elseif cmd == "name" or cmd == "rename" then
		local index, name = rest:match("^(%d+)%s+(.+)$")
		index = tonumber(index)
		if not index or index < 1 or index > MAX_SETS or not name then
			PrintHelp()
			return
		end
		DB.sets[index].name = strtrim(name)
		UpdateButtonText()
		if ns.OnSetChanged then
			ns.OnSetChanged()
		end
		Print(L.RENAMED:format(index, DB.sets[index].name))
	elseif cmd == "show" or cmd == "hide" then
		DB.button.shown = (cmd == "show")
		UpdateButtonVisibility()
	elseif cmd == "lock" or cmd == "unlock" then
		DB.button.locked = (cmd == "lock")
		Print(DB.button.locked and L.BUTTON_LOCKED or L.BUTTON_UNLOCKED)
	elseif cmd == "check" then
		ns.CheckConflicts(false)
	elseif cmd == "status" then
		Print(L.STATUS_HEADER:format(SetName(DB.current), DB.current, DB.count))
		local pages = DB.sets[DB.current].pages
		for bar = 1, NUM_BARS do
			local page = pages[bar] or 0
			if bar <= 2 or page > 0 then
				local label
				if page == 0 then
					label = L.PAGE_DEFAULT:format(BARS[bar].defaultPage)
				else
					label = L.PAGE:format(page)
				end
				DEFAULT_CHAT_FRAME:AddMessage("  " .. BarName(bar) .. ": " .. label)
			end
		end
	elseif cmd == "debug" then
		ns.PrintDebug()
	elseif cmd == "reset" then
		ns.ResetAll()
	else
		PrintHelp()
	end
end

SLASH_ACTIONBARSWITCHER1 = "/abs"
SLASH_ACTIONBARSWITCHER2 = "/actionbarswitcher"
SlashCmdList.ACTIONBARSWITCHER = SlashHandler

-- Addon compartment (the addon list button next to the minimap).
function ActionBarSwitcher_OnAddonCompartmentClick(_, buttonName)
	if buttonName == "RightButton" then
		ns.SwitchRelative(1)
	elseif ns.OpenOptions then
		ns.OpenOptions()
	end
end

function ActionBarSwitcher_OnAddonCompartmentEnter(_, menuButtonFrame)
	GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
	GameTooltip:SetText(L.TITLE)
	if DB then
		GameTooltip:AddLine(SetName(DB.current), 1, 1, 1)
	end
	GameTooltip:Show()
end

function ActionBarSwitcher_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local function Initialize()
	if initialized then
		return
	end
	if InCombatLockdown() then
		pending.init = true
		return
	end
	CreateFrames()
	initialized = true
	PushConfig()
	if ns.GetKeyText then
		local anyKey = ns.GetKeyText("next") or ns.GetKeyText("prev")
		for i = 1, MAX_SETS do
			anyKey = anyKey or ns.GetKeyText("set" .. i)
		end
		if not anyKey then
			Print(L.KB_FIRST_HINT)
		end
	end
	if ns.OnSetChanged then
		ns.OnSetChanged()
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(self, event, arg1, arg2)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			ActionBarSwitcherCharDB = SanitizeDB(ActionBarSwitcherCharDB)
			DB = ActionBarSwitcherCharDB
			ns.DB = DB
			if ns.CreateOptions then
				-- The options panel is optional: never let it break the core.
				local ok, err = pcall(ns.CreateOptions)
				if not ok then
					geterrorhandler()(err)
				end
			end
			self:UnregisterEvent("ADDON_LOADED")
		end
	elseif event == "PLAYER_LOGIN" then
		Initialize()
	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = arg1, arg2
		if (isInitialLogin or isReloadingUi) and initialized then
			-- Re-apply once the world is up, in case Blizzard reset the page of Action Bar 1.
			if InCombatLockdown() then
				pending.config = true
			else
				PushConfig()
			end
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pending.init then
			pending.init = nil
			Initialize()
		end
		if pending.config then
			pending.config = nil
			PushConfig()
		end
		if pending.visibility then
			pending.visibility = nil
			UpdateButtonVisibility()
		end
	end
end)
