// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TextifyUI",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "TextifyUI", targets: ["TextifyUI"]),
    ],
    dependencies: [
        .package(path: "../TextifyKit"),
    ],
    targets: [
        .target(name: "TextifyUI", dependencies: ["TextifyKit"]),
        .testTarget(name: "TextifyUITests", dependencies: ["TextifyUI"]),
    ]
)
