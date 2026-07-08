// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VocalDiveCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VocalDiveCore",
            targets: ["VocalDiveCore"]
        ),
        .executable(
            name: "VocalDiveApp",
            targets: ["VocalDiveApp"]
        )
    ],
    targets: [
        .target(name: "VocalDiveCore"),
        .executableTarget(
            name: "VocalDiveApp",
            dependencies: ["VocalDiveCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "VocalDiveCoreTests",
            dependencies: ["VocalDiveCore"]
        )
    ]
)
