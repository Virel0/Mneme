// swift-tools-version: 6.2

import PackageDescription

/// WireGuard for the packet tunnel: Mullvad's gotatun, built from crates.io
/// by `build.sh` behind the C interface in `rust/include/tunnel_core.h` (see
/// BUILD-INFO.txt), and a Swift face for it.
let package = Package(
    name: "Tunnel",
    platforms: [
        .tvOS("26.1"),
        .iOS("26.1"),
        // For `swift test` on the Mac that builds the app.
        .macOS(.v15),
    ],
    products: [
        .library(name: "Tunnel", targets: ["Tunnel"]),
    ],
    targets: [
        .binaryTarget(name: "TunnelCore", path: "TunnelCore.xcframework"),
        // The licences to show, of every crate in TunnelCore.
        .target(name: "Tunnel", dependencies: ["TunnelCore"], resources: [.copy("Licenses")]),
        .testTarget(name: "TunnelTests", dependencies: ["Tunnel"]),
    ]
)
