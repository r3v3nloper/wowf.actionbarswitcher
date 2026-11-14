# Übergabe: ActionBar Switcher (WoW Forever)

Diese Datei fasst alles zusammen, was eine neue Claude-Sitzung braucht, um nahtlos weiterzumachen.
**Bitte zuerst komplett lesen.** Antworte dem Nutzer auf **Deutsch**.

---

## 1. Sofort zu erledigen: Git

**Stand:** Auf GitHub (`r3v3nloper/wowf.actionbarswitcher`, Branch `main`) liegt nur der **allererste Stand**
(Commit „Add files via upload“, Version 1.0.0 mit Belegungsfenster). Alle späteren Änderungen (Versionen 1.1.0 bis 1.1.3)
gibt es **nur in diesem Ordner** bzw. in der ZIP `wowf.actionbarswitcher-v1.1.3.zip`. Die alte Cloud-Sitzung konnte
nicht pushen, weil die Claude GitHub App keinen Zugriff auf das Repo hatte (Fehler 403).

**Aufgabe:**
1. Prüfen, ob der Ordner bereits ein Git-Repo ist (`git status`).
   - Falls **nein**: `git clone https://github.com/r3v3nloper/wowf.actionbarswitcher.git` in einen Arbeitsordner,
     dann die Dateien aus diesem Ordner (Version 1.1.3) darüberkopieren.
   - Falls **ja**: `git pull` und dann prüfen, dass die Dateien Version 1.1.3 entsprechen
     (`ActionBarSwitcher/ActionBarSwitcher.toc` muss `## Version: 1.1.3` enthalten).
2. Tests laufen lassen (siehe Abschnitt 6), wenn Lua 5.1 vorhanden ist.
3. Committen, z. B. mit der Nachricht:
   `Stealth/form support for switched Action Bar 1, /abs debug (v1.1.3)`
4. Nach `main` pushen, sofern der Nutzer nichts anderes sagt.
5. Bei Push-Problemen: Ist Git installiert und ist der Nutzer bei GitHub angemeldet (Git Credential Manager,
   GitHub CLI `gh auth login` oder GitHub Desktop)?

Ordnerstruktur im Repo:

```
ActionBarSwitcher/          <- das eigentliche Addon (dieser Ordner kommt nach Interface\AddOns\)
  ActionBarSwitcher.toc
  Bindings.xml
  Locales.lua               (enUS + deDE)
  Core.lua                  (Hauptlogik, sichere Snippets)
  KeyBinds.lua              (Belegungsfenster /abs bind)
  Options.lua               (Einstellungen über Blizzards Settings-API)
tests/harness.lua           (Lua-5.1-Mock der WoW-API, 67 Testfälle)
README.md                   (Nutzer-Doku, Deutsch)
HANDOFF.md                  (diese Datei)
```

---

## 2. Worum es geht

Der Nutzer spielt **WoW Forever** (Client 1.60.x, Build ca. 70755), als **Schurke**. Er nutzt die Aktionsleisten
**1 und 2** und will beide **per Tastendruck** zwischen zwei Sets umschalten können (z. B. je nach Content).
Vorgaben:
- **Kein UI-Ersatz:** Blizzards Standardleisten bleiben (kein Bartender/Dominos/ElvUI-Stil).
- **Toggle statt „switch while hold“.**
- **Nie automatisch umschalten**, nur auf Tastendruck. Das muss aber auch im Kampf funktionieren.
- **Taste im Spiel frei wählbar**, z. B. Shift + 1. Ist umgesetzt, Shift + 1 funktioniert beim Nutzer.
- **Verstohlenheit:** Ist Set 2 aktiv und der Schurke geht in Verstohlenheit, soll Leiste 1 auf Blizzards
  Verstohlenheitsleiste wechseln. Danach soll sie wieder die Seite von Set 2 zeigen. Leiste 2 bleibt immer auf ihrer Set-Seite.

WoW Forever basiert auf der **Mainline-/Retail-UI (12.x, Midnight)** inklusive Secret Values und
Addon-Einschränkungen. Quelle: https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes.
Blizzard-UI-Quellcode als Referenz: https://github.com/Gethe/wow-ui-source (Branch `live`), vor allem
`Blizzard_ActionBar/Shared/ActionButton.lua`, `Blizzard_FrameXML/SecureTemplates.lua`,
`Blizzard_ActionBarController/ActionBarController.lua` und `Blizzard_RestrictedAddOnEnvironment/*`.

---

## 3. Aktueller Funktionsstand (v1.1.3)

| Funktion | Status im echten Spiel |
|---|---|
| Addon lädt, Einstellungen, Belegungsfenster | ✅ bestätigt (Screenshot) |
| Taste belegen (Shift + 1) über `/abs bind` | ✅ bestätigt |
| Set 1 ⇄ Set 2 umschalten (Leiste 1 und 2) | ✅ bestätigt |
| In Verstohlenheit (in Set 1) → auf Set 2 wechseln → Verstohlenheitsleiste bleibt | ✅ bestätigt (v1.1.2) |
| **Schon in Set 2 → in Verstohlenheit gehen → Verstohlenheitsleiste erscheint** | ❓ **in v1.1.3 umgesetzt, noch nicht im Spiel getestet** |
| Umschalten im Kampf | wahrscheinlich ok, nicht ausdrücklich bestätigt |

Standardkonfiguration: Set 1 = Leiste 1 Seite 1 / Leiste 2 Standard (Seite 6). Set 2 = Leiste 1 Seite 2 /
Leiste 2 Seite 13 (normalerweise Aktionsleiste 6, beim Nutzer unbenutzt).

Slash-Befehle: `/abs` (Einstellungen), `/abs bind`, `/abs next|prev|1-4`, `/abs name <n> <Name>`,
`/abs show|hide|lock|unlock`, `/abs check`, `/abs status`, `/abs reset`, `/abs debug`.

---

## 4. Technik: Wie es funktioniert

- **Leisten 2–8:** Jeder Blizzard-Button berechnet `slot = ID + (actionpage − 1) × 12` und liest `actionpage`
  zuerst vom Button selbst, dann von der Leiste (`useparent-actionpage`, `frame.bar`). Das Addon setzt
  `actionpage` direkt auf die 12 Buttons (z. B. `MultiBarBottomLeftButton1..12`). Der Button aktualisiert sich dann
  über `OnAttributeChanged → UpdateAction`. `nil` bedeutet: zurück zur Standardseite der Leiste.
- **Leiste 1:** Blizzards eigene Seite (`C_ActionBar.GetActionBarPage()`) bleibt **immer 1**, damit Blizzard
  Verstohlenheit, Formen und Fahrzeuge selbst handhabt. Blizzards `ActionBarController` setzt dann
  `MainActionBar:SetAttribute("actionpage", 7)` usw. Das Addon legt die Set-Seite als `actionpage` auf
  `ActionButton1..12`, **aber nur**, wenn
  1. die Set-Seite > 1 ist,
  2. `MainActionBar`'s `actionpage` gleich 1 ist und
  3. der State-Driver-Zustand `state-absbar1` nicht `special` ist.

  Sonst wird die Überschreibung entfernt (`nil`), und die Buttons folgen `MainActionBar`.
- **State-Driver** (`RegisterStateDriver(header, "absbar1", …)`), klassenabhängig gebaut in `BuildBar1StateDriver()`:
  `[petbattle][vehicleui][overridebar][possessbar][shapeshift][bonusbar]` plus `[stealth]` (Schurke) bzw.
  `[stealth][form]` (Druide) → `special`, sonst `normal`.
- **Alles läuft in gesicherten Snippets** eines Headers (`SecureHandlerStateTemplate`, Name
  `ActionBarSwitcherHeader`, Snippets `_abs_apply`, `_abs_bar1`, `_abs_reset`). Ausgelöst wird es durch den
  `SecureActionButtonTemplate`-Button `ActionBarSwitcherButton`, dessen `OnClick` per `SecureHandlerWrapScript`
  umhüllt ist. Tastenbelegungen sind `CLICK ActionBarSwitcherButton:next|prev|set1..set4`. Der Button registriert nur
  `AnyDown` und `useOnKeyDown = true` → genau ein Wechsel pro Tastendruck.
- Außerhalb des Kampfes (Login, `/abs <n>`, Einstellungen) wird über `SecureHandlerExecute` angewendet.
  Blizzards Buttons sollen **nie** von unsicherem Addon-Code Attribute bekommen, wegen Taint und Midnight-Secrets.
- Gespeichert wird pro Charakter in `ActionBarSwitcherCharDB`.

---

## 5. Wichtige Erkenntnisse aus dem Test im echten Spiel (WoW Forever)

Gemessen beim Schurken in Verstohlenheit, Set 2 aktiv, noch mit v1.1:
- `ActionBarSwitcherHeader:GetAttribute("state-absbar1")` → `normal`
- `SecureCmdOptionParse("[bonusbar]bonus;normal")` → **`normal`**. Die Makro-Bedingung **`[bonusbar]` ist in
  Verstohlenheit FALSCH** und deshalb unbrauchbar.
- `C_ActionBar.GetActionBarPage()` → `1`, `MainActionBar:GetAttribute("actionpage")` → **`7`**. Blizzard
  schaltet also korrekt auf die Verstohlenheitsseite 7.

Mit v1.1.2:
- Ein `SecureHandlerWrapScript(MainActionBar, "OnAttributeChanged", …)` **feuert offenbar nicht** (oder nicht
  zuverlässig). Ein Set-Wechsel *in* Verstohlenheit funktionierte, weil der Snippet dann `MainActionBar`'s Attribut
  liest. Der Eintritt in Verstohlenheit bei schon aktivem Set 2 wurde aber nicht erkannt.
  → In v1.1.3 deshalb `[stealth]` im State-Driver. Der Wrapper ist nur noch ein Zusatz-Trigger (Status in
  `/abs debug` als `wrap: ok|failed`).

Interface-Version in der TOC: `16001, 16000` (aus Addon-Seiten abgeleitet, nicht offiziell). Das Addon lädt beim
Nutzer. Ob „veraltet“ angezeigt wird, ist unbekannt.

Eingabelimit im WoW-Chat: ca. 255 Zeichen. Dem Nutzer also keine langen `/run`-Zeilen geben, sondern `/abs debug`.

---

## 6. Tests

```
lua5.1 tests/harness.lua                         # Englisch
lua5.1 tests/harness.lua ActionBarSwitcher deDE  # Deutsch
```

Der Harness bildet unter anderem nach: Restricted Environment (Snippets mit `owner`/`self`), Frame-Refs,
`SecureHandlerExecute`, Click-Wrapper, State-Driver (manuell gesteuert), Kampfsperre für unsichere
`SetAttribute`-Aufrufe, Blizzards `MainActionBar`-Paging, Tastenbelegungs-API und Settings-API.
Er bildet auch die Forever-Eigenheit nach, dass der `OnAttributeChanged`-Wrap nicht feuert.
Er ersetzt **keinen** Test im echten Spiel.

---

## 7. Nächste Schritte

1. **Git-Push** (Abschnitt 1).
2. Den Nutzer **v1.1.3 im Spiel testen** lassen: In Set 2 wechseln, in Verstohlenheit gehen, Verstohlenheit
   verlassen, das Ganze auch im Kampf.
   - Klappt es nicht: In Verstohlenheit `/abs debug` eingeben und einen Screenshot schicken lassen.
     Darauf achten: `state:` (soll `special` sein), `stealth:` (soll `yes` sein), `main bar:` (soll `7` sein),
     `btn1:` (Attribut soll `nil` sein).
   - Ist `stealth: no`, funktioniert auch `[stealth]` in Forever nicht. Dann wäre die Alternative eine Erkennung über
     Events: unsicherer Code merkt `UPDATE_BONUS_ACTIONBAR`/`UPDATE_SHAPESHIFT_FORM`, kann aber im Kampf keine
     Attribute setzen. Also bräuchte es einen anderen sicheren Trigger, z. B. einen `SecureHandlerAttributeTemplate`
     auf einem eigenen Frame, der per State-Driver mit `[stance]`/`[form]` angestoßen wird. Vorher die `/abs debug`-Werte
     auswerten.
3. Optional: Prüfen, ob die TOC-Interface-Nummer stimmt (`/dump select(4, GetBuildInfo())` im Spiel).

---

## 8. Hinweise zur Zusammenarbeit mit dem Nutzer

- Deutsch, locker, kurze klare Schritt-für-Schritt-Anleitungen. Der Nutzer ist kein Entwickler.
- Er wurde schon frustriert, als Dinge nicht funktionierten. Ehrlich sagen, was getestet ist und was nicht.
  Nichts als „funktioniert“ verkaufen, was nur im Mock getestet wurde.
- Neue Versionen als fertigen Ordner bzw. ZIP bereitstellen. Installation: Ordner `ActionBarSwitcher` in
  `...\World of Warcraft\<Forever-Ordner>\Interface\AddOns\` ersetzen, im Spiel `/reload`.
- Bei jeder Änderung die Version in der `.toc` hochzählen, damit der Nutzer mit `/abs debug` prüfen kann, welche
  Version läuft.
