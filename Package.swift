// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProbySDK",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .watchOS(.v8),
    ],
    products: [
        .library(
            name: "ProbySDK",
            targets: ["ProbySDK"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/fumoboy007/msgpack-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "ProbySDK",
            dependencies: [
                .product(name: "DMMessagePack", package: "msgpack-swift"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "ProbySDKTests",
            dependencies: ["ProbySDK"]
        ),
    ]
)
