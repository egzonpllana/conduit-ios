// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Conduit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Conduit",
            targets: ["Conduit"]
        )
    ],
    targets: [
        .target(
            name: "Conduit",
            path: "Sources/Conduit"
        ),
        .testTarget(
            name: "ConduitTests",
            dependencies: ["Conduit"],
            path: "Tests/ConduitTests"
        )
    ]
)
