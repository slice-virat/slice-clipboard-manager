// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipboardManager",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ClipCore"),
        .executableTarget(name: "ClipTests", dependencies: ["ClipCore"]),
        .executableTarget(name: "ClipboardManager", dependencies: ["ClipCore"]),
    ],
    swiftLanguageModes: [.v6]
)
