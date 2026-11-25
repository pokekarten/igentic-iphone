// swift-tools-version: 6.2
import PackageDescription

// Mac-only integration fixture. It links the Debug app module so the test
// exercises the real review logic without adding an entry point to the app.
let package = Package(
    name: "NativeRelaySmoke",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../../../ios")],
    targets: [
        .executableTarget(name: "NativeRelaySmoke",
                          dependencies: [.product(name: "iGenticApp", package: "ios")],
                          path: ".", sources: ["NativeRelayClaimSmoke.swift"])
    ]
)
