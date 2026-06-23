import AppKit
import SpriteKit

@MainActor
final class MenuBarGameController: NSObject, NSPopoverDelegate {
    private let settingsStore: SettingsStore
    private let haptics: HapticFeedbackController
    private let inputMonitor = InputMonitor()
    private let popover = NSPopover()
    private var scene: PongScene!

    var isShown: Bool { popover.isShown }

    init(settingsStore: SettingsStore, haptics: HapticFeedbackController) {
        self.settingsStore = settingsStore
        self.haptics = haptics
        super.init()
        configurePopover()
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        isShown ? close() : show(relativeTo: button)
    }

    func show(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            scene.setPaused(false)
            return
        }
        inputMonitor.start()
        inputMonitor.isCapturingInput = true
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        scene.setPaused(false)
        updateSceneWindowOrigin()
        haptics.click()
    }

    func close() {
        scene.setPaused(true)
        inputMonitor.isCapturingInput = false
        popover.close()
        popover.contentViewController?.view.window?.close()
    }

    func togglePause() {
        scene.togglePause()
        haptics.click()
    }

    func resetGame() {
        scene.resetGame()
    }

    func runtimeSnapshot() -> MenuBarGameRuntimeSnapshot {
        MenuBarGameRuntimeSnapshot(
            isShown: popover.isShown,
            inputCapturing: inputMonitor.isCapturingInput,
            scenePaused: scene.isGamePaused,
            sceneSize: scene.size
        )
    }

    func popoverDidClose(_ notification: Notification) {
        scene.setPaused(true)
        inputMonitor.isCapturingInput = false
    }

    private func configurePopover() {
        let contentSize = CGSize(width: 440, height: 320)
        let viewController = NSViewController()
        viewController.view = MiniGameContentView(frame: CGRect(origin: .zero, size: contentSize))
        viewController.preferredContentSize = contentSize

        let skView = SKView(frame: viewController.view.bounds.insetBy(dx: 14, dy: 14))
        skView.autoresizingMask = [.width, .height]
        skView.allowsTransparency = true
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        skView.wantsLayer = true
        skView.layer?.backgroundColor = NSColor.clear.cgColor
        viewController.view.addSubview(skView)

        let scene = PongScene(size: skView.bounds.size, settingsStore: settingsStore, inputMonitor: inputMonitor)
        scene.onImpact = { [weak self] in self?.haptics.impact() }
        skView.presentScene(scene)
        self.scene = scene

        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(contentClicked))
        viewController.view.addGestureRecognizer(clickRecognizer)

        popover.contentViewController = viewController
        popover.behavior = .semitransient
        popover.animates = true
        popover.delegate = self
    }

    private func updateSceneWindowOrigin() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let window = self.popover.contentViewController?.view.window else { return }
            self.scene.screenOriginY = window.frame.minY
            self.scene.size = self.popover.contentSize
            self.scene.resetClock()
        }
    }

    @objc private func contentClicked() {
        togglePause()
    }
}

final class MiniGameContentView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct MenuBarGameRuntimeSnapshot: Codable {
    let isShown: Bool
    let inputCapturing: Bool
    let scenePaused: Bool
    let sceneSize: CGSize
}
