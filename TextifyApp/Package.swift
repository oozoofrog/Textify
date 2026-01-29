// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TextifyApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "TextifyApp",
            targets: ["TextifyApp"]
        )
    ],
    dependencies: [
        .package(path: "../TextifyKit")
    ],
    targets: [
        .executableTarget(
            name: "TextifyApp",
            dependencies: ["TextifyKit"],
            path: "TextifyApp/Sources",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
