// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "iGenticIPhone",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "AgentCore", targets: ["AgentCore"]),
        .library(name: "iGenticApp", targets: ["iGenticApp"])
    ],
    targets: [
        .target(name: "AgentCore"),
        .target(name: "iGenticApp", dependencies: ["AgentCore"]),
        .testTarget(name: "AgentCoreTests", dependencies: ["AgentCore"]),
        .testTarget(name: "iGenticAppTests", dependencies: ["iGenticApp", "AgentCore"])
    ]
)
