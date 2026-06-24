import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSWindowController {
    init(settingsStore: SettingsStore, resetGame: @escaping () -> Void) {
        let rootView = PreferencesView(store: settingsStore, resetGame: resetGame)
        let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
        window.title = "Desktop Pong Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 500, height: 650))
        window.minSize = NSSize(width: 460, height: 520)
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

@MainActor
final class AboutWindowController: NSWindowController {
    init() {
        let view = VStack(spacing: 12) {
            Text("🏓")
                .font(.system(size: 48))
            Text("Desktop Pong Overlay")
                .font(.title2.weight(.semibold))
            Text("A transparent desktop Pong game built from scratch for macOS.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("No screen recording, network, or analytics. Keyboard capture is temporary and gameplay-key filtered.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(width: 390, height: 245)

        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "About Desktop Pong Overlay"
        window.styleMask = [.titled, .closable]
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
