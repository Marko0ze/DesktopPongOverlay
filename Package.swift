// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DesktopPongOverlay",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "DesktopPongOverlay", targets: ["DesktopPongOverlay"])
    ],
    targets: [
        .executableTarget(name: "DesktopPongOverlay")
    ]
)
