-- In-game key binding window: /abs bind (or the button in the settings).
-- Click a field, press any key or key combination (e.g. Shift + 1) and it is
-- bound. Right click clears a binding, Esc cancels.
--
-- The bindings are ordinary WoW key bindings ("CLICK ActionBarSwitcherButton:next"
-- etc.), so they also show up in Blizzard's own key binding menu under AddOns.

local ADDON_NAME, ns = ...
local L = ns.L

local BUTTON_NAME = "ActionBarSwitcherButton"

-- action = the pseudo mouse button the secure switch button understands
local ROWS = {
	{ action = "next", label = function() return L.BINDING_NEXT end },
	{ action = "prev", label = function() return L.BINDING_PREV end },
}
for i = 1, 4 do
	ROWS[#ROWS + 1] = { action = "set" .. i, label = function() return L.BINDING_SET:format(i) .. " (" .. ns.SetName(i) .. ")" end }
end

local function Command(action)
	return "CLICK " .. BUTTON_NAME .. ":" .. action
end

-- Keys that only modify other keys can't be bound on their own.
local MODIFIER_KEYS = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
	LMETA = true, RMETA = true, UNKNOWN = true,
}

local MOUSE_BUTTONS = {
	MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5",
}

-- Builds "ALT-CTRL-SHIFT-KEY" in the order WoW expects.
local function KeyChord(key)
	if CreateKeyChordStringUsingMetaKeyState then
		return CreateKeyChordStringUsingMetaKeyState(key)
	end
	local chord = ""
	if IsAltKeyDown() then chord = chord .. "ALT-" end
	if IsControlKeyDown() then chord = chord .. "CTRL-" end
	if IsShiftKeyDown() then chord = chord .. "SHIFT-" end
	return chord .. key
end

local function BindingDisplayName(command)
	local name = _G["BINDING_NAME_" .. command]
	return name or command
end

local function SaveAll()
	if SaveBindings and GetCurrentBindingSet then
		SaveBindings(GetCurrentBindingSet())
	end
end

local frame
local capturing -- row currently waiting for a key

local function RefreshRows()
	if not frame then
		return
	end
	for _, row in ipairs(frame.rows) do
		row.Label:SetText(row.def.label())
		local key1, key2 = GetBindingKey(Command(row.def.action))
		local text
		if capturing == row then
			text = "|cffffd100" .. L.KB_PRESS_KEY .. "|r"
		elseif key1 then
			text = GetBindingText(key1)
			if key2 then
				text = text .. ", " .. GetBindingText(key2)
			end
		else
			text = "|cff808080" .. L.KB_NOT_BOUND .. "|r"
		end
		row.Key:SetText(text)
	end
end

local function StopCapture()
	capturing = nil
	if frame and not InCombatLockdown() then
		frame:EnableMouseWheel(false)
		frame:EnableKeyboard(false)
		frame:SetPropagateKeyboardInput(true)
	end
	RefreshRows()
end

local function Bind(row, key)
	if InCombatLockdown() then
		ns.Print(L.IN_COMBAT)
		StopCapture()
		return
	end
	local command = Command(row.def.action)
	local chord = KeyChord(key)

	-- Warn if the key was used for something else.
	local previous = GetBindingAction(chord)
	if previous and previous ~= "" and previous ~= command then
		ns.Print(L.KB_REPLACED:format(GetBindingText(chord), BindingDisplayName(previous)))
	end

	-- One key per action: drop old keys of this action first.
	local old1, old2 = GetBindingKey(command)
	if old1 then SetBinding(old1) end
	if old2 then SetBinding(old2) end

	if SetBindingClick(chord, BUTTON_NAME, row.def.action) then
		SaveAll()
		ns.Print(L.KB_BOUND:format(GetBindingText(chord), row.def.label()))
	end
	StopCapture()
end

local function Clear(row)
	if InCombatLockdown() then
		ns.Print(L.IN_COMBAT)
		return
	end
	local command = Command(row.def.action)
	local key1, key2 = GetBindingKey(command)
	if key1 then SetBinding(key1) end
	if key2 then SetBinding(key2) end
	SaveAll()
	RefreshRows()
end

local function StartCapture(row)
	if InCombatLockdown() then
		ns.Print(L.IN_COMBAT)
		return
	end
	capturing = row
	frame:EnableMouseWheel(true)
	frame:EnableKeyboard(true)
	frame:SetPropagateKeyboardInput(false)
	RefreshRows()
end

local function CreateBindingFrame()
	local f = CreateFrame("Frame", "ActionBarSwitcherKeyBindFrame", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(380, 90 + #ROWS * 30)
	f:SetPoint("CENTER")
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	tinsert(UISpecialFrames, f:GetName()) -- Esc closes the window

	if f.TitleText then
		f.TitleText:SetText(L.TITLE .. " - " .. L.KB_TITLE)
	end

	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 14, -32)
	hint:SetPoint("TOPRIGHT", -14, -32)
	hint:SetJustifyH("LEFT")
	hint:SetText(L.KB_HINT)

	f.rows = {}
	for i, def in ipairs(ROWS) do
		local row = CreateFrame("Frame", nil, f)
		row:SetSize(352, 26)
		row:SetPoint("TOPLEFT", 14, -40 - i * 30)
		row.def = def

		row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row.Label:SetPoint("LEFT")
		row.Label:SetWidth(190)
		row.Label:SetJustifyH("LEFT")
		row.Label:SetWordWrap(false)

		local keyButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		keyButton:SetSize(160, 24)
		keyButton:SetPoint("RIGHT")
		keyButton:RegisterForClicks("AnyUp")
		keyButton:SetScript("OnClick", function(_, mouseButton)
			if capturing == row then
				-- Extra mouse buttons can be bound, too.
				local converted = MOUSE_BUTTONS[mouseButton]
				if converted then
					Bind(row, converted)
				elseif mouseButton == "RightButton" or mouseButton == "LeftButton" then
					StopCapture()
				end
			elseif mouseButton == "RightButton" then
				Clear(row)
			elseif mouseButton == "LeftButton" then
				StartCapture(row)
			end
		end)
		row.Key = keyButton
		f.rows[i] = row
	end

	f:SetScript("OnKeyDown", function(self, key)
		if not capturing then
			return
		end
		if key == "ESCAPE" then
			StopCapture()
			return
		end
		if MODIFIER_KEYS[key] then
			return -- wait for the actual key
		end
		Bind(capturing, key)
	end)
	f:SetScript("OnMouseWheel", function(_, delta)
		if capturing then
			Bind(capturing, delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
		end
	end)
	f:SetScript("OnHide", StopCapture)
	f:SetScript("OnShow", RefreshRows)
	f:SetScript("OnEvent", RefreshRows)
	f:RegisterEvent("UPDATE_BINDINGS")
	f:EnableKeyboard(false)
	f:SetPropagateKeyboardInput(true)
	return f
end

function ns.OpenKeyBindings()
	if InCombatLockdown() then
		ns.Print(L.IN_COMBAT)
		return
	end
	frame = frame or CreateBindingFrame()
	frame:Show()
	frame:Raise()
end

-- Short summary for chat (/abs status) and tooltips.
function ns.GetKeyText(action)
	local key = GetBindingKey(Command(action))
	return key and GetBindingText(key) or nil
end
