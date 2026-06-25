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
    case fullGlass
    case clear
    case frosted

    var title: String {
        switch self {
        case .glass: "Liquid Glass"
        case .fullGlass: "Full Liquid Glass"
        case .clear: "Clear"
        case .frosted: "Frosted"
        }
    }

    var isLiquidGlass: Bool {
        switch self {
        case .glass, .fullGlass: true
        case .clear, .frosted: false
        }
    }
}

enum GlassQuality: String, Codable, CaseIterable, Sendable {
    case performance
    case balanced
    case rich

    var title: String {
        switch self {
        case .performance: "Performance"
        case .balanced: "Balanced"
        case .rich: "Rich"
        }
    }
}

enum PaddleGlassFill: String, Codable, CaseIterable, Sendable {
    case tinted
    case transparent

    var title: String {
        switch self {
        case .tinted: "Tinted"
        case .transparent: "Transparent"
        }
    }

    var fillAlphaScale: Double {
        switch self {
        case .tinted: 1
        case .transparent: 0
        }
    }
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

enum PlayerControlMode: String, Codable, CaseIterable, Sendable {
    case keyboardAndMouse
    case keyboardOnly
    case mouseOnly

    var title: String {
        switch self {
        case .keyboardAndMouse: "Keyboard + Mouse"
        case .keyboardOnly: "Keyboard Only"
        case .mouseOnly: "Mouse Only"
        }
    }
}

enum PresentationMode: String, Codable, CaseIterable, Sendable {
    case desktopOverlay
    case menuBarGame

    var title: String {
        switch self {
        case .desktopOverlay: "Desktop Overlay"
        case .menuBarGame: "Menu Bar Game"
        }
    }
}

struct KeyBinding: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var label: String

    static let w = KeyBinding(keyCode: 13, label: "W")
    static let s = KeyBinding(keyCode: 1, label: "S")
    static let upArrow = KeyBinding(keyCode: 126, label: "↑")
    static let downArrow = KeyBinding(keyCode: 125, label: "↓")
    static let p = KeyBinding(keyCode: 35, label: "P")

    init(keyCode: UInt16, label: String) {
        self.keyCode = keyCode
        self.label = label
    }

    init(event: NSEvent) {
        keyCode = event.keyCode
        label = Self.displayLabel(for: event)
    }

    static func displayLabel(for event: NSEvent) -> String {
        switch event.keyCode {
        case 123: "←"
        case 124: "→"
        case 125: "↓"
        case 126: "↑"
        case 36: "Return"
        case 49: "Space"
        case 51: "Delete"
        case 53: "Esc"
        default:
            if let characters = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines),
               !characters.isEmpty {
                characters.uppercased()
            } else {
                "Key \(event.keyCode)"
            }
        }
    }
}

struct ControlBindings: Codable, Equatable, Sendable {
    var leftUp: KeyBinding = .upArrow
    var leftDown: KeyBinding = .downArrow
    var rightUp: KeyBinding = .w
    var rightDown: KeyBinding = .s
    var globalToggle: KeyBinding = .p

    static let `default` = ControlBindings()
    static let legacyDefault = ControlBindings(
        leftUp: .w,
        leftDown: .s,
        rightUp: .upArrow,
        rightDown: .downArrow,
        globalToggle: .p
    )

    var gameplayKeyCodes: Set<UInt16> {
        Set([leftUp.keyCode, leftDown.keyCode, rightUp.keyCode, rightDown.keyCode])
    }

    var hasDuplicateGameplayKeys: Bool {
        gameplayKeyCodes.count < 4
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
    var mode: GameMode = .playerVsAI
    var presentationMode: PresentationMode = .desktopOverlay
    var materialStyle: PongMaterialStyle = .glass
    var glassQuality: GlassQuality = .rich
    var paddleGlassFill: PaddleGlassFill = .tinted
    var impactPreset: ImpactPreset = .subtle
    var playerControlMode: PlayerControlMode = .keyboardAndMouse
    var controlBindings: ControlBindings = .default
    var playerPaddleColor: RGBAColor = .playerBlue
    var aiPaddleColor: RGBAColor = .aiPurple
    var ballColor: RGBAColor = .signalYellow
    var scoreColor: RGBAColor = .white
    var objectOpacity = 0.90
    var glowStrength = 0.20
    var glassEdgeIntensity = 0.64
    var glassRimIntensity = 0.88
    var glassBaseIntensity = 0.66
    var glassSpecularIntensity = 0.72
    var glassDepth = 0.62
    var glassEdgeDistance = 0.38
    var glassRimDistance = 0.62
    var glassBaseDistance = 0.52
    var glassCornerBoost = 0.18
    var glassRippleEffect = 0.42
    var glassBlurRadius = 4.0
    var glassTintOpacity = 0.24
    var glassCenterWarpEnabled = true
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
    var hapticFeedbackEnabled = true

    static let `default` = PongSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PongSettings()

        mode = try container.decodeIfPresent(GameMode.self, forKey: .mode) ?? defaults.mode
        presentationMode = try container.decodeIfPresent(PresentationMode.self, forKey: .presentationMode) ?? defaults.presentationMode
        materialStyle = try container.decodeIfPresent(PongMaterialStyle.self, forKey: .materialStyle) ?? defaults.materialStyle
        glassQuality = try container.decodeIfPresent(GlassQuality.self, forKey: .glassQuality) ?? defaults.glassQuality
        paddleGlassFill = try container.decodeIfPresent(PaddleGlassFill.self, forKey: .paddleGlassFill) ?? defaults.paddleGlassFill
        impactPreset = try container.decodeIfPresent(ImpactPreset.self, forKey: .impactPreset) ?? defaults.impactPreset
        playerControlMode = try container.decodeIfPresent(PlayerControlMode.self, forKey: .playerControlMode) ?? defaults.playerControlMode
        controlBindings = try container.decodeIfPresent(ControlBindings.self, forKey: .controlBindings) ?? defaults.controlBindings
        playerPaddleColor = try container.decodeIfPresent(RGBAColor.self, forKey: .playerPaddleColor) ?? defaults.playerPaddleColor
        aiPaddleColor = try container.decodeIfPresent(RGBAColor.self, forKey: .aiPaddleColor) ?? defaults.aiPaddleColor
        ballColor = try container.decodeIfPresent(RGBAColor.self, forKey: .ballColor) ?? defaults.ballColor
        scoreColor = try container.decodeIfPresent(RGBAColor.self, forKey: .scoreColor) ?? defaults.scoreColor
        objectOpacity = try container.decodeIfPresent(Double.self, forKey: .objectOpacity) ?? defaults.objectOpacity
        glowStrength = try container.decodeIfPresent(Double.self, forKey: .glowStrength) ?? defaults.glowStrength
        glassEdgeIntensity = try container.decodeIfPresent(Double.self, forKey: .glassEdgeIntensity) ?? defaults.glassEdgeIntensity
        glassRimIntensity = try container.decodeIfPresent(Double.self, forKey: .glassRimIntensity) ?? defaults.glassRimIntensity
        glassBaseIntensity = try container.decodeIfPresent(Double.self, forKey: .glassBaseIntensity) ?? defaults.glassBaseIntensity
        glassSpecularIntensity = try container.decodeIfPresent(Double.self, forKey: .glassSpecularIntensity) ?? defaults.glassSpecularIntensity
        glassDepth = try container.decodeIfPresent(Double.self, forKey: .glassDepth) ?? defaults.glassDepth
        glassEdgeDistance = try container.decodeIfPresent(Double.self, forKey: .glassEdgeDistance) ?? defaults.glassEdgeDistance
        glassRimDistance = try container.decodeIfPresent(Double.self, forKey: .glassRimDistance) ?? defaults.glassRimDistance
        glassBaseDistance = try container.decodeIfPresent(Double.self, forKey: .glassBaseDistance) ?? defaults.glassBaseDistance
        glassCornerBoost = try container.decodeIfPresent(Double.self, forKey: .glassCornerBoost) ?? defaults.glassCornerBoost
        glassRippleEffect = try container.decodeIfPresent(Double.self, forKey: .glassRippleEffect) ?? defaults.glassRippleEffect
        glassBlurRadius = try container.decodeIfPresent(Double.self, forKey: .glassBlurRadius) ?? defaults.glassBlurRadius
        glassTintOpacity = try container.decodeIfPresent(Double.self, forKey: .glassTintOpacity) ?? defaults.glassTintOpacity
        glassCenterWarpEnabled = try container.decodeIfPresent(Bool.self, forKey: .glassCenterWarpEnabled) ?? defaults.glassCenterWarpEnabled
        paddleRoundness = try container.decodeIfPresent(Double.self, forKey: .paddleRoundness) ?? defaults.paddleRoundness
        paddleHeight = try container.decodeIfPresent(Double.self, forKey: .paddleHeight) ?? defaults.paddleHeight
        paddleWidth = try container.decodeIfPresent(Double.self, forKey: .paddleWidth) ?? defaults.paddleWidth
        ballSize = try container.decodeIfPresent(Double.self, forKey: .ballSize) ?? defaults.ballSize
        ballSpeed = try container.decodeIfPresent(Double.self, forKey: .ballSpeed) ?? defaults.ballSpeed
        aiSkill = try container.decodeIfPresent(Double.self, forKey: .aiSkill) ?? defaults.aiSkill
        showScore = try container.decodeIfPresent(Bool.self, forKey: .showScore) ?? defaults.showScore
        showCenterLine = try container.decodeIfPresent(Bool.self, forKey: .showCenterLine) ?? defaults.showCenterLine
        passThrough = try container.decodeIfPresent(Bool.self, forKey: .passThrough) ?? defaults.passThrough
        reducedMotion = try container.decodeIfPresent(Bool.self, forKey: .reducedMotion) ?? defaults.reducedMotion
        hapticFeedbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticFeedbackEnabled) ?? defaults.hapticFeedbackEnabled
    }

    mutating func clamp() {
        objectOpacity = objectOpacity.clamped(to: 0.20 ... 1.0)
        glowStrength = glowStrength.clamped(to: 0 ... 1)
        glassEdgeIntensity = glassEdgeIntensity.clamped(to: 0 ... 1)
        glassRimIntensity = glassRimIntensity.clamped(to: 0 ... 1)
        glassBaseIntensity = glassBaseIntensity.clamped(to: 0 ... 1)
        glassSpecularIntensity = glassSpecularIntensity.clamped(to: 0 ... 1)
        glassDepth = glassDepth.clamped(to: 0 ... 1)
        glassEdgeDistance = glassEdgeDistance.clamped(to: 0 ... 1)
        glassRimDistance = glassRimDistance.clamped(to: 0 ... 1)
        glassBaseDistance = glassBaseDistance.clamped(to: 0 ... 1)
        glassCornerBoost = glassCornerBoost.clamped(to: 0 ... 1)
        glassRippleEffect = glassRippleEffect.clamped(to: 0 ... 1)
        glassBlurRadius = glassBlurRadius.clamped(to: 0 ... 12)
        glassTintOpacity = glassTintOpacity.clamped(to: 0 ... 1)
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
            if stored.controlBindings == .legacyDefault {
                stored.controlBindings = .default
            }
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
