import AppKit

@MainActor
final class InputMonitor {
    private var localMonitor: Any?
    private var pressedKeyCodes = Set<UInt16>()
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

    func snapshot(screenOriginY: CGFloat) -> InputSnapshot {
        let leftAxis = axis(negativeKey: 1, positiveKey: 13) // S / W
        let rightAxis = axis(negativeKey: 125, positiveKey: 126) // Down / Up
        let localMouseY = mouseScreenY.map { $0 - screenOriginY }
        return InputSnapshot(
            leftAxis: leftAxis,
            rightAxis: rightAxis,
            mouseY: isCapturingInput ? localMouseY : nil
        )
    }

    private func axis(negativeKey: UInt16, positiveKey: UInt16) -> CGFloat {
        CGFloat((pressedKeyCodes.contains(positiveKey) ? 1 : 0) - (pressedKeyCodes.contains(negativeKey) ? 1 : 0))
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard isCapturingInput else { return event }
        switch event.type {
        case .keyDown:
            if isGameKey(event.keyCode) {
                pressedKeyCodes.insert(event.keyCode)
                return nil
            }
        case .keyUp:
            if isGameKey(event.keyCode) {
                pressedKeyCodes.remove(event.keyCode)
                return nil
            }
        case .mouseMoved, .leftMouseDragged:
            mouseScreenY = NSEvent.mouseLocation.y
        default:
            break
        }
        return event
    }

    private func isGameKey(_ keyCode: UInt16) -> Bool {
        [1, 13, 125, 126].contains(keyCode)
    }
}
