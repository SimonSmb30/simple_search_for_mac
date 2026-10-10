import SwiftUI
import Carbon
import ServiceManagement

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
        keyLabel = d.string(forKey: "keyLabel") ?? "Leertaste"
        launchAtLogin = SMAppService.mainApp.status == .enabled
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
        case kVK_Space: return "Leertaste"
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
            LabeledContent("Tastenkürzel") {
                Button(s.recording ? "Kürzel drücken … (Esc bricht ab)" : s.shortcutText) {
                    s.recording ? s.stopRecording() : s.startRecording()
                }
            }
            Toggle("Beim Login starten", isOn: Binding(get: { s.launchAtLogin }, set: { s.setLaunchAtLogin($0) }))
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
