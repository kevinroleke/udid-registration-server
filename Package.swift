// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "udid-server",
    platforms: [
       .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/swift-mustache.git", from: "2.0.2"),
        .package(url: "https://github.com/swiftpackages/DotEnv.git", from: "3.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "udid-server",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Mustache", package: "swift-mustache"),
                .product(name: "DotEnv", package: "DotEnv"),
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
] }
