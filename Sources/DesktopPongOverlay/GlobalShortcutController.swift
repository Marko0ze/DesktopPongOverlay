import AppKit
import Carbon

@MainActor
final class GlobalShortcutController {
    static let shortcutDescription = "⌥⌘P"

    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: fourCharCode("DPOG"), id: 1)

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func register() {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var pressedHotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressedHotKeyID
                )
                guard status == noErr else { return status }

                let controller = Unmanaged<GlobalShortcutController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                guard pressedHotKeyID.signature == controller.hotKeyID.signature,
                      pressedHotKeyID.id == controller.hotKeyID.id else {
                    return noErr
                }

                Task { @MainActor in
                    controller.action()
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )

        RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            UInt32(cmdKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }
}

private func fourCharCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
}
