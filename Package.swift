// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DropConvert",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DropConvert",
            path: "Sources/DropConvert",
            resources: [.process("Resources")]
        )
    ]
)
