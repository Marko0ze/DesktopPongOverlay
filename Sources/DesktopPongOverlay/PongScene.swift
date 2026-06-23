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
    private let centerLine = SKShapeNode()
    private let centerLineShadow = SKShapeNode()
    private let leftScore = SKLabelNode(fontNamed: "SFMono-Semibold")
    private let rightScore = SKLabelNode(fontNamed: "SFMono-Semibold")
    private let leftScoreShadow = SKLabelNode(fontNamed: "SFMono-Semibold")
    private let rightScoreShadow = SKLabelNode(fontNamed: "SFMono-Semibold")

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
            input: inputMonitor.snapshot(screenOriginY: screenOriginY),
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
            ballVisible: !ball.isHidden && ball.parent === self,
            paddlesVisible: !leftPaddle.isHidden && !rightPaddle.isHidden,
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
        [centerLineShadow, centerLine, leftPaddle, rightPaddle, ball, leftScoreShadow, rightScoreShadow, leftScore, rightScore].forEach(addChild)
        centerLineShadow.zPosition = -0.1
        centerLine.zPosition = 0
        leftPaddle.zPosition = 2
        rightPaddle.zPosition = 2
        ball.zPosition = 3
        leftScore.zPosition = 2
        rightScore.zPosition = 2
        leftScoreShadow.zPosition = 1.9
        rightScoreShadow.zPosition = 1.9
        [leftScore, rightScore, leftScoreShadow, rightScoreShadow].forEach {
            $0.horizontalAlignmentMode = .center
            $0.verticalAlignmentMode = .top
        }
    }

    private func applySettings() {
        let settings = settingsStore.settings
        let paddleSize = CGSize(width: settings.paddleWidth, height: settings.paddleHeight)
        let cornerRadius = min(paddleSize.width / 2, paddleSize.width * settings.paddleRoundness / 2)

        leftPaddle.path = CGPath(
            roundedRect: CGRect(origin: CGPoint(x: -paddleSize.width / 2, y: -paddleSize.height / 2), size: paddleSize),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        rightPaddle.path = leftPaddle.path
        ball.path = CGPath(
            ellipseIn: CGRect(
                x: -settings.ballSize / 2,
                y: -settings.ballSize / 2,
                width: settings.ballSize,
                height: settings.ballSize
            ),
            transform: nil
        )

        style(leftPaddle, color: settings.playerPaddleColor.nsColor, settings: settings)
        style(rightPaddle, color: settings.aiPaddleColor.nsColor, settings: settings)
        style(ball, color: settings.ballColor.nsColor, settings: settings)

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

    private func style(_ node: SKShapeNode, color: NSColor, settings: PongSettings) {
        let opacity = CGFloat(settings.objectOpacity)
        switch settings.materialStyle {
        case .glass:
            node.fillColor = color.withAlphaComponent(opacity * 0.62)
            node.strokeColor = NSColor.white.withAlphaComponent(opacity * 0.85)
            node.lineWidth = 1.5
            node.glowWidth = settings.glowStrength * 12
        case .clear:
            node.fillColor = color.withAlphaComponent(opacity)
            node.strokeColor = .clear
            node.lineWidth = 0
            node.glowWidth = 0
        case .frosted:
            node.fillColor = color.withAlphaComponent(opacity * 0.72)
            node.strokeColor = color.blended(withFraction: 0.55, of: .white)?.withAlphaComponent(opacity * 0.6) ?? color
            node.lineWidth = 1
            node.glowWidth = settings.glowStrength * 7
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
        leftScore.text = String(gameState.leftScore)
        rightScore.text = String(gameState.rightScore)
        leftScoreShadow.text = leftScore.text
        rightScoreShadow.text = rightScore.text
        leftScore.position = CGPoint(x: size.width / 2 - 48, y: size.height - 28)
        rightScore.position = CGPoint(x: size.width / 2 + 48, y: size.height - 28)
        leftScoreShadow.position = CGPoint(x: leftScore.position.x + 1.5, y: leftScore.position.y - 1.5)
        rightScoreShadow.position = CGPoint(x: rightScore.position.x + 1.5, y: rightScore.position.y - 1.5)
    }

    private func playImpactIfNeeded() {
        guard gameState.impactSequence != renderedImpactSequence else { return }
        renderedImpactSequence = gameState.impactSequence
        let settings = settingsStore.settings
        let shouldReduceMotion = settings.reducedMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard !shouldReduceMotion, settings.impactPreset != .off else { return }
        onImpact?()

        let paddle = gameState.lastImpactSide == .left ? leftPaddle : rightPaddle
        let amount = settings.impactPreset.scale
        paddle.removeAction(forKey: "impactSquish")
        paddle.setScale(1)
        let squish = SKAction.scaleX(to: 1 + amount, y: 1 - amount * 0.48, duration: 0.045)
        squish.timingMode = .easeOut
        let restore = SKAction.scale(to: 1, duration: 0.10)
        restore.timingMode = .easeOut
        paddle.run(.sequence([squish, restore]), withKey: "impactSquish")
        spawnRipple(at: CGPoint(x: paddle.position.x, y: gameState.ballPosition.y), strength: amount)
    }

    private func spawnRipple(at position: CGPoint, strength: CGFloat) {
        let ripple = SKShapeNode(circleOfRadius: 8)
        ripple.position = position
        ripple.zPosition = 1
        ripple.fillColor = .clear
        ripple.strokeColor = NSColor.white.withAlphaComponent(0.55)
        ripple.lineWidth = 1.5
        addChild(ripple)
        ripple.run(.sequence([
            .group([
                .scale(to: 2.2 + strength * 3, duration: 0.14),
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
    let ballVisible: Bool
    let paddlesVisible: Bool
    let centerLineVisible: Bool
    let scoreVisible: Bool
}
