// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "screen-vision",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "screen-vision",
            path: "Sources"
        )
    ]
)
