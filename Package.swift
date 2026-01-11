// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RuntimePilot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "RuntimePilot", targets: ["RuntimePilot"])
    ],
    targets: [
        .executableTarget(
            name: "RuntimePilot",
            path: "Sources/RuntimePilot",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
