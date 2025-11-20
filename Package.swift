// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftNetworking",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "SwiftNetworking",
            targets: ["SwiftNetworking"]),
    ],
    targets: [
        .target(
            name: "SwiftNetworking",
            path: "SwiftNetworking",
            exclude: ["Info.plist", "SwiftNetworking.h"]),
        .testTarget(
            name: "SwiftNetworkingTests",
            dependencies: ["SwiftNetworking"],
            path: "SwiftNetworkingTests",
            exclude: ["Info.plist"]),
    ],
    swiftLanguageModes: [.v6]
)
