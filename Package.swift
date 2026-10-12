// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WormaCeptor",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "WormaCeptorURLSession", targets: ["WormaCeptorURLSession"]),
        // The in-app inspector, separate so capture-only apps don't link SwiftUI screens.
        .library(name: "WormaCeptorUI", targets: ["WormaCeptorUI"]),
    ],
    targets: [
        .binaryTarget(
            name: "WormaCeptor",
            url: "https://github.com/azikar24/WormaCeptor-iOS/releases/download/0.2.0/WormaCeptor.xcframework.zip",
            checksum: "becd45652279a1f7f20d796214c65447a72a8e9b83980dd256889fafc55dd2c4"
        ),
        .target(name: "WormaCeptorURLSession", dependencies: ["WormaCeptor"]),
        .target(name: "WormaCeptorUI", dependencies: ["WormaCeptor"]),
    ]
)
