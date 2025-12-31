// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DevManager",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DevManager", targets: ["DevManager"])
    ],
    targets: [
        .executableTarget(
            name: "DevManager",
            path: "Sources/DevManager"
        )
    ]
)
