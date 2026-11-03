// swift-tools-version: 6.2

import PackageDescription

/// libass, with the FreeType, HarfBuzz and FriBidi it needs, built from
/// source by `build.sh` (see BUILD-INFO.txt), for drawing ASS/SSA subtitles
/// as they were authored.
let package = Package(
    name: "Libass",
    platforms: [
        .tvOS("26.1"),
        // For `swift test` on the Mac that builds the app.
        .macOS(.v15),
    ],
    products: [
        .library(name: "Libass", targets: ["Libass"]),
    ],
    targets: [
        .binaryTarget(name: "Libass", path: "Libass.xcframework"),
        .testTarget(name: "LibassTests", dependencies: ["Libass"]),
    ]
)
