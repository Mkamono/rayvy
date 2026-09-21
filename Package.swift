// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Rayvy",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Pinned below 1.16.0: newer releases use the `#Preview` macro in Recorder.swift, which
        // requires the PreviewsMacros plugin that only ships inside Xcode.app. This project
        // targets plain Command Line Tools + `swift build`, which cannot resolve that macro.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", .upToNextMinor(from: "1.15.0")),
        .package(url: "https://github.com/LebJe/TOMLKit", from: "0.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Rayvy",
            dependencies: [
                "KeyboardShortcuts",
                "TOMLKit"
            ]
        ),
        .testTarget(
            name: "RayvyTests",
            dependencies: ["Rayvy"]
        )
    ]
)
