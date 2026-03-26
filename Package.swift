// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "YAMP",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(url: "https://github.com/korenskoy/zvuk-swift.git", from: "0.2.0"),
        .package(url: "https://github.com/duhnnie/LastFM.swift", from: "1.6.1"),
    ],
    targets: [
        .executableTarget(
            name: "YAMP",
            dependencies: [
                .product(name: "ZvukMusic", package: "zvuk-swift"),
                .product(name: "LastFM", package: "LastFM.swift"),
            ],
            path: "Sources/YAMP",
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
