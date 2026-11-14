local ADDON_NAME, ns = ...

-- English defaults. German overrides follow below.
local L = {
	TITLE = "ActionBar Switcher",
	SET = "Set",

	-- Key bindings
	BINDING_NEXT = "Next set",
	BINDING_PREV = "Previous set",
	BINDING_SET = "Activate set %d",

	-- Bars / pages
	BAR = "Action Bar %d",
	PAGE = "Page %d",
	PAGE_UNCHANGED = "Don't change",
	PAGE_DEFAULT = "Default (own page %d)",
	PAGE_HINT_BAR = "normally %s",
	PAGE_HINT_BAR1_PAGE2 = "2nd page of Action Bar 1",
	PAGE_HINT_BONUS = "class/bonus bar: forms, stealth, skyriding ...",

	-- Chat
	SWITCHED = "Switched to |cffffd100%s|r.",
	IN_COMBAT = "Not possible in combat - please use the key binding or the switch button.",
	DEFERRED = "In combat - changes will be applied when combat ends.",
	NOT_READY = "Not initialised yet.",
	UNKNOWN_SET = "Unknown set: %s",
	RENAMED = "Set %d is now called |cffffd100%s|r.",
	RESET_DONE = "All bars were reset to their default pages.",
	BUTTON_LOCKED = "Switch button locked.",
	BUTTON_UNLOCKED = "Switch button unlocked - Shift + drag to move it.",
	NO_CONFLICTS = "No conflicts found.",
	STATUS_HEADER = "Current set: |cffffd100%s|r (%d of %d)",

	-- Conflict warnings
	WARN_BONUS = "%s / %s uses page %d, which belongs to class/bonus bars (forms, stealth, skyriding ...). This can show unexpected buttons.",
	WARN_SHARED_VISIBLE = "%s / %s uses page %d, the normal page of the visible %s. Both bars will show the same buttons.",
	WARN_DUPLICATE = "%s: %s and %s both use page %d.",

	-- Slash help
	HELP = {
		"|cffffd100/abs|r - open the settings",
		"|cffffd100/abs bind|r - choose keys / key combinations (e.g. Shift + 1)",
		"|cffffd100/abs next|r, |cffffd100/abs prev|r, |cffffd100/abs <1-4>|r - switch set (out of combat)",
		"|cffffd100/abs name <1-4> <name>|r - rename a set",
		"|cffffd100/abs show|r / |cffffd100hide|r - show/hide the switch button",
		"|cffffd100/abs lock|r / |cffffd100unlock|r - lock/unlock the switch button",
		"|cffffd100/abs check|r - check the configuration for conflicts",
		"|cffffd100/abs status|r - show the current set",
		"|cffffd100/abs reset|r - reset all bars to their default pages",
		"Also possible: Esc > Options > Keybindings > AddOns > ActionBar Switcher",
	},

	-- Tooltip of the switch button
	TT_LEFT = "Left click: next set",
	TT_RIGHT = "Right click: previous set",
	TT_MOVE = "Shift + drag: move",

	-- Settings panel
	OPT_GENERAL = "General",
	OPT_SETCOUNT = "Number of sets",
	OPT_SETCOUNT_TT = "How many sets the 'Next set' key cycles through.",
	OPT_SHOWBUTTON = "Show switch button",
	OPT_SHOWBUTTON_TT = "Small on-screen button showing the active set. Left click = next, right click = previous, Shift + drag = move. Key bindings work even when it is hidden.",
	OPT_LOCK = "Lock switch button",
	OPT_LOCK_TT = "Prevents the button from being moved.",
	OPT_ANNOUNCE = "Chat message on switch",
	OPT_ANNOUNCE_TT = "Prints the name of the new set to the chat window.",
	OPT_SET_INFO = "Choose which page each bar shows while this set is active. Rename the set with /abs name %d <name>.",
	OPT_BAR1_TT = "Action Bar 1 uses Blizzard's own paging (pages 1-6), exactly like Shift + mouse wheel. 'Don't change' leaves it alone.",
	OPT_BARN_TT = "'Default' shows the bar's own page. Free pages for most players: 3, 4, 5 (if Action Bars 4, 5, 3 are not used) and 13, 14, 15 (if Action Bars 6, 7, 8 are not used). Drag spells onto the bar while the set is active to fill that page.",
	OPT_INACTIVE = "(inactive - number of sets is %d)",
	OPT_KEYBINDS = "Key bindings",
	OPT_KEYBINDS_BUTTON = "Set keys ...",
	OPT_KEYBINDS_TT = "Opens a small window where you bind any key or key combination (e.g. Shift + 1) to the switch functions.",

	-- Key binding window
	KB_TITLE = "Key bindings",
	KB_HINT = "Left click a field, then press a key or combination (e.g. Shift + 1). Right click clears, Esc cancels. Nothing switches automatically - only when you press the key.",
	KB_PRESS_KEY = "Press a key ...",
	KB_NOT_BOUND = "not bound",
	KB_BOUND = "|cffffd100%s|r now triggers: %s",
	KB_REPLACED = "|cffffd100%s|r was bound to \"%s\" - replaced.",
	KB_FIRST_HINT = "No key bound yet. Type |cffffd100/abs bind|r to choose a key (e.g. Shift + 1).",
	KEYS = "Keys",
}

if GetLocale() == "deDE" then
	local de = {
		TITLE = "ActionBar Switcher",
		SET = "Set",

		BINDING_NEXT = "Nächstes Set",
		BINDING_PREV = "Vorheriges Set",
		BINDING_SET = "Set %d aktivieren",

		BAR = "Aktionsleiste %d",
		PAGE = "Seite %d",
		PAGE_UNCHANGED = "Nicht ändern",
		PAGE_DEFAULT = "Standard (eigene Seite %d)",
		PAGE_HINT_BAR = "normal %s",
		PAGE_HINT_BAR1_PAGE2 = "2. Seite von Aktionsleiste 1",
		PAGE_HINT_BONUS = "Klassen-/Bonusleiste: Formen, Verstohlenheit, Himmelsreiten ...",

		SWITCHED = "Gewechselt zu |cffffd100%s|r.",
		IN_COMBAT = "Im Kampf nicht möglich - bitte die Tastenbelegung oder den Umschalt-Button benutzen.",
		DEFERRED = "Im Kampf - Änderungen werden nach dem Kampf übernommen.",
		NOT_READY = "Noch nicht initialisiert.",
		UNKNOWN_SET = "Unbekanntes Set: %s",
		RENAMED = "Set %d heißt jetzt |cffffd100%s|r.",
		RESET_DONE = "Alle Leisten wurden auf ihre Standardseiten zurückgesetzt.",
		BUTTON_LOCKED = "Umschalt-Button gesperrt.",
		BUTTON_UNLOCKED = "Umschalt-Button entsperrt - mit Shift + Ziehen verschieben.",
		NO_CONFLICTS = "Keine Konflikte gefunden.",
		STATUS_HEADER = "Aktives Set: |cffffd100%s|r (%d von %d)",

		WARN_BONUS = "%s / %s nutzt Seite %d, die zu den Klassen-/Bonusleisten gehört (Formen, Verstohlenheit, Himmelsreiten ...). Das kann unerwartete Buttons anzeigen.",
		WARN_SHARED_VISIBLE = "%s / %s nutzt Seite %d, die normale Seite der sichtbaren %s. Beide Leisten zeigen dann dieselben Buttons.",
		WARN_DUPLICATE = "%s: %s und %s nutzen beide Seite %d.",

		HELP = {
			"|cffffd100/abs|r - Einstellungen öffnen",
			"|cffffd100/abs bind|r - Tasten / Tastenkombinationen festlegen (z. B. Shift + 1)",
			"|cffffd100/abs next|r, |cffffd100/abs prev|r, |cffffd100/abs <1-4>|r - Set wechseln (außerhalb des Kampfes)",
			"|cffffd100/abs name <1-4> <Name>|r - Set umbenennen",
			"|cffffd100/abs show|r / |cffffd100hide|r - Umschalt-Button ein-/ausblenden",
			"|cffffd100/abs lock|r / |cffffd100unlock|r - Umschalt-Button sperren/entsperren",
			"|cffffd100/abs check|r - Konfiguration auf Konflikte prüfen",
			"|cffffd100/abs status|r - aktives Set anzeigen",
			"|cffffd100/abs reset|r - alle Leisten auf Standardseiten zurücksetzen",
			"Alternativ: Esc > Optionen > Tastaturbelegung > AddOns > ActionBar Switcher",
		},

		TT_LEFT = "Linksklick: nächstes Set",
		TT_RIGHT = "Rechtsklick: vorheriges Set",
		TT_MOVE = "Shift + Ziehen: verschieben",

		OPT_GENERAL = "Allgemein",
		OPT_SETCOUNT = "Anzahl Sets",
		OPT_SETCOUNT_TT = "Durch wie viele Sets die Taste 'Nächstes Set' schaltet.",
		OPT_SHOWBUTTON = "Umschalt-Button anzeigen",
		OPT_SHOWBUTTON_TT = "Kleiner Button, der das aktive Set anzeigt. Linksklick = nächstes, Rechtsklick = vorheriges, Shift + Ziehen = verschieben. Die Tastenbelegungen funktionieren auch, wenn er ausgeblendet ist.",
		OPT_LOCK = "Umschalt-Button sperren",
		OPT_LOCK_TT = "Verhindert, dass der Button verschoben wird.",
		OPT_ANNOUNCE = "Chat-Meldung beim Wechsel",
		OPT_ANNOUNCE_TT = "Schreibt den Namen des neuen Sets ins Chatfenster.",
		OPT_SET_INFO = "Lege fest, welche Seite jede Leiste zeigt, solange dieses Set aktiv ist. Umbenennen mit /abs name %d <Name>.",
		OPT_BAR1_TT = "Aktionsleiste 1 nutzt Blizzards eigenes Blättern (Seiten 1-6), genau wie Shift + Mausrad. 'Nicht ändern' lässt sie in Ruhe.",
		OPT_BARN_TT = "'Standard' zeigt die eigene Seite der Leiste. Für die meisten Spieler frei: Seite 3, 4, 5 (wenn Aktionsleiste 4, 5, 3 nicht genutzt werden) und 13, 14, 15 (wenn Aktionsleiste 6, 7, 8 nicht genutzt werden). Bei aktivem Set einfach Zauber auf die Leiste ziehen, um diese Seite zu befüllen.",
		OPT_INACTIVE = "(inaktiv - Anzahl Sets ist %d)",
		OPT_KEYBINDS = "Tastenbelegung",
		OPT_KEYBINDS_BUTTON = "Tasten festlegen ...",
		OPT_KEYBINDS_TT = "Öffnet ein kleines Fenster, in dem du jede beliebige Taste oder Tastenkombination (z. B. Shift + 1) den Umschalt-Funktionen zuweist.",

		KB_TITLE = "Tastenbelegung",
		KB_HINT = "Feld mit Linksklick anwählen, dann Taste oder Kombination drücken (z. B. Shift + 1). Rechtsklick löscht, Esc bricht ab. Es wird nie automatisch umgeschaltet - nur wenn du die Taste drückst.",
		KB_PRESS_KEY = "Taste drücken ...",
		KB_NOT_BOUND = "nicht belegt",
		KB_BOUND = "|cffffd100%s|r löst jetzt aus: %s",
		KB_REPLACED = "|cffffd100%s|r war mit \"%s\" belegt - ersetzt.",
		KB_FIRST_HINT = "Noch keine Taste belegt. Mit |cffffd100/abs bind|r eine Taste wählen (z. B. Shift + 1).",
		KEYS = "Tasten",
	}
	for k, v in pairs(de) do
		L[k] = v
	end
end

ns.L = L

-- Key binding labels (shown in Blizzard's key binding UI).
BINDING_HEADER_ACTIONBARSWITCHER = L.TITLE
_G["BINDING_NAME_CLICK ActionBarSwitcherButton:next"] = L.BINDING_NEXT
_G["BINDING_NAME_CLICK ActionBarSwitcherButton:prev"] = L.BINDING_PREV
for i = 1, 4 do
	_G["BINDING_NAME_CLICK ActionBarSwitcherButton:set" .. i] = L.BINDING_SET:format(i)
end
