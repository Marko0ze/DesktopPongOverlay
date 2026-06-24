import AppKit
import Carbon

@MainActor
final class InputMonitor {
    private var localMonitor: Any?
    private var pressedKeyCodes = Set<UInt16>()
    private var gameplayKeyCodes = ControlBindings.default.gameplayKeyCodes
    private var gameplayHotkeyRefs = [UInt16: EventHotKeyRef]()
    private var gameplayHotkeyIDs = [UInt32: UInt16]()
    private var gameplayHotkeyHandlerRef: EventHandlerRef?
    private var gameplayHotkeyRegistrationFailures = [UInt16: OSStatus]()
    private(set) var mouseScreenY: CGFloat?
    var registeredGameplayHotkeyCount: Int {
        gameplayHotkeyRefs.count
    }

    var expectedGameplayHotkeyCount: Int {
        gameplayKeyCodes.count
    }

    var gameplayHotkeyFailureCount: Int {
        gameplayHotkeyRegistrationFailures.count
    }

    var isCapturingInput = false {
        didSet {
            guard oldValue != isCapturingInput else { return }
            if isCapturingInput {
                registerGameplayHotkeys()
            } else {
                unregisterGameplayHotkeys()
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
        unregisterGameplayHotkeys()
        removeGameplayHotkeyHandler()
        pressedKeyCodes.removeAll()
    }

    func updateControlBindings(_ bindings: ControlBindings) {
        let nextGameplayKeyCodes = bindings.gameplayKeyCodes
        guard nextGameplayKeyCodes != gameplayKeyCodes else { return }
        gameplayKeyCodes = nextGameplayKeyCodes
        guard isCapturingInput else { return }
        registerGameplayHotkeys()
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

    private func registerGameplayHotkeys() {
        unregisterGameplayHotkeys()
        installGameplayHotkeyHandlerIfNeeded()
        guard gameplayHotkeyHandlerRef != nil else { return }

        for (index, keyCode) in gameplayKeyCodes.sorted().enumerated() {
            let hotkeyID = EventHotKeyID(
                signature: Self.gameplayHotkeySignature,
                id: UInt32(index + 1)
            )
            var hotkeyRef: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(keyCode),
                0,
                hotkeyID,
                GetApplicationEventTarget(),
                0,
                &hotkeyRef
            )
            if status == noErr, let hotkeyRef {
                gameplayHotkeyRefs[keyCode] = hotkeyRef
                gameplayHotkeyIDs[hotkeyID.id] = keyCode
            } else {
                gameplayHotkeyRegistrationFailures[keyCode] = status
            }
        }
    }

    private func unregisterGameplayHotkeys() {
        for hotkeyRef in gameplayHotkeyRefs.values {
            UnregisterEventHotKey(hotkeyRef)
        }
        gameplayHotkeyRefs.removeAll()
        gameplayHotkeyIDs.removeAll()
        gameplayHotkeyRegistrationFailures.removeAll()
    }

    private func installGameplayHotkeyHandlerIfNeeded() {
        guard gameplayHotkeyHandlerRef == nil else { return }
        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            )
        ]
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = eventTypes.withUnsafeMutableBufferPointer { eventTypes in
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, userData in
                    guard let event, let userData else { return noErr }
                    var hotkeyID = EventHotKeyID()
                    let status = GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotkeyID
                    )
                    guard status == noErr else { return status }
                    guard hotkeyID.signature == InputMonitor.gameplayHotkeySignature else {
                        return noErr
                    }

                    let eventKind = GetEventKind(event)
                    let monitor = Unmanaged<InputMonitor>
                        .fromOpaque(userData)
                        .takeUnretainedValue()
                    Task { @MainActor in
                        monitor.handleGameplayHotkey(id: hotkeyID.id, eventKind: eventKind)
                    }
                    return noErr
                },
                eventTypes.count,
                eventTypes.baseAddress,
                userData,
                &gameplayHotkeyHandlerRef
            )
        }
        if status != noErr {
            gameplayHotkeyHandlerRef = nil
        }
    }

    private func removeGameplayHotkeyHandler() {
        if let gameplayHotkeyHandlerRef {
            RemoveEventHandler(gameplayHotkeyHandlerRef)
            self.gameplayHotkeyHandlerRef = nil
        }
    }

    private func handleGameplayHotkey(id: UInt32, eventKind: UInt32) {
        guard isCapturingInput, let keyCode = gameplayHotkeyIDs[id] else { return }
        switch eventKind {
        case UInt32(kEventHotKeyPressed):
            pressedKeyCodes.insert(keyCode)
        case UInt32(kEventHotKeyReleased):
            pressedKeyCodes.remove(keyCode)
        default:
            break
        }
    }

    private static let gameplayHotkeySignature = inputMonitorFourCharCode("DPGK")
}

private func inputMonitorFourCharCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
}
