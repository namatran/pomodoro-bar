// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1")
    ],
    targets: [
        .executableTarget(
            name: "Pomodoro",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Pomodoro"
        )
    ]
)
