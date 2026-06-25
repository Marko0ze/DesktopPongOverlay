import AppKit
import SpriteKit

@MainActor
final class PongScene: SKScene {
    private let settingsStore: SettingsStore
    private let inputMonitor: InputMonitor
    private var gameState: PongGameState

    private let leftPaddle = SKShapeNode()
    private let rightPaddle = SKShapeNode()
    private let ball = SKShapeNode()
    private let leftPaddleRim = SKShapeNode()
    private let rightPaddleRim = SKShapeNode()
    private let ballRim = SKShapeNode()
    private let leftPaddleSpecular = SKShapeNode()
    private let rightPaddleSpecular = SKShapeNode()
    private let ballSpecular = SKShapeNode()
    private let centerLine = SKShapeNode()
    private let centerLineShadow = SKShapeNode()
    private let leftScore = SKLabelNode(fontNamed: "SFMono-Semibold")
    private let rightScore = SKLabelNode(fontNamed: "SFMono-Semibold")
    private let leftScoreShadow = SKLabelNode(fontNamed: "SFMono-Semibold")
    private let rightScoreShadow = SKLabelNode(fontNamed: "SFMono-Semibold")
    private let inputStatusLabel = SKLabelNode(fontNamed: "SFMono-Regular")
    private let inputStatusShadow = SKLabelNode(fontNamed: "SFMono-Regular")

    private var lastUpdateTime: TimeInterval?
    private var renderedImpactSequence = 0
    private(set) var isGamePaused = false
    var screenOriginY: CGFloat = 0
    var onImpact: (() -> Void)?

    init(size: CGSize, settingsStore: SettingsStore, inputMonitor: InputMonitor) {
        self.settingsStore = settingsStore
        self.inputMonitor = inputMonitor
        gameState = PongGameState(playfieldSize: size, settings: settingsStore.settings)
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        anchorPoint = .zero
        configureNodes()
        applySettings()
        render()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: SettingsStore.didChangeNotification,
            object: settingsStore
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(resetClock),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        guard !isGamePaused else { return }
        guard let lastUpdateTime else { return }

        gameState.update(
            deltaTime: currentTime - lastUpdateTime,
            input: inputMonitor.snapshot(screenOriginY: screenOriginY, settings: settingsStore.settings),
            settings: settingsStore.settings
        )
        render()
        playImpactIfNeeded()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size != oldSize else { return }
        gameState.resize(to: size, settings: settingsStore.settings)
        rebuildCenterLine()
        render()
    }

    func togglePause() {
        setPaused(!isGamePaused)
    }

    func setPaused(_ paused: Bool) {
        isGamePaused = paused
        lastUpdateTime = nil
    }

    func resetGame() {
        gameState.resetScores(settings: settingsStore.settings)
        render()
    }

    func runtimeSnapshot() -> PongSceneRuntimeSnapshot {
        PongSceneRuntimeSnapshot(
            size: size,
            backgroundAlpha: backgroundColor.alphaComponent,
            isPaused: isGamePaused,
            updateClockIsPrimed: lastUpdateTime != nil,
            ballPosition: gameState.ballPosition,
            leftPaddleY: gameState.leftPaddleY,
            rightPaddleY: gameState.rightPaddleY,
            leftScore: gameState.leftScore,
            rightScore: gameState.rightScore,
            leftPaddleFillAlpha: leftPaddle.fillColor.alphaComponent,
            rightPaddleFillAlpha: rightPaddle.fillColor.alphaComponent,
            leftPaddleSpecularVisible: !leftPaddleSpecular.isHidden,
            rightPaddleSpecularVisible: !rightPaddleSpecular.isHidden,
            ballVisible: !ball.isHidden && ball.parent === self,
            paddlesVisible: !leftPaddle.isHidden && !rightPaddle.isHidden,
            liquidGlassRimVisible: settingsStore.settings.materialStyle.isLiquidGlass && !ballRim.isHidden && !leftPaddleRim.isHidden,
            liquidGlassSpecularVisible: settingsStore.settings.materialStyle.isLiquidGlass && !ballSpecular.isHidden,
            centerLineVisible: !centerLine.isHidden,
            scoreVisible: !leftScore.isHidden && !rightScore.isHidden
        )
    }

    @objc func resetClock() {
        lastUpdateTime = nil
    }

    @objc private func settingsDidChange() {
        gameState.resize(to: size, settings: settingsStore.settings)
        applySettings()
        render()
    }

    private func configureNodes() {
        [
            centerLineShadow, centerLine,
            leftPaddle, rightPaddle, ball,
            leftPaddleRim, rightPaddleRim, ballRim,
            leftPaddleSpecular, rightPaddleSpecular, ballSpecular,
            leftScoreShadow, rightScoreShadow, leftScore, rightScore,
            inputStatusShadow, inputStatusLabel
        ].forEach(addChild)
        centerLineShadow.zPosition = -0.1
        centerLine.zPosition = 0
        leftPaddle.zPosition = 2
        rightPaddle.zPosition = 2
        ball.zPosition = 3
        leftPaddleRim.zPosition = 2.2
        rightPaddleRim.zPosition = 2.2
        ballRim.zPosition = 3.2
        leftPaddleSpecular.zPosition = 2.3
        rightPaddleSpecular.zPosition = 2.3
        ballSpecular.zPosition = 3.3
        leftScore.zPosition = 2
        rightScore.zPosition = 2
        leftScoreShadow.zPosition = 1.9
        rightScoreShadow.zPosition = 1.9
        inputStatusShadow.zPosition = 3.9
        inputStatusLabel.zPosition = 4
        [leftScore, rightScore, leftScoreShadow, rightScoreShadow].forEach {
            $0.horizontalAlignmentMode = .center
            $0.verticalAlignmentMode = .top
        }
        [inputStatusShadow, inputStatusLabel].forEach {
            $0.horizontalAlignmentMode = .left
            $0.verticalAlignmentMode = .bottom
            $0.fontSize = 13
        }
        inputStatusShadow.fontColor = NSColor.black.withAlphaComponent(0.52)
    }

    private func applySettings() {
        let settings = settingsStore.settings
        inputMonitor.updateControlBindings(settings.controlBindings)
        let paddleSize = CGSize(width: settings.paddleWidth, height: settings.paddleHeight)
        let cornerRadius = min(paddleSize.width / 2, paddleSize.width * settings.paddleRoundness / 2)

        leftPaddle.path = CGPath(
            roundedRect: CGRect(origin: CGPoint(x: -paddleSize.width / 2, y: -paddleSize.height / 2), size: paddleSize),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        rightPaddle.path = leftPaddle.path
        leftPaddleRim.path = leftPaddle.path
        rightPaddleRim.path = leftPaddle.path
        leftPaddleSpecular.path = leftPaddle.path
        rightPaddleSpecular.path = leftPaddle.path
        ball.path = CGPath(
            ellipseIn: CGRect(
                x: -settings.ballSize / 2,
                y: -settings.ballSize / 2,
                width: settings.ballSize,
                height: settings.ballSize
            ),
            transform: nil
        )
        ballRim.path = ball.path
        ballSpecular.path = CGPath(
            ellipseIn: CGRect(
                x: -settings.ballSize * 0.28,
                y: settings.ballSize * 0.10,
                width: settings.ballSize * 0.32,
                height: settings.ballSize * 0.24
            ),
            transform: nil
        )

        styleGlassObject(
            base: leftPaddle,
            rim: leftPaddleRim,
            specular: leftPaddleSpecular,
            color: settings.playerPaddleColor.nsColor,
            settings: settings,
            fillAlphaScale: CGFloat(settings.paddleGlassFill.fillAlphaScale),
            rimColor: settings.playerPaddleColor.nsColor.blended(withFraction: 0.48, of: .white) ?? .white,
            transparentOutlineBoost: settings.paddleGlassFill == .transparent,
            isPaddle: true
        )
        styleGlassObject(
            base: rightPaddle,
            rim: rightPaddleRim,
            specular: rightPaddleSpecular,
            color: settings.aiPaddleColor.nsColor,
            settings: settings,
            fillAlphaScale: CGFloat(settings.paddleGlassFill.fillAlphaScale),
            rimColor: settings.aiPaddleColor.nsColor.blended(withFraction: 0.48, of: .white) ?? .white,
            transparentOutlineBoost: settings.paddleGlassFill == .transparent,
            isPaddle: true
        )
        styleGlassObject(base: ball, rim: ballRim, specular: ballSpecular, color: settings.ballColor.nsColor, settings: settings)

        leftScore.fontSize = 38
        rightScore.fontSize = 38
        leftScoreShadow.fontSize = 38
        rightScoreShadow.fontSize = 38
        leftScore.fontColor = settings.scoreColor.nsColor.withAlphaComponent(settings.objectOpacity)
        rightScore.fontColor = leftScore.fontColor
        leftScoreShadow.fontColor = NSColor.black.withAlphaComponent(0.52)
        rightScoreShadow.fontColor = leftScoreShadow.fontColor
        leftScore.isHidden = !settings.showScore
        rightScore.isHidden = !settings.showScore
        leftScoreShadow.isHidden = !settings.showScore
        rightScoreShadow.isHidden = !settings.showScore
        centerLine.isHidden = !settings.showCenterLine
        centerLineShadow.isHidden = !settings.showCenterLine
        rebuildCenterLine()
    }

    private func styleGlassObject(
        base: SKShapeNode,
        rim: SKShapeNode,
        specular: SKShapeNode,
        color: NSColor,
        settings: PongSettings,
        fillAlphaScale: CGFloat = 1,
        rimColor: NSColor = .white,
        transparentOutlineBoost: Bool = false,
        isPaddle: Bool = false
    ) {
        let opacity = CGFloat(settings.objectOpacity)
        let qualityMultiplier = glassQualityMultiplier(settings.glassQuality)
        let edgeIntensity = CGFloat(settings.glassEdgeIntensity) * qualityMultiplier
        let rimAlpha = CGFloat(settings.glassRimIntensity) * opacity * qualityMultiplier
        let baseIntensity = CGFloat(settings.glassBaseIntensity) * qualityMultiplier
        let specularAlpha = CGFloat(settings.glassSpecularIntensity) * opacity * qualityMultiplier
        let depth = CGFloat(settings.glassDepth) * CGFloat(settings.glassBaseDistance) * qualityMultiplier
        let edgeDistance = CGFloat(settings.glassEdgeDistance)
        let rimDistance = CGFloat(settings.glassRimDistance)
        let cornerBoost = isPaddle ? CGFloat(settings.glassCornerBoost) * CGFloat(settings.paddleRoundness) : CGFloat(settings.glassCornerBoost)
        let blurRadius = CGFloat(settings.glassBlurRadius)
        let tintOpacity = CGFloat(settings.glassTintOpacity)
        let warpBoost: CGFloat = settings.glassCenterWarpEnabled ? 1.0 : 0.72
        let outlineAlpha = transparentOutlineBoost ? opacity * (0.58 + edgeIntensity * 0.34) : opacity * (0.18 + edgeIntensity * 0.34)
        let frostedOutlineAlpha = transparentOutlineBoost ? opacity * 0.80 : opacity * 0.5
        switch settings.materialStyle {
        case .glass:
            base.fillColor = color.withAlphaComponent(opacity * (0.26 + tintOpacity * 0.78 + depth * 0.18) * baseIntensity * fillAlphaScale)
            base.strokeColor = color.blended(withFraction: 0.40, of: .white)?.withAlphaComponent(outlineAlpha) ?? color
            base.lineWidth = (transparentOutlineBoost ? 0.95 : 0.55) + edgeDistance * 1.15 + cornerBoost * 0.55
            base.glowWidth = settings.glowStrength * (blurRadius + depth * 10 + edgeIntensity * 5) * (transparentOutlineBoost ? 1.18 : 1)
            rim.fillColor = .clear
            rim.strokeColor = rimColor.withAlphaComponent(min(1, rimAlpha * (transparentOutlineBoost ? 1.16 : 1)))
            rim.lineWidth = 0.8 + rimDistance * 2.3 + depth * 0.9 + cornerBoost * 0.6 + (transparentOutlineBoost ? 0.35 : 0)
            rim.glowWidth = settings.glowStrength * (1.4 + blurRadius) * qualityMultiplier * (transparentOutlineBoost ? 1.25 : 1)
            specular.fillColor = NSColor.white.withAlphaComponent(specularAlpha * 0.75)
            specular.strokeColor = NSColor.white.withAlphaComponent(specularAlpha * 0.35 * warpBoost)
            specular.lineWidth = 0.35 + edgeDistance * 0.55
            specular.glowWidth = settings.glowStrength * (1.2 + blurRadius * 0.55) * qualityMultiplier
            rim.isHidden = settings.glassQuality == .performance
            specular.isHidden = isPaddle || settings.glassQuality == .performance
        case .fullGlass:
            let lensFillScale = max(fillAlphaScale, settings.paddleGlassFill == .transparent ? 0.35 : 1)
            base.fillColor = color.withAlphaComponent(opacity * (0.05 + tintOpacity * 0.52 + depth * 0.16) * max(0.35, baseIntensity) * lensFillScale)
            base.strokeColor = NSColor.white.withAlphaComponent(opacity * (0.32 + edgeIntensity * 0.48 + depth * 0.20))
            base.lineWidth = 0.9 + edgeDistance * 1.5 + cornerBoost * 0.6
            base.glowWidth = settings.glowStrength * (blurRadius + 4 + depth * 13 + edgeIntensity * 5)
            rim.fillColor = .clear
            rim.strokeColor = rimColor.withAlphaComponent(min(1, rimAlpha * 1.35 + 0.16))
            rim.lineWidth = 1.0 + rimDistance * 3.1 + depth * 1.2 + cornerBoost * 0.7
            rim.glowWidth = settings.glowStrength * (2.3 + blurRadius * 1.05) * qualityMultiplier
            specular.fillColor = .clear
            specular.strokeColor = NSColor.white.withAlphaComponent(specularAlpha * 0.55 * warpBoost)
            specular.lineWidth = 0.55 + edgeDistance * 0.9
            specular.glowWidth = settings.glowStrength * (1.2 + blurRadius * 0.78) * qualityMultiplier
            rim.isHidden = settings.glassQuality == .performance
            specular.isHidden = settings.glassQuality == .performance
        case .clear:
            base.fillColor = color.withAlphaComponent(opacity * fillAlphaScale)
            base.strokeColor = transparentOutlineBoost ? color.withAlphaComponent(opacity * 0.82) : .clear
            base.lineWidth = transparentOutlineBoost ? 1.1 : 0
            base.glowWidth = transparentOutlineBoost ? settings.glowStrength * 5 : 0
            rim.isHidden = true
            specular.isHidden = true
        case .frosted:
            base.fillColor = color.withAlphaComponent(opacity * (0.58 + depth * 0.12) * fillAlphaScale)
            base.strokeColor = color.blended(withFraction: 0.55, of: .white)?.withAlphaComponent(frostedOutlineAlpha) ?? color
            base.lineWidth = transparentOutlineBoost ? 1.25 : 1
            base.glowWidth = settings.glowStrength * (5 + depth * 5) * (transparentOutlineBoost ? 1.18 : 1)
            rim.fillColor = .clear
            rim.strokeColor = rimColor.withAlphaComponent(rimAlpha * (transparentOutlineBoost ? 0.70 : 0.45))
            rim.lineWidth = 1
            rim.glowWidth = settings.glowStrength * 2
            specular.fillColor = NSColor.white.withAlphaComponent(specularAlpha * 0.25)
            specular.strokeColor = .clear
            specular.lineWidth = 0
            specular.glowWidth = 0
            rim.isHidden = settings.glassQuality == .performance
            specular.isHidden = isPaddle || settings.glassQuality != .rich
        }
    }

    private func glassQualityMultiplier(_ quality: GlassQuality) -> CGFloat {
        switch quality {
        case .performance: 0.35
        case .balanced: 0.75
        case .rich: 1.0
        }
    }

    private func rebuildCenterLine() {
        let path = CGMutablePath()
        var y: CGFloat = 18
        while y < size.height - 18 {
            path.move(to: CGPoint(x: size.width / 2, y: y))
            path.addLine(to: CGPoint(x: size.width / 2, y: min(y + 14, size.height - 18)))
            y += 28
        }
        centerLine.path = path
        centerLineShadow.path = path
        centerLineShadow.strokeColor = NSColor.black.withAlphaComponent(0.22)
        centerLineShadow.lineWidth = 3.5
        centerLine.strokeColor = NSColor.white.withAlphaComponent(0.52)
        centerLine.lineWidth = 1.5
    }

    private func render() {
        leftPaddle.position = CGPoint(x: 30, y: gameState.leftPaddleY)
        rightPaddle.position = CGPoint(x: max(30, size.width - 30), y: gameState.rightPaddleY)
        ball.position = gameState.ballPosition
        leftPaddleRim.position = leftPaddle.position
        rightPaddleRim.position = rightPaddle.position
        ballRim.position = ball.position
        leftPaddleSpecular.position = leftPaddle.position
        rightPaddleSpecular.position = rightPaddle.position
        ballSpecular.position = ball.position
        leftScore.text = String(gameState.leftScore)
        rightScore.text = String(gameState.rightScore)
        leftScoreShadow.text = leftScore.text
        rightScoreShadow.text = rightScore.text
        leftScore.position = CGPoint(x: size.width / 2 - 48, y: size.height - 28)
        rightScore.position = CGPoint(x: size.width / 2 + 48, y: size.height - 28)
        leftScoreShadow.position = CGPoint(x: leftScore.position.x + 1.5, y: leftScore.position.y - 1.5)
        rightScoreShadow.position = CGPoint(x: rightScore.position.x + 1.5, y: rightScore.position.y - 1.5)
        renderInputStatus()
    }

    private func renderInputStatus() {
        let settings = settingsStore.settings
        let isVisible = inputMonitor.isCapturingInput
        inputStatusLabel.isHidden = !isVisible
        inputStatusShadow.isHidden = !isVisible
        guard isVisible else { return }

        let text = inputMonitor.captureStatusDescription(bindings: settings.controlBindings)
        inputStatusLabel.text = text
        inputStatusShadow.text = text
        inputStatusLabel.fontColor = inputMonitor.keyboardEventTapNeedsAccessibility
            ? NSColor.systemOrange.withAlphaComponent(0.95)
            : settings.scoreColor.nsColor.withAlphaComponent(0.82)
        let position = CGPoint(x: 22, y: 18)
        inputStatusLabel.position = position
        inputStatusShadow.position = CGPoint(x: position.x + 1, y: position.y - 1)
    }

    private func playImpactIfNeeded() {
        guard gameState.impactSequence != renderedImpactSequence else { return }
        renderedImpactSequence = gameState.impactSequence
        let settings = settingsStore.settings
        let shouldReduceMotion = settings.reducedMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard !shouldReduceMotion, settings.impactPreset != .off else { return }
        onImpact?()

        let paddleNodes = gameState.lastImpactSide == .left
            ? [leftPaddle, leftPaddleRim, leftPaddleSpecular]
            : [rightPaddle, rightPaddleRim, rightPaddleSpecular]
        let amount = settings.impactPreset.scale
        let squish = SKAction.scaleX(to: 1 + amount, y: 1 - amount * 0.48, duration: 0.045)
        squish.timingMode = .easeOut
        let restore = SKAction.scale(to: 1, duration: 0.10)
        restore.timingMode = .easeOut
        paddleNodes.forEach { node in
            node.removeAction(forKey: "impactSquish")
            node.setScale(1)
            node.run(.sequence([squish, restore]), withKey: "impactSquish")
        }
        [ball, ballRim, ballSpecular].forEach { node in
            node.removeAction(forKey: "impactStretch")
            node.setScale(1)
            let stretch = SKAction.scaleX(to: 1 + amount * 0.55, y: 1 - amount * 0.30, duration: 0.04)
            stretch.timingMode = .easeOut
            node.run(.sequence([stretch, restore]), withKey: "impactStretch")
        }
        let impactX = gameState.lastImpactSide == .left ? leftPaddle.position.x : rightPaddle.position.x
        spawnRipple(at: CGPoint(x: impactX, y: gameState.ballPosition.y), strength: amount)
    }

    private func spawnRipple(at position: CGPoint, strength: CGFloat) {
        let ripple = SKShapeNode(circleOfRadius: 8)
        let rippleEffect = CGFloat(settingsStore.settings.glassRippleEffect)
        ripple.position = position
        ripple.zPosition = 1
        ripple.fillColor = .clear
        ripple.strokeColor = NSColor.white.withAlphaComponent(0.25 + rippleEffect * 0.55)
        ripple.lineWidth = 0.8 + rippleEffect * 2.0
        addChild(ripple)
        ripple.run(.sequence([
            .group([
                .scale(to: 1.4 + rippleEffect * 1.4 + strength * 3, duration: 0.14 + rippleEffect * 0.08),
                .fadeOut(withDuration: 0.14)
            ]),
            .removeFromParent()
        ]))
    }
}

struct PongSceneRuntimeSnapshot: Codable {
    let size: CGSize
    let backgroundAlpha: CGFloat
    let isPaused: Bool
    let updateClockIsPrimed: Bool
    let ballPosition: CGPoint
    let leftPaddleY: CGFloat
    let rightPaddleY: CGFloat
    let leftScore: Int
    let rightScore: Int
    let leftPaddleFillAlpha: CGFloat
    let rightPaddleFillAlpha: CGFloat
    let leftPaddleSpecularVisible: Bool
    let rightPaddleSpecularVisible: Bool
    let ballVisible: Bool
    let paddlesVisible: Bool
    let liquidGlassRimVisible: Bool
    let liquidGlassSpecularVisible: Bool
    let centerLineVisible: Bool
    let scoreVisible: Bool
}
