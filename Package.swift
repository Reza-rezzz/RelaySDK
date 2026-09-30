// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RelaySDK",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "RelaySDK", targets: ["RelaySDK"])
    ],
    targets: [
        .target(
            name: "RelaySDK",
            path: "Sources/RelaySDK",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "RelaySDKTests",
            dependencies: ["RelaySDK"],
            path: "Tests/RelaySDKTests"
        )
    ]
)
