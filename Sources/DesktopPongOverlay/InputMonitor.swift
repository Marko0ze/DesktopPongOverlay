import AppKit
import ApplicationServices
import Carbon

@MainActor
final class InputMonitor {
    private var localMonitor: Any?
    private var pressedKeyCodes = Set<UInt16>()
    private var polledKeyCodes = Set<UInt16>()
    private var gameplayKeyCodes = ControlBindings.default.gameplayKeyCodes
    private var keyboardEventTap: CFMachPort?
    private var keyboardEventTapSource: CFRunLoopSource?
    private var accessibilityPromptShown = false
    private(set) var keyboardPollingActive = false
    private(set) var keyboardEventTapActive = false
    private(set) var keyboardEventTapNeedsAccessibility = false
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
                startKeyboardEventTap()
                registerGameplayHotkeys()
            } else {
                stopKeyboardEventTap()
                unregisterGameplayHotkeys()
                pressedKeyCodes.removeAll()
                polledKeyCodes.removeAll()
                keyboardPollingActive = false
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
        stopKeyboardEventTap()
        unregisterGameplayHotkeys()
        removeGameplayHotkeyHandler()
        pressedKeyCodes.removeAll()
        polledKeyCodes.removeAll()
        keyboardPollingActive = false
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
        polledKeyCodes.removeAll()
        self.mouseScreenY = mouseScreenY
    }

    @discardableResult
    func applyRuntimeTestKeyEvent(type: NSEvent.EventType, keyCode: UInt16) -> Bool {
        handleKeyEvent(type: type, keyCode: keyCode)
    }

    func snapshot(screenOriginY: CGFloat, settings: PongSettings) -> InputSnapshot {
        updateControlBindings(settings.controlBindings)
        pollGameplayKeyStates()
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

    func captureStatusDescription(bindings: ControlBindings) -> String {
        guard isCapturingInput else { return "Capture OFF" }
        let activeKeyCodes = pressedKeyCodes.union(polledKeyCodes)
        let pressedLabels = [
            (bindings.leftUp.keyCode, bindings.leftUp.label),
            (bindings.leftDown.keyCode, bindings.leftDown.label),
            (bindings.rightUp.keyCode, bindings.rightUp.label),
            (bindings.rightDown.keyCode, bindings.rightDown.label)
        ]
        .filter { activeKeyCodes.contains($0.0) }
        .map(\.1)
        let keyText = pressedLabels.isEmpty ? "no key" : pressedLabels.joined(separator: "+")

        if keyboardEventTapActive {
            return "Capture ON · keyboard active · \(keyText)"
        }
        if keyboardPollingActive {
            return "Capture ON · keyboard polling fallback · \(keyText)"
        }
        if keyboardEventTapNeedsAccessibility {
            return "Capture ON · allow Accessibility for keyboard · \(keyText)"
        }
        if registeredGameplayHotkeyCount > 0 {
            return "Capture ON · hotkey fallback · \(keyText)"
        }
        return "Capture ON · keyboard unavailable"
    }

    private func axis(negativeKey: UInt16, positiveKey: UInt16) -> CGFloat {
        let activeKeyCodes = pressedKeyCodes.union(polledKeyCodes)
        return CGFloat((activeKeyCodes.contains(positiveKey) ? 1 : 0) - (activeKeyCodes.contains(negativeKey) ? 1 : 0))
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

    private func pollGameplayKeyStates() {
        guard isCapturingInput else {
            polledKeyCodes.removeAll()
            keyboardPollingActive = false
            return
        }
        keyboardPollingActive = true
        polledKeyCodes = Set(gameplayKeyCodes.filter { keyCode in
            let cgKeyCode = CGKeyCode(keyCode)
            return CGEventSource.keyState(.combinedSessionState, key: cgKeyCode)
                || CGEventSource.keyState(.hidSystemState, key: cgKeyCode)
        })
    }

    private func startKeyboardEventTap() {
        stopKeyboardEventTap()

        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
        let userData = Unmanaged.passUnretained(self).toOpaque()
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: keyboardEventTapCallback,
            userInfo: userData
        ) else {
            keyboardEventTapActive = false
            keyboardEventTapNeedsAccessibility = !AXIsProcessTrusted()
            requestAccessibilityPermissionIfNeeded()
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            keyboardEventTapActive = false
            keyboardEventTapNeedsAccessibility = false
            return
        }

        keyboardEventTap = eventTap
        keyboardEventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        keyboardEventTapActive = true
        keyboardEventTapNeedsAccessibility = false
    }

    private func stopKeyboardEventTap() {
        keyboardEventTapActive = false
        keyboardEventTapNeedsAccessibility = false
        if let keyboardEventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), keyboardEventTapSource, .commonModes)
            self.keyboardEventTapSource = nil
        }
        if let keyboardEventTap {
            CFMachPortInvalidate(keyboardEventTap)
            self.keyboardEventTap = nil
        }
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !accessibilityPromptShown,
              ProcessInfo.processInfo.environment["DESKTOP_PONG_SUPPRESS_ACCESSIBILITY_PROMPT"] != "1",
              !AXIsProcessTrusted() else { return }
        accessibilityPromptShown = true
        let promptKey = "AXTrustedCheckOptionPrompt"
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    fileprivate func handleKeyboardEventTap(type: CGEventType, keyCode: UInt16) {
        guard isCapturingInput, isGameKey(keyCode) else { return }
        switch type {
        case .keyDown:
            pressedKeyCodes.insert(keyCode)
        case .keyUp:
            pressedKeyCodes.remove(keyCode)
        default:
            break
        }
    }

    fileprivate func reenableKeyboardEventTap() {
        guard isCapturingInput, let keyboardEventTap else { return }
        CGEvent.tapEnable(tap: keyboardEventTap, enable: true)
        keyboardEventTapActive = true
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

private let keyboardEventTapCallback: CGEventTapCallBack = { _, type, event, userData in
    guard let userData else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<InputMonitor>.fromOpaque(userData).takeUnretainedValue()
    switch type {
    case .keyDown, .keyUp:
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        Task { @MainActor in
            monitor.handleKeyboardEventTap(type: type, keyCode: keyCode)
        }
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        Task { @MainActor in
            monitor.reenableKeyboardEventTap()
        }
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}
