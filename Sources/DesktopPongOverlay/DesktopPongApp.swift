import AppKit

@main
@MainActor
enum DesktopPongApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsStore: SettingsStore!
    private var inputMonitor: InputMonitor!
    private var haptics: HapticFeedbackController!
    private var overlayController: OverlayWindowController!
    private var menuBarGameController: MenuBarGameController!
    private var preferencesController: PreferencesWindowController!
    private var aboutController: AboutWindowController!
    private var statusMenuController: StatusMenuController!
    private var globalShortcutController: GlobalShortcutController!
    private var registeredGlobalToggle = KeyBinding.p

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore = SettingsStore()
        inputMonitor = InputMonitor()
        haptics = HapticFeedbackController()
        overlayController = OverlayWindowController(
            settingsStore: settingsStore,
            inputMonitor: inputMonitor,
            haptics: haptics
        )
        menuBarGameController = MenuBarGameController(settingsStore: settingsStore, haptics: haptics)
        preferencesController = PreferencesWindowController(
            settingsStore: settingsStore,
            resetGame: { [weak overlayController] in overlayController?.resetGame() }
        )
        aboutController = AboutWindowController()
        statusMenuController = StatusMenuController(
            overlayController: overlayController,
            menuBarGameController: menuBarGameController,
            settingsStore: settingsStore,
            preferencesController: preferencesController,
            aboutController: aboutController,
            haptics: haptics
        )
        globalShortcutController = GlobalShortcutController { [weak statusMenuController] in
            statusMenuController?.toggleActiveSurface()
        }
        registeredGlobalToggle = settingsStore.settings.controlBindings.globalToggle
        globalShortcutController.register(binding: registeredGlobalToggle)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: SettingsStore.didChangeNotification,
            object: settingsStore
        )
        configureMainMenu()
        if settingsStore.settings.presentationMode == .desktopOverlay {
            overlayController.showOverlay()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func settingsDidChange() {
        let globalToggle = settingsStore.settings.controlBindings.globalToggle
        guard globalToggle != registeredGlobalToggle else { return }
        registeredGlobalToggle = globalToggle
        globalShortcutController.register(binding: globalToggle)
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Desktop Pong Overlay")
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        let aboutItem = NSMenuItem(title: "About Desktop Pong Overlay", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Desktop Pong Overlay", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let gameMenuItem = NSMenuItem()
        let gameMenu = NSMenu(title: "Game")
        gameMenu.addItem(commandItem("Show/Hide Overlay", action: #selector(toggleOverlay), key: "h"))
        gameMenu.addItem(commandItem("Open/Close Menu Bar Game", action: #selector(toggleMenuBarGame), key: "m"))
        gameMenu.addItem(commandItem("Pause/Resume", action: #selector(togglePause), key: "p"))
        gameMenu.addItem(commandItem("Reset Score", action: #selector(resetScore), key: "r"))
        gameMenu.addItem(commandItem("Capture Input", action: #selector(toggleCapture), key: "i"))
        gameMenuItem.submenu = gameMenu
        mainMenu.addItem(gameMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func commandItem(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openSettings() {
        overlayController.setInputCapture(false)
        preferencesController.present()
    }

    @objc private func openAbout() {
        overlayController.setInputCapture(false)
        aboutController.present()
    }
    @objc private func toggleOverlay() { overlayController.toggleOverlay() }
    @objc private func toggleMenuBarGame() {
        let title = menuBarGameController.isShown ? "Close Menu Bar Game" : "Open Menu Bar Game"
        statusMenuController.performRuntimeMenuAction(titled: title)
    }
    @objc private func togglePause() {
        if menuBarGameController.isShown {
            menuBarGameController.togglePause()
        } else {
            overlayController.togglePause()
        }
    }
    @objc private func resetScore() {
        overlayController.resetGame()
        menuBarGameController.resetGame()
    }
    @objc private func toggleCapture() { overlayController.toggleInputCapture() }
}
