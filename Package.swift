// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "udid-server",
    platforms: [
       .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    
    ],
    targets: [
        .executableTarget(
            name: "udid-server",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
            
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
] }
