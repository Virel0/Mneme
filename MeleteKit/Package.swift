// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MeleteKit",
    platforms: [
        .tvOS("26.1"),
        .iOS("18.6"),
        // For `swift test` on the Mac that builds the app.
        .macOS(.v15),
    ],
    products: [
        .library(name: "MeleteKit", targets: ["MeleteKit"]),
    ],
    targets: [
        .target(name: "MeleteKit"),
        .testTarget(name: "MeleteKitTests", dependencies: ["MeleteKit"]),
    ]
)
