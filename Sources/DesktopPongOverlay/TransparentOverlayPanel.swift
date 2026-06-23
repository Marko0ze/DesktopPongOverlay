import AppKit

final class TransparentOverlayPanel: NSPanel {
    var acceptsGameInput = false

    override var canBecomeKey: Bool { acceptsGameInput }
    override var canBecomeMain: Bool { false }
}
