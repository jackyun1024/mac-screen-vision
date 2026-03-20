// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "screen-vision",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "ScreenVisionLib",
            path: "Sources/ScreenVisionLib"
        ),
        .executableTarget(
            name: "screen-vision",
            dependencies: ["ScreenVisionLib"],
            path: "Sources/screen-vision"
        ),
        .testTarget(
            name: "ScreenVisionTests",
            dependencies: ["ScreenVisionLib"],
            path: "Tests/ScreenVisionTests"
        )
    ]
)
