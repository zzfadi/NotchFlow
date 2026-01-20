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
        // Swift 6.2 Subprocess for external process execution
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.0.1")
    ],
    targets: [
        .executableTarget(
            name: "NotchFlow",
            dependencies: [
                "DynamicNotchKit",
                .product(name: "Subprocess", package: "swift-subprocess")
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

