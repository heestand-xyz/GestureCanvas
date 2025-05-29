// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GestureCanvas",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "GestureCanvas",
            targets: ["GestureCanvas"]),
    ],
    dependencies: [
        .package(url: "https://github.com/heestand-xyz/CoreGraphicsExtensions", from: "2.0.1"),
        .package(url: "https://github.com/heestand-xyz/DisplayLink", from: "2.0.1"),
    ],
    targets: [
        .target(
            name: "GestureCanvas",
            dependencies: [
                "CoreGraphicsExtensions",
                "DisplayLink",
            ]),
    ]
)
