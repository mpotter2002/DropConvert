// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DropConvert",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "DropConvertCore",
            path: "Sources/DropConvertCore"
        ),
        .executableTarget(
            name: "DropConvert",
            dependencies: ["DropConvertCore"],
            path: "Sources/DropConvert",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "DropConvertMCP",
            dependencies: ["DropConvertCore"],
            path: "Sources/DropConvertMCP"
        )
    ]
)
