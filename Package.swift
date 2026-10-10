// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Launcher",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "Launcher", path: "Sources/Launcher")
    ],
    swiftLanguageModes: [.v5]
)
