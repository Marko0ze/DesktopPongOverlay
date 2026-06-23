import AppKit

@MainActor
final class HapticFeedbackController {
    private var lastImpactTime = Date.distantPast

    func impact() {
        guard Date().timeIntervalSince(lastImpactTime) > 0.08 else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        lastImpactTime = Date()
    }

    func click() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}
