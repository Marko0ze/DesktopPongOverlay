import AppKit

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let overlayController: OverlayWindowController
    private let settingsStore: SettingsStore
    private let preferencesController: PreferencesWindowController
    private let aboutController: AboutWindowController

    private let overlayItem = NSMenuItem()
    private let pauseItem = NSMenuItem()
    private let captureItem = NSMenuItem()
    private var modeItems: [GameMode: NSMenuItem] = [:]
    private var difficultyItems: [(value: Double, item: NSMenuItem)] = []

    init(
        overlayController: OverlayWindowController,
        settingsStore: SettingsStore,
        preferencesController: PreferencesWindowController,
        aboutController: AboutWindowController
    ) {
        self.overlayController = overlayController
        self.settingsStore = settingsStore
        self.preferencesController = preferencesController
        self.aboutController = aboutController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.title = "🏓"
        statusItem.button?.toolTip = "Desktop Pong Overlay"
        statusItem.menu = buildMenu()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        overlayItem.title = overlayController.isOverlayVisible ? "Hide Overlay" : "Show Overlay"
        pauseItem.title = overlayController.scene.isGamePaused ? "Resume" : "Pause"
        captureItem.state = settingsStore.settings.passThrough ? .off : .on
        modeItems.forEach { mode, item in
            item.state = settingsStore.settings.mode == mode ? .on : .off
        }
        difficultyItems.forEach { value, item in
            item.state = abs(settingsStore.settings.aiSkill - value) < 0.03 ? .on : .off
        }
    }

    func runtimeMenuTitles() -> [String] {
        guard let menu = statusItem.menu else { return [] }
        menuNeedsUpdate(menu)
        return flattenedTitles(in: menu)
    }

    @discardableResult
    func performRuntimeMenuAction(titled title: String) -> Bool {
        guard let menu = statusItem.menu else { return false }
        menuNeedsUpdate(menu)
        guard let item = findItem(titled: title, in: menu),
              let action = item.action else { return false }
        return NSApp.sendAction(action, to: item.target, from: item)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "Desktop Pong Overlay")
        menu.delegate = self

        configure(overlayItem, title: "Hide Overlay", action: #selector(toggleOverlay), key: "h")
        configure(pauseItem, title: "Pause", action: #selector(togglePause), key: "p")
        menu.addItem(overlayItem)
        menu.addItem(pauseItem)
        menu.addItem(actionItem("Reset Score", action: #selector(resetScore), key: "r"))
        menu.addItem(.separator())

        let modeItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        let modeMenu = NSMenu(title: "Mode")
        for mode in GameMode.allCases {
            let item = actionItem(mode.title, action: #selector(selectMode(_:)))
            item.representedObject = mode.rawValue
            modeItems[mode] = item
            modeMenu.addItem(item)
        }
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        let difficultyItem = NSMenuItem(title: "AI Difficulty", action: nil, keyEquivalent: "")
        let difficultyMenu = NSMenu(title: "AI Difficulty")
        for option in [("Easy", 0.20), ("Normal", 0.50), ("Hard", 0.78), ("Original-ish", 0.95)] {
            let item = actionItem(option.0, action: #selector(selectDifficulty(_:)))
            item.representedObject = option.1
            difficultyItems.append((option.1, item))
            difficultyMenu.addItem(item)
        }
        difficultyItem.submenu = difficultyMenu
        menu.addItem(difficultyItem)

        configure(captureItem, title: "Capture Input", action: #selector(toggleCapture), key: "i")
        menu.addItem(captureItem)
        menu.addItem(.separator())
        menu.addItem(actionItem("Settings…", action: #selector(openPreferences), key: ","))
        menu.addItem(actionItem("About Desktop Pong Overlay", action: #selector(openAbout)))
        menu.addItem(.separator())
        menu.addItem(actionItem("Quit Desktop Pong Overlay", action: #selector(quit), key: "q"))
        return menu
    }

    private func actionItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func flattenedTitles(in menu: NSMenu) -> [String] {
        menu.items.flatMap { item -> [String] in
            guard !item.isSeparatorItem else { return [] }
            if let submenu = item.submenu {
                return [item.title] + flattenedTitles(in: submenu)
            }
            return [item.title]
        }
    }

    private func findItem(titled title: String, in menu: NSMenu) -> NSMenuItem? {
        for item in menu.items where !item.isSeparatorItem {
            if item.title == title { return item }
            if let submenu = item.submenu,
               let match = findItem(titled: title, in: submenu) {
                return match
            }
        }
        return nil
    }

    private func configure(_ item: NSMenuItem, title: String, action: Selector, key: String) {
        item.title = title
        item.action = action
        item.keyEquivalent = key
        item.target = self
    }

    @objc private func toggleOverlay() { overlayController.toggleOverlay() }
    @objc private func togglePause() { overlayController.togglePause() }
    @objc private func resetScore() { overlayController.resetGame() }
    @objc private func toggleCapture() { overlayController.toggleInputCapture() }
    @objc private func openPreferences() { preferencesController.present() }
    @objc private func openAbout() { aboutController.present() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = GameMode(rawValue: rawValue) else { return }
        settingsStore.settings.mode = mode
    }

    @objc private func selectDifficulty(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        settingsStore.settings.aiSkill = value
    }
}
