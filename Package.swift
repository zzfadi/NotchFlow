// swift-tools-version: 5.9
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
        .package(path: "Packages/DynamicNotchKit")
    ],
    targets: [
        .executableTarget(
            name: "NotchFlow",
            dependencies: ["DynamicNotchKit"],
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
