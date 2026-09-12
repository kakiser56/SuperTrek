// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrekEngine",
    platforms: [.iOS(.v17), .macOS(.v15)],
    products: [
        .library(name: "TrekEngine", targets: ["TrekEngine"]),
    ],
    targets: [
        .target(name: "TrekEngine"),
        .testTarget(name: "TrekEngineTests", dependencies: ["TrekEngine"]),
    ]
)
