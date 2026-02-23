// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "opus_codec_macos",
    platforms: [
        .macOS("10.14")
    ],
    products: [
        .library(name: "opus-codec-macos", targets: ["opus_codec_macos"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "opus_codec_macos",
            dependencies: [
                .target(name: "opus")
            ]
        ),
        .binaryTarget(
            name: "opus",
            path: "../opus.xcframework"
        )
    ]
)
