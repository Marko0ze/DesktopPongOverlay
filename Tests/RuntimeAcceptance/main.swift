import AppKit
import Foundation

private struct RuntimeCheck: Codable {
    let name: String
    let passed: Bool
    let detail: String
}

private struct RuntimeReport: Codable {
    let passed: Bool
    let checks: [RuntimeCheck]
    let systemVersion: String
}

@main
@MainActor
enum DesktopPongRuntimeAcceptance {
    static func main() {
        let application = NSApplication.shared
        let delegate = RuntimeAcceptanceDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
private final class RuntimeAcceptanceDelegate: NSObject, NSApplicationDelegate {
    private var checks: [RuntimeCheck] = []
    private var settingsStore: SettingsStore!
    private var inputMonitor: InputMonitor!
    private var haptics: HapticFeedbackController!
    private var overlayController: OverlayWindowController!
    private var menuBarGameController: MenuBarGameController!
    private var preferencesController: PreferencesWindowController!
    private var aboutController: AboutWindowController!
    private var statusMenuController: StatusMenuController!
    private var passThroughProbeController: PassThroughProbeWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        let suiteName = "DesktopPongRuntimeAcceptance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        settingsStore = SettingsStore(defaults: defaults)
        haptics = HapticFeedbackController()
        if ProcessInfo.processInfo.environment["DESKTOP_PONG_SETTINGS_ONLY"] == "1" {
            preferencesController = PreferencesWindowController(settingsStore: settingsStore, resetGame: {})
            preferencesController.present()
            if let renderPath = ProcessInfo.processInfo.environment["DESKTOP_PONG_SETTINGS_RENDER_PATH"] {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
                    self?.captureSettingsWindow(to: renderPath)
                }
            }
            return
        }

        if ProcessInfo.processInfo.environment["DESKTOP_PONG_PASS_THROUGH_PROBE"] == "1" {
            let reportPath = ProcessInfo.processInfo.environment["DESKTOP_PONG_PROBE_REPORT"]
                ?? "/tmp/desktop-pong-pass-through-probe.txt"
            passThroughProbeController = PassThroughProbeWindowController(reportPath: reportPath)
            passThroughProbeController.present()
            inputMonitor = InputMonitor()
            overlayController = OverlayWindowController(
                settingsStore: settingsStore,
                inputMonitor: inputMonitor,
                haptics: haptics
            )
            overlayController.showOverlay()
            return
        }

        inputMonitor = InputMonitor()
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
        overlayController.showOverlay()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.runWindowAndMenuChecks()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func runWindowAndMenuChecks() {
        let overlay = overlayController.runtimeSnapshot()
        record("overlay visible", overlay.isVisible, "visible=\(overlay.isVisible)")
        record("borderless panel", overlay.isBorderless, "borderless=\(overlay.isBorderless)")
        record("transparent panel", !overlay.isOpaque && overlay.backgroundAlpha == 0, "opaque=\(overlay.isOpaque), alpha=\(overlay.backgroundAlpha)")
        record("shadowless panel", !overlay.hasShadow, "hasShadow=\(overlay.hasShadow)")
        record("floating level", overlay.isFloating, "floating=\(overlay.isFloating)")
        record("Space behavior", overlay.joinsAllSpaces && overlay.supportsFullScreen && overlay.ignoresWindowCycle, "allSpaces=\(overlay.joinsAllSpaces), fullScreen=\(overlay.supportsFullScreen)")
        record("pass-through default", overlay.ignoresMouseEvents && !overlay.acceptsGameInput && !overlay.inputMonitorCapturing, "ignoresMouse=\(overlay.ignoresMouseEvents)")
        record("transparent SpriteKit view", overlay.hasSpriteView && overlay.spriteViewAllowsTransparency, "hasSKView=\(overlay.hasSpriteView), transparent=\(overlay.spriteViewAllowsTransparency)")
        let visibleFrame = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        record(
            "overlay leaves menu bar accessible",
            overlay.frameOrigin == visibleFrame.origin && overlay.frameSize == visibleFrame.size,
            "origin=\(overlay.frameOrigin), size=\(overlay.frameSize), visible=\(visibleFrame)"
        )

        let scene = overlayController.scene.runtimeSnapshot()
        record("transparent scene", scene.backgroundAlpha == 0, "alpha=\(scene.backgroundAlpha)")
        record("Pong objects visible", scene.ballVisible && scene.paddlesVisible && scene.centerLineVisible && scene.scoreVisible, "ball=\(scene.ballVisible), paddles=\(scene.paddlesVisible), line=\(scene.centerLineVisible), score=\(scene.scoreVisible)")
        let firstBallPosition = scene.ballPosition

        let menuTitles = Set(statusMenuController.runtimeMenuTitles())
        let requiredMenuTitles: Set<String> = [
            "Hide Overlay", "Pause", "Reset Score", "Mode", "Demo", "Player vs AI",
            "Two Player", "AI Difficulty", "Easy", "Normal", "Hard", "Original-ish",
            "Capture Input", "Settings…", "About Desktop Pong Overlay", "Quit Desktop Pong Overlay"
        ]
        let missingMenuTitles = requiredMenuTitles.subtracting(menuTitles)
        record("status menu inventory", missingMenuTitles.isEmpty, "missing=\(missingMenuTitles.sorted())")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
            self?.runInteractionChecks(firstBallPosition: firstBallPosition)
        }
    }

    private func runInteractionChecks(firstBallPosition: CGPoint) {
        let movingPosition = overlayController.scene.runtimeSnapshot().ballPosition
        record("ball advances", movingPosition != firstBallPosition, "from=\(firstBallPosition), to=\(movingPosition)")

        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        let wakeSnapshot = overlayController.scene.runtimeSnapshot()
        record("wake resets update clock", !wakeSnapshot.updateClockIsPrimed, "clockPrimed=\(wakeSnapshot.updateClockIsPrimed)")

        let pauseActionSent = statusMenuController.performRuntimeMenuAction(titled: "Pause")
        record("status menu pause action", pauseActionSent, "sent=\(pauseActionSent)")
        let pausedPosition = overlayController.scene.runtimeSnapshot().ballPosition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            self?.finishInteractionChecks(pausedPosition: pausedPosition)
        }
    }

    private func finishInteractionChecks(pausedPosition: CGPoint) {
        let pausedScene = overlayController.scene.runtimeSnapshot()
        record("pause freezes game", pausedScene.isPaused && pausedScene.ballPosition == pausedPosition, "paused=\(pausedScene.isPaused)")
        let resumeActionSent = statusMenuController.performRuntimeMenuAction(titled: "Resume")
        record("resume clears pause", !overlayController.scene.isGamePaused, "paused=\(overlayController.scene.isGamePaused)")
        record("status menu resume action", resumeActionSent, "sent=\(resumeActionSent)")

        let hideActionSent = statusMenuController.performRuntimeMenuAction(titled: "Hide Overlay")
        record("hide overlay", !overlayController.runtimeSnapshot().isVisible, "visible=\(overlayController.runtimeSnapshot().isVisible)")
        record("status menu hide action", hideActionSent, "sent=\(hideActionSent)")
        let showActionSent = statusMenuController.performRuntimeMenuAction(titled: "Show Overlay")
        record("show overlay", overlayController.runtimeSnapshot().isVisible, "visible=\(overlayController.runtimeSnapshot().isVisible)")
        record("status menu show action", showActionSent, "sent=\(showActionSent)")

        settingsStore.settings.mode = .demo
        let captureActionSent = statusMenuController.performRuntimeMenuAction(titled: "Capture Input")
        let captured = overlayController.runtimeSnapshot()
        record(
            "capture input",
            captured.ignoresMouseEvents && !captured.acceptsMouseMovedEvents && captured.acceptsGameInput && captured.inputMonitorCapturing,
            "ignoresMouse=\(captured.ignoresMouseEvents), capture=\(captured.inputMonitorCapturing)"
        )
        record("capture keeps desktop clickable", captured.ignoresMouseEvents, "ignoresMouse=\(captured.ignoresMouseEvents)")
        record("capture enables playable controls", settingsStore.settings.mode == .playerVsAI, "mode=\(settingsStore.settings.mode.rawValue)")
        record("status menu capture action", captureActionSent, "sent=\(captureActionSent)")
        let passThroughActionSent = statusMenuController.performRuntimeMenuAction(titled: "Capture Input")
        record("restore pass-through", overlayController.runtimeSnapshot().ignoresMouseEvents, "ignoresMouse=\(overlayController.runtimeSnapshot().ignoresMouseEvents)")
        record("status menu pass-through action", passThroughActionSent, "sent=\(passThroughActionSent)")

        let playerModeActionSent = statusMenuController.performRuntimeMenuAction(titled: "Player vs AI")
        record("player vs AI mode", settingsStore.settings.mode == .playerVsAI, "mode=\(settingsStore.settings.mode.rawValue)")
        record("status menu player mode action", playerModeActionSent, "sent=\(playerModeActionSent)")
        let twoPlayerActionSent = statusMenuController.performRuntimeMenuAction(titled: "Two Player")
        record("two-player mode", settingsStore.settings.mode == .twoPlayer, "mode=\(settingsStore.settings.mode.rawValue)")
        record("status menu two-player action", twoPlayerActionSent, "sent=\(twoPlayerActionSent)")
        let difficultyActionSent = statusMenuController.performRuntimeMenuAction(titled: "Original-ish")
        record("difficulty update", settingsStore.settings.aiSkill == 0.95, "skill=\(settingsStore.settings.aiSkill)")
        record("status menu difficulty action", difficultyActionSent, "sent=\(difficultyActionSent)")

        runRemappedControlAndGlassChecks()

        let miniGameActionSent = statusMenuController.performRuntimeMenuAction(titled: "Open Menu Bar Game")
        let miniGame = menuBarGameController.runtimeSnapshot()
        record(
            "menu bar game opens",
            miniGameActionSent && miniGame.isShown && miniGame.inputCapturing && !miniGame.scenePaused,
            "sent=\(miniGameActionSent), shown=\(miniGame.isShown), input=\(miniGame.inputCapturing), paused=\(miniGame.scenePaused)"
        )
        let desktopPresentationSent = statusMenuController.performRuntimeMenuAction(titled: "Desktop Overlay")
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        record(
            "desktop overlay presentation restores",
            desktopPresentationSent && overlayController.runtimeSnapshot().isVisible && !menuBarGameController.isShown,
            "sent=\(desktopPresentationSent), overlay=\(overlayController.runtimeSnapshot().isVisible), mini=\(menuBarGameController.isShown)"
        )

        overlayController.applyRuntimeTestSize(CGSize(width: 840, height: 560))
        let resized = overlayController.scene.runtimeSnapshot()
        let objectsInsideBounds = (0 ... resized.size.width).contains(resized.ballPosition.x)
            && (0 ... resized.size.height).contains(resized.ballPosition.y)
            && (0 ... resized.size.height).contains(resized.leftPaddleY)
            && (0 ... resized.size.height).contains(resized.rightPaddleY)
        record("display resize recovery", resized.size == CGSize(width: 840, height: 560) && objectsInsideBounds, "size=\(resized.size), ball=\(resized.ballPosition)")

        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let displayNotificationSize = overlayController.scene.runtimeSnapshot().size
        let expectedDisplaySize = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame.size
        record("display-change notification recovery", displayNotificationSize == expectedDisplaySize, "size=\(displayNotificationSize), expected=\(expectedDisplaySize)")

        runAuxiliaryWindowCycles()
        finishReport()
    }

    private func runRemappedControlAndGlassChecks() {
        settingsStore.settings.mode = .twoPlayer
        settingsStore.settings.materialStyle = .glass
        settingsStore.settings.glassQuality = .rich
        settingsStore.settings.paddleGlassFill = .transparent
        settingsStore.settings.controlBindings.leftUp = KeyBinding(keyCode: 0, label: "A")
        settingsStore.settings.controlBindings.leftDown = KeyBinding(keyCode: 2, label: "D")
        settingsStore.settings.controlBindings.rightUp = KeyBinding(keyCode: 14, label: "E")
        settingsStore.settings.controlBindings.rightDown = KeyBinding(keyCode: 15, label: "R")

        let before = overlayController.scene.runtimeSnapshot()
        inputMonitor.isCapturingInput = true
        inputMonitor.updateControlBindings(settingsStore.settings.controlBindings)
        let leftKeyHandled = inputMonitor.applyRuntimeTestKeyEvent(type: .keyDown, keyCode: 0)
        let rightKeyHandled = inputMonitor.applyRuntimeTestKeyEvent(type: .keyDown, keyCode: 15)
        overlayController.scene.update(ProcessInfo.processInfo.systemUptime + 1.0)
        overlayController.scene.update(ProcessInfo.processInfo.systemUptime + 1.05)
        let leftKeyReleased = inputMonitor.applyRuntimeTestKeyEvent(type: .keyUp, keyCode: 0)
        let rightKeyReleased = inputMonitor.applyRuntimeTestKeyEvent(type: .keyUp, keyCode: 15)
        let after = overlayController.scene.runtimeSnapshot()

        record(
            "remapped key events accepted",
            leftKeyHandled && rightKeyHandled && leftKeyReleased && rightKeyReleased,
            "leftDown=\(leftKeyHandled), rightDown=\(rightKeyHandled), leftUp=\(leftKeyReleased), rightUp=\(rightKeyReleased)"
        )

        record(
            "remapped controls move paddles",
            after.leftPaddleY > before.leftPaddleY && after.rightPaddleY < before.rightPaddleY,
            "leftBefore=\(before.leftPaddleY), leftAfter=\(after.leftPaddleY), rightBefore=\(before.rightPaddleY), rightAfter=\(after.rightPaddleY)"
        )
        record(
            "rich liquid glass layers visible",
            after.liquidGlassRimVisible && after.liquidGlassSpecularVisible,
            "rim=\(after.liquidGlassRimVisible), specular=\(after.liquidGlassSpecularVisible)"
        )
        record(
            "transparent paddle glass fill",
            after.leftPaddleFillAlpha == 0 && after.rightPaddleFillAlpha == 0,
            "leftAlpha=\(after.leftPaddleFillAlpha), rightAlpha=\(after.rightPaddleFillAlpha)"
        )
    }

    private func runAuxiliaryWindowCycles() {
        var settingsCyclesPassed = true
        var aboutCyclesPassed = true
        var settingsReleasedCapture = false
        for cycle in 0 ..< 3 {
            if cycle == 0 {
                settingsCyclesPassed = statusMenuController.performRuntimeMenuAction(titled: "Settings…")
                let overlay = overlayController.runtimeSnapshot()
                settingsReleasedCapture = overlay.ignoresMouseEvents && !overlay.inputMonitorCapturing
            } else {
                preferencesController.present()
            }
            settingsCyclesPassed = settingsCyclesPassed && (preferencesController.window?.isVisible == true)
            preferencesController.close()
            settingsCyclesPassed = settingsCyclesPassed && (preferencesController.window?.isVisible == false)

            if cycle == 0 {
                aboutCyclesPassed = statusMenuController.performRuntimeMenuAction(titled: "About Desktop Pong Overlay")
            } else {
                aboutController.present()
            }
            aboutCyclesPassed = aboutCyclesPassed && (aboutController.window?.isVisible == true)
            aboutController.close()
            aboutCyclesPassed = aboutCyclesPassed && (aboutController.window?.isVisible == false)
        }
        record("Settings open-close cycles", settingsCyclesPassed, "three cycles")
        record("Settings releases overlay capture", settingsReleasedCapture, "released=\(settingsReleasedCapture)")
        record("About open-close cycles", aboutCyclesPassed, "three cycles")
        record("overlay survives auxiliary windows", overlayController.scene.view != nil && !overlayController.scene.isGamePaused, "scene attached and running")
    }

    private func finishReport() {
        overlayController.hideOverlay()
        preferencesController.present()

        let report = RuntimeReport(
            passed: checks.allSatisfy(\.passed),
            checks: checks,
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString
        )
        let path = ProcessInfo.processInfo.environment["DESKTOP_PONG_RUNTIME_REPORT"]
            ?? "/tmp/desktop-pong-runtime-report.json"
        do {
            let data = try JSONEncoder.pretty.encode(report)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
            fputs("Unable to write runtime report: \(error)\n", stderr)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            NSApp.terminate(nil)
        }
    }

    private func record(_ name: String, _ passed: Bool, _ detail: String) {
        checks.append(RuntimeCheck(name: name, passed: passed, detail: detail))
    }

    private func captureSettingsWindow(to path: String) {
        guard let view = preferencesController.window?.contentView else { return }
        preferencesController.window?.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}

@MainActor
private final class PassThroughProbeWindowController: NSWindowController {
    private let reportPath: String
    private let statusLabel: NSTextField
    private var probeButton: NSButton!
    private var clickCount = 0

    init(reportPath: String) {
        self.reportPath = reportPath
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 240))

        let title = NSTextField(labelWithString: "Pass-through probe")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.alignment = .center
        title.frame = NSRect(x: 40, y: 165, width: 380, height: 34)
        content.addSubview(title)

        statusLabel = NSTextField(labelWithString: "Waiting for a click")
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 40, y: 125, width: 380, height: 24)
        statusLabel.setAccessibilityIdentifier("probe-status")
        content.addSubview(statusLabel)

        let window = NSWindow(
            contentRect: content.bounds,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Desktop Pong Pass-through Probe"
        window.contentView = content
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        let button = NSButton(title: "Click Through Probe", target: self, action: #selector(recordClick))
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 130, y: 62, width: 200, height: 42)
        button.setAccessibilityIdentifier("probe-button")
        content.addSubview(button)
        probeButton = button
        writeCount()
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

    @objc private func recordClick() {
        clickCount += 1
        statusLabel.stringValue = "Received \(clickCount) click\(clickCount == 1 ? "" : "s")"
        writeCount()
    }

    private func writeCount() {
        try? String(clickCount).write(toFile: reportPath, atomically: true, encoding: .utf8)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
