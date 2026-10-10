import SwiftUI
import Carbon
import ServiceManagement

/// Deutsch, wenn die Systemsprache Deutsch ist, sonst Englisch.
enum L10n {
    static let isGerman = Locale.preferredLanguages.first?.hasPrefix("de") ?? false
    static func t(_ de: String, _ en: String) -> String { isGerman ? de : en }

    static var windowTitle: String { t("Simple Search Einstellungen", "Simple Search Settings") }
    static var shortcut: String { t("Tastenkürzel", "Keyboard Shortcut") }
    static var recording: String { t("Kürzel drücken … (Esc bricht ab)", "Press shortcut … (Esc cancels)") }
    static var launchAtLogin: String { t("Beim Login starten", "Start at Login") }
    static var leertaste: String { t("Leertaste", "Space") }
}

final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var keyCode: UInt32
    @Published var modifiers: UInt32
    @Published var keyLabel: String
    @Published var recording = false
    @Published var launchAtLogin: Bool
    @Published var loginError: String?
    private var monitor: Any?

    init() {
        keyCode = d.object(forKey: "keyCode") as? UInt32 ?? UInt32(kVK_Space)
        modifiers = d.object(forKey: "modifiers") as? UInt32 ?? UInt32(optionKey)
        keyLabel = d.string(forKey: "keyLabel") ?? L10n.leertaste
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if keyCode == UInt32(kVK_Space) { keyLabel = L10n.leertaste }
    }

    var shortcutText: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + " " + keyLabel
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self else { return e }
            if e.keyCode == UInt16(kVK_Escape) { self.stopRecording(); return nil }
            var mods: UInt32 = 0
            if e.modifierFlags.contains(.command) { mods |= UInt32(cmdKey) }
            if e.modifierFlags.contains(.option) { mods |= UInt32(optionKey) }
            if e.modifierFlags.contains(.control) { mods |= UInt32(controlKey) }
            if e.modifierFlags.contains(.shift) { mods |= UInt32(shiftKey) }
            guard mods != 0 else { NSSound.beep(); return nil }
            self.keyCode = UInt32(e.keyCode)
            self.modifiers = mods
            self.keyLabel = Self.label(for: e)
            self.d.set(self.keyCode, forKey: "keyCode")
            self.d.set(self.modifiers, forKey: "modifiers")
            self.d.set(self.keyLabel, forKey: "keyLabel")
            self.stopRecording()
            return nil
        }
    }

    func stopRecording() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        recording = false
    }

    private static func label(for e: NSEvent) -> String {
        switch Int(e.keyCode) {
        case kVK_Space: return L10n.leertaste
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: return (e.charactersIgnoringModifiers ?? "?").uppercased()
        }
    }
}

struct SettingsView: View {
    @ObservedObject var s = Settings.shared

    var body: some View {
        Form {
            LabeledContent(L10n.shortcut) {
                Button(s.recording ? L10n.recording : s.shortcutText) {
                    s.recording ? s.stopRecording() : s.startRecording()
                }
            }
            Toggle(L10n.launchAtLogin, isOn: Binding(get: { s.launchAtLogin }, set: { s.setLaunchAtLogin($0) }))
            if let e = s.loginError {
                Text(e).font(.caption).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .frame(width: 420)
        .onDisappear { s.stopRecording() }
    }
}
