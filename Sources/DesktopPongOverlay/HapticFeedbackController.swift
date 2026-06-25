import AppKit

@MainActor
final class HapticFeedbackController {
    private var lastImpactTime = Date.distantPast
    var isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func impact() {
        guard isEnabled else { return }
        guard Date().timeIntervalSince(lastImpactTime) > 0.08 else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        lastImpactTime = Date()
    }

    func click() {
        guard isEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}
