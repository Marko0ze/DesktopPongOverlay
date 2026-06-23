# Desktop Pong Overlay

A native, transparent Pong game for macOS Tahoe. The app uses AppKit for its borderless floating panel, SpriteKit for rendering, SwiftUI for settings, and no private APIs or copied Screen Tennis assets.

## Run

```sh
./script/build_and_run.sh --verify
```

Focused game-state checks:

```sh
./script/run_core_checks.sh
```

Native runtime acceptance harness:

```sh
./script/build_runtime_checks.sh
```

The menu-bar item controls the app. Left-click it to toggle the active game surface; right-click or Control-click it for controls.
Pass-through is enabled by default in Desktop Overlay mode, so apps underneath remain interactive.
The app runs as a menu-bar utility with no Dock icon.

The run script also applies a narrow compatibility flag for the Swift/SDK patch-version mismatch in the macOS 26.5.1 Command Line Tools currently installed on this machine. It can be removed after installing a matching Xcode 26 toolchain.
The staged app contains both arm64 and x86_64 slices.

## Controls

- Demo mode: AI plays both paddles.
- Player vs AI: choose **Capture Input**, then use the configured keyboard controls or mouse.
- Two Player: choose **Capture Input**; each paddle uses its configured up/down keys.
- Settings → Controls lets you remap left paddle, right paddle, and the global toggle key.
- Presentation: choose **Desktop Overlay** for full-screen transparent Pong, or **Menu Bar Game** for a compact popover game from the menu-bar icon.
- Global shortcut: Option-Command plus the configured global toggle key opens the active game surface from anywhere.
- In Menu Bar Game mode, click the popover to pause/resume.
- Menu shortcuts: Command-H show/hide, Command-P pause/resume, Command-R reset, Command-I capture input, Command-, settings, Command-Q quit.

## Appearance

- Settings → Appearance controls Liquid Glass, Clear, and Frosted modes.
- Liquid Glass uses native SpriteKit layers for object-local depth, rim light, glow, and specular highlights.
- Paddle Fill can be switched to **Transparent** to keep the paddle bodies clear while retaining coloured rim/glow/specular cues.
- The app does not sample the desktop for live refraction, preserving the no-screen-recording privacy model.
- Reference provenance is tracked in `docs/reference-provenance.md`; external repositories were used as inspiration only.

## Privacy

The app does not record the screen, take screenshots, use the network, collect analytics, or install global input monitors. Keyboard and mouse events are read locally only while **Capture Input** is explicitly enabled.
The global shortcut is registered with macOS as a hotkey; it does not inspect typed text.

## Packaging

Local test DMG:

```sh
./script/build_and_run.sh --build
./script/package_dmg.sh --local
./script/release_preflight.sh --local
```

Developer ID signed DMG, once a Developer ID Application certificate is installed:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" ./script/package_dmg.sh --developer-id
```

Notarized distribution DMG, once notary credentials are configured:

```sh
APPLE_ID="you@example.com" APPLE_TEAM_ID="TEAMID" ./script/store_notary_profile.sh desktop-pong-notary

NOTARYTOOL_PROFILE="desktop-pong-notary" \
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
./script/package_dmg.sh --notarize
```

Distribution prerequisite audit:

```sh
./script/release_preflight.sh --distribution
```

Current machine status: local ad-hoc packaging works, but public distribution still requires a valid Developer ID Application certificate and notary credentials. The project does not invent or silently use signing credentials.
