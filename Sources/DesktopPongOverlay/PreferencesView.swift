import AppKit
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case appearance
    case controls
    case gameplay
    case presentation
    case privacy

    var id: Self { self }

    var title: String {
        switch self {
        case .appearance: "Appearance"
        case .controls: "Controls"
        case .gameplay: "Gameplay"
        case .presentation: "Presentation"
        case .privacy: "Privacy"
        }
    }

    var systemImage: String {
        switch self {
        case .appearance: "sparkles"
        case .controls: "keyboard"
        case .gameplay: "gamecontroller"
        case .presentation: "menubar.rectangle"
        case .privacy: "hand.raised"
        }
    }
}

struct PreferencesView: View {
    @ObservedObject var store: SettingsStore
    let resetGame: () -> Void
    @State private var selection: SettingsSection? = .appearance

    init(store: SettingsStore, resetGame: @escaping () -> Void) {
        self.store = store
        self.resetGame = resetGame
        _selection = State(initialValue: SettingsSection.previewDefault)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                    .padding(.bottom, 8)
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        Label(section.title, systemImage: section.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle((selection ?? .appearance) == section ? .primary : .secondary)
                    .background {
                        if (selection ?? .appearance) == section {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.18))
                        }
                    }
                    .accessibilityValue((selection ?? .appearance) == section ? "Selected" : "Not selected")
                }
                Spacer()
            }
            .frame(width: 190)
            .padding(18)
            .background(.ultraThinMaterial)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsPreviewView(settings: store.settings)
                    detail(for: selection ?? .appearance)
                }
                .padding(24)
            }
        }
        .frame(width: 760, height: 580)
    }

    @ViewBuilder private func detail(for section: SettingsSection) -> some View {
        switch section {
        case .appearance:
            appearanceSettings
        case .controls:
            controlsSettings
        case .gameplay:
            gameplaySettings
        case .presentation:
            presentationSettings
        case .privacy:
            privacySettings
        }
    }

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Liquid Glass")
                .font(.title3.weight(.semibold))
            Text("Object-local glass keeps the no-screen-recording privacy promise while giving the ball and paddles richer depth, rim light, glow, and specular highlights.")
                .font(.caption)
                .foregroundStyle(.secondary)
            MaterialStylePicker(selection: $store.settings.materialStyle)
            Picker("Glass Quality", selection: $store.settings.glassQuality) {
                ForEach(GlassQuality.allCases, id: \.self) { quality in
                    Text(quality.title).tag(quality)
                }
            }
            .pickerStyle(.segmented)
            ColorPicker("Player Paddle", selection: colorBinding(\.playerPaddleColor))
            ColorPicker("AI Paddle", selection: colorBinding(\.aiPaddleColor))
            Picker("Paddle Fill", selection: $store.settings.paddleGlassFill) {
                ForEach(PaddleGlassFill.allCases, id: \.self) { fill in
                    Text(fill.title).tag(fill)
                }
            }
            .pickerStyle(.segmented)
            Text("Transparent keeps the paddle body clear while the colour still drives the rim, glow, and impact highlight.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ColorPicker("Ball", selection: colorBinding(\.ballColor))
            ColorPicker("Score", selection: colorBinding(\.scoreColor))
            valueSlider("Object Opacity", value: $store.settings.objectOpacity, range: 0.2 ... 1, format: .percent)
            valueSlider("Glow", value: $store.settings.glowStrength, range: 0 ... 1, format: .percent)
            valueSlider("Rim Intensity", value: $store.settings.glassRimIntensity, range: 0 ... 1, format: .percent)
            valueSlider("Specular Highlight", value: $store.settings.glassSpecularIntensity, range: 0 ... 1, format: .percent)
            valueSlider("Glass Depth", value: $store.settings.glassDepth, range: 0 ... 1, format: .percent)
        }
        .settingsCard()
    }

    private var controlsSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Controls")
                .font(.title3.weight(.semibold))
            Picker("Player Control", selection: $store.settings.playerControlMode) {
                ForEach(PlayerControlMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            KeyBindingRow(
                title: "Player Paddle Up",
                binding: $store.settings.controlBindings.leftUp,
                reservedKeyCodes: Set([
                    store.settings.controlBindings.leftDown.keyCode,
                    store.settings.controlBindings.rightUp.keyCode,
                    store.settings.controlBindings.rightDown.keyCode
                ])
            )
            KeyBindingRow(
                title: "Player Paddle Down",
                binding: $store.settings.controlBindings.leftDown,
                reservedKeyCodes: Set([
                    store.settings.controlBindings.leftUp.keyCode,
                    store.settings.controlBindings.rightUp.keyCode,
                    store.settings.controlBindings.rightDown.keyCode
                ])
            )
            Divider()
            KeyBindingRow(
                title: "Second Paddle Up",
                binding: $store.settings.controlBindings.rightUp,
                reservedKeyCodes: Set([
                    store.settings.controlBindings.leftUp.keyCode,
                    store.settings.controlBindings.leftDown.keyCode,
                    store.settings.controlBindings.rightDown.keyCode
                ])
            )
            KeyBindingRow(
                title: "Second Paddle Down",
                binding: $store.settings.controlBindings.rightDown,
                reservedKeyCodes: Set([
                    store.settings.controlBindings.leftUp.keyCode,
                    store.settings.controlBindings.leftDown.keyCode,
                    store.settings.controlBindings.rightUp.keyCode
                ])
            )
            if store.settings.controlBindings.hasDuplicateGameplayKeys {
                Label("Each gameplay action needs a unique key.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            Divider()
            KeyBindingRow(
                title: "Global Toggle",
                binding: $store.settings.controlBindings.globalToggle,
                prefix: "⌥⌘"
            )
            HStack {
                Spacer()
                Button("Reset Controls") {
                    store.settings.controlBindings = .default
                    store.settings.playerControlMode = .keyboardAndMouse
                }
            }
            Text("Player vs AI accepts W/S or Up/Down arrows by default. If the overlay never changes from “no key” while you hold ↑/↓, grant Accessibility access to Desktop Pong Overlay and toggle Capture Input off/on.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .settingsCard()
    }

    private var gameplaySettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Gameplay")
                .font(.title3.weight(.semibold))
            Picker("Mode", selection: $store.settings.mode) {
                ForEach(GameMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            Toggle("Left Paddle is AI", isOn: leftPaddleIsAIBinding)
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
            HStack {
                Button("Reset Score", action: resetGame)
                Spacer()
                Button("Reset All Settings", action: store.resetToDefaults)
            }
        }
        .settingsCard()
    }

    private var presentationSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Presentation")
                .font(.title3.weight(.semibold))
            Picker("Presentation", selection: $store.settings.presentationMode) {
                ForEach(PresentationMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Toggle("Pass-through Overlay", isOn: $store.settings.passThrough)
            Toggle("Show Score", isOn: $store.settings.showScore)
            Toggle("Show Centre Line", isOn: $store.settings.showCenterLine)
            Toggle("Reduced Motion", isOn: $store.settings.reducedMotion)
            Text("Desktop Overlay floats over the screen. Menu Bar Game collapses Pong into the icon popover.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .settingsCard()
    }

    private var privacySettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy")
                .font(.title3.weight(.semibold))
            Label("No internet, analytics, accounts, or data collection.", systemImage: "network.slash")
            Label("No screen recording or screenshots.", systemImage: "camera.viewfinder")
            Label("No always-on key monitor; Capture Input checks configured gameplay keys and uses a filtered Accessibility tap as backup.", systemImage: "keyboard")
            Label("Liquid Glass is simulated locally on the game objects, not by sampling your desktop.", systemImage: "sparkles")
        }
        .settingsCard()
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

private extension SettingsSection {
    static var previewDefault: SettingsSection {
        guard let rawValue = ProcessInfo.processInfo.environment["DESKTOP_PONG_SETTINGS_SECTION"],
              let section = SettingsSection(rawValue: rawValue) else {
            return .appearance
        }
        return section
    }
}

private struct SettingsCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private extension View {
    func settingsCard() -> some View {
        modifier(SettingsCardModifier())
    }
}

private struct KeyBindingRow: View {
    let title: String
    @Binding var binding: KeyBinding
    var prefix = ""
    var reservedKeyCodes = Set<UInt16>()
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Button(isRecording ? "Press a key…" : "\(prefix)\(binding.label)") {
                    startRecording()
                }
                .keyboardShortcut(.defaultAction)
                .monospaced()
                .accessibilityLabel("\(title) key")
                .accessibilityValue("\(prefix)\(binding.label)")
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        stopRecording()
        errorMessage = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let candidate = KeyBinding(event: event)
            if reservedKeyCodes.contains(candidate.keyCode) {
                errorMessage = "\(candidate.label) is also assigned to another paddle action."
            }
            binding = candidate
            DispatchQueue.main.async {
                stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
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
                if settings.materialStyle != .clear || settings.paddleGlassFill == .transparent {
                    RoundedRectangle(cornerRadius: previewPaddleWidth * settings.paddleRoundness / 2)
                        .stroke(
                            paddleStroke(color: color),
                            lineWidth: settings.paddleGlassFill == .transparent ? 1.2 : 1
                        )
                }
            }
            .overlay(alignment: .topLeading) {
                if settings.materialStyle == .glass && settings.glassQuality != .performance {
                    RoundedRectangle(cornerRadius: previewPaddleWidth * settings.paddleRoundness / 2)
                        .fill(.white.opacity(settings.glassSpecularIntensity * 0.20))
                        .frame(width: max(2, previewPaddleWidth * 0.35))
                        .padding(.leading, previewPaddleWidth * 0.18)
                        .padding(.vertical, previewPaddleHeight * 0.14)
                        .allowsHitTesting(false)
                }
            }
            .shadow(
                color: Color(nsColor: color).opacity(settings.glowStrength * (settings.paddleGlassFill == .transparent ? 1.18 : 1)),
                radius: settings.glowStrength * 10
            )
    }

    private func paddleFill(color: NSColor) -> Color {
        let base = Color(nsColor: color)
        let fillScale = settings.paddleGlassFill.fillAlphaScale
        return switch settings.materialStyle {
        case .glass: base.opacity(settings.objectOpacity * 0.62 * fillScale)
        case .clear: base.opacity(settings.objectOpacity * fillScale)
        case .frosted: base.opacity(settings.objectOpacity * 0.74 * fillScale)
        }
    }

    private func paddleStroke(color: NSColor) -> Color {
        if settings.paddleGlassFill == .transparent {
            Color(nsColor: color).opacity(settings.objectOpacity * 0.82)
        } else {
            .white.opacity(settings.materialStyle == .glass ? 0.72 : 0.30)
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
