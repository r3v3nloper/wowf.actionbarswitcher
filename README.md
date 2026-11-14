# ActionBar Switcher (WoW Forever)

Ein schlankes Addon für **World of Warcraft Forever (1.60.x)**, mit dem du **Aktionsleiste 1 _und_ Aktionsleiste 2**
(optional auch 3–8) per Tastendruck zwischen verschiedenen Seiten umschaltest, zum Beispiel ein Set für Raid, eines
für PvP und eines für Open World.

- **Kein UI-Ersatz:** Blizzards Standard-Aktionsleisten, Edit Mode, Tastenbelegungen und Optik bleiben komplett
  unverändert. Das Addon sagt den vorhandenen Leisten nur, welche Seite sie anzeigen sollen.
- **Echtes Umschalten statt „Switch while hold“:** Ein Tastendruck schaltet um, und das Set bleibt aktiv.
- **Nur auf Tastendruck:** Es wird **nie automatisch** umgeschaltet, auch nicht bei Kampfbeginn, Zonenwechsel o. Ä.
  Die Leisten wechseln ausschließlich, wenn du deine Taste drückst. Das funktioniert dafür aber auch mitten im Kampf.
- **Taste frei wählbar im Spiel:** Jede Taste oder Kombination (z. B. **Shift + 1**, Strg + Q, Maustaste 4),
  festgelegt im Addon-Fenster `/abs bind` oder in Blizzards Tastaturbelegung.
- **Bis zu 4 Sets**, jeweils mit einer eigenen Seite für jede der 8 Leisten.

## Installation

1. Den Ordner `ActionBarSwitcher` nach `World of Warcraft\_forever_\Interface\AddOns\` kopieren.
   (Der genaue Ordnername der Spielversion kann abweichen; es ist der Ordner, in dem deine anderen Forever-Addons liegen.)
2. Spiel starten und das Addon in der Addon-Liste aktivieren.
   Wird es als „veraltet“ angezeigt, „Veraltete AddOns laden“ anhaken oder die Zeile `## Interface:` in
   `ActionBarSwitcher.toc` an die Version anpassen, die im Spiel mit `/dump select(4, GetBuildInfo())` angezeigt wird.

## Schnellstart

1. **Taste festlegen:** `/abs bind` eingeben (oder Einstellungen → „Tasten festlegen …“). Das Feld „Nächstes Set“
   anklicken und die gewünschte Kombination drücken, z. B. **Shift + 1**. Fertig, die Belegung wird sofort gespeichert.
   Rechtsklick auf ein Feld löscht die Belegung, Esc bricht ab. Dieselben Einträge findest du auch unter
   `Esc` → Optionen → Tastaturbelegung → AddOns → *ActionBar Switcher*.
   (Optional gibt es auch „Vorheriges Set“ und „Set 1–4 aktivieren“, z. B. Shift + 1 für Set 1 und Shift + 2 für Set 2.)

   Hinweis: Blizzard belegt Shift + 1 … 6 standardmäßig mit „Aktionsleiste Seite 1 … 6“. Wenn du eine solche Kombination
   wählst, ersetzt das Addon die alte Belegung und sagt dir im Chat, was vorher darauf lag.
2. **Taste drücken:** Du bist jetzt in *Set 2*. Leiste 1 zeigt Seite 2, Leiste 2 zeigt Seite 13.
   Beide Seiten sind beim ersten Mal leer.
3. **Befüllen:** Ziehe einfach Zauber auf Leiste 1 und 2. Sie landen auf den Seiten von Set 2.
4. **Zurück:** Taste noch einmal drücken. Set 1 zeigt wieder deine normalen Leisten.

Standardkonfiguration:

| Set   | Aktionsleiste 1 | Aktionsleiste 2                  |
|-------|-----------------|----------------------------------|
| Set 1 | Seite 1         | Standard (Seite 6, wie bisher)   |
| Set 2 | Seite 2         | Seite 13 (sonst Aktionsleiste 6) |

Seite 13 ist nur frei, solange du Aktionsleiste 6 nicht benutzt. Wie oben beschrieben nutzt du nur Leiste 1 und 2, also ist
sie frei. Wenn du Leiste 6 doch aktivierst, nimm stattdessen Seite 14/15 (Leiste 7/8) oder 3/4/5 (Leiste 4/5/3).

## Einstellungen

`/abs` oder `Esc` → Optionen → AddOns → **ActionBar Switcher**

- **Allgemein:** Anzahl Sets (1–4), Umschalt-Button anzeigen/sperren, Chat-Meldung beim Wechsel.
- **Set 1 … Set 4:** Seite für jede Aktionsleiste.
  - Leiste 1: Seite 1–6 (1 = deine normale Leiste 1). Verstohlenheit, Druidenformen, Himmelsreiten und Fahrzeuge
    ersetzen Leiste 1 in **jedem** Set weiterhin automatisch.
  - Leiste 2–8: „Standard“ (eigene Seite) oder Seite 1–15.

Nach jeder Änderung prüft das Addon auf Konflikte und warnt im Chat, z. B. wenn zwei sichtbare Leisten dieselbe Seite zeigen
oder eine Klassen-/Bonusseite (7–12) gewählt wurde.

### Welche Seiten sind frei?

| Seite | gehört normalerweise zu                                         |
|-------|-----------------------------------------------------------------|
| 1     | Aktionsleiste 1                                                 |
| 2     | Aktionsleiste 1, 2. Seite                                       |
| 3     | Aktionsleiste 4 (rechts)                                        |
| 4     | Aktionsleiste 5 (rechts)                                        |
| 5     | Aktionsleiste 3                                                 |
| 6     | Aktionsleiste 2                                                 |
| 7–12  | Klassen-/Bonusleisten (Druidenformen, Verstohlenheit, Himmelsreiten, Fahrzeuge …), **nicht verwenden** |
| 13    | Aktionsleiste 6                                                 |
| 14    | Aktionsleiste 7                                                 |
| 15    | Aktionsleiste 8                                                 |

Jede Seite, deren Leiste du nicht benutzt, ist frei.

## Bedienung

| Aktion                         | Wie                                               |
|--------------------------------|---------------------------------------------------|
| Nächstes / vorheriges Set      | Tastenbelegung oder Links-/Rechtsklick auf den Umschalt-Button |
| Bestimmtes Set                 | Tastenbelegung „Set N aktivieren“ oder `/abs N`   |
| Umschalt-Button verschieben    | Shift + Ziehen                                    |
| Addon-Menü (Minimap)           | Linksklick = Einstellungen, Rechtsklick = nächstes Set |

Slash-Befehle (`/abs` oder `/actionbarswitcher`):

```
/abs                 Einstellungen öffnen
/abs bind            Tasten / Tastenkombinationen festlegen (z. B. Shift + 1)
/abs next | prev     Set wechseln (außerhalb des Kampfes)
/abs 1..4            bestimmtes Set aktivieren (außerhalb des Kampfes)
/abs name 2 PvP      Set 2 umbenennen (Name erscheint auf dem Button)
/abs show | hide     Umschalt-Button ein-/ausblenden
/abs lock | unlock   Umschalt-Button sperren/entsperren
/abs check           Konfiguration auf Konflikte prüfen
/abs status          aktives Set und Seiten anzeigen
/abs reset           alle Leisten auf Blizzard-Standard zurücksetzen
/abs debug           Diagnose-Infos (bei Problemen bitte mitschicken)
```

Im Kampf funktionieren **Tastenbelegungen und der Umschalt-Button**. Slash-Befehle und Einstellungen sind dort gesperrt
(Blizzard-Vorgabe); Änderungen an den Einstellungen werden nach dem Kampf automatisch übernommen.

## Wie es technisch funktioniert

- **Aktionsleiste 1:** Blizzards eigene Seite bleibt immer 1. Dadurch kümmert sich Blizzard weiterhin um
  Verstohlenheit, Druidenformen, Himmelsreiten, Fahrzeuge usw. (Blizzard zeigt diese Leisten nur auf Seite 1 an).
  Die Seite des Sets wird als `actionpage` direkt auf die 12 Buttons gelegt, aber nur im Normalzustand.
  Ein sicherer State-Driver erkennt Verstohlenheit (`[stealth]`, Schurke/Druide), Druidenformen (`[form]`),
  Fahrzeuge, Override-/Possess-Leisten und Haustierkämpfe, auch im Kampf. Solange so ein Zustand aktiv ist (oder
  Blizzards `MainActionBar` nicht auf Seite 1 steht), folgt Leiste 1 Blizzard und zeigt z. B. die Verstohlenheitsleiste.
  Danach erscheint wieder die Seite des aktiven Sets. (`[bonusbar]` ist in WoW Forever dafür nicht zuverlässig.)
- **Aktionsleisten 2–8:** Jeder Blizzard-Button berechnet seinen Aktionsplatz als
  `ID + (actionpage − 1) × 12` und liest `actionpage` zuerst vom Button selbst, dann von seiner Leiste.
  Das Addon setzt `actionpage` direkt auf die 12 Buttons. Die Buttons aktualisieren sich daraufhin selbst
  (`OnAttributeChanged` → `UpdateAction`). Wird das Attribut entfernt, gilt wieder die Standardseite der Leiste.
- Alle Änderungen laufen in gesicherten Snippets eines `SecureHandler`-Headers, ausgelöst durch einen
  `SecureActionButton`. Nur so dürfen geschützte Frames im Kampf verändert werden, und Blizzards Buttons bleiben frei
  von Addon-„Taint“.
- Das aktive Set wird pro Charakter gespeichert (`ActionBarSwitcherCharDB`) und beim Einloggen bzw. `/reload`
  wiederhergestellt.

## Bekannte Eigenheiten

- **Schurken/Druiden:** Verstohlenheit und Formen funktionieren in jedem Set. In Set 2 zeigt Leiste 1 also normalerweise
  Seite 2, in Verstohlenheit aber deine Verstohlenheitsleiste. Danach kehrt sie zu Seite 2 zurück. Leiste 2 behält ihre
  Set-Seite immer. Blätterst du Leiste 1 zusätzlich von Hand (Shift + Mausrad), gilt Blizzards normales Verhalten:
  Auf einer anderen Seite als 1 gibt es keine Verstohlenheitsleiste.
- Andere Addons, die Blizzards Leisten selbst blättern oder ersetzen (Bartender, Dominos, ElvUI …), sind nicht das
  Ziel dieses Addons und können sich mit ihm in die Quere kommen.

## Entwicklung

Ein kleiner Lua-5.1-Testharness bildet die nötige WoW-API inklusive der sicheren Snippet-Ausführung nach und prüft die
Umschaltlogik (Zyklus, direkte Sets, Kampf, verzögerte Konfiguration, Konfliktprüfung, Reset):

```
lua5.1 tests/harness.lua                       # Englisch
lua5.1 tests/harness.lua ActionBarSwitcher deDE  # Deutsch
```

Der Harness ersetzt keinen Test im echten Spielclient.
