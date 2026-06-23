import CoreGraphics
import Foundation

enum PaddleSide: Sendable {
    case left
    case right
}

struct InputSnapshot: Sendable {
    var leftAxis: CGFloat = 0
    var rightAxis: CGFloat = 0
    var mouseY: CGFloat?
}

struct PongGameState: Sendable {
    private(set) var playfieldSize: CGSize
    var ballPosition: CGPoint
    var ballVelocity: CGVector
    var leftPaddleY: CGFloat
    var rightPaddleY: CGFloat
    var leftScore = 0
    var rightScore = 0
    private(set) var impactSequence = 0
    private(set) var lastImpactSide: PaddleSide?

    init(playfieldSize: CGSize, settings: PongSettings = .default) {
        self.playfieldSize = playfieldSize
        ballPosition = CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2)
        ballVelocity = CGVector(dx: 0, dy: 0)
        leftPaddleY = playfieldSize.height / 2
        rightPaddleY = playfieldSize.height / 2
        resetBall(settings: settings, towardRight: true)
    }

    mutating func update(
        deltaTime: TimeInterval,
        input: InputSnapshot,
        settings: PongSettings,
        randomUnit: () -> Double = { Double.random(in: 0 ... 1) }
    ) {
        let dt = CGFloat(deltaTime.clamped(to: 0 ... (1.0 / 30.0)))
        guard dt > 0, playfieldSize.width > 100, playfieldSize.height > 100 else { return }

        updatePaddles(dt: dt, input: input, settings: settings, randomUnit: randomUnit)

        let previous = ballPosition
        ballPosition.x += ballVelocity.dx * dt
        ballPosition.y += ballVelocity.dy * dt

        let radius = CGFloat(settings.ballSize / 2)
        if ballPosition.y + radius > playfieldSize.height {
            ballPosition.y = playfieldSize.height - radius
            ballVelocity.dy = -abs(ballVelocity.dy)
        } else if ballPosition.y - radius < 0 {
            ballPosition.y = radius
            ballVelocity.dy = abs(ballVelocity.dy)
        }

        handlePaddleCollisions(previousPosition: previous, settings: settings)

        if ballPosition.x + radius < 0 {
            rightScore += 1
            resetBall(settings: settings, towardRight: true)
        } else if ballPosition.x - radius > playfieldSize.width {
            leftScore += 1
            resetBall(settings: settings, towardRight: false)
        }
    }

    mutating func resetScores(settings: PongSettings) {
        leftScore = 0
        rightScore = 0
        resetBall(settings: settings, towardRight: true)
    }

    mutating func resetBall(settings: PongSettings, towardRight: Bool) {
        ballPosition = CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2)
        let speed = Self.initialBallSpeed(for: settings.ballSpeed)
        let direction: CGFloat = towardRight ? 1 : -1
        ballVelocity = CGVector(dx: speed * direction, dy: speed * 0.32)
    }

    mutating func resize(to newSize: CGSize, settings: PongSettings) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        let oldSize = playfieldSize
        playfieldSize = newSize
        if oldSize.width > 0, oldSize.height > 0 {
            ballPosition.x = ballPosition.x / oldSize.width * newSize.width
            ballPosition.y = ballPosition.y / oldSize.height * newSize.height
            leftPaddleY = leftPaddleY / oldSize.height * newSize.height
            rightPaddleY = rightPaddleY / oldSize.height * newSize.height
        }
        clampObjects(settings: settings)
    }

    private mutating func updatePaddles(
        dt: CGFloat,
        input: InputSnapshot,
        settings: PongSettings,
        randomUnit: () -> Double
    ) {
        let playerSpeed: CGFloat = 650
        switch settings.mode {
        case .demo:
            moveAI(side: .left, dt: dt, settings: settings, randomUnit: randomUnit)
            moveAI(side: .right, dt: dt, settings: settings, randomUnit: randomUnit)
        case .playerVsAI:
            if let mouseY = input.mouseY {
                leftPaddleY = moveToward(
                    current: leftPaddleY,
                    target: mouseY,
                    maxDelta: playerSpeed * dt
                )
            } else {
                leftPaddleY += input.leftAxis * playerSpeed * dt
            }
            moveAI(side: .right, dt: dt, settings: settings, randomUnit: randomUnit)
        case .twoPlayer:
            leftPaddleY += input.leftAxis * playerSpeed * dt
            rightPaddleY += input.rightAxis * playerSpeed * dt
        }
        clampPaddles(settings: settings)
    }

    private mutating func moveAI(
        side: PaddleSide,
        dt: CGFloat,
        settings: PongSettings,
        randomUnit: () -> Double
    ) {
        let skill = CGFloat(settings.aiSkill)
        let noise = CGFloat(randomUnit() * 2 - 1) * (1 - skill) * 170
        let target = ballPosition.y + noise
        let maxSpeed = 300 + skill * 700
        switch side {
        case .left:
            leftPaddleY = moveToward(current: leftPaddleY, target: target, maxDelta: maxSpeed * dt)
        case .right:
            rightPaddleY = moveToward(current: rightPaddleY, target: target, maxDelta: maxSpeed * dt)
        }
    }

    private func moveToward(current: CGFloat, target: CGFloat, maxDelta: CGFloat) -> CGFloat {
        current + (target - current).clamped(to: -maxDelta ... maxDelta)
    }

    private mutating func handlePaddleCollisions(previousPosition: CGPoint, settings: PongSettings) {
        let radius = CGFloat(settings.ballSize / 2)
        let paddleHalfHeight = CGFloat(settings.paddleHeight / 2)
        let paddleHalfWidth = CGFloat(settings.paddleWidth / 2)
        let leftFace = 30 + paddleHalfWidth
        let rightFace = playfieldSize.width - 30 - paddleHalfWidth

        if ballVelocity.dx < 0,
           previousPosition.x - radius >= leftFace,
           ballPosition.x - radius <= leftFace,
           abs(ballPosition.y - leftPaddleY) <= paddleHalfHeight + radius {
            ballPosition.x = leftFace + radius
            bounceFromPaddle(side: .left, paddleY: leftPaddleY, settings: settings)
        } else if ballVelocity.dx > 0,
                  previousPosition.x + radius <= rightFace,
                  ballPosition.x + radius >= rightFace,
                  abs(ballPosition.y - rightPaddleY) <= paddleHalfHeight + radius {
            ballPosition.x = rightFace - radius
            bounceFromPaddle(side: .right, paddleY: rightPaddleY, settings: settings)
        }
    }

    private mutating func bounceFromPaddle(side: PaddleSide, paddleY: CGFloat, settings: PongSettings) {
        let currentSpeed = hypot(ballVelocity.dx, ballVelocity.dy)
        let speed = min(currentSpeed * 1.03, Self.maximumBallSpeed(for: settings.ballSpeed))
        let normalizedImpact = ((ballPosition.y - paddleY) / CGFloat(settings.paddleHeight / 2))
            .clamped(to: -1 ... 1)
        var verticalRatio = (normalizedImpact * 0.78).clamped(to: -0.82 ... 0.82)
        if abs(verticalRatio) < 0.12 {
            verticalRatio = 0.12 * (normalizedImpact < 0 ? -1 : 1)
        }
        let horizontalSpeed = speed * sqrt(1 - verticalRatio * verticalRatio)
        ballVelocity.dx = side == .left ? horizontalSpeed : -horizontalSpeed
        ballVelocity.dy = speed * verticalRatio
        impactSequence += 1
        lastImpactSide = side
    }

    private mutating func clampObjects(settings: PongSettings) {
        let radius = CGFloat(settings.ballSize / 2)
        ballPosition.x = ballPosition.x.clamped(to: radius ... max(radius, playfieldSize.width - radius))
        ballPosition.y = ballPosition.y.clamped(to: radius ... max(radius, playfieldSize.height - radius))
        clampPaddles(settings: settings)
    }

    private mutating func clampPaddles(settings: PongSettings) {
        let halfHeight = CGFloat(settings.paddleHeight / 2)
        let range = halfHeight ... max(halfHeight, playfieldSize.height - halfHeight)
        leftPaddleY = leftPaddleY.clamped(to: range)
        rightPaddleY = rightPaddleY.clamped(to: range)
    }

    static func initialBallSpeed(for sliderValue: Double) -> CGFloat {
        let value = sliderValue.clamped(to: 0 ... 1)
        if value <= 0.5 {
            return 250 + CGFloat(value / 0.5) * 170
        }
        return 420 + CGFloat((value - 0.5) / 0.5) * 480
    }

    static func maximumBallSpeed(for sliderValue: Double) -> CGFloat {
        let value = sliderValue.clamped(to: 0 ... 1)
        if value <= 0.5 {
            return 600 + CGFloat(value / 0.5) * 600
        }
        return 1_200 + CGFloat((value - 0.5) / 0.5) * 400
    }
}
