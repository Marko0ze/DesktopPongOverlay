import AppKit
import Combine
import Foundation
import SwiftUI

enum GameMode: String, Codable, CaseIterable, Sendable {
    case demo
    case playerVsAI
    case twoPlayer

    var title: String {
        switch self {
        case .demo: "Demo"
        case .playerVsAI: "Player vs AI"
        case .twoPlayer: "Two Player"
        }
    }
}

enum PongMaterialStyle: String, Codable, CaseIterable, Sendable {
    case glass
    case clear
    case frosted

    var title: String { rawValue.capitalized }
}

enum ImpactPreset: String, Codable, CaseIterable, Sendable {
    case off
    case subtle
    case medium
    case juicy

    var title: String { rawValue.capitalized }

    var scale: CGFloat {
        switch self {
        case .off: 0
        case .subtle: 0.10
        case .medium: 0.18
        case .juicy: 0.25
        }
    }
}

struct RGBAColor: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let playerBlue = RGBAColor(red: 0.20, green: 0.56, blue: 1.00, alpha: 1)
    static let aiPurple = RGBAColor(red: 0.68, green: 0.38, blue: 1.00, alpha: 1)
    static let signalYellow = RGBAColor(red: 1.00, green: 0.72, blue: 0.12, alpha: 1)
    static let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)

    var nsColor: NSColor {
        NSColor(
            calibratedRed: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(nsColor: NSColor) {
        let color = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        red = Double(color.redComponent)
        green = Double(color.greenComponent)
        blue = Double(color.blueComponent)
        alpha = Double(color.alphaComponent)
    }
}

struct PongSettings: Codable, Equatable, Sendable {
    var mode: GameMode = .demo
    var materialStyle: PongMaterialStyle = .glass
    var impactPreset: ImpactPreset = .subtle
    var playerPaddleColor: RGBAColor = .playerBlue
    var aiPaddleColor: RGBAColor = .aiPurple
    var ballColor: RGBAColor = .signalYellow
    var scoreColor: RGBAColor = .white
    var objectOpacity = 0.90
    var glowStrength = 0.20
    var paddleRoundness = 0.85
    var paddleHeight = 130.0
    var paddleWidth = 16.0
    var ballSize = 14.0
    var ballSpeed = 0.50
    var aiSkill = 0.65
    var showScore = true
    var showCenterLine = true
    var passThrough = true
    var reducedMotion = false

    static let `default` = PongSettings()

    mutating func clamp() {
        objectOpacity = objectOpacity.clamped(to: 0.20 ... 1.0)
        glowStrength = glowStrength.clamped(to: 0 ... 1)
        paddleRoundness = paddleRoundness.clamped(to: 0 ... 1)
        paddleHeight = paddleHeight.clamped(to: 60 ... 240)
        paddleWidth = paddleWidth.clamped(to: 8 ... 36)
        ballSize = ballSize.clamped(to: 8 ... 36)
        ballSpeed = ballSpeed.clamped(to: 0 ... 1)
        aiSkill = aiSkill.clamped(to: 0 ... 1)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let didChangeNotification = Notification.Name("DesktopPongSettingsDidChange")

    @Published var settings: PongSettings {
        didSet {
            persist()
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        }
    }

    private let defaults: UserDefaults
    private let storageKey = "DesktopPongOverlay.settings.v2"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           var stored = try? JSONDecoder().decode(PongSettings.self, from: data) {
            stored.clamp()
            settings = stored
        } else {
            settings = .default
        }
    }

    func resetToDefaults() {
        settings = .default
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
