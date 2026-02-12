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
    dependencies: [
        .package(url: "https://github.com/fumoboy007/msgpack-swift.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "PorbySDK",
            dependencies: [
                .product(name: "DMMessagePack", package: "msgpack-swift"),
            ]
        ),
        .testTarget(
            name: "PorbySDKTests",
            dependencies: ["PorbySDK"]
        ),
    ]
)
