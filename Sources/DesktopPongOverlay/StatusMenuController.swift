import AppKit

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let overlayController: OverlayWindowController
    private let menuBarGameController: MenuBarGameController
    private let settingsStore: SettingsStore
    private let preferencesController: PreferencesWindowController
    private let aboutController: AboutWindowController
    private let haptics: HapticFeedbackController

    private let menu: NSMenu
    private let overlayItem = NSMenuItem()
    private let menuBarGameItem = NSMenuItem()
    private let pauseItem = NSMenuItem()
    private let captureItem = NSMenuItem()
    private let globalShortcutItem = NSMenuItem()
    private var appliedPresentationMode: PresentationMode
    private var presentationItems: [PresentationMode: NSMenuItem] = [:]
    private var modeItems: [GameMode: NSMenuItem] = [:]
    private var difficultyItems: [(value: Double, item: NSMenuItem)] = []

    init(
        overlayController: OverlayWindowController,
        menuBarGameController: MenuBarGameController,
        settingsStore: SettingsStore,
        preferencesController: PreferencesWindowController,
        aboutController: AboutWindowController,
        haptics: HapticFeedbackController
    ) {
        self.overlayController = overlayController
        self.menuBarGameController = menuBarGameController
        self.settingsStore = settingsStore
        self.preferencesController = preferencesController
        self.aboutController = aboutController
        self.haptics = haptics
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menu = NSMenu(title: "Desktop Pong Overlay")
        appliedPresentationMode = settingsStore.settings.presentationMode
        super.init()

        menu.delegate = self
        configureStatusButton()
        buildMenu()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: SettingsStore.didChangeNotification,
            object: settingsStore
        )
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        overlayItem.title = overlayController.isOverlayVisible ? "Hide Overlay" : "Show Overlay"
        menuBarGameItem.title = menuBarGameController.isShown ? "Close Menu Bar Game" : "Open Menu Bar Game"
        pauseItem.title = activeSceneIsPaused ? "Resume" : "Pause"
        captureItem.state = settingsStore.settings.passThrough ? .off : .on
        globalShortcutItem.title = "Global Shortcut: \(GlobalShortcutController.shortcutDescription(for: settingsStore.settings.controlBindings.globalToggle))"
        presentationItems.forEach { mode, item in
            item.state = settingsStore.settings.presentationMode == mode ? .on : .off
        }
        modeItems.forEach { mode, item in
            item.state = settingsStore.settings.mode == mode ? .on : .off
        }
        difficultyItems.forEach { value, item in
            item.state = abs(settingsStore.settings.aiSkill - value) < 0.03 ? .on : .off
        }
    }

    func toggleActiveSurface() {
        haptics.click()
        switch settingsStore.settings.presentationMode {
        case .desktopOverlay:
            menuBarGameController.close()
            overlayController.toggleOverlay()
        case .menuBarGame:
            overlayController.hideOverlay()
            guard let button = statusItem.button else { return }
            menuBarGameController.toggle(relativeTo: button)
        }
    }

    func runtimeMenuTitles() -> [String] {
        menuNeedsUpdate(menu)
        return flattenedTitles(in: menu)
    }

    @discardableResult
    func performRuntimeMenuAction(titled title: String) -> Bool {
        menuNeedsUpdate(menu)
        guard let item = findItem(titled: title, in: menu),
              let action = item.action else { return false }
        return NSApp.sendAction(action, to: item.target, from: item)
    }

    private var activeSceneIsPaused: Bool {
        if menuBarGameController.isShown {
            menuBarGameController.runtimeSnapshot().scenePaused
        } else {
            overlayController.scene.isGamePaused
        }
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.image = .desktopPongMenuBarIcon()
        button.imagePosition = .imageOnly
        button.toolTip = "Desktop Pong Overlay — click to toggle, right-click for menu"
        button.target = self
        button.action = #selector(statusButtonPressed)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func buildMenu() {
        configure(overlayItem, title: "Hide Overlay", action: #selector(toggleOverlay), key: "h")
        configure(menuBarGameItem, title: "Open Menu Bar Game", action: #selector(toggleMenuBarGame), key: "m")
        configure(pauseItem, title: "Pause", action: #selector(togglePause), key: "p")
        menu.addItem(overlayItem)
        menu.addItem(menuBarGameItem)
        menu.addItem(pauseItem)
        menu.addItem(actionItem("Reset Score", action: #selector(resetScore), key: "r"))
        menu.addItem(.separator())

        let presentationItem = NSMenuItem(title: "Presentation", action: nil, keyEquivalent: "")
        let presentationMenu = NSMenu(title: "Presentation")
        for mode in PresentationMode.allCases {
            let item = actionItem(mode.title, action: #selector(selectPresentation(_:)))
            item.representedObject = mode.rawValue
            presentationItems[mode] = item
            presentationMenu.addItem(item)
        }
        presentationItem.submenu = presentationMenu
        menu.addItem(presentationItem)

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
        globalShortcutItem.title = "Global Shortcut: \(GlobalShortcutController.shortcutDescription(for: settingsStore.settings.controlBindings.globalToggle))"
        globalShortcutItem.isEnabled = false
        menu.addItem(globalShortcutItem)
        menu.addItem(actionItem("Quit Desktop Pong Overlay", action: #selector(quit), key: "q"))
    }

    private func actionItem(_ title: String, action: Selector?, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = action == nil ? nil : self
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

    private func showControlMenu(from button: NSStatusBarButton) {
        menuNeedsUpdate(menu)
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: button.bounds.midX, y: button.bounds.minY - 4),
            in: button
        )
    }

    @objc private func statusButtonPressed() {
        guard let button = statusItem.button else { return }
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        wantsMenu ? showControlMenu(from: button) : toggleActiveSurface()
    }

    @objc private func toggleOverlay() {
        guard settingsStore.settings.presentationMode == .desktopOverlay else {
            settingsStore.settings.presentationMode = .desktopOverlay
            return
        }
        menuBarGameController.close()
        overlayController.toggleOverlay()
    }

    @objc private func toggleMenuBarGame() {
        guard settingsStore.settings.presentationMode == .menuBarGame else {
            settingsStore.settings.presentationMode = .menuBarGame
            return
        }
        overlayController.hideOverlay()
        guard let button = statusItem.button else { return }
        menuBarGameController.toggle(relativeTo: button)
    }

    @objc private func togglePause() {
        if menuBarGameController.isShown {
            menuBarGameController.togglePause()
        } else {
            overlayController.togglePause()
            haptics.click()
        }
    }

    @objc private func resetScore() {
        overlayController.resetGame()
        menuBarGameController.resetGame()
        haptics.click()
    }

    @objc private func toggleCapture() { overlayController.toggleInputCapture() }
    @objc private func openPreferences() { preferencesController.present() }
    @objc private func openAbout() { aboutController.present() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func selectPresentation(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = PresentationMode(rawValue: rawValue) else { return }
        settingsStore.settings.presentationMode = mode
        applyPresentationMode(mode)
    }

    @objc private func settingsDidChange() {
        let mode = settingsStore.settings.presentationMode
        guard mode != appliedPresentationMode else { return }
        applyPresentationMode(mode)
    }

    private func applyPresentationMode(_ mode: PresentationMode) {
        appliedPresentationMode = mode
        switch mode {
        case .desktopOverlay:
            menuBarGameController.close()
            overlayController.showOverlay()
        case .menuBarGame:
            overlayController.hideOverlay()
            guard let button = statusItem.button else { return }
            menuBarGameController.show(relativeTo: button)
        }
    }

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

private extension NSImage {
    static func desktopPongMenuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 18))
        image.lockFocus()
        NSColor.labelColor.setStroke()
        NSColor.labelColor.setFill()

        let screenRect = NSRect(x: 2.5, y: 3.5, width: 13, height: 11)
        let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 2.5, yRadius: 2.5)
        screenPath.lineWidth = 2
        screenPath.stroke()

        let paddle = NSBezierPath(roundedRect: NSRect(x: 15.5, y: 3, width: 4.5, height: 4.5), xRadius: 1, yRadius: 1)
        paddle.fill()

        let arrow = NSBezierPath()
        arrow.lineWidth = 2
        arrow.lineCapStyle = .round
        arrow.lineJoinStyle = .round
        arrow.move(to: NSPoint(x: 6, y: 11))
        arrow.line(to: NSPoint(x: 10.5, y: 6.5))
        arrow.move(to: NSPoint(x: 10.5, y: 6.5))
        arrow.line(to: NSPoint(x: 10.5, y: 10))
        arrow.move(to: NSPoint(x: 10.5, y: 6.5))
        arrow.line(to: NSPoint(x: 7, y: 6.5))
        arrow.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
