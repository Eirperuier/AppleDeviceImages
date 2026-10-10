// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppleDeviceImages",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [
        .library(name: "AppleDeviceImages", targets: ["AppleDeviceImages"]),
    ],
    targets: [
        .target(name: "AppleDeviceImages"),
        .testTarget(name: "AppleDeviceImagesTests", dependencies: ["AppleDeviceImages"]),
    ]
)
