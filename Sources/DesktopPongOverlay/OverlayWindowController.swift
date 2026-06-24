import AppKit
import SpriteKit

@MainActor
final class OverlayWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private let inputMonitor: InputMonitor
    private let haptics: HapticFeedbackController
    private(set) var scene: PongScene!
    private(set) var isOverlayVisible = false

    private var overlayPanel: TransparentOverlayPanel {
        window as! TransparentOverlayPanel
    }

    init(settingsStore: SettingsStore, inputMonitor: InputMonitor, haptics: HapticFeedbackController) {
        self.settingsStore = settingsStore
        self.inputMonitor = inputMonitor
        self.haptics = haptics

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let overlayFrame = Self.overlayFrame(for: screen)
        let panel = TransparentOverlayPanel(
            contentRect: overlayFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        super.init(window: panel)
        configure(panel: panel, screen: screen)

        let skView = SKView(frame: panel.contentView?.bounds ?? CGRect(origin: .zero, size: overlayFrame.size))
        skView.autoresizingMask = [.width, .height]
        skView.allowsTransparency = true
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        skView.wantsLayer = true
        skView.layer?.backgroundColor = NSColor.clear.cgColor

        let scene = PongScene(size: skView.bounds.size, settingsStore: settingsStore, inputMonitor: inputMonitor)
        scene.screenOriginY = overlayFrame.minY
        scene.onImpact = { [weak haptics] in haptics?.impact() }
        skView.presentScene(scene)
        panel.contentView = skView
        self.scene = scene

        inputMonitor.start()
        applyPassThroughSetting()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: SettingsStore.didChangeNotification,
            object: settingsStore
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func showOverlay() {
        guard !isOverlayVisible else { return }
        resizeToMainScreen()
        overlayPanel.orderFrontRegardless()
        isOverlayVisible = true
    }

    func hideOverlay() {
        overlayPanel.orderOut(nil)
        isOverlayVisible = false
    }

    func toggleOverlay() {
        isOverlayVisible ? hideOverlay() : showOverlay()
    }

    func togglePause() {
        scene.togglePause()
    }

    func resetGame() {
        scene.resetGame()
    }

    func toggleInputCapture() {
        setInputCapture(settingsStore.settings.passThrough)
    }

    func setInputCapture(_ enabled: Bool) {
        if enabled {
            if settingsStore.settings.mode == .demo {
                settingsStore.settings.mode = .playerVsAI
            }
            settingsStore.settings.passThrough = false
        } else {
            settingsStore.settings.passThrough = true
        }
    }

    func runtimeSnapshot() -> OverlayRuntimeSnapshot {
        let skView = overlayPanel.contentView as? SKView
        return OverlayRuntimeSnapshot(
            isVisible: isOverlayVisible && overlayPanel.isVisible,
            isBorderless: overlayPanel.styleMask == .borderless,
            isOpaque: overlayPanel.isOpaque,
            backgroundAlpha: overlayPanel.backgroundColor?.alphaComponent ?? 1,
            hasShadow: overlayPanel.hasShadow,
            isFloating: overlayPanel.level == .floating,
            joinsAllSpaces: overlayPanel.collectionBehavior.contains(.canJoinAllSpaces),
            supportsFullScreen: overlayPanel.collectionBehavior.contains(.fullScreenAuxiliary),
            ignoresWindowCycle: overlayPanel.collectionBehavior.contains(.ignoresCycle),
            ignoresMouseEvents: overlayPanel.ignoresMouseEvents,
            acceptsMouseMovedEvents: overlayPanel.acceptsMouseMovedEvents,
            acceptsGameInput: overlayPanel.acceptsGameInput,
            frameOrigin: overlayPanel.frame.origin,
            frameSize: overlayPanel.frame.size,
            hasSpriteView: skView != nil,
            spriteViewAllowsTransparency: skView?.allowsTransparency ?? false,
            inputMonitorCapturing: inputMonitor.isCapturingInput,
            keyboardEventTapActive: inputMonitor.keyboardEventTapActive,
            keyboardEventTapNeedsAccessibility: inputMonitor.keyboardEventTapNeedsAccessibility,
            registeredGameplayHotkeyCount: inputMonitor.registeredGameplayHotkeyCount,
            expectedGameplayHotkeyCount: inputMonitor.expectedGameplayHotkeyCount,
            gameplayHotkeyFailureCount: inputMonitor.gameplayHotkeyFailureCount
        )
    }

    func applyRuntimeTestSize(_ size: CGSize) {
        overlayPanel.setFrame(
            CGRect(origin: overlayPanel.frame.origin, size: size),
            display: true
        )
        scene.size = size
        scene.resetClock()
    }

    private func configure(panel: TransparentOverlayPanel, screen: NSScreen) {
        panel.setFrame(Self.overlayFrame(for: screen), display: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
    }

    @objc private func settingsDidChange() {
        applyPassThroughSetting()
    }

    private func applyPassThroughSetting() {
        let capturesInput = !settingsStore.settings.passThrough
        overlayPanel.acceptsGameInput = capturesInput
        overlayPanel.ignoresMouseEvents = true
        overlayPanel.acceptsMouseMovedEvents = false
        inputMonitor.isCapturingInput = capturesInput

        if capturesInput {
            NSApp.activate(ignoringOtherApps: true)
            overlayPanel.makeKeyAndOrderFront(nil)
        } else if isOverlayVisible {
            overlayPanel.orderFrontRegardless()
        }
    }

    @objc private func screenParametersDidChange() {
        resizeToMainScreen()
    }

    private func resizeToMainScreen() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            hideOverlay()
            return
        }
        let overlayFrame = Self.overlayFrame(for: screen)
        overlayPanel.setFrame(overlayFrame, display: true)
        scene.screenOriginY = overlayFrame.minY
        scene.size = overlayFrame.size
        scene.resetClock()
    }

    private static func overlayFrame(for screen: NSScreen) -> CGRect {
        let frame = screen.visibleFrame
        return frame.isEmpty ? screen.frame : frame
    }
}

struct OverlayRuntimeSnapshot: Codable {
    let isVisible: Bool
    let isBorderless: Bool
    let isOpaque: Bool
    let backgroundAlpha: CGFloat
    let hasShadow: Bool
    let isFloating: Bool
    let joinsAllSpaces: Bool
    let supportsFullScreen: Bool
    let ignoresWindowCycle: Bool
    let ignoresMouseEvents: Bool
    let acceptsMouseMovedEvents: Bool
    let acceptsGameInput: Bool
    let frameOrigin: CGPoint
    let frameSize: CGSize
    let hasSpriteView: Bool
    let spriteViewAllowsTransparency: Bool
    let inputMonitorCapturing: Bool
    let keyboardEventTapActive: Bool
    let keyboardEventTapNeedsAccessibility: Bool
    let registeredGameplayHotkeyCount: Int
    let expectedGameplayHotkeyCount: Int
    let gameplayHotkeyFailureCount: Int
}
