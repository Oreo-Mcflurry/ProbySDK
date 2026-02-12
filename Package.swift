// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PorbySDK",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "PorbySDK",
            targets: ["PorbySDK"]
        ),
    ],
    targets: [
        .target(
            name: "PorbySDK"
        ),
        .testTarget(
            name: "PorbySDKTests",
            dependencies: ["PorbySDK"]
        ),
    ]
)
