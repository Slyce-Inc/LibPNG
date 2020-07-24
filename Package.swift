// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LibPNG",
    products: [
        .library(name: "LibPNG", targets: ["LibPNG"]),
    ],
    dependencies: [],
    targets: [
        .systemLibrary(name: "CPNG", path: "Library/CPNG", pkgConfig: "libpng", providers: [ .brew(["libpng"]), .apt(["libpng-dev"])]),
        .target(name: "LibPNG", dependencies: ["CPNG"]),
        .testTarget(name: "LibPNGTests", dependencies: ["LibPNG"]),
    ]
)
