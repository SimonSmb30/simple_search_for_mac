# Simple Search

Minimaler Spotlight-Ersatz für macOS 26: Hotkey öffnet ein Suchfeld, Tippen filtert die installierten Apps, Enter startet die markierte App.

## Bedienung
- **Öffnen/Schließen:** Hotkey (Standard ⌥+Leertaste, in den Einstellungen änderbar)
- **Tippen:** filtert Apps (Präfix > Wortanfang > enthalten > Teilfolge). Ohne Eingabe ist nur das Suchfeld zu sehen.
- **Tab / Shift+Tab / ↓ / ↑:** Auswahl bewegen, **Enter:** App starten, **Esc** oder Klick daneben: schließen
- **Einstellungen:** ⌘+Komma im Suchfenster oder die App erneut öffnen (kein Menüleisten-Icon)
  - Tastenkürzel aufnehmen
  - Beim Login starten

## Design
- Liquid Glass (`NSGlassEffectView`), Radius 30 (bei leerem Feld eine Kapsel)
- Öffnen: Feder-Animation von der Mitte aus, dezenter Overshoot (`damping` 25)
- Schließen: kurz auf 103 % aufblähen, dann zur Mitte auf 40 % schrumpfen und ausblenden (0,22 s)

## Bauen und starten
```bash
./build.sh && open "Simple Search.app"
```
`build.sh` baut mit SwiftPM, erzeugt `AppIcon.icns` nicht neu (liegt im Ordner), packt `Simple Search.app` (`LSUIElement`, kein Dock-Icon) und signiert ad hoc. Beenden: `pkill "Simple Search"`.

## ⌘+Leertaste statt ⌥+Leertaste
Spotlight-Shortcut abschalten (Systemeinstellungen → Tastatur → Tastaturkurzbefehle → Spotlight), dann in Simple Search das Kürzel aufnehmen. Per Terminal (danach ggf. abmelden):
```bash
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 '{ enabled = 0; value = { parameters = (32, 49, 1048576); type = standard; }; }'
```

## Struktur
| Datei | Aufgabe |
|---|---|
| `Sources/Launcher/main.swift` | Start, `.accessory`-Policy |
| `Sources/Launcher/Panel.swift` | AppDelegate, Glas-Panel, Tastatursteuerung, Animationen, Einstellungsfenster |
| `Sources/Launcher/SearchView.swift` | SwiftUI-Suchfeld und Liste, `SearchModel` |
| `Sources/Launcher/AppIndex.swift` | App-Scan (`/Applications`, `/System/Applications`, `~/Applications`) und Fuzzy-Filter |
| `Sources/Launcher/Hotkey.swift` | Globaler Hotkey über Carbon |
| `Sources/Launcher/Settings.swift` | Einstellungen (UserDefaults), Kürzel-Recorder, Login-Start (`SMAppService`) |
| `icon.svg` / `AppIcon.icns` | App-Icon (icns aus der SVG gerendert) |
