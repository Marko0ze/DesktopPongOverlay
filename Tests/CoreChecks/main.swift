import CoreGraphics
import Foundation

private var checkCount = 0

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fatalError("Core check failed: \(message)")
    }
    checkCount += 1
}

private func checkLargeDeltaClamping() {
    let settings = PongSettings.default
    var state = PongGameState(playfieldSize: CGSize(width: 1_000, height: 700), settings: settings)
    let start = state.ballPosition
    state.update(deltaTime: 10, input: InputSnapshot(), settings: settings, randomUnit: { 0.5 })
    expect(abs(state.ballPosition.x - start.x) < 40, "large delta should be clamped on x")
    expect(abs(state.ballPosition.y - start.y) < 40, "large delta should be clamped on y")
}

private func checkTopEdgeBounce() {
    let settings = PongSettings.default
    var state = PongGameState(playfieldSize: CGSize(width: 1_000, height: 700), settings: settings)
    state.ballPosition = CGPoint(x: 500, y: 695)
    state.ballVelocity = CGVector(dx: 100, dy: 300)
    state.update(deltaTime: 1.0 / 30.0, input: InputSnapshot(), settings: settings, randomUnit: { 0.5 })
    expect(state.ballVelocity.dy < 0, "top collision should reverse vertical velocity")
    expect(state.ballPosition.y <= 693, "ball should be placed inside the top boundary")
}

private func checkScoring() {
    let settings = PongSettings.default
    var state = PongGameState(playfieldSize: CGSize(width: 1_000, height: 700), settings: settings)
    state.ballPosition = CGPoint(x: -20, y: 20)
    state.ballVelocity = CGVector(dx: -500, dy: 0)
    state.update(deltaTime: 1.0 / 30.0, input: InputSnapshot(), settings: settings, randomUnit: { 0.5 })
    expect(state.rightScore == 1, "right score should increment when ball exits left")
    expect(state.ballPosition == CGPoint(x: 500, y: 350), "ball should reset to centre after a point")

    state.ballPosition = CGPoint(x: 1_020, y: 20)
    state.ballVelocity = CGVector(dx: 500, dy: 0)
    state.update(deltaTime: 1.0 / 30.0, input: InputSnapshot(), settings: settings, randomUnit: { 0.5 })
    expect(state.leftScore == 1, "left score should increment when ball exits right")

    state.resetScores(settings: settings)
    expect(state.leftScore == 0 && state.rightScore == 0, "reset should clear both scores")
}

private func checkSweptPaddleCollision() {
    var settings = PongSettings.default
    settings.paddleHeight = 130
    settings.paddleWidth = 16
    var state = PongGameState(playfieldSize: CGSize(width: 1_000, height: 700), settings: settings)
    state.leftPaddleY = 350
    state.ballPosition = CGPoint(x: 60, y: 350)
    state.ballVelocity = CGVector(dx: -1_000, dy: 0)
    state.update(deltaTime: 1.0 / 30.0, input: InputSnapshot(), settings: settings, randomUnit: { 0.5 })
    expect(state.ballVelocity.dx > 0, "left paddle collision should reverse horizontal velocity")
    expect(state.impactSequence == 1, "paddle collision should record one impact")
    expect(state.lastImpactSide == .left, "impact should record the left side")

    state.ballPosition = CGPoint(x: 60, y: 350)
    state.ballVelocity = CGVector(dx: -2_000, dy: 0)
    state.update(deltaTime: 1.0 / 30.0, input: InputSnapshot(), settings: settings, randomUnit: { 0.5 })
    expect(hypot(state.ballVelocity.dx, state.ballVelocity.dy) <= 1_200.1, "paddle bounce should respect the configured maximum speed")
}

private func checkResizeAndSettingsClamping() {
    var settings = PongSettings.default
    var state = PongGameState(playfieldSize: CGSize(width: 1_200, height: 800), settings: settings)
    state.ballPosition = CGPoint(x: 1_100, y: 700)
    state.leftPaddleY = 760
    state.resize(to: CGSize(width: 600, height: 400), settings: settings)
    expect((0 ... 600).contains(state.ballPosition.x), "resized ball x should remain in bounds")
    expect((0 ... 400).contains(state.ballPosition.y), "resized ball y should remain in bounds")
    expect(state.leftPaddleY <= 335, "resized paddle should remain in bounds")

    settings.ballSize = 1_000
    settings.aiSkill = -1
    settings.objectOpacity = 2
    settings.clamp()
    expect(settings.ballSize == 36, "ball size should clamp to its maximum")
    expect(settings.aiSkill == 0, "AI skill should clamp to zero")
    expect(settings.objectOpacity == 1, "opacity should clamp to one")
}

private func checkSpeedMapping() {
    expect(PongGameState.initialBallSpeed(for: 0) == 250, "minimum initial speed should be 250")
    expect(PongGameState.initialBallSpeed(for: 0.5) == 420, "default initial speed should be 420")
    expect(PongGameState.initialBallSpeed(for: 1) == 900, "maximum initial speed should be 900")
    expect(PongGameState.maximumBallSpeed(for: 0) == 600, "minimum speed cap should be 600")
    expect(PongGameState.maximumBallSpeed(for: 0.5) == 1_200, "default speed cap should be 1200")
    expect(PongGameState.maximumBallSpeed(for: 1) == 1_600, "maximum speed cap should be 1600")
}

private func checkPlayableDefaults() {
    expect(PongSettings.default.mode == .playerVsAI, "default mode should be playable with controls")
}

private func checkControlModes() {
    var settings = PongSettings.default
    let field = CGSize(width: 1_000, height: 700)

    settings.mode = .twoPlayer
    settings.controlBindings.leftUp = KeyBinding(keyCode: 0, label: "A")
    settings.controlBindings.leftDown = KeyBinding(keyCode: 2, label: "D")
    settings.controlBindings.rightUp = KeyBinding(keyCode: 14, label: "E")
    settings.controlBindings.rightDown = KeyBinding(keyCode: 15, label: "R")
    var twoPlayer = PongGameState(playfieldSize: field, settings: settings)
    let twoPlayerLeftStart = twoPlayer.leftPaddleY
    let twoPlayerRightStart = twoPlayer.rightPaddleY
    twoPlayer.update(
        deltaTime: 1.0 / 30.0,
        input: InputSnapshot(leftAxis: 1, rightAxis: -1),
        settings: settings,
        randomUnit: { 0.5 }
    )
    expect(twoPlayer.leftPaddleY > twoPlayerLeftStart, "remapped left-up input should move the left paddle up")
    expect(twoPlayer.rightPaddleY < twoPlayerRightStart, "remapped right-down input should move the right paddle down")

    settings.mode = .playerVsAI
    settings.controlBindings = .default
    var playerVsAI = PongGameState(playfieldSize: field, settings: settings)
    let playerStart = playerVsAI.leftPaddleY
    playerVsAI.update(
        deltaTime: 1.0 / 30.0,
        input: InputSnapshot(mouseY: 600),
        settings: settings,
        randomUnit: { 0.5 }
    )
    expect(playerVsAI.leftPaddleY > playerStart, "captured mouse position should move the player paddle")

    let keyboardStart = playerVsAI.leftPaddleY
    playerVsAI.update(
        deltaTime: 1.0 / 30.0,
        input: InputSnapshot(leftAxis: -1, mouseY: 600),
        settings: settings,
        randomUnit: { 0.5 }
    )
    expect(playerVsAI.leftPaddleY < keyboardStart, "W/S keyboard input should override stale mouse position")

    let arrowKeyStart = playerVsAI.leftPaddleY
    playerVsAI.update(
        deltaTime: 1.0 / 30.0,
        input: InputSnapshot(rightAxis: 1),
        settings: settings,
        randomUnit: { 0.5 }
    )
    expect(playerVsAI.leftPaddleY > arrowKeyStart, "Up arrow input should move the player paddle in Player vs AI")

    settings.playerControlMode = .mouseOnly
    let mouseOnlyStart = playerVsAI.leftPaddleY
    playerVsAI.update(
        deltaTime: 1.0 / 30.0,
        input: InputSnapshot(leftAxis: -1, mouseY: 650),
        settings: settings,
        randomUnit: { 0.5 }
    )
    expect(playerVsAI.leftPaddleY > mouseOnlyStart, "mouse-only control should ignore keyboard axis and follow mouse")

    settings.playerControlMode = .keyboardOnly
    let keyboardOnlyStart = playerVsAI.leftPaddleY
    playerVsAI.update(
        deltaTime: 1.0 / 30.0,
        input: InputSnapshot(leftAxis: -1, mouseY: 650),
        settings: settings,
        randomUnit: { 0.5 }
    )
    expect(playerVsAI.leftPaddleY < keyboardOnlyStart, "keyboard-only control should ignore stale mouse position")

    settings.mode = .demo
    var demo = PongGameState(playfieldSize: field, settings: settings)
    demo.ballPosition.y = 600
    let demoLeftStart = demo.leftPaddleY
    let demoRightStart = demo.rightPaddleY
    demo.update(deltaTime: 1.0 / 30.0, input: InputSnapshot(), settings: settings, randomUnit: { 0.5 })
    expect(demo.leftPaddleY > demoLeftStart && demo.rightPaddleY > demoRightStart, "demo mode should drive both paddles with AI")
}

private func checkAIDifficultyChangesBehavior() {
    let field = CGSize(width: 1_000, height: 700)
    var easySettings = PongSettings.default
    easySettings.mode = .playerVsAI
    easySettings.aiSkill = 0.1
    var hardSettings = easySettings
    hardSettings.aiSkill = 0.9

    var easy = PongGameState(playfieldSize: field, settings: easySettings)
    var hard = PongGameState(playfieldSize: field, settings: hardSettings)
    easy.ballPosition.y = 640
    hard.ballPosition.y = 640
    let start = easy.rightPaddleY

    easy.update(deltaTime: 1.0 / 30.0, input: InputSnapshot(), settings: easySettings, randomUnit: { 0.5 })
    hard.update(deltaTime: 1.0 / 30.0, input: InputSnapshot(), settings: hardSettings, randomUnit: { 0.5 })

    let easyMovement = abs(easy.rightPaddleY - start)
    let hardMovement = abs(hard.rightPaddleY - start)
    expect(hardMovement > easyMovement, "higher AI skill should react faster than easy AI")

    let verticalVelocities = stride(from: -520.0, through: 520.0, by: 80.0).map { CGFloat($0) }
    let easyReturns = verticalVelocities.filter {
        rightAIReturnsBall(skill: 0.15, verticalVelocity: $0, randomUnit: 1)
    }.count
    let hardReturns = verticalVelocities.filter {
        rightAIReturnsBall(skill: 0.85, verticalVelocity: $0, randomUnit: 0.5)
    }.count
    expect(easyReturns < verticalVelocities.count, "easy AI should miss at least one representative shot")
    expect(hardReturns > easyReturns, "hard AI should return more representative shots than easy AI")
}

private func checkAIStableTargetMemory() {
    var settings = PongSettings.default
    settings.mode = .playerVsAI
    settings.aiSkill = 0.15
    settings.paddleHeight = 130

    var state = PongGameState(playfieldSize: CGSize(width: 1_000, height: 700), settings: settings)
    state.ballPosition = CGPoint(x: 500, y: 350)
    state.ballVelocity = CGVector(dx: 420, dy: 0)

    let randomValues = [1.0, 1.0, 0.0, 0.0]
    var randomIndex = 0
    var positions = [state.rightPaddleY]

    for _ in 0 ..< 12 {
        state.update(
            deltaTime: 1.0 / 120.0,
            input: InputSnapshot(),
            settings: settings,
            randomUnit: {
                defer { randomIndex += 1 }
                return randomValues[randomIndex % randomValues.count]
            }
        )
        positions.append(state.rightPaddleY)
    }

    let deltas = zip(positions, positions.dropFirst()).map { $1 - $0 }
    expect(positions.last! > positions.first!, "AI should move toward its stable target")
    expect(deltas.allSatisfy { $0 >= -0.001 }, "AI should not reverse direction inside one target window")
    expect(randomIndex == 2, "AI should only randomize once inside the short target window")
}

private func rightAIReturnsBall(skill: Double, verticalVelocity: CGFloat, randomUnit: Double) -> Bool {
    var settings = PongSettings.default
    settings.mode = .playerVsAI
    settings.aiSkill = skill
    var state = PongGameState(playfieldSize: CGSize(width: 1_000, height: 700), settings: settings)
    state.ballPosition = CGPoint(x: 500, y: 350)
    state.ballVelocity = CGVector(dx: 420, dy: verticalVelocity)

    for _ in 0 ..< 1_200 {
        state.update(
            deltaTime: 1.0 / 120.0,
            input: InputSnapshot(),
            settings: settings,
            randomUnit: { randomUnit }
        )
        if state.lastImpactSide == .right { return true }
        if state.leftScore > 0 { return false }
    }
    return false
}

private func checkSettingsPersistence() {
    MainActor.assumeIsolated {
        let suiteName = "DesktopPongCoreChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstStore = SettingsStore(defaults: defaults)
        firstStore.settings.mode = .twoPlayer
        firstStore.settings.aiSkill = 0.82
        firstStore.settings.materialStyle = .frosted
        firstStore.settings.glassQuality = .balanced
        firstStore.settings.paddleGlassFill = .transparent
        firstStore.settings.controlBindings.leftUp = KeyBinding(keyCode: 0, label: "A")

        let restoredStore = SettingsStore(defaults: defaults)
        expect(restoredStore.settings.mode == .twoPlayer, "game mode should survive relaunch")
        expect(restoredStore.settings.aiSkill == 0.82, "AI skill should survive relaunch")
        expect(restoredStore.settings.materialStyle == .frosted, "material style should survive relaunch")
        expect(restoredStore.settings.glassQuality == .balanced, "glass quality should survive relaunch")
        expect(restoredStore.settings.paddleGlassFill == .transparent, "transparent paddle fill should survive relaunch")
        expect(restoredStore.settings.controlBindings.leftUp.keyCode == 0, "custom control binding should survive relaunch")

        restoredStore.resetToDefaults()
        expect(restoredStore.settings == .default, "Reset to Defaults should restore every setting")
    }
}

private func checkControlBindingConflicts() {
    var bindings = ControlBindings.default
    expect(!bindings.hasDuplicateGameplayKeys, "default gameplay controls should be unique")
    bindings.leftUp = bindings.leftDown
    expect(bindings.hasDuplicateGameplayKeys, "duplicate gameplay controls should be detected")
}

checkLargeDeltaClamping()
checkTopEdgeBounce()
checkScoring()
checkSweptPaddleCollision()
checkResizeAndSettingsClamping()
checkSpeedMapping()
checkPlayableDefaults()
checkControlModes()
checkAIDifficultyChangesBehavior()
checkAIStableTargetMemory()
checkSettingsPersistence()
checkControlBindingConflicts()
print("Core checks passed (\(checkCount) assertions)")
