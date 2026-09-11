// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WindowLayout",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WindowLayout",
            path: "Sources/WindowLayout"
        )
    ]
)
