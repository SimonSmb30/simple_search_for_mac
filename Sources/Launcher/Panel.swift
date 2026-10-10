import AppKit
import Combine
import SwiftUI
import Carbon

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var panel: KeyPanel!
    private let model = SearchModel()
    private var hotkey: Hotkey?
    private var monitor: Any?
    private let container = NSView()
    private let margin: CGFloat = 40

    func applicationDidFinishLaunching(_ n: Notification) {
        let hosting = NSHostingView(rootView: SearchView(model: model))
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let glass = NSGlassEffectView()
        glass.cornerRadius = 30
        glass.style = .regular
        glass.contentView = hosting
        glass.translatesAutoresizingMaskIntoConstraints = false

        // Container mit Rand, damit der Overshoot der Animation nicht vom Fenster abgeschnitten wird.
        container.wantsLayer = true
        container.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: margin),
            glass.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -margin),
            glass.topAnchor.constraint(equalTo: container.topAnchor, constant: margin),
            glass.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -margin),
        ])

        panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 680 + 2 * margin, height: fieldHeight + 2 * margin),
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        panel.contentView = container
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        model.onClose = { [weak self] in self?.hide() }

        // Panelhöhe folgt der Trefferzahl, die Oberkante bleibt stehen.
        model.$results.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.resize(animated: true) }
            .store(in: &cancellables)

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self, self.panel.isVisible else { return e }
            switch Int(e.keyCode) {
            case kVK_Tab:
                self.model.move(e.modifierFlags.contains(.shift) ? -1 : 1); return nil
            case kVK_DownArrow: self.model.move(1); return nil
            case kVK_UpArrow: self.model.move(-1); return nil
            case kVK_Return, kVK_ANSI_KeypadEnter: self.model.launchSelected(); return nil
            case kVK_Escape: self.hide(); return nil
            case kVK_ANSI_Comma where e.modifierFlags.contains(.command):
                self.hide(); self.openSettings(); return nil
            default: return e
            }
        }

        let st = Settings.shared
        Publishers.CombineLatest3(st.$keyCode, st.$modifiers, st.$recording)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] code, mods, recording in
                self?.hotkey = nil
                guard !recording else { return }
                self?.hotkey = Hotkey(keyCode: code, modifiers: mods) { [weak self] in self?.toggle() }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func toggle() { panel.isVisible ? hide() : show() }

    private func show() {
        guard !closing else { return }
        model.reset()
        resize(animated: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        container.layoutSubtreeIfNeeded()
        popOpen()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    /// Von der Mitte nach außen aufgehen, überschwingen, zurückfedern.
    private func popOpen() {
        guard let layer = container.layer else { return }
        let c = CGPoint(x: container.bounds.midX, y: container.bounds.midY)
        var from = CATransform3DMakeTranslation(c.x, c.y, 0)
        from = CATransform3DScale(from, 0.4, 0.4, 1)
        from = CATransform3DTranslate(from, -c.x, -c.y, 0)
        let spring = CASpringAnimation(keyPath: "transform")
        spring.fromValue = NSValue(caTransform3D: from)
        spring.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        spring.mass = 1
        spring.stiffness = 320
        spring.damping = 25
        spring.initialVelocity = 0
        spring.duration = spring.settlingDuration
        layer.add(spring, forKey: "pop")
    }

    private var closing = false
    private var settingsWindow: NSWindow?

    /// Ohne Menüleisten-Icon: erneutes Öffnen der App (Finder, Dock, Spotlight) zeigt die Einstellungen.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 150),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = L10n.windowTitle
            w.contentView = NSHostingView(rootView: SettingsView())
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Kurz aufblähen, dann schnell zur Mitte schrumpfen und ausblenden.
    private func hide() {
        guard !closing, let layer = container.layer else { return }
        closing = true
        let c = CGPoint(x: container.bounds.midX, y: container.bounds.midY)
        func scaled(_ k: CGFloat) -> NSValue {
            var t = CATransform3DMakeTranslation(c.x, c.y, 0)
            t = CATransform3DScale(t, k, k, 1)
            t = CATransform3DTranslate(t, -c.x, -c.y, 0)
            return NSValue(caTransform3D: t)
        }
        let duration = 0.22
        let anim = CAKeyframeAnimation(keyPath: "transform")
        anim.values = [scaled(1), scaled(1.03), scaled(0.4)]
        anim.keyTimes = [0, 0.3, 1]
        anim.timingFunctions = [CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .easeIn)]
        anim.duration = duration
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        layer.add(anim, forKey: "close")
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.panel.orderOut(nil)
            self.container.layer?.removeAllAnimations()
            self.closing = false
        })
    }

    private func resize(animated: Bool) {
        guard let screen = NSScreen.main else { return }
        let h = model.panelHeight
        let w: CGFloat = 680 + 2 * margin
        let x = screen.frame.midX - w / 2
        let top = screen.frame.maxY - screen.frame.height * 0.22 + margin
        let frame = NSRect(x: x, y: top - h - 2 * margin, width: w, height: h + 2 * margin)
        panel.setFrame(frame, display: true, animate: animated && panel.isVisible)
    }

    func windowDidResignKey(_ n: Notification) { if panel.isVisible { hide() } }
}
