import AppKit

@MainActor
final class InputMonitor {
    private var localMonitor: Any?
    private var pressedKeyCodes = Set<UInt16>()
    private var gameplayKeyCodes = ControlBindings.default.gameplayKeyCodes
    private(set) var mouseScreenY: CGFloat?
    var isCapturingInput = false {
        didSet {
            if !isCapturingInput {
                pressedKeyCodes.removeAll()
                mouseScreenY = nil
            }
        }
    }

    func start() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .mouseMoved, .leftMouseDragged]
        ) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
        pressedKeyCodes.removeAll()
    }

    func updateControlBindings(_ bindings: ControlBindings) {
        gameplayKeyCodes = bindings.gameplayKeyCodes
    }

    func applyRuntimeTestInput(pressedKeyCodes: Set<UInt16>, mouseScreenY: CGFloat? = nil) {
        self.pressedKeyCodes = pressedKeyCodes
        self.mouseScreenY = mouseScreenY
    }

    @discardableResult
    func applyRuntimeTestKeyEvent(type: NSEvent.EventType, keyCode: UInt16) -> Bool {
        handleKeyEvent(type: type, keyCode: keyCode)
    }

    func snapshot(screenOriginY: CGFloat, settings: PongSettings) -> InputSnapshot {
        updateControlBindings(settings.controlBindings)
        let leftAxis = axis(
            negativeKey: settings.controlBindings.leftDown.keyCode,
            positiveKey: settings.controlBindings.leftUp.keyCode
        )
        let rightAxis = axis(
            negativeKey: settings.controlBindings.rightDown.keyCode,
            positiveKey: settings.controlBindings.rightUp.keyCode
        )
        let shouldSampleMouse = isCapturingInput
            && settings.mode == .playerVsAI
            && settings.playerControlMode != .keyboardOnly
        if shouldSampleMouse {
            mouseScreenY = NSEvent.mouseLocation.y
        }
        let localMouseY = shouldSampleMouse ? mouseScreenY.map { $0 - screenOriginY } : nil
        return InputSnapshot(
            leftAxis: leftAxis,
            rightAxis: rightAxis,
            mouseY: localMouseY
        )
    }

    private func axis(negativeKey: UInt16, positiveKey: UInt16) -> CGFloat {
        CGFloat((pressedKeyCodes.contains(positiveKey) ? 1 : 0) - (pressedKeyCodes.contains(negativeKey) ? 1 : 0))
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard isCapturingInput else { return event }
        switch event.type {
        case .keyDown:
            return handleKeyEvent(type: event.type, keyCode: event.keyCode) ? nil : event
        case .keyUp:
            return handleKeyEvent(type: event.type, keyCode: event.keyCode) ? nil : event
        case .mouseMoved, .leftMouseDragged:
            mouseScreenY = NSEvent.mouseLocation.y
        default:
            break
        }
        return event
    }

    private func isGameKey(_ keyCode: UInt16) -> Bool {
        gameplayKeyCodes.contains(keyCode)
    }

    private func handleKeyEvent(type: NSEvent.EventType, keyCode: UInt16) -> Bool {
        guard isCapturingInput, isGameKey(keyCode) else { return false }
        switch type {
        case .keyDown:
            pressedKeyCodes.insert(keyCode)
            return true
        case .keyUp:
            pressedKeyCodes.remove(keyCode)
            return true
        default:
            return false
        }
    }
}
