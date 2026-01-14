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
        .package(url: "https://github.com/MrKai77/DynamicNotchKit", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "NotchFlow",
            dependencies: ["DynamicNotchKit"],
            path: "NotchFlow"
        )
    ]
)
