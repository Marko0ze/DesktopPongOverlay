# Keyboard playtest log

Date: 2026-06-24
App tested: `/Users/marcustossmann/Documents/PingPong/dist/DesktopPongOverlay.app`
Tester: Codex using Computer Use plus local command-line observation

## Steps and observations

1. Launched the packaged app from `dist/DesktopPongOverlay.app`.
   - Result: App launched.
   - Initial visible state: Settings window was open on Gameplay.
   - Gameplay mode shown: Player vs AI.

2. Closed Settings.
   - Result: Desktop overlay became visible.
   - Visible game elements: left paddle, right paddle, ball, score.

3. Opened the app's Game menu.
   - Result: Menu opened.
   - Visible command: Capture Input.

4. Selected Capture Input.
   - Result: Overlay remained visible and focused on the SpriteKit game surface.

5. Pressed Down arrow using Computer Use.
   - Result: A single tap did not produce obvious visible paddle movement.
   - Note: This tool sends tap-style key events, not a held key.

6. Pressed Down arrow several more times using Computer Use.
   - Result: Left paddle still appeared visually pinned near the top.
   - Ball and score continued changing, so the game itself was running.

7. Pressed `S` using Computer Use.
   - Result: A single tap did not produce obvious visible paddle movement.

8. Opened Settings with Command-comma.
   - Result: Settings opened successfully.

9. Opened the Controls tab.
   - Result: Control settings were visible and correct:
     - Player Control: Keyboard Only
     - Player Paddle Up: ↑
     - Player Paddle Down: ↓
     - Second Paddle Up: W
     - Second Paddle Down: S

10. Closed Settings and enabled Capture Input again.
    - Result: Overlay returned and Capture Input could be re-enabled.

11. Attempted to synthesize a held Down-arrow key for one second with a tiny local CoreGraphics helper.
    - Result: The helper hung while trying to post system input events from the current automation environment and was interrupted.

## Conclusion

Configuration is correct: the player paddle is assigned to Up/Down arrows, and Player Control is set to Keyboard Only.

The visible playtest was inconclusive for actual held-key movement because the available UI automation could only tap keys, and the local synthetic hold path was blocked/hung in this environment.

Likely user-facing guidance: hold ↑ or ↓ while Capture Input is enabled. Tapping may be too brief to show movement. If physical held keys still do not move the paddle, the next fix should add an in-app input debug overlay or visible key-state indicator so we can distinguish "key not delivered" from "key delivered but movement too subtle/snaps back."

## Follow-up after physical-key failure report

User confirmed physical key taps and holds do not work.

Follow-up build added a visible input status label and a temporary, gameplay-key filtered macOS Accessibility keyboard tap while Capture Input is enabled.

Observed status after enabling Capture Input in the fresh build:

- `Capture ON · allow Accessibility for keyboard · no key`

Interpretation: macOS is blocking keyboard observation for this app until Desktop Pong Overlay is granted Accessibility access in System Settings. This explains why physical held ↑/↓ keys were not moving the paddle.
