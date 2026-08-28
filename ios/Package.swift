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
        .library(name: "iGenticApp", targets: ["iGenticApp"]),
        .executable(name: "AppleFoundationBaselineHost", targets: ["AppleFoundationBaselineHost"])
    ],
    targets: [
        .target(name: "AgentCore"),
        .target(
            name: "iGenticApp",
            dependencies: ["AgentCore"],
            resources: [.process("Resources")]
        ),
        .target(name: "ModelResearchSupport"),
        .executableTarget(
            name: "AppleFoundationBaselineHost",
            dependencies: ["ModelResearchSupport"]
        ),
        .testTarget(name: "AgentCoreTests", dependencies: ["AgentCore"]),
        .testTarget(name: "iGenticAppTests", dependencies: ["iGenticApp", "AgentCore"]),
        .testTarget(name: "ModelResearchSupportTests", dependencies: ["ModelResearchSupport"])
    ]
)
