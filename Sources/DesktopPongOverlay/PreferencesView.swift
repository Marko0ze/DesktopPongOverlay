import AppKit
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var store: SettingsStore
    let resetGame: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsPreviewView(settings: store.settings)

                GroupBox("Appearance") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Material")
                            .font(.subheadline.weight(.medium))
                        MaterialStylePicker(selection: $store.settings.materialStyle)

                        ColorPicker("Player Paddle", selection: colorBinding(\.playerPaddleColor))
                        ColorPicker("AI Paddle", selection: colorBinding(\.aiPaddleColor))
                        ColorPicker("Ball", selection: colorBinding(\.ballColor))
                        ColorPicker("Score", selection: colorBinding(\.scoreColor))
                        valueSlider("Object Opacity", value: $store.settings.objectOpacity, range: 0.2 ... 1, format: .percent)
                        valueSlider("Glow", value: $store.settings.glowStrength, range: 0 ... 1, format: .percent)
                    }
                    .padding(.top, 6)
                }

                GroupBox("Gameplay Feel") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Impact", selection: $store.settings.impactPreset) {
                            ForEach(ImpactPreset.allCases, id: \.self) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)
                        valueSlider("Paddle Roundness", value: $store.settings.paddleRoundness, range: 0 ... 1, format: .percent)
                        valueSlider("Paddle Height", value: $store.settings.paddleHeight, range: 60 ... 240, format: .pixels)
                        valueSlider("Paddle Width", value: $store.settings.paddleWidth, range: 8 ... 36, format: .pixels)
                        valueSlider("Ball Size", value: $store.settings.ballSize, range: 8 ... 36, format: .pixels)
                        valueSlider("Ball Speed", value: $store.settings.ballSpeed, range: 0 ... 1, format: .percent)
                        Text("Ball speed applies on the next serve, then ramps gently after each paddle hit.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        valueSlider("AI Skill", value: $store.settings.aiSkill, range: 0 ... 1, format: .percent)
                    }
                    .padding(.top, 6)
                }

                GroupBox("Game") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Mode", selection: $store.settings.mode) {
                            ForEach(GameMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        Toggle("Left Paddle is AI", isOn: leftPaddleIsAIBinding)
                        Toggle("Show Score", isOn: $store.settings.showScore)
                        Toggle("Show Centre Line", isOn: $store.settings.showCenterLine)
                        HStack {
                            Button("Reset Score", action: resetGame)
                            Spacer()
                            Button("Reset to Defaults", action: store.resetToDefaults)
                        }
                    }
                    .padding(.top, 6)
                }

                DisclosureGroup("Advanced") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Pass-through Overlay", isOn: $store.settings.passThrough)
                        Text("When enabled, clicks go to the apps underneath the game.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Toggle("Reduced Motion", isOn: $store.settings.reducedMotion)
                        Text("The system Reduce Motion setting is respected automatically too.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(20)
        }
        .frame(width: 500, height: 650)
        .background(.background)
    }

    private func colorBinding(_ keyPath: WritableKeyPath<PongSettings, RGBAColor>) -> Binding<Color> {
        Binding(
            get: { Color(nsColor: store.settings[keyPath: keyPath].nsColor) },
            set: { store.settings[keyPath: keyPath] = RGBAColor(nsColor: NSColor($0)) }
        )
    }

    private var leftPaddleIsAIBinding: Binding<Bool> {
        Binding(
            get: { store.settings.mode == .demo },
            set: { store.settings.mode = $0 ? .demo : .playerVsAI }
        )
    }

    private func valueSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: SliderValueFormat
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text(format.text(value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
                .accessibilityLabel(title)
        }
    }
}

private struct MaterialStylePicker: View {
    @Binding var selection: PongMaterialStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(PongMaterialStyle.allCases, id: \.self) { style in
                    Button {
                        selection = style
                    } label: {
                        VStack(spacing: 7) {
                            MaterialSample(style: style)
                                .frame(height: 34)
                            HStack(spacing: 4) {
                                Text(style.title)
                                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                                if selection == style {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .font(.caption.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.glass)
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(selection == style ? Color.accentColor : .clear, lineWidth: 2)
                            .allowsHitTesting(false)
                    }
                    .accessibilityLabel("\(style.title) material")
                    .accessibilityValue(selection == style ? "Selected" : "Not selected")
                }
            }
        }
    }
}

private struct MaterialSample: View {
    let style: PongMaterialStyle

    var body: some View {
        HStack(spacing: 13) {
            samplePaddle
            Circle()
                .fill(sampleFill)
                .frame(width: 12, height: 12)
                .overlay(sampleStroke)
                .shadow(color: glowColor, radius: glowRadius)
            samplePaddle
        }
        .frame(maxWidth: .infinity)
    }

    private var samplePaddle: some View {
        Capsule()
            .fill(sampleFill)
            .frame(width: 8, height: 28)
            .overlay(sampleStroke)
            .shadow(color: glowColor, radius: glowRadius)
    }

    private var sampleFill: Color {
        switch style {
        case .glass: .cyan.opacity(0.58)
        case .clear: .cyan
        case .frosted: .cyan.opacity(0.70)
        }
    }

    @ViewBuilder private var sampleStroke: some View {
        switch style {
        case .glass:
            CircleOrCapsuleStroke(color: .white.opacity(0.82))
        case .clear:
            CircleOrCapsuleStroke(color: .clear)
        case .frosted:
            CircleOrCapsuleStroke(color: .white.opacity(0.35))
        }
    }

    private var glowColor: Color {
        style == .clear ? .clear : .cyan.opacity(style == .glass ? 0.48 : 0.24)
    }

    private var glowRadius: CGFloat { style == .glass ? 5 : 3 }
}

private struct CircleOrCapsuleStroke: View {
    let color: Color

    var body: some View {
        Capsule().stroke(color, lineWidth: 1)
    }
}

private enum SliderValueFormat {
    case percent
    case pixels

    func text(_ value: Double) -> String {
        switch self {
        case .percent: "\(Int((value * 100).rounded()))%"
        case .pixels: "\(Int(value.rounded())) px"
        }
    }
}

private struct SettingsPreviewView: View {
    let settings: PongSettings
    @State private var ballAtRight = false
    @State private var impactPulse = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.black.opacity(0.82))
                paddle(color: settings.playerPaddleColor.nsColor)
                    .frame(width: previewPaddleWidth, height: previewPaddleHeight)
                    .position(x: 36, y: proxy.size.height / 2)
                    .scaleEffect(
                        x: impactPulse ? 1 + previewImpactScale : 1,
                        y: impactPulse ? 1 - previewImpactScale * 0.48 : 1
                    )
                paddle(color: settings.aiPaddleColor.nsColor)
                    .frame(width: previewPaddleWidth, height: previewPaddleHeight)
                    .position(x: proxy.size.width - 36, y: proxy.size.height / 2)
                Circle()
                    .fill(Color(nsColor: settings.ballColor.nsColor).opacity(settings.objectOpacity))
                    .shadow(color: Color(nsColor: settings.ballColor.nsColor).opacity(settings.glowStrength), radius: settings.glowStrength * 10)
                    .frame(width: previewBallSize, height: previewBallSize)
                    .position(
                        x: ballAtRight ? proxy.size.width - 58 : 58,
                        y: proxy.size.height / 2
                    )
                    .animation(
                        effectiveReducedMotion ? .none : .linear(duration: 1.35).repeatForever(autoreverses: true),
                        value: ballAtRight
                    )
            }
        }
        .frame(height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live preview of the current paddle and ball appearance")
        .onAppear { ballAtRight = true }
        .onChange(of: settings.impactPreset) { _, _ in
            playImpactPreview()
        }
    }

    private var previewPaddleWidth: CGFloat { max(8, settings.paddleWidth * 0.72) }
    private var previewPaddleHeight: CGFloat { max(42, settings.paddleHeight * 0.48) }
    private var previewBallSize: CGFloat { max(8, settings.ballSize * 0.82) }
    private var effectiveReducedMotion: Bool { settings.reducedMotion || systemReduceMotion }
    private var previewImpactScale: CGFloat { effectiveReducedMotion ? 0 : settings.impactPreset.scale }

    private func paddle(color: NSColor) -> some View {
        RoundedRectangle(cornerRadius: previewPaddleWidth * settings.paddleRoundness / 2)
            .fill(paddleFill(color: color))
            .overlay {
                if settings.materialStyle != .clear {
                    RoundedRectangle(cornerRadius: previewPaddleWidth * settings.paddleRoundness / 2)
                        .stroke(
                            .white.opacity(settings.materialStyle == .glass ? 0.72 : 0.30),
                            lineWidth: 1
                        )
                }
            }
            .shadow(color: Color(nsColor: color).opacity(settings.glowStrength), radius: settings.glowStrength * 10)
    }

    private func paddleFill(color: NSColor) -> Color {
        let base = Color(nsColor: color)
        return switch settings.materialStyle {
        case .glass: base.opacity(settings.objectOpacity * 0.62)
        case .clear: base.opacity(settings.objectOpacity)
        case .frosted: base.opacity(settings.objectOpacity * 0.74)
        }
    }

    private func playImpactPreview() {
        guard !effectiveReducedMotion, settings.impactPreset != .off else { return }
        withAnimation(.easeOut(duration: 0.045)) {
            impactPulse = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(55))
            withAnimation(.easeOut(duration: 0.10)) {
                impactPulse = false
            }
        }
    }
}
