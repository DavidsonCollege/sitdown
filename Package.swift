// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Luxicon",
    platforms: [
        .macOS("15.0"),
        .iOS("18.0"),
    ],
    products: [
        .library(name: "LuxiconKit", targets: ["LuxiconKit"]),
        .executable(name: "luxicon-cli", targets: ["LuxiconCLI"]),
        .executable(name: "luxicon-mcp", targets: ["LuxiconMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/soniqo/speech-swift.git", from: "0.0.21"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.0"),
    ],
    targets: [
        .target(
            name: "LuxiconKit",
            dependencies: [
                .product(name: "SpeechVAD", package: "speech-swift"),
                .product(name: "ParakeetASR", package: "speech-swift"),
                .product(name: "ParakeetStreamingASR", package: "speech-swift"),
                .product(name: "Qwen3ASR", package: "speech-swift"),
                .product(name: "Qwen3Chat", package: "speech-swift"),
                .product(name: "AudioCommon", package: "speech-swift"),
            ]
        ),
        .executableTarget(
            name: "LuxiconCLI",
            dependencies: ["LuxiconKit"]
        ),
        .executableTarget(
            name: "LuxiconMCP",
            dependencies: [
                "LuxiconKit",
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
        .testTarget(
            name: "LuxiconKitTests",
            dependencies: ["LuxiconKit"]
        ),
    ]
)
