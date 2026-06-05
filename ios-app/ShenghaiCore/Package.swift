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
        )
    ],
    targets: [
        .target(name: "ShenghaiCore"),
        .testTarget(
            name: "ShenghaiCoreTests",
            dependencies: ["ShenghaiCore"]
        )
    ]
)
