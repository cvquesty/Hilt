// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hilt",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "HiltCore", targets: ["HiltCore"]),
        .executable(name: "hilt", targets: ["hilt"])
    ],
    targets: [
        .target(
            name: "HiltCore",
            path: "Sources/HiltCore"
        ),
        .executableTarget(
            name: "hilt",
            dependencies: ["HiltCore"],
            path: "Sources/hilt"
        ),
        .testTarget(
            name: "HiltCoreTests",
            dependencies: ["HiltCore"],
            path: "Tests/HiltCoreTests"
        )
    ]
)
