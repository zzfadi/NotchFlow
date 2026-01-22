// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NotchFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NotchFlow", targets: ["NotchFlow"])
    ],
    dependencies: [
        // Use local fork to support larger window sizes
        .package(path: "Packages/DynamicNotchKit"),
        // CodexBar plugin for AI usage tracking
        .package(path: "External/CodexBar"),
        // Swift 6.2 Subprocess for external process execution
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.0.1"),
        // Markdown rendering for rich content display
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
        // Syntax highlighting for code blocks (JSON, YAML, etc.)
        .package(url: "https://github.com/appstefan/HighlightSwift", from: "1.1.0")
    ],
    targets: [
        .executableTarget(
            name: "NotchFlow",
            dependencies: [
                "DynamicNotchKit",
                .product(name: "CodexBarNotchPlugin", package: "CodexBar"),
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                "HighlightSwift"
            ],
            path: "NotchFlow",
            exclude: [
                "Resources/Info.plist",
                "Resources/NotchFlow.entitlements"
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        )
    ]
)

