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
            url: "https://github.com/azikar24/WormaCeptor-iOS/releases/download/0.1.1/WormaCeptor.xcframework.zip",
            checksum: "0559dbf85eb111fb4c085c9ea3abf8ab6c18759e7c44a74ec88c66a35a847121"
        ),
        .target(name: "WormaCeptorURLSession", dependencies: ["WormaCeptor"]),
        .target(name: "WormaCeptorUI", dependencies: ["WormaCeptor"]),
    ]
)
