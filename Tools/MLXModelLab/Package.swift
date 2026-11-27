// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "MLXProbe", platforms: [.iOS("27.0")], products: [.library(name: "MLXProbe", targets: ["MLXProbe"])], dependencies: [
    .package(url: "https://github.com/ml-explore/mlx-swift-lm", revision: "026d599e52f3a2cebbecbd5b3f318b800a73ff02"),
    .package(path: "../../ios"),
    .package(url: "https://github.com/huggingface/swift-transformers", revision: "b38443e44d93eca770f2eb68e2a4d0fa100f9aa2"),
    .package(url: "https://github.com/huggingface/swift-huggingface", revision: "b721959445b617d0bf03910b2b4aced345fd93bf")
], targets: [.target(name: "MLXProbe", dependencies: [
    .product(name: "iGenticApp", package: "ios"), .product(name: "AgentCore", package: "ios"),
    .product(name: "MLXLLM", package: "mlx-swift-lm"), .product(name: "MLXLMCommon", package: "mlx-swift-lm"), .product(name: "MLXHuggingFace", package: "mlx-swift-lm"), .product(name: "Tokenizers", package: "swift-transformers"), .product(name: "HuggingFace", package: "swift-huggingface")])])
