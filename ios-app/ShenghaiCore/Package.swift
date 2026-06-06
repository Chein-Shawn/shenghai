// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ShenghaiCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ShenghaiCore",
            targets: ["ShenghaiCore"]
        ),
        .executable(
            name: "ShenghaiApp",
            targets: ["ShenghaiApp"]
        )
    ],
    targets: [
        .target(name: "ShenghaiCore"),
        .executableTarget(
            name: "ShenghaiApp",
            dependencies: ["ShenghaiCore"]
        ),
        .testTarget(
            name: "ShenghaiCoreTests",
            dependencies: ["ShenghaiCore"]
        )
    ]
)
