// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "iGenticIPhone",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "AgentCore", targets: ["AgentCore"])
    ],
    targets: [
        .target(name: "AgentCore"),
        .testTarget(name: "AgentCoreTests", dependencies: ["AgentCore"])
    ]
)
