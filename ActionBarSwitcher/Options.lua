-- Settings panel: Esc > Options > AddOns > ActionBar Switcher
-- Built with Blizzard's Settings API (vertical layout). Created from
-- Core.lua inside a pcall, so a problem here can never break switching.

local ADDON_NAME, ns = ...
local L = ns.L

local mainCategory

local function PageLabel(page)
	local label = L.PAGE:format(page)
	local hint
	if page == 2 then
		hint = L.PAGE_HINT_BAR1_PAGE2
	elseif ns.IsBonusPage(page) then
		hint = L.PAGE_HINT_BONUS
	else
		local owner = ns.BarForDefaultPage(page)
		if owner then
			hint = L.PAGE_HINT_BAR:format(ns.BarName(owner))
		end
	end
	if hint then
		label = label .. " (" .. hint .. ")"
	end
	return label
end

local function Bar1Options()
	local container = Settings.CreateControlTextContainer()
	container:Add(0, L.PAGE_UNCHANGED)
	for page = 1, ns.BAR1_MAX_PAGE do
		container:Add(page, PageLabel(page))
	end
	return container:GetData()
end

local function BarOptionsFor(bar)
	return function()
		local container = Settings.CreateControlTextContainer()
		container:Add(0, L.PAGE_DEFAULT:format(ns.BARS[bar].defaultPage))
		for page = 1, ns.MAX_PAGE do
			if page ~= ns.BARS[bar].defaultPage then
				container:Add(page, PageLabel(page))
			end
		end
		return container:GetData()
	end
end

local function SetCountOptions()
	local container = Settings.CreateControlTextContainer()
	for count = 1, ns.MAX_SETS do
		container:Add(count, tostring(count))
	end
	return container:GetData()
end

-- Applies the changed configuration (or defers it until combat ends).
local function ConfigChanged()
	if InCombatLockdown() then
		ns.Print(L.DEFERRED)
	end
	ns.PushConfig()
	ns.CheckConflicts(true)
end

local function AddHeader(layout, text, tooltip)
	if layout and CreateSettingsListSectionHeaderInitializer then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text, tooltip))
	end
end

local function RegisterSubcategory(parent, name)
	local category, layout = Settings.RegisterVerticalLayoutSubcategory(parent, name)
	if not layout and SettingsPanel and SettingsPanel.GetLayout then
		layout = SettingsPanel:GetLayout(category)
	end
	return category, layout
end

function ns.CreateOptions()
	if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting) then
		return
	end
	local DB = ns.DB

	local category, layout = Settings.RegisterVerticalLayoutCategory(L.TITLE)
	mainCategory = category
	if not layout and SettingsPanel and SettingsPanel.GetLayout then
		layout = SettingsPanel:GetLayout(category)
	end

	-- Key bindings --------------------------------------------------------
	if layout and CreateSettingsButtonInitializer and ns.OpenKeyBindings then
		layout:AddInitializer(CreateSettingsButtonInitializer(L.OPT_KEYBINDS, L.OPT_KEYBINDS_BUTTON,
			function() ns.OpenKeyBindings() end, L.OPT_KEYBINDS_TT, true))
	end

	-- General -----------------------------------------------------------
	do
		local setting = Settings.RegisterProxySetting(category, "ABS_SetCount", Settings.VarType.Number,
			L.OPT_SETCOUNT, 2,
			function() return DB.count end,
			function(value)
				DB.count = value
				if DB.current > DB.count then
					DB.current = 1
				end
				ConfigChanged()
			end)
		Settings.CreateDropdown(category, setting, SetCountOptions, L.OPT_SETCOUNT_TT)
	end

	do
		local setting = Settings.RegisterProxySetting(category, "ABS_ShowButton", Settings.VarType.Boolean,
			L.OPT_SHOWBUTTON, true,
			function() return DB.button.shown end,
			function(value)
				DB.button.shown = value
				ns.UpdateButtonVisibility()
			end)
		Settings.CreateCheckbox(category, setting, L.OPT_SHOWBUTTON_TT)
	end

	do
		local setting = Settings.RegisterProxySetting(category, "ABS_LockButton", Settings.VarType.Boolean,
			L.OPT_LOCK, false,
			function() return DB.button.locked end,
			function(value) DB.button.locked = value end)
		Settings.CreateCheckbox(category, setting, L.OPT_LOCK_TT)
	end

	do
		local setting = Settings.RegisterProxySetting(category, "ABS_Announce", Settings.VarType.Boolean,
			L.OPT_ANNOUNCE, false,
			function() return DB.announce end,
			function(value) DB.announce = value end)
		Settings.CreateCheckbox(category, setting, L.OPT_ANNOUNCE_TT)
	end

	-- One subcategory per set -------------------------------------------
	for s = 1, ns.MAX_SETS do
		local title = L.SET .. " " .. s
		local subcategory, layout = RegisterSubcategory(category, title)

		AddHeader(layout, title, L.OPT_SET_INFO:format(s))

		for bar = 1, ns.NUM_BARS do
			local default = ns.DefaultPage(s, bar)
			local setting = Settings.RegisterProxySetting(subcategory, ("ABS_Set%d_Bar%d"):format(s, bar),
				Settings.VarType.Number, ns.BarName(bar), default,
				function() return DB.sets[s].pages[bar] or 0 end,
				function(value)
					DB.sets[s].pages[bar] = value
					ConfigChanged()
				end)

			local tooltip = (bar == 1) and L.OPT_BAR1_TT or L.OPT_BARN_TT
			local function Tooltip()
				local text = tooltip
				if s > DB.count then
					text = text .. "\n\n" .. L.OPT_INACTIVE:format(DB.count)
				end
				return text
			end
			Settings.CreateDropdown(subcategory, setting, (bar == 1) and Bar1Options or BarOptionsFor(bar), Tooltip)
		end
	end

	Settings.RegisterAddOnCategory(category)
end

function ns.OpenOptions()
	if mainCategory and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(mainCategory:GetID())
	else
		for _, line in ipairs(L.HELP) do
			DEFAULT_CHAT_FRAME:AddMessage(line)
		end
	end
end
