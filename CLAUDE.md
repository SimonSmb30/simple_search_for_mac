# Simple Search

macOS-26-App (Swift 6.2 Package, Language Mode 5, SwiftUI + AppKit), die nur Apps sucht und startet. Siehe README.md für Bedienung und Struktur.

## Befehle
- Bauen + starten: `./build.sh && open "Simple Search.app"`
- Beenden: `pkill "Simple Search"` (Prozessname, nicht "Launcher")

## Konventionen und Entscheidungen
- Swift-Target heißt intern `Launcher`, das App-Bundle und der Prozess `Simple Search`.
- Kein Menüleisten- und kein Dock-Icon (`LSUIElement`, `.accessory`). Einstellungen nur per ⌘+Komma im Panel oder App erneut öffnen (`applicationShouldHandleReopen`). Nicht ungefragt ein Menüleisten-Icon einbauen.
- Panel ist ein `NSPanel` mit 40 pt transparentem Rand um das Glas (`margin`), damit der Overshoot der Öffnen-Animation nicht abgeschnitten wird. Panelhöhe = `SearchModel.panelHeight`; bei leerem Suchfeld ist die Liste eingeklappt.
- Tastatursteuerung über lokalen `NSEvent`-Monitor in `Panel.swift`, nicht über SwiftUI-`onKeyPress` (Tab wird sonst vom Fokussystem abgefangen).
- Hotkey liegt in UserDefaults (`keyCode`, `modifiers`, `keyLabel`), Standard ⌥+Leertaste. Beim Aufnehmen wird der Hotkey kurz deaktiviert.
- Animationsparameter: Öffnen `CASpringAnimation` (stiffness 320, damping 25, Start 40 %), Schließen Keyframes 1 → 1,03 → 0,4 in 0,22 s.
- Icon: `icon.svg` wird manuell zu `AppIcon.icns` gerendert, `build.sh` kopiert nur die vorhandene icns.

## Hinweise
- Systemeinstellungen (Spotlight-Shortcut abschalten) macht der Nutzer selbst; nicht ungefragt per Befehl ändern.
- Login-Start (`SMAppService.mainApp`) klappt zuverlässiger, wenn die App in `/Applications` liegt.
